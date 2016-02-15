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
@protocol PCMEncoderToAACDelegate
-(void)encodeCompleteBuffer:(uint8_t*)buffer withLenth:(long)totalLenth;
@end
@interface PCMEncoderToAAC : NSObject
-(void)encodeWithBufferWithBuffer:(CMSampleBufferRef)buffer;

@end
