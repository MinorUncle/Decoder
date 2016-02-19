//
//  RWFormat.h
//  AACEncoder
//
//  Created by tongguan on 15/11/20.
//  Copyright © 2015年 tongguan. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RWFormat : NSObject
@property (nonatomic, assign) NSUInteger sampleRate;
@property (nonatomic, assign) NSUInteger channels;
@property (nonatomic, assign) NSUInteger bitsPerSample;

+ (instancetype)formatWithSampleRate:(NSUInteger)sampleRate
                            channels:(NSUInteger)channels
                       bitsPerSample:(NSUInteger)bitsPerSample;

- (float)bitrate;

@end