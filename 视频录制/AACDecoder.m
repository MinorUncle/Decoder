//
//  AACDecoder.m
//  AACEncoder
//
//  Created by tongguan on 15/11/20.
//  Copyright © 2015年 tongguan. All rights reserved.
//

#import "AACDecoder.h"
#import "RWFormat.h"

static const UInt32 kRawBufferSize              = 32768;
static const UInt32 kPCMDataBufferSize          = kRawBufferSize * 10;

@interface AACDecoder () {
    
    AudioFileStreamID                           mAudioFileStreamID;
    AudioConverterRef                           mAudioConverter;
    
    AudioStreamBasicDescription                 mSourceAudioStreamDescription;
    
    
    void                                        *mParsedRawData;
    UInt32                                      mParsedRawDataSize;
    UInt32                                      mParsedRawPacketsNumber;
    AudioStreamPacketDescription                *mParsedRawPacketDescriptions;
    
    UInt32                                      mPCMPacketsNumber;
    AudioStreamPacketDescription                *mPCMPacketDescriptions;
    
    void                                        *mPCMDataBuffer;
}

@property (nonatomic, strong) NSMutableData *pcmdata;
@property (nonatomic, strong) RWFormat *pcmFormat;

@property (nonatomic, assign) SInt64 decodedRawdataByteCount1;
@property (nonatomic, assign) SInt64 decodedPCMdataByteCount1;

@property (nonatomic, assign) SInt64 decodedRawdataByteCount2;
@property (nonatomic, assign) SInt64 decodedPCMdataByteCount2;

- (void)handleAudioFileStreamPropertyChange:(AudioFileStreamID)inAudioFileStream
                       fileStreamPropertyID:(AudioFileStreamPropertyID)inPropertyID
                                    ioFlags:(UInt32 *)ioFlags;
- (void)handleAudioFileStreamFindPackets:(const void *)inInputData
                             numberBytes:(UInt32)inNumberBytes
                           numberPackets:(UInt32)inNumberPackets
                      packetDescriptions:(AudioStreamPacketDescription *)inPacketDescriptions;

- (OSStatus)handleAudioConverterComplexInputData:(AudioConverterRef)inAudioConverter
                             ioNumberDataPackets:(UInt32 *)ioNumberDataPackets
                                          ioData:(AudioBufferList *)ioData
                        outDataPacketDescription:(AudioStreamPacketDescription **)outDataPacketDescription;

@end


#pragma mark - AudioFileStream callbacks

// 当AudioFileStream从所有解析的音乐文件数据流中发现文件格式、大小和偏移量等信息时调用此函数
static void handleAudioFileStreamPropertyListenCallback(void *inClientData,
                                                        AudioFileStreamID inAudioFileStream,
                                                        AudioFileStreamPropertyID inPropertyID,
                                                        UInt32 *ioFlags) {
    
    AACDecoder *decoder = (__bridge AACDecoder *)inClientData;
    [decoder handleAudioFileStreamPropertyChange:inAudioFileStream
                            fileStreamPropertyID:inPropertyID
                                         ioFlags:ioFlags];
}


// ASBPAudioFileStreamPacketsCallback
// 当有音乐数据被解析出来可以播放时调用此函数，在次函数中把音乐流交给AudioQueue播放
//
static void handleAudioFileStreamPacketsCallback(void *inClientData,
                                                 UInt32	inNumberBytes,
                                                 UInt32	inNumberPackets,
                                                 const void *inInputData,
                                                 AudioStreamPacketDescription *inPacketDescriptions) {
    
    AACDecoder *decoder = (__bridge AACDecoder *)inClientData;
    
    
    [decoder handleAudioFileStreamFindPackets:inInputData
                                  numberBytes:inNumberBytes
                                numberPackets:inNumberPackets
                           packetDescriptions:inPacketDescriptions];
}

#pragma mark - AudioConverter callbacks

static OSStatus handleAudioConverterComplexInputDataProc(AudioConverterRef inAudioConverter,
                                                         UInt32 *ioNumberDataPackets,
                                                         AudioBufferList *ioData,
                                                         AudioStreamPacketDescription **outDataPacketDescription,
                                                         void *inUserData) {
    
    AACDecoder *decoder = (__bridge AACDecoder *)inUserData;
    return [decoder handleAudioConverterComplexInputData:inAudioConverter
                                     ioNumberDataPackets:ioNumberDataPackets
                                                  ioData:ioData
                                outDataPacketDescription:outDataPacketDescription];
}

@implementation AACDecoder

#pragma mark - lazy loading

- (NSMutableData *)pcmdata {
    if (!_pcmdata) {
        _pcmdata = [NSMutableData new];
    }
    return _pcmdata;
}

- (NSData*)canDecodeData:(NSData *)data {
    
    NSData *pcmdata = [self decode:data];
    [self flush];
    NSLog(@"length:::::::%lu",pcmdata.length);
    if (!pcmdata) {
        return nil;
    }
    
    return pcmdata;
}


- (NSData *)fetchMagicCookie
{
    UInt32 cookieSize;
    Boolean writable;
    OSStatus status = AudioFileStreamGetPropertyInfo(mAudioFileStreamID, kAudioFileStreamProperty_MagicCookieData, &cookieSize, &writable);
    if (status != noErr)
    {
        return nil;
    }
    
    void *cookieData = malloc(cookieSize);
    status = AudioFileStreamGetProperty(mAudioFileStreamID, kAudioFileStreamProperty_MagicCookieData, &cookieSize, cookieData);
    if (status != noErr)
    {
        return nil;
    }
    
    NSData *cookie = [NSData dataWithBytes:cookieData length:cookieSize];
    free(cookieData);
    
    return cookie;
}

#pragma mark - LXDecoderProtocol

- (NSData *)decode:(NSData *)rawdata {
    
    if (NULL == mAudioFileStreamID) {
        if (0 != AudioFileStreamOpen((__bridge void *)self,
                                     handleAudioFileStreamPropertyListenCallback,
                                     handleAudioFileStreamPacketsCallback,
                                     kAudioFileAAC_ADTSType,
                                     &mAudioFileStreamID)) {
            return nil;
        }
    }
    
     self.pcmdata = nil;
    
    if (0 != AudioFileStreamParseBytes(mAudioFileStreamID,
                                       (UInt32)rawdata.length,
                                       rawdata.bytes,
                                       0)) {
        return nil;
    }
    
//    if (!self.pcmFormat) {
//        
//        if (0 != memcmp(" caa", (char *)&(mSourceAudioStreamDescription.mFormatID), strlen("aac "))) {
//            return nil;
//        }
//    }
    
    if (self.decodedRawdataByteCount1 < 50 * 1024) {
        self.decodedRawdataByteCount1 += rawdata.length;
        self.decodedPCMdataByteCount1 += self.pcmdata.length;
    }
    
    self.decodedRawdataByteCount2 += rawdata.length;
    self.decodedPCMdataByteCount2 += self.pcmdata.length;
    
    return self.pcmdata;
}


- (RWFormat *)format {
    return self.pcmFormat;
}

- (void)flush {
    
    self.pcmdata                        = nil;
    self.decodedRawdataByteCount1       = 0;
    self.decodedRawdataByteCount2       = 0;
    self.decodedPCMdataByteCount1       = 0;
    self.decodedPCMdataByteCount2       = 0;
    
    
    //    self.pcmFormat      = nil;
    
    if (mAudioFileStreamID) {
        AudioFileStreamClose(mAudioFileStreamID);
        mAudioFileStreamID = NULL;
    }
    
    if (mAudioConverter) {
        //        AudioConverterDispose(mAudioConverter);
        //        mAudioConverter = NULL;
        AudioConverterReset(mAudioConverter);
    }
    
    if (mPCMDataBuffer) {
        free(mPCMDataBuffer);
        mPCMDataBuffer = NULL;
    }
    
    if (mPCMPacketDescriptions) {
        free(mPCMPacketDescriptions);
        mPCMPacketDescriptions = NULL;
    }
    
    mParsedRawData                  = NULL;
    mParsedRawDataSize              = 0;
    mParsedRawPacketsNumber         = 0;
    mParsedRawPacketDescriptions    = NULL;
}

- (BOOL)seekable {
    return NO;
}

#pragma mark - handle AudioFileStream callbacks

- (void)handleAudioFileStreamPropertyChange:(AudioFileStreamID)inAudioFileStream
                       fileStreamPropertyID:(AudioFileStreamPropertyID)inPropertyID
                                    ioFlags:(UInt32 *)ioFlags {
    
    char *propertyIDName = (char *)&inPropertyID;
//    NSLog(@"property ID is: %c%c%c%c", propertyIDName[3], propertyIDName[2], propertyIDName[1], propertyIDName[0]);
    
    if (inPropertyID == kAudioFileStreamProperty_DataFormat) {
        
        //        if (0 == mSourceAudioStreamDescription.mFormatID) {
        UInt32 size = sizeof(mSourceAudioStreamDescription);
        AudioFileStreamGetProperty(inAudioFileStream,
                                   kAudioFileStreamProperty_DataFormat,
                                   &size,
                                   &mSourceAudioStreamDescription);
        char *formatName = (char *)&(mSourceAudioStreamDescription.mFormatID);
        NSLog(@"format is: %c%c%c%c", formatName[3], formatName[2], formatName[1], formatName[0]);
        //        }
    }
    else if (inPropertyID == kAudioFileStreamProperty_BitRate) {
        
        UInt32 bitrate;
        UInt32 size = sizeof(bitrate);
        AudioFileStreamGetProperty(mAudioFileStreamID, kAudioFileStreamProperty_BitRate, &size, &bitrate);
        NSLog(@"bitrate is: %d", (int)bitrate);
    }
}

- (void)handleAudioFileStreamFindPackets:(const void *)inInputData
                             numberBytes:(UInt32)inNumberBytes
                           numberPackets:(UInt32)inNumberPackets
                      packetDescriptions:(AudioStreamPacketDescription *)inPacketDescriptions {
    
    //    NSLog(@"%@", NSStringFromSelector(_cmd));
    //    NSLog(@"parsed bytes is: %d, parsed packet number is: %d", inNumberBytes, inNumberPackets);
    if (_packetFormat == NULL) {
        _packetFormat = malloc(sizeof(AudioStreamPacketDescription));
        *_packetFormat = *inPacketDescriptions;
    }
    
    mParsedRawData                      = (void *)inInputData;
    mParsedRawDataSize                  = inNumberBytes;
    mParsedRawPacketsNumber             = inNumberPackets;
    mParsedRawPacketDescriptions        = inPacketDescriptions;
    
    OSStatus status;
    
    if (NULL == mAudioConverter) {
        
        _mTargetAudioStreamDescripion.mSampleRate         = 8000;
        _mTargetAudioStreamDescripion.mFormatID           = kAudioFormatLinearPCM;
        _mTargetAudioStreamDescripion.mFormatFlags        = kLinearPCMFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
        _mTargetAudioStreamDescripion.mChannelsPerFrame   = 1;
        _mTargetAudioStreamDescripion.mFramesPerPacket    = 1;
        _mTargetAudioStreamDescripion.mBitsPerChannel     = 16;
        
        _mTargetAudioStreamDescripion.mBytesPerFrame      = (_mTargetAudioStreamDescripion.mBitsPerChannel / 8) * _mTargetAudioStreamDescripion.mChannelsPerFrame;
        _mTargetAudioStreamDescripion.mBytesPerPacket     = _mTargetAudioStreamDescripion.mBytesPerFrame;
        
        self.pcmFormat = [RWFormat formatWithSampleRate:_mTargetAudioStreamDescripion.mSampleRate
                                                  channels:_mTargetAudioStreamDescripion.mChannelsPerFrame
                                             bitsPerSample:_mTargetAudioStreamDescripion.mBitsPerChannel];
        
        
        
        if (0 != (AudioConverterNew(&mSourceAudioStreamDescription, &_mTargetAudioStreamDescripion, &mAudioConverter))) {
            char *codeString = (char *)&status;
            NSLog(@"create AudioConverter failed with code: %d, %c%c%c%c",
                  status, codeString[3], codeString[2], codeString[1], codeString[0]);
            return;
        }
    }
    
    if (NULL == mPCMDataBuffer) {
        if (NULL == (mPCMDataBuffer = (char *)malloc(sizeof(Byte) * kPCMDataBufferSize))) {
            NSLog(@"no memory!");
            return;
        }
    }
    AudioBufferList pcmBuffList;
    pcmBuffList.mNumberBuffers                  = 1;
    pcmBuffList.mBuffers[0].mNumberChannels     = _mTargetAudioStreamDescripion.mChannelsPerFrame;
    pcmBuffList.mBuffers[0].mDataByteSize       = kPCMDataBufferSize;
    pcmBuffList.mBuffers[0].mData               = mPCMDataBuffer;
    
    if (NULL == mPCMPacketDescriptions) {
        
        UInt32 outputSizePerPacket = _mTargetAudioStreamDescripion.mBytesPerPacket; // this will be non-zero if the format is CBR
        
        if (outputSizePerPacket == 0) {
            // if the destination format is VBR, we need to get max size per packet from the converter
            UInt32 size = sizeof(outputSizePerPacket);
            AudioConverterGetProperty(mAudioConverter, kAudioConverterPropertyMaximumOutputPacketSize, &size, &outputSizePerPacket);
            
            // allocate memory for the PacketDescription structures describing the layout of each packet
            mPCMPacketDescriptions = (AudioStreamPacketDescription *)malloc(sizeof(AudioStreamPacketDescription) * (kRawBufferSize / outputSizePerPacket));
            if (NULL == mPCMPacketDescriptions) {
                NSLog(@"no memory!");
                return;
            }
        }
        mPCMPacketsNumber = kRawBufferSize / outputSizePerPacket;
    }
    
    UInt32 ioPacketsNumber = mPCMPacketsNumber;
    status = AudioConverterFillComplexBuffer(mAudioConverter,
                                             handleAudioConverterComplexInputDataProc,
                                             (__bridge void *)self,
                                             &ioPacketsNumber,
                                             &pcmBuffList,
                                             mPCMPacketDescriptions);
    //    char *code = (char *)&status;
    //    NSLog(@"fill complex buffer return with code: %d %c%c%c%c", status, code[3], code[2], code[1], code[0]);
    if (status != 0 && status != -1) {
        return;
    }
    
    if ([_aacDecodeDelegate respondsToSelector:@selector(pcmDataToPlay:size:)]) {
        [_aacDecodeDelegate pcmDataToPlay:pcmBuffList.mBuffers[0].mData size:pcmBuffList.mBuffers[0].mDataByteSize];
    }
    
    [self.pcmdata appendData:[NSData dataWithBytes:pcmBuffList.mBuffers[0].mData
                                            length:pcmBuffList.mBuffers[0].mDataByteSize]];
    
    return;
}

#pragma mark - handle AudioConverter callbacks

- (OSStatus)handleAudioConverterComplexInputData:(AudioConverterRef)inAudioConverter
                             ioNumberDataPackets:(UInt32 *)ioNumberDataPackets
                                          ioData:(AudioBufferList *)ioData
                        outDataPacketDescription:(AudioStreamPacketDescription **)outDataPacketDescription {
    
    //    NSLog(@"%@", NSStringFromSelector(_cmd));
    
    if (0 == mParsedRawPacketsNumber
        || 0 == mParsedRawDataSize) {
        
        *ioNumberDataPackets        = 0;
        *outDataPacketDescription   = NULL;
        
        return -1;
    }
    
    //    NSLog(@"rawdata size is: %d, packet number is: %d", (int)mParsedRawDataSize, (int)mParsedRawPacketsNumber);
    
    *ioNumberDataPackets                    = mParsedRawPacketsNumber;
    
    ioData->mBuffers[0].mData               = mParsedRawData;
    ioData->mBuffers[0].mDataByteSize       = mParsedRawDataSize;
    ioData->mBuffers[0].mNumberChannels     = mSourceAudioStreamDescription.mChannelsPerFrame;
    
    // don't forget the packet descriptions if required
    if (outDataPacketDescription) {
        if (mParsedRawPacketDescriptions) {
            *outDataPacketDescription = mParsedRawPacketDescriptions;
        }
        else {
            *outDataPacketDescription = NULL;
        }
    }
    
    mParsedRawPacketsNumber     = 0;
    mParsedRawData              = NULL;
    mParsedRawDataSize = 0;
    
    return 0;
}

- (void)dealloc
{
    [self flush];
    
}

@end

