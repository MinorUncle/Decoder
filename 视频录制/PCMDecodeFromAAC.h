//
//  PCMDecodeFromAAC.h
//  视频录制
//
//  Created by tongguan on 16/1/8.
//  Copyright © 2016年 未成年大叔. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>

@protocol PCMDecodeFromAACDelegate
-(void)pcmDecodeCompleteData:(NSData*)pcmData;
@end
@interface PCMDecodeFromAAC : NSObject
@property(nonatomic,assign)AudioStreamBasicDescription outPacketFormat;



-(void)decodeBuffer:(uint8_t*)buffer withLenth:(uint32_t)totalLenth;

@end
