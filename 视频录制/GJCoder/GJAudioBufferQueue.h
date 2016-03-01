//
//  GJAudioBufferQueue.h
//  Decoder
//
//  Created by 未成年大叔 on 16/2/28.
//  Copyright © 2016年 未成年大叔. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <pthread.h>
#import <CoreAudio/CoreAudioTypes.h>
#define MAX_FRAME_SIZE 7000
#define AUDIOQUEUE_MAX_COUNT 10

class GJAudioBufferQueue{
private:
    AudioBuffer buffer[AUDIOQUEUE_MAX_COUNT];
    long _inPointer;  //尾
    long _outPointer; //头
    int _maxBufferSize;
    
    pthread_mutex_t _mutex;
    pthread_cond_t _inCond;
    pthread_cond_t _outCond;
    
    
    pthread_mutex_t _uniqueLock;
    
    void _mutexInit();
    void _mutexDestory();
    void _mutexWait(pthread_cond_t* _cond);
    void _mutexSignal(pthread_cond_t* _cond);
    
    ~GJAudioBufferQueue();
public:
    GJAudioBufferQueue(int maxBufferSize);
    bool queuePop(AudioBuffer** temBuffer);
    bool queuePush(AudioBuffer* temBuffer);
};