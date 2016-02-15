//
//  H264Encoder.m
//  视频录制
//
//  Created by tongguan on 15/12/28.
//  Copyright © 2015年 未成年大叔. All rights reserved.
//

#import "H264Encoder.h"
@interface H264Encoder()
{
    long encoderFrameCount;

}
@property(nonatomic)VTCompressionSessionRef enCodeSession;
@end

@implementation H264Encoder
int _keyInterval;////key内的p帧数量

H264Encoder* encoder ;
- (instancetype)init
{
    self = [super init];
    if (self) {
        encoder = self;
    }
    return self;
}



//编码
-(void)encodeSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    CVImageBufferRef imgRef = CMSampleBufferGetImageBuffer(sampleBuffer);

    if (_enCodeSession == nil) {
        int32_t h = (int32_t)CVPixelBufferGetHeight(imgRef);
        int32_t w = (int32_t)CVPixelBufferGetWidth(imgRef);
        [self creatEnCodeSessionWithWidth:w height:h];
    }
    CMTime presentationTimeStamp = CMTimeMake(encoderFrameCount, 10);
    OSStatus status = VTCompressionSessionEncodeFrame(
                                                  _enCodeSession,
                                                  imgRef,
                                                  presentationTimeStamp,
                                                  kCMTimeInvalid, // may be kCMTimeInvalid
                                                  NULL,
                                                  NULL,
                                                  NULL );
    encoderFrameCount++;
    if (status != 0) {
        NSLog(@"encodeSampleBuffer error:%d",(int)status);
        return;
    }
    
}

-(void)creatEnCodeSessionWithWidth:(int32_t)w height:(int32_t)h{
    OSStatus t = VTCompressionSessionCreate(
                                            NULL,
                                            w,
                                            h,
                                            kCMVideoCodecType_H264,
                                            NULL,
                                            NULL,
                                            NULL,
                                            encodeOutputCallback,
                                            NULL,
                                            &_enCodeSession);
    NSLog(@"VTCompressionSessionCreate status:%d",(int)t);
    VTSessionSetProperty(_enCodeSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
    VTSessionSetProperty(_enCodeSession, kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanFalse);
    VTSessionSetProperty(_enCodeSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Baseline_AutoLevel);
    VTSessionSetProperty(_enCodeSession, kVTCompressionPropertyKey_H264EntropyMode, kVTH264EntropyMode_CABAC);

    
    SInt32 bitRate = 0.5;
    CFNumberRef ref = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &bitRate);
    VTSessionSetProperty(_enCodeSession, kVTCompressionPropertyKey_AverageBitRate, ref);
    CFRelease(ref);
    
    float quality = 0.1;
    CFNumberRef  qualityRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberFloatType,&quality);
    VTSessionSetProperty(_enCodeSession, kVTCompressionPropertyKey_Quality,qualityRef);
      CFRelease(qualityRef);
    
    int frameInterval = 240;
    CFNumberRef  frameIntervalRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &frameInterval);
    VTSessionSetProperty(_enCodeSession, kVTCompressionPropertyKey_MaxKeyFrameInterval,frameIntervalRef);
    CFRelease(frameIntervalRef);
    
    VTCompressionSessionPrepareToEncodeFrames(_enCodeSession);
//    UInt32 num = 5;
//    ref = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type,&num);
//    VTSessionSetProperty(_enCodeSession, kVTCompressionPropertyKey_ExpectedFrameRate,ref);

    
}

void encodeOutputCallback(void *  outputCallbackRefCon,void *  sourceFrameRefCon,OSStatus statu,VTEncodeInfoFlags infoFlags,
                          CMSampleBufferRef sample ){
    if (statu != 0) return;
    if (!CMSampleBufferDataIsReady(sample))
    {
        NSLog(@"didCompressH264 data is not ready ");
        return;
    }
    
    bool keyframe = !CFDictionaryContainsKey( (CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(sample, true), 0)), kCMSampleAttachmentKey_NotSync);

    
    if (keyframe)
    {
        NSLog(@"key interval%d",_keyInterval);
        _keyInterval = -1;
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sample);
        size_t sparameterSetSize, sparameterSetCount;
        int spHeadSize;
        int ppHeadSize;
        const uint8_t *sparameterSet;
        OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 0, &sparameterSet, &sparameterSetSize, &sparameterSetCount, &spHeadSize );
        if (statusCode == noErr)
        {
            size_t pparameterSetSize, pparameterSetCount;
            const uint8_t *pparameterSet;
            OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 1, &pparameterSet, &pparameterSetSize, &pparameterSetCount, &ppHeadSize );
            if (statusCode == noErr)
            {
                uint8_t* data = malloc(4+4+sparameterSetSize+pparameterSetSize);
                memcpy(&data[0], "\x00\x00\x00\x01", 4);
                memcpy(&data[4], sparameterSet, sparameterSetSize);
                memcpy(&data[4+sparameterSetSize], "\x00\x00\x00\x01", 4);
                memcpy(&data[8+sparameterSetSize], pparameterSet, pparameterSetSize);
                [encoder.deleagte encodeCompleteBuffer:data withLenth:pparameterSetSize+sparameterSetSize+8];
                free(data);
            }
        }
    }
    
    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sample);
    size_t length, totalLength;
    uint8_t *dataPointer;
    OSStatus statusCodeRet = CMBlockBufferGetDataPointer(dataBuffer, 0, &length, &totalLength, &dataPointer);
    

    if (statusCodeRet == noErr) {
        
        uint32_t bufferOffset = 0;
        static const uint32_t AVCCHeaderLength = 4;
        while (bufferOffset < totalLength - AVCCHeaderLength) {
            
            _keyInterval++;
            // Read the NAL unit length
            uint32_t NALUnitLength = 0;
            memcpy(&NALUnitLength, dataPointer + bufferOffset, AVCCHeaderLength);
            
            NALUnitLength = CFSwapInt32BigToHost(NALUnitLength);
            uint8_t* data = dataPointer + bufferOffset;
            memcpy(&data[0], "\x00\x00\x00\x01", 4);
        
            [encoder.deleagte encodeCompleteBuffer:data withLenth:NALUnitLength + 4];
            
            bufferOffset += AVCCHeaderLength + NALUnitLength;
        }
    }
}
-(void)stop{
    _enCodeSession = nil;
}
//-(void)restart{
//
//    [self creatEnCodeSession];
//}

@end
