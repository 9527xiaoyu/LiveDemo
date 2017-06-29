//
//  VideoFrame.h
//  faceToFace
//
//  Created by yxy on 17/6/29.
//  Copyright © 2017年 霜月. All rights reserved.
//

#import<Foundation/Foundation.h>
#import "SY_Frame.h"

@interface SY_VideoFrame : SY_Frame

@property (nonatomic, assign) BOOL isKeyFrame;
@property (nonatomic, strong) NSData *sps;
@property (nonatomic, strong) NSData *pps;

@end
