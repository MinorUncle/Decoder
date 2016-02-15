//
//  RWPlayer.h
//  GuardOnLight
//
//  Created by tongguan on 15/8/10.
//  Copyright (c) 2015年 tongguantech. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

#define QUEUE_BUFFER_SIZE 10 //队列缓冲个数
#define MIN_SIZE_PER_FRAME 1000 //每侦最小数据长度


@interface RWPlayer : NSObject
{
    AudioStreamBasicDescription _audioDescription;///音频参数
    AudioQueueRef _audioQueue;//音频播放队列
    AudioQueueBufferRef _audioQueueBuffers[QUEUE_BUFFER_SIZE];//音频缓存
    NSLock *_synlock ;///同步控制
}

-(void)startAudio;
- (void)pauseAudio;
- (void)stopAudio;

-(void)addBuf:(char*)buf size:(long)size;
-(void)checkUsedQueueBuffer:(AudioQueueBufferRef) qbuf;

@end
