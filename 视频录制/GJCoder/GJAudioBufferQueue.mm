//
//  GJAudioBufferQueue.m
//  Decoder
//
//  Created by 未成年大叔 on 16/2/28.
//  Copyright © 2016年 未成年大叔. All rights reserved.
//

#import "GJAudioBufferQueue.h"
GJAudioBufferQueue::GJAudioBufferQueue(int maxBufferSize){
    _maxBufferSize = maxBufferSize;
    _inPointer = 0;
    _outPointer = 0;
    _mutexInit();
    
    for (int i = 0; i< AUDIOQUEUE_MAX_COUNT; i++) {
        buffer[i].mData = malloc(_maxBufferSize);
        buffer[i].mDataByteSize = 0;
        buffer[i].mNumberChannels = 1;
    }
    
}

bool GJAudioBufferQueue::queuePop(AudioBuffer** temBuffer){
    bool result = YES;
    pthread_mutex_lock(&_uniqueLock);
    if (_inPointer <= _outPointer) {
        pthread_mutex_unlock(&_uniqueLock);
        printf("begin Wait in ----------\n");
        
        _mutexWait(&_inCond);
        pthread_mutex_lock(&_uniqueLock);
        
        printf("after Wait in.  incount:%ld  outcount:%ld----------\n",_inPointer,_outPointer);
        
    }
    
    *temBuffer = &buffer[_outPointer%AUDIOQUEUE_MAX_COUNT];
    _outPointer++;
    _mutexSignal(&_outCond);
    printf("after signal out.  incount:%ld  outcount:%ld----------\n",_inPointer,_outPointer);
    
    
    pthread_mutex_unlock(&_uniqueLock);
    
    
    
    //assert(result);
    return result;
}
bool GJAudioBufferQueue::queuePush(AudioBuffer* temBuffer){
    bool result = true;
    if ( temBuffer->mDataByteSize >= _maxBufferSize) { //留最后一个外部使用缓冲
        result = false;
    }else{
        pthread_mutex_lock(&_uniqueLock);
        if ((_inPointer % AUDIOQUEUE_MAX_COUNT == _outPointer % AUDIOQUEUE_MAX_COUNT && _inPointer > _outPointer)) {
            pthread_mutex_unlock(&_uniqueLock);
            printf("begin Wait out ----------\n");
            
            _mutexWait(&_outCond);
            pthread_mutex_lock(&_uniqueLock);
            printf("after Wait out.  incount:%ld  outcount:%ld----------\n",_inPointer,_outPointer);
        }
        long temInPointer = _inPointer;
        _inPointer++;
        _mutexSignal(&_inCond);
        printf("after signal in. incount:%ld  outcount:%ld----------\n",_inPointer,_outPointer);
        pthread_mutex_unlock(&_uniqueLock);
        
        buffer[temInPointer%AUDIOQUEUE_MAX_COUNT].mDataByteSize = temBuffer->mDataByteSize;
        buffer[temInPointer%AUDIOQUEUE_MAX_COUNT].mNumberChannels = temBuffer->mNumberChannels;
        memcpy(buffer[temInPointer%AUDIOQUEUE_MAX_COUNT].mData , temBuffer->mData, temBuffer->mDataByteSize);
    }
    assert(result);
    return result;
}

void GJAudioBufferQueue::_mutexInit()
{
    pthread_mutex_init(&_mutex, NULL);
    pthread_cond_init(&_inCond, NULL);
    pthread_cond_init(&_outCond, NULL);
    
    pthread_mutex_init(&_uniqueLock, NULL);
    
    
}

void GJAudioBufferQueue::_mutexDestory()
{
    pthread_mutex_destroy(&_mutex);
    pthread_cond_destroy(&_inCond);
    pthread_cond_destroy(&_outCond);
    
    pthread_mutex_destroy(&_uniqueLock);
    
    
}

void GJAudioBufferQueue::_mutexWait(pthread_cond_t* _cond)
{
    pthread_mutex_lock(&_mutex);
    pthread_cond_wait(_cond, &_mutex);
    pthread_mutex_unlock(&_mutex);
}

void GJAudioBufferQueue::_mutexSignal(pthread_cond_t* _cond)
{
    pthread_mutex_lock(&_mutex);
    pthread_cond_signal(_cond);
    pthread_mutex_unlock(&_mutex);
}

GJAudioBufferQueue::~GJAudioBufferQueue(){
    _mutexDestory();
    for (int i = 0; i< AUDIOQUEUE_MAX_COUNT; i++) {
        free(buffer[i].mData) ;
    }
}