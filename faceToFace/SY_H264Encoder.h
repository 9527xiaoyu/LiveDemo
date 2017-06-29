//
//  SY_H264Encoder.h
//  faceToFace
//
//  Created by yxy on 17/6/29.
//  Copyright © 2017年 霜月. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <VideoToolbox/VideoToolbox.h>
#import "SY_VideoFrame.h"

typedef void (^VideoEncoderCompletionBlock)(NSData *data, NSInteger length);

@protocol SY_H264EncoderDelegate <NSObject>

- (void)sy_videoEncoder_call_back_videoFrame:(SY_VideoFrame *)frame;

@end

@interface SY_H264Encoder : NSObject

@property (nonatomic, assign) id<SY_H264EncoderDelegate> delegate;

// 编码
- (void)encodeWithSampleBuffer:(CMSampleBufferRef )sampleBuffer timeStamp:(uint64_t)timeStamp completionBlock:(VideoEncoderCompletionBlock)completionBlock;

- (void)stopEncodeSession;

@end
