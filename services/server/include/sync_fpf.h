/*************************************************************************/ /*!
@File           sync_fpf.h
@Title          Common functions for fast path fence sync.
@Codingstyle    IMG
@Copyright      Copyright (c) Imagination Technologies Ltd. All Rights Reserved
@Description    Common functions for fast path fence sync module. Handles
                sync checkpoint setup and Token correlation.
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

#if !defined(SYNC_FPF_H)
#define SYNC_FPF_H

#include "img_types.h"
#include "device.h"
#include "rgx_fwif_fpf.h"



/***************************************************************************/ /*!
@Function       FPFSyncCheckpointAlloc
@Description    Allocate a new FPF synchronisation checkpoint on the specified
                synchronisation checkpoint context.
@Input          psSyncContext           Handle to the synchronisation
                                        checkpoint context
@Input          hTimeline               Timeline on which this sync
                                        checkpoint is being created
@Input          hFence                  Fence as passed into pfnFenceResolve
                                        API, when the API encounters a non-PVR
                                        fence as part of its input fence. From
                                        all other places this argument must be
                                        PVRSRV_NO_FENCE.
@Input          pszCheckpointName       Sync checkpoint source annotation
                                        (will be truncated to at most
                                         PVRSRV_SYNC_NAME_LENGTH chars)
@Input          uiToken                 FPF Token used to create the sync
                                        checkpoint.
@Output         ppsSyncCheckpoint       Created synchronisation checkpoint
@Return         PVRSRV_OK if the synchronisation checkpoint was
                                        successfully allocated
@Return         PVRSRV_ERROR            Otherwise
*/ /***************************************************************************/
PVRSRV_ERROR
FPFSyncCheckpointAlloc(PSYNC_CHECKPOINT_CONTEXT psSyncContext,
                       PVRSRV_TIMELINE hTimeline,
                       PVRSRV_FENCE hFence,
                       const IMG_CHAR *pszCheckpointName,
                       PVRSRV_FAST_PATH_FENCE_TOKEN uiToken,
                       PSYNC_CHECKPOINT *ppsSyncCheckpoint);

/***************************************************************************/ /*!
@Function       FPFSyncCheckpointFree
@Description    Free a FPF synchronisation checkpoint.
                The reference count held for the synchronisation checkpoint
                is decremented - if it has becomes zero, it is also freed.
@Input          psSyncCheckpoint        The synchronisation checkpoint to free
@Return         None
*/ /***************************************************************************/
PVRSRV_ERROR
FPFSyncCheckpointFree(PSYNC_CHECKPOINT psSyncCheckpoint);


#endif /* SYNC_FPF_H */
