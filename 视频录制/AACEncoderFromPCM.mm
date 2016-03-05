//
//  PCMEncoderToAAC.m
//  视频录制
//
//  Created by tongguan on 16/1/8.
//  Copyright © 2016年 未成年大叔. All rights reserved.
//
#import "GJAudioBufferQueue.h"
#import "AACEncoderFromPCM.h"


@interface AACEncoderFromPCM ()
{
    AudioConverterRef _encodeConvert;
    AudioBufferList _outCacheBufferList;
    GJAudioBufferQueue* _resumeQueue;
    BOOL _isRunning;//状态，是否运行
    
    AudioStreamPacketDescription _sourcePCMPacketDescription;
}
@end

@implementation AACEncoderFromPCM
- (instancetype)initWithDestDescription:(AudioStreamBasicDescription)description
{
    self = [super init];
    if (self) {
        _destFormatDescription = description;
    }
    return self;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        
        memset(&_destFormatDescription, 0, sizeof(_destFormatDescription));
        _destFormatDescription.mChannelsPerFrame = 1;
        _destFormatDescription.mFramesPerPacket = 1024;
        _destFormatDescription.mSampleRate = 44100;
        _destFormatDescription.mFormatID = kAudioFormatMPEG4AAC;  //aac

        _outCacheBufferList.mNumberBuffers = 1;
        _outCacheBufferList.mBuffers[0].mNumberChannels = 1;
        _outCacheBufferList.mBuffers[0].mData = (void*)malloc(MAX_FRAME_SIZE);
        _outCacheBufferList.mBuffers[0].mDataByteSize = MAX_FRAME_SIZE;
    }
    return self;
}
//编码输入
static OSStatus encodeInputDataProc(AudioConverterRef inConverter, UInt32 *ioNumberDataPackets, AudioBufferList *ioData,AudioStreamPacketDescription **outDataPacketDescription, void *inUserData)
{ //<span style="font-family: Arial, Helvetica, sans-serif;">AudioConverterFillComplexBuffer 编码过程中，会要求这个函数来填充输入数据，也就是原始PCM数据</span>

    
    GJAudioBufferQueue* param =   ((__bridge AACEncoderFromPCM*)inUserData)->_resumeQueue;
    AudioBuffer * popBuffer;
    if (param->queuePop(&popBuffer)) {
        ioData->mBuffers[0].mData = popBuffer->mData;
        ioData->mBuffers[0].mNumberChannels = popBuffer->mNumberChannels;
        ioData->mBuffers[0].mDataByteSize = popBuffer->mDataByteSize;
        
        AudioStreamBasicDescription* baseDescription = &(((__bridge AACEncoderFromPCM*)inUserData)->_sourceFormatDescription);
        *ioNumberDataPackets = ioData->mBuffers[0].mDataByteSize / baseDescription->mBytesPerPacket;

    }else{
        *ioNumberDataPackets = 0;
        return -1;
    }
    
    if (outDataPacketDescription) {
        AudioStreamPacketDescription* packetDesc = &(((__bridge AACEncoderFromPCM*)inUserData)->_sourcePCMPacketDescription);
        packetDesc->mStartOffset = 0;
        packetDesc->mDataByteSize = ioData->mBuffers[0].mDataByteSize;
        packetDesc->mVariableFramesInPacket = 0;
    }
    return noErr;
}

-(void)encodeWithBuffer:(CMSampleBufferRef)sampleBuffer{
    
    AudioBufferList inBufferList;
    CMBlockBufferRef blockBuffer;
    OSStatus status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sampleBuffer, nil, &inBufferList, sizeof(inBufferList), NULL, NULL, 0, &blockBuffer);
    assert(!status);
    if (status != noErr) {
        NSLog(@"CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer error:%d",status);
        return;
    }
    assert(inBufferList.mBuffers[0].mDataByteSize <= 3000);

    if (_resumeQueue == nil) {
         _resumeQueue = new GJAudioBufferQueue(inBufferList.mBuffers[0].mDataByteSize+10);
    }
    
    _resumeQueue->queuePush(&inBufferList.mBuffers[0]);
    
    CFRelease(blockBuffer);
    [self _createEncodeConverterWithBuffer:sampleBuffer];

}

-(BOOL)_createEncodeConverterWithBuffer:(CMSampleBufferRef)sampleBuffer{
    if (_encodeConvert != NULL) {
        return YES;
    }
    
    const AudioStreamBasicDescription* sourceFormat = CMAudioFormatDescriptionGetStreamBasicDescription(CMSampleBufferGetFormatDescription(sampleBuffer));
    assert(sourceFormat);
    if (sourceFormat != NULL) {
        _sourceFormatDescription = *sourceFormat;
    }else{
        return false;
    }

    UInt32 size = sizeof(AudioStreamBasicDescription);
    AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, NULL, &size, &_destFormatDescription);
    AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, NULL, &size, &_sourceFormatDescription);

    
    AudioClassDescription audioClass;
   OSStatus status = [self _getAudioClass:&audioClass WithType:_destFormatDescription.mFormatID fromManufacturer:kAppleSoftwareAudioCodecManufacturer];
    assert(!status);
    status = AudioConverterNewSpecific(&_sourceFormatDescription, &_destFormatDescription, 1, &audioClass, &_encodeConvert);
    assert(!status);
    
    AudioConverterGetProperty(_encodeConvert, kAudioConverterCurrentInputStreamDescription, &size, &_sourceFormatDescription);
    
    AudioConverterGetProperty(_encodeConvert, kAudioConverterCurrentOutputStreamDescription, &size, &_destFormatDescription);
    
    if (_destFormatDescription.mBytesPerPacket == 0) {//VCR
        UInt32 size;
       OSStatus status = AudioConverterGetProperty(_encodeConvert, kAudioConverterPropertyMaximumOutputPacketSize, &size, &_destMaxOutSize);
        assert(!status);
    }
    if (_destFormatDescription.mFormatID == kAudioFormatMPEG4AAC) {
        UInt32 outputBitRate = 64000; // 64kbs
        UInt32 propSize = sizeof(outputBitRate);
        
        if (_destFormatDescription.mSampleRate >= 44100) {
            outputBitRate = 192000; // 192kbs
        } else if (_destFormatDescription.mSampleRate < 22000) {
            outputBitRate = 32000; // 32kbs
        }
        
        // set the bit rate depending on the samplerate chosen
        AudioConverterSetProperty(_encodeConvert, kAudioConverterEncodeBitRate, propSize, &outputBitRate);
        
        // get it back and print it out
        AudioConverterGetProperty(_encodeConvert, kAudioConverterEncodeBitRate, &propSize, &outputBitRate);
        printf ("AAC Encode Bitrate: %u\n", (unsigned int)outputBitRate);
    }
    
    [self performSelectorInBackground:@selector(_converterStart) withObject:nil];
    NSLog(@"AudioConverterNewSpecific success");

    return YES;
}
-(OSStatus)_getAudioClass:(AudioClassDescription*)audioClass WithType:(UInt32)type fromManufacturer:(UInt32)manufacturer{
    UInt32 audioClassSize;
    OSStatus status = AudioFormatGetPropertyInfo(kAudioFormatProperty_Encoders, sizeof(type), &type, &audioClassSize);
    if (status != noErr) {
        return status;
    }
    int count = audioClassSize / sizeof(AudioClassDescription);
    AudioClassDescription audioList[count];
    status = AudioFormatGetProperty(kAudioFormatProperty_Encoders, sizeof(type), &type, &audioClassSize, audioClass);
    if (status != noErr) {
        return status;
    }
    for (int i= 0; i < count; i++) {
        if (type == audioList[i].mSubType  && manufacturer == audioList[i].mManufacturer) {
            *audioClass = audioList[i];
            break;
        }
    }
    
    return noErr;
}

-(void)_converterStart{
    
    _isRunning = YES;
    UInt32 outputDataPacketSize               = 1;
    AudioStreamPacketDescription packetDesc;
    while (_isRunning) {
        memset(&packetDesc, 0, sizeof(packetDesc));
        _outCacheBufferList.mBuffers[0].mDataByteSize = _destMaxOutSize;
        OSStatus status = AudioConverterFillComplexBuffer(_encodeConvert, encodeInputDataProc, (__bridge void*)self, &outputDataPacketSize, &_outCacheBufferList, &packetDesc);
       // assert(!status);
        if (status != noErr || status == -1) {
            NSLog(@"AudioConverterFillComplexBuffer error:%d",status);
            return;
        }
        
        
        NSData* data = [NSData dataWithBytes:_outCacheBufferList.mBuffers[0].mData length:_outCacheBufferList.mBuffers[0].mDataByteSize];
        NSLog(@"datalenth:%ld",[data length]);
        //    CMTime pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        //    float VALUE = pts.value / pts.timescale;
        //    NSLog(@"pts:%lf  value:%lld CMTimeScale:%d  CMTimeFlags:%d CMTimeEpoch:%lld",VALUE, pts.value,pts.timescale,pts.flags,pts.epoch);
        UInt32 outDateLenth = _outCacheBufferList.mBuffers[0].mDataByteSize;
        NSData * adts = [self adtsDataForPacketLength:outDateLenth];
        NSMutableData * aacStreamData = [[NSMutableData alloc]init];
        [aacStreamData appendBytes:_outCacheBufferList.mBuffers[0].mData length:outDateLenth];
        
        packetDesc.mDataByteSize = (UInt32)aacStreamData.length;
        packetDesc.mStartOffset = 0;
        if ([self.delegate respondsToSelector:@selector(AACEncoderFromPCM:encodeCompleteBuffer:Lenth:packetCount:packets:)]) {
            [self.delegate AACEncoderFromPCM:self  encodeCompleteBuffer:(u_int8_t*)[aacStreamData bytes] Lenth:aacStreamData.length packetCount:1 packets:&packetDesc];
        }
    }
}
#pragma -mark =======ADTS=======
- (NSData *)adtsDataForPacketLength:(NSUInteger)packetLength
{
    /*=======adts=======
     7字节
     {
     syncword -------12 bit
     ID              -------  1 bit
     layer         -------  2 bit
     protection_absent - 1 bit
     profile       -------  2 bit
     sampling_frequency_index ------- 4 bit
     private_bit ------- 1 bit
     channel_configuration ------- 3bit
     original_copy -------1bit
     home ------- 1bit
     }
     
     */
    int adtsLength = 7;
    char *packet = (char*)malloc(sizeof(adtsLength));
    //profile：表示使用哪个级别的AAC，有些芯片只支持AAC LC 。在MPEG-2 AAC中定义了3种：
    /*
     0-------Main profile
     1-------LC
     2-------SSR
     3-------保留
     */
    int profile = 0;
    /*
     sampling_frequency_index：表示使用的采样率下标，通过这个下标在 Sampling Frequencies[ ]数组中查找得知采样率的值。
     There are 13 supported frequencies:
     0: 96000 Hz
     1: 88200 Hz
     2: 64000 Hz
     3: 48000 Hz
     4: 44100 Hz
     5: 32000 Hz
     6: 24000 Hz
     7: 22050 Hz
     8: 16000 Hz
     9: 12000 Hz
     10: 11025 Hz
     11: 8000 Hz
     12: 7350 Hz
     13: Reserved
     14: Reserved
     15: frequency is written explictly
     */
    int freqIdx = get_f_index(_destFormatDescription.mSampleRate);//11
    /*
     channel_configuration: 表示声道数
     0: Defined in AOT Specifc Config
     1: 1 channel: front-center
     2: 2 channels: front-left, front-right
     3: 3 channels: front-center, front-left, front-right
     4: 4 channels: front-center, front-left, front-right, back-center
     5: 5 channels: front-center, front-left, front-right, back-left, back-right
     6: 6 channels: front-center, front-left, front-right, back-left, back-right, LFE-channel
     7: 8 channels: front-center, front-left, front-right, side-left, side-right, back-left, back-right, LFE-channel
     8-15: Reserved
     */
    int chanCfg = 1;
    NSUInteger fullLength = adtsLength + packetLength;
    packet[0] = (char)0xFF;	// 11111111  	= syncword
    packet[1] = (char)0xF1;	   // 1111 0 00 1 = syncword+id(MPEG-4) + Layer + absent
    //00 1000 0000
    //          01 0000
    //                    0001
    //==============
    //      1001 0000
    packet[2] = (char)(((profile)<<6) + (freqIdx<<2) +(chanCfg>>2));// profile(2)+sampling(4)+privatebit(1)+channel_config(1)
    packet[3] = (char)(((chanCfg&3)<<6) + (fullLength>>11));
    packet[4] = (char)((fullLength&0x7FF) >> 3);
    packet[5] = (char)(((fullLength&7)<<5) + 0x1F);
    packet[6] = (char)0xFC;
    
    NSData *data = [NSData dataWithBytesNoCopy:packet length:adtsLength freeWhenDone:YES];
    
    return data;
}

int get_f_index(unsigned int sampling_frequency)
{
    switch (sampling_frequency)
    {
        case 96000: return 0;
        case 88200: return 1;
        case 64000: return 2;
        case 48000: return 3;
        case 44100: return 4;
        case 32000: return 5;
        case 24000: return 6;
        case 22050: return 7;
        case 16000: return 8;
        case 12000: return 9;
        case 11025: return 10;
        case 8000:  return 11;
        case 7350:  return 12;
        default:    return 0;
    }
}

#pragma mark - mutex

@end
