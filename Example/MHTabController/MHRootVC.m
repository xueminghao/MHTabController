//
//  MHViewController.m
//  MHTabController
//
//  Created by 薛明浩 on 01/18/2019.
//  Copyright (c) 2019 薛明浩. All rights reserved.
//

#import "MHRootVC.h"
#import "MHContentVC.h"
#import "MHTabController.h"

@interface MHRootVC ()<MHTabControllerDataSource>

@property (nonatomic, strong) NSArray *vcs;
@property (nonatomic, strong) NSArray *colors;
@property (nonatomic, weak) MHTabController *tabVC;

@end

@implementation MHRootVC

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupData];
    if ([self.childViewControllers.firstObject isKindOfClass:[MHTabController class]]) {
        self.tabVC = self.childViewControllers.firstObject;
        self.tabVC.dataSource = self;
        [self.tabVC reload];
    }
}

#pragma mark - Private methods

- (void)setupData {
    self.colors = @[
                    [UIColor orangeColor],
                    [UIColor blueColor],
                    [UIColor purpleColor]
                    ];
    
    NSMutableArray *temp = [NSMutableArray new];
    for (NSInteger index = 0; index < self.colors.count; index++) {
        MHContentVC *vc = [[MHContentVC alloc] init];
        vc.view.backgroundColor = self.colors[index];
        [temp addObject:vc];
    }
    self.vcs = [temp copy];
}

#pragma mark - MHTabControllerDataSource

- (NSUInteger)numberOfTabItems {
    return self.vcs.count;
}

- (NSString *)titleForItemAtIndex:(NSUInteger)index {
    return [NSString stringWithFormat:@"title%ld", index];
}

-(UIViewController *)presentViewControlerForItemAtIndex:(NSUInteger)index {
    return self.vcs[index];
}

@end
