//
//  SY_LiveShowVC.m
//  faceToFace
//
//  Created by yxy on 17/6/29.
//  Copyright © 2017年 霜月. All rights reserved.
//

#import "SY_LiveShowVC.h"
#import <AVFoundation/AVFoundation.h>
#import <GPUImage.h>
#import "SY_H264Encoder.h"
#import "SY_AACEncoder.h"
#import "SY_RTMP_Socket.h"
#import "SY_LiveStreamInfo.h"

#define NOW (CACurrentMediaTime()*1000)
#define SY_WIDTH [UIScreen mainScreen].bounds.size.width
#define SY_HEIGHT [UIScreen mainScreen].bounds.size.height
@interface SY_LiveShowVC ()<AVCaptureAudioDataOutputSampleBufferDelegate,AVCaptureVideoDataOutputSampleBufferDelegate,SY_RtmpSocketDelegate, SY_H264EncoderDelegate, SY_AACEncoderDelegate>{
    dispatch_queue_t _videoProcessingQueue;
    dispatch_queue_t _audioProcessingQueue;
    dispatch_queue_t _sy_encodeQueue_video;//视频编码线程
    dispatch_queue_t _sy_encodeQueue_audio;//音频编码线程
    VTCompressionSessionRef _encodeSesion;//视频压缩
    long                    _frameCount;
    FILE    *               _h264File;
    int                     _spsppsFound;
    FILE    *               _aacFile;
    dispatch_semaphore_t    _lock;
}
@property (nonatomic, strong) UIView *liveView;

@property (nonatomic, strong) UIView *headView;

@property (nonatomic, strong) UIButton *liveBtn;

@property (nonatomic, strong) AVCaptureSession *session;    // 音视频录制期间管理者

@property (nonatomic, strong) AVCaptureDevice *videoDevice; // 视频管理者, (用来操作所闪光灯, 聚焦, 摄像头切换)

@property (nonatomic, strong) AVCaptureDevice *audioDevice; // 音频管理者

@property (nonatomic, strong) AVCaptureDeviceInput *videoInput;   // 视频输入数据的管理对象
@property (nonatomic, strong) AVCaptureDeviceInput *audioInput;   // 音频输入数据的管理对象
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoOutput; // 视频输出数据的管理者
@property (nonatomic, strong) AVCaptureAudioDataOutput *audioOutput; // 音频输出数据的管理者

@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer; // 用来展示视频的图像

@property (nonatomic, strong) NSString *documentDictionary;

@property (nonatomic , strong) SY_AACEncoder    *audioEncoder;//音频编码管理类

@property (nonatomic, strong) SY_H264Encoder *videoEncoder;//视频编码管理类

@property (nonatomic, strong) SY_RTMP_Socket *socket; // Rtmp 推流管理类

@property (nonatomic, assign) uint64_t timestamp;

@property (nonatomic, assign) BOOL isFirstFrame;

@property (nonatomic, assign) uint64_t currentTimestamp;

@property (nonatomic, assign) BOOL uploading;

@end

@implementation SY_LiveShowVC

- (void)viewDidLoad {
    [super viewDidLoad];
    _videoProcessingQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    _audioProcessingQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
    _sy_encodeQueue_video = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    _sy_encodeQueue_audio = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    [self initLiveView];
    [self checkDeviceCamera];
    [self initLiveBtn];
    self.documentDictionary = [(NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask, YES)) objectAtIndex:0];
    
    self.audioEncoder = [[SY_AACEncoder alloc] init];
    self.audioEncoder.delegate = self;
    self.videoEncoder = [[SY_H264Encoder alloc] init];
    self.videoEncoder.delegate = self;
    
    _lock = dispatch_semaphore_create(1);
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)initLiveView{
    self.liveView = [[UIView alloc]initWithFrame:CGRectMake(0, 0, SY_WIDTH, SY_HEIGHT)];
    [self.view addSubview:self.liveView];
}

-(void)initLiveBtn{
    self.liveBtn=[[UIButton alloc]initWithFrame:CGRectMake(SY_WIDTH/2-50, SY_HEIGHT-80, 70, 70)];
    [self.liveBtn setImage:[UIImage imageNamed:@"videoRecord"] forState:UIControlStateNormal];
    [self.liveBtn addTarget:self action:@selector(startLiveAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.liveView addSubview:self.liveBtn];
}

-(void)startLiveAction:(UIButton*)sender{
    _h264File = fopen([[NSString stringWithFormat:@"%@/jf_encodeVideo.h264", self.documentDictionary] UTF8String], "wb");
    _aacFile = fopen([[NSString stringWithFormat:@"%@/jf_encodeAudio.aac", self.documentDictionary] UTF8String], "wb");
    
    // 初始化 直播流信息
    SY_LiveStreamInfo *streamInfo = [[SY_LiveStreamInfo alloc] init];
    streamInfo.url = @"rtmp://192.168.0.5:1935/rtmplive/room";
    
    self.socket = [[SY_RTMP_Socket alloc] initWithStream:streamInfo];
    self.socket.delegate = self;
    [self.socket start];
    
    // 开始直播
    [self.session startRunning];
    sender.hidden = YES;
}

#pragma mark ---- 检测摄像头授权
-(void)checkDeviceCamera{
    switch ([AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo]) {
        case AVAuthorizationStatusAuthorized://已授权
            NSLog(@"已授权");
            [self checkDeviceMic];
            break;
        case AVAuthorizationStatusNotDetermined://用户尚未允许或拒绝
        {
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
                if (granted) {
                    NSLog(@"已授权");
                    [self checkDeviceMic];
                }else{
                    NSLog(@"用户拒绝授权摄像头的使用, 返回上一页, 请打开--> 设置 -- > 隐私 --> 通用等权限设置");
                }
            }];
            
        }
            break;
        default:
            NSLog(@"用户尚未授权摄像头的使用权");
            break;
    }
}

#pragma mark ---- 检测麦克授权
-(void)checkDeviceMic{
    switch ([AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio]) {
        case AVAuthorizationStatusAuthorized://已授权
            NSLog(@"已授权");
            [self initAVCaptureSession];
            break;
        case AVAuthorizationStatusNotDetermined://用户尚未允许或拒绝
        {
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:^(BOOL granted) {
                if (granted) {
                    NSLog(@"已授权");
                    [self initAVCaptureSession];
                }else{
                    NSLog(@"用户拒绝授权麦克的使用, 返回上一页, 请打开--> 设置 -- > 隐私 --> 通用等权限设置");
                }
            }];
            
        }
            break;
        default:
            NSLog(@"用户尚未授权摄像头的使用权");
            break;
    }
}

#pragma mark ---- 初始化管理者-Session
-(void)initAVCaptureSession{
    self.session = [[AVCaptureSession alloc]init];
    // 设置录像的分辨率
    // 先判断是被是否支持要设置的分辨率
    if ([self.session canSetSessionPreset:AVCaptureSessionPreset1280x720]) {
        // 如果支持则设置
        [self.session canSetSessionPreset:AVCaptureSessionPreset1280x720];
    } else if ([self.session canSetSessionPreset:AVCaptureSessionPresetiFrame960x540]) {
        [self.session canSetSessionPreset:AVCaptureSessionPresetiFrame960x540];
    } else if ([self.session canSetSessionPreset:AVCaptureSessionPreset640x480]) {
        [self.session canSetSessionPreset:AVCaptureSessionPreset640x480];
    }
    // 开始配置
    [self.session beginConfiguration];
    // 初始化视频管理
    self.videoDevice = nil;
    // 创建摄像头类型
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionFront];
    self.videoDevice = device;
    // 视频
    [self videoInputAndOutput];
    
    // 音频
    [self audioInputAndOutput];
    
    // 录制的同时播放
    [self initPreviewLayer];
    
    // 提交配置
    [self.session commitConfiguration];
}

#pragma mark ---- 视频输入输出
-(void)videoInputAndOutput{
    NSError *error;
    // 视频输入
    // 初始化 根据输入设备来初始化输出对象
    self.videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:self.videoDevice error:&error];
    if (error) {
        NSLog(@"-- 摄像头出错 -- %@", error);
        return;
    }
    // 将输入对象添加到管理者 -- AVCaptureSession 中
    // 先判断是否能搞添加输入对象
    if ([self.session canAddInput:self.videoInput]) {
        // 管理者能够添加 才可以添加
        [self.session addInput:self.videoInput];
    }
    
    // 视频输出
    // 初始化 输出对象
    self.videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    // 是否允许卡顿时丢帧
    self.videoOutput.alwaysDiscardsLateVideoFrames = NO;
    if ([self supportsFastTextureUpload])
    {
        // 是否支持全频色彩编码 YUV 一种色彩编码方式, 即YCbCr, 现在视频一般采用该颜色空间, 可以分离亮度跟色彩, 在不影响清晰度的情况下来压缩视频
        BOOL supportsFullYUVRange = NO;
        
        // 获取输出对象 支持的像素格式
        NSArray *supportedPixelFormats = self.videoOutput.availableVideoCVPixelFormatTypes;
        
        for (NSNumber *currentPixelFormat in supportedPixelFormats)
        {
            if ([currentPixelFormat intValue] == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
            {
                supportsFullYUVRange = YES;
            }
        }
        
        // 根据是否支持 来设置输出对象的视频像素压缩格式,
        if (supportsFullYUVRange)
        {
            [self.videoOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
        }
        else
        {
            [self.videoOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
        }
    }
    else
    {
        [self.videoOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
    }
    
    // 设置代理
    [self.videoOutput setSampleBufferDelegate:self queue:_videoProcessingQueue];
    // 判断管理是否可以添加 输出对象
    if ([self.session canAddOutput:self.videoOutput]) {
        [self.session addOutput:self.videoOutput];
        AVCaptureConnection *connection = [self.videoOutput connectionWithMediaType:AVMediaTypeVideo];
        // 设置视频的方向
        connection.videoOrientation = AVCaptureVideoOrientationPortrait;
        // 视频稳定设置
        if ([connection isVideoStabilizationSupported]) {
            connection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeAuto;
        }
        connection.videoScaleAndCropFactor = connection.videoMaxScaleAndCropFactor;
    }
}

#pragma mark ---- 音频输入输出
-(void)audioInputAndOutput{
    NSError *error;
    // 音频输入设备
    self.audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    
    // 音频输入对象
    self.audioInput = [[AVCaptureDeviceInput alloc] initWithDevice:self.audioDevice error:&error];
    if (error) {
        NSLog(@"-- 录音设备出错 -- %@", error);
    }
    
    // 将输入对象添加到 管理者中
    if ([self.session canAddInput:self.audioInput]) {
        [self.session addInput:self.audioInput];
    }
    
    // 音频输出对象
    self.audioOutput = [[AVCaptureAudioDataOutput alloc] init];
    // 将输出对象添加到管理者中
    if ([self.session canAddOutput:self.audioOutput]) {
        [self.session addOutput:self.audioOutput];
    }
    
    // 设置代理
    [self.audioOutput setSampleBufferDelegate:self queue:_audioProcessingQueue];
}

#pragma mark ---- 显示层
-(void)initPreviewLayer{
    [self.view layoutIfNeeded];
    // 初始化对象
    self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
    self.previewLayer.frame = self.view.layer.bounds;
    self.previewLayer.connection.videoOrientation = [self.videoOutput connectionWithMediaType:AVMediaTypeVideo].videoOrientation;
    
    self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    self.previewLayer.position = CGPointMake(self.liveView.frame.size.width*0.5,self.liveView.frame.size.height*0.5);
    
    CALayer *layer = self.liveView.layer;
    layer.masksToBounds = true;
    [layer addSublayer:self.previewLayer];
}

#pragma mark --  AVCaptureAudioDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if (captureOutput == self.audioOutput) {
        [self.audioEncoder encodeSampleBuffer:sampleBuffer timeStamp:self.currentTimestamp completionBlock:^(NSData *encodedData, NSError *error) {
            fwrite(encodedData.bytes, 1, encodedData.length, _aacFile);
        }];
    } else {
        [self.videoEncoder encodeWithSampleBuffer:sampleBuffer timeStamp:self.currentTimestamp completionBlock:^(NSData *data, NSInteger length) {
            fwrite(data.bytes, 1, length, _h264File);
        }];
    }
}


- (void)dealloc {
    if ([self.session isRunning]) {
        [self.session stopRunning];
    }
    [self.videoOutput setSampleBufferDelegate:nil queue:dispatch_get_main_queue()];
    [self.audioOutput setSampleBufferDelegate:nil queue:dispatch_get_main_queue()];
}


// 是否支持快速纹理更新
- (BOOL)supportsFastTextureUpload;
{
#if TARGET_IPHONE_SIMULATOR
    return NO;
#else
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-pointer-compare"
    return (CVOpenGLESTextureCacheCreate != NULL);
#pragma clang diagnostic pop
    
#endif
}


// 保存h264数据到文件
- (void) writeH264Data:(void*)data length:(size_t)length addStartCode:(BOOL)b
{
    // 添加4字节的 h264 协议 start code
    const Byte bytes[] = "\x00\x00\x00\x01";
    
    if (_h264File) {
        if(b)
            fwrite(bytes, 1, 4, _h264File);
        
        fwrite(data, 1, length, _h264File);
    } else {
        NSLog(@"_h264File null error, check if it open successed");
    }
}


#pragma mark - JFRtmpSocketDelegate
- (void)sy_videoEncoder_call_back_videoFrame:(SY_VideoFrame *)frame {
    if (self.uploading) {
        [self.socket sendFrame:frame];
    }
}

#pragma mark - AACEncoderDelegate
- (void)sy_AACEncoder_call_back_audioFrame:(SY_AudioFrame *)audionFrame {
    
    if (self.uploading) {
        [self.socket sendFrame:audionFrame];
    }
}

#pragma mark -- JFRtmpSocketDelegate
- (void)socketStatus:(nullable SY_RTMP_Socket *)socket status:(SY_LiveState)status {
    switch (status) {
        case SY_LiveReady:
            NSLog(@"准备");
            break;
        case SY_LivePending:
            NSLog(@"链接中");
            break;
        case SY_LiveStart:
            NSLog(@"已连接");
            if (!self.uploading) {
                self.timestamp = 0;
                self.isFirstFrame = YES;
                self.uploading = YES;
            }
            break;
        case SY_LiveStop:
            NSLog(@"已断开");
            break;
        case SY_LiveError:
            NSLog(@"链接出错");
            self.uploading = NO;
            self.isFirstFrame = NO;
            self.uploading = NO;
            break;
        default:
            break;
    }
}

- (uint64_t)currentTimestamp{
    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
    uint64_t currentts = 0;
    if(_isFirstFrame == true) {
        _timestamp = NOW;
        _isFirstFrame = false;
        currentts = 0;
    }
    else {
        currentts = NOW - _timestamp;
    }
    dispatch_semaphore_signal(_lock);
    return currentts;
}






/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
