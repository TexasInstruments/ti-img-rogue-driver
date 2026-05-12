########################################################################### ###
#@File
#@Copyright     Copyright (c) Imagination Technologies Ltd. All Rights Reserved
#@License       Dual MIT/GPLv2
#
# The contents of this file are subject to the MIT license as set out below.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# Alternatively, the contents of this file may be used under the terms of
# the GNU General Public License Version 2 ("GPL") in which case the provisions
# of GPL are applicable instead of those above.
#
# If you wish to allow use of your version of this file only under the terms of
# GPL, and not to allow others to use your version of this file under the terms
# of the MIT license, indicate your decision by deleting the provisions above
# and replace them with the notice and other provisions required by GPL as set
# out in the file called "GPL-COPYING" included in this distribution. If you do
# not delete the provisions above, a recipient may use your version of this file
# under the terms of either the MIT license or GPL.
#
# This License is also included in this distribution in the file called
# "MIT-COPYING".
#
# EXCEPT AS OTHERWISE STATED IN A NEGOTIATED AGREEMENT: (A) THE SOFTWARE IS
# PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
# BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
# PURPOSE AND NONINFRINGEMENT; AND (B) IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
# IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
### ###########################################################################

override PVRSRV_MODNAME := pvrsrvkm
obj-$(CONFIG_POWERVR_ROGUE) += $(PVRSRV_MODNAME).o

_pvrsrvkm_dir := $(src)

ifneq ($(KBUILD_EXTMOD),)
  # $(src) is reliable across kernel versions when building out of tree, so
  # there is no need to change it

  ccflags-$(CONFIG_X86_5LEVEL) += \
	-include $(srctree)/arch/x86/include/asm/cpufeatures.h
else
  # We're actually building pvrsrvkm in-tree, this makefile is our "anchor" to
  # work out whether $(src) has pre-6.10 (pre-b1992c3772e6) meaning or the new
  # meaning
  _abs_this_makefile_dir := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

  ifneq ($(_abs_this_makefile_dir),$(abspath $(src))/)
    # Kernel is <6.10, use $(srctree)/$(src)
    _pvrsrvkm_dir := $(srctree)/$(src)
  endif
endif

imgtec_kernel_top := $(_pvrsrvkm_dir)/..

# Config files
include $(imgtec_kernel_top)/config_kernel.mk
ccflags-y += -include $(imgtec_kernel_top)/config_kernel.h

# Aliases for pvrsrvkm.mk
HWDEFS_DIR := $(_pvrsrvkm_dir)/hwdefs/$(PVR_ARCH)
bridge_base := $(_pvrsrvkm_dir)/generated/$(PVR_ARCH)

# Need to use override as sometimes TOP gets specified as command line (when
# this Makefile is used in sub-Make that was invoked from out-of-tree build
# system), therefore setting without override is insufficient.
override TOP := $(_pvrsrvkm_dir)

include $(_pvrsrvkm_dir)/services/server/env/linux/pvrsrvkm.mk

ccflags-y += $(INTERNAL_KBUILD_CFLAGS)

ccflags-$(CONFIG_X86) += -mno-soft-float

ccflags-$(PVR_ARCH:rogue=y)    += -DPVR_ARCH_ROGUE
ccflags-$(PVR_ARCH:volcanic=y) += -DPVR_ARCH_VOLCANIC
