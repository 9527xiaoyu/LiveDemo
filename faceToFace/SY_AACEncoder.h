//
//  SY_AACEncoder.h
//  faceToFace
//
//  Created by yxy on 17/6/29.
//  Copyright © 2017年 霜月. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "SY_AudioFrame.h"

typedef void(^AACDataBlock)(NSData *encodedData, NSError* error);

@protocol SY_AACEncoderDelegate<NSObject>

- (void)sy_AACEncoder_call_back_audioFrame:(SY_AudioFrame *)audionFrame;

@end

@interface SY_AACEncoder : NSObject

@property (nonatomic) dispatch_queue_t encoderQueue;
@property (nonatomic) dispatch_queue_t callbackQueue;

@property (nonatomic, assign) id<SY_AACEncoderDelegate> delegate;

- (void) encodeSampleBuffer:(CMSampleBufferRef)sampleBuffer timeStamp:(uint64_t)timeStamp completionBlock:(AACDataBlock)completionBlock;

@end
