//
//  MHTabController.m
//  MHTabController
//
//  Created by Minghao Xue on 2019/1/18.
//

#import "MHTabController.h"
#import <Masonry/Masonry.h>

#define TabHeaderBtnScaleMax 1.1
#define TabHeaderBtnScaleMin 1.0
#define TabHeaderHeight 44
#define TabHeaderTitleWidthOffset 12

@implementation MHTabItemBadge

- (instancetype)init {
    if (self = [super init]) {
        self.type = MHTabItemBadgeTypeNone;
    }
    return self;
}

@end

@interface MHTabControllerRoundEdgeView : UIView

@end

@interface MHTabController ()<UIScrollViewDelegate>
/**
 分栏头。分栏控制器会在reload时，为每一个分栏创建一个分栏button，并且添加在分栏头上。注意：tabHeader的子视图除了每个分栏的UIButton外还有pageIndicatorView和tabHeaderBottomLine
 */
@property (nonatomic, strong) UIView *tabHeader;
/**
 分栏头底部分割线
 */
@property (nonatomic, strong) UIView *tabHeaderBottomLine;
/**
 分栏浏览视图
 */
@property (nonatomic, strong) UIScrollView *tabPages;
/**
 分栏指示器
 */
@property (nonatomic, strong) MHTabControllerRoundEdgeView *pageIndicatorView;

@property (nonatomic, strong) MASConstraint *pageIndicatorLeadingCons;
@property (nonatomic, strong) MASConstraint *pageIndicatorTrailingCons;
/**
 当前分栏索引
 */
@property (nonatomic, assign) NSUInteger currentTabIndex;

@property (nonatomic, strong) NSMutableArray<NSString *> *titles;
@property (nonatomic, strong) NSMutableArray<UIViewController *> *innerVCs;
@property (nonatomic, strong) NSMutableArray<UIView *> *subviewContainers;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *tabIndexedShowedStates;

@end

@implementation MHTabController

#pragma mark - Life cycles;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self buildSubViews];
    [self reload];
}

#pragma mar - Getters

- (UIViewController *)currentViewController {
    NSArray *vcs = self.childViewControllers;
    if (self.currentTabIndex >= vcs.count) {
        return nil;
    }
    return vcs[self.currentTabIndex];
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    CGFloat width = CGRectGetWidth(scrollView.bounds);
    CGFloat baseOffset = self.currentTabIndex * width;
    CGFloat offset = scrollView.contentOffset.x - baseOffset;
    float scrollProgress = offset / width;
    
    [self updateIndicatorViewWithProgress:scrollProgress];
    [self updateBtnWithProgress:scrollProgress];
    
    NSUInteger expectedTabIndex = self.currentTabIndex;
    if (offset > 0) {
        expectedTabIndex += 1;
    } else if (offset < 0) {
        expectedTabIndex -= 1;
    }
    [self loadTabItemVCForTabIndexIfNeeded: expectedTabIndex];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    //手势引起的动画结束
    if ([self.delegate respondsToSelector:@selector(tabController:didScrollOutIndex:)]) {
        [self.delegate tabController:self didScrollOutIndex:self.currentTabIndex];
    }
    
    NSUInteger tabIndex = scrollView.contentOffset.x / CGRectGetWidth(scrollView.bounds);
    self.currentTabIndex = tabIndex;
    [self resetBtnApperance];
    [self postDidScrollToDelegateMethod];
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
    //代码引起的动画结束
    [self resetBtnApperance];
}

#pragma mark - Private methods

- (void)buildSubViews {
    self.tabHeader = [UIView new];
    [self.view addSubview:self.tabHeader];
    self.tabHeader.backgroundColor = [UIColor whiteColor];
    [self.tabHeader mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.top.equalTo(self.view);
        make.height.equalTo(@TabHeaderHeight);
    }];
    UIView *tabHeaderBottomLine = [UIView new];
    self.tabHeaderBottomLine = tabHeaderBottomLine;
    self.tabHeaderBottomLine.backgroundColor = [UIColor lightGrayColor];
    [self.tabHeader addSubview:self.tabHeaderBottomLine];
    [self.tabHeaderBottomLine mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.bottom.equalTo(self.tabHeader);
        make.height.equalTo(@1);
    }];
    
    self.pageIndicatorView = [MHTabControllerRoundEdgeView new];
    self.pageIndicatorView.backgroundColor = [UIColor redColor];
    [self.tabHeader addSubview:self.pageIndicatorView];
    [self.pageIndicatorView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.bottom.equalTo(self.tabHeader).offset(-1);
        make.height.equalTo(@2);
    }];
    [self setIndicatorViewZeroLength];
    
    self.tabPages = [UIScrollView new];
    self.tabPages.pagingEnabled = YES;
    self.tabPages.showsHorizontalScrollIndicator = NO;
    self.tabPages.directionalLockEnabled = YES;
    UIGestureRecognizer *interactivePopGesture = self.navigationController.interactivePopGestureRecognizer;
    if (interactivePopGesture) {
        [self.tabPages.panGestureRecognizer requireGestureRecognizerToFail:interactivePopGesture];
    }
    self.tabPages.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    self.tabPages.bounces = NO;
    self.tabPages.delegate = self;
    [self.view addSubview:self.tabPages];
    [self.tabPages mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.bottom.equalTo(self.view);
        make.top.equalTo(self.tabHeader.mas_bottom);
    }];
    
    [self.view bringSubviewToFront:self.tabHeader];
}

- (void)reload {
    //remove child views
    for (UIView *subView in self.tabHeader.subviews) {
        if (subView == self.pageIndicatorView ||
            subView == self.tabHeaderBottomLine) {
            continue;
        }
        [subView removeFromSuperview];
    }
    [self.tabPages.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    //reset indicator view position
    [self setIndicatorViewZeroLength];
    //clear array
    if (self.titles) {
        [self.titles removeAllObjects];
    } else {
        self.titles = [NSMutableArray new];
    }
    if (self.innerVCs) {
        [self.innerVCs removeAllObjects];
    } else {
        self.innerVCs = [NSMutableArray new];
    }
    if (self.tabIndexedShowedStates) {
        [self.tabIndexedShowedStates removeAllObjects];
    } else {
        self.tabIndexedShowedStates = [NSMutableArray new];
    }
    if (self.subviewContainers) {
        [self.subviewContainers makeObjectsPerformSelector:@selector(removeFromSuperview)];
        [self.subviewContainers removeAllObjects];
    } else {
        self.subviewContainers = [NSMutableArray new];
    }
    //reload
    if (![self.dataSource respondsToSelector:@selector(numberOfTabItems)]) {
        return;
    }
    NSUInteger count = [self.dataSource numberOfTabItems];
    if (count <= 0) {
        return;
    } else if (count <= 1) { //只有一个分栏时，隐藏分栏头
        [self.tabHeader mas_updateConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(self.view).offset(-TabHeaderHeight);
        }];
        self.tabHeader.hidden = YES;
    } else {
        [self.tabHeader mas_updateConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(self.view);
        }];
        self.tabHeader.hidden = NO;
    }
    
    UIView * lastTabVCContainerView = nil;
    UIButton *lastBtn = nil;
    for (NSUInteger index = 0; index < count; index++) {
        // get tab title
        if (![self.dataSource respondsToSelector:@selector(titleForItemAtIndex:)]) {
            continue;
        }
        NSString *tabItemTitle = [self.dataSource titleForItemAtIndex:index];
        
        // get tab vc
        if (![self.dataSource respondsToSelector:@selector(presentViewControlerForItemAtIndex:)]) {
            continue;
        }
        UIViewController *tabItemVC = [self.dataSource presentViewControlerForItemAtIndex:index];
        
        // add to cache
        [self.titles addObject:tabItemTitle];
        [self.innerVCs addObject:tabItemVC];
        
        // add tab vc container view
        UIView *containerView = [UIView new];
        [self.tabPages addSubview:containerView];
        [containerView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.bottom.height.equalTo(self.tabPages);
            make.width.equalTo(self.tabPages);
        }];
        if (!lastTabVCContainerView) {
            [containerView mas_makeConstraints:^(MASConstraintMaker *make) {
                make.left.equalTo(self.tabPages);
            }];
        } else {
            [containerView mas_makeConstraints:^(MASConstraintMaker *make) {
                make.left.equalTo(lastTabVCContainerView.mas_right);
            }];
        }
        if (index == count - 1) {
            [containerView mas_makeConstraints:^(MASConstraintMaker *make) {
                make.right.equalTo(self.tabPages);
            }];
        }
        lastTabVCContainerView = containerView;
        [self.subviewContainers addObject:containerView];
        // set showed state
        [self.tabIndexedShowedStates addObject:@(NO)];
        // add header.等分逻辑
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        [btn setTitle:tabItemTitle forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont systemFontOfSize:14];
        btn.titleLabel.textAlignment = NSTextAlignmentCenter;
        btn.tag = index;
        
        if ([self.dataSource respondsToSelector:@selector(badgeModelForItemAtIndex:)]) {
            MHTabItemBadge *badge = [self.dataSource badgeModelForItemAtIndex:index];
            MHTabItemBadgeType type = badge.type;
            switch (type) {
                case MHTabItemBadgeTypeNone:
                case MHTabItemBadgeTypeText:
                {
                    UIView *view = [btn viewWithTag:100];
                    [view removeFromSuperview];
                    break;
                }
                case MHTabItemBadgeTypeDot:
                {
                    UIView *dotView = [UIView new];
                    dotView.tag = 100;
                    dotView.backgroundColor = [UIColor redColor];
                    dotView.layer.cornerRadius = 3;
                    [btn addSubview:dotView];
                    [dotView mas_makeConstraints:^(MASConstraintMaker *make) {
                        make.width.height.equalTo(@6);
                        make.centerY.equalTo(btn.titleLabel.mas_top);
                        make.centerX.equalTo(btn.titleLabel.mas_trailing);
                    }];
                }
            }
        }
        
        [self.tabHeader addSubview:btn];
        [btn mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(self.tabHeader);
            make.bottom.equalTo(self.tabHeaderBottomLine.mas_top);
        }];
        if (!lastBtn) {
            [btn mas_makeConstraints:^(MASConstraintMaker *make) {
                make.left.equalTo(self.tabHeader);
            }];
        } else {
            [btn mas_makeConstraints:^(MASConstraintMaker *make) {
                make.left.equalTo(lastBtn.mas_right);
                make.width.equalTo(lastBtn);
            }];
        }
        if (index == count - 1) {
            [btn mas_makeConstraints:^(MASConstraintMaker *make) {
                make.right.equalTo(self.tabHeader);
            }];
        }
        lastBtn = btn;
        [btn addTarget:self action:@selector(tabBtnClicked:) forControlEvents:UIControlEventTouchUpInside];
    }
    
    NSUInteger defaultIndex = 0;
    if ([self.dataSource respondsToSelector:@selector(defaultTabIndex)]) {
        defaultIndex = [self.dataSource defaultTabIndex];
    }
    self.currentTabIndex = defaultIndex;
    [self resetIndicatorViewPosition];
    [self scrollToTabIndex:self.currentTabIndex animated:NO];
}

/**
 懒加载子Vc的view
 */
- (void)loadTabItemVCForTabIndexIfNeeded:(NSUInteger)tabIndex {
    UIView *containerView = self.subviewContainers[tabIndex];
    if (containerView.subviews.count > 0) { //已经添加
        return;
    }
    
    UIViewController *vc = self.innerVCs[tabIndex];
    [vc willMoveToParentViewController:self];
    vc.view.frame = containerView.bounds;
    [vc.view layoutIfNeeded];
    [containerView addSubview:vc.view];
    [self addChildViewController:vc];
    [vc didMoveToParentViewController:self];
}

- (void)tabBtnClicked:(UIButton *)sender {
    
    if ([self.delegate respondsToSelector:@selector(tabController:didScrollOutIndex:)]) {
        [self.delegate tabController:self didScrollOutIndex:self.currentTabIndex];
    }
    
    [self scrollToTabIndex:sender.tag animated:NO];
}

- (void)postDidScrollToDelegateMethod {
    BOOL showed = [self.tabIndexedShowedStates[self.currentTabIndex] boolValue];
    if ([self.delegate respondsToSelector:@selector(tabController:didScrollToTabIndex:firstTime:)]) {
        BOOL isFirstTime = !showed;
        [self.delegate tabController:self didScrollToTabIndex:self.currentTabIndex firstTime:isFirstTime];
    }
    self.tabIndexedShowedStates[self.currentTabIndex] = @(YES);
}

#pragma mark - Scroll

- (void)scrollToTabIndex:(NSUInteger)index animated:(BOOL)animated {
    [self.tabPages endEditing:YES];
    
    if ([self.delegate respondsToSelector:@selector(tabController:didScrollOutIndex:)]) {
        [self.delegate tabController:self didScrollOutIndex:self.currentTabIndex];
    }
    
    [self loadTabItemVCForTabIndexIfNeeded:index];
    CGPoint offset = CGPointMake(index * CGRectGetWidth(self.tabPages.bounds), 0);
    self.currentTabIndex = index;
    if (!animated) { //非动画方式，setContentOffset不会触发代理方法scrollViewDidEndScrollingAnimation；非动画的方式不用区分时间顺序。所以直接重置按钮样式
        [self resetBtnApperance];
        [self postDidScrollToDelegateMethod];
    }
    [self.tabPages setContentOffset:offset animated:animated];
}

#pragma mark - Indicator re-positioning

/**
 tab header不可用时，不显示indicator view
 */
- (void)setIndicatorViewZeroLength {
    [self.pageIndicatorTrailingCons uninstall];
    [self.pageIndicatorLeadingCons uninstall];
    [self.pageIndicatorView mas_makeConstraints:^(MASConstraintMaker *make) {
        self.pageIndicatorLeadingCons = make.left.equalTo(self.tabHeader);
        self.pageIndicatorTrailingCons = make.right.equalTo(self.tabHeader.mas_left);
    }];
    [self.view layoutIfNeeded];
}

- (void)updateIndicatorViewWithProgress:(float)progress {
    UIButton *currentBtn = [self indicatorBtnAtTabIndex:self.currentTabIndex];
    UIButton *nextBtn;
    if (progress == 0) {
        nextBtn = currentBtn;
    } else if (progress > 0) {
        nextBtn = [self indicatorBtnAtTabIndex:self.currentTabIndex + 1];
    } else {
        nextBtn = [self indicatorBtnAtTabIndex:self.currentTabIndex - 1];
    }
    
    CGFloat minXOffset = [self minXOffsetBetweenBtn:nextBtn andAnotherBtn:currentBtn];
    CGFloat maxXOffset = [self maxXOffsetBetweenBtn:nextBtn andAnotherBtn:currentBtn];
    [self updateIndicatorViewPostionWithMinXoffset:minXOffset * fabsf(progress) andMaxXoffset:maxXOffset * fabsf(progress)];
}

- (void)updateIndicatorViewPostionWithMinXoffset:(CGFloat)minXoffset andMaxXoffset:(CGFloat)maxXOffset {
    UIButton *btn = [self indicatorBtnAtTabIndex:self.currentTabIndex];
    
    [self.pageIndicatorTrailingCons uninstall];
    [self.pageIndicatorLeadingCons uninstall];
    [self.pageIndicatorView mas_makeConstraints:^(MASConstraintMaker *make) {
        self.pageIndicatorLeadingCons = make.left.equalTo(btn.titleLabel).offset(minXoffset + TabHeaderTitleWidthOffset / 2);
        self.pageIndicatorTrailingCons = make.right.equalTo(btn.titleLabel).offset(maxXOffset - TabHeaderTitleWidthOffset / 2);
    }];
    [UIView animateWithDuration:0.25 animations:^{
        [self.view layoutIfNeeded];
    }];
}

- (void)resetIndicatorViewPosition {
    [self.pageIndicatorTrailingCons uninstall];
    [self.pageIndicatorLeadingCons uninstall];
    UIButton *btn = [self indicatorBtnAtTabIndex:self.currentTabIndex];
    [self.pageIndicatorView mas_makeConstraints:^(MASConstraintMaker *make) {
        self.pageIndicatorLeadingCons = make.left.equalTo(btn.titleLabel).offset(TabHeaderTitleWidthOffset / 2);
        self.pageIndicatorTrailingCons = make.right.equalTo(btn.titleLabel).offset(-TabHeaderTitleWidthOffset / 2);
    }];
    [self.view layoutIfNeeded];
}

- (UIButton *)indicatorBtnAtTabIndex:(NSUInteger)index {
    return (UIButton *)self.tabHeader.subviews[index + 2];
}

- (CGFloat)minXOffsetBetweenBtn:(UIButton *)btn andAnotherBtn:(UIButton *)anotherBtn {
    CGRect frame1 = [btn convertRect:btn.titleLabel.frame toView:self.tabHeader];
    CGRect frame2 = [anotherBtn convertRect:anotherBtn.titleLabel.frame toView:self.tabHeader];
    CGFloat minXOffset = CGRectGetMinX(frame1) - CGRectGetMinX(frame2);
    return minXOffset;
}

- (CGFloat)maxXOffsetBetweenBtn:(UIButton *)btn andAnotherBtn:(UIButton *)anotherBtn {
    CGRect frame1 = [btn convertRect:btn.titleLabel.frame toView:self.tabHeader];
    CGRect frame2 = [anotherBtn convertRect:anotherBtn.titleLabel.frame toView:self.tabHeader];
    CGFloat maxXOffset = CGRectGetMaxX(frame1) - CGRectGetMaxX(frame2);
    return maxXOffset;
}

- (void)resetBtnApperance {
    for (UIView *subview in self.tabHeader.subviews) {
        if (![subview isKindOfClass:[UIButton class]]) {
            continue;
        }
        UIButton *btn = (UIButton *)subview;
        [btn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        btn.layer.transform = CATransform3DIdentity;
    }
    UIButton *btn = [self indicatorBtnAtTabIndex:self.currentTabIndex];
    [btn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    btn.layer.transform = CATransform3DMakeScale(TabHeaderBtnScaleMax, TabHeaderBtnScaleMax, 1.0);
}

- (void)updateBtnWithProgress:(float)progress {
    UIButton *currentBtn = [self indicatorBtnAtTabIndex:self.currentTabIndex];
    CGFloat currentScale = TabHeaderBtnScaleMax - (TabHeaderBtnScaleMax - TabHeaderBtnScaleMin) * fabsf(progress);
    currentBtn.layer.transform = CATransform3DMakeScale(currentScale, currentScale, 1);
    // 选中RGB: 241 84 64
    // 普通RGB: 102 102 102
    CGFloat currentRed = 241 - (241 - 102) * fabsf(progress);
    CGFloat currentGreen = 84 - (84 - 102) *fabsf(progress);
    CGFloat currentBlue = 64 - (64 - 102) *fabsf(progress);
    UIColor *currentColor = [UIColor colorWithRed:currentRed / 255.0 green:currentGreen / 255.0 blue:currentBlue / 255.0 alpha:1];
    [currentBtn setTitleColor:currentColor forState:UIControlStateNormal];
    
    UIButton *nextBtn;
    if (progress > 0) {
        nextBtn = [self indicatorBtnAtTabIndex:self.currentTabIndex + 1];
    } else if (progress < 0) {
        nextBtn = [self indicatorBtnAtTabIndex:self.currentTabIndex - 1];
    }
    if (!nextBtn) {
        return;
    }
    CGFloat nextScale = TabHeaderBtnScaleMin + (TabHeaderBtnScaleMax - TabHeaderBtnScaleMin) * fabsf(progress);
    nextBtn.layer.transform = CATransform3DMakeScale(nextScale, nextScale, 1.0);
    CGFloat nextRed = 102 + (241 - 102) * fabsf(progress);
    CGFloat nextGreen = 102 + (84 - 102) *fabsf(progress);
    CGFloat nextBlue = 102 + (64 - 102) *fabsf(progress);
    UIColor *nextColor = [UIColor colorWithRed:nextRed / 255.0 green:nextGreen / 255.0 blue:nextBlue / 255.0 alpha:1];
    [nextBtn setTitleColor:nextColor forState:UIControlStateNormal];
}

@end

@implementation MHTabControllerRoundEdgeView
{
    UIColor *_bgColor;
}

- (void)setBackgroundColor:(UIColor *)backgroundColor {
    [super setBackgroundColor:[UIColor clearColor]];
    _bgColor = backgroundColor;
}

- (void)drawRect:(CGRect)rect {
    //实现圆角
    CGFloat width = CGRectGetWidth(rect);
    CGFloat height = CGRectGetHeight(rect);
    CGFloat roundEdgeRadius = height / 2.0;
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextMoveToPoint(ctx, roundEdgeRadius, 0);
    CGContextAddLineToPoint(ctx, width - roundEdgeRadius, 0);
    CGContextMoveToPoint(ctx, width - roundEdgeRadius, 0);
    CGContextAddArcToPoint(ctx, width, 0, width, roundEdgeRadius, roundEdgeRadius);
    CGContextAddArcToPoint(ctx, width, height, width - roundEdgeRadius, height, roundEdgeRadius);
    CGContextAddLineToPoint(ctx, roundEdgeRadius, height);
    CGContextAddArcToPoint(ctx, 0, height, 0, roundEdgeRadius, roundEdgeRadius);
    CGContextAddArcToPoint(ctx, 0, 0, roundEdgeRadius, 0, roundEdgeRadius);
    [_bgColor setFill];
    CGContextFillPath(ctx);
    CGContextClip(ctx);
}

@end
