/*****************************************************************************
@File
@Title          System layer for devicetree-based embedded Linux platforms
@Codingstyle    IMG
@Copyright      Copyright (c) Imagination Technologies Ltd. All Rights Reserved
@Description    Implements a system layer compatible with upstream Linux
                PowerVR GPU devicetree bindings. As much of the required
                information as possible is deduced via Linux kernel APIs and
                definitions in the devicetree.
@License        Dual MIT/GPLv2

The contents of this file are subject to the MIT license as set out below.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

Alternatively, the contents of this file may be used under the terms of
the GNU General Public License Version 2 ("GPL") in which case the provisions
of GPL are applicable instead of those above.

If you wish to allow use of your version of this file only under the terms of
GPL, and not to allow others to use your version of this file under the terms
of the MIT license, indicate your decision by deleting the provisions above
and replace them with the notice and other provisions required by GPL as set
out in the file called "GPL-COPYING" included in this distribution. If you do
not delete the provisions above, a recipient may use your version of this file
under the terms of either the MIT license or GPL.

This License is also included in this distribution in the file called
"MIT-COPYING".

EXCEPT AS OTHERWISE STATED IN A NEGOTIATED AGREEMENT: (A) THE SOFTWARE IS
PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE AND NONINFRINGEMENT; AND (B) IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
******************************************************************************/

#include "syscommon.h"

#include "interrupt_support.h"
#include "pvrsrv_device.h"
#include "pvrsrv_error.h"
#include "rgxdevice.h"
#include "sysconfig_cmn.h"
#include "sysinfo.h"

#include <linux/clk.h>
#include <linux/clk/clk-conf.h>
#include <linux/dma-mapping.h>
#include <linux/of_device.h>
#include <linux/platform_device.h>
#include <linux/pm_domain.h>
#include <linux/pm_runtime.h>
#include <linux/slab.h>

typedef struct PD_DATA_TAG {
	struct device *psPDVdev;
	struct device_link *psPDLink;
} PD_DATA;

typedef struct SYS_LAYER_DATA_TAG {
	struct device *psGpuDev;
	struct clk *psGpuClk;
	/* PM data */
	PD_DATA *pasPDData;
	size_t uiPDCnt;
} SYS_LAYER_DATA;

static PVRSRV_ERROR PopulatePlatformResources(PVRSRV_DEVICE_CONFIG *psDevCfg)
{
	struct platform_device *const psPDev =
		to_platform_device(psDevCfg->pvOSDevice);
	const struct resource *const psRegBank =
		platform_get_resource(psPDev, IORESOURCE_MEM, 0);
	const int iIrq = platform_get_irq(psPDev, 0);
	SYS_LAYER_DATA *const pSysData = psDevCfg->hSysData;
	PVRSRV_ERROR eStatus = PVRSRV_OK;

	if (!psRegBank) {
		dev_err(psDevCfg->pvOSDevice,
			"%s: platform_get_resource() call failed\n", __func__);
		eStatus = PVRSRV_ERROR_INIT_FAILURE;
	}

	if (iIrq < 0) {
		dev_err(psDevCfg->pvOSDevice,
			"%s: platform_get_irq() call failed: %d\n", __func__,
			iIrq);
		eStatus = PVRSRV_ERROR_INIT_FAILURE;
	}

	pSysData->psGpuClk = devm_clk_get(psDevCfg->pvOSDevice, "core");
	if (IS_ERR(pSysData->psGpuClk)) {
		/* Don't really care about calling clk_disable_unprepare -
		 * we're failing device init, so device should be unbound
		 * imminently, and that in turn will handle all of the
		 * clk-related tidying up. */

		dev_err(psDevCfg->pvOSDevice,
			"%s: devm_clk_get() call failed: %ld\n", __func__,
			PTR_ERR(pSysData->psGpuClk));
		eStatus = PVRSRV_ERROR_INIT_FAILURE;
	}

	if (eStatus != PVRSRV_OK) {
		return eStatus;
	}

	psDevCfg->sRegsCpuPBase.uiAddr = psRegBank->start;
	psDevCfg->ui32RegsSize = resource_size(psRegBank);
	psDevCfg->ui32IRQ = iIrq;

	return PVRSRV_OK;
}

static PVRSRV_ERROR PopulateHeaps(PVRSRV_DEVICE_CONFIG *psDevCfg)
{
	PHYS_HEAP_CONFIG *psHeap = OSAllocZMem(sizeof(*psHeap));
	if (!psHeap) {
		dev_err(psDevCfg->pvOSDevice, "%s: memory allocation failed\n",
			__func__);
		return PVRSRV_ERROR_OUT_OF_MEMORY;
	}

	psHeap->eType = PHYS_HEAP_TYPE_UMA;
	psHeap->ui32UsageFlags = PHYS_HEAP_USAGE_GPU_LOCAL;
	psHeap->uConfig.sUMA.pszPDumpMemspaceName = "SYSMEM";
	psHeap->uConfig.sUMA.psMemFuncs = &g_sUmaHeapFns;
	psHeap->uConfig.sUMA.pszHeapName = "default";
	psHeap->uConfig.sUMA.hPrivData = NULL;

	psDevCfg->eDefaultHeap = PVRSRV_PHYS_HEAP_GPU_LOCAL;
	psDevCfg->pasPhysHeaps = psHeap;
	psDevCfg->ui32PhysHeapCount = 1;

	return PVRSRV_OK;
}

static PVRSRV_ERROR PopulateTimingInfo(struct device *psDev,
				       RGX_DATA *const psRgxData,
				       struct clk *const psGpuClk)
{
	const unsigned long ulClockRate = clk_get_rate(psGpuClk);
	RGX_TIMING_INFORMATION *psTimingInfo = NULL;

	if (!ulClockRate) {
		dev_err(psDev, "%s: clk_get_rate() returned 0\n", __func__);
		return PVRSRV_ERROR_INIT_FAILURE;
	}

	psTimingInfo = OSAllocMem(sizeof(*psTimingInfo));
	if (!psTimingInfo) {
		dev_err(psDev, "%s: memory allocation failed\n", __func__);
		return PVRSRV_ERROR_OUT_OF_MEMORY;
	}

	*psTimingInfo = (RGX_TIMING_INFORMATION){
		.ui32CoreClockSpeed = ulClockRate,
		.bEnableActivePM = IMG_TRUE,
		.bEnableRDPowIsland = IMG_FALSE,
		.ui32ActivePMLatencyms = SYS_RGX_ACTIVE_POWER_LATENCY_MS,
	};

	psRgxData->psRGXTimingInfo = psTimingInfo;

	return PVRSRV_OK;
}

static void FreeRGXData(RGX_DATA *psRgxData)
{
	if (psRgxData)
		OSFreeMem(psRgxData->psRGXTimingInfo);
	OSFreeMem(psRgxData);
}

static PVRSRV_ERROR PopulateRGXData(PVRSRV_DEVICE_CONFIG *psDevCfg)
{
	PVRSRV_ERROR eStatus = PVRSRV_OK;
	const SYS_LAYER_DATA *const pSysData = psDevCfg->hSysData;
	RGX_DATA *psRgxData = OSAllocZMem(sizeof(*psRgxData));
	if (!psRgxData) {
		dev_err(psDevCfg->pvOSDevice, "%s: memory allocation failed\n",
			__func__);
		return PVRSRV_ERROR_OUT_OF_MEMORY;
	}

	eStatus = PopulateTimingInfo(psDevCfg->pvOSDevice, psRgxData,
				     pSysData->psGpuClk);
	if (eStatus != PVRSRV_OK) {
		OSFreeMem(psRgxData);
	} else {
		psDevCfg->hDevData = psRgxData;
	}

	return eStatus;
}

static void FreeDevCfg(PVRSRV_DEVICE_CONFIG *psDevCfg)
{
	FreeRGXData(psDevCfg->hDevData);
	OSFreeMem(psDevCfg->pasPhysHeaps);
	OSFreeMem(psDevCfg->hSysData);
	OSFreeMem(psDevCfg);
}

static PVRSRV_ERROR PMInit(SYS_LAYER_DATA *const psData)
{
	struct device *const psDev = psData->psGpuDev;
	if (!psDev->pm_domain) {
		const int iPDCnt = of_count_phandle_with_args(
			psDev->of_node, "power-domains", "#power-domain-cells");
		if (iPDCnt < 2) {
			if (iPDCnt < 0) {
				dev_err(psDev,
					"%s: of_count_phandle_with_args() failed: %d\n",
					__func__, iPDCnt);
			} else {
				/* We should have 2+, 0 or 1 is unexpected */
				dev_err(psDev, "%s: unexpected PD count: %d\n",
					__func__, iPDCnt);
			}
			return PVRSRV_ERROR_INIT_FAILURE;
		}

		psData->pasPDData =
			OSAllocMem(sizeof(*(psData->pasPDData)) * iPDCnt);
		if (!psData->pasPDData) {
			dev_err(psDev,
				"%s: memory allocation for power domain data array failed\n",
				__func__);
			return PVRSRV_ERROR_OUT_OF_MEMORY;
		}

		for (psData->uiPDCnt = 0; psData->uiPDCnt < iPDCnt;
		     ++(psData->uiPDCnt)) {
			PD_DATA *const psCurrPD =
				&(psData->pasPDData[psData->uiPDCnt]);

			psCurrPD->psPDVdev = dev_pm_domain_attach_by_id(
				psDev, psData->uiPDCnt);
			if (IS_ERR_OR_NULL(psCurrPD->psPDVdev)) {
				dev_err(psDev,
					"%s: attaching to PD domain %zu failed: %ld\n",
					__func__, psData->uiPDCnt,
					PTR_ERR(psCurrPD->psPDVdev));
				return PVRSRV_ERROR_INIT_FAILURE;
			}

			psCurrPD->psPDLink = device_link_add(
				psDev, psCurrPD->psPDVdev,
				DL_FLAG_PM_RUNTIME | DL_FLAG_STATELESS);
			if (!(psCurrPD->psPDLink)) {
				dev_err(psDev,
					"%s: creating device link for PD %zu vdev failed\n",
					__func__, psData->uiPDCnt);
				/* Need to increment the power domain counter as PD vdev
				 * needs to be detached in cleanup code */
				++(psData->uiPDCnt);
				return PVRSRV_ERROR_INIT_FAILURE;
			}
		}
	}

	pm_runtime_enable(psDev);
	return PVRSRV_OK;
}

static void PMDeinit(SYS_LAYER_DATA *const psData)
{
	struct device *const psDev = psData->psGpuDev;
	pm_runtime_disable(psDev);
	while (psData->uiPDCnt) {
		PD_DATA *const psCurrPD =
			&(psData->pasPDData[--(psData->uiPDCnt)]);
		if (psCurrPD->psPDLink) {
			device_link_del(psCurrPD->psPDLink);
		}
		dev_pm_domain_detach(psCurrPD->psPDVdev, false);
	}
	OSFreeMem(psData->pasPDData);
}

static PVRSRV_ERROR PrePowerState(IMG_HANDLE hSysData,
				  PVRSRV_SYS_POWER_STATE eNewPowerState,
				  PVRSRV_SYS_POWER_STATE eCurrentPowerState,
				  PVRSRV_POWER_FLAGS ePwrFlags)
{
	const SYS_LAYER_DATA *const pSysData = hSysData;

	if ((PVRSRV_SYS_POWER_STATE_OFF == eNewPowerState) &&
	    (PVRSRV_SYS_POWER_STATE_ON == eCurrentPowerState)) {
		int iErr = pm_runtime_put_sync_autosuspend(pSysData->psGpuDev);
		if (iErr) {
			dev_err(pSysData->psGpuDev,
				"%s: pm_runtime_put_sync_autosuspend() failed: %d\n",
				__func__, iErr);
			return PVRSRV_ERROR_DEVICE_POWER_CHANGE_FAILURE;
		}
		clk_disable_unprepare(pSysData->psGpuClk);
	}
	return PVRSRV_OK;
}

static PVRSRV_ERROR PostPowerState(IMG_HANDLE hSysData,
				   PVRSRV_SYS_POWER_STATE eNewPowerState,
				   PVRSRV_SYS_POWER_STATE eCurrentPowerState,
				   PVRSRV_POWER_FLAGS ePwrFlags)
{
	const SYS_LAYER_DATA *const pSysData = hSysData;

	if ((PVRSRV_SYS_POWER_STATE_ON == eNewPowerState) &&
	    (PVRSRV_SYS_POWER_STATE_OFF == eCurrentPowerState)) {
		int iErr = clk_prepare_enable(pSysData->psGpuClk);
		if (iErr) {
			dev_err(pSysData->psGpuDev,
				"%s: clk_prepare_enable() failed: %d\n",
				__func__, iErr);
			return PVRSRV_ERROR_DEVICE_POWER_CHANGE_FAILURE;
		} else {
			iErr = pm_runtime_resume_and_get(pSysData->psGpuDev);
			if (iErr) {
				dev_err(pSysData->psGpuDev,
					"%s: pm_runtime_resume_and_get() failed: %d\n",
					__func__, iErr);
				return PVRSRV_ERROR_DEVICE_POWER_CHANGE_FAILURE;
			}
		}
	}
	return PVRSRV_OK;
}

PVRSRV_ERROR SysDevInit(void *pvOSDevice, PVRSRV_DEVICE_CONFIG **ppsDevConfig)
{
	PVRSRV_ERROR eStatus = PVRSRV_OK;
	const struct of_device_id *id;

	*ppsDevConfig = OSAllocMem(sizeof(**ppsDevConfig));
	if (!(*ppsDevConfig)) {
		dev_err(pvOSDevice, "%s: memory allocation failed\n", __func__);
		return PVRSRV_ERROR_OUT_OF_MEMORY;
	}

	**ppsDevConfig = (PVRSRV_DEVICE_CONFIG){
		.pvOSDevice = pvOSDevice,
		.pszName = SYS_RGX_DEV_NAME,
		.pszVersion = NULL,
		.eSystemCoherencyMode = PVRSRV_DEVICE_SNOOP_NONE,
		.bHasNonMappableLocalMemory = IMG_FALSE,
		.bHasFBCDCVersion31 = IMG_FALSE,
		.pfnSysDevErrorNotify = SysRGXErrorNotify,
		.pfnPrePowerState = PrePowerState,
		.pfnPostPowerState = PostPowerState,
	};

	do {
		/* Platform-specific quirks */
		id = of_match_device(
			((struct device *)pvOSDevice)->driver->of_match_table,
			pvOSDevice);
		if (id) {
			if (!(strcmp(id->compatible, "ti,j721s2-gpu") ||
				 strcmp(id->compatible, "ti,j721s2-pvr")))
			{
				(*ppsDevConfig)->eSystemCoherencyMode =
					PVRSRV_DEVICE_SNOOP_CPU_ONLY;
			}
		} else {
			dev_err(pvOSDevice, "%s: no matching device id\n",
				__func__);
			eStatus = PVRSRV_ERROR_INIT_FAILURE;
			break;
		}

		(*ppsDevConfig)->hSysData = OSAllocMem(sizeof(SYS_LAYER_DATA));
		if (!((*ppsDevConfig)->hSysData)) {
			eStatus = PVRSRV_ERROR_OUT_OF_MEMORY;
			break;
		} else {
			SYS_LAYER_DATA *const pSysData =
				(*ppsDevConfig)->hSysData;
			*pSysData = (SYS_LAYER_DATA){ .psGpuDev = pvOSDevice };
		}

		if (dma_set_mask(pvOSDevice, DMA_BIT_MASK(SYS_RGX_DMA_WIDTH))) {
			eStatus = PVRSRV_ERROR_INIT_FAILURE;
			break;
		}

		eStatus = PopulatePlatformResources(*ppsDevConfig);
		if (eStatus != PVRSRV_OK)
			break;

		eStatus = PopulateHeaps(*ppsDevConfig);
		if (eStatus != PVRSRV_OK)
			break;

		eStatus = PMInit((*ppsDevConfig)->hSysData);
		if (eStatus != PVRSRV_OK)
			break;

		if (pm_runtime_resume_and_get((struct device *)pvOSDevice))
			PVR_LOG(("%s: failed to resume", __func__));

		/* Set clock values from dt */
		if (of_clk_set_defaults(((struct device *)pvOSDevice)->of_node,
					true)) {
			PVR_DPF((PVR_DBG_ERROR, "%s: failed to set clock rates",
				 __func__));
			return PVRSRV_ERROR_INVALID_DEVICE;
		}

		eStatus = PopulateRGXData(*ppsDevConfig);
		if (eStatus != PVRSRV_OK)
			break;

		if (pm_runtime_put_sync_autosuspend(
			    (struct device *)pvOSDevice))
			PVR_LOG(("%s: failed to suspend", __func__));

		return PVRSRV_OK;
	} while (false);

	SysDevDeInit(*ppsDevConfig);
	*ppsDevConfig = NULL;
	return eStatus;
}

void SysDevDeInit(PVRSRV_DEVICE_CONFIG *psDevConfig)
{
	PMDeinit(psDevConfig->hSysData);
	FreeDevCfg(psDevConfig);
}

PVRSRV_ERROR SysDebugInfo(PVRSRV_DEVICE_CONFIG *psDevConfig,
			  DUMPDEBUG_PRINTF_FUNC *pfnDumpDebugPrintf,
			  void *pvDumpDebugFile)
{
	PVR_UNREFERENCED_PARAMETER(psDevConfig);
	PVR_UNREFERENCED_PARAMETER(pfnDumpDebugPrintf);
	PVR_UNREFERENCED_PARAMETER(pvDumpDebugFile);
	return PVRSRV_OK;
}

PVRSRV_ERROR SysInstallDeviceLISR(IMG_HANDLE hSysData, IMG_UINT32 ui32IRQ,
				  const IMG_CHAR *pszName, PFN_LISR pfnLISR,
				  void *pvData, IMG_HANDLE *phLISRData)
{
	return OSInstallSystemLISR(phLISRData, ui32IRQ, pszName, pfnLISR,
				   pvData, SYS_IRQ_FLAG_TRIGGER_DEFAULT);
}

PVRSRV_ERROR SysUninstallDeviceLISR(IMG_HANDLE hLISRData)
{
	return OSUninstallSystemLISR(hLISRData);
}
