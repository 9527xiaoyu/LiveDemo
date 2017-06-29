//
//  SY_LiveStreamInfo.h
//  faceToFace
//
//  Created by yxy on 17/6/29.
//  Copyright © 2017年 霜月. All rights reserved.
//

#import <Foundation/Foundation.h>

/// 流状态
typedef NS_ENUM(NSUInteger, SY_LiveState){
    /// 准备
    SY_LiveReady = 0,
    /// 连接中
    SY_LivePending = 1,
    /// 已连接
    SY_LiveStart = 2,
    /// 已断开
    SY_LiveStop = 3,
    /// 连接出错
    SY_LiveError = 4
};

typedef NS_ENUM(NSUInteger,SY_LiveSocketErrorCode) {
    SY_LiveSocketError_PreView               = 201,///< 预览失败
    SY_LiveSocketError_GetStreamInfo         = 202,///< 获取流媒体信息失败
    SY_LiveSocketError_ConnectSocket         = 203,///< 连接socket失败
    SY_LiveSocketError_Verification          = 204,///< 验证服务器失败
    SY_LiveSocketError_ReConnectTimeOut      = 205///< 重新连接服务器超时
};


@interface SY_LiveStreamInfo : NSObject

/**
 流ID
 */
@property (nonatomic, copy) NSString *streamId;

/**
 token
 */
@property (nonatomic, copy) NSString *token;

/**
 上传地址 RTMP
 */
@property (nonatomic, copy) NSString *url;

/**
 上传 IP
 */
@property (nonatomic, copy) NSString *host;

/**
 上传端口
 */
@property (nonatomic, assign) NSInteger port;

@end
