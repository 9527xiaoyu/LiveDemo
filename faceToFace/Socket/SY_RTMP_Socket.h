//
//  SY_RTMP_Socket.h
//  faceToFace
//
//  Created by yxy on 17/6/29.
//  Copyright © 2017年 霜月. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SY_LiveStreamInfo.h"
#import "SY_Frame.h"

@class SY_RTMP_Socket;

@protocol SY_RtmpSocketDelegate <NSObject>

/** callback socket current status (回调当前网络情况) */
- (void)socketStatus:(nullable SY_RTMP_Socket *)socket status:(SY_LiveState)status;

@end

@interface SY_RTMP_Socket : NSObject

@property (nonatomic, assign)_Nullable id<SY_RtmpSocketDelegate> delegate;

// 初始化
- (nullable instancetype)initWithStream:(nullable SY_LiveStreamInfo *)stream;

- (void) start;
- (void) stop;
- (void) sendFrame:(nullable SY_Frame*)frame;

@end
