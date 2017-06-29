//
//  NSMutableArray+SY_Add.m
//  faceToFace
//
//  Created by yxy on 17/6/29.
//  Copyright © 2017年 霜月. All rights reserved.
//

#import "NSMutableArray+SY_Add.h"

@implementation NSMutableArray (SY_Add)

-(id)SY_PopFirstObject{
    id obj = nil;
    if (self.count) {
        obj = self.firstObject;
        [self SY_RemoveFirstObject];
    }
    return obj;
}

- (void)SY_RemoveFirstObject {
    if (self.count) {
        [self removeObjectAtIndex:0];
    }
}

@end
