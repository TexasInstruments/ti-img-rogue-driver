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


ifneq ($(INTERNAL_CLOBBER_ONLY),true)
 ifeq ($(RGX_BVNC),)
  ifeq ($(NO_HARDWARE),1)
   $(error Error: Must specify RGX_BVNC when building for NO_HARDWARE)
  else ifeq ($(PVR_ARCH),)
   $(error Error: Must specify PVR_ARCH when doing a kernel mode build without RGX_BVNC set)
  endif
 endif
endif

# Configuration wrapper for new build system. This file deals with
# configuration of the build. Add to this file anything that deals
# with switching driver options on/off and altering the defines or
# objects the build uses.
#
# At the end of this file is an exhaustive list of all variables
# that are passed between the platform/config stage and the generic
# build. PLEASE refrain from adding more variables than necessary
# to this stage -- almost all options can go through config.h.
#

# Sanity check: Make sure preconfig has been included
ifeq ($(TOP),)
$(error TOP not defined: Was preconfig.mk included in root makefile?)
endif

################################# MACROS ####################################

ALL_TUNABLE_OPTIONS :=

# This records the config option's help text and default value. Note that
# the help text can't contain a literal comma. Use $(comma) instead.
define RegisterOptionHelp
ALL_TUNABLE_OPTIONS += $(1)
ifeq ($(INTERNAL_DESCRIPTION_FOR_$(1)),)
INTERNAL_DESCRIPTION_FOR_$(1) := $(3)
endif
INTERNAL_CONFIG_DEFAULT_FOR_$(1) := $(2)
$(if $(4),\
	$(error Too many arguments in config option '$(1)' (stray comma in help text?)))
endef

# Write out a GNU make option for both user & kernel
#
define BothConfigMake
$$(eval $$(call KernelConfigMake,$(1),$(2)))
$$(eval $$(call UserConfigMake,$(1),$(2)))
endef

# Conditionally write out a GNU make option for both user & kernel
#
define TunableBothConfigMake
$$(eval $$(call _TunableKernelConfigMake,$(1),$(2)))
$$(eval $$(call _TunableUserConfigMake,$(1),$(2)))
$(call RegisterOptionHelp,$(1),$(2),$(3),$(4))
endef

# Write out an option for both user & kernel
#
define BothConfigC
$$(eval $$(call KernelConfigC,$(1),$(2)))
$$(eval $$(call UserConfigC,$(1),$(2)))
endef

# Conditionally write out an option for both user & kernel
#
define TunableBothConfigC
$$(eval $$(call _TunableKernelConfigC,$(1),$(2)))
$$(eval $$(call _TunableUserConfigC,$(1),$(2)))
$(call RegisterOptionHelp,$(1),$(2),$(3),$(4))
endef

# Use this to mark config options which have to exist, but aren't
# user-tunable. Warn if an attempt is made to change it.
#
define NonTunableOption
$(if $(filter command line environment,$(origin $(1))),\
	$(error Changing '$(1)' is not supported))
endef

############################### END MACROS ##################################

# Check we have a new enough version of GNU make.
#
need := 3.81
ifeq ($(filter $(need),$(firstword $(sort $(MAKE_VERSION) $(need)))),)
$(error A version of GNU make >= $(need) is required - this is version $(MAKE_VERSION))
endif

include ../defs.mk

# Infer PVR_BUILD_DIR from the directory configuration is launched from.
# Check anyway that such a directory exists.
#
PVR_BUILD_DIR := $(notdir $(abspath .))
$(call directory-must-exist,$(TOP)/build/linux/$(PVR_BUILD_DIR))

# Output directory for configuration, object code,
# final programs/libraries, and install/rc scripts.
#
ifneq ($(filter $(WINDOW_SYSTEM),xorg wayland nullws nulldrmws screen surfaceless tizen lws-generic compute_only),)
OUT          ?= $(TOP)/binary_$(PVR_BUILD_DIR)_$(WINDOW_SYSTEM)_$(BUILD)
else
OUT          ?= $(TOP)/binary_$(PVR_BUILD_DIR)_$(BUILD)
endif

# Use abspath, which doesn't require the path to already exist, to remove '.'
# and '..' path components. This allows paths to be manipulated without things
# ending up in the wrong place.
override OUT := $(abspath $(if $(filter /%,$(OUT)),$(OUT),$(TOP)/$(OUT)))

CONFIG_MK			:= $(OUT)/config.mk
CONFIG_H			:= $(OUT)/config.h
CONFIG_KERNEL_MK	:= $(OUT)/config_kernel.mk
CONFIG_KERNEL_H		:= $(OUT)/config_kernel.h

# Convert commas to spaces in $(D). This is so you can say "make
# D=config-changes,freeze-config" and have $(filter config-changes,$(D))
# still work.
override D := $(subst $(comma),$(space),$(D))

# Create the OUT directory
#
$(shell mkdir -p $(OUT))

# Enable PVRSRV_ENABLE_HTB if building on debug BUILD configuration
# Enable SUPPORT_DOUBLE_FREE_SENTINEL if building on debug BUILD config
ifeq ($(BUILD),debug)
 PVRSRV_ENABLE_HTB ?= 1
 SUPPORT_DOUBLE_FREE_SENTINEL := 1
endif

# For a clobber-only build, we shouldn't regenerate any config files
ifneq ($(INTERNAL_CLOBBER_ONLY),true)

# Core handling
#

-include ../config/user-defs.mk
-include ../config/kernel-defs.mk

# Disabling the online OpenCL compiler breaks the OpenCL spec.
# Use this option carefully (i.e. for embedded usage only).
OCL_ONLINE_COMPILATION ?= 1

# Some platforms don't have blob cache support, or the blob cache isn't usable
# for some reason. Make it possible to disable the OpenCL driver's use of it.
OCL_USE_KERNEL_BLOB_CACHE ?= 1

# Allow OpenCL to disable image sharing with EGL on platforms that don't support it.
OCL_USE_EGL_SHARING ?= 1
OCL_USE_GRALLOC_IMAGE_SHARING ?= 0

# Rather than requiring the user to have to define two variables (one quoted,
# one not), make PVRSRV_MODNAME a non-tunable and give it an overridable
# default here.
#
PVRSRV_MODNAME := pvrsrvkm
PVRSYNC_MODNAME := pvr_sync

# Check and set make variable if we are building using musl libc target toolchains.
# The build variable MUSL_LIBC can be set to 1 from command line or in the env
# if the toolchain name does not follow the standard naming convention.
ifneq ($(filter %-musl %-musleabi %-muslx32,$(CROSS_TRIPLE)),)
 MUSL_LIBC ?= 1
endif

VULKAN_LEGACY_LOADER ?= 0

ifneq ($(SUPPORT_CHROMIUMOS_PLATFORM)$(SUPPORT_ANDROID_PLATFORM),)
# Android/ChromeOS provides its own loader.
# This should overwrite any user-provided value of VULKAN_LEGACY_LOADER.
# As it won't be an LWS build, the loader must be present in the Android SYSROOTS.
override VULKAN_LEGACY_LOADER := 0
endif


# Default place for binaries and shared libraries
BIN_DESTDIR ?= /usr/local/bin
INCLUDE_DESTDIR ?= /usr/include
SHARE_DESTDIR ?= /usr/local/share
SHLIB_DESTDIR ?= /usr/lib
FW_DESTDIR ?= /lib/firmware
DTB_DESTDIR ?= /lib/firmware

# Write out settings to config* for the next make stage
SHADER_DESTDIR := $(SHARE_DESTDIR)/pvr/shaders/

# The SUPPORT_OPEN_SOURCE_DRIVER_FIRMWARE setting builds the (proprietary)
# DDK with the firmware configuration required for the open-source driver. This
# includes reserved padding words to ensure a consistent and compatible interface.
ifeq ($(SUPPORT_OPEN_SOURCE_DRIVER_FIRMWARE),1)
 # Set firmware major and minor versions for the open source driver. On the MAIN branch
 # this is set to 9999, but on a release branch set it to appropriate versions.
 OS_FW_MAJOR := 9999
 OS_FW_MINOR := 9999
endif

# Prevent rgx_kicksync bridge build when build option not enabled
# disable as unnecessary for release builds
ifneq ($(BUILD),release)
SUPPORT_RGXKICKSYNC_BRIDGE ?= 1

ifneq ($(SUPPORT_FIRMWARE_UNITTESTS),1)
RGX_FW_STACK_OVERFLOW_DEBUG ?= 1
endif
endif

# enable for Internal IMG testing
ifeq ($(PDUMP),1)
SUPPORT_RGXKICKSYNC_BRIDGE ?= 1
endif

# enable for Internal IMG testing
ifeq ($(SUPPORT_VALIDATION),1)
SUPPORT_RGXKICKSYNC_BRIDGE ?= 1
RGX_FW_STACK_OVERFLOW_DEBUG ?= 1
TRACK_FW_BOOT ?= 1
RGXFW_ASSERT_ENABLED ?= 1
endif

# enable for Internal IMG testing
ifeq ($(PVR_TESTING_UTILS),1)
SUPPORT_RGXKICKSYNC_BRIDGE ?= 1
endif

# default enable SUPPORT_DOUBLE_FREE_SENTINEL for all builds
SUPPORT_DOUBLE_FREE_SENTINEL ?= 1

# PVR_ENABLE_DMABUF_UPSTREAM_COMPAT enables behavior where the GPU is granted
# read/write access to the dma_buf regardless of the permission set to the
# dma_buf, in accordance with common upstream DRM driver practices.
$(eval $(call TunableBothConfigC,PVR_ENABLE_DMABUF_UPSTREAM_COMPAT,))

# Write out settings to config* for the next make stage
$(eval $(call TunableBothConfigC,SUPPORT_RGXKICKSYNC_BRIDGE,))
$(eval $(call TunableBothConfigMake,SUPPORT_RGXKICKSYNC_BRIDGE,))

$(eval $(call TunableBothConfigC,PVRSRV_ENABLE_HTB,,))
$(eval $(call TunableBothConfigMake,PVRSRV_ENABLE_HTB,$(PVRSRV_ENABLE_HTB),))

$(eval $(call TunableBothConfigC,VIRTUAL_PLATFORM,))
$(eval $(call TunableBothConfigC,EMULATOR,))

# Enable double-free sentinel for Linux KMD release builds if set in the
# environment. This is always enabled for DEBUG builds
$(eval $(call TunableKernelConfigC,SUPPORT_DOUBLE_FREE_SENTINEL,))
$(eval $(call TunableKernelConfigMake,SUPPORT_DOUBLE_FREE_SENTINEL,\
Enable double-free sentinel behaviour for all Linux KMD OSFreeMem calls._\
))

# Link Time Optimisation

# Only determine SUPPORT_LINUX_WRAP_EXTMEM_PAGE_TABLE_WALK support if we are
# building on a system that already has SUPPORT_WRAP_EXTMEM enabled.
ifeq ($(SUPPORT_WRAP_EXTMEM),1)
  $(eval $(call TunableKernelConfigMake,SUPPORT_LINUX_WRAP_EXTMEM_PAGE_TABLE_WALK,))
  $(eval $(call TunableKernelConfigC,SUPPORT_LINUX_WRAP_EXTMEM_PAGE_TABLE_WALK,,\
  This allows the kernel wrap memory handler to determine the pages_\
  associated with a given virtual address by performing a walk-through of the_\
  corresponding page tables. This method is only used with virtual address_\
  regions that belong to device or with virtual memory regions that have_\
  VM_IO set._\
  This setting is for Linux platforms only ._\
  ))
endif

$(eval $(call TunableKernelConfigC,PVRSRV_ENABLE_POWERLOCK_PRIO_INHERIT,,\
Use realtime-priority mutex lock for the power-lock. This respects the thread_\
priority and improves performance when many waiter threads compete for the resource._\
This setting is for Linux/Android platforms only ._\
))

# As we already know PVR_ARCH (and related defines - they're dealt with in
# preconfig.mk), may as well commit it to config*.mk
$(eval $(call BothConfigMake,PVR_ARCH,$(PVR_ARCH)))
$(eval $(call BothConfigMake,PVR_ARCH_DEFS,$(PVR_ARCH_DEFS)))

# Include architecture specific file
ifeq ($(PVR_ARCH),volcanic)
  include ../config/core_volcanic.mk
else
  include ../config/core_rogue.mk
endif


ifeq ($(PVRSRV_ENABLE_GPU_MEMORY_INFO),1)
# Increase the default annotation max length to 96 when PVRSRV_ENABLE_GPU_MEMORY_INFO
# is enabled
override PVR_ANNOTATION_MAX_LEN ?= 96
endif

# Default annotation max length to 63 if no other debug options are specified
$(eval $(call TunableBothConfigC,PVR_ANNOTATION_MAX_LEN,63,\
Defines the max length for PMR$(comma) MemDesc$(comma) Device_\
Memory History and RI debug annotations stored in memory.\
))

ifneq ($(SUPPORT_REDROID_PLATFORM),1)
  PVRSRV_DEVICE_INIT_MODE ?= PVRSRV_LINUX_DEV_INIT_ON_CONNECT
else
  # loading firmware when ON_PROBE otherwise it failed.
  PVRSRV_DEVICE_INIT_MODE ?= PVRSRV_LINUX_DEV_INIT_ON_PROBE
endif
$(eval $(call TunableBothConfigC,PVRSRV_DEVICE_INIT_MODE,PVRSRV_DEVICE_INIT_MODE,\
Specify when device initialisation (and loading of Firmware) will be done._\
PVRSRV_LINUX_DEV_INIT_ON_PROBE means do this as part of the driver probe function$(comma)_\
which is the moment an instance of the device gets bound to the driver._\
If the driver fails to load the Firmware at this point$(comma) it will return_\
an error and it will not be possible to open a connection to the device._\
PVRSRV_LINUX_DEV_INIT_ON_OPEN means do this when the device is first opened._\
PVRSRV_LINUX_DEV_INIT_ON_CONNECT means do this when the first connection_\
is made to the device._\
This is a Linux-only feature.\
))

$(eval $(call TunableKernelConfigC,DEBUG_BRIDGE_KM,,\
Enable Services bridge debugging and bridge statistics output_\
))

ifneq ($(SUPPORT_INTEGRITY_PLATFORM),1)
  $(eval $(call TunableKernelConfigMake,SUPPORT_DI_APPHINT_IMPL,1,\
  Support apphints access via OS agnostic Debug Info interface._\
  ))
  $(eval $(call TunableKernelConfigC,SUPPORT_DI_APPHINT_IMPL,1,\
  Support apphints access via OS agnostic Debug Info interface._\
  ))
endif

$(eval $(call TunableBothConfigC,PVRSRV_ENABLE_MEMORY_STATS,,\
Enable Memory allocations to be recorded and published via Process Statistics._\
))

$(eval $(call TunableKernelConfigC,PVRSRV_ENABLE_MEMTRACK_STATS_FILE,,\
Enable the memtrack_stats debugfs file when not on an Android platform._\
))

$(eval $(call TunableBothConfigC,PVRSRV_ENABLE_PROCESS_STATS,1,\
Enable the collection of Process Statistics in the kernel Server module._\
Feature on by default. Driver_stats summary presented in DebugFS on Linux._\
))

$(eval $(call TunableBothConfigC,PVRSRV_DEBUG_LINUX_MEMORY_STATS,,\
Present Process Statistics memory stats in a more detailed manner to_\
assist with debugging and finding memory leaks (under Linux only)._\
))

$(eval $(call TunableBothConfigC,PVRSRV_ENABLE_PERPID_STATS,,\
Enable the presentation of process statistics in the kernel Server module._\
Feature off by default. \
))

$(eval $(call TunableBothConfigMake,PVRSRV_ENABLE_PHYSHEAP_PERPID_STATS,1,))
$(eval $(call TunableBothConfigC,PVRSRV_ENABLE_PHYSHEAP_PERPID_STATS,1,\
Enable the per-process per-device physheap stats tracking._\
Feature on by default for Linux._\
))

$(eval $(call TunableBothConfigC,PVRSRV_STRICT_COMPAT_CHECK,,\
Enable strict mode of checking all the build options between um & km._\
The driver may fail to load if there is any mismatch in the options._\
))

$(eval $(call TunableBothConfigC,PVR_LINUX_PHYSMEM_MAX_POOL_PAGES,10240,\
Defines how many pages the page cache should hold.))

$(eval $(call TunableBothConfigC,PVR_LINUX_PHYSMEM_MAX_EXCESS_POOL_PAGES,20480,\
We double check if we would exceed this limit if we are below MAX_POOL_PAGES_\
and want to add an allocation to the pool._\
This prevents big allocations being given back to the OS just because they_\
exceed the MAX_POOL_PAGES limit even though the pool is currently empty._\
))

ifneq ($(PVR_TESTING_UTILS),1)
  PVR_PHYSMEM_ZERO_ALL_PAGES ?= 1
else
  PVR_PHYSMEM_ZERO_ALL_PAGES ?= 0
endif
$(eval $(call TunableBothConfigC,PVR_PHYSMEM_ZERO_ALL_PAGES,PVR_PHYSMEM_ZERO_ALL_PAGES,\
All device memory allocated from the OS via the Rogue driver will be zeroed_\
when this is defined. This may not be necessary in closed platforms where_\
undefined data from previous use in device memory is acceptable._\
This feature may change the performance signature of the drivers memory_\
allocations on some platforms and kernels._\
))

PVR_PHYSMEM_LMA_ZERO_ALL_PAGES ?= 0
$(eval $(call TunableBothConfigC,PVR_PHYSMEM_LMA_ZERO_ALL_PAGES,PVR_PHYSMEM_LMA_ZERO_ALL_PAGES,\
All GPU local memory will be zeroed on free for platforms where this_\
is required for security. This may affect how quickly memory is freed._\
))

# If target is 32bit
ifeq ($(filter target_arm target_armel target_armhf target_armv7-a \
               target_i686 target_mips target_mips32r6el target_mips32r2el \
               target_x86,$(TARGET_PRIMARY_ARCH)), $(TARGET_PRIMARY_ARCH))
 PVR_LINUX_PHYSMEM_SUPPRESS_DMA_AC ?= 1
else
 PVR_LINUX_PHYSMEM_SUPPRESS_DMA_AC ?= 0
endif

$(eval $(call TunableKernelConfigC,PVR_LINUX_PHYSMEM_SUPPRESS_DMA_AC,PVR_LINUX_PHYSMEM_SUPPRESS_DMA_AC,\
Higher order page requests on Linux use dma_alloc_coherent but on some systems_\
it could return pages from high memory and map those to the vmalloc space._\
Since graphics demand a lot of memory the system could quickly exhaust the_\
vmalloc space. Setting this define will suppress the use of dma_alloc_coherent_\
and fall back to use alloc_pages and not map them to vmalloc space unless_\
requested explicitly by the driver._\
))

$(eval $(call TunableKernelConfigC,PVR_LINUX_PHYSMEM_USE_HIGHMEM_ONLY,,\
GPU buffers are allocated from the highmem region by default._\
Only affects 32bit systems and devices with DMA_BIT_MASK equal to 32._\
))

$(eval $(call TunableKernelConfigC,PVR_PMR_TRANSLATE_UMA_ADDRESSES,,\
Requests for physical addresses from the PMR will translate the addresses_\
retrieved from the PMR-factory from CpuPAddrToDevPAddr. This can be used_\
for systems where the GPU has a different view onto the system memory_\
compared to the CPU._\
))

$(eval $(call TunableBothConfigC,PVR_MMAP_USE_VM_INSERT,,\
If enabled Linux will always use vm_insert_page for CPU mappings._\
vm_insert_page was found to be slower than remap_pfn_range on ARM kernels_\
but guarantees full memory accounting for the process that mapped the memory._\
The slowdown in vm_insert_page is caused by a dcache flush_\
that is only implemented for ARM and a few other architectures._\
This tunable can be enabled to debug memory issues. On x86 platforms_\
we always use vm_insert_page independent of this tunable._\
))

$(eval $(call TunableBothConfigC,PVR_DIRTY_BYTES_FLUSH_THRESHOLD,524288,\
When allocating uncached or write-combine memory we need to invalidate the_\
CPU cache before we can use the acquired pages; also when using cached memory_\
we need to clean/flush the CPU cache before we transfer ownership of the_\
memory to the device. This threshold defines at which number of pages expressed_\
in bytes we want to do a full cache flush instead of invalidating pages one by one._\
Default value is 524288 bytes or 128 pages; ideal value depends on SoC cache size._\
))

$(eval $(call TunableKernelConfigC,RGX_FORCE_FREELIST_CLEANUP,,\
Force Free List cleanup if it has not been freed by the CleanupThread for_\
a defined number of retries._\
This feature is experimental and should be utilized exclusively for debugging_\
and diagnostic purposes._\
))

$(eval $(call TunableBothConfigC,PVR_LINUX_HIGHORDER_ALLOCATION_THRESHOLD,256,\
Allocate OS pages in 2^(order) chunks if more than this threshold were requested_\
))

PVR_LINUX_PHYSMEM_MAX_ALLOC_ORDER ?= 2
$(eval $(call TunableBothConfigC,PVR_LINUX_PHYSMEM_MAX_ALLOC_ORDER_NUM,$(PVR_LINUX_PHYSMEM_MAX_ALLOC_ORDER),\
Allocate OS pages in 2^(order) chunks to help reduce duration of large allocations_\
))

$(eval $(call TunableBothConfigC,PVR_LINUX_KMALLOC_ALLOCATION_THRESHOLD,16384,\
Choose the threshold at which allocation size the driver uses vmalloc instead of_\
kmalloc. On highly fragmented systems large kmallocs can fail because it requests_\
physically contiguous pages. All allocations bigger than this define use vmalloc._\
))

ifeq ($(SUPPORT_LINUX_OSPAGE_MIGRATION),1)
 ifeq ($(PDUMP),1)
  $(error Linux OSPage Migration not supported on PDUMP builds)
 endif
endif
$(eval $(call TunableBothConfigMake,SUPPORT_LINUX_OSPAGE_MIGRATION,))
$(eval $(call TunableBothConfigC,SUPPORT_LINUX_OSPAGE_MIGRATION,,\
Enable support for Linux OS page migration logic in the UM & KM driver_\
for systems with UMA physical heaps._\
))

$(eval $(call TunableKernelConfigC,PVRSRV_ENABLE_READBACK_ON_WRITES,,\
Perform memory readback on writes on platform with buses that require it._\
))

# Enable checking of Linux kernel init_on_alloc setting in the KM driver's UMA allocator on
# Linux kernels 5.3 or later. Helps avoid duplicating the zero on alloc behaviour in the
# driver on such systems. Make option values supported:
#  1 - Check runtime setting value via want_init_on_alloc() API
#  2 - Assume runtime setting value (modparam) not used on system, assume config value
#  0 - Ignore kernel behaviour, driver zeroes on alloc when required
#
PVRSRV_USE_LINUX_INIT_ON_ALLOC ?= 1
ifeq ($(PVRSRV_USE_LINUX_INIT_ON_ALLOC),0)
$(eval $(call KernelConfigC,PVRSRV_USE_LINUX_CONFIG_INIT_ON_ALLOC,0))
else ifeq ($(PVRSRV_USE_LINUX_INIT_ON_ALLOC),1)
$(eval $(call KernelConfigC,PVRSRV_USE_LINUX_CONFIG_INIT_ON_ALLOC,1))
else ifeq ($(PVRSRV_USE_LINUX_INIT_ON_ALLOC),2)
$(eval $(call KernelConfigC,PVRSRV_USE_LINUX_CONFIG_INIT_ON_ALLOC,2))
else
$(error Invalid value supplied to PVRSRV_USE_LINUX_INIT_ON_ALLOC in KM build)
endif

ifeq ($(PDUMP),1)
$(eval $(call TunableKernelConfigC,PDUMP_PARAM_INIT_STREAM_SIZE,$(_pdump_param_init_stream_size),\
Size of pdump param init buffer (in bytes)))
$(eval $(call TunableKernelConfigC,PDUMP_PARAM_MAIN_STREAM_SIZE,0x1000000,\
Default size of PDump param main buffer is 16 MB))
$(eval $(call TunableKernelConfigC,PDUMP_PARAM_DEINIT_STREAM_SIZE,0x10000,\
Default size of PDump param deinit buffer is 64KB))
# Default size of PDump param block buffer is 0KB as it is currently not in use
$(eval $(call TunableKernelConfigC,PDUMP_PARAM_BLOCK_STREAM_SIZE,0x0,\
Default size of PDump param block buffer is 0KB))
$(eval $(call TunableKernelConfigC,PDUMP_SCRIPT_INIT_STREAM_SIZE,$(_pdump_script_init_stream_size),\
Size of PDump script init buffer (in bytes)))
$(eval $(call TunableKernelConfigC,PDUMP_SCRIPT_MAIN_STREAM_SIZE,0x800000,\
Default size of PDump script main buffer is 8MB))
$(eval $(call TunableKernelConfigC,PDUMP_SCRIPT_DEINIT_STREAM_SIZE,0x10000,\
Default size of PDump script deinit buffer is 64KB))
$(eval $(call TunableKernelConfigC,PDUMP_SCRIPT_BLOCK_STREAM_SIZE,0x800000,\
Default size of PDump script block buffer is 8MB))
$(eval $(call TunableKernelConfigC,PDUMP_SPLIT_64BIT_REGISTER_ACCESS,1,\
 Split 64 bit RGX register accesses into two 32 bit))
endif

# Fence Sync build tunables
# Default values dependent on WINDOW_SYSTEM and found in window_system.mk
#
$(eval $(call TunableBothConfigMake,SUPPORT_NATIVE_FENCE_SYNC,$(SUPPORT_NATIVE_FENCE_SYNC)))
$(eval $(call TunableBothConfigC,SUPPORT_NATIVE_FENCE_SYNC,,\
Use the Linux native fence sync back-end with timelines and fences))

$(eval $(call TunableBothConfigMake,SUPPORT_FALLBACK_FENCE_SYNC,))
$(eval $(call TunableBothConfigC,SUPPORT_FALLBACK_FENCE_SYNC,,\
Use Services OS agnostic fallback fence sync back-end with timelines and fences))

$(eval $(call TunableBothConfigC,PVRSRV_STALLED_CCB_ACTION,1,\
This determines behaviour of DDK on detecting that a cCCB_\
has stalled (failed to progress for a number of seconds when GPU is idle):_\
  "" = Output warning message to kernel log only_\
 "1" = Output warning message and additionally try to unblock cCCB by_\
       erroring sync checkpoints on which it is fenced (the value of any_\
       sync prims in the fenced will remain unmodified)_\
))

$(eval $(call TunableBothConfigC,PVRSRV_DEMOTE_PMRS_TO_UNCACHED,1,\
Allow the DDK to apply the cache coherency downgrade workaround \
for the SoCs that need it))

$(eval $(call TunableBothConfigC,PVRSRV_PROMOTE_PMRS_TO_CACHE_INCOHERENT,1,\
Allow the DDK to promote a mapping to caching for the SoCs that need it))

ifeq ($(SUPPORT_DMA_TRANSFER),1)
 $(eval $(call BothConfigMake,SUPPORT_DMA_TRANSFER,1))
 $(eval $(call BothConfigC,SUPPORT_DMA_TRANSFER,1))
 $(eval $(call TunableKernelConfigC,PVRSRV_DEBUG_DMA,1,\
 Instructs the PVR Services kernel mode driver to produce_\
 additional debug information during the execution of a_\
 DMA transfer such as the physical addresses of the pages_\
 of the source and  destination buffers.))
 ifeq ($(TC_XILINX_DMA),1)
  ifeq ($(call kernel-version-is-available),true)
   ifneq ($(call kernel-version-at-least,4,9),true)
   $(error Xilinx DMA requires at least Kernel 4.9)
   endif
  endif
 endif
endif

# Fallback and native sync implementations are mutually exclusive because they
# both offer an implementation for the same interface
ifeq ($(SUPPORT_FALLBACK_FENCE_SYNC),1)
ifeq ($(SUPPORT_NATIVE_FENCE_SYNC),1)
$(error Choose either SUPPORT_NATIVE_FENCE_SYNC=1 or SUPPORT_FALLBACK_FENCE_SYNC=1 but not both)
endif
endif

ifeq ($(SUPPORT_NATIVE_FENCE_SYNC),1)
 PVR_USE_LEGACY_SYNC_H ?= 1


  $(eval $(call TunableBothConfigMake,SUPPORT_FOREIGN_FENCE_TOKEN,,))
  $(eval $(call TunableBothConfigC,SUPPORT_FOREIGN_FENCE_TOKEN,,\
  Build option for enabling handling of foreign fence tokens in _\
  sync checkpoint and FW.))

  $(eval $(call TunableBothConfigMake,SUPPORT_FASTPATH_FENCE,,))
  $(eval $(call TunableBothConfigC,SUPPORT_FASTPATH_FENCE,,\
  Build option for enabling the Fast-path Fence DDK feature. _\
  This feature provides a firmware interface to 3rd-party IP allowing fences to be _\
  directly signalled on the GPU firmware. This has a lower latency than the host _\
  route between devices using the dma_fence Linux framework.))

  ifeq ($(SUPPORT_FASTPATH_FENCE),1)
   ifeq ($(SUPPORT_TRUSTED_DEVICE),1)
    $(error SUPPORT_FASTPATH_FENCE=1 not supported with SUPPORT_TRUSTED_DEVICE=1)
   endif
   ifeq ($(SUPPORT_FOREIGN_FENCE_TOKEN),1)
    $(error SUPPORT_FASTPATH_FENCE=1 not supported with SUPPORT_FOREIGN_FENCE_TOKEN=1)
   endif

   ifneq ($(RGX_NUM_DRIVERS_SUPPORTED),)
    ifneq ($(RGX_NUM_DRIVERS_SUPPORTED), 0)
     ifneq ($(RGX_NUM_DRIVERS_SUPPORTED), 1)
      $(error SUPPORT_FASTPATH_FENCE does not support RGX_NUM_DRIVERS_SUPPORTED > 1)
     endif
    endif
   endif

   ifeq ($(SUPPORT_MIPS_FIRMWARE),1)
    $(error SUPPORT_FASTPATH_FENCE=1 not supported with MIPS devices)
   endif

   $(eval $(call TunableBothConfigC,SUPPORT_FASTPATH_FENCE_CUSTOM_COMMS,,\
   Use custom kick and communicate method rather than the reference FPT-CB design.))
  endif

else # SUPPORT_NATIVE_FENCE_SYNC=0

 ifeq ($(SUPPORT_FASTPATH_FENCE),1)
  $(error Error: Fast Path Fence feature can not be used with non-Native Fence Sync WINDOW_SYSTEM builds)
 endif

 ifeq ($(SUPPORT_FOREIGN_FENCE_TOKEN),1)
 $(error Error: Foreign fence token feature can not be used with non-Native Fence Sync WINDOW_SYSTEM builds)
 endif

endif # SUPPORT_NATIVE_FENCE_SYNC=1

ifeq ($(SUPPORT_FASTPATH_FENCE),1)
 ifeq ($(SUPPORT_FASTPATH_FENCE_CUSTOM_COMMS),1)
   $(eval $(call AppHintConfigC,PVRSRV_APPHINT_ENABLEAPM,RGX_ACTIVEPM_DEFAULT,\
   Force the initial driver APM configuration to the specified value _\
   It is assumed that MTS is not used in this mode for APU->GPU wake.))
 else
   # APM is not supported in combination with FPF using MTS.
   $(eval $(call AppHintConfigC,PVRSRV_APPHINT_ENABLEAPM,RGX_ACTIVEPM_FORCE_OFF,\
   Force the initial driver APM configuration to the specified value))
 endif

else
  $(eval $(call AppHintConfigC,PVRSRV_APPHINT_ENABLEAPM,RGX_ACTIVEPM_DEFAULT,\
  Force the initial driver APM configuration to the specified value))
endif

# This value is needed by ta/3d kick for early command size calculation.
$(eval $(call KernelConfigC,UPDATE_FENCE_CHECKPOINT_COUNT,1))

RGX_VZ_CONNECTION_COOLDOWN_PERIOD ?= 0
$(eval $(call KernelConfigC,RGX_VZ_CONNECTION_COOLDOWN_PERIOD,$(RGX_VZ_CONNECTION_COOLDOWN_PERIOD),\
Minimum amount of time in seconds that a Guest must wait after being forcefully disconnected_\
from the GPU before retrying to establish a connection.))

ifeq ($(SUPPORT_ANDROID_PLATFORM),1)
RGX_MAX_CONTEXT_DEFER_LIMIT ?= 2
endif
$(eval $(call TunableBothConfigC,RGX_MAX_CONTEXT_DEFER_LIMIT,$(RGX_MAX_CONTEXT_DEFER_LIMIT)))

$(eval $(call TunableKernelConfigC,SUPPORT_CPUCACHED_FWMEMCTX,,\
Should only be used on Linux ARM64 systems with CPU->GPU cache _\
snooping to prevent snooping of Uncached WC buffers due to the _\
linux direct mapping))

$(eval $(call BothConfigC,PVR_DRM_NAME,"\"pvr\""))



$(eval $(call TunableKernelConfigC,PVRSRV_FORCE_SLOWER_VMAP_ON_64BIT_BUILDS,,\
If enabled$(comma) all kernel mappings will use vmap/vunmap._\
vmap/vunmap is slower than vm_map_ram/vm_unmap_ram and can_\
even have bad peaks taking up to 100x longer than vm_map_ram._\
The disadvantage of vm_map_ram is that it can lead to vmalloc space_\
fragmentation that can lead to vmalloc space exhaustion on 32 bit Linux systems._\
This flag only affects 64 bit Linux builds$(comma) on 32 bit we always default_\
to use vmap because of the described fragmentation problem._\
))

$(eval $(call TunableBothConfigC,DEVICE_MEMSETCPY_ALIGN_IN_BYTES,16,\
Sets pointer alignment (in bytes) needed by PVRSRVDeviceMemSet/Copy_\
for arm64 arch._\
This value should reflect memory bus width e.g. if the bus is 64 bits_\
wide this value should be set to 8 bytes (though it's not a hard requirement)._\
))


$(eval $(call TunableKernelConfigC,PVRSRV_DEBUG_LISR_EXECUTION,,\
Collect information about the last execution of the LISR in order to_\
debug interrupt handling timeouts._\
))

$(eval $(call TunableKernelConfigC,PVRSRV_TIMER_CORRELATION_HISTORY,,\
Collect information about timer correlation data over time._\
))

$(eval $(call TunableKernelConfigC,DISABLE_GPU_FREQUENCY_CALIBRATION,,\
Disable software estimation of the GPU frequency done on the Host and used_\
for timer correlation._\
))

$(eval $(call TunableKernelConfigC,RGX_INITIAL_SLR_HOLDOFF_PERIOD_MS,0,\
Period (in ms) for which any Sync Lockup Recovery (SLR) behaviour should be_\
suppressed following driver load. This can help to avoid any attempted SLR_\
during the boot process._\
))

# Set default CCB sizes
# Key for log2 CCB sizes:
# 13=8K 14=16K 15=32K 16=64K 17=128K
$(eval $(call TunableBothConfigC,PVRSRV_RGX_LOG2_CLIENT_CCB_SIZE_TQ3D,14,\
Define the log2 size of the TQ3D client CCB._\
))

$(eval $(call TunableBothConfigC,PVRSRV_RGX_LOG2_CLIENT_CCB_SIZE_TQ2D,14,\
Define the log2 size of the TQ2D client CCB._\
))

$(eval $(call TunableBothConfigC,PVRSRV_RGX_LOG2_CLIENT_CCB_SIZE_CDM,,\
Define the log2 size of the CDM client CCB._\
))

$(eval $(call TunableBothConfigC,PVRSRV_RGX_LOG2_CLIENT_CCB_SIZE_TA,15,\
Define the log2 size of the TA client CCB._\
))

$(eval $(call TunableBothConfigC,PVRSRV_RGX_LOG2_CLIENT_CCB_SIZE_3D,16,\
Define the log2 size of the 3D client CCB._\
))

$(eval $(call TunableBothConfigC,PVRSRV_RGX_LOG2_CLIENT_CCB_SIZE_KICKSYNC,13,\
Define the log2 size of the KickSync client CCB._\
))

$(eval $(call TunableBothConfigC,PVRSRV_RGX_LOG2_CLIENT_CCB_SIZE_TDM,14,\
Define the log2 size of the TDM client CCB._\
))

$(eval $(call TunableBothConfigC,PVRSRV_RGX_LOG2_CLIENT_CCB_SIZE_RDM,13,\
Define the log2 size of the RDM client CCB._\
))

# Max sizes (used in CCB grow feature)
$(eval $(call TunableBothConfigC,PVRSRV_RGX_LOG2_CLIENT_CCB_MAX_SIZE_TQ3D,17,\
Define the log2 max size of the TQ3D client CCB._\
))

$(eval $(call TunableBothConfigC,PVRSRV_RGX_LOG2_CLIENT_CCB_MAX_SIZE_TQ2D,17,\
Define the log2 max size of the TQ2D client CCB._\
))

$(eval $(call TunableBothConfigC,PVRSRV_RGX_LOG2_CLIENT_CCB_MAX_SIZE_CDM,,\
Define the log2 max size of the CDM client CCB._\
))

$(eval $(call TunableBothConfigC,PVRSRV_RGX_LOG2_CLIENT_CCB_MAX_SIZE_TA,16,\
Define the log2 max size of the TA client CCB._\
))

$(eval $(call TunableBothConfigC,PVRSRV_RGX_LOG2_CLIENT_CCB_MAX_SIZE_3D,17,\
Define the log2 max size of the 3D client CCB._\
))

$(eval $(call TunableBothConfigC,PVRSRV_RGX_LOG2_CLIENT_CCB_MAX_SIZE_KICKSYNC,13,\
Define the log2 max size of the KickSync client CCB._\
))

$(eval $(call TunableBothConfigC,PVRSRV_RGX_LOG2_CLIENT_CCB_MAX_SIZE_TDM,17,\
Define the log2 max size of the TDM client CCB._\
))

$(eval $(call TunableBothConfigC,PVRSRV_RGX_LOG2_CLIENT_CCB_MAX_SIZE_RDM,15,\
Define the log2 max size of the RDM client CCB._\
))

$(eval $(call TunableBothConfigC,SUPPORT_FW_HOST_SIDE_RECOVERY,,\
Enable to recover the device through the Host if the FW was unresponsive._\
))

$(eval $(call TunableBothConfigMake,SUPPORT_SYZKALLER,))
$(eval $(call TunableBothConfigC,SUPPORT_SYZKALLER,,))

# Only permit compute_only and lws-generic WS for compute-only BVNCs
ifeq ($(SUPPORT_COMPUTE_ONLY),1)
 ifeq ($(filter $(WINDOW_SYSTEM),compute_only lws-generic),)
  $(error COMPUTE_ONLY DDK build only supports WINDOW_SYSTEM=compute_only or WINDOW_SYSTEM=lws-generic)
 endif
endif

# None of LWS stuff is relevant to non-Linux platforms
ifeq ($(SUPPORT_NEUTRINO_PLATFORM)$(SUPPORT_INTEGRITY_PLATFORM),)
 ifeq ($(filter nullws nulldrmws ews compute_only,$(WINDOW_SYSTEM)),)
  ifeq ($(SUPPORT_BUILD_LWS),1)
   ifneq ($(SYSROOT),)
    $(warning ******************************************************)
    $(warning WARNING: You have specified a SYSROOT, or are using a)
    $(warning buildroot compiler, and enabled SUPPORT_BUILD_LWS. We)
    $(warning will ignore the sysroot and will build all required)
    $(warning LWS components. Set SUPPORT_BUILD_LWS to 0 if this is)
    $(warning not what you want.)
    $(warning ******************************************************)
   endif

   ifneq ($(origin SUPPORT_BUILD_LWS),file)
    ifneq ($(filter surfaceless wayland xorg tizen,$(WINDOW_SYSTEM)),)
     $(warning ******************************************************)
     $(warning WARNING: You should not set SUPPORT_BUILD_LWS to 1)
     $(warning explicitly, it's enabled by default)
     $(warning ******************************************************)
    endif
   endif

   override SYSROOT :=
  endif
 else
  ifneq ($(filter-out file undefined,$(origin SUPPORT_BUILD_LWS)),)
   $(info *** SUPPORT_BUILD_LWS is not user-configurable for nullws/nulldrmws/compute_only/ews.)
   $(info *** If SYSROOT is set, dependencies will be picked up from SYSROOT,)
   $(info *** otherwise LWS will be built if available.)
  endif
  # Eventually, this should be the only logic required for SUPPORT_BUILD_LWS for
  # _all_ windowing systems - once we accomplish that, it should become non-user
  # configurable variable.
  ifeq ($(SYSROOT),)
   override SUPPORT_BUILD_LWS := 1
  else
   override SUPPORT_BUILD_LWS := 0
  endif
 endif


 ifneq ($(strip $(LWS_PREFIX)),)
 endif

 # The name of the file that contains the set of tarballs that should be
 # built to support a given Linux distribution.
 ifeq ($(WINDOW_SYSTEM),tizen)
 LWS_DIST ?= tarballs-tizen-next
 else
 LWS_DIST ?= tarballs-ubuntu-next
 endif

 ifeq ($(SUPPORT_BUILD_LWS),1)
  COMPONENTS += $(LWS_COMPONENTS)
 endif
endif

ifneq ($(filter pvr_vk_loader,$(COMPONENTS)),)
  $(warning ******************************************************)
  $(warning WARNING: You are building the PVR loader, which is)
  $(warning soon to be deprecated)
  $(warning ******************************************************)
  ifeq ($(SUPPORT_BUILD_LWS),1)
    $(warning ******************************************************)
    $(warning WARNING: SUPPORT_BUILD_LWS and VULKAN_LEGACY_LOADER both)
    $(warning =1. This will prevent the Khronos Loader from being)
    $(warning built as an LWS component, only building the PVR loader)
    $(warning ******************************************************)
  endif
endif

# This is intended for integration with other build systems, and with the
# lws-generic window system in particular. It allows additional components
# to be built beyond what would be built as standard.
COMPONENTS += $(EXTRA_COMPONENTS)


ifeq ($(SUPPORT_EGL_KHR_NATIVE_PIXMAP),1)
endif

$(eval $(call NonTunableOption,SUPPORT_VOLCANIC_TB))
$(eval $(call TunableKernelConfigC,SUPPORT_VOLCANIC_TB,$(SUPPORT_VOLCANIC_TB)))
$(eval $(call TunableKernelConfigMake,SUPPORT_VOLCANIC_TB,$(SUPPORT_VOLCANIC_TB)))

# Only relevant for Linux builds where SUPPORT_PERFETTO is a path to the
# Perfetto SDK. Android uses API level to do the fixup where the
# SUPPORT_PERFETTO_GT_27 is used.
ifneq ($(filter-out 0 1,$(SUPPORT_PERFETTO)),)
endif
endif # INTERNAL_CLOBBER_ONLY


export INTERNAL_CLOBBER_ONLY
export TOP
export OUT
export PVR_ARCH_CFLAG
export PVR_USC_ARCH
export PVR_TPU_ARCH
export PVR_FBC_ARCH
export HWDEFS_ALL_PATHS

MAKE_ETC := -Rr --no-print-directory -C $(TOP) \
		TOP=$(TOP) OUT=$(OUT) HWDEFS_DIR=$(HWDEFS_DIR) \
	        -f build/linux/toplevel.mk

# This must match the default value of MAKECMDGOALS below, and the default
# goal in toplevel.mk
.DEFAULT_GOAL := build

ifeq ($(MAKECMDGOALS),)
MAKECMDGOALS := build
else
# We can't pass autogen to toplevel.mk
MAKECMDGOALS := $(filter-out autogen,$(MAKECMDGOALS))
ifneq ($(filter rgxfw_debug, $(strip $(MAKECMDGOALS))),)
$(info ** rgxfw_debug is redundant now, rgxfw_debug.zip is built as a part of the main build.)
MAKECMDGOALS := $(filter-out rgxfw_debug,$(MAKECMDGOALS))
endif
endif

.PHONY: autogen
autogen:
ifeq ($(INTERNAL_CLOBBER_ONLY),)
	@$(MAKE) -s --no-print-directory -C $(TOP) \
		-f build/linux/prepare_tree.mk
else
	@:
endif

include ../config/help.mk

# This deletes built-in suffix rules. Otherwise the submake isn't run when
# saying e.g. "make thingy.a"
.SUFFIXES:

# Because we have a match-anything rule below, we'll run the main build when
# we're actually trying to remake various makefiles after they're read in.
# These rules try to prevent that
%.mk: ;
Makefile%: ;
Makefile: ;

# Default values for virtualisation QoS parameters
DriverID := 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31

$(foreach i,$(DriverID),$(eval RGX_DRIVERID_$(i)_DEFAULT_PRIORITY ?= ($(RGX_NUM_DRIVERS_SUPPORTED) - $(i))))
$(foreach i,$(DriverID),\
$(eval $(call KernelConfigC,RGX_DRIVERID_$(i)_DEFAULT_PRIORITY,$(RGX_DRIVERID_$(i)_DEFAULT_PRIORITY),)))

$(foreach i,$(DriverID), $(eval RGX_DRIVERID_$(i)_DEFAULT_ISOLATION_GROUP ?= ($(i))))
$(foreach i,$(DriverID),\
$(eval $(call KernelConfigC,RGX_DRIVERID_$(i)_DEFAULT_ISOLATION_GROUP,$(RGX_DRIVERID_$(i)_DEFAULT_ISOLATION_GROUP),)))

$(foreach i,$(DriverID), $(eval RGX_DRIVERID_$(i)_DEFAULT_TIME_SLICE ?= 0))
RGX_DRIVER_DEFAULT_TIME_SLICE_INTERVAL ?= 0
$(foreach i,$(DriverID),\
$(eval $(call KernelConfigC,RGX_DRIVERID_$(i)_DEFAULT_TIME_SLICE,$(RGX_DRIVERID_$(i)_DEFAULT_TIME_SLICE),)))
$(eval $(call KernelConfigC,RGX_DRIVER_DEFAULT_TIME_SLICE_INTERVAL,$(RGX_DRIVER_DEFAULT_TIME_SLICE_INTERVAL),))
$(foreach i,$(DriverID),\
$(eval RGX_DRIVER_DEFAULT_TIME_SLICES_SUM := ($(RGX_DRIVER_DEFAULT_TIME_SLICES_SUM) + $(RGX_DRIVERID_$(i)_DEFAULT_TIME_SLICE))))
$(eval $(call KernelConfigC,RGX_DRIVER_DEFAULT_TIME_SLICES_SUM,$(RGX_DRIVER_DEFAULT_TIME_SLICES_SUM),))

$(foreach i,$(DriverID), $(eval DRIVER$(i)_SECURITY_SUPPORT ?= 0))
$(foreach i,$(DriverID), \
$(eval $(call BothConfigC,DRIVER$(i)_SECURITY_SUPPORT,$(DRIVER$(i)_SECURITY_SUPPORT),)))

tags:
	cd $(TOP) ; \
	ctags \
		--recurse=yes \
		--exclude=binary_* \
		--exclude=caches \
		--exclude=docs \
		--exclude=external \
		--languages=C,C++

.PHONY: build kbuild install
build kbuild install: MAKEOVERRIDES :=
build kbuild install: autogen
	@$(if $(MAKECMDGOALS),$(MAKE) $(MAKE_ETC) $(MAKECMDGOALS) $(eval MAKECMDGOALS :=),:)

%: MAKEOVERRIDES :=
%: autogen
	@$(if $(MAKECMDGOALS),$(MAKE) $(MAKE_ETC) $(MAKECMDGOALS) $(eval MAKECMDGOALS :=),:)
