//
//  AACDecoder.h
//  AACEncoder
//
//  Created by tongguan on 15/11/20.
//  Copyright © 2015年 tongguan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@protocol AACDecodeTocPCMCallBack <NSObject>

- (void)pcmDataToPlay:(char*)buf size:(int)size;

@end

@interface AACDecoder : NSObject
@property (nonatomic,assign,readonly) AudioStreamBasicDescription mTargetAudioStreamDescripion;

@property (nonatomic,assign,readonly) AudioStreamPacketDescription* packetFormat;

@property (assign,nonatomic) id <AACDecodeTocPCMCallBack> aacDecodeDelegate;
- (NSData*)canDecodeData:(NSData *)data;
- (NSData *)fetchMagicCookie;
@end
