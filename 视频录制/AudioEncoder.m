//
//  AudioEncoder.m
//  AACEncoder
//
//  Created by tongguan on 15/11/16.
//  Copyright © 2015年 tongguan. All rights reserved.
//

#import "AudioEncoder.h"
#define RWDefineSampleRate 44100
@implementation AudioEncoder
//根据输入样本初始化一个编码转换器
{
   AudioConverterRef m_EncodeConverter;//encode
    AudioConverterRef m_DecodeConverter;//decode
    
    uint8_t compressedBuffer[1024*4];
    AudioConverterSettings converterSettings;

}

//创建编码器
- (BOOL)createEncodeAudioConvert:(CMSampleBufferRef)sampleBuffer
{
    if (m_EncodeConverter != NULL)
    {
        return TRUE;
    }
    
    AudioStreamBasicDescription inputFormat = *(CMAudioFormatDescriptionGetStreamBasicDescription(CMSampleBufferGetFormatDescription(sampleBuffer))); // 输入音频格式
    NSLog(@"mSampleRate:%lf mFramesPerPacket:%u mChannelsPerFrame:%u mBitsPerChannel:%u mBytesPerFrame:%u mBytesPerPacket:%u ",inputFormat.mSampleRate,(unsigned int)inputFormat.mFramesPerPacket,inputFormat.mChannelsPerFrame,inputFormat.mBitsPerChannel,inputFormat.mBytesPerFrame,inputFormat.mBytesPerPacket);
    

    AudioStreamBasicDescription outputFormat; // 这里开始是输出音频格式
    memset(&outputFormat, 0, sizeof(outputFormat));
    outputFormat.mSampleRate       = RWDefineSampleRate; // 采样率保持一致
    outputFormat.mFormatID         = kAudioFormatMPEG4AAC;    // AAC编码
    outputFormat.mChannelsPerFrame = 1;
    outputFormat.mFramesPerPacket  = 1024;                    // AAC一帧是1024个字节

    
    AudioClassDescription *desc = [self getAudioEncodeClassDescriptionWithType:kAudioFormatMPEG4AAC fromManufacturer:kAppleSoftwareAudioCodecManufacturer];
    if (AudioConverterNewSpecific(&inputFormat, &outputFormat, 1, desc, &m_EncodeConverter) != noErr)
    {
        NSLog(@"AACEncoderEnableConverterNewSpecific failed");
        self.AACEncoderEnable = NO;
        return NO;
    }
    self.AACEncoderEnable = YES;
    return YES;
}

// 编码PCM成AAC
- (void)encodeAAC:(CMSampleBufferRef)sampleBuffer
{
    char aacData[4096];
    int  aacLen = sizeof(aacData);
    
    if ([self createEncodeAudioConvert:sampleBuffer] != YES)
    {
        return;
    }
    
    CMBlockBufferRef blockBuffer = nil;
    AudioBufferList  inBufferList;
    if (CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sampleBuffer, NULL, &inBufferList, sizeof(AudioBufferList), NULL, NULL, 0, &blockBuffer) != noErr)
    {
        NSLog(@"CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer failed");
        return;
    }
    // 初始化一个输出缓冲列表
    AudioBufferList outBufferList;
    outBufferList.mNumberBuffers              = 1;
    outBufferList.mBuffers[0].mNumberChannels = 1;
    outBufferList.mBuffers[0].mDataByteSize  = aacLen; // 设置缓冲区大小
    outBufferList.mBuffers[0].mData           = aacData; // 设置AAC缓冲区
    UInt32 outputDataPacketSize               = 1;
    if (AudioConverterFillComplexBuffer(m_EncodeConverter, encodeInputDataProc, &inBufferList, &outputDataPacketSize, &outBufferList, NULL) != noErr)
    {
        NSLog(@"AudioConverterFillComplexBuffer failed");
        return;
    }
    
    aacLen = outBufferList.mBuffers[0].mDataByteSize; //设置编码后的AAC大小
    
    CMTime pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    
    CFRelease(blockBuffer);
    
    NSData * adts = [self adtsDataForPacketLength:aacLen];
    NSMutableData * aacStreamData = [[NSMutableData alloc]initWithData:adts];
    [aacStreamData appendBytes:aacData length:aacLen];
    
        if ([_aacCallbackDelegate respondsToSelector:@selector(aacCallBack:length:pts:)]) {
//            [_aacCallbackDelegate aacCallBack:aacData length:aacLen pts:pts];//aac
            [_aacCallbackDelegate aacCallBack:[aacStreamData mutableBytes] length:(int)[aacStreamData length] pts:pts];
        }
}

// 获得编码器
- (AudioClassDescription*)getAudioEncodeClassDescriptionWithType:(UInt32)type fromManufacturer:(UInt32)manufacturer
{
    static AudioClassDescription audioEncodeDesc;
    
    UInt32 encoderSpecifier = type, size = 0;
    OSStatus status;
    
    memset(&audioEncodeDesc, 0, sizeof(audioEncodeDesc));
    status = AudioFormatGetPropertyInfo(kAudioFormatProperty_Encoders, sizeof(encoderSpecifier), &encoderSpecifier, &size);
    if (status)
    {
        return nil;
    }
    
    uint32_t count = size / sizeof(AudioClassDescription);
    AudioClassDescription descs[count];
    status = AudioFormatGetProperty(kAudioFormatProperty_Encoders, sizeof(encoderSpecifier), &encoderSpecifier, &size, descs);
    for (uint32_t i = 0; i < count; i++)
    {
        if ((type == descs[i].mSubType) && (manufacturer == descs[i].mManufacturer))
        {
            memcpy(&audioEncodeDesc, &descs[i], sizeof(audioEncodeDesc));
            break;
        }
    }
    return &audioEncodeDesc;
}

//编码输入
OSStatus encodeInputDataProc(AudioConverterRef inConverter, UInt32 *ioNumberDataPackets, AudioBufferList *ioData,AudioStreamPacketDescription **outDataPacketDescription, void *inUserData)
{ //<span style="font-family: Arial, Helvetica, sans-serif;">AudioConverterFillComplexBuffer 编码过程中，会要求这个函数来填充输入数据，也就是原始PCM数据</span>
    AudioBufferList bufferList = *(AudioBufferList*)inUserData;
    ioData->mBuffers[0].mNumberChannels = 1;
    ioData->mBuffers[0].mData           = bufferList.mBuffers[0].mData;
    ioData->mBuffers[0].mDataByteSize   = bufferList.mBuffers[0].mDataByteSize;
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
    int freqIdx = get_sr_index(RWDefineSampleRate);//11
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

int get_sr_index(unsigned int sampling_frequency)
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

-(void) errCheck:(OSStatus)err {
    
    switch(err) {
        case kAudioConverterErr_FormatNotSupported:
            NSLog(@"kAudioConverterErr_FormatNotSupported");
            break;
        case kAudioConverterErr_OperationNotSupported:
            NSLog(@"kAudioConverterErr_OperationNotSupported");
            
            break;
        case kAudioConverterErr_PropertyNotSupported:
            NSLog(@"kAudioConverterErr_PropertyNotSupported");
            
            break;
        case kAudioConverterErr_InvalidInputSize:
            NSLog(@"kAudioConverterErr_InvalidInputSize");
            
            break;
        case kAudioConverterErr_InvalidOutputSize:
            NSLog(@"kAudioConverterErr_InvalidOutputSize");
            
            break;
        case kAudioConverterErr_UnspecifiedError:
            NSLog(@"kAudioConverterErr_UnspecifiedError");
            
            break;
        case kAudioConverterErr_BadPropertySizeError:
            NSLog(@"kAudioConverterErr_BadPropertySizeError");
            
            break;
        case kAudioConverterErr_RequiresPacketDescriptionsError:
            NSLog(@"kAudioConverterErr_RequiresPacketDescriptionsError");
            
            break;
        case kAudioConverterErr_InputSampleRateOutOfRange:
            NSLog(@"kAudioConverterErr_InputSampleRateOutOfRange");
            
            break;
        case kAudioConverterErr_OutputSampleRateOutOfRange:
            NSLog(@"kAudioConverterErr_OutputSampleRateOutOfRange");
            
            break;
    }
    
}

- (void)dealloc
{
    AudioConverterDispose(m_EncodeConverter);
    AudioConverterDispose(m_DecodeConverter);
}

@end
