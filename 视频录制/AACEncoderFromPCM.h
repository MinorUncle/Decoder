//
//  PCMEncoderToAAC.h
//  视频录制
//
//  Created by tongguan on 16/1/8.
//  Copyright © 2016年 未成年大叔. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <CoreMedia/CoreMedia.h>
@protocol AACEncoderFromPCMDelegate<NSObject>
-(void)aacEncodeCompleteBuffer:(uint8_t*)buffer withLenth:(long)totalLenth;
@end
@interface AACEncoderFromPCM : NSObject
@property(nonatomic,assign)Float64 outSampleRate;  //采样率
@property(nonatomic,assign)UInt32 outChannelsPerFrame;
@property(nonatomic,assign,readonly)UInt32 outFramesPerPacket;
@property(nonatomic,weak)id<AACEncoderFromPCMDelegate>delegate;

-(void)encodeWithBufferWithBuffer:(CMSampleBufferRef)buffer;

@end
