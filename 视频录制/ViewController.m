//
//  ViewController.m
//  视频录制
//
//  Created by 未成年大叔 on 15/9/1.
//  Copyright (c) 2015年 未成年大叔. All rights reserved.
//

#import "ViewController.h"
#import "OpenGLView20.h"
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <VideoToolbox/VideoToolbox.h>
#import "GJH264Decoder.h"
#import "GJH264Encoder.h"
#import "GJAudioQueuePlayer.h"
#import "AACEncoderFromPCM.h"
#import "PCMDecodeFromAAC.h"
#import "MCAudioFileStream.h"
#import "AudioEncoder.h"
#import "GJAudioQueueRecoder.h"
#import "AACDecoder.h"
#define fps 10
typedef void(^PropertyChangeBlock)(AVCaptureDevice *captureDevice);

@interface ViewController ()<AVCaptureFileOutputRecordingDelegate,AVCaptureVideoDataOutputSampleBufferDelegate,AVCaptureAudioDataOutputSampleBufferDelegate,GJH264DecoderDelegate,GJH264EncoderDelegate,AACEncoderFromPCMDelegate,MCAudioFileStreamDelegate,aacCallbackDelegate,AACDecodeTocPCMCallBack,PCMDecodeFromAACDelegate,GJAudioQueueRecoderDelegate>//视频文件输出代理
{
    GJAudioQueuePlayer* _streamQueue;

    long frameCount;///每一重计，计算帧率
    long totalCount;////总共多少帧
    long totalSize;////总共传输大小
    
    long _audioOffset;//音频偏移
    
    NSTimer* _timer;
    GJAudioQueuePlayer* _audioOutputQueue;
    AACEncoderFromPCM* _audioEncoder;
    PCMDecodeFromAAC* _audioDecoder;
    AudioEncoder* _RWAudioEncoder;
    AACDecoder* _RWAudioDecoder;
    
    GJAudioQueueRecoder* _recoder;
    
    dispatch_queue_t _playQueue;


}
@property (strong,nonatomic) AVCaptureSession *captureSession;//负责输入和输出设备之间的数据传递
@property(strong,nonatomic)AVCaptureDevice *audioCaptureDevice;   //音频输入设备
@property (strong,nonatomic)AVCaptureDeviceInput *audioCaptureDeviceInput; //音频输入
@property (strong,nonatomic) AVCaptureDeviceInput *captureDeviceInput;//负责从AVCaptureDevice获得输入数据
@property (strong,nonatomic) AVCaptureMovieFileOutput *captureMovieFileOutput;//视频输出流
@property (strong,nonatomic) AVCaptureVideoDataOutput *captureDataOutput;//视频输出流
@property (strong,nonatomic) AVCaptureAudioDataOutput *captureAudioOutput;//音频输出流

@property (strong,nonatomic) AVCaptureConnection *videoConnect;//视频链接
@property (strong,nonatomic) AVCaptureConnection *audioConnect;//音频链接

@property (strong,nonatomic) dispatch_queue_t audioQueue;//音频线程
@property (strong,nonatomic) dispatch_queue_t videoQueue;//视频线程
@property (strong,nonatomic) dispatch_queue_t dealDataQueue;//处理数据线程





@property (strong,nonatomic) AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;//相机拍摄预览图层
@property (strong,nonatomic)AVCaptureDevice *captureDevice;//相机拍摄预览图层

@property (assign,nonatomic) BOOL enableRotation;//是否允许旋转（注意在视频录制过程中禁止屏幕旋转）
@property (assign,nonatomic) CGRect *lastBounds;//旋转的前大小
@property (assign,nonatomic) UIBackgroundTaskIdentifier backgroundTaskIdentifier;//后台任务标识
@property (weak, nonatomic) IBOutlet UIView *viewContainer;
@property (weak, nonatomic) IBOutlet UIButton *takeButton;//拍照按钮
@property (weak, nonatomic) IBOutlet UIImageView *focusCursor; //聚焦光标
@property (weak, nonatomic) IBOutlet OpenGLView20 *playView;    ///播放view


@property (weak, nonatomic) IBOutlet UILabel *fpsLab;
@property (weak, nonatomic) IBOutlet UILabel *ptsLab;

@property(nonatomic)GJH264Decoder* decoder;
@property(nonatomic)GJH264Encoder* encoder;

@property(nonatomic)BOOL isFileStore;//是否文件存储；

//@property (nonatomic, assign) int spsSize;
//@property (nonatomic, assign) int ppsSize;




@end


@implementation ViewController


#pragma mark - 控制器视图方法

-(void)timeFire:(NSTimer*)time{
    self.fpsLab.text = [NSString stringWithFormat:@"fps:%ld",frameCount];
    self.ptsLab.text = [NSString stringWithFormat:@"pts:%0.2f kb/s",totalSize/1024.0];
    totalSize = 0;
    frameCount = 0;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.openALPlayer = [[HYOpenALHelper alloc]init];
    [self.openALPlayer initOpenAL];
 
    _audioEncoder = [[AACEncoderFromPCM alloc]init];
    _audioEncoder.delegate = self;
//    _audioDecoder = [[MCAudioFileStream alloc]initWithFileType:kAudioFileAAC_ADTSType fileSize:0 error:nil];
//    _audioDecoder.delegate = self;
    _RWAudioEncoder = [[AudioEncoder alloc]init];
    _RWAudioEncoder.aacCallbackDelegate = self;
    _RWAudioDecoder = [[AACDecoder alloc]init];
    _RWAudioDecoder.aacDecodeDelegate = self;
#if 0
    openGLLayer = [[AAPLEAGLLayer alloc]init];
    [self.playView.layer addSublayer:openGLLayer];
    openGLLayer.frame = self.playView.bounds;
    [openGLLayer setupGL];
#endif
    _isFileStore = NO;
    if (!_isFileStore) {
        _encoder = [[GJH264Encoder alloc]init];
        _encoder.deleagte = self;
        _decoder = [[GJH264Decoder alloc]init];
        _decoder.delegate = self;
        _timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(timeFire:) userInfo:nil repeats:YES];
    }
    
}

-(void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    //初始化会话
    _captureSession=[[AVCaptureSession alloc]init];
    if ([_captureSession canSetSessionPreset:AVCaptureSessionPreset640x480]) {//设置分辨率
        _captureSession.sessionPreset=AVCaptureSessionPreset640x480;
    }
 
    //获得输入设备
    self.captureDevice=[self getCameraDeviceWithPosition:AVCaptureDevicePositionBack];//取得后置摄像头
    if (!self.captureDevice) {
        NSLog(@"取得后置摄像头时出现问题.");
        return;
    }
    NSError* error;
   
    //添加一个音频输入设备
    _audioCaptureDevice=[[AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio] firstObject];
    
    
    //根据输入设备初始化设备输入对象，用于获得输入数据
    _captureDeviceInput=[[AVCaptureDeviceInput alloc]initWithDevice:self.captureDevice error:&error];
    if (error) {
        NSLog(@"取得设备输入对象时出错，错误原因：%@",error.localizedDescription);
        return;
    }
    _audioCaptureDeviceInput=[[AVCaptureDeviceInput alloc]initWithDevice:_audioCaptureDevice error:&error];
    if (error) {
        NSLog(@"取得设备输入对象时出错，错误原因：%@",error.localizedDescription);
        return;
    }
    _captureAudioOutput = [[AVCaptureAudioDataOutput alloc]init];
    if ([_captureSession canAddOutput:_captureAudioOutput]) {
        [_captureSession addOutput:_captureAudioOutput];
    }
    //初始化设备输出对象，用于获得输出数据
    if(_isFileStore){
        _captureMovieFileOutput = [[AVCaptureMovieFileOutput alloc]init];
        if ([_captureSession canAddOutput:_captureMovieFileOutput]) {
            [_captureSession addOutput:_captureMovieFileOutput];
        }


    }else{
        _captureDataOutput = [[AVCaptureVideoDataOutput alloc] init];
        if ([_captureSession canAddOutput:_captureDataOutput]) {
            [_captureSession addOutput:_captureDataOutput];
        }
    }

    //将设备输入添加到会话中
    if ([_captureSession canAddInput:_captureDeviceInput]) {
        [_captureSession addInput:_captureDeviceInput];
    }
    if ([_captureSession canAddInput:_audioCaptureDeviceInput]) {
        [_captureSession addInput:_audioCaptureDeviceInput];
    }
    
    _videoConnect = [_captureDataOutput connectionWithMediaType:AVMediaTypeVideo];
    _audioConnect = [_captureAudioOutput connectionWithMediaType:AVMediaTypeAudio];
    //创建视频预览层，用于实时展示摄像头状态
    _captureVideoPreviewLayer=[[AVCaptureVideoPreviewLayer alloc]initWithSession:self.captureSession];
    
    CALayer *layer=self.viewContainer.layer;
    layer.masksToBounds=YES;
    
    _captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspect;//填充模式
    //将视频预览层添加到界面中
    //[layer addSublayer:_captureVideoPreviewLayer];
    [layer insertSublayer:_captureVideoPreviewLayer below:self.focusCursor.layer];
    _captureVideoPreviewLayer.frame=layer.bounds;

    
    [self addNotificationToCaptureDevice:self.captureDevice];
    [self addGenstureRecognizer];
    
    
    //链接创建后
    if([self.captureDevice lockForConfiguration:&error]){
        self.captureDevice.activeVideoMinFrameDuration = CMTimeMake(1, fps);
        self.captureDevice.activeVideoMaxFrameDuration = CMTimeMake(1, fps);
        [self.captureDevice unlockForConfiguration];
    }else{
        NSLog(@"error:%@",error.localizedDescription);
        return;
    }
    _enableRotation = YES;
    
    _audioQueue = dispatch_queue_create("audio", DISPATCH_QUEUE_CONCURRENT);
    _videoQueue = dispatch_queue_create("video", DISPATCH_QUEUE_CONCURRENT);
    _dealDataQueue = dispatch_queue_create("dealData", DISPATCH_QUEUE_CONCURRENT);
    

   
}

//[weakSelf.openALPlayer insertPCMDataToQueue:(unsigned char *)buf size:(UInt32)size samplerate:(int)bufinfo.samples_per_sec bitPerFrame:bufinfo.bits_per_sample channels:bufinfo.channels];

-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    [self.captureSession startRunning];
//    [_encoder restart];
}

-(void)viewDidDisappear:(BOOL)animated{
    [super viewDidDisappear:animated];
    [self.captureSession stopRunning];
    [_encoder stop];
}

-(BOOL)shouldAutorotate{
    return self.enableRotation;
}


////屏幕旋转时调整视频预览图层的方向

-(void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection{
    [super traitCollectionDidChange:previousTraitCollection];
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    AVCaptureConnection *captureConnection=[self.captureVideoPreviewLayer connection];
    captureConnection.videoOrientation = (AVCaptureVideoOrientation)orientation;
}


//旋转后重新设置大小
-(void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation{
    _captureVideoPreviewLayer.frame=self.viewContainer.bounds;
}

//-(void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator{
//    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
//    NSLog(@"%@", [NSValue valueWithCGRect: self.viewContainer.layer.bounds]);
//    _captureVideoPreviewLayer.frame=self.viewContainer.layer.bounds;
//}


-(void)dealloc{
    [self removeNotification];
}
#pragma mark - UI方法
#pragma mark 视频录制
- (IBAction)takeButtonClick:(UIButton *)sender {
    //根据设备输出获得连接
    
//    if (_isFileStore) {
//        AVCaptureConnection *captureConnection=[self.captureMovieFileOutput connectionWithMediaType:AVMediaTypeVideo];
//        NSString *outputFielPath=[NSTemporaryDirectory() stringByAppendingString:@"myMovie.mov"];
//        NSLog(@"save path is :%@",outputFielPath);
//        
//        //根据连接取得设备输出的数据
//        if (![self.captureMovieFileOutput isRecording]) {
//            [sender setTitle:@"停止录制" forState:UIControlStateNormal];
//            //        self.enableRotation=NO;
//            //如果支持多任务则则开始多任务
//            if ([[UIDevice currentDevice] isMultitaskingSupported]) {
//                self.backgroundTaskIdentifier=[[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:nil];
//            }
//            //预览图层和视频方向保持一致
//            captureConnection.videoOrientation=[self.captureVideoPreviewLayer connection].videoOrientation;
//            [self.captureMovieFileOutput startRecordingToOutputFileURL:[NSURL fileURLWithPath:outputFielPath] recordingDelegate:self];
//        }
//        else{
//            [self.captureMovieFileOutput stopRecording];//停止录制
//            [sender setTitle:@"开始录制" forState:UIControlStateNormal];
//        }
//    }else{
//        if ([sender.titleLabel.text isEqualToString:@"开始录制"]) {
////            self.captureDataOutput.videoSettings = @{(id)kCVPixelBufferPixelFormatTypeKey:@(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)};
//            [self.captureDataOutput setSampleBufferDelegate:self queue:_videoQueue];
//            [self.captureAudioOutput setSampleBufferDelegate:self queue:_audioQueue];
//            [sender setTitle:@"停止录制" forState:UIControlStateNormal];
//        }else{
//            [self.captureDataOutput setSampleBufferDelegate:nil queue:NULL];
//            [sender setTitle:@"开始录制" forState:UIControlStateNormal];
//        }
//    }
//    
//    
//    return;
    AudioStreamBasicDescription desc;
    memset(&desc, 0, sizeof(AudioStreamBasicDescription));
    
    desc.mFormatID = kAudioFormatLinearPCM;
    desc.mBitsPerChannel = 16;
    desc.mChannelsPerFrame = 1;
    desc.mSampleRate = 44100;
    desc.mFramesPerPacket = 1;
    desc.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger|kLinearPCMFormatFlagIsPacked;
    
//    desc.mFormatID         = kAudioFormatMPEG4AAC; // 2
//    desc.mSampleRate       = 44100;               // 3
//    desc.mChannelsPerFrame = 2;                     // 4
//    desc.mFramesPerPacket  = 1024;                     // 7
    _recoder = [[GJAudioQueueRecoder alloc]initWithStreamDestFormat:&desc];
    _recoder.delegate = self;
    [_recoder startRecodeAudio];
    
    
}

#pragma mark 切换前后摄像头
- (IBAction)toggleButtonClick:(UIButton *)sender {
    [self removeNotificationFromCaptureDevice:self.captureDevice];
    AVCaptureDevicePosition currentPosition=[self.captureDevice position];
   
    self.captureDevice =[self.captureDeviceInput device];
    AVCaptureDevicePosition toChangePosition=AVCaptureDevicePositionFront;
    if (currentPosition==AVCaptureDevicePositionUnspecified||currentPosition==AVCaptureDevicePositionFront) {
        toChangePosition=AVCaptureDevicePositionBack;
    }
    
    self.captureDevice =[self getCameraDeviceWithPosition:toChangePosition];
    [self addNotificationToCaptureDevice:self.captureDevice ];
    //获得要调整的设备输入对象
    AVCaptureDeviceInput *toChangeDeviceInput=[[AVCaptureDeviceInput alloc]initWithDevice:self.captureDevice  error:nil];
    
    //改变会话的配置前一定要先开启配置，配置完成后提交配置改变
    [self.captureSession beginConfiguration];
    //移除原有输入对象
    [self.captureSession removeInput:self.captureDeviceInput];
    //添加新的输入对象
    if ([self.captureSession canAddInput:toChangeDeviceInput]) {
        [self.captureSession addInput:toChangeDeviceInput];
        self.captureDeviceInput=toChangeDeviceInput;
    }
    //提交会话配置
    [self.captureSession commitConfiguration];
    
    self.captureDeviceInput = toChangeDeviceInput;
    
    NSError* error;
    //链接创建后
    if([self.captureDevice lockForConfiguration:&error]){
        self.captureDevice.activeVideoMinFrameDuration = CMTimeMake(1, fps);
        self.captureDevice.activeVideoMaxFrameDuration = CMTimeMake(1, fps);
        [self.captureDevice unlockForConfiguration];
    }else{
        NSLog(@"error:%@",error.localizedDescription);
        return;
    }
}

#pragma mark - 视频输出代理
-(void)captureOutput:(AVCaptureFileOutput *)captureOutput didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections{
    NSLog(@"开始录制...");
}
-(void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error{
    NSLog(@"视频录制完成.");
    //视频录入完成之后在后台将视频存储到相簿
    self.enableRotation=YES;
    self.backgroundTaskIdentifier = [[UIApplication sharedApplication]beginBackgroundTaskWithExpirationHandler:^{
       
    }];
     [self saveToAlbum:outputFileURL];
    
    
}

-(BOOL)saveToAlbum:(NSURL*)outputFileURL{
    ALAssetsLibrary *assetsLibrary=[[ALAssetsLibrary alloc]init];
   __block BOOL flg;
    [assetsLibrary writeVideoAtPathToSavedPhotosAlbum:outputFileURL completionBlock:^(NSURL *assetURL, NSError *error) {
        if (error) {
            NSLog(@"保存视频到相簿过程中发生错误，错误信息：%@",error.localizedDescription);
            flg = NO;
        }
        NSLog(@"成功保存视频到相簿.");

        if (self.backgroundTaskIdentifier != UIBackgroundTaskInvalid) {
            [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTaskIdentifier];
            self.backgroundTaskIdentifier = UIBackgroundTaskInvalid;
        }
        flg = YES;
    }];
    return flg;

}

#pragma mark - 通知
/**
 *  给输入设备添加通知
 */
-(void)addNotificationToCaptureDevice:(AVCaptureDevice *)captureDevice{
    //注意添加区域改变捕获通知必须首先设置设备允许捕获
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        captureDevice.subjectAreaChangeMonitoringEnabled=YES;
    }];
    NSNotificationCenter *notificationCenter= [NSNotificationCenter defaultCenter];
    //捕获区域发生改变
    [notificationCenter addObserver:self selector:@selector(areaChange:) name:AVCaptureDeviceSubjectAreaDidChangeNotification object:captureDevice];
}
-(void)printCMTime:(CMTime)time flg:(NSString*)str{
    NSLog(@"flg:%@    value:%lld    timescale:%d   sec:%f 秒",str,time.value,time.timescale,(time.value * 0.1)/time.timescale);
}
////收到buffer





-(void)removeNotificationFromCaptureDevice:(AVCaptureDevice *)captureDevice{
    NSNotificationCenter *notificationCenter= [NSNotificationCenter defaultCenter];
    [notificationCenter removeObserver:self name:AVCaptureDeviceSubjectAreaDidChangeNotification object:captureDevice];
}
/**
 *  移除所有通知
 */
-(void)removeNotification{
    NSNotificationCenter *notificationCenter= [NSNotificationCenter defaultCenter];
    [notificationCenter removeObserver:self];
}

-(void)addNotificationToCaptureSession:(AVCaptureSession *)captureSession{
    NSNotificationCenter *notificationCenter= [NSNotificationCenter defaultCenter];
    //会话出错
    [notificationCenter addObserver:self selector:@selector(sessionRuntimeError:) name:AVCaptureSessionRuntimeErrorNotification object:captureSession];
}



/**
 *  设备连接成功
 *
 *  @param notification 通知对象
 */
-(void)deviceConnected:(NSNotification *)notification{
    NSLog(@"设备已连接...");
}
/**
 *  设备连接断开
 *
 *  @param notification 通知对象
 */
-(void)deviceDisconnected:(NSNotification *)notification{
    NSLog(@"设备已断开.");
}
/**
 *  捕获区域改变
 *
 *  @param notification 通知对象
 */
-(void)areaChange:(NSNotification *)notification{
    NSLog(@"捕获区域改变...");
}

/**
 *  会话出错
 *
 *  @param notification 通知对象
 */
-(void)sessionRuntimeError:(NSNotification *)notification{
    NSLog(@"会话发生错误.");
}

#pragma mark - 私有方法

/**
 *  取得指定位置的摄像头
 *
 *  @param position 摄像头位置
 *
 *  @return 摄像头设备
 */
-(AVCaptureDevice *)getCameraDeviceWithPosition:(AVCaptureDevicePosition )position{
    NSArray *cameras= [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *camera in cameras) {
        if ([camera position]==position) {
            return camera;
        }
    }
    return nil;
}

/**
 *  改变设备属性的统一操作方法
 *
 *  @param propertyChange 属性改变操作
 */
-(void)changeDeviceProperty:(PropertyChangeBlock)propertyChange{
    AVCaptureDevice *captureDevice= [self.captureDeviceInput device];
    NSError *error;
    //注意改变设备属性前一定要首先调用lockForConfiguration:调用完之后使用unlockForConfiguration方法解锁
    if ([captureDevice lockForConfiguration:&error]) {
        propertyChange(captureDevice);
        [captureDevice unlockForConfiguration];
    }else{
        NSLog(@"设置设备属性过程发生错误，错误信息：%@",error.localizedDescription);
    }
}

/**
 *  设置闪光灯模式
 *
 *  @param flashMode 闪光灯模式
 */
-(void)setFlashMode:(AVCaptureFlashMode )flashMode{
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        if ([captureDevice isFlashModeSupported:flashMode]) {
            [captureDevice setFlashMode:flashMode];
        }
    }];
}
/**
 *  设置聚焦模式
 *
 *  @param focusMode 聚焦模式
 */
-(void)setFocusMode:(AVCaptureFocusMode )focusMode{
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        if ([captureDevice isFocusModeSupported:focusMode]) {
            [captureDevice setFocusMode:focusMode];
        }
    }];
}
/**
 *  设置曝光模式
 *
 *  @param exposureMode 曝光模式
 */
-(void)setExposureMode:(AVCaptureExposureMode)exposureMode{
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        if ([captureDevice isExposureModeSupported:exposureMode]) {
            [captureDevice setExposureMode:exposureMode];
        }
    }];
}
/**
 *  设置聚焦点
 *
 *  @param point 聚焦点
 */
-(void)focusWithMode:(AVCaptureFocusMode)focusMode exposureMode:(AVCaptureExposureMode)exposureMode atPoint:(CGPoint)point{
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        if ([captureDevice isFocusModeSupported:focusMode]) {
            [captureDevice setFocusMode:AVCaptureFocusModeAutoFocus];
        }
        if ([captureDevice isFocusPointOfInterestSupported]) {
            [captureDevice setFocusPointOfInterest:point];
        }
        if ([captureDevice isExposureModeSupported:exposureMode]) {
            [captureDevice setExposureMode:AVCaptureExposureModeAutoExpose];
        }
        if ([captureDevice isExposurePointOfInterestSupported]) {
            [captureDevice setExposurePointOfInterest:point];
        }
    }];
}

/**
 *  添加点按手势，点按时聚焦
 */
-(void)addGenstureRecognizer{
    UITapGestureRecognizer *tapGesture=[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(tapScreen:)];
    [self.viewContainer addGestureRecognizer:tapGesture];
}
-(void)tapScreen:(UITapGestureRecognizer *)tapGesture{
    CGPoint point= [tapGesture locationInView:self.viewContainer];
    //将UI坐标转化为摄像头坐标
    CGPoint cameraPoint= [self.captureVideoPreviewLayer captureDevicePointOfInterestForPoint:point];
    [self setFocusCursorWithPoint:point];
    [self focusWithMode:AVCaptureFocusModeAutoFocus exposureMode:AVCaptureExposureModeAutoExpose atPoint:cameraPoint];
}

/**
 *  设置聚焦光标位置
 *
 *  @param point 光标位置
 */
-(void)setFocusCursorWithPoint:(CGPoint)point{
    self.focusCursor.center=point;
    self.focusCursor.transform=CGAffineTransformMakeScale(1.5, 1.5);
    self.focusCursor.alpha=1.0;
    [UIView animateWithDuration:1.0 animations:^{
        self.focusCursor.transform=CGAffineTransformIdentity;
    } completion:^(BOOL finished) {
        self.focusCursor.alpha=0;
        
    }];
}






-(void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    
    
    if (connection == self.videoConnect) {
        
        [_encoder encodeSampleBuffer:sampleBuffer];
        frameCount++;
        NSLog(@"video");
    }else if(connection == self.audioConnect){
        NSLog(@"audio");
        //        [_RWAudioEncoder encodeAAC:sampleBuffer];
//        [_audioEncoder encodeWithBuffer:sampleBuffer];
        //        [self playSampleBuffer:sampleBuffer];
        
        if (_audioOutputQueue == nil) {
            CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
            const AudioStreamBasicDescription* base = CMAudioFormatDescriptionGetStreamBasicDescription(format);
            AudioFormatID formtID = base->mFormatID;
            char* codeChar = (char*)&(formtID);
            NSLog(@"GJAudioQueueRecoder format：%c%c%c%c ",codeChar[3],codeChar[2],codeChar[1],codeChar[0]);
            
            _audioOutputQueue = [[GJAudioQueuePlayer alloc]initWithFormat:*base bufferSize:4000 macgicCookie:nil];
        }
        AudioBufferList bufferOut;
        CMBlockBufferRef bufferRetain;
        size_t size;

        AudioStreamPacketDescription packet;
        memset(&packet, 0, sizeof(AudioStreamPacketDescription));
       OSStatus status = CMSampleBufferGetAudioStreamPacketDescriptions(sampleBuffer, sizeof(AudioStreamPacketDescription), &packet, &size);
        assert(!status);
        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sampleBuffer, &size, &bufferOut, sizeof(AudioBufferList), NULL, NULL, 0, &bufferRetain);
        assert(!status);
        [_audioOutputQueue playData:bufferOut.mBuffers[0].mData lenth:bufferOut.mBuffers[0].mDataByteSize packetCount:0 packetDescriptions:NULL isEof:NO];
        CFRelease(bufferRetain);
    }
    
}


#pragma --mark   硬编码成h624
//编码完成代理
-(void)encodeCompleteBuffer:(uint8_t *)buffer withLenth:(long)totalLenth{
    totalSize+= totalLenth;
//    NSLog(@"totalLenth:%ld",totalLenth);
    [_decoder decodeBuffer:buffer withLenth:(uint32_t)totalLenth];

}
//解码完成代理
-(void)decodeCompleteImageData:(CVImageBufferRef)imageBuffer{
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    void* baseAdd = CVPixelBufferGetBaseAddress(imageBuffer);
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    size_t w = CVPixelBufferGetWidth(imageBuffer);
    size_t h = CVPixelBufferGetHeight(imageBuffer);
    [_playView displayYUV420pData:baseAdd width:(uint32_t)w height:(uint32_t)h];
//    [openGLLayer displayPixelBuffer:imageBuffer];
}
-(void)AACEncoderFromPCM:(AACEncoderFromPCM *)encoder encodeCompleteBuffer:(uint8_t *)buffer Lenth:(long)totalLenth packetCount:(int)count packets:(AudioStreamPacketDescription *)packets{
//    NSData* data = [NSData dataWithBytes:buffer length:totalLenth];
//        [_RWAudioDecoder canDecodeData:data];
//    NSLog(@"lenth:%ld",totalLenth);
//    
//    if (_audioOutputQueue == nil) {
//        _audioOutputQueue = [[GJAudioQueuePlayer alloc]initWithFormat:encoder.destFormatDescription  bufferSize:encoder.destMaxOutSize macgicCookie:nil];
//    }
//    
//    
//    [_audioOutputQueue playData:buffer lenth:(int)totalLenth packetCount:count packetDescriptions:packets isEof:NO];
//
//    return;
    if (_audioDecoder == nil) {
        AudioStreamBasicDescription temDesc = _audioEncoder.destFormatDescription;
       _audioDecoder = [[PCMDecodeFromAAC alloc]initWithDestDescription:NULL SourceDescription:&(temDesc) sourceMaxBufferLenth:_audioEncoder.destMaxOutSize];

        _audioDecoder.delegate = self;
    }
    
    [_audioDecoder decodeBuffer:buffer + packets->mStartOffset withLenth:(uint32_t)(totalLenth - packets->mStartOffset)];
    
//    if (!_streamQueue) {
//        _streamQueue = [[MCAudioOutputQueue alloc]initWithFormat:_audioEncoder.destFormatDescription bufferSize:60000 macgicCookie:nil];
//        _playQueue = dispatch_queue_create("playQueue", DISPATCH_QUEUE_CONCURRENT);
//    }
//    
//    
//    NSData* ocdata = [NSData dataWithBytes:buffer length:totalLenth];
//    
////    dispatch_async(_playQueue, ^{
////        char *formatName = (char *)&(recoder.pAqData->mDataFormat.mFormatID);
////        NSLog(@"format is: %c%c%c%c   lenth:%d  -----------", formatName[3], formatName[2], formatName[1], formatName[0],lenth);
////        
////        NSLog(@"data:%@",ocdata);
//        
//    
//        [_streamQueue playData:ocdata packetCount:count packetDescriptions:packets isEof:NO];
////    });

//    [_audioDecoder decodeBuffer:buffer withLenth:(uint32_t)totalLenth];
}

-(void)pcmDecode:(PCMDecodeFromAAC*)decode completeBuffer:(void *)buffer lenth:(int)lenth{
    if (_audioOutputQueue == nil) {
              _audioOutputQueue = [[GJAudioQueuePlayer alloc]initWithFormat:decode.destFormatDescription bufferSize:decode.destMaxOutSize macgicCookie:nil];
    }
    
 
    [_audioOutputQueue playData:buffer lenth:lenth packetCount:0 packetDescriptions:nil isEof:NO];
}


-(void)playSampleBuffer:(CMSampleBufferRef)sampleBuffer{
    
        if (_audioOutputQueue == nil) {
            CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
            const AudioStreamBasicDescription* baseDesc = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription);
            size_t cookieSize = 0;
            const void* cookie = CMAudioFormatDescriptionGetMagicCookie(formatDescription, &cookieSize);
            NSData* cookieData = [NSData dataWithBytes:cookie length:cookieSize];
            _audioOutputQueue = [[GJAudioQueuePlayer alloc]initWithFormat:*baseDesc bufferSize:2000 macgicCookie:cookieData];
        }

        size_t  bufferListSize;
        AudioBufferList bufferList ;
        CMBlockBufferRef blockBuffer;
        OSStatus status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sampleBuffer, &bufferListSize, &bufferList, sizeof(AudioBufferList), NULL, NULL, 0, &blockBuffer);

        if (status != noErr) {
            NSLog(@"status:%d",status);
            return ;
        }

        NSMutableData* data = [NSMutableData data];
        AudioStreamPacketDescription* packetDesc = malloc(sizeof(AudioStreamPacketDescription)*bufferList.mNumberBuffers);
        for (int i = 0; i < bufferList.mNumberBuffers; i++) {
            [data appendBytes:bufferList.mBuffers[i].mData length:bufferList.mBuffers[i].mDataByteSize];
            packetDesc[i].mDataByteSize =bufferList.mBuffers[i].mDataByteSize;
            packetDesc[i].mStartOffset = _audioOffset;
            _audioOffset += packetDesc[i].mDataByteSize;
        }

    [_audioOutputQueue playData:[data bytes] lenth:[data length] packetCount:bufferList.mNumberBuffers packetDescriptions:packetDesc isEof:NO];
        CFRelease(blockBuffer);
        free(packetDesc);
}

-(void)aacCallBack:(char *)aacData length:(int)datalength pts:(CMTime)pts{
//    NSData* date = [NSData dataWithBytes:aacData length:datalength];
//    [_audioDecoder parseData:date error:nil];
//    [_RWAudioDecoder canDecodeData:date];
    
}
-(void)GJAudioQueueRecoder:(GJAudioQueueRecoder *)recoder streamData:(void *)data lenth:(int)lenth packetCount:(int)packetCount packetDescriptions:(const AudioStreamPacketDescription *)packetDescriptions{
    
    if (_audioOutputQueue == nil) {
        AudioFormatID formtID = _recoder.destFormatDescription.mFormatID;
        char* codeChar = (char*)&(formtID);
        NSLog(@"GJAudioQueueRecoder format：%c%c%c%c ",codeChar[3],codeChar[2],codeChar[1],codeChar[0]);

        _audioOutputQueue = [[GJAudioQueuePlayer alloc]initWithFormat:(_recoder.destFormatDescription) bufferSize:_recoder.pAqData->bufferByteSize macgicCookie:nil];
    }
    [_audioOutputQueue playData:data lenth:lenth packetCount:packetCount packetDescriptions:packetDescriptions isEof:NO];
    
    return;
    if (_audioDecoder == nil) {
        AudioStreamBasicDescription temDesc = recoder.destFormatDescription;
        _audioDecoder = [[PCMDecodeFromAAC alloc]initWithDestDescription:NULL SourceDescription:&(temDesc) sourceMaxBufferLenth:recoder.destMaxOutSize];
        
        _audioDecoder.delegate = self;
    }
    
    int total = 0;
    for (int i=0; i<packetCount; i++) {
        [_audioDecoder decodeBuffer:data + packetDescriptions[i].mStartOffset withLenth:(uint32_t)packetDescriptions[i].mDataByteSize];
        total += packetDescriptions[i].mDataByteSize;
    }
    
    
    
}

-(void)pcmDataToPlay:(char *)buf size:(int)size{
    if (_audioOutputQueue == nil) {
        _audioOutputQueue = [[GJAudioQueuePlayer alloc]initWithFormat:_RWAudioDecoder.mTargetAudioStreamDescripion bufferSize:3000 macgicCookie:[_RWAudioDecoder fetchMagicCookie]];
    }
    NSData* data = [NSData dataWithBytes:buf length:size];
    [_audioOutputQueue playData:buf lenth:size packetCount:1 packetDescriptions:_RWAudioDecoder.packetFormat isEof:NO];
//    for (MCParsedAudioData* data in audioData) {
//        AudioStreamPacketDescription desc = data.packetDescription;
//        [_audioOutputQueue playData:data.data packetCount:1 packetDescriptions:&desc isEof:NO];
//    }
}


@end
