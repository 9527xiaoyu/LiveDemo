//
//  ViewController.m
//  faceToFace
//
//  Created by yxy on 17/6/27.
//  Copyright © 2017年 霜月. All rights reserved.
//

#import "ViewController.h"
#import "SY_LiveShowVC.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
- (IBAction)zhibo:(UIButton *)sender {
    SY_LiveShowVC *vc=[[SY_LiveShowVC alloc]init];
    [self presentViewController:vc animated:YES completion:nil];
}


@end
