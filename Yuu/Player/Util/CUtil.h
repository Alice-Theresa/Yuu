//
//  CUtil.h
//  Yuu
//
//  Created by Skylar on 2019/9/25.
//  Copyright © 2019 Skylar. All rights reserved.
//

#ifndef CUtil_h
#define CUtil_h

#import <VideoToolbox/VideoToolbox.h>
#include <stdio.h>

long YuuYUVChannelFilterNeedSize(long linesize, long width, long height);
void YuuYUVChannelFilter(uint8_t * src,
                         long linesize,
                         long width,
                         long height,
                         uint8_t * dst,
                         size_t dstsize);

void YuuDidDecompress(void *decompressionOutputRefCon,
                      void *sourceFrameRefCon,
                      OSStatus status,
                      VTDecodeInfoFlags infoFlags,
                      CVImageBufferRef pixelBuffer,
                      CMTime presentationTimeStamp,
                      CMTime presentationDuration);

#endif /* CUtil_h */
