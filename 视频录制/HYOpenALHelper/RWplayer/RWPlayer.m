//
//  RWPlayer.m
//  GuardOnLight
//
//  Created by tongguan on 15/8/10.
//  Copyright (c) 2015年 tongguantech. All rights reserved.
//

#import "RWPlayer.h"
#import <AVFoundation/AVFoundation.h>


@implementation RWPlayer
{
    NSUInteger _bufIndex;
}
RWPlayer* _private_rwPlayer;

- (id)init
{
    self = [super init];
    if (self) {
        _private_rwPlayer = self;
         _synlock = [[NSLock alloc] init];
    }
    return self;
}

//- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
//{
//    return (interfaceOrientation == UIInterfaceOrientationPortrait);
//}

-(void)startAudio
{
    [self initAudio];
//    kAudioQueueParam_Volume         = 1,
//    kAudioQueueParam_PlayRate       = 2,
//    kAudioQueueParam_Pitch          = 3,
//    kAudioQueueParam_VolumeRampTime = 4,
//    kAudioQueueParam_Pan            = 13
    AudioQueueSetParameter(_audioQueue, kAudioQueueParam_Volume, 1);
//    AudioQueueSetParameter(_audioQueue, kAudioQueueParam_VolumeRampTime, 1);
    AudioQueueStart(_audioQueue, NULL);
}

- (void)pauseAudio
{
    AudioQueuePause(_audioQueue);
}

- (void)stopAudio
{
    AudioQueueStop(_audioQueue, YES);
}


-(void)onbutton2clicked
{
    NSLog(@"onbutton2clicked");
}

#pragma mark -
#pragma mark player call back
/*
 试了下其实可以不用静态函数，但是c写法的函数内是无法调用[self ***]这种格式的写法，所以还是用静态函数通过void *input来获取原类指针
 这个回调存在的意义是为了重用缓冲buffer区，当通过AudioQueueEnqueueBuffer(outQ, outQB, 0, NULL);函数放入queue里面的音频文件播放完以后，通过这个函数通知
 调用者，这样可以重新再使用回调传回的AudioQueueBufferRef
 */
static void AudioPlayerAQInputCallback(void *input, AudioQueueRef outQ, AudioQueueBufferRef outQB)
{
    [_private_rwPlayer checkUsedQueueBuffer:outQB];
//    [_private_rwPlayer readPCMAndPlay:outQ buffer:outQB];
}



-(void)initAudio
{
    //扬声器播放
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    //默认情况下扬声器播放
    [audioSession setCategory:AVAudioSessionCategoryPlayback error:nil];
    ///设置音频参数
    _audioDescription.mSampleRate = 8000;//采样率
    _audioDescription.mFormatID = kAudioFormatLinearPCM;
    _audioDescription.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger;
    _audioDescription.mChannelsPerFrame = 1;///单声道
    _audioDescription.mFramesPerPacket = 1;//每一个packet一侦数据
    _audioDescription.mBitsPerChannel = 16;//每个采样点16bit量化
    _audioDescription.mBytesPerFrame = (_audioDescription.mBitsPerChannel/8) * _audioDescription.mChannelsPerFrame;
    _audioDescription.mBytesPerPacket = _audioDescription.mBytesPerFrame;
    ///创建一个新的从audioqueue到硬件层的通道
    //	AudioQueueNewOutput(&audioDescription, AudioPlayerAQInputCallback, self, CFRunLoopGetCurrent(), kCFRunLoopCommonModes, 0, &audioQueue);///使用当前线程播
    
    AudioQueueNewOutput(&_audioDescription, AudioPlayerAQInputCallback, (__bridge void*)self,nil, nil, 0, &_audioQueue);//使用player的内部线程播
    ////添加buffer区
    for(int i=0;i<QUEUE_BUFFER_SIZE;i++)
    {
        int result =  AudioQueueAllocateBuffer(_audioQueue, MIN_SIZE_PER_FRAME, &_audioQueueBuffers[i]);///创建buffer区，MIN_SIZE_PER_FRAME为每一侦所需要的最小的大小，该大小应该比每次往buffer里写的最大的一次还大
        NSLog(@"AudioQueueAllocateBuffer i = %d,result = %d",i,result);
    }
}

-(void)addBuf:(char*)buf size:(long)size
{
    NSLog(@"addbuf");
    [_synlock lock];

    AudioQueueBufferRef   buffer = (AudioQueueBufferRef)_audioQueueBuffers[_bufIndex%QUEUE_BUFFER_SIZE];
    buffer->mAudioDataByteSize = (UInt32)size;
    memcpy(buffer->mAudioData, buf, size);
    AudioQueueEnqueueBuffer(_audioQueue, buffer, 0, NULL);
    
//    [self readPCMAndPlay:_audioQueue buffer:audioQueueBuffers[_bufIndex%QUEUE_BUFFER_SIZE] Size:(int)size buf:buf];
    _bufIndex ++;
    [_synlock unlock];
}


-(void)readPCMAndPlay:(AudioQueueRef)outQ buffer:(AudioQueueBufferRef)outQB Size:(int)size buf:(void*)buf
{
    [_synlock lock];
    int readLength = size;
    NSLog(@"read raw data size = %d",readLength);
    outQB->mAudioDataByteSize = readLength;
    void *audiodata = (void *)outQB->mAudioData;
    memcpy(audiodata, buf, size);
    
    
    /*
     将创建的buffer区添加到audioqueue里播放
     AudioQueueBufferRef用来缓存待播放的数据区，AudioQueueBufferRef有两个比较重要的参数，AudioQueueBufferRef->mAudioDataByteSize用来指示数据区大小，AudioQueueBufferRef->mAudioData用来保存数据区
     */
    AudioQueueEnqueueBuffer(outQ, outQB, 0, NULL);
    [_synlock unlock];
}

-(void)checkUsedQueueBuffer:(AudioQueueBufferRef) qbuf
{
    if(qbuf == _audioQueueBuffers[0])
    {
        NSLog(@"AudioPlayerAQInputCallback,bufferindex = 0");
    }
    if(qbuf == _audioQueueBuffers[1])
    {
        NSLog(@"AudioPlayerAQInputCallback,bufferindex = 1");
    }
    if(qbuf == _audioQueueBuffers[2])
    {
        NSLog(@"AudioPlayerAQInputCallback,bufferindex = 2");
    }
    if(qbuf == _audioQueueBuffers[3])
    {
        NSLog(@"AudioPlayerAQInputCallback,bufferindex = 3");
    }
    if(qbuf == _audioQueueBuffers[4])
    {
        NSLog(@"AudioPlayerAQInputCallback,bufferindex = 4");
    }
    if(qbuf == _audioQueueBuffers[5])
    {
        NSLog(@"AudioPlayerAQInputCallback,bufferindex = 5");
    }
    if(qbuf == _audioQueueBuffers[6])
    {
        NSLog(@"AudioPlayerAQInputCallback,bufferindex = 6");
    }
    if(qbuf == _audioQueueBuffers[7])
    {
        NSLog(@"AudioPlayerAQInputCallback,bufferindex = 7");
    }
}

@end
