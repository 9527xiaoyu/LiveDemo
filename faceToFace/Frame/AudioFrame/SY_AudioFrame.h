//
//  AudioFrame.h
//  faceToFace
//
//  Created by yxy on 17/6/29.
//  Copyright © 2017年 霜月. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SY_Frame.h"

@interface SY_AudioFrame : SY_Frame

// flv打包中aac的header
@property (nonatomic, strong) NSData *audioInfo;

@end
