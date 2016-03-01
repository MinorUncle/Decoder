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

@class PCMDecodeFromAAC;
@protocol PCMDecodeFromAACDelegate <NSObject>
-(void)pcmDecode:(PCMDecodeFromAAC*)decoder completeBuffer:(void*)buffer lenth:(int)lenth;
@end
@interface PCMDecodeFromAAC : NSObject
@property (nonatomic,assign,readonly) UInt32 destMaxOutSize;
@property (nonatomic,assign,readonly) AudioStreamBasicDescription sourceFormatDescription;
@property (nonatomic,assign,readonly)AudioStreamBasicDescription destFormatDescription;


@property (nonatomic,assign,readonly) UInt32 bitRate;
@property (nonatomic,weak) id<PCMDecodeFromAACDelegate>delegate;


-(void)decodeBuffer:(uint8_t*)buffer withLenth:(uint32_t)totalLenth;
- (instancetype)initWithDestDescription:(AudioStreamBasicDescription*)description SourceDescription:(AudioStreamBasicDescription*)sourceDescription sourceMaxBufferLenth:(int)maxLenth;
@end
