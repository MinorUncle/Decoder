//
//  RWFormat.m
//  AACEncoder
//
//  Created by tongguan on 15/11/20.
//  Copyright © 2015年 tongguan. All rights reserved.
//

#import "RWFormat.h"

@implementation RWFormat
+ (instancetype)formatWithSampleRate:(NSUInteger)sampleRate
                            channels:(NSUInteger)channels
                       bitsPerSample:(NSUInteger)bitsPerSample {
    
    RWFormat *format     = [RWFormat new];
    format.sampleRate       = sampleRate;
    format.channels         = channels;
    format.bitsPerSample    = bitsPerSample;
    return format;
}

- (float)bitrate {
    return (float)self.bitsPerSample * self.sampleRate * self.channels;
}

- (void)dealloc
{
}

@end
