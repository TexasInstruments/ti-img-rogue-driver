/*************************************************************************/ /*!
@File
@Title          RGX system layer fast path fence FPT-CB APU driver interface
@Codingstyle    IMG
@Copyright      Copyright (c) Imagination Technologies Ltd. All Rights Reserved
@Description    RGX fast path fence system interface for the external APU
                driver.

                This file contains all of the necessary definitions to allow
                communication for configuration process between the GPU and the
                APU drivers that communicate with a circulate buffer and
                register kick interface.
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

#ifndef SYS_FPF_FPT_CB_APU_IF_H
#define SYS_FPF_FPT_CB_APU_IF_H

#include <linux/types.h>

/*! Circular buffer configuration data.
 *
 * APU driver shall use this structure to pass information about circular
 * buffer allocations back to the GPU driver.
 */
struct fpf_apu2gpu_cb_config {
	phys_addr_t buff_paddr; /*!< Physical address of the circular buffer. */
	size_t buff_pages;      /*!< Number of pages of the circular buffer
	                             allocation. */
	phys_addr_t ctrl_paddr; /*!< Physical address of the circular buffer
	                             control structure. */
	size_t ctrl_pages;      /*!< Number of pages of the circular buffer
	                             control structure allocation (usually 1
	                             page). */
	size_t page_shift;      /*!< Page shift of the pages used in circular
	                             buffer allocations (usually 12 for 4K
	                             pages). */
};

/*! Kick register size.
 */
enum fpf_apu2gpu_kickreg_write_size
{
	FPF_APU2GPU_KICKREG_WRITE_SIZE_32B, /*!< Register is a 32-bit register. */
	FPF_APU2GPU_KICKREG_WRITE_SIZE_64B, /*!< Register is a 64-bit register. */
};

/*! Kick register bank details.
 *
 * API driver shall use these values to set up a mapping of the GPU register
 * bank.
 *
 * This can be for example done in the following way:
 *
 *     void __iomem *gpu_kick_regbank = ioremap(regbank_paddr.uiAddr,
 *                                              regbank_size);
 */
struct fpf_apu2gpu_kickreg_regbank
{
	IMG_CPU_PHYADDR regbank_paddr;
	IMG_UINT32 regbank_size;
};

/*! Kick register details.
 *
 * APU driver shall use these values to write to the GPU register
 * to communicate that APU has finished work which is ready to be processed
 * by the GPU.
 *
 * This can be for example done in the following way:
 *
 *     void __iomem *reg = (unsigned char __iomem *) gpu_kick_regbank +
 *                         reg_offset;
 *
 *     if (reg_size == FPF_APU2GPU_KICKREG_WRITE_SIZE_64B) {
 *         writeq(write_value, reg);
 *     } else {
 *         writel((u32) write_value, reg);
 *     }
 */
struct fpf_apu2gpu_kickreg_details
{
	enum fpf_apu2gpu_kickreg_write_size reg_size; /*! Kick regiter size (32-bit
	                                                  or 64-bit). */
	IMG_UINT32 reg_offset;                        /*! Register offset in the
	                                                  register bank. */
	IMG_UINT64 write_value;                       /*! Value to write. */
};

/*! Kick register configuration.
 *
 * APU driver shall use this data to map the register bank into its address
 * space and to signal the GPU about the completed work.
 */
struct fpf_apu2gpu_mts_config
{
	struct fpf_apu2gpu_kickreg_regbank kickreg_regbank;
	struct fpf_apu2gpu_kickreg_details kickreg_details;
};

/*!
 * @Function    fpf_apu2gpu_acquire_cb
 * @Description Retrieve from APU the physical address of the APU to GPU
 *              (inbound) circular buffer and the circular buffer's control
 *              structure along with the sizes of both of those allocations.
 * @Output      cb_config Pointer to the inbound circular buffer configuration
 *              object, see `fpf_apu2gpu_cb_config` for details.
 * @Return      0 on success and standard negative error code on failure.
 */
extern int fpf_apu2gpu_acquire_cb(struct fpf_apu2gpu_cb_config *cb_config);

/*!
 * @Function    fpf_apu2gpu_supply_kickreg
 * @Description Send details of the MTS register to the APU to give it an
 *              ability of signalling the firmware when a token is written
 *              to the APU to GPU (inbound) circular buffer.
 * @Input       mts_config Details of the MTS kick register, see
 *              `fpf_apu2gpu_mts_config` for details..
 * @Return      0 on success and standard negative error code on failure.
 */
extern int fpf_apu2gpu_supply_kickreg(struct fpf_apu2gpu_mts_config *mts_config);

/*!
 * @Function    fpf_apu2gpu_put
 * @Description Release resources acquired by `fpf_apu2gpu_acquire_cb()`
 *              and/or `fpf_apu2gpu_supply_kickreg()`.
 *
 *              After this call the GPU driver makes a promise to not use APU's
 *              resources.
 *
 * @Return      0 on success and standard negative error code on failure.
 */
extern int fpf_apu2gpu_put(void);

#endif /* SYS_FPF_FPT_CB_APU_IF_H */
