//
//  PCMDecodeFromAAC.m
//  视频录制
//
//  Created by tongguan on 16/1/8.
//  Copyright © 2016年 未成年大叔. All rights reserved.
//

#define BitRateEstimationMaxPackets 5000
#define BitRateEstimationMinPackets 100
#import "PCMDecodeFromAAC.h"
#import <AudioToolbox/AudioConverter.h>
#import <AudioToolbox/AudioFileStream.h>


@interface PCMDecodeFromAAC()
{
    AudioConverterRef _decodeConvert;
    AudioFileStreamID _audioFileStreamID;
    
    AudioBufferList* _currentData;
    
    
    AudioStreamBasicDescription                 _mSourceAudioStreamDescription;
    AudioStreamBasicDescription                 _mTargetAudioStreamDescription;
    
    
    
#pragma mark audioFileStream
    BOOL _readyToProducePackets;
    BOOL _discontinuous;
    NSTimeInterval _packetDuration;
    UInt64 _processedPacketsCount;
    UInt64 _processedPacketsSizeTotal;



}
- (void)handleAudioFileStreamProperty:(AudioFileStreamPropertyID)propertyID;
- (void)handleAudioFileStreamPackets:(const void *)packets
                       numberOfBytes:(UInt32)numberOfBytes
                     numberOfPackets:(UInt32)numberOfPackets
                  packetDescriptions:(AudioStreamPacketDescription *)packetDescriptioins;
@end
@implementation PCMDecodeFromAAC

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self _openAudioFileStreamWithFileTypeHint:kAudioFileAAC_ADTSType error:nil];
        [self _createEncoder];
        
    }
    return self;
}

static OSStatus handleAudioConverterComplexInputDataProc(AudioConverterRef inAudioConverter,
                                                         UInt32 *ioNumberDataPackets,
                                                         AudioBufferList *ioData,
                                                         AudioStreamPacketDescription **outDataPacketDescription,
                                                         void *inUserData) {
    
    PCMDecodeFromAAC *decoder = (__bridge PCMDecodeFromAAC *)inUserData;
    return [decoder handleAudioConverterComplexInputData:inAudioConverter
                                     ioNumberDataPackets:ioNumberDataPackets
                                                  ioData:ioData
                                outDataPacketDescription:outDataPacketDescription];
}
- (OSStatus)handleAudioConverterComplexInputData:(AudioConverterRef)inAudioConverter
                             ioNumberDataPackets:(UInt32 *)ioNumberDataPackets
                                          ioData:(AudioBufferList *)ioData
                        outDataPacketDescription:(AudioStreamPacketDescription **)outDataPacketDescription {
    
    //    NSLog(@"%@", NSStringFromSelector(_cmd));
    
    if (0 == ioNumberDataPackets || NULL == _currentData) {
        
        *ioNumberDataPackets        = 0;
        *outDataPacketDescription   = NULL;
        return -1;
    }
    
    
    //    NSLog(@"rawdata size is: %d, packet number is: %d", (int)mParsedRawDataSize, (int)mParsedRawPacketsNumber);
    ioData->mNumberBuffers = 1;
    ioData->mBuffers[0].mData = _currentData->mBuffers[0].mData;
    ioData->mBuffers[0].mDataByteSize = _currentData->mBuffers[0].mDataByteSize;
    ioData->mBuffers[0].mNumberChannels = _currentData->mBuffers[0].mNumberChannels;
    
    *ioNumberDataPackets = 1;
    

    
    _currentData     = NULL;
   
    
    return 0;
}

-(void)decodeBuffer:(uint8_t*)buffer withLenth:(uint32_t)totalLenth{
 
    if (_audioFileStreamID == 0) {
        [self _openAudioFileStreamWithFileTypeHint:kAudioFileAAC_ADTSType error:nil];
    }
    
    OSStatus status = AudioFileStreamParseBytes(_audioFileStreamID,totalLenth,buffer, 0);


}

-(BOOL)_createEncoder{
    if (_decodeConvert != NULL) {
        return YES;
    }
    if (!_readyToProducePackets) {
        return NO;
    }
    
    _mTargetAudioStreamDescription.mSampleRate         = 44100;
    _mTargetAudioStreamDescription.mFormatID           = kAudioFormatLinearPCM;
    _mTargetAudioStreamDescription.mFormatFlags        = kLinearPCMFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    _mTargetAudioStreamDescription.mChannelsPerFrame   = 1;
    _mTargetAudioStreamDescription.mFramesPerPacket    = 1;
    _mTargetAudioStreamDescription.mBitsPerChannel     = 16;
    
    _mTargetAudioStreamDescription.mBytesPerFrame      = (_mTargetAudioStreamDescription.mBitsPerChannel / 8) * _mTargetAudioStreamDescription.mChannelsPerFrame;
    _mTargetAudioStreamDescription.mBytesPerPacket    = _mTargetAudioStreamDescription.mBytesPerFrame;
    
    UInt32 size = sizeof(AudioStreamBasicDescription);
    AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, NULL, &size, &_mTargetAudioStreamDescription);
    
   
    OSStatus status = (AudioConverterNew(&_mSourceAudioStreamDescription, &_mTargetAudioStreamDescription, &_decodeConvert));
    assert(!status);
    if (0 != status) {
        NSLog(@"create AudioConverter failed ");
        return NO;
    }
   
    return YES;
}


#pragma mark filestream
#pragma mark - static callbacks
static void MCSAudioFileStreamPropertyListener(void *inClientData,
                                               AudioFileStreamID inAudioFileStream,
                                               AudioFileStreamPropertyID inPropertyID,
                                               UInt32 *ioFlags)
{
    PCMDecodeFromAAC *decodeFromAAC = (__bridge PCMDecodeFromAAC *)inClientData;
    [decodeFromAAC handleAudioFileStreamProperty:inPropertyID];
}

static void MCAudioFileStreamPacketsCallBack(void *inClientData,
                                             UInt32 inNumberBytes,
                                             UInt32 inNumberPackets,
                                             const void *inInputData,
                                             AudioStreamPacketDescription *inPacketDescriptions)
{
    PCMDecodeFromAAC *decodeFromAAC = (__bridge PCMDecodeFromAAC *)inClientData;
    [decodeFromAAC handleAudioFileStreamPackets:inInputData
                                    numberOfBytes:inNumberBytes
                                  numberOfPackets:inNumberPackets
                               packetDescriptions:inPacketDescriptions];
}



- (BOOL)_openAudioFileStreamWithFileTypeHint:(AudioFileTypeID)fileTypeHint error:(NSError *__autoreleasing *)error
{
    
    OSStatus status = AudioFileStreamOpen((__bridge void *)self,
                                          MCSAudioFileStreamPropertyListener,
                                          MCAudioFileStreamPacketsCallBack,
                                          fileTypeHint,
                                          &_audioFileStreamID);
    
    if (status != noErr)
    {
        _audioFileStreamID = NULL;
    }
    
    return status == noErr;
}

- (void)_closeAudioFileStream
{
    if (_audioFileStreamID != NULL)
    {
        AudioFileStreamClose(_audioFileStreamID);
        _audioFileStreamID = NULL;
    }
}



- (void)calculateBitRate
{
    if (_packetDuration && _processedPacketsCount > BitRateEstimationMinPackets && _processedPacketsCount <= BitRateEstimationMaxPackets)
    {
        double averagePacketByteSize = _processedPacketsSizeTotal / _processedPacketsCount;
        _bitRate = 8.0 * averagePacketByteSize / _packetDuration;
    }
}

- (void)calculatepPacketDuration
{
    if (_mSourceAudioStreamDescription.mSampleRate > 0)
    {
        _packetDuration = _mSourceAudioStreamDescription.mFramesPerPacket / _mSourceAudioStreamDescription.mSampleRate;
    }
}


- (void)handleAudioFileStreamProperty:(AudioFileStreamPropertyID)propertyID
{
    if (propertyID == kAudioFileStreamProperty_ReadyToProducePackets)
    {
        _readyToProducePackets = YES;
        _discontinuous = YES;
        
        UInt32 sizeOfUInt32 = sizeof(_maxPacketSize);
        OSStatus status = AudioFileStreamGetProperty(_audioFileStreamID, kAudioFileStreamProperty_PacketSizeUpperBound, &sizeOfUInt32, &_maxPacketSize);
        if (status != noErr || _maxPacketSize == 0)
        {
            status = AudioFileStreamGetProperty(_audioFileStreamID, kAudioFileStreamProperty_MaximumPacketSize, &sizeOfUInt32, &_maxPacketSize);
        }
    }else if (propertyID == kAudioFileStreamProperty_DataFormat)
    {
        UInt32 asbdSize = sizeof(_mSourceAudioStreamDescription);
        AudioFileStreamGetProperty(_audioFileStreamID, kAudioFileStreamProperty_DataFormat, &asbdSize, &_mSourceAudioStreamDescription);
        
        char *formatName = (char *)&(_mSourceAudioStreamDescription.mFormatID);
        NSLog(@"format is: %c%c%c%c", formatName[3], formatName[2], formatName[1], formatName[0]);
        [self calculatepPacketDuration];
    }else if (propertyID == kAudioFileStreamProperty_FormatList){
        Boolean outWriteable;
        UInt32 formatListSize;
        OSStatus status = AudioFileStreamGetPropertyInfo(_audioFileStreamID, kAudioFileStreamProperty_FormatList, &formatListSize, &outWriteable);
        if (status == noErr)
        {
            AudioFormatListItem *formatList = malloc(formatListSize);
            OSStatus status = AudioFileStreamGetProperty(_audioFileStreamID, kAudioFileStreamProperty_FormatList, &formatListSize, formatList);
            if (status == noErr)
            {
                UInt32 supportedFormatsSize;
                status = AudioFormatGetPropertyInfo(kAudioFormatProperty_DecodeFormatIDs, 0, NULL, &supportedFormatsSize);
                if (status != noErr)
                {
                    free(formatList);
                    return;
                }
                UInt32 supportedFormatCount = supportedFormatsSize / sizeof(OSType);
                OSType *supportedFormats = (OSType *)malloc(supportedFormatsSize);
                status = AudioFormatGetProperty(kAudioFormatProperty_DecodeFormatIDs, 0, NULL, &supportedFormatsSize, supportedFormats);
                if (status != noErr)
                {
                    free(formatList);
                    free(supportedFormats);
                    return;
                }
                for (int i = 0; i * sizeof(AudioFormatListItem) < formatListSize; i ++)
                {
                    AudioStreamBasicDescription format = formatList[i].mASBD;
                    for (UInt32 j = 0; j < supportedFormatCount; ++j)
                    {
                        NSLog(@"format:%d  support:%d",(unsigned int)format.mFormatID,(unsigned int)supportedFormats[j]);
                        if (format.mFormatID == supportedFormats[j])
                        {
                            _mSourceAudioStreamDescription = format;
                            [self calculatepPacketDuration];
                        }
                    }
                }
                free(supportedFormats);
            }
            free(formatList);
        }
    }
}

- (void)handleAudioFileStreamPackets:(const void *)packets
                       numberOfBytes:(UInt32)numberOfBytes
                     numberOfPackets:(UInt32)numberOfPackets
                  packetDescriptions:(AudioStreamPacketDescription *)packetDescriptioins
{
    if (_discontinuous){
        _discontinuous = NO;
    }
    if (numberOfBytes == 0 || numberOfPackets == 0){
        return;
    }
    BOOL deletePackDesc = NO;
    if (packetDescriptioins == NULL)
    {
        deletePackDesc = YES;
        UInt32 packetSize = numberOfBytes / numberOfPackets;
        AudioStreamPacketDescription *descriptions = (AudioStreamPacketDescription *)malloc(sizeof(AudioStreamPacketDescription) * numberOfPackets);
        for (int i = 0; i < numberOfPackets; i++)
        {
            UInt32 packetOffset = packetSize * i;
            descriptions[i].mStartOffset = packetOffset;
            descriptions[i].mVariableFramesInPacket = 0;
            if (i == numberOfPackets - 1)
            {
                descriptions[i].mDataByteSize = numberOfBytes - packetOffset;
            }
            else
            {
                descriptions[i].mDataByteSize = packetSize;
            }
        }
        packetDescriptioins = descriptions;
    }
    
    AudioBufferList dataList;
    dataList.mNumberBuffers = 1;
    dataList.mBuffers[0].mData = packets;
    dataList.mBuffers[0].mDataByteSize = numberOfBytes;
    dataList.mBuffers[0].mNumberChannels = 1;
    
    UInt32 outPCMBufferSize = numberOfPackets;
    _currentData = &dataList;
    if (_decodeConvert == NULL) {
       BOOL status = [self _createEncoder];
        if (!status) {
            return;
        }else{
            outPCMBufferSize = numberOfBytes / _mTargetAudioStreamDescription.mBytesPerPacket;
        }
    }
    
    NSMutableArray *parsedDataArray = [[NSMutableArray alloc] init];
    for (int i = 0; i < numberOfPackets; ++i)
    {
        SInt64 packetOffset = packetDescriptioins[i].mStartOffset;
        
        
        if (_processedPacketsCount < BitRateEstimationMaxPackets)
        {
            _processedPacketsCount += 1;
            [self calculateBitRate];
        }
    }
    
    AudioBufferList outPCMBufferList;
    AudioStreamPacketDescription* outPacketDescriptioins = malloc(sizeof(AudioStreamPacketDescription) * numberOfPackets);
    OSStatus status = AudioConverterFillComplexBuffer(_decodeConvert,
                                                      handleAudioConverterComplexInputDataProc,
                                                      (__bridge void *)self,
                                                      &outPCMBufferSize,
                                                      &outPCMBufferList,
                                                      packetDescriptioins);
    char* statusStr = (char*)&status;
    NSLog(@"%c %c %c %c",statusStr[0],statusStr[1],statusStr[2],statusStr[3]);
//    assert(!status);
    
    if (deletePackDesc)
    {
        free(packetDescriptioins);
    
    }
}

@end
