//
//  GJAudioQueueRecode.m
//  Decoder
//
//  Created by tongguan on 16/2/22.
//  Copyright © 2016年 未成年大叔. All rights reserved.
//

#import "GJAudioQueueRecode.h"
@interface GJAudioQueueRecode()
{
   
}
@end
 AQRecorderState *pAqData;
@implementation GJAudioQueueRecode
static void HandleInputBuffer (
                               void                                *aqData,             // 1
                               AudioQueueRef                       inAQ,                // 2
                               AudioQueueBufferRef                 inBuffer,            // 3
                               const AudioTimeStamp                *inStartTime,        // 4
                               UInt32                              inNumPackets,        // 5
                               const AudioStreamPacketDescription  *inPacketDesc        // 6
){
    AQRecorderState *pAqData = (AQRecorderState *) aqData;               // 1
    
    if (inNumPackets == 0 && pAqData->mDataFormat.mBytesPerPacket != 0)
        inNumPackets = inBuffer->mAudioDataByteSize / pAqData->mDataFormat.mBytesPerPacket;
    
    OSStatus status = AudioFileWritePackets (pAqData->mAudioFile,false,inBuffer->mAudioDataByteSize,inPacketDesc,pAqData->mCurrentPacket,&inNumPackets,inBuffer->mAudioData);
    if (status == noErr) {
        pAqData->mCurrentPacket += inNumPackets;                     // 4
    }
    if (pAqData->mIsRunning == 0)return;
    
    AudioQueueEnqueueBuffer (                                            // 6
                             pAqData->mQueue,
                             inBuffer,
                             0,
                             NULL
                             );

};

void DeriveBufferSize (AudioQueueRef audioQueue,AudioStreamBasicDescription  ASBDescription, Float64 seconds, UInt32                       *outBufferSize) {
    static const int maxBufferSize = 0x50000;                 // 5
    
    int maxPacketSize = ASBDescription.mBytesPerPacket;       // 6
    if (maxPacketSize == 0) {                                 // 7
        UInt32 maxVBRPacketSize = sizeof(maxPacketSize);
        AudioQueueGetProperty (
                               audioQueue,
                               kAudioQueueProperty_MaximumOutputPacketSize,
                               // in Mac OS X v10.5, instead use
                               //   kAudioConverterPropertyMaximumOutputPacketSize
                               &maxPacketSize,
                               &maxVBRPacketSize
                               );
    }
    
    Float64 numBytesForTime = ASBDescription.mSampleRate * maxPacketSize * seconds; // 8
    *outBufferSize = (UInt32)(numBytesForTime < maxBufferSize ? numBytesForTime : maxBufferSize);                     // 9
}

OSStatus SetMagicCookieForFile (AudioQueueRef inQueue,AudioFileID   inFile) {
    OSStatus result = noErr;                                    // 3
    UInt32 cookieSize;                                          // 4
    
    OSStatus status = AudioQueueGetPropertySize (inQueue,kAudioQueueProperty_MagicCookie,&cookieSize);
    if (status == noErr) {
        char* magicCookie =(char *) malloc (cookieSize);                       // 6
        status =AudioQueueGetProperty (inQueue,kAudioQueueProperty_MagicCookie,magicCookie,&cookieSize);
        if (status == noErr)
            result = AudioFileSetProperty ( inFile,kAudioFilePropertyMagicCookieData,cookieSize,magicCookie);
        free (magicCookie);                                     // 9
    }
    return result;                                              // 10
}

@end
