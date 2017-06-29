//
//  SY_Frame.h
//  faceToFace
//
//  Created by yxy on 17/6/29.
//  Copyright © 2017年 霜月. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SY_Frame : NSObject
@property (nonatomic, assign) uint64_t timestamp;
@property (nonatomic, strong) NSData *data;
// flv或者rtmp包头
@property (nonatomic, strong) NSData *header;
@end
