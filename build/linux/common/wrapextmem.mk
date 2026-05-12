########################################################################### ###
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

# SUPPORT_WRAP_EXTMEM enables support for the Services API function
# PVRSRVWrapExtMem() which takes a CPU virtual address with size and imports the
# physical memory behind it into Services for use with the GPU.
#
# It's always available in the kmd but user mode components can be built without

$(if $(filter command line environment,$(origin SUPPORT_WRAP_EXTMEM)),\
    $(error Error: SUPPORT_WRAP_EXTMEM is a platform property\
            defined in every platform Makefile, it should not\
            be defined as a build option on the command line.))

# The platform Makefile should set SUPPORT_WRAP_EXTMEM to whatever value makes
# sense for the platform. If the platform Makefile doesn't define it, then an
# error is raised.
ifndef SUPPORT_WRAP_EXTMEM
 $(error The platform Makefile doesn't explicitly set SUPPORT_WRAP_EXTMEM=0|1 as required)
endif

# In the lines below we tweak the value set in the platform Makefile, but in
# normal case we trust SUPPORT_WRAP_EXTMEM supplied in the platform Makefile.

# If PDUMP is activated then we disable wrap external memory no matter what
ifeq ($(PDUMP),1)
 SUPPORT_WRAP_EXTMEM := 0
endif

# If external memory isn't supported, we forcibly disable wrap extmem (TC-like
# systems only)
ifeq ($(TC_MEMORY_CONFIG),TC_MEMORY_LOCAL)
 SUPPORT_WRAP_EXTMEM := 0
endif

# (debug output to be removed when the feature is stable)
$(info ******* Wrap Extmem:         $(SUPPORT_WRAP_EXTMEM))

# bridges.mk (which may be included much later) needs SUPPORT_WRAP_EXTMEM
$(eval $(call TunableBothConfigMake,SUPPORT_WRAP_EXTMEM,SUPPORT_WRAP_EXTMEM))

$(eval $(call TunableBothConfigC,SUPPORT_WRAP_EXTMEM,SUPPORT_WRAP_EXTMEM))
