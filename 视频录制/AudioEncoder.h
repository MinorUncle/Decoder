//
//  AudioEncoder.h
//  AACEncoder
//
//  Created by tongguan on 15/11/16.
//  Copyright © 2015年 tongguan. All rights reserved.
//

#import <Foundation/Foundation.h>
@import AVFoundation;

typedef struct AudioConverterSettings {
    
    AudioConverterRef audioEncoder;
    AudioConverterRef audioDecoder;
    
    AudioStreamBasicDescription inputFormat;
    AudioStreamBasicDescription outputFormat;
    
    AudioStreamPacketDescription * encodedPacketDescriptions;
    
    UInt8 * rawSampleBuffer;
    int rawSampleBufferSize;
    
    uint8_t * compressedBuffer;
    int compressedBufferSize;
    
    int outputBufferByteSize;
    int numPacketsInCompressedBuffer;
    
    
} AudioConverterSettings;

@protocol aacCallbackDelegate <NSObject>

- (void)aacCallBack:(char*)aacData length:(int)datalength pts:(CMTime)pts;

@end

@interface AudioEncoder : NSObject

@property (assign,nonatomic) id <aacCallbackDelegate> aacCallbackDelegate;

@property (assign,nonatomic) BOOL AACEncoderEnable;

@property (assign,nonatomic) BOOL AACDecoderEnable;

- (BOOL)createEncodeAudioConvert:(CMSampleBufferRef)sampleBuffer;

- (void)encodeAAC:(CMSampleBufferRef)sampleBuffer;

@end
