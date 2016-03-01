//
//  PCMDecodeFromAAC.m
//  视频录制
//
//  Created by tongguan on 16/1/8.
//  Copyright © 2016年 未成年大叔. All rights reserved.
//


#import "GJAudioBufferQueue.h"
#import "PCMDecodeFromAAC.h"

@interface PCMDecodeFromAAC ()
{
    AudioConverterRef _decodeConvert;
    GJAudioBufferQueue* _resumeQueue;
    AudioStreamPacketDescription _inPacketDescript;
    BOOL _isRunning;//状态，是否运行
    int _sourceMaxLenth;
    
    UInt32 _outputDataPacketCount; //转码出去包的个数

}
@property(nonatomic,assign)AudioBufferList* outCacheBufferList;

@end

@implementation PCMDecodeFromAAC
- (instancetype)initWithDestDescription:(AudioStreamBasicDescription*)destDescription SourceDescription:(AudioStreamBasicDescription*)sourceDescription sourceMaxBufferLenth:(int)maxLenth;
{
    self = [super init];
    if (self) {
        
        if (sourceDescription != NULL) {
            _sourceFormatDescription = *sourceDescription;
            _sourceMaxLenth = maxLenth;
        }else{
            [self initDefaultSourceFormateDescription];
        }
        
        if (destDescription != NULL) {
            _destFormatDescription = *destDescription;
        }else{
            [self initDefaultDestFormatDescription];
        }
        
        _resumeQueue = new GJAudioBufferQueue(maxLenth);
        _outputDataPacketCount = 1024;
        
    }
    return self;
}


- (instancetype)init
{
    self = [super init];
    if (self) {
        [self initDefaultDestFormatDescription];
        [self initDefaultSourceFormateDescription];
      
        
        _resumeQueue = new GJAudioBufferQueue(MAX_FRAME_SIZE);
    }
    return self;
}
-(void)initDefaultSourceFormateDescription{
    _sourceMaxLenth = 6000;
    
    memset(&_sourceFormatDescription, 0, sizeof(_sourceFormatDescription));
    _sourceFormatDescription.mChannelsPerFrame = 1;
    _sourceFormatDescription.mFramesPerPacket = 1024;
    _sourceFormatDescription.mSampleRate = 44100;
    _sourceFormatDescription.mFormatID = kAudioFormatMPEG4AAC;  //aac
    
}
-(void)initDefaultDestFormatDescription{
    memset(&_destFormatDescription, 0, sizeof(_destFormatDescription));
    _destFormatDescription.mChannelsPerFrame = 1;
    _destFormatDescription.mSampleRate = 44100;
    _destFormatDescription.mFormatID = kAudioFormatLinearPCM; //PCM
    _destFormatDescription.mBitsPerChannel = 16;
    _destFormatDescription.mBytesPerPacket = _destFormatDescription.mBytesPerFrame =_destFormatDescription.mChannelsPerFrame *  _destFormatDescription.mBitsPerChannel;
    _destFormatDescription.mFramesPerPacket = 1;
    _destFormatDescription.mFormatFlags = kLinearPCMFormatFlagIsPacked | kLinearPCMFormatFlagIsSignedInteger; // little-endian
}

//编码输入
static OSStatus encodeInputDataProc(AudioConverterRef inConverter, UInt32 *ioNumberDataPackets, AudioBufferList *ioData,AudioStreamPacketDescription **outDataPacketDescription, void *inUserData)
{ //<span style="font-family: Arial, Helvetica, sans-serif;">AudioConverterFillComplexBuffer 编码过程中，会要求这个函数来填充输入数据，也就是原始PCM数据</span>
   
    GJAudioBufferQueue* param =   ((__bridge PCMDecodeFromAAC*)inUserData)->_resumeQueue;
    AudioBuffer * popBuffer;
    AudioStreamPacketDescription* description = (AudioStreamPacketDescription*)&(((__bridge PCMDecodeFromAAC*)inUserData)->_inPacketDescript);

    if (param->queuePop(&popBuffer)) {
        ioData->mBuffers[0].mData = popBuffer->mData;
        ioData->mBuffers[0].mNumberChannels = popBuffer->mNumberChannels;
        ioData->mBuffers[0].mDataByteSize = popBuffer->mDataByteSize;
        *ioNumberDataPackets = 1;
        
        description->mDataByteSize = ioData->mBuffers[0].mDataByteSize ;
        description->mStartOffset = 0;
        description->mVariableFramesInPacket = 0;
        
    }else{
        *ioNumberDataPackets = 0;
        return -1;
    }
    
    if (outDataPacketDescription) {

        *outDataPacketDescription = description;
    }
    
    return noErr;
}

-(void)decodeBuffer:(uint8_t*)data withLenth:(uint32_t)totalLenth{
    AudioBuffer buffer;
    buffer.mData = data;
    buffer.mDataByteSize = totalLenth;
    buffer.mNumberChannels = _sourceFormatDescription.mChannelsPerFrame;
    _resumeQueue->queuePush(&buffer);
    
    [self _createEncodeConverter];
}

-(AudioBufferList *)outCacheBufferList{
    if (_outCacheBufferList == nil) {
        _outCacheBufferList = (AudioBufferList*)malloc(sizeof(AudioBufferList));
        
        _outCacheBufferList->mNumberBuffers = 1;
        _outCacheBufferList->mBuffers[0].mNumberChannels = 1;
        _outCacheBufferList->mBuffers[0].mData = (void*)malloc(MAX_FRAME_SIZE);
        _outCacheBufferList->mBuffers[0].mDataByteSize = MAX_FRAME_SIZE;
    }
    return _outCacheBufferList;
}


-(BOOL)_createEncodeConverter{
    if (_decodeConvert != NULL) {
        return YES;
    }
    UInt32 size = sizeof(AudioStreamBasicDescription);
    AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, NULL, &size, &_destFormatDescription);
    AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, NULL, &size, &_sourceFormatDescription);
    

    OSStatus status = AudioConverterNew(&_sourceFormatDescription, &_destFormatDescription, &_decodeConvert);
    assert(!status);
    NSLog(@"AudioConverterNewSpecific success");

    _destMaxOutSize = 0;
    status = AudioConverterGetProperty(_decodeConvert, kAudioConverterPropertyMaximumOutputPacketSize, &size, &_destMaxOutSize);
    assert(!status);
    _destMaxOutSize *= _outputDataPacketCount;

    
    AudioConverterGetProperty(_decodeConvert, kAudioConverterCurrentInputStreamDescription, &size, &_sourceFormatDescription);
    
    AudioConverterGetProperty(_decodeConvert, kAudioConverterCurrentOutputStreamDescription, &size, &_destFormatDescription);
    
    [self performSelectorInBackground:@selector(_converterStart) withObject:nil];
    return YES;
}


-(void)_converterStart{
    
    _isRunning = YES;
    AudioStreamPacketDescription packetDesc;
    while (_isRunning) {
        memset(&packetDesc, 0, sizeof(packetDesc));
        self.outCacheBufferList->mBuffers[0].mDataByteSize = MAX_FRAME_SIZE;
        OSStatus status = AudioConverterFillComplexBuffer(_decodeConvert, encodeInputDataProc, (__bridge void*)self, &_outputDataPacketCount, self.outCacheBufferList, &packetDesc);
        // assert(!status);
        if (status != noErr || status == -1) {
            char* codeChar = (char*)&status;
            NSLog(@"AudioConverterFillComplexBufferError：%c%c%c%c CODE:%d",codeChar[3],codeChar[2],codeChar[1],codeChar[0],status);
            return;
        }

        static int j =0;
        NSLog(@"decode out times:%d",j++);
        
        if ([self.delegate respondsToSelector:@selector(pcmDecode:completeBuffer:lenth:)]) {
            [self.delegate pcmDecode:self completeBuffer:self.outCacheBufferList->mBuffers[0].mData lenth:self.outCacheBufferList->mBuffers[0].mDataByteSize];
        }
    }
}

-(void)dealloc{
    free(_outCacheBufferList);
}

#pragma mark - mutex

@end
