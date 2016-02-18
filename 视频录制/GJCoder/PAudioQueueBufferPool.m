//
//  PAudioQueueBufferPool.m
//  Decoder
//
//  Created by tongguan on 16/2/16.
//  Copyright © 2016年 未成年大叔. All rights reserved.
//

#import "PAudioQueueBufferPool.h"
@interface PAudioQueueBufferPool ()
@property(nonatomic,retain)NSMutableArray* queueBuffers;
@property(nonatomic,retain)NSMutableArray* reuseableQueueBuffers;
@end
@implementation PAudioQueueBufferPool
- (instancetype)init
{
    self = [super init];
    if (self) {
        _queueBuffers = [[NSMutableArray alloc]initWithCapacity:3];
        _reuseableQueueBuffers = [[NSMutableArray alloc]initWithCapacity:3];
    }
    return self;
}

@end
