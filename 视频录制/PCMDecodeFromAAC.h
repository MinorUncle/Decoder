//
//  PCMDecodeFromAAC.h
//  视频录制
//
//  Created by tongguan on 16/1/8.
//  Copyright © 2016年 未成年大叔. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import <AudioToolbox/AudioToolbox.h>

@protocol PCMDecodeFromAACDelegate <NSObject>
-(void)pcmDecodeCompleteData:(NSData*)pcmData;
@end
@interface PCMDecodeFromAAC : NSObject
@property (nonatomic,assign,readonly) UInt32 maxPacketSize;
@property (nonatomic,assign,readonly) AudioStreamBasicDescription mSourceAudioStreamDescription;

@property (nonatomic,assign,readonly) UInt32 bitRate;
@property (nonatomic,assign,readonly) UInt64 audioDataByteCount;
@property(nonatomic,assign,readonly)AudioStreamBasicDescription destFormatDescription;
@property (nonatomic,weak) id<PCMDecodeFromAACDelegate>delegate;


-(void)decodeBuffer:(uint8_t*)buffer withLenth:(uint32_t)totalLenth;

@end
