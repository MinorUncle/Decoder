//
//  PCMDecodeFromAAC.m
//  视频录制
//
//  Created by tongguan on 16/1/8.
//  Copyright © 2016年 未成年大叔. All rights reserved.
//

#import "PCMDecodeFromAAC.h"
#import <AudioToolbox/AudioConverter.h>
@interface PCMDecodeFromAAC()
{
    AudioConverterRef* _decodeConvert;

}
@end
@implementation PCMDecodeFromAAC

-(void)decodeBuffer:(uint8_t*)buffer withLenth:(uint32_t)totalLenth{

}

-(BOOL)_createEncodeConverterWithBuffer:(CMSampleBufferRef)sampleBuffer{
    if (_decodeConvert != NULL) {
        return YES;
    }
    
    const AudioStreamBasicDescription* sourceFormat = CMAudioFormatDescriptionGetStreamBasicDescription(CMSampleBufferGetFormatDescription(sampleBuffer));
    AudioStreamBasicDescription destFormat;
    memset(&destFormat, 0, sizeof(destFormat));
    destFormat.mSampleRate = _outPacketFormat.mSampleRate;
    destFormat.mFormatID = kAudioFormatMPEG4AAC;  //aac
    destFormat.mFramesPerPacket = _outPacketFormat.mFramesPerPacket;
    destFormat.mChannelsPerFrame = _outPacketFormat. _outChannelsPerFrame;
    
    AudioClassDescription audioClass;
    OSStatus status = [self _getAudioClass:&audioClass WithType:destFormat.mFormatID fromManufacturer:kAppleSoftwareAudioCodecManufacturer];
    if (status != noErr) {
        return NO;
    }
    status = AudioConverterNewSpecific(sourceFormat, &destFormat, 1, &audioClass, &_decodeConvert);
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

@end
