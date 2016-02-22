//
//  GJAudioQueueRecode.h
//  Decoder
//
//  Created by tongguan on 16/2/22.
//  Copyright © 2016年 未成年大叔. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioQueue.h>
#import <AudioToolbox/AudioFile.h>
static const int kNumberBuffers = 3;                            // 1
typedef struct _AQRecorderState {
    AudioStreamBasicDescription  mDataFormat;                   // 2
    AudioQueueRef                mQueue;                        // 3
    AudioQueueBufferRef          mBuffers[kNumberBuffers];      // 4
    AudioFileID                  mAudioFile;                    // 5
    UInt32                       bufferByteSize;                // 6
    SInt64                       mCurrentPacket;                // 7
    bool                         mIsRunning;                    // 8
} AQRecorderState;
@interface GJAudioQueueRecode : NSObject

@end
