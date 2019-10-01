//
//  CUtil.c
//  Yuu
//
//  Created by Skylar on 2019/9/25.
//  Copyright © 2019 Skylar. All rights reserved.
//

#define MIN(X, Y) (((X) < (Y)) ? (X) : (Y))

#include "CUtil.h"
#import <Accelerate/Accelerate.h>
#import <libavformat/avformat.h>

long YuuYUVChannelFilterNeedSize(long linesize, long width, long height) {
    width = MIN(linesize, width);
    return width * height;
}

void YuuYUVChannelFilter(uint8_t * src,
                         long linesize,
                         long width,
                         long height,
                         uint8_t * dst,
                         size_t dstsize) {
    width = MIN(linesize, width);
    uint8_t * temp = dst;
    memset(dst, 0, dstsize);
    for (int i = 0; i < height; i++) {
        memcpy(temp, src, width);
        temp += width;
        src += linesize;
    }
}

void YuuDidDecompress(void *decompressionOutputRefCon,
                      void *sourceFrameRefCon,
                      OSStatus status,
                      VTDecodeInfoFlags infoFlags,
                      CVImageBufferRef pixelBuffer,
                      CMTime presentationTimeStamp,
                      CMTime presentationDuration) {
    CVPixelBufferRef *outputPixelBuffer = (CVPixelBufferRef *)sourceFrameRefCon;
    *outputPixelBuffer = CVPixelBufferRetain(pixelBuffer);
}
