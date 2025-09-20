/*************************************************************************/ /*!
@File
@Title          RGX system layer fast path fence interface
@Codingstyle    IMG
@Copyright      Copyright (c) Imagination Technologies Ltd. All Rights Reserved
@Description    RGX fast path fence system layer interface. Circular buffer
                implementation.
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
*/ /**************************************************************************/

#include "pvr_debug.h"
#include "allocmem.h"
#include "pvrsrv_device.h"
#include "rgxfwutils.h"
#include "sys_fpf_fpt_cb.h"

/* These stub functions are defined for internal build purposes.
 *
 * On real platforms those shall be defined in an APU driver. */

int fpf_apu2gpu_acquire_cb(struct fpf_apu2gpu_cb_config *cb_config)
{
	return -1;
}

int fpf_apu2gpu_supply_kickreg(struct fpf_apu2gpu_mts_config *mts_config)
{
	return -1;
}

int fpf_apu2gpu_put(void)
{
	return -1;
}

PVRSRV_ERROR SysFpfFptCbDeviceInit(PVRSRV_DEVICE_CONFIG *psDeviceConfig)
{
	RGX_FPF_KICK_COMMS_CONFIG *psFpfConfig =
		psDeviceConfig->psFpfConfigPrivData;
	PVRSRV_ERROR eError;

	PVR_LOG_RETURN_IF_INVALID_PARAM(psDeviceConfig != NULL,
					"psDeviceConfig");

	eError = fpf_apu2gpu_acquire_cb(&psFpfConfig->sApu2GpuConfig);
	PVR_LOG_RETURN_IF_ERROR(eError, "apumock_init_mts");

	{
		struct fpf_apu2gpu_mts_config sMTSKickRegDetails = {
			.kickreg_regbank = {
				.regbank_paddr = psDeviceConfig->sRegsCpuPBase,
				.regbank_size = psDeviceConfig->ui32RegsSize,
			},
			.kickreg_details = {
				.reg_size = FPF_APU2GPU_KICKREG_WRITE_SIZE_32B,
#if defined(RGX_FEATURE_NUM_OSIDS)
				.reg_offset = RGX_CR_MTS_SCHEDULE1,
				.write_value = RGXFWIF_DM_GP & ~RGX_CR_MTS_SCHEDULE1_DM_CLRMSK,
#else
				.reg_offset = RGX_CR_MTS_SCHEDULE,
				.write_value = RGXFWIF_DM_GP & ~RGX_CR_MTS_SCHEDULE_DM_CLRMSK,
#endif
			}
		};

		eError = fpf_apu2gpu_supply_kickreg(&sMTSKickRegDetails);
		PVR_LOG_RETURN_IF_ERROR(eError, "apumock_init_mts");
	}

	FPFCommonDeviceInit(psDeviceConfig);

	psDeviceConfig->eGPUKickType = RGXFWIF_FPF_GPU_KICKREG_TYPE_MTS;

	return PVRSRV_OK;
}

void SysFpfFptCbDeviceDeInit(PVRSRV_DEVICE_CONFIG *psDeviceConfig)
{
	PVR_UNREFERENCED_PARAMETER(psDeviceConfig);

	fpf_apu2gpu_put();
}

PVRSRV_ERROR SysFpfFptCbCommunicationInit(PVRSRV_DEVICE_CONFIG *psDeviceConfig,
					  RGX_FPF_KICK_COMMS_FWCTX *psContext)
{
	PVRSRV_DEVICE_NODE *psDeviceNode = psDeviceConfig->psDevNode;
	RGX_FPF_KICK_COMMS_CONFIG *psFpfConfig =
		psDeviceConfig->psFpfConfigPrivData;
	IMG_CPU_PHYADDR sBuffPAddr = { psFpfConfig->sApu2GpuConfig.buff_paddr };
	IMG_CPU_PHYADDR sCtrlPAddr = { psFpfConfig->sApu2GpuConfig.ctrl_paddr };
	IMG_HANDLE hBuff, hCtrl;
	PVRSRV_ERROR eError;

	eError = RGXRequestFWGPUMapResource(
		psDeviceNode, &sBuffPAddr,
		psFpfConfig->sApu2GpuConfig.page_shift,
		psFpfConfig->sApu2GpuConfig.buff_pages, &hBuff,
		&psContext->sFPTCBFWAddr);
	PVR_LOG_GOTO_IF_ERROR(eError, "RGXRequestFWGPUMapResource", ErrReturn);

	eError = RGXRequestFWGPUMapResource(
		psDeviceNode, &sCtrlPAddr,
		psFpfConfig->sApu2GpuConfig.page_shift,
		psFpfConfig->sApu2GpuConfig.ctrl_pages, &hCtrl,
		&psContext->sFPTCBCTRLFWAddr);
	PVR_LOG_GOTO_IF_ERROR(eError, "RGXRequestFWGPUMapResource",
			      ErrUnmapBuffer);

	psFpfConfig->hFpfBuff = hBuff;
	psFpfConfig->hFpfCtrl = hCtrl;

	return PVRSRV_OK;

ErrUnmapBuffer:
	RGXRequestFWGPUUnmapResource(hBuff);
ErrReturn:
	return eError;
}

void SysFpfFptCbCommunicationDeInit(PVRSRV_DEVICE_CONFIG *psDeviceConfig)
{
	RGX_FPF_KICK_COMMS_CONFIG *psFpfConfig =
		psDeviceConfig->psFpfConfigPrivData;

	if (psFpfConfig->hFpfBuff != NULL) {
		RGXRequestFWGPUUnmapResource(psFpfConfig->hFpfBuff);
	}
	if (psFpfConfig->hFpfBuff != NULL) {
		RGXRequestFWGPUUnmapResource(psFpfConfig->hFpfCtrl);
	}

	psFpfConfig->hFpfBuff = NULL;
	psFpfConfig->hFpfCtrl = NULL;
}
