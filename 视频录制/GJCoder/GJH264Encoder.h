//
//  GJH264Encoder.h
//  视频录制
//
//  Created by tongguan on 15/12/28.
//  Copyright © 2015年 未成年大叔. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <VideoToolbox/VideoToolbox.h>
@protocol GJH264EncoderDelegate <NSObject>
-(void)encodeCompleteBuffer:(uint8_t*)buffer withLenth:(long)totalLenth;
@end




@interface GJH264Encoder : NSObject
@property(nonatomic,weak)id<GJH264EncoderDelegate> deleagte;
-(void)encodeSampleBuffer:(CMSampleBufferRef)sampleBuffer;
-(void)stop;
@end
