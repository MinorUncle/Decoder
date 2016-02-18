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
    AudioConverterRef* _encodeConvert;
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
        
        
    }
    return self;
}
-(void)encodeWithBufferWithBuffer:(CMSampleBufferRef)sampleBuffer{
    if (![self _createEncodeConverterWithBuffer:sampleBuffer]) {
        return;
    }
    AudioBufferList bufferList;
    CMBlockBufferRef blockBuffer;
    CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sampleBuffer, nil, &bufferList, sizeof(bufferList), NULL, NULL, 0, &blockBuffer);
    
 
   
    
    CFRelease(blockBuffer);

}
-(BOOL)_createEncodeConverterWithBuffer:(CMSampleBufferRef)sampleBuffer{
    if (_encodeConvert != NULL) {
        return YES;
    }
    
    const AudioStreamBasicDescription* sourceFormat = CMAudioFormatDescriptionGetStreamBasicDescription(CMSampleBufferGetFormatDescription(sampleBuffer));
    AudioStreamBasicDescription destFormat;
    destFormat.mSampleRate = _outSampleRate;
    destFormat.mFormatID = kAudioFormatMPEG4AAC;  //aac
    destFormat.mFramesPerPacket = _outFramesPerPacket;
    destFormat.mChannelsPerFrame = _outChannelsPerFrame;
    
    AudioClassDescription audioClass;
   OSStatus status = [self _getAudioClass:&audioClass WithType:destFormat.mFormatID fromManufacturer:kAppleSoftwareAudioCodecManufacturer];
    if (status != noErr) {
        return NO;
    }
    status = AudioConverterNewSpecific(sourceFormat, &destFormat, 1, &audioClass, _encodeConvert);
    if (status != noErr) {
        return NO;
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
@end
