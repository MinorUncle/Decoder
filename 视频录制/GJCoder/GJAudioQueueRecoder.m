//
//  GJAudioQueueRecode.m
//  Decoder
//
//  Created by tongguan on 16/2/22.
//  Copyright © 2016年 未成年大叔. All rights reserved.
//

#import "GJAudioQueueRecoder.h"
#import <AudioToolbox/AudioFormat.h>


@interface GJAudioQueueRecoder()
{
    AudioFormatID _currentFormatID;
}
@end
@implementation GJAudioQueueRecoder
- (instancetype)initWithStreamDestFormat:(AudioStreamBasicDescription*)format{
    self = [super init];
    if (self) {
        _pAqData = malloc(sizeof(AQRecorderState));

        [self _createAudioQueueWithFormat:format];
        _deriveBufferSize(_pAqData->mQueue, _destFormatDescription, 0.02, &_pAqData->bufferByteSize);
        [self _PrepareAudioQueueBuffers];
    }
    return self;

}
- (instancetype)initWithPath:(NSString*)path fileType:(AudioFileTypeID)fileType
{
    self = [super init];
    if (self) {
        _pAqData = malloc(sizeof(AQRecorderState));

        [self initDefaultFormat];
        [self _createAudioQueueWithFormat:NULL];
        _deriveBufferSize(_pAqData->mQueue, _destFormatDescription, 0.02, &_pAqData->bufferByteSize);
        [self _PrepareAudioQueueBuffers];

        [self _createAudioQueueFileWithFilePath:path fileType:fileType];
        SetMagicCookieForFile(_pAqData->mQueue, _pAqData->mAudioFile);        
    }
    return self;
}
-(void)initDefaultFormat{  //pcm
    //pcm format
        memset(&_destFormatDescription, 0, sizeof(_destFormatDescription));
    
        _destFormatDescription.mFormatID         = kAudioFormatLinearPCM; // 2
        _destFormatDescription.mSampleRate       = 44100.0;               // 3
        _destFormatDescription.mChannelsPerFrame = 2;                     // 4
        _destFormatDescription.mBitsPerChannel   = 16;                    // 5
        _destFormatDescription.mBytesPerPacket   =                        // 6
        _destFormatDescription.mBytesPerFrame =
        _destFormatDescription.mChannelsPerFrame * sizeof (SInt16) * 16;
        _destFormatDescription.mFramesPerPacket  = 1;                     // 7
    
        _destFormatDescription.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger|kLinearPCMFormatFlagIsPacked;
    
        UInt32 size = sizeof(AudioStreamBasicDescription);
        AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, NULL, &size, &_destFormatDescription);

}

static void handleInputBuffer (void *aqData, AudioQueueRef inAQ,AudioQueueBufferRef inBuffer,const AudioTimeStamp *inStartTime,UInt32 inNumPackets, const AudioStreamPacketDescription  *inPacketDesc){
    
    GJAudioQueueRecoder* tempSelf = (__bridge GJAudioQueueRecoder*)aqData;
    AQRecorderState *pAqData = tempSelf.pAqData;               // 1
    
    //关闭写文件
    
    //    OSStatus status = AudioFileWritePackets (pAqData->mAudioFile,false,inBuffer->mAudioDataByteSize,inPacketDesc,pAqData->mCurrentPacket,&inNumPackets,inBuffer->mAudioData);
    //    if (status == noErr) {
    pAqData->mCurrentPacket += inNumPackets;                     // 4
    //    }
    
    if (inPacketDesc == NULL)inNumPackets = 0;
    
    if (!pAqData->mIsRunning)return;
    AudioQueueEnqueueBuffer (pAqData->mQueue,inBuffer,0,NULL);
    if ([tempSelf.delegate respondsToSelector:@selector(GJAudioQueueRecoder:streamData:lenth:packetCount:packetDescriptions:)]) {
        [tempSelf.delegate GJAudioQueueRecoder:tempSelf streamData:inBuffer->mAudioData lenth:inBuffer->mAudioDataByteSize packetCount:inNumPackets packetDescriptions:inPacketDesc];
    }

};

-(BOOL)_createAudioQueueWithFormat:(AudioStreamBasicDescription*)format{
    if (format == NULL) {
        [self initDefaultFormat];
    }else{
        _destFormatDescription = *format;
    }
  
    UInt32 size = sizeof(AudioStreamBasicDescription);
    OSStatus status = AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, NULL, &size, &_destFormatDescription);
    assert(!status);

    status = AudioQueueNewInput ( &_destFormatDescription, handleInputBuffer, (__bridge void * _Nullable)(self),  NULL, kCFRunLoopCommonModes, 0, &_pAqData->mQueue );
    assert(!status);
    
    size = sizeof(AudioStreamBasicDescription);
    status = AudioQueueGetProperty(_pAqData->mQueue, kAudioQueueProperty_StreamDescription, &_destFormatDescription, &size);
    assert(!status);
    return YES;
}
-(BOOL)_createAudioQueueFileWithFilePath:(NSString* )filePath fileType:(AudioFileTypeID)fileType{
    CFURLRef audioFileURL = CFURLCreateFromFileSystemRepresentation ( NULL,(UInt8*)[filePath UTF8String], filePath.length, false);
    
   OSStatus status = AudioFileCreateWithURL (audioFileURL, fileType, &_destFormatDescription,kAudioFileFlags_EraseFile,&_pAqData->mAudioFile);
    assert(!status);
    return YES;
}

void _deriveBufferSize (AudioQueueRef audioQueue,AudioStreamBasicDescription  ASBDescription, Float64 seconds, UInt32                       *outBufferSize) {
    static const int maxBufferSize = 0x5000;                 // 5
    
    int maxPacketSize = ASBDescription.mBytesPerPacket;       // 6
    if (maxPacketSize == 0) {                                 // 7
        UInt32 maxVBRPacketSize = sizeof(maxPacketSize);
        AudioQueueGetProperty (audioQueue,kAudioQueueProperty_MaximumOutputPacketSize,&maxPacketSize,&maxVBRPacketSize);
    }
    Float64 numBytesForTime = ASBDescription.mSampleRate * maxPacketSize * seconds; // 8
    *outBufferSize = (UInt32)(numBytesForTime < maxBufferSize ? numBytesForTime : maxBufferSize);                     // 9
}

OSStatus SetMagicCookieForFile (AudioQueueRef inQueue,AudioFileID   inFile) {
    OSStatus result = noErr;                                    // 3
    UInt32 cookieSize;                                          // 4
    
    OSStatus status = AudioQueueGetPropertySize (inQueue,kAudioQueueProperty_MagicCookie,&cookieSize);
    if (status == noErr) {
        char* magicCookie =(char *) malloc (cookieSize);                       // 6
        status =AudioQueueGetProperty (inQueue,kAudioQueueProperty_MagicCookie,magicCookie,&cookieSize);
        if (status == noErr)
            result = AudioFileSetProperty ( inFile,kAudioFilePropertyMagicCookieData,cookieSize,magicCookie);
        free (magicCookie);                                     // 9
    }
    return result;                                              // 10
}

-(BOOL)_PrepareAudioQueueBuffers{
    if (_pAqData == NULL) {
        return NO;
    }
    for (int i = 0; i < kNumberBuffers; ++i) {           // 1
        assert(!AudioQueueAllocateBuffer (_pAqData->mQueue,_pAqData->bufferByteSize,&_pAqData->mBuffers[i]));
        
        assert(!AudioQueueEnqueueBuffer (_pAqData->mQueue,_pAqData->mBuffers[i],0,NULL));
    }
    return YES;
}
-(BOOL)startRecodeAudio{
    if (_pAqData == NULL) {
        return NO;
    }
    _pAqData->mCurrentPacket = 0;                           // 1
    _pAqData->mIsRunning = true;                            // 2
    OSStatus status = AudioQueueStart(_pAqData->mQueue,NULL);
   assert(!status);
    // 9
    return YES;
}
-(void)stop{
    AudioQueueStop(_pAqData->mQueue,true);
    AudioFileClose(_pAqData->mAudioFile);

    _pAqData->mIsRunning = false;                          }
-(void)clean{
    AudioQueueDispose(_pAqData->mQueue, true);
    
    AudioFileClose(_pAqData->mAudioFile);
    free(_pAqData);

    
}
-(void)dealloc{
    [self clean];
}

@end
