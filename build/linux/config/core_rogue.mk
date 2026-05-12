########################################################################### ###
#@File
#@Title         Root build configuration.
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


# Skip defining these UM/FW macros for kbuilds which do not define RGX_BVNC
ifneq ($(RGX_BNC_CONFIG_KM_HEADER),)

# Some (very few) rogue BVNCs actually come with volcanic testbench for the emulator
SUPPORT_VOLCANIC_TB :=\
 $(shell grep -qw RGX_FEATURE_VOLCANIC_TB $(RGX_BNC_CONFIG_KM) && echo 1)

# Only the Firmware needs this make macro.
SUPPORT_META_DMA :=\
 $(shell grep -qw RGX_FEATURE_META_DMA $(RGX_BNC_CONFIG_KM) && echo 1)

# SoC Timer is enabled for GPU cores that can support it.
SUPPORT_SOC_TIMER ?=\
 $(shell grep -qw RGX_FEATURE_SOC_TIMER $(RGX_BNC_CONFIG_KM) && echo 1)

# Only the Firmware needs this make macro.
SUPPORT_META_COREMEM :=\
 $(shell grep -qe 'RGX_FEATURE_META_COREMEM_SIZE ([123456789][1234567890]*U*)' $(RGX_BNC_CONFIG_KM) && echo 1)

# Client drivers, firmware and libsrv_um need this make macro.
SUPPORT_COMPUTE := \
 $(shell grep -qw RGX_FEATURE_COMPUTE $(RGX_BNC_CONFIG_KM) && echo 1)

# Compute only used by Firmware and client drivers
SUPPORT_COMPUTE_ONLY := \
 $(shell grep -qw RGX_FEATURE_COMPUTE_ONLY $(RGX_BNC_CONFIG_KM) && echo 1)

# FASTRENDER_DM | COMPUTE_ONLY | SUPPORT_TQ
# -----------------------------------------
# 0             | 0            | 1
# 1             | 0            | 1
# 0             | 1            | 0
# 1             | 1            | 1
SUPPORT_TQ := \
 $(shell grep -qw RGX_FEATURE_FASTRENDER_DM $(RGX_BNC_CONFIG_KM) || ! grep -qw RGX_FEATURE_COMPUTE_ONLY $(RGX_BNC_CONFIG_KM) && echo 1)

# Macro used by client driver makefiles only.
OPENCL_CDM_FORMAT_2 ?= \
 $(shell grep -qw "RGX_FEATURE_CDM_CONTROL_STREAM_FORMAT (2U*)" $(RGX_BNC_CONFIG_KM) && echo 1)

# Only the Firmware needs this make macro.
SUPPORT_MIPS_FIRMWARE :=\
 $(shell grep -qw RGX_FEATURE_MIPS $(RGX_BNC_CONFIG_KM) && echo 1)

# Only the Firmware needs this make macro.
SUPPORT_RISCV_FIRMWARE :=\
 $(shell grep -qw RGX_FEATURE_RISCV_FW_PROCESSOR $(RGX_BNC_CONFIG_KM) && echo 1)

# Firmware and libsrv_um need this make macro.
SUPPORT_TLA :=\
 $(shell grep -qw RGX_FEATURE_TLA $(RGX_BNC_CONFIG_KM) && echo 1)

# Firmware and libsrv_um need this make macro.
SUPPORT_FASTRENDER_DM :=\
 $(shell grep -qw RGX_FEATURE_FASTRENDER_DM $(RGX_BNC_CONFIG_KM) && echo 1)

# FBC descriptors are used by both volcanic and meteoric
SUPPORT_FBC_DESCRIPTORS := \
 $(shell grep -qw 'RGX_FEATURE_FBCDC' $(RGX_BNC_CONFIG_KM) && ! grep -qw 'RGX_FEATURE_FBC_MAX_DEFAULT_DESCRIPTORS (0U)' $(RGX_BNC_CONFIG_KM) && echo 1)

CORE_SUPPORTS_MULTICORE :=\
 $(shell grep -qw RGX_FEATURE_GPU_MULTICORE_SUPPORT $(RGX_BNC_CONFIG_KM) && grep -qw RGX_FEATURE_XPU_MAX_SLAVES $(RGX_BNC_CONFIG_KM) && echo 1)

# Macro used by client driver makefiles only.
ifneq ($(wildcard $(RGX_BNC_CONFIG_H)),)
 SUPPORT_ES32 :=\
    $(shell grep -qw RGX_FEATURE_ASTC $(RGX_BNC_CONFIG_H) && grep -qw RGX_FEATURE_GS_RTA_SUPPORT $(RGX_BNC_CONFIG_KM) && echo 1)

 SUPPORT_OPENGL ?=
endif
endif

ifeq ($(SUPPORT_COMPUTE_ONLY),1)
	# A compute only core has neither TLA or 3D
	PVRSRV_SUPPORT_LEGACY_TQ_UM ?= 0
	PVRSRV_SUPPORT_LEGACY_TQ_FW ?= 0
else
	ifneq ($(SUPPORT_FASTRENDER_DM),1)
	# Without a TDM, the TLA and/or 3D TQ is required
	PVRSRV_SUPPORT_LEGACY_TQ_UM ?= 1
	PVRSRV_SUPPORT_LEGACY_TQ_FW ?= 1
	endif
endif

# Build's selected list of components.
# - components.mk is a per-build file that specifies the components that are
#   to be built
# Include consumer DDK components
-include components.mk

$(eval $(call BothConfigMake,PVRSRV_DIR, services))

# Set up the host and target compiler.
include ../config/compiler.mk

# pvr-gdb needs extra components
#
ifeq ($(SUPPORT_DEBUGGER),1)
 ifneq ($(filter opencl,$(COMPONENTS)),)
  COMPONENTS += libpvrdebugger pvrgtrace
 endif
 ifneq ($(filter opengles3,$(COMPONENTS)),)
  COMPONENTS += libpvrdebugger pvrgtrace
 endif
 ifneq ($(filter vulkan,$(COMPONENTS)),)
  COMPONENTS += libpvrdebugger pvrgtrace
 endif
 ifeq ($(SUPPORT_ANDROID_PLATFORM),1)
  COMPONENTS += libpvrdebugipc
 endif
 ifeq ($(SUPPORT_DEBUGGER_UNITTESTS), 1)
  COMPONENTS += gdb_ocl_test gdb_unit_test dbg_pipe_test dbg_unit_test
 endif
endif

$(if $(filter config,$(D)),$(info Build configuration:))

################################# CONFIG ####################################

-include ../config/core-internal.mk

$(eval $(call AppHintConfigC,PVRSRV_APPHINT_FIRMWARE_HEAP_POLICY,5,\
Apphint that configures the Firmware Heap mode. First two bits configures_\
the free block selection policy. Bit 2 configures the bucket selection policy_\
))

# Firmware toolchain versions
$(eval $(call BothConfigMake,METAG_VERSION_NEEDED,2.8.1.0.3))
$(eval $(call BothConfigMake,MIPS_VERSION_NEEDED,2014.07-1))
$(eval $(call BothConfigMake,RISCV_VERSION_NEEDED,2024.1.0))

ifneq ($(SUPPORT_NEUTRINO_PLATFORM), 1)

# Bazel build is isolated from host environment and defines its own build
# artifacts. Toolchain relevant configs are not required for bazel.
ifeq ($(PVR_ANDROID_BAZEL_KBUILD),1)
$(eval $(call BothConfigMake,KERNEL_ID,$(KERNEL_ID)))
$(eval $(call BothConfigMake,KERNEL_COMPONENTS,$(KERNEL_COMPONENTS)))
$(eval $(call BothConfigMake,PVRSRV_MODULE_BASEDIR,$(PVRSRV_MODULE_BASEDIR)))
else
# If KERNELDIR is set, write it out to the config.mk, with
# KERNEL_COMPONENTS and KERNEL_ID
#
ifneq ($(strip $(KERNELDIR)),)
PVRSRV_MODULE_BASEDIR ?= /lib/modules/$(KERNEL_ID)/extra/
$(eval $(call BothConfigMake,KERNELDIR,$(KERNELDIR)))
$(eval $(call BothConfigMake,KERNEL_ID,$(KERNEL_ID)))
$(eval $(call BothConfigMake,PVRSRV_MODULE_BASEDIR,$(PVRSRV_MODULE_BASEDIR)))
$(eval $(call BothConfigMake,KERNEL_COMPONENTS,$(KERNEL_COMPONENTS)))
$(eval $(call TunableKernelConfigMake,EXTRA_PVRSRVKM_COMPONENTS,,\
List of components that should be built in to pvrsrvkm.ko$(comma) rather than_\
forming separate kernel modules._\
))

KERNEL_CROSS_COMPILE ?= $(CROSS_COMPILE)
$(eval $(call TunableBothConfigMake,KERNEL_CROSS_COMPILE,))

# Alternatively, allow the CC used for kbuild to be overridden
# exactly, bypassing any KERNEL_CROSS_COMPILE configuration.
# AR, LD, NM, OBJCOPY and OBJDUMP could be overridden by set
# of CC tools.
$(eval $(call TunableBothConfigMake,KERNEL_AR,))
$(eval $(call TunableBothConfigMake,KERNEL_CC,))
$(eval $(call TunableBothConfigMake,KERNEL_LD,))
$(eval $(call TunableBothConfigMake,KERNEL_NM,))
$(eval $(call TunableBothConfigMake,KERNEL_OBJCOPY,))
$(eval $(call TunableBothConfigMake,KERNEL_OBJDUMP,))

# Check the KERNELDIR has a kernel built.
KERNEL_AUTOCONF := \
 $(strip $(wildcard $(KERNELDIR)/include/linux/autoconf.h) \
         $(wildcard $(KERNELDIR)/include/generated/autoconf.h))
ifeq ($(KERNEL_AUTOCONF),)
$(warning autoconf.h not found in $$(KERNELDIR)/include/linux \
or $$(KERNELDIR)/include/generated. Check your $$(KERNELDIR) variable \
and kernel configuration.)
endif
else
$(if $(KERNEL_COMPONENTS),$(warning KERNELDIR is not set. Kernel components cannot be built))
endif

endif # PVR_ANDROID_BAZEL_KBUILD

endif # !Neutrino


ifneq ($(_window_systems),)
# If there's only one window system then don't output this option as part
# of `make confighelp`
ifeq ($(words $(_window_systems)),1)
$(eval $(call BothConfigMake,WINDOW_SYSTEM,$(WINDOW_SYSTEM)))
else
$(eval $(call TunableBothConfigMake,WINDOW_SYSTEM,,\
Window system to use ($(_window_systems))._\
))
endif
endif

# Ideally configured by platform Makefiles, as necessary
#
RGX_FW_FILENAME_PREFIX ?= rgx.fw
RGX_FW_FILENAME_PREFIX_KM ?= "\"$(RGX_FW_FILENAME_PREFIX)\""

# RGX_FW_SIGNED=1 means that the user wants to sign the firmware binaries.
# In such a case, the build system needs to ensure that it has access to the
# public / private key and the message digest algo is correctly specified.
# If unavailable, we must handle these problems gracefully (by falling back
# to known values) or reporting errors to the user.
# Here's what we do,
# -> If kernel version is less than 4.9, we throw a warning as signing feature
#    is unsupported for older kernels, and fall back to unsigned firmware.
# -> If kernel version is >= 4.9,
#    .. If message digest algo is not specified, we fall back to "sha1"
#    .. If public / private key are not specified, we throw an error and exit.
ifeq ($(RGX_FW_SIGNED),1)
 ifeq ($(call kernel-version-is-available),true)
  ifeq ($(call kernel-version-at-least,4,9),true)
   override RGX_FW_HASH ?= sha1
   override RGX_FILENAME_SIGN := .signed
   ifeq ($(RGX_FW_PRIV_KEY),)
    $(error RGX_FW_PRIV_KEY must be set for RGX_FW_SIGNED=1.)
   endif # !RGX_FW_PRIV_KEY
   ifeq ($(RGX_FW_X509),)
    $(error RGX_FW_X509 must be set for RGX_FW_SIGNED=1.)
   endif # !RGX_FW_X509
  else
   $(warning Firmware signing is not implemented for kernels < 4.9. Signing will not be done!!)
   override RGX_FW_SIGNED := 0
  endif # ($(call kernel-version-at-least,4,9),true)
 endif # ($(call kernel-version-is-available),true)
endif # RGX_FW_SIGNED

ifeq ($(SUPPORT_OPEN_SOURCE_DRIVER_FIRMWARE),1)
else
endif # SUPPORT_OPEN_SOURCE_DRIVER_FIRMWARE


ifeq ($(RGX_FW_SIGNED),1)



endif # RGX_FW_SIGNED

ifeq ($(RGX_FW_SIGNED),1)
$(eval $(call KernelConfigC,RGX_FW_FILENAME,"$(RGX_FW_FILENAME_PREFIX_KM) \".signed\""))
$(eval $(call KernelConfigC,RGX_SH_FILENAME,"\"rgx.sh.signed\""))
ifneq ($(RGX_FW_X509),)
$(eval $(call KernelConfigC,RGX_FW_SIGNED,1))
endif # RGX_FW_X509
else ifeq ($(SUPPORT_CUSTOMER_SIGNING),1)
$(eval $(call KernelConfigC,RGX_FW_FILENAME,"$(RGX_FW_FILENAME_PREFIX_KM) \".signed\""))
$(eval $(call KernelConfigC,RGX_SH_FILENAME,"\"rgx.sh\""))
$(eval $(call KernelConfigC,SUPPORT_CUSTOMER_SIGNING,1))
else
$(eval $(call KernelConfigC,RGX_FW_FILENAME,"$(RGX_FW_FILENAME_PREFIX_KM)"))
$(eval $(call KernelConfigC,RGX_SH_FILENAME,"\"rgx.sh\""))
endif # RGX_FW_SIGNED

ifneq ($(SUPPORT_ANDROID_PLATFORM),1)
 ifeq ($(wildcard ${TOP}/build/linux/tools/prepare-llvm.sh),)
  # No facility for using LLVM in this package.
 else ifeq ($(LLVM_BUILD_DIR),)
  $(warning LLVM_BUILD_DIR is not set. Components that use it (e.g. OpenCL, Vulkan) cannot be built)
 else
  override LLVM_BUILD_DIR := $(abspath $(LLVM_BUILD_DIR))
  ifneq ($(PVR_NO_LLVM_CHECK),1)
  ifeq ($(SUPPORT_NEUTRINO_PLATFORM),1)
    LLVM_MESSAGE=$(shell VARIANT1=${VARIANT1} CC=${CC} CXX=${CXX} ${TOP}/build/linux/tools/prepare-llvm.sh -c $(LLVM_BUILD_DIR))
  else
    LLVM_MESSAGE=$(shell ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} ${TOP}/build/linux/tools/prepare-llvm.sh -c $(LLVM_BUILD_DIR))
  endif

  ifneq ($(filter Error:,$(firstword $(LLVM_MESSAGE))),)
   $(info  *** prepare-llvm.sh: $(LLVM_MESSAGE))
   $(error *** LLVM_BUILD_DIR $(LLVM_BUILD_DIR) is not suitable)
  endif

  ifneq ($(filter Warning:,$(firstword $(LLVM_MESSAGE))),)
   $(info  *** prepare-llvm.sh: $(LLVM_MESSAGE))
  endif
  endif

  # Because we need to handle MULTIARCH builds, we can't work out the
  # architecture to use in the paths until compile-time.  So leave
  # _LLVM_ARCH_ as a placeholder that will be replaced in the
  # moduledef.
  LLVM_INCLUDE_PATH := $(LLVM_BUILD_DIR)/llvm.src/llvm/include \
                       $(LLVM_BUILD_DIR)/llvm._LLVM_ARCH_/include

  CLANG_INCLUDE_PATH := $(LLVM_INCLUDE_PATH) \
                        $(LLVM_BUILD_DIR)/llvm.src/clang/include \
                        $(LLVM_BUILD_DIR)/llvm._LLVM_ARCH_/tools/clang/include

  SPV_INCLUDE_PATH := $(LLVM_INCLUDE_PATH) \
                      $(LLVM_BUILD_DIR)/llvm.src/spv-translator/include \
                      $(LLVM_BUILD_DIR)/llvm._LLVM_ARCH_/tools/SPV_TRANSLATOR/include

  LLVM_LIB_PATH := $(LLVM_BUILD_DIR)/llvm._LLVM_ARCH_/lib/

  LLVM_INCLUDE_PATH_HOST := $(LLVM_BUILD_DIR)/llvm.src/llvm/include/ \
                            $(LLVM_BUILD_DIR)/llvm._LLVM_ARCH_/include/

  CLANG_INCLUDE_PATH_HOST := $(LLVM_INCLUDE_PATH_HOST) \
                             $(LLVM_BUILD_DIR)/llvm.src/clang/include \
                             $(LLVM_BUILD_DIR)/llvm._LLVM_ARCH_/tools/clang/include

  SPV_INCLUDE_PATH_HOST := $(LLVM_INCLUDE_PATH_HOST) \
                           $(LLVM_BUILD_DIR)/llvm.src/spv-translator/include \
                           $(LLVM_BUILD_DIR)/llvm._LLVM_ARCH_/tools/SPV_TRANSLATOR/include

  LLVM_LIB_PATH_HOST := $(LLVM_BUILD_DIR)/llvm._LLVM_ARCH_/lib/
 endif
 else
 LLVM_MESSAGE=$(shell ANDROID_SDK_ROOT=$(ANDROID_SDK_ROOT) ${TOP}/build/linux/tools/prepare-llvm-android.sh -a verify -t "$(JNI_CPU_ABI) $(JNI_CPU_ABI_2ND)")

 ifneq ($(filter Warning:,$(firstword $(LLVM_MESSAGE))),)
  $(info  *** prepare-llvm-android.sh: $(LLVM_MESSAGE))
  $(info *** Please update your VNDK with the newer LLVM version. )
 endif
endif






# The SPV library is in the same folder as the LLVM ones as it is built
# as part of LLVM


# Enable USE_LLD_LINKER Makefile config for Clang compiler
ifeq ($(SUPPORT_ANDROID_PLATFORM),)
 ifeq ($(_CLANG),true)
  $(eval $(call BothConfigMake,USE_LLD_LINKER,1))
 endif
endif



$(if $(USE_CCACHE),$(if $(USE_DISTCC),$(error\
Enabling both USE_CCACHE and USE_DISTCC at the same time is not supported)))


$(eval $(call TunableKernelConfigMake,LLVM_IAS,,\
Enable Clang's integrated assembler. This feature is supported by default from_\
Linux v5.15-rc1. Use a tunable option so it can be disabled for older kernels._\
))

# Invariant options for Linux
#
$(eval $(call BothConfigC,PVR_BUILD_DIR,"\"$(PVR_BUILD_DIR)\""))
$(eval $(call BothConfigC,PVR_BUILD_TYPE,"\"$(BUILD)\""))
$(eval $(call BothConfigC,PVRSRV_MODNAME,"\"$(PVRSRV_MODNAME)\""))
$(eval $(call BothConfigMake,PVRSRV_MODNAME,$(PVRSRV_MODNAME)))
$(eval $(call BothConfigC,PVRSYNC_MODNAME,"\"$(PVRSYNC_MODNAME)\""))
$(eval $(call BothConfigMake,PVR_BUILD_DIR,$(PVR_BUILD_DIR)))
$(eval $(call BothConfigMake,PVR_BUILD_TYPE,$(BUILD)))

SUPPORT_RGX ?= 1
ifeq ($(SUPPORT_RGX),1)
$(eval $(call BothConfigC,SUPPORT_RGX,1))
$(eval $(call BothConfigMake,SUPPORT_RGX,1))
endif

# Some of the definitions in stdint.h aren't exposed by default in C++ mode,
# unless these macros are defined. To make sure we get these definitions
# regardless of which files include stdint.h, define them here.

ifeq ($(SUPPORT_ANDROID_PLATFORM),1)
ifeq ($(USE_ELF_TLS),1)
else
endif
else
endif

ifneq ($(DISPLAY_CONTROLLER),)
$(eval $(call BothConfigC,DISPLAY_CONTROLLER,$(DISPLAY_CONTROLLER)))
$(eval $(call BothConfigMake,DISPLAY_CONTROLLER,$(DISPLAY_CONTROLLER)))
endif

ifneq ($(DMA_CONTROLLER),)
endif
ifneq ($(GPU_UTIL),)
endif
ifneq ($(GPU_CONTROLLER),)
endif


$(eval $(call BothConfigMake,PVR_SYSTEM,$(PVR_SYSTEM)))
$(eval $(call KernelConfigMake,PVR_LOADER,$(PVR_LOADER)))

ifeq ($(MESA_EGL),1)
else
endif

$(eval $(call TunableBothConfigC,USE_PVRSYNC_DEVNODE,,\
Use a separate device node for PVR Sync._\
This is set on a per-platform basis$(comma) and should not normally be changed._\
It is a tunable in order to make testing easier._\
))
$(eval $(call TunableKernelConfigMake,USE_PVRSYNC_DEVNODE,))

$(eval $(call TunableKernelConfigC,SUPPORT_SYNC_IRQ,))


# Set the maximum number of GPU devices supported in the DDK. This should range
# from 1 to 64
ifeq ($(PVRSRV_MAX_DEVICES),)
 override PVRSRV_MAX_DEVICES := 8
endif
$(eval $(call CheckValueInRange,PVRSRV_MAX_DEVICES,1,64))

$(eval $(call BothConfigC,PVRSRV_MAX_DEVICES,$(PVRSRV_MAX_DEVICES),\
Specify the maximum number of device instances to be supported by the DDK._\
This can range from 1 .. 64. Note: This setting will increase or decrease the_\
memory footprint of the driver._\
))

# Derive PVRSRV_HWPERF_COUNTERS_PERBLK. If not set this is defaulted to
# 12 for non-SUPPORT_VALIDATION or 64 for SUPPORT_VALIDATION builds.
ifeq ($(PVRSRV_HWPERF_COUNTERS_PERBLK),)
 ifeq ($(SUPPORT_VALIDATION),1)
  override PVRSRV_HWPERF_COUNTERS_PERBLK := 64
 else
  override PVRSRV_HWPERF_COUNTERS_PERBLK := 12
 endif
endif
$(eval $(call TunableBothConfigC,PVRSRV_HWPERF_COUNTERS_PERBLK,,\
Specify the maximum number of HWPerf counters to allow per non-multiplexed block (12..64)._\
This is only applicable to directly addressable counters in non-mux HWPerf counter blocks._\
))

# Validate that we have a reasonable value for PVRSRV_HWPERF_COUNTERS_PERBLK.
# Odd values will fail with a static assert so we limit the range from 8 to
# 64 with a 4-step increment.
ValidRange := 8 12 16 20 24 28 32 36 40 44 48 52 56 60 64
$(eval $(call ValidateValues,PVRSRV_HWPERF_COUNTERS_PERBLK,$(ValidRange)))

# Query the Intermediate Physical Address support. If set we provide a
# means to specify particular physical address bits to be set for an IPA.
$(eval $(call TunableBothConfigC,SUPPORT_STATIC_IPA,,\
Enable Intermediate Physical Address support in the DDK._\
))

# Build-type dependent options
#
$(eval $(call BothConfigMake,BUILD,$(BUILD)))

ifeq ($(SUPPORT_VALIDATION),1)
SUPPORT_TRP :=\
 $(shell grep -qw RGX_FEATURE_TILE_REGION_PROTECTION $(RGX_BNC_CONFIG_KM) && ! grep -qw RGX_FEATURE_COMPUTE_ONLY $(RGX_BNC_CONFIG_KM) && echo 1)

# Enable Periodic Hardware Reset functionality for testing
override PVR_ENABLE_PHR := 1
# Enable CSW register decode
override PVRSRV_DEBUG_CSW_STATE := 1
endif

ifeq ($(SUPPORT_PERFORMANCE_RUN),1)
PVRSRV_APPHINT_HWPERFDISABLECOUNTERFILTER := 1
OCL_DUMP_KERNEL_DISASSEMBLY := 1
endif


# Sort bridge structure members according to size from biggest to smallest
# members.
#
$(eval $(call TunableBothConfigMake,SORT_BRIDGE_STRUCTS,1))

# Prevent excluding regconfig bridge when the build level macro defined,
# regconfig functions are used in pvrdebug.
#
ifeq ($(SUPPORT_USER_REGISTER_CONFIGURATION),1)
ifeq ($(EXCLUDE_RGXREGCONFIG_BRIDGE),1)
override EXCLUDE_RGXREGCONFIG_BRIDGE := 0
endif
endif

ifeq ($(SUPPORT_ANDROID_PLATFORM),1)
# Always use DEBUGLINK. These days we are using external components which
# have large amounts of C++ debug information and it is impractical to carry
# statically linked components to the target filesystem without stripping.
DEBUGLINK ?= 1
# For kernel modules
KERNEL_DEBUGLINK ?= 1
endif

ifeq ($(BUILD),debug)

$(eval $(call TunableBothConfigMake,PVR_SERVICES_DEBUG,,\
Enable additional services debug options._\
This needs to be enabled for both the UM and KM builds_\
so that compatibility between them is achieved.\
))

ifeq ($(PVR_SERVICES_DEBUG),1)
PVRSRV_ENABLE_GPU_MEMORY_INFO ?= 1
PVRSRV_DEBUG_HANDLE_LOCK ?= 1
PVRSRV_APPHINT_ENABLEFWPOISONONFREE ?= IMG_TRUE
PVRSRV_TIMER_CORRELATION_HISTORY ?= 1
PVRSRV_PHYSMEM_CPUMAP_HISTORY ?= 1
endif

# enable sync prim poisoning in debug builds
PVRSRV_ENABLE_SYNC_POISONING ?= 1

# bridge debug and statistics enabled by default in debug builds
DEBUG_BRIDGE_KM ?= 1
$(eval $(call BothConfigC,DEBUG,))
$(eval $(call TunableBothConfigMake,DEBUGLINK,))
PERFDATA ?= 1
TRACK_FW_BOOT ?= 1
RGXFW_ASSERT_ENABLED ?= 1

else ifeq ($(BUILD),release)
$(eval $(call BothConfigC,RELEASE,))
$(eval $(call TunableBothConfigMake,DEBUGLINK,1))


else ifeq ($(BUILD),timing)
$(eval $(call BothConfigC,TIMING,))
$(eval $(call TunableBothConfigMake,DEBUGLINK,1))
else
$(error BUILD= must be either debug, release or timing)

endif # $BUILD



$(eval $(call TunableKernelConfigMake,KERNEL_DEBUGLINK,,\
Enable this to store DDK kernel module debugging symbols in separate$(comma) per_\
module$(comma) .dbg files. These files will not be installed on the target system$(comma)_\
but can be used by tools$(comma) e.g. gdb$(comma) for offline debugging. This may be_\
desirable when the target system has limited storage space and the kernel_\
has been configured with CONFIG_DEBUG_INFO=y$(comma) which can have a significant_\
impact on kernel module size.))

$(eval $(call TunableBothConfigMake,COMPRESS_DEBUG_SECTIONS,,\
Enable compression on debug sections (.zdebug)_\
May have tool compatibility issues.))


ifneq ($(SUPPORT_ALT_REGBASE),)
$(eval $(call KernelConfigC,SUPPORT_ALT_REGBASE,,\
Some systems alter the GPU addresses before they reach the bus, e.g. by appending_\
a MSB bit. In such cases, the GPU regbank in the system address space might alias_\
from the GPU perspective with memory addresses used by the GPU. For example, if_\
the GPU regbank is located in the lower 1GB and the 32bit GPU accesses the range_\
1GB-5GB due to the address alteration. In such cases, the MIPS wrapper must use_\
an alternate register bank address to avoid aliasing with device memory. The address_\
used must be an address that is not mapped in the GPU as memory. The memory backing_\
those addresses is never touched since the access is resolved inside the GPU.\
\))
endif

# User-configurable options
#
$(eval $(call TunableBothConfigMake,RGX_BNC,))
ifneq ($(RGX_BVNC),)
$(eval $(call TunableKernelConfigC,RGX_BVNC_CORE_KM_HEADER,))
endif
ifneq ($(RGX_BVNC),)
$(eval $(call TunableKernelConfigC,RGX_BNC_CONFIG_KM_HEADER,))
endif

$(eval $(call TunableBothConfigC,PVRSRV_DEBUG_HANDLE_LOCK,,\
Enable checking that the handle lock is held when a handle reference_\
count is modified))

$(eval $(call TunableKernelConfigMake,PVRSRV_ENABLE_DYNAMIC_PHYSHEAPS,))
$(eval $(call TunableKernelConfigC,PVRSRV_ENABLE_DYNAMIC_PHYSHEAPS,,\
Include module in KMD for VRAM based systems to utilise the dynamic import physical heaps IMA/DLM.\
))

$(eval $(call TunableKernelConfigMake,PVRSRV_ENABLE_XD_MEM,1))
$(eval $(call TunableKernelConfigC,PVRSRV_ENABLE_XD_MEM,1,\
Enable sharing of physical memory between devices.\
))

$(eval $(call TunableKernelConfigMake,PVRSRV_PHYSMEM_CPUMAP_HISTORY,,\
Enable and include debug module to track KM CPU PMR mappings \
))
$(eval $(call TunableKernelConfigC,PVRSRV_PHYSMEM_CPUMAP_HISTORY,,\
Enable and include debug module to track KM CPU PMR mappings \
))

$(eval $(call TunableBothConfigC,PVR_DBG_BREAK_ASSERT_FAIL,,\
Enable this to treat PVR_DBG_BREAK as PVR_ASSERT(0)._\
Otherwise it is ignored._\
))
$(eval $(call TunableBothConfigC,PDUMP,,\
Enable parameter dumping in the driver._\
This adds code to record the parameters being sent to the hardware for_\
later analysis._\
))
$(eval $(call TunableBothConfigC,NO_HARDWARE,,\
Disable hardware interactions (e.g. register writes) that the driver would_\
normally perform. A driver built with this option can$(apos)t drive hardware$(comma)_\
but with PDUMP enabled$(comma) it can capture parameters to be played back later._\
))
$(eval $(call TunableBothConfigC,PDUMP_DEBUG_OUTFILES,,\
Add debug information to the pdump script (out2.txt) as it is generated._\
This includes line numbers$(comma) process names and also enables checksumming_\
of the binary data dumped to out2.prm which can be verified offline._\
))
$(eval $(call TunableKernelConfigC,PVRSRV_NEED_PVR_DPF,1,\
Enables PVR_DPF messages in the kernel mode driver._\
))

ifeq ($(BUILD),debug)
else ifeq ($(SUPPORT_VALIDATION),1)
else
endif

$(eval $(call TunableBothConfigC,PVRSRV_NEED_PVR_ASSERT,,\
Enable this to turn on PVR_ASSERT in release builds._\
))
$(eval $(call TunableBothConfigC,PVRSRV_NEED_PVR_TRACE,,\
Enable this to turn on PVR_TRACE in release builds._\
))
$(eval $(call TunableBothConfigC,PVRSRV_NEED_PVR_STACKTRACE,,\
Enable this to turn on stack trace functionality requiring either native_\
operating system features$(comma) or additional dependencies such as_\
libunwind._\
))
ifneq ($(KERNEL_VERSION),)
ifeq ($(SUPPORT_INTEGRITY_PLATFORM)$(SUPPORT_NEUTRINO_PLATFORM),)
SUPPORT_LINUX_FDINFO_SETTING := $(shell ( ( \
[ $(KERNEL_VERSION) -eq 4 -a $(KERNEL_PATCHLEVEL) -ge 17 -o \
$(KERNEL_VERSION) -ge 5 ] ) && echo 1 || echo 0 ) )
SUPPORT_LINUX_FDINFO:= $(SUPPORT_LINUX_FDINFO_SETTING)
else
SUPPORT_LINUX_FDINFO:= 0
endif
else
SUPPORT_LINUX_FDINFO:= 0
endif
$(eval $(call TunableBothConfigMake,SUPPORT_LINUX_FDINFO,))
$(eval $(call TunableBothConfigC,SUPPORT_LINUX_FDINFO,,))

$(eval $(call TunableKernelConfigMake,PVRSRV_TRACE_ROGUE_EVENTS,1))
$(eval $(call TunableBothConfigC,PVRSRV_TRACE_ROGUE_EVENTS,1,\
When enabled defines set of "rogue" FTrace events that are emitted from_\
various parts of the Server$(comma) including from selected HWPerf events._\
))

$(eval $(call TunableKernelConfigC,PVRSRV_ANDROID_TRACE_GPU_WORK_PERIOD,))
$(eval $(call TunableKernelConfigMake,PVRSRV_ANDROID_TRACE_GPU_WORK_PERIOD,))

$(eval $(call TunableKernelConfigC,PVRSRV_ANDROID_TRACE_GPU_FREQ,))
$(eval $(call TunableKernelConfigMake,PVRSRV_ANDROID_TRACE_GPU_FREQ,))

ifeq ($(PVRSRV_NEED_PVR_STACKTRACE),1)
ifeq ($(SUPPORT_ANDROID_PLATFORM),1)
$(warning Since Android O it's not allowed to link to libunwind.)
endif
endif

# Memtest, currently implemented for Linux only
ifeq ($(PDUMP),1)
$(eval $(call TunableKernelConfigC,SUPPORT_PHYSMEM_TEST,))
$(eval $(call TunableKernelConfigMake,SUPPORT_PHYSMEM_TEST,))
else
$(eval $(call TunableKernelConfigC,SUPPORT_PHYSMEM_TEST,1))
$(eval $(call TunableKernelConfigMake,SUPPORT_PHYSMEM_TEST,1))
endif

ifeq ($(PDUMP),1)
$(eval $(call TunableBothConfigC,PVRSRV_PHYSHEAP_DISABLE_OOM_DEMOTION,1,\
Disable OOM Physheap Reassignment))
$(eval $(call TunableKernelConfigC,PVRSRV_PHYSHEAP_ENABLE_GPUPRIVATE_PROMOTION,,\
Enables Physheap promotion to GPUPRIVATE when a new PMR buffer has no CPU mapping flags.))
else
$(eval $(call TunableBothConfigC,PVRSRV_PHYSHEAP_DISABLE_OOM_DEMOTION,,\
Disable OOM Physheap Reassignment))
$(eval $(call TunableKernelConfigC,PVRSRV_PHYSHEAP_ENABLE_GPUPRIVATE_PROMOTION,1,\
Enables Physheap promotion to GPUPRIVATE when a new PMR buffer has no CPU mapping flags.))
endif

$(eval $(call TunableBothConfigC,REFCOUNT_DEBUG,))
$(eval $(call TunableBothConfigC,DC_DEBUG,,\
Enable debug tracing in the DC (display class) server code))
$(eval $(call TunableKernelConfigC,SCP_DEBUG,,\
Enable debug tracing in the SCP (software command processor)_\
which is used by the DC.))
$(eval $(call TunableBothConfigC,SUPPORT_INSECURE_EXPORT,))
$(eval $(call TunableBothConfigC,SUPPORT_SECURE_EXPORT,,\
Enable support for secure device memory and sync export._\
This replaces export handles with file descriptors$(comma) which can be passed_\
between processes to share memory._\
))
$(eval $(call TunableBothConfigC,SUPPORT_DISPLAY_CLASS,,\
Enable DC (display class) support. Disable if not using a DC display driver.))
$(eval $(call TunableBothConfigC,PVRSRV_DEBUG_CCB_MAX,))

ifeq ($(SUPPORT_DISPLAY_CLASS),1)
override SUPPORT_EXTERNAL_PHYSHEAP_INTERFACE := 1
endif

$(eval $(call TunableKernelConfigC,SUPPORT_EXTERNAL_PHYSHEAP_INTERFACE,,\
Enable the external physheap interface._\
This may be required by some non-DC display drivers._\
The interface is enabled by default for DC display drivers._\
))
$(eval $(call TunableKernelConfigMake,SUPPORT_EXTERNAL_PHYSHEAP_INTERFACE,,))

$(eval $(call TunableBothConfigMake,SUPPORT_TRUSTED_DEVICE,))
$(eval $(call TunableBothConfigC,SUPPORT_TRUSTED_DEVICE,,\
Enable a build mode targeting an REE._\
))

ifeq ($(SUPPORT_TRUSTED_DEVICE),1)
SUPPORT_SECURE_ALLOC_KM ?= 1
ifeq ($(NO_HARDWARE),1)
SUPPORT_SECURITY_VALIDATION ?= 1
endif
endif

$(eval $(call TunableBothConfigC,SUPPORT_SECURITY_VALIDATION,,\
Enable DRM security validation mode._\
))
$(eval $(call TunableBothConfigMake,SUPPORT_SECURITY_VALIDATION,))

$(eval $(call TunableBothConfigC,SUPPORT_SECURE_ALLOC_KM,,\
Add Support for allocating secure memory from KM._\
Adds functions OSAllocateSecBuf/OSFreeSecBuf to KM osfunc.h._\
Only for driver with SUPPORT_TRUSTED_DEVICE=1 enabled._\
Secure allocations from UM may be possible if not supported from KM._\
))

ifeq ($(SUPPORT_SECURE_ALLOC_KM),1)
 ifeq ($(SUPPORT_TRUSTED_DEVICE),)
  $(error SUPPORT_SECURE_ALLOC_KM=1 requires SUPPORT_TRUSTED_DEVICE=1)
 endif
endif

$(eval $(call TunableBothConfigC,SECURE_FW_CODE_OSID,,\
Software workaround for rogue platform with missing fw_code_\
and fw_secure_data signals. Emit specified OSID when the FW_\
fetches code from memory._\
In MIPS this will only work for statically mapped FW code._\
))

ifeq ($(SUPPORT_TRUSTED_DEVICE),1)
override SUPPORT_MIPS_CONTIGUOUS_FW_MEMORY := 1
endif


$(eval $(call TunableBothConfigC,SUPPORT_RGXTQ_BRIDGE,1,\
Enable RGXTQ bridge which is always present on Rogue cores_\
))



$(eval $(call TunableBothConfigC,SUPPORT_MIPS_CONTIGUOUS_FW_MEMORY,,\
Use a single big allocation for the FW code and another one_\
for the FW private data._\
))

$(eval $(call TunableBothConfigC,SUPPORT_MIPS_UNIFIED_FW_MEMORY,,\
Map both MIPS FW code and data in a single MIPS TLB entry. Code and data_\
need to be adjacent in both virtual and physical memory space._\
))

$(eval $(call TunableBothConfigC,METRICS_USE_ARM_COUNTERS,,\
Enable usage of hardware performance counters for metrics on ARM platforms._\
))









# poison values for the Services
$(eval $(call TunableBothConfigC,PVRSRV_POISON_ON_ALLOC_VALUE,0xd9,\
Poison on alloc byte value))
$(eval $(call TunableBothConfigC,PVRSRV_POISON_ON_FREE_VALUE,0x63,\
Poison on free byte value))

$(eval $(call BothConfigMake,SUPPORT_MIPS_16K_PAGE_SIZE,$(SUPPORT_MIPS_16K_PAGE_SIZE),\
Enable this to change the MIPS FW page size to 16K._\
))

$(eval $(call BothConfigMake,SUPPORT_MIPS_64K_PAGE_SIZE,$(SUPPORT_MIPS_64K_PAGE_SIZE),\
Enable this to change the MIPS FW page size to 64K._\
))

#
# GPU virtualization support
#
VMM_TYPE ?= stub
RGX_FW_HEAP_SHIFT ?= 25

ifdef PVRSRV_VZ_NUM_OSID
 # deprecated build option is kept to maintain backwards compatibility
 RGX_NUM_DRIVERS_SUPPORTED ?= $(PVRSRV_VZ_NUM_OSID)
else
 RGX_NUM_DRIVERS_SUPPORTED ?= 1
endif

ifeq ($(RGX_NUM_DRIVERS_SUPPORTED),0)
 override RGX_NUM_DRIVERS_SUPPORTED := 1
endif

# Make RGX_NUM_DRIVERS_SUPPORTED visible to both UM & KM makefiles
$(eval $(call BothConfigMake,RGX_NUM_DRIVERS_SUPPORTED,$(RGX_NUM_DRIVERS_SUPPORTED),))
# Reveal RGX_NUM_DRIVERS_SUPPORTED only to KM code, allowing the firmware makefiles,
# which are part of the UM, to selectively control this symbol so the same DDK
# build can create both native and vz-supported firmware binaries
$(eval $(call KernelConfigC,RGX_NUM_DRIVERS_SUPPORTED,$(RGX_NUM_DRIVERS_SUPPORTED),\
The maximum number of DriverIDs (VMs) supported by the DDK [1 native build : 2+ vz build]))

RGX_HCS_DEFAULT_DEADLINE_MS ?= 0xFFFFFFFFU
$(eval $(call KernelConfigC,RGX_HCS_DEFAULT_DEADLINE_MS,$(RGX_HCS_DEFAULT_DEADLINE_MS),))

ifeq ($(SUPPORT_TRUSTED_DEVICE),1)
  DRIVER0_SECURITY_SUPPORT ?= 1
endif

ifeq ($(shell test $(RGX_NUM_DRIVERS_SUPPORTED) -gt 1; echo $$?),0)
$(eval $(call TunableBothConfigC,RGX_GUEST_MANAGED_GPU_WORK_PERIOD,,\
Vz guest managed GPU work period events support))
endif

$(eval $(call BothConfigC,RGX_FW_HEAP_USES_FIRMWARE_OSID,0,_\
Firmware heaps are accessible via the Firmware's OSID))
$(eval $(call BothConfigC,RGX_FW_HEAP_USES_HOST_OSID,1,_\
Firmware heaps are accessible via the Host Driver's OSID))
$(eval $(call BothConfigC,RGX_FW_HEAP_USES_DEDICATED_OSID,2,_\
Firmware heaps are accessible via a dedicated OSID (= Fw OSID +1)))

RGX_FW_HEAP_OSID_ASSIGNMENT ?= RGX_FW_HEAP_USES_FIRMWARE_OSID

$(eval $(call BothConfigC,RGX_FW_HEAP_OSID_ASSIGNMENT,$(RGX_FW_HEAP_OSID_ASSIGNMENT),\
Configure which OSID space can be used by CPU and GPU to access the Fw Heaps))
$(eval $(call BothConfigMake,RGX_FW_HEAP_OSID_ASSIGNMENT,$(RGX_FW_HEAP_OSID_ASSIGNMENT),))

$(eval $(call AppHintConfigC,PVRSRV_APPHINT_PHYSHEAPMINMEMONCONNECTION,0,\
The minimum free physical memory in MBs required for an application_\
connection request to succeed. The threshold check is disabled when a value of_\
0 is used. The free memory available in the system layer's default heap is checked_\
when this is non-zero))

$(eval $(call TunableKernelConfigC,RGX_FW_PHYSHEAP_MINMEM_ON_CONNECTION, 512,\
The minimum free physical memory in KBs required for an application_\
connection request to succeed. The threshold check is disabled when the value of_\
PVRSRV_APPHINT_PHYSHEAPMINMEMONCONNECTION or this tunable is 0. The free memory_\
available in a devices FW_MAIN heap is checked when the value is non-zero))

$(eval $(call AppHintConfigC,PVRSRV_APPHINT_DRIVERMODE,\"default\",\
Comma separated strings specifying the virtualization modes of the_\
devices controlled by this driver (e.g. default,native,host,guest)))

$(eval $(call KernelConfigMake,VMM_TYPE,$(VMM_TYPE),\
The virtual machine manager type, defaults to stub implementation))

$(eval $(call TunableBothConfigC,RGX_FW_HEAP_SHIFT,$(RGX_FW_HEAP_SHIFT),\
Firmware physical heap log2 size per DriverID (minimum 4MiB, maximum 256MB, default 32MB).))

$(eval $(call AppHintConfigC,PVRSRV_APPHINT_GUESTFWHEAPSTRIDE,(1 << RGX_FW_HEAP_SHIFT),\
Difference between the device physical base addresses of consecutive_\
Guest Firmware heap carveouts (64 bit value). Address stride used only_\
by the Host driver to map the device physical bases of Guest Fw heaps_\
into the Firmware's virtual address space.))

$(eval $(call AppHintConfigC,PVRSRV_APPHINT_AUTOVZGPUPOWERDOWN,IMG_FALSE,\
The Host driver shutdown also powers down the AutoVz Firmware & GPU. _\
By default under AutoVz the GPU continues running regardless of Host Driver.))

ifeq ($(SUPPORT_FIRMWARE_UNITTESTS),1)
# These configs are planned to be off on SC builds, hence the unittests don't test them
override SUPPORT_POWMON_COMPONENT := 0
override SUPPORT_PVR_GPIO := 0
endif

$(eval $(call TunableBothConfigC,SUPPORT_AUTOVZ,,\
Enable support for AutoVz mode_))

ifeq ($(SUPPORT_AUTOVZ),1)
 override RGX_VZ_STATIC_CARVEOUT_FW_HEAPS := 1
 override RGX_PREMAP_FW_HEAPS := 1

 $(eval $(call TunableBothConfigC,SUPPORT_AUTOVZ_HW_REGS,1,\
 Use dedicated hardware registers for tracking OS states otherwise rely on shared memory._))

 $(eval $(call TunableKernelConfigC,PVR_AUTOVZ_WDG_PERIOD_MS,3000,\
 Time period in milliseconds between the firmware autovz watchdog checks._))
endif

$(eval $(call TunableKernelConfigC,RGX_PREMAP_FW_HEAPS,,\
Premap the entire Firmware heap of the Native or Host driver in the Firmware virtual_\
address space during initialisation._))

$(eval $(call TunableKernelConfigMake,RGX_PREMAP_FW_HEAPS,,\
Premap the entire Firmware heap of the Native or Host driver in the Firmware virtual_\
address space during initialisation._))

$(eval $(call TunableBothConfigC,RGX_VZ_STATIC_CARVEOUT_FW_HEAPS,,\
Firmware heaps of Guest VMs are allocated from pre-determined carveout memory.))

RGX_FW_CODE_SECTION_SIZE ?= 0x80000
$(eval $(call BothConfigC,RGX_FW_CODE_SECTION_SIZE,$(RGX_FW_CODE_SECTION_SIZE),))

RGX_FW_DATA_SECTION_SIZE ?= 0x20000
$(eval $(call BothConfigC,RGX_FW_DATA_SECTION_SIZE,$(RGX_FW_DATA_SECTION_SIZE),))

RGX_FW_RODATA_SECTION_SIZE ?= 0x20000
$(eval $(call BothConfigC,RGX_FW_RODATA_SECTION_SIZE,$(RGX_FW_RODATA_SECTION_SIZE),))

RGX_VZ_CONNECTION_TIMEOUT_US ?= 60000000
$(eval $(call KernelConfigC,RGX_VZ_CONNECTION_TIMEOUT_US,$(RGX_VZ_CONNECTION_TIMEOUT_US),\
Period of time in microseconds that a VZ driver will wait on the Firmware to establish_\
a connection before timing out.))

$(eval $(call TunableBothConfigMake,PVR_ENABLE_PHR,,))
$(eval $(call TunableBothConfigC,PVR_ENABLE_PHR,,\
Enable the Periodic Hardware Reset functionality (PHR)))

$(eval $(call TunableBothConfigC,RGX_FW_IRQ_OS_COUNTERS,))
$(eval $(call TunableBothConfigC,RGX_IRQ_HYPERV_HANDLER,))


PVRSRV_MAX_REAL_TIME_CONTEXTS ?= 1
$(eval $(call KernelConfigC,PVRSRV_MAX_REAL_TIME_CONTEXTS,$(PVRSRV_MAX_REAL_TIME_CONTEXTS),))

PVRSRV_DEFAULT_DEADLINE_MS ?= 0xFFFFFFFFU

#
# GPU virtualization validation
#
$(eval $(call TunableBothConfigC,SUPPORT_GPUVIRT_VALIDATION,,\
Enable validation mode for GPU Virtualisation in which processes inside_\
an OS are given independent OSIDs.))

$(eval $(call TunableBothConfigC,GPUVIRT_VALIDATION_NUM_OS,8))

ifeq ($(SUPPORT_GPUVIRT_VALIDATION),1)
 override SUPPORT_GPUVIRT_VALIDATION_MTS := 1
 override SUPPORT_CUSTOM_OSID_EMISSION := 1
endif

$(eval $(call TunableBothConfigC,SUPPORT_GPUVIRT_VALIDATION_MTS,,\
Perform a test on startup that validates the OSID sideband data transmitted through the MTS unit.))

$(eval $(call TunableBothConfigC,SUPPORT_CUSTOM_OSID_EMISSION,,\
Allows overriding the OSID that is configured for GPU workloads.))
$(eval $(call TunableBothConfigMake,SUPPORT_CUSTOM_OSID_EMISSION,,\
Allows overriding the OSID that is configured for GPU workloads.))

# Enable Client CCB grow: VZ, premapped Fw heaps and Neutrino drivers excluded
ifneq ($(SUPPORT_NEUTRINO_PLATFORM), 1)
 ifeq ($(RGX_NUM_DRIVERS_SUPPORTED), 1)
  ifneq ($(RGX_PREMAP_FW_HEAPS),1)
   PVRSRV_ENABLE_CCCB_GROW ?= 1
  endif
 endif
endif

$(eval $(call TunableBothConfigC,PVRSRV_ENABLE_CCCB_GROW,,\
This controls the feature that allows the Services client CCBs to grow_\
when they become full._\
))

$(eval $(call TunableBothConfigC,FIX_DUSTS_POW_ON_INIT,,\
Enable WA for power controllers that power up dusts by default._\
The Firmware powers down the dusts after booting._\
))

$(eval $(call TunableKernelConfigMake,SUPPORT_LINUX_DVFS,,\
Support Linux DVFS.))

$(eval $(call TunableKernelConfigC,SUPPORT_LINUX_DVFS,,\
Enables PVR DVFS implementation to actively change frequency / voltage depending_\
on current GPU load. Currently only supported on Linux._\
))

$(eval $(call TunableKernelConfigMake,SUPPORT_PVR_DVFS_GOVERNOR,,\
Support Linux DVFS custom governor.))

$(eval $(call TunableKernelConfigC,SUPPORT_PVR_DVFS_GOVERNOR,,\
Enables PVR DVFS governor. Currently only supported on Linux._\
))

$(eval $(call TunableKernelConfigC,SUPPORT_DVFS_RUNTIME_CONFIG,,\
Enables PVR DVFS sysfs-based runtime configuration. Currently only supported on Linux._\
))

$(eval $(call TunableBothConfigC,SUPPORT_PDVFS_HEADROOM_EXT,,\
Enables PVR DVFS capacity headroom extension. Currently only supported on Linux._\
))

$(eval $(call TunableBothConfigC,SUPPORT_PDVFS_POLLINT_EXT,,\
Enables PVR DVFS polling interval extension. Currently only supported on Linux._\
))

#
# GPU power monitoring configuration
#

$(eval $(call TunableBothConfigMake,SUPPORT_POWMON_COMPONENT,1))
$(eval $(call TunableBothConfigC,SUPPORT_POWMON_COMPONENT,1,\
Includes power-monitoring component in firmware build._\
))

$(eval $(call TunableKernelConfigC,SUPPORT_LMA_SUSPEND_TO_RAM,,\
Enables additional argument to PVRSRVSetDevicePowerStateKM() that allows_\
passing information if the current power state change requires preserving_\
Video RAM in System RAM._\
))

ifeq ($(SUPPORT_POWMON_COMPONENT),0)
# Force disable power-sampling if powmon component not being compiled in
 override SUPPORT_POWER_SAMPLING_VIA_DEBUGFS := 0
endif

ifneq ($(SUPPORT_POWMON_COMPONENT),0)
# Following tunables are only used when power-monitoring present
$(eval $(call TunableBothConfigC,PVR_POWER_ACTOR,,\
Enables PVR power actor implementation for registration with a kernel configured_\
with IPA. Enables power counter measurement timer in the FW which is periodically_\
read by the host DVFS from the POWER_ESTIMATE register in order to operate within_\
a governor set power envelope.))
$(eval $(call TunableBothConfigC,PVR_POWER_ACTOR_MEASUREMENT_PERIOD_MS,10U,\
Period of time between regular power measurements. Default 10ms))
$(eval $(call BothConfigC,PVR_POWER_MONITOR_HWPERF,,\
Enables the generation of hwperf power monitoring packets._\
This incurs an additional performance cost.))
$(eval $(call TunableBothConfigC,PVR_POWER_MONITOR_DYNAMIC_ENERGY,,\
Configures the power monitoring module to calculate dynamic energy_\
instead of the default total power.))
$(eval $(call TunableBothConfigC,PVR_POWER_ACTOR_SCALING,,\
Scaling factor for the dynamic power coefficients.))
$(eval $(call TunableBothConfigC,SUPPORT_POWER_SAMPLING_VIA_DEBUGFS,,\
Enable sampling of power counter registers and expose the values via DebugFS power_data file.))
endif


ifneq ($(PVR_POWER_ACTOR),)


else


endif

$(eval $(call TunableKernelConfigC,DEBUG_HANDLEALLOC_INFO_KM,))
$(eval $(call TunableKernelConfigC,PVRSRV_RESET_ON_HWTIMEOUT,))
$(eval $(call TunableKernelConfigC,PVR_LDM_PLATFORM_PRE_REGISTERED,))
$(eval $(call TunableKernelConfigC,PVR_LDM_DRIVER_REGISTRATION_NAME,"\"$(PVRSRV_MODNAME)\""))
$(eval $(call TunableBothConfigC,PVRSRV_ENABLE_SYNC_POISONING,,\
Poison Sync Prim values on free.))
$(eval $(call TunableBothConfigC,PVRSRV_FULL_SYNC_TRACKING_HISTORY_LEN,256))
$(eval $(call TunableKernelConfigC,SYNC_DEBUG,))
$(eval $(call TunableKernelConfigC,DEBUG_OVERRIDE_PWRLOCK,))
$(eval $(call TunableKernelConfigC,SUPPORT_DUMP_CLIENT_CCB_COMMANDS,))
$(eval $(call TunableKernelConfigC,SUPPORT_MMU_PAGESIZECONFIG_REFCOUNT,))

MMU_PT_ALLOC_MULTIPLIER ?= 1
$(eval $(call CheckValueInRange,MMU_PT_ALLOC_MULTIPLIER,1,16))
$(eval $(call BothConfigC,MMU_PT_ALLOC_MULTIPLIER,$(MMU_PT_ALLOC_MULTIPLIER),\
Multiplier passed to MMU PT allocation RA. Can reduce latency for large allocations._\
))

# Disable DDK features when PDUMP is defined
#
ifeq ($(PDUMP),1)
# Increase the default max annotation length when PDump is enabled
override PVR_ANNOTATION_MAX_LEN ?= 127
endif

$(eval $(call TunableKernelConfigC,SUPPORT_DC_COMPLETE_TIMEOUT_DEBUG,))

$(eval $(call TunableBothConfigC,SUPPORT_PVR_VALGRIND,))

ifeq ($(MESA_ZINK_COMMON),1)
  $(warning ******************************************************)
  $(warning WARNING: You have enabled zink on a rogue core.)
  $(warning This is not a supported configuration and is not)
  $(warning covered by any support and maintenance agreement.)
  $(warning Performance and functionality may vary.)
  $(warning ******************************************************)
 ifeq ($(filter $(WINDOW_SYSTEM),xorg wayland)),)
  # Zink currently only supports xorg and wayland
  $(error Zink can only be enabled with xorg or wayland window systems.)
 endif
 ifneq ($(filter vulkan,$(EXCLUDED_APIS)),)
  $(error Zink requires vulkan to function.)
 endif
 ifneq ($(filter opengles3,$(EXCLUDED_APIS)),)
  $(error Zink requires native GLES3 for xorg server/wayland compositor.)
 endif
endif

$(eval $(call TunableBothConfigC,ION_DEFAULT_HEAP_NAME,\"ion_system_heap\",\
In ion enabled DDKs$(comma) this setting should be the default heap name defined in the kernel_\
where gralloc buffers are allocated by default._\
This setting is for kernels (>=4.12) which support ION heap query_\
))
$(eval $(call TunableBothConfigC,ION_DEFAULT_HEAP_ID_MASK,(1 << ION_HEAP_TYPE_SYSTEM),\
In ion enabled DDKs$(comma) this setting should be (1 << ION_HEAP_TYPE_xxx)_\
where ION_HEAP_TYPE_xxx is default heap id defined in the kernel._\
This setting is for kernels (<4.12) which do not support ION heap query_\
))
$(eval $(call TunableBothConfigC,ION_FALLBACK_HEAP_NAME,,\
In ion enabled DDKs$(comma) use this setting to define fallback heap._\
This setting is optional (depends if kernel has defined a fallback heap)_\
))
$(eval $(call TunableBothConfigC,ION_FALLBACK_HEAP_ID_MASK,,\
In ion enabled DDKs$(comma) use this setting to define fallback heap id mask._\
This setting is optional (depends if kernel has defined a fallback heap)_\
))

EGL_EXTENSION_KHR_GL_COLORSPACE ?= 1


# The EGL EXT_image_gl_colorspace spec says:
#    "Can be supported on EGL 1.4 provided that EGL_KHR_gl_colorspace is
#     implemented, as well as either EGL_KHR_image or EGL_KHR_image_base."
#
# Note: IMG EGL supports EGL_KHR_image and EGL_KHR_image_base unconditionally.
ifeq ($(EGL_EXTENSION_KHR_GL_COLORSPACE),1)
endif


ifneq ($(MESA_EGL),1)

 # Check for GBM_BACKENDs that aren't understood by the GBM Linux.mk.
 $(eval $(call ValidateValues,GBM_BACKEND,$(_supported_gbm_backends)))

endif


$(eval $(call TunableBothConfigC,PVRSRV_DEVMEM_TEST_SAFE_MEMSETCPY,,\
Enable this to force the use of PVRSRVMemSet/Copy in the client driver _\
instead of the built-in libc functions. These implementations are device _\
memory safe and are used by default on AARCH64 platform._\
))

$(eval $(call TunableBothConfigC,PVRSRV_BRIDGE_LOGGING,,\
If enabled$(comma) provides a debugfs entry which logs the number of calls_\
made to each bridge function._\
))

$(eval $(call TunableKernelConfigC,PVRSRV_SERVER_THREADS_INDEFINITE_SLEEP,,\
If enabled it will make kernel threads to sleep indefinitely until signalled._\
))

# If we are building against a ChromeOS kernel, set this.
$(eval $(call TunableKernelConfigC,CHROMIUMOS_KERNEL,))
$(eval $(call TunableKernelConfigMake,CHROMIUMOS_KERNEL,))




ifneq ($(SUPPORT_ANDROID_PLATFORM),1)
endif


DEFERRED_WORKER_THREAD ?= 1


$(eval $(call TunableKernelConfigC,CACHEFLUSH_NO_KMRBF_USING_UMVA,))
$(eval $(call TunableBothConfigC,CACHEFLUSH_ISA_TYPE,,\
Specify CPU d-cache maintenance ISA type (i.e. CACHEFLUSH_ISA_TYPE_[X86,ARM64,GENERIC])._\
))

# Overrides the size of the Vulkan host-visible heap with the supplied size in MB

ifneq ($(BUILD),release)
ZEUS_SUPPORT_RENDER_INFO ?= 1
ZEUS_SHADER_ANALYSIS ?= 1
endif






# Support version 7 of the loader. Versions 0-6 should not be used.
# Default needs to be set separately otherwise 0 gets replaced with the default
SUPPORT_LUNARG_LOADER_VERSION ?= 7


ifeq ($(SUPPORT_VKEXT_IMAGE_FORMAT_MOD),1)
endif

ifneq ($(SUPPORT_ANDROID_PLATFORM),1)
ifeq ($(WINDOW_SYSTEM),lws-generic)
# Check for SUPPORT_VK_PLATFORMS that aren't understood by the Vulkan Linux.mk.
# Platform names match Mesa where possible.
_supported_vk_platforms := headless null wayland x11
$(eval $(call ValidateValues,SUPPORT_VK_PLATFORMS,$(_supported_vk_platforms)))

else
endif

ifneq ($(SUPPORT_VK_PLATFORMS),)
endif
endif

$(eval $(call TunableBothConfigC,SUPPORT_SOC_TIMER,,\
Enable the use of the SoC timer. When enabled the SoC system layer must implement the pfnSoCTimerRead_\
callback that when invoked returns the current value of the SoC timer._\
))

ifeq ($(SUPPORT_SOC_TIMER),1)
ifneq ($(filter target_arm% target_aarch%,$(TARGET_PRIMARY_ARCH)),)
$(eval $(call TunableKernelConfigC,SUPPORT_ARM_ARCH_TIMER,1,\
Use the ARM arch timer helpers to enable SoC timer support. This registers a_\
default implementation of the pfnSoCTimerRead callback that when invoked_\
returns the current binary value of the SoC timer._\
))
endif
endif

ifeq ($(PVR_BLOB_CACHE_DEBUG),1)
$(eval $(call BothConfigC,BLOB_CACHE_DEBUG,))
endif


$(eval $(call TunableBothConfigMake,PDUMP,))
$(eval $(call TunableBothConfigMake,SUPPORT_INSECURE_EXPORT,))
$(eval $(call TunableBothConfigMake,SUPPORT_SECURE_EXPORT,))
$(eval $(call TunableBothConfigMake,SUPPORT_DISPLAY_CLASS,))
ifeq ($(SUPPORT_META_COREMEM),1)

 ifeq ($(SUPPORT_FW_COREMEM_OPTIMISATION),1)
  ifeq ($(SUPPORT_RISCV_FIRMWARE),1)
  else
  endif
 endif
endif
$(eval $(call TunableBothConfigMake,CLDNN,,\
Build CLDNN graph libraries._\
))
$(eval $(call TunableBothConfigC,SUPPORT_FW_VIEW_EXTRA_DEBUG,,\
Enable extra debug information using the META Slave Port or RISC-V Debug Module._\
Checks the validity of the Firmware code and dumps sync values_\
using the GPU memory subsystem via the META Slave Port or RISC-V Debug Module._\
))
$(eval $(call TunableBothConfigC,SUPPORT_RISCV_GDB,,\
Enable debugfs entry used to attach GDB to the RISC-V Firmware._\
))
$(eval $(call TunableBothConfigC,TRACK_FW_BOOT,,Enable FW boot tracking.))
# Required to pass the build flag to the META FW makefile
$(eval $(call TunableBothConfigC,SUPPORT_FASTRENDER_DM,))
$(eval $(call TunableBothConfigC,SUPPORT_TDM_DEBUG,,\
Enable TDM control stream log in FW trace._\
))

$(eval $(call TunableBothConfigMake,OPTIM,,\
Specify the optimisation flags passed to the compiler. Normally this_\
is autoconfigured based on the build type._\
))













# Enables the pre-compiled header use.

# Switch among glsl frontend compiler variants

RGX_SECONDARY_OS_CLOCK_SOURCE ?= sched
$(eval $(call TunableKernelConfigMake,RGX_SECONDARY_OS_CLOCK_SOURCE,sched,\
Configurable OS clock source used in GPU/OS time domain correlation module._\
Used to calculate timestamps embedded within a FTrace event.))

ifeq ($(RGX_SECONDARY_OS_CLOCK_SOURCE),mono)
PVRSRV_APPHINT_SECONDARYOSCLOCKSOURCE=0
else ifeq ($(RGX_SECONDARY_OS_CLOCK_SOURCE),mono_raw)
PVRSRV_APPHINT_SECONDARYOSCLOCKSOURCE=1
else ifeq ($(RGX_SECONDARY_OS_CLOCK_SOURCE),sched)
PVRSRV_APPHINT_SECONDARYOSCLOCKSOURCE=2
else
$(error Wrong value ($(RGX_SECONDARY_OS_CLOCK_SOURCE)) for RGX_SECONDARY_OS_CLOCK_SOURCE)
endif

# HWR is enabled by default
ASSERTONHWRTRIGGER_DEFAULT_ENABLED ?= 0
$(eval $(call TunableBothConfigC,ASSERTONHWRTRIGGER_DEFAULT_ENABLED,))

# Build-only AppHint configuration values
$(eval $(call AppHintConfigC,PVRSRV_APPHINT_HWRDEBUGDUMPLIMIT,APPHNT_BLDVAR_DBGDUMPLIMIT,\
Limit for the number of HWR debug dumps produced))
$(eval $(call AppHintConfigC,PVRSRV_APPHINT_ENABLETRUSTEDDEVICEACECONFIG,IMG_FALSE,\
Enable trusted device ACE config))
$(eval $(call AppHintConfigC,PVRSRV_APPHINT_GENERALNON4KHEAPPAGESIZE,0x4000,\
Alternate general heap page size (i.e. 4K,16K [default],64K,256K,1M,2M)))
$(eval $(call AppHintConfigC,PVRSRV_APPHINT_HWPERFCLIENTBUFFERSIZE,786432,\
Buffer size in bytes for client HWPerf streams))

# PDUMP AppHint defaults
$(eval $(call AppHintConfigC,PVRSRV_APPHINT_ENABLESIGNATURECHECKS,APPHNT_BLDVAR_ENABLESIGNATURECHECKS,\
Enable storing of signature check data in PDUMPs))
$(eval $(call AppHintConfigC,PVRSRV_APPHINT_SIGNATURECHECKSBUFSIZE,RGXFW_SIG_BUFFER_SIZE_MIN,\
Buffer size in bytes for storing signature check data))

$(eval $(call AppHintConfigC,PVRSRV_APPHINT_ENABLEFULLSYNCTRACKING,IMG_FALSE,\
Enable full sync tracking))
$(eval $(call AppHintConfigC,PVRSRV_APPHINT_ENABLEPAGEFAULTDEBUG,APPHNT_BLDVAR_ENABLEPAGEFAULTDEBUG,\
Enable page fault debug))

# Validation AppHint defaults
$(eval $(call AppHintConfigC,PVRSRV_APPHINT_VALIDATEIRQ,0,\
Used to validate the interrupt integration. \
Enables extra code in the FW to assert all interrupt lines \
at boot and polls on the host side. The code is only built when \
generating pdumps for nohw targets.))

$(eval $(call AppHintConfigC,PVRSRV_APPHINT_DISABLECLOCKGATING,0,\
Disable GPU clock gating))
$(eval $(call AppHintConfigC,PVRSRV_APPHINT_DISABLEDMOVERLAP,0,\
Disable GPU data master overlapping))

$(eval $(call AppHintConfigC,PVRSRV_APPHINT_ENABLECDMKILLINGRANDMODE,0,\
Enable random killing of the compute data master))
$(eval $(call AppHintConfigC,PVRSRV_APPHINT_ENABLERANDOMCONTEXTSWITCH,0,\
Enable random context switching of all DMs for debug and testing purposes))
$(eval $(call AppHintConfigC,PVRSRV_APPHINT_ENABLESOFTRESETCONTEXTSWITCH,0,\
Enable soft GPU resets on context switching))
$(eval $(call AppHintConfigC,PVRSRV_APPHINT_ENABLEFWCONTEXTSWITCH,RGXFWIF_INICFG_OS_CTXSWITCH_DM_ALL,\
Enable firmware context switching))
$(eval $(call AppHintConfigC,PVRSRV_APPHINT_ENABLERDPOWERISLAND,RGX_RD_POWER_ISLAND_DEFAULT,\
Enable RD power island))
$(eval $(call AppHintConfigC,PVRSRV_APPHINT_ENABLESPUCLOCKGATING,IMG_FALSE,\
Enable SPU clock gating))

$(eval $(call AppHintConfigC,PVRSRV_APPHINT_FIRMWAREPERF,FW_PERF_CONF_NONE,\
Force the initial Firmware Performance Configuration to the specified value))
$(eval $(call AppHintConfigC,PVRSRV_APPHINT_FWCONTEXTSWITCHPROFILE,RGXFWIF_CTXSWITCH_PROFILE_MEDIUM_EN,\
Firmware context switch profile))
$(eval $(call AppHintConfigC,PVRSRV_APPHINT_HWPERFDISABLECUSTOMCOUNTERFILTER,0,\
Force the initial HW Performance Custom Counter Filter value))
$(eval $(call AppHintConfigC,PVRSRV_APPHINT_HWPERFFWBUFSIZEINKB,2048,\
Buffer size in KB of the hardware performance GPU buffer))
$(eval $(call AppHintConfigC,PVRSRV_APPHINT_HWPERFHOSTBUFSIZEINKB,2048,\
Buffer size in KB of the hardware performance host buffer))
$(eval $(call AppHintConfigC,PVRSRV_APPHINT_HWPERFHOSTTHREADTIMEOUTINMS,50,\
Timeout in milliseconds of the hardware performance host thread))

$(eval $(call AppHintConfigC,PVRSRV_APPHINT_TFBCCOMPRESSIONCONTROLGROUP,1,\
Override default TFBC compression control group if supported \
(0) Group 0: 25%/50%/75% lossy modes \
(1) Group 1: 25%/37.5%/75% lossy modes))

$(eval $(call AppHintConfigC,PVRSRV_APPHINT_TFBCCOMPRESSIONCONTROLSCHEME,0,\
Override default TFBC compression scheme if supported \
(0) All compression schemes enabled \
(1) Delta standard and correlation \
(2) Delta standard only))

$(eval $(call AppHintConfigC,PVRSRV_APPHINT_TFBCVERSION,0,\
Downgrade the TFBC version the GPU hardware is configured to run with \
(0) Use default from RGX_FEATURE_TFBC_VERSION \
(10) Use TFBC_VERSION 1.0 \
(11) Use TFBC_VERSION 1.1))

$(eval $(call AppHintConfigC,PVRSRV_APPHINT_NEWFILTERINGMODE,1,\
Enable new TPU filtering mode))
$(eval $(call AppHintConfigC,PVRSRV_APPHINT_TRUNCATEMODE,0,\
Truncate mode))
$(eval $(call AppHintConfigC,PVRSRV_APPHINT_EMUMAXFREQ,0,\
Set the maximum frequency for the emulator))
$(eval $(call AppHintConfigC,PVRSRV_APPHINT_GPIOVALIDATIONMODE,0,\
Set the validation type for GPIO 1 for the standard protocol validation\
2 for the address protocol validation))
$(eval $(call AppHintConfigC,PVRSRV_APPHINT_RGXBVNC,\"\",\
Array of comma separated strings that define BVNC info of the devices.\
(module parameter usage is RGXBVNC=x.x.x.x,y.y.y.y etc)))

# Build-only AppHint configuration values
$(eval $(call AppHintConfigC,PVRSRV_APPHINT_CLEANUPTHREADPRIORITY,5,\
Set the priority of the cleanup thread (0 - default, 1 - highest, 5 - lowest)))
$(eval $(call AppHintConfigC,PVRSRV_APPHINT_WATCHDOGTHREADPRIORITY,0,\
Set the priority of the watchdog thread (0 - default, 1 - highest, 5 - lowest)))
$(eval $(call AppHintConfigC,PVRSRV_APPHINT_CACHEOPTHREADPRIORITY,1,\
Set the priority of the pvrcache_ops thread (0 - default, 1 - highest, 5 - lowest)))
$(eval $(call AppHintConfigC,PVRSRV_APPHINT_DEVMEM_HISTORY_BUFSIZE_LOG2,11,\
Adjust Devmemhistory CCB size in KB((11 - default, 18 - highest, 5 - lowest))))
$(eval $(call AppHintConfigC,PVRSRV_APPHINT_DEVMEM_HISTORY_MAX_ENTRIES,10000,\
Adjust Devmemhistory max entries((10000 - default, 250000 - highest, 5000 - lowest))))

# Debugfs AppHint configuration values
$(eval $(call AppHintConfigC,PVRSRV_APPHINT_ASSERTONHWRTRIGGER,IMG_FALSE,\
Enable firmware assert when an HWR event is triggered))
$(eval $(call AppHintConfigC,PVRSRV_APPHINT_ASSERTOUTOFMEMORY,IMG_FALSE,\
Enable firmware assert when the TA raises out-of-memory))
$(eval $(call AppHintConfigC,PVRSRV_APPHINT_CHECKMLIST,APPHNT_BLDVAR_DEBUG,\
Enable firmware MLIST consistency checker))
$(eval $(call AppHintConfigC,PVRSRV_APPHINT_DISABLEFEDLOGGING,IMG_FALSE,\
Disable fatal error detection debug dumps))
$(eval $(call AppHintConfigC,PVRSRV_APPHINT_KCCB_SIZE_LOG2,10,\
Defines the number of commands that the KMD->FW command queue can hold before buffering elsewhere (10 - default, 16 - highest, 4 - lowest)))

$(eval $(call AppHintConfigC,PVRSRV_APPHINT_ENABLEHTBLOGGROUP,0,\
Enable host trace log groups))

ifeq ($(RGX_NUM_DRIVERS_SUPPORTED),1)
 DEFAULT_FW_LOG_TYPE := RGXFWIF_LOG_TYPE_NONE
else
 # virtualization builds have the vz fw trace category enabled by default
 DEFAULT_FW_LOG_TYPE := RGXFWIF_LOG_TYPE_GROUP_VZ
endif

$(eval $(call AppHintFlagsConfigC,PVRSRV_APPHINT_ENABLELOGGROUP,$(DEFAULT_FW_LOG_TYPE),\
RGXFWIF_LOG_TYPE_GROUP_,BIF CLEANUP CSW DEBUG DMA HWP HWR MAIN MTS PM POW RPM RTD SPM VZ SAFETY VERBOSE CUSTOMER MISC,\
Enable firmware trace log groups))
$(eval $(call AppHintConfigC,PVRSRV_APPHINT_FIRMWARELOGTYPE,0,\
Specify output mechanism for firmware log data. 0 = TRACE and 1 = TBI))
$(eval $(call AppHintConfigC,PVRSRV_APPHINT_FWTRACEBUFSIZEINDWORDS,$\
RGXFW_TRACE_BUF_DEFAULT_SIZE_IN_DWORDS,Buffer size in DWords for FW trace log data))

$(eval $(call AppHintConfigC,PVRSRV_APPHINT_DEBUGDUMPFWTLOGTYPE,1,\
Specify output mechanism for firmware trace in debug dumps.\
(0) No firmware trace \
(1) Binary format trace \
(2) Full decoded trace \
(3) Partial decoded trace))

$(eval $(call AppHintConfigC,PVRSRV_APPHINT_ENABLEIDLECYCLESTEALING,0,\
Enable Idle Cycle Stealing protection mechanism))

$(eval $(call AppHintConfigC,PVRSRV_APPHINT_FAULTDETECTIONTIMEINTERVAL_USEC,40000,\
Value of the Fault Detection Time Interval for Idle Cycle Stealing ))

$(eval $(call AppHintConfigC,PVRSRV_APPHINT_ICSTIMEINTERVAL_THRESHOLD,90,\
Value of the Idle Cycle Stealing Time Interval Threshold for Idle Cycle Stealing ))

$(eval $(call AppHintConfigC,PVRSRV_APPHINT_FBCDCVERSIONOVERRIDE,0,\
Override system layer FBCDC version settings \
(0) No override \
(1) Force v3 \
(2) Force v3.1))

$(eval $(call AppHintConfigC,PVRSRV_APPHINT_HTBOPERATIONMODE,HTB_OPMODE_DROPOLDEST,\
Configure host trace buffer behaviour))
$(eval $(call AppHintConfigC,PVRSRV_APPHINT_HTBUFFERSIZE,64,\
Buffer size in Kbytes for Host Trace log data))
$(eval $(call AppHintConfigC,PVRSRV_APPHINT_ENABLEFTRACEGPU,IMG_FALSE,\
Enables generation of GPU FTrace events))
$(eval $(call AppHintConfigC,PVRSRV_APPHINT_HWPERFFWFILTER,0,\
Mask used to select GPU events to log for performance))
$(eval $(call AppHintConfigC,PVRSRV_APPHINT_HWPERFHOSTFILTER,0,\
Mask used to select host events to log for performance))
$(eval $(call AppHintConfigC,PVRSRV_APPHINT_HWPERFCLIENTFILTER_SERVICES,0,\
Mask used to select client Services events to log for performance))
$(eval $(call AppHintConfigC,PVRSRV_APPHINT_HWPERFCLIENTFILTER_EGL,0,\
Mask used to select client EGL events to log for performance))
$(eval $(call AppHintConfigC,PVRSRV_APPHINT_HWPERFCLIENTFILTER_OPENGLES,0,\
Mask used to select client OpenGLES events to log for performance))
$(eval $(call AppHintConfigC,PVRSRV_APPHINT_HWPERFCLIENTFILTER_OPENCL,0,\
Mask used to select client OpenCL events to log for performance))
$(eval $(call AppHintConfigC,PVRSRV_APPHINT_HWPERFCLIENTFILTER_VULKAN,0,\
Mask used to select client Vulkan events to log for performance))
$(eval $(call AppHintConfigC,PVRSRV_APPHINT_HWPERFCLIENTFILTER_OPENGL,0,\
Mask used to select client OpenGL events to log for performance))
$(eval $(call AppHintConfigC,PVRSRV_APPHINT_SECONDARYOSCLOCKSOURCE,2,\
Configurable OS clock source used in GPU/OS time domain correlation module._\
Used to calculate timestamps embedded within a FTrace event$(comma) defaults_\
to sched.))
$(eval $(call AppHintConfigC,PVRSRV_APPHINT_ENABLEFWPOISONONFREE,IMG_FALSE,\
Enables poisoning of firmware allocations when freed))
$(eval $(call AppHintConfigC,PVRSRV_APPHINT_FWPOISONONFREEVALUE,0xBD,\
Poison value when PVRSRV_APPHINT_ENABLEFWPOISONONFREE is enabled))

$(eval $(call AppHintConfigC,PVRSRV_APPHINT_ZEROFREELIST,IMG_FALSE,\
Zero freelist memory during freelist reconstruction as part of HWR))

$(eval $(call AppHintConfigC,PVRSRV_APPHINT_GPUUNITSPOWERCHANGE,IMG_FALSE,\
Setting this to '1' enables a test mode to dynamically change the_\
DUSTs powered before each kick to the FW))
$(eval $(call AppHintConfigC,PVRSRV_APPHINT_DISABLEPDUMPPANIC,IMG_FALSE,\
Disable PDUMP panic))
$(eval $(call AppHintConfigC,PVRSRV_APPHINT_CACHEOPCONFIG,0,\
CPU d-cache maintenance framework <CacheOp> flush type configuration))
$(eval $(call AppHintConfigC,PVRSRV_APPHINT_CACHEOPUMKMHRESHOLDSIZE,0,\
CPU d-cache maintenance framework <CacheOp> UM/KM threshold configuration))
$(eval $(call AppHintConfigC,PVRSRV_APPHINT_IGNOREHWREPORTEDBVNC,IMG_FALSE,\
Ignore BVNC reported by HW and use the value specified at build time))
$(eval $(call AppHintConfigC,PVRSRV_APPHINT_PHYSMEMTESTPASSES,$\
APPHNT_PHYSMEMTEST_ENABLE,Set number of passes of driver start time MemTest))

$(eval $(call AppHintConfigC,PVRSRV_APPHINT_TESTSLRINTERVAL,0,\
Interval which determines after how many 3D kicks the driver will_\
insert an additional unsignalled sync checkpoint to the 3D fence_\
allowing testing of SLR))

$(eval $(call AppHintConfigC,PVRSRV_APPHINT_RISCVDMITEST,0,\
Enable RISC-V FW DMI test))

$(eval $(call AppHintConfigC,PVRSRV_APPHINT_VALIDATESOCUSCTIMERS,0,\
Used to validate SOC and USC timer integration. \
Enables extra code in the kernel driver and FW to check that these \
timers increase after each TA and 3D kick. The code is built both \
when generating Pdumps for NOHW targets and as a driver live test.))

$(eval $(call AppHintConfigC,PVRSRV_APPHINT_CHECKPOINTPOOLMAXLOG2,8,\
Used to specify the Log2 size of the sync checkpoint pool. \
The sync checkpoint pool reduces the time take to allocate a sync \
checkpoint. Freed sync checkpoints are returned to the pool if there \
is room.))

$(eval $(call AppHintConfigC,PVRSRV_APPHINT_CHECKPOINTPOOLINITLOG2,7,\
Used to pre-populate the sync checkpoint pool. The pool is initially \
empty unless this Log2 value is > 0.))

# GLSL compiler options
ifeq ($(BUILD),debug)
DUMP_LOGFILES ?= 1
endif
# end of GLSL compiler options


$(eval $(call TunableBothConfigC,SUPPORT_AXI_ACE_TEST,,\
Enable this to add extra FW code for the AXI ACE unittest._\
))


TQ_CAPTURE_PARAMS ?= 1

TQ_DISABLE_SPARSE ?= 0

$(eval $(call TunableBothConfigC,RGXFW_DEBUG_LOG_GROUP,,\
Enable the usage of DEBUG log group in the Firmware logs._\
))


#
# OCL internal memory test support.
#
ifeq ($(SUPPORT_VALIDATION),1)
endif

#
# Tile Lifetime tracking support.
#
ifeq ($(SUPPORT_COMPUTE_ONLY),)
ifeq ($(SUPPORT_VALIDATION),1)
SUPPORT_TLT_PERF ?= 1
endif
endif

$(eval $(call TunableBothConfigMake,SUPPORT_TLT_PERF,,\
Enables render profiling data at a tile granularity when supported_\
by the GPU.))
$(eval $(call TunableBothConfigC,SUPPORT_TLT_PERF,))

#
# Strip Rendering support.
#
$(eval $(call TunableBothConfigMake,SUPPORT_STRIP_RENDERING,,\
Enabling this feature provides the ability for the firmware to drive the_\
display controller via GPIO and support Strip Rendering._\
))
$(eval $(call TunableBothConfigC,SUPPORT_STRIP_RENDERING,))

$(eval $(call TunableBothConfigMake,SUPPORT_WGP,,\
Enables Safe Compute workgroup protection._\
))
$(eval $(call TunableBothConfigC,SUPPORT_WGP,))

$(eval $(call TunableBothConfigMake,SUPPORT_ECC_RAMS,,\
Support ECC RAMs when ECC_RAMS >= 1._\
))
$(eval $(call TunableBothConfigC,SUPPORT_ECC_RAMS,))

#
# Ensure top-level PDVFS build defines are set correctly
#
ifeq ($(SUPPORT_PDVFS),1)
SUPPORT_WORKLOAD_ESTIMATION ?= 1
endif

#
# Ensure PDVFS comms. protocol is compatible with RGX GPIO mode
#
ifneq ($(PDVFS_COM),)
ifneq ($(PDVFS_COM),PDVFS_COM_HOST)
SUPPORT_PVR_GPIO ?= 1
# Disable power monitoring request over GPIO
SUPPORT_POWMON_COMPONENT ?= 0
DISABLE_GPU_FREQUENCY_CALIBRATION ?= 1
endif
endif

ifeq ($(SUPPORT_PDVFS),1)
$(eval $(call TunableBothConfigMake,SUPPORT_PDVFS,1,\
Enabling this feature enables proactive dvfs in the firmware._\
))
$(eval $(call TunableBothConfigC,SUPPORT_PDVFS,1))

$(eval $(call TunableBothConfigC,SUPPORT_PDVFS_IDLE,1,\
This enables idle management in PDVFS._\
))

$(eval $(call TunableKernelConfigC,SUPPORT_PDVFS_DEVFREQ,,\
Enables the Linux devfreq wrapper/syfs interface to the firmware-based DVFS._\
))

$(eval $(call TunableBothConfigC,SUPPORT_PDVFS_SIMPLEONDEMAND,,\
Enables reactive firmware DVFS via a simpleondemand governor._\
))


ifeq ($(BUILD),debug)
endif
endif

ifeq ($(SUPPORT_WORKLOAD_ESTIMATION),1)
$(eval $(call BothConfigMake,SUPPORT_WORKLOAD_ESTIMATION,1,\
Enabling this feature enables workload intensity estimation from a workload's_\
characteristics and assigning a deadline to it._\
))
$(eval $(call BothConfigC,SUPPORT_WORKLOAD_ESTIMATION,1))

ifeq ($(BUILD),debug)
endif
endif

#
# These specify how PDVFS OPP values are sent by the firmware
#
$(eval $(call BothConfigMake,PDVFS_COM_HOST,1,\
Enables host shared-memory protocol._\
))
$(eval $(call BothConfigC,PDVFS_COM_HOST,1))

$(eval $(call BothConfigMake,PDVFS_COM_AP,2,\
Enables GPIO address protocol._\
))
$(eval $(call BothConfigC,PDVFS_COM_AP,2))

$(eval $(call BothConfigMake,PDVFS_COM_PMC,3,\
Enables GPIO power management controller protocol._\
))
$(eval $(call BothConfigC,PDVFS_COM_PMC,3))

$(eval $(call BothConfigMake,PDVFS_COM_IMG_CLKDIV,4,\
Enables GPIO clock divider control protocol._\
))
$(eval $(call BothConfigC,PDVFS_COM_IMG_CLKDIV,4))

$(eval $(call BothConfigMake,PDVFS_COM_SYSREG,5,\
Enables custom system register control. Not supported on Rogue._\
))
$(eval $(call BothConfigC,PDVFS_COM_SYSREG,5))

ifeq ($(SUPPORT_STRIP_RENDERING),1)
PDVFS_COM ?= PDVFS_COM_AP
else
PDVFS_COM ?= PDVFS_COM_HOST
endif

$(eval $(call BothConfigMake,PDVFS_COM,$(PDVFS_COM)))
$(eval $(call BothConfigC,PDVFS_COM,$(PDVFS_COM)))

#
# Enable FW-host clock change notification/request
#
ifeq ($(SUPPORT_PDVFS),1)
SUPPORT_FW_CORE_CLK_RATE_CHANGE_NOTIFY := 1
endif

$(eval $(call TunableBothConfigMake,SUPPORT_FW_CORE_CLK_RATE_CHANGE_NOTIFY,1,\
Enables external power/thermal controller to signal GPU clock rate change. \
))
$(eval $(call TunableBothConfigC,SUPPORT_FW_CORE_CLK_RATE_CHANGE_NOTIFY,1))

#
# Enable FW OPP table
#
ifeq ($(SUPPORT_PDVFS),1)
SUPPORT_FW_OPP_TABLE := 1
endif

$(eval $(call TunableBothConfigMake,SUPPORT_FW_OPP_TABLE,,\
Enables Firmware OPP (Operating Point) table. \
))
$(eval $(call TunableBothConfigC,SUPPORT_FW_OPP_TABLE,))

ifeq ($(SUPPORT_FW_OPP_TABLE),1)
 ifeq ($(SUPPORT_LINUX_DVFS),)
  ifeq ($(SUPPORT_PDVFS),)
   $(error SUPPORT_FW_OPP_TABLE requires SUPPORT_LINUX_DVFS or SUPPORT_PDVFS to configure the OPP table.)
  endif
 endif
endif

#
# These specify how RGX GPIO port is used by the firmware.
#
$(eval $(call BothConfigMake,SUPPORT_PVR_GPIO,1,\
Enable basic send and receive using GPIO._\
))
$(eval $(call BothConfigC,SUPPORT_PVR_GPIO,1))

# If NDK_ROOT is set, SUPPORT_WORKLOAD_ESTIMATION can't be, because the
# ANDROID_WSEGL module uses APIs (binder, gui) which are not in the NDK.
ifeq ($(SUPPORT_WORKLOAD_ESTIMATION),1)
 ifneq ($(PVR_ANDROID_HAS_COMPOSITION_TIMINGS),1)
  ifneq ($(NDK_ROOT),)
   $(error SUPPORT_WORKLOAD_ESTIMATION and NDK_ROOT are incompatible features)
  endif
  ifeq ($(EGL_WSEGL_DIRECTLY_LINKED),1)
   $(error EGL_WSEGL_DIRECTLY_LINKED and SUPPORT_WORKLOAD_ESTIMATION are not supported at the same time)
  endif
 endif
endif

$(eval $(call TunableKernelConfigMake,PVR_HANDLE_BACKEND,idr,\
Specifies the back-end that should be used$(comma) by the Services kernel handle_\
interface$(comma) to allocate handles. The available backends are:_\
* generic (OS agnostic)_\
* idr (Uses the Linux IDR interface)_\
))


# SUPPORT_DMABUF_BRIDGE is set to include the dmabuf.brg in bridge generation
# by default for all Linux based builds.
$(eval $(call TunableBothConfigMake,SUPPORT_DMABUF_BRIDGE,1))

# SUPPORT_USC_BREAKPOINT is set to include the rgxbreakpoint.brg in bridge generation
# and to enable USC breakpoint in FW. Enabled by default for all Linux based builds.
#
ifeq ($(PVR_USC_ARCH),volcanic)
SUPPORT_USC_BREAKPOINT ?= 0
else
SUPPORT_USC_BREAKPOINT ?= 1
endif
$(eval $(call TunableBothConfigMake,SUPPORT_USC_BREAKPOINT,))
$(eval $(call TunableBothConfigC,SUPPORT_USC_BREAKPOINT,,Enable the USC breakpoint support))

# EXCLUDE_CMM_BRIDGE is set to exclude the cmm.brg bridge in
# the Kernel This is disabled by default for release builds.
#
$(eval $(call TunableBothConfigMake,EXCLUDE_CMM_BRIDGE,))
$(eval $(call TunableBothConfigC,EXCLUDE_CMM_BRIDGE,,Disables the cmm bridge))

# EXCLUDE_RGXREGCONFIG_BRIDGE is set to exclude the rgxregconfig.brg bridge in
# the Kernel This is disabled by default for release builds.
#
$(eval $(call TunableBothConfigMake,EXCLUDE_RGXREGCONFIG_BRIDGE,))
$(eval $(call TunableBothConfigC,EXCLUDE_RGXREGCONFIG_BRIDGE,,Disables the RGX regconfig bridge))

# PVRSRV_ENABLE_GPU_MEMORY_INFO is set to enable RI annotation of devmem allocations
# This is enabled by default for debug builds.
#
$(eval $(call TunableBothConfigMake,PVRSRV_ENABLE_GPU_MEMORY_INFO,))
$(eval $(call TunableBothConfigC,PVRSRV_ENABLE_GPU_MEMORY_INFO,,\
Enable Resource Information (RI) debug. This logs details of_\
resource allocations with annotation to help indicate their use._\
))

# PVRSRV_DEBUG_CSW_STATE is set to provide context switch task information
# to FSIM. This is disabled by default for debug and release builds.

ifeq ($(PDUMP),1)
# Force enable TBI interface in PDUMP mode
 override SUPPORT_TBI_INTERFACE :=1
endif

ifeq ($(VIRTUAL_PLATFORM),1)
# Force enable TBI interface for VIRTUAL_PLATFORM
 override SUPPORT_TBI_INTERFACE :=1
endif

$(eval $(call TunableBothConfigC,SUPPORT_TBI_INTERFACE,,\
Enable TBI interface support for firmware._\
))

$(eval $(call TunableBothConfigC,SUPPORT_FIRMWARE_GCOV,,\
Enable gcov support for firmware._\
))


# Safety related options
$(eval $(call TunableBothConfigMake,SUPPORT_TRP,))
$(eval $(call TunableBothConfigC,SUPPORT_TRP,))

ifeq ($(CORE_SUPPORTS_MULTICORE),1)
SUPPORT_AGP ?= 1
ifneq ($(MULTICORE_FIXED_PRIMARIES),)
ifeq ($(shell test $(MULTICORE_FIXED_PRIMARIES) -lt 2; echo $$?),0)
 SUPPORT_AGP := 0
endif
MULTICORE_FIXED_SECONDARIES ?= 0
endif

ifneq ($(MULTICORE_FIXED_SECONDARIES),)
endif

$(eval $(call TunableBothConfigC,SUPPORT_AGP,,\
Enable Alternate Geometry Processing support for multicore devices._\
))
endif

RGXFW_SAFETY_WATCHDOG_PERIOD_IN_US ?= 2000000
$(eval $(call KernelConfigC,RGXFW_SAFETY_WATCHDOG_PERIOD_IN_US,$(RGXFW_SAFETY_WATCHDOG_PERIOD_IN_US),\
The period in microseconds before the watchdog will trigger a safety_\
event if not reset in time. 0 = disabled; if enabled must be > 1000.\
))

# Some GPU arch-specific defaults for PDUMP parameters
override _pdump_param_init_stream_size := 0x200000
override _pdump_script_init_stream_size := 0x80000

# Set default CCB sizes
# Key for log2 CCB sizes:
# 13=8K 14=16K 15=32K 16=64K 17=128K
PVRSRV_RGX_LOG2_CLIENT_CCB_SIZE_CDM ?= 13
PVRSRV_RGX_LOG2_CLIENT_CCB_MAX_SIZE_CDM ?= 15
