//
//  HYOpenALHelper.m
//  BTDemo
//
//  Created by crte on 13-8-16.
//  Copyright (c) 2013年 Shadow. All rights reserved.
//

#import "HYOpenALHelper.h"
#import <AVFoundation/AVFoundation.h>
@implementation HYOpenALHelper
{
    NSLock * _lock;
}
@synthesize outSourceID;

- (BOOL)initOpenAL
{
    if (!self.mDevice) {
        self.mDevice = alcOpenDevice(NULL);
    }
    if (!self.mDevice) {
        return NO;
    }
    if (!self.mContext) {
        self.mContext = alcCreateContext(self.mDevice, NULL);
        alcMakeContextCurrent(self.mContext);
    }
    
    //创建音源
    alGenSources(1, &outSourceID);
    //设为不循环
    alSourcei(outSourceID, AL_LOOPING, AL_FALSE);
    //播放模式设为流式播放
    alSourcef(outSourceID, AL_SOURCE_TYPE, AL_STREAMING);
    //设置播放音量
    alSourcef(outSourceID, AL_GAIN, 0.5);
    //设置播放速度, (无效, 不知道为何)
    alSpeedOfSound(0.5);
    
    //清除错误
    alGetError();
    
    //设置定时器
    self.timer = [NSTimer scheduledTimerWithTimeInterval:0.05
                                                  target:self
                                                selector:@selector(cleanBuffers)
                                                userInfo:nil repeats:YES];
    
    //扬声器播放
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    //默认情况下扬声器播放
    [audioSession setCategory:AVAudioSessionCategoryPlayback error:nil];
    
    _lock = [[NSLock alloc]init];
    
    if (!self.mContext) {
        return NO;
    }
    return YES;
}

- (void)insertPCMDataToQueue:(unsigned char *)data size:(UInt32)size samplerate:(long)samplerate bitPerFrame:(long)bitPerFrame channels:(long)channels
{
    [_lock lock];
    @synchronized(self) {
        ALenum error;
        
        //读取错误信息
        error = alGetError();
        if (error != AL_NO_ERROR) {
            NSLog(@"插入PCM数据时发生错误, 错误信息: %d", error);
            [self cleanBuffers];
            [_lock unlock];
            return;
        }
        //常规安全性判断
        if (data == NULL) {
            NSLog(@"插入PCM数据为空, 返回");
            [self cleanBuffers];
            [_lock unlock];
            return;
        }
        
        //建立缓存区
        ALuint bufferID = 0;
        alGenBuffers(1, &bufferID);
        
        error = alGetError();
        if (error != AL_NO_ERROR) {
            NSLog(@"建立缓存区发生错误, 错误信息: %d", error);
            [self cleanBuffers];
            [_lock unlock];
            return;
        }
        
        //将数据存入缓存区
        NSData *nData = [NSData dataWithBytes:data length:size];
        
        if (bitPerFrame == 8&&channels == 1) {
            alBufferData(bufferID, AL_FORMAT_MONO8, (char *)[nData bytes], (ALsizei)[nData length], (int)samplerate);
        }
        else if (bitPerFrame == 16&&channels == 1)
        {
            alBufferData(bufferID, AL_FORMAT_MONO16, (char *)[nData bytes], (ALsizei)[nData length],  (int)samplerate);
        }
        else if (bitPerFrame == 8&&channels == 2)
        {
            alBufferData(bufferID, AL_FORMAT_STEREO8, (char *)[nData bytes], (ALsizei)[nData length],  (int)samplerate);
        }
        else if (bitPerFrame == 16&&channels == 2)
        {
            alBufferData(bufferID, AL_FORMAT_STEREO16, (char *)[nData bytes], (ALsizei)[nData length],  (int)samplerate);
        }
        
        
        error = alGetError();
        if (error != AL_NO_ERROR) {
            NSLog(@"向缓存区内插入数据发生错误, 错误信息: %d", error);
            [self cleanBuffers];
            [_lock unlock];
            return;
        }
        
        //添加到队列
        alSourceQueueBuffers(outSourceID, 1, &bufferID);
        
        error = alGetError();
        if (error != AL_NO_ERROR) {
            NSLog(@"将缓存区插入队列发生错误, 错误信息: %d", error);
            [self cleanBuffers];
            [_lock unlock];
            return;
        }
        //开始播放
        [self play];
    }
    [_lock unlock];
}

- (void)play
{
    ALint state;
    alGetSourcei(outSourceID, AL_SOURCE_STATE, &state);
    
    if (state != AL_PLAYING) {
        alSourcePlay(outSourceID);
    }
}

- (void)stop
{
    [self clean];
    ALint state;
    alGetSourcei(outSourceID, AL_SOURCE_STATE, &state);
    
    if (state != AL_STOPPED) {
        alSourceStop(outSourceID);
    }

}

- (void)clean
{
    //停止定时器
    [self.timer invalidate];
    self.timer = nil;
    //删除声源
    alDeleteSources(1, &outSourceID);
    //删除环境
    alcDestroyContext(self.mContext);
    //关闭设备
    alcCloseDevice(self.mDevice);
    
}

- (void)getInfo
{
    ALint queued;
    ALint processed;
    alGetSourcei(outSourceID, AL_BUFFERS_PROCESSED, &processed);
    alGetSourcei(outSourceID, AL_BUFFERS_QUEUED, &queued);
    NSLog(@"process = %d, queued = %d", processed, queued);
}


//清除已播放完成的缓存区
- (void)cleanBuffers
{
    ALint processed;
    alGetSourcei(outSourceID, AL_BUFFERS_PROCESSED, &processed);
    
    while (processed--) {
        ALuint bufferID;
        alSourceUnqueueBuffers(outSourceID, 1, &bufferID);
        alDeleteBuffers(1, &bufferID);
    }
}

@end
