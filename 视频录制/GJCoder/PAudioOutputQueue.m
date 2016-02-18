//
//  PAudioOutputQueue.m
//  Decoder
//
//  Created by tongguan on 16/2/16.
//  Copyright © 2016年 未成年大叔. All rights reserved.
//

#import "PAudioOutputQueue.h"
#import <pthread/pthread.h>
#define DEFAULT_BUFFERS_COUNT 3

@interface MCAudioQueueBuffer : NSObject
@property (nonatomic,assign) AudioQueueBufferRef buffer;
@end
@implementation MCAudioQueueBuffer
- (instancetype)initWithAudioQueue:(AudioQueueRef)audioQueue bufferSize:(float)bufferSize
{
    self = [super init];
    if (self) {
        AudioQueueAllocateBuffer(audioQueue, bufferSize, &_buffer);
    }
    return self;
}
@end

@interface PAudioOutputQueue()
{
    AudioStreamBasicDescription _format;
    UInt32 _bufferSize;
    NSMutableArray* _buffers;
    NSMutableArray* _reusableBuffers;
    AudioQueueRef _audioOutputQueue;
    pthread_mutex_t _mutex;
    pthread_cond_t _cond;
    AudioTimeStamp _resumeTime;
    NSTimeInterval _playedTime;

    
}
@property (nonatomic,assign) float volume;

@end

@implementation PAudioOutputQueue
static void _AudioQueueOutputCallback(void * inUserData,AudioQueueRef inAQ,AudioQueueBufferRef inBuffer){
    PAudioOutputQueue*queue = (__bridge PAudioOutputQueue*)inUserData;
    MCAudioQueueBuffer* queueBuffer = [[MCAudioQueueBuffer alloc]init];
    queueBuffer.buffer = inBuffer;
    [queue->_reusableBuffers addObject:queueBuffer];
    
}
static void _AudioQueuePropertyListenerProc(void *inUserData,AudioQueueRef inAQ,AudioQueuePropertyID inID){

}

- (instancetype)initWithFormat:(AudioStreamBasicDescription)format bufferSize:(UInt32)bufferSize macgicCookie:(NSData*)macgicCookie
{
    self = [super init];
    if (self) {
        _bufferSize = bufferSize;
        _buffers = [[NSMutableArray alloc]init];
        _reusableBuffers = [[NSMutableArray alloc]initWithCapacity:DEFAULT_BUFFERS_COUNT];
        _format = format;
        [self _createAudioOutputQueueWithMacgicCookie:macgicCookie];
        self.volume = 1.0;
    }
    return self;
}
- (BOOL)playData:(NSData *)data packetCount:(UInt32)packetCount packetDescriptions:(AudioStreamPacketDescription *)packetDescriptions isEof:(BOOL)isEof{
    if ([data length]>_bufferSize) {
        return NO;
    }
    
    MCAudioQueueBuffer *temBuffer;
    if (_reusableBuffers.count == 0) {
        temBuffer = [[MCAudioQueueBuffer alloc]initWithAudioQueue:_audioOutputQueue bufferSize:_bufferSize];
    }else{
        temBuffer = _reusableBuffers.firstObject;
        [_reusableBuffers removeObject:temBuffer];
        
    }
    memcpy(temBuffer.buffer->mAudioData, [data bytes], [data length]);
    temBuffer.buffer->mAudioDataByteSize = (UInt32)[data length];
    
    OSStatus status = AudioQueueEnqueueBuffer(_audioOutputQueue, temBuffer.buffer, packetCount, packetDescriptions);
    [self _errorForOSStatus:status error:NULL];
    return [self start];;
}
- (NSTimeInterval)playedTime
{
    if (_format.mSampleRate == 0)
    {
        return 0;
    }
    
    AudioTimeStamp time;
    OSStatus status = AudioQueueGetCurrentTime(_audioOutputQueue, NULL, &time, NULL);
    if (status == noErr)
    {
        _playedTime = time.mSampleTime / _format.mSampleRate;
    }
    
    return _playedTime;
}
-(void)setVolume:(float)volume{
    if (volume < 0.0) {
        volume = 0.0;
    }else if(volume > 1.0){
        volume = 1.0;
    }
    _volume = volume;
    [self setParmeter:kAudioQueueParam_Volume parmeter:_volume outError:NULL];
    
}
-(void)_createAudioOutputQueueWithMacgicCookie:(NSData*)macgicCookie{

    //新建output
    OSStatus status = AudioQueueNewOutput(&_format, _AudioQueueOutputCallback, (__bridge void * _Nullable)(self), NULL, NULL, 0, &_audioOutputQueue);
    if (status != noErr) {
        NSLog(@"AudioQueueNewOutput errorCode:%d",status);
        return;
    }
    
    //新建监听
    status = AudioQueueAddPropertyListener(_audioOutputQueue, kAudioQueueProperty_IsRunning, _AudioQueuePropertyListenerProc, NULL);
    if (status != noErr) {
        NSLog(@"AudioQueueAddPropertyListener errorCode:%d",status);
        return;
    }
    
#if TARGET_OS_IPHONE
    UInt32 property = kAudioQueueHardwareCodecPolicy_PreferSoftware;
    NSError* error;
    [self setProperty:kAudioQueueProperty_HardwareCodecPolicy propertyData:&property dataSize:sizeof(UInt32) outError:&error];
#endif
    
    if (macgicCookie) {
        [self setProperty:kAudioQueueProperty_MagicCookie propertyData:[macgicCookie bytes] dataSize:(UInt32) macgicCookie.length outError:NULL];
    }
    

}
-(BOOL)setProperty:(AudioQueuePropertyID)propertyID propertyData:(const void*)propertyData dataSize:(UInt32)dataSize outError:(NSError*__autoreleasing *)outError{
    OSStatus status = AudioQueueSetProperty(_audioOutputQueue, propertyID, propertyData, dataSize);
    [self _errorForOSStatus:status error:outError];
    return status == noErr;
}

-(BOOL)setParmeter:(AudioQueueParameterID)parmeterID parmeter:(AudioQueueParameterValue)parmeter outError:(NSError*__autoreleasing *)outError{
    OSStatus status = AudioQueueSetParameter(_audioOutputQueue, parmeterID, parmeter);
    [self _errorForOSStatus:status error:outError];
    return status == noErr;
}

- (void)_errorForOSStatus:(OSStatus)status error:(NSError *__autoreleasing *)outError

{
    if (status != noErr && outError != NULL)
    {   NSError* error;
        error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
        *outError = error;
        NSLog(@"error occur:%@",[error localizedDescription]);
    }
}
- (BOOL)reset
{
    OSStatus status = AudioQueueReset(_audioOutputQueue);
    [self _errorForOSStatus:status error:NULL];
    return status == noErr;
}

- (BOOL)flush
{
    OSStatus status = AudioQueueFlush(_audioOutputQueue);
    [self _errorForOSStatus:status error:NULL];
    return status == noErr;
}
-(BOOL)stop:(BOOL)immediately{
    OSStatus status = AudioQueueStop(_audioOutputQueue, immediately);
    [self _errorForOSStatus:status error:NULL];
    return status == noErr;
}
-(BOOL)start{
    OSStatus status = AudioQueueStart(_audioOutputQueue, NULL);
    [self _errorForOSStatus:status error:NULL];
    return status == noErr;
}
-(BOOL)resume{
    return [self start];
}
- (void)_disposeAudioOutputQueue:(BOOL)inImmediate{
    if (_audioOutputQueue != NULL) {
        OSStatus status = AudioQueueDispose(_audioOutputQueue, inImmediate);
        [self _errorForOSStatus:status error:NULL];
    }
}
#pragma mark - mutex
- (void)_mutexInit
{
    pthread_mutex_init(&_mutex, NULL);
    pthread_cond_init(&_cond, NULL);
}

- (void)_mutexDestory
{
    pthread_mutex_destroy(&_mutex);
    pthread_cond_destroy(&_cond);
}

- (void)_mutexWait
{
    pthread_mutex_lock(&_mutex);
    pthread_cond_wait(&_cond, &_mutex);
    pthread_mutex_unlock(&_mutex);
}

- (void)_mutexSignal
{
    pthread_mutex_lock(&_mutex);
    pthread_cond_signal(&_cond);
    pthread_mutex_unlock(&_mutex);
}
@end
