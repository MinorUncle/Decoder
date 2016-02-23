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
@class GJAudioQueueRecoder;

@protocol GJAudioQueueRecoderDelegate <NSObject>
@optional
//回调不带头信息
-(void)GJAudioQueueRecoder:(GJAudioQueueRecoder*) recoder streamData:(void*)data lenth:(int)lenth packetCount:(int)packetCount packetDescriptions:(const AudioStreamPacketDescription *)packetDescriptions;

@end
@interface GJAudioQueueRecoder : NSObject
@property(nonatomic,assign)AQRecorderState *pAqData;
@property(nonatomic,weak)id<GJAudioQueueRecoderDelegate> delegate;

- (instancetype)initWithPath:(NSString*)path fileType:(AudioFileTypeID)fileType;
- (instancetype)initWithStreamFormat:(AudioFormatID)formatID;

-(BOOL)startRecodeAudio;
-(void)stop;

@end
