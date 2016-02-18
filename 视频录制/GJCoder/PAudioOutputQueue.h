//
//  PAudioOutputQueue.h
//  Decoder
//
//  Created by tongguan on 16/2/16.
//  Copyright © 2016年 未成年大叔. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@interface PAudioOutputQueue : NSObject
- (instancetype)initWithFormat:(AudioStreamBasicDescription)format bufferSize:(UInt32)bufferSize macgicCookie:(NSData *)macgicCookie;
- (BOOL)playData:(NSData *)data packetCount:(UInt32)packetCount packetDescriptions:(AudioStreamPacketDescription *)packetDescriptions isEof:(BOOL)isEof;

@end
