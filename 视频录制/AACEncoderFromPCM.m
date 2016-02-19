//
//  PCMEncoderToAAC.m
//  视频录制
//
//  Created by tongguan on 16/1/8.
//  Copyright © 2016年 未成年大叔. All rights reserved.
//
#define MAX_FRAME_SIZE 4096
#import "AACEncoderFromPCM.h"
@interface AACEncoderFromPCM ()
{
    AudioConverterRef _encodeConvert;
    AudioBufferList _outCacheBufferList;
}
@end

@implementation AACEncoderFromPCM
- (instancetype)init
{
    self = [super init];
    if (self) {
        _outChannelsPerFrame = 1;
        _outFramesPerPacket = 1024;
        _outSampleRate = 44100;
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
    *ioData = *(AudioBufferList*)inUserData;
    *ioNumberDataPackets = 1;

    return noErr;
}

-(void)encodeWithBufferWithBuffer:(CMSampleBufferRef)sampleBuffer{
    if (![self _createEncodeConverterWithBuffer:sampleBuffer]) {
        return;
    }
    AudioBufferList inBufferList;
    CMBlockBufferRef blockBuffer;
    UInt32 outputDataPacketSize               = 1;
    
    _outCacheBufferList.mBuffers[0].mDataByteSize = MAX_FRAME_SIZE;
    OSStatus status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sampleBuffer, nil, &inBufferList, sizeof(inBufferList), NULL, NULL, 0, &blockBuffer);
    if (status != noErr) {
        NSLog(@"CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer error:%d",status);
        return;
    }
    status = AudioConverterFillComplexBuffer(_encodeConvert, encodeInputDataProc, &inBufferList, &outputDataPacketSize, &_outCacheBufferList, nil);
    if (status != noErr) {
        NSLog(@"AudioConverterFillComplexBuffer error:%d",status);
        return;
    }
    CFRelease(blockBuffer);

//    CMTime pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
//    float VALUE = pts.value / pts.timescale;
//    NSLog(@"pts:%lf  value:%lld CMTimeScale:%d  CMTimeFlags:%d CMTimeEpoch:%lld",VALUE, pts.value,pts.timescale,pts.flags,pts.epoch);
    UInt32 outDateLenth = _outCacheBufferList.mBuffers[0].mDataByteSize;
    NSData * adts = [self adtsDataForPacketLength:outDateLenth];
    NSMutableData * aacStreamData = [[NSMutableData alloc]initWithData:adts];
    [aacStreamData appendBytes:_outCacheBufferList.mBuffers[0].mData length:outDateLenth];
    
    if ([self.delegate respondsToSelector:@selector(aacEncodeCompleteBuffer:withLenth:)]) {
        [self.delegate aacEncodeCompleteBuffer:(u_int8_t*)[aacStreamData bytes] withLenth:aacStreamData.length];
    }
}

-(BOOL)_createEncodeConverterWithBuffer:(CMSampleBufferRef)sampleBuffer{
    if (_encodeConvert != NULL) {
        return YES;
    }
    
    const AudioStreamBasicDescription* sourceFormat = CMAudioFormatDescriptionGetStreamBasicDescription(CMSampleBufferGetFormatDescription(sampleBuffer));
    AudioStreamBasicDescription destFormat;
    memset(&destFormat, 0, sizeof(destFormat));
    destFormat.mSampleRate = _outSampleRate;
    destFormat.mFormatID = kAudioFormatMPEG4AAC;  //aac
    destFormat.mFramesPerPacket = _outFramesPerPacket;
    destFormat.mChannelsPerFrame = _outChannelsPerFrame;
    
    AudioClassDescription audioClass;
   OSStatus status = [self _getAudioClass:&audioClass WithType:destFormat.mFormatID fromManufacturer:kAppleSoftwareAudioCodecManufacturer];
    if (status != noErr) {
        return NO;
    }
    status = AudioConverterNewSpecific(sourceFormat, &destFormat, 1, &audioClass, &_encodeConvert);
    if (status != noErr) {
        NSLog(@"AudioConverterNewSpecific error:%d",status);

        return NO;
    }else{
        NSLog(@"AudioConverterNewSpecific success");

    }
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
    char *packet = malloc(sizeof(adtsLength));
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
    int freqIdx = get_f_index(_outSampleRate);//11
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
@end
