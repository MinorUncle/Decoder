//
//  GJH264Decoder.m
//  视频录制
//
//  Created by tongguan on 15/12/28.
//  Copyright © 2015年 未成年大叔. All rights reserved.
//

#import "GJH264Decoder.h"
#define maxCount 10
//////会覆盖队列
@interface queue : NSObject 
{
    uint8_t* bufferQueue[maxCount];
    int bufferSize[maxCount];
}
@property (assign,readonly) int start;
@property (assign,readonly)int end;

@end
@implementation queue

-(void)push:(uint8_t*)buffer size:(int)size{
    bufferQueue[_end] = buffer;
    bufferSize[_end] = size;
    _end = (_end+1) % maxCount;
}
-(Boolean)popBuffer:(uint8_t**)outputBuffer size:(int*)outputSize{
    if (_end == _start) {
        return false;
    }
    int temp = _start;
    _start = (_start+1) % maxCount;
    
    
    *outputBuffer = bufferQueue[temp];
    *outputSize = bufferSize[temp];
    
    bufferSize[temp] = 0;
    return true;
}

@end

@interface GJH264Decoder()
{
    dispatch_queue_t _decodeQueue;
    
}
@property(nonatomic)VTDecompressionSessionRef decompressionSession;
@property (nonatomic, assign) CMVideoFormatDescriptionRef formatDesc;

@end
@implementation GJH264Decoder
GJH264Decoder *decoder;
uint8_t *pps = NULL;
uint8_t *sps = NULL;

- (instancetype)init
{
    self = [super init];
    if (self) {
        decoder = self;
        _decodeQueue = dispatch_queue_create("decodeQueue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}
-(void) createDecompSession
{
    _decompressionSession = NULL;
    VTDecompressionOutputCallbackRecord callBackRecord;
    callBackRecord.decompressionOutputCallback = decodeOutputCallback;
    
    callBackRecord.decompressionOutputRefCon = (__bridge void *)self;
    
    NSDictionary *destinationImageBufferAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                                      [NSNumber numberWithBool:YES],
                                                      (id)kCVPixelBufferOpenGLESCompatibilityKey,
                                                      nil];
    //使用UIImageView播放时可以设置这个
    //    NSDictionary *destinationImageBufferAttributes =[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:NO],(id)kCVPixelBufferOpenGLESCompatibilityKey,[NSNumber numberWithInt:kCVPixelFormatType_32BGRA],(id)kCVPixelBufferPixelFormatTypeKey,nil];
    
    OSStatus status =  VTDecompressionSessionCreate(NULL,
                                                    _formatDesc,
                                                    NULL,
                                                    (__bridge CFDictionaryRef)(destinationImageBufferAttributes),
                                                    &callBackRecord,
                                                    &_decompressionSession);
    NSLog(@"Video Decompression Session Create: \t %@", (status == noErr) ? @"successful!" : @"failed...");
}


void decodeOutputCallback(
                          void * decompressionOutputRefCon,
                          void * sourceFrameRefCon,
                          OSStatus status,
                          VTDecodeInfoFlags infoFlags,
                          CVImageBufferRef imageBuffer,
                          CMTime presentationTimeStamp,
                          CMTime presentationDuration ){
//    NSLog(@"decodeOutputCallback:%@",[NSThread currentThread]);
    
    if (status != 0) {
        NSLog(@"解码error:%d",(int)status);
        return;
    }
    
    if ([decoder.delegate respondsToSelector:@selector(decodeCompleteImageData:)]) {
        [decoder.delegate decodeCompleteImageData:imageBuffer];
    }
}

-(void)decodeBuffer:(uint8_t*)frame withLenth:(uint32_t)frameSize;
{
//    NSLog(@"decodeFrame:%@",[NSThread currentThread]);
    OSStatus status;
    //    NSData* d = [NSData dataWithBytes:frame length:frameSize];
    //      NSLog(@"d:%@",d);
    uint8_t *data = NULL;
    
    int startCodeIndex = 0;
    int secondStartCodeIndex = 0;
    int thirdStartCodeIndex = 0;
    int _spsSize = 0;
    int _ppsSize = 0;
    long blockLength = 0;
    
    CMSampleBufferRef sampleBuffer = NULL;
    CMBlockBufferRef blockBuffer = NULL;
    
    int nalu_type = (frame[startCodeIndex + 4] & 0x1F);
    
    if (nalu_type != 7 && _formatDesc == NULL)
    {
        NSLog(@"Video error: Frame is not an I Frame and format description is null");
        return;
    }
    
    if (nalu_type == 7)    ///sps
    {
        // 去掉起始头0x00 00 00 01   有的为0x00 00 01
        int i = [self findFlgIndexData:&frame[startCodeIndex + 4] lenth:frameSize - startCodeIndex -4];
        if (i != -1) {
            secondStartCodeIndex = i + startCodeIndex + 4;
            _spsSize = secondStartCodeIndex;
        }else{
            return;
        }
        
        nalu_type = (frame[secondStartCodeIndex + 4] & 0x1F);
    }
    
    if(nalu_type == 8)    ///pps
    {
        int i = [self findFlgIndexData:&frame[secondStartCodeIndex + 4] lenth:frameSize - secondStartCodeIndex - 4];
        if (i != -1) {
            thirdStartCodeIndex = i + secondStartCodeIndex + 4;
            _ppsSize = thirdStartCodeIndex - _spsSize;
        }else{
            thirdStartCodeIndex = frameSize;
            _ppsSize = thirdStartCodeIndex - _spsSize;
        }
        
           
        if (sps != NULL) {
            free(sps);
        }
        if (pps != NULL) {
            free(pps);
        }
        sps = malloc(_spsSize - 4);
        pps = malloc(_ppsSize - 4);
        
        memcpy (sps, &frame[4], _spsSize-4);
        memcpy (pps, &frame[_spsSize+4], _ppsSize-4);
        
        uint8_t*  parameterSetPointers[2] = {sps, pps};
        size_t parameterSetSizes[2] = {_spsSize-4, _ppsSize-4};
        if (_formatDesc != nil) {
            CFRelease(_formatDesc);
        }
        
        status = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault, 2,
                                                                     (const uint8_t *const*)parameterSetPointers,
                                                                     parameterSetSizes, 4,
                                                                     &_formatDesc);
        
        if((status == noErr) && (_decompressionSession == NULL))
        {
            [self createDecompSession];
        }
        
        if (frameSize <= thirdStartCodeIndex +4) {
            return;
        }else{
            nalu_type = (frame[thirdStartCodeIndex + 4] & 0x1F);
        }

    }
    
  
    
//    NSLog(@"numtpty:%d",nalu_type);
//    if(1)   //5则帧，1则p帧
    
    int offset = _spsSize + _ppsSize;
    blockLength = frameSize - offset;
    data = &frame[offset];
    uint32_t dataLength32 = htonl (blockLength - 4);
    memcpy (data, &dataLength32, sizeof (uint32_t));
    status = CMBlockBufferCreateWithMemoryBlock(NULL, data,
                                                blockLength,
                                                kCFAllocatorNull, NULL,
                                                0,
                                                blockLength,
                                                0, &blockBuffer);
    if (status != 0) {
        NSLog(@"\t\t BlockBufferCreation: \t %@", (status == kCMBlockBufferNoErr) ? @"successful!" : @"failed...");
        return;
    }
    
    
//    if (nalu_type == 1)     //p帧
//    {
//        blockLength = frameSize;
//        data = frame;
////        data = malloc(blockLength);
////        data = memcpy(data, &frame[0], blockLength);
//        
//        uint32_t dataLength32 = htonl (blockLength - 4);
//        memcpy (data, &dataLength32, sizeof (uint32_t));
//        
//        status = CMBlockBufferCreateWithMemoryBlock(NULL, data,
//                                                    blockLength,
//                                                    kCFAllocatorNull, NULL,
//                                                    0,
//                                                    blockLength,
//                                                    0, &blockBuffer);
//    }
    if (blockLength == 0) {
        return;
    }
    
    
    if(status == noErr)
    {
        const size_t sampleSize = blockLength;
        status = CMSampleBufferCreate(kCFAllocatorDefault,
                                      blockBuffer, true, NULL, NULL,
                                      _formatDesc, 1, 0, NULL, 1,
                                      &sampleSize, &sampleBuffer);
        if (status != 0) {
            NSLog(@"\t\t SampleBufferCreate: \t %@", (status == noErr) ? @"successful!" : @"failed...");
        }
        
    }
    
    if(status == noErr)
    {
        CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, YES);
        CFMutableDictionaryRef dict = (CFMutableDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
        CFDictionarySetValue(dict, kCMSampleAttachmentKey_DisplayImmediately, kCFBooleanTrue);
        
        [self render:sampleBuffer];
        CFRelease(sampleBuffer);
    }
    
    
    if (NULL != blockBuffer) {
        CFRelease(blockBuffer);
        blockBuffer = NULL;
    }
    
  
    
}
-(void)relaseData:(uint8_t*) tmpData{
    if (NULL != tmpData)
    {
        free (tmpData);
        tmpData = NULL;
    }
}
-(uint32_t)findFlgIndexData:(uint8_t*)frame lenth:(uint32_t)frameSize{
    for (uint32_t i = 0; i < frameSize - 3; i++)
    {
        if (frame[i] == 0x00 && frame[i+1] == 0x00 && frame[i+2] == 0x00 && frame[i+3] == 0x01)
        {
            
            return i;
        }
    }
    return -1;
}
//解码
- (void) render:(CMSampleBufferRef)sampleBuffer
{
    VTDecodeFrameFlags flags = kVTDecodeFrame_EnableAsynchronousDecompression;
    VTDecodeInfoFlags flagOut;
    VTDecompressionSessionDecodeFrame(_decompressionSession, sampleBuffer, flags,&sampleBuffer, &flagOut);
}
NSString * const naluTypesStrings[] =
{
    @"0: Unspecified (non-VCL)",
    @"1: Coded slice of a non-IDR picture (VCL)",    // P frame
    @"2: Coded slice data partition A (VCL)",
    @"3: Coded slice data partition B (VCL)",
    @"4: Coded slice data partition C (VCL)",
    @"5: Coded slice of an IDR picture (VCL)",      // I frame
    @"6: Supplemental enhancement information (SEI) (non-VCL)",
    @"7: Sequence parameter set (non-VCL)",         // SPS parameter
    @"8: Picture parameter set (non-VCL)",          // PPS parameter
    @"9: Access unit delimiter (non-VCL)",
    @"10: End of sequence (non-VCL)",
    @"11: End of stream (non-VCL)",
    @"12: Filler data (non-VCL)",
    @"13: Sequence parameter set extension (non-VCL)",
    @"14: Prefix NAL unit (non-VCL)",
    @"15: Subset sequence parameter set (non-VCL)",
    @"16: Reserved (non-VCL)",
    @"17: Reserved (non-VCL)",
    @"18: Reserved (non-VCL)",
    @"19: Coded slice of an auxiliary coded picture without partitioning (non-VCL)",
    @"20: Coded slice extension (non-VCL)",
    @"21: Coded slice extension for depth view components (non-VCL)",
    @"22: Reserved (non-VCL)",
    @"23: Reserved (non-VCL)",
    @"24: STAP-A Single-time aggregation packet (non-VCL)",
    @"25: STAP-B Single-time aggregation packet (non-VCL)",
    @"26: MTAP16 Multi-time aggregation packet (non-VCL)",
    @"27: MTAP24 Multi-time aggregation packet (non-VCL)",
    @"28: FU-A Fragmentation unit (non-VCL)",
    @"29: FU-B Fragmentation unit (non-VCL)",
    @"30: Unspecified (non-VCL)",
    @"31: Unspecified (non-VCL)",
};

@end
