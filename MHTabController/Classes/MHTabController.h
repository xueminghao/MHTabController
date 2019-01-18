//
//  MHTabController.h
//  MHTabController
//
//  Created by Minghao Xue on 2019/1/18.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, MHTabItemBadgeType) {
    MHTabItemBadgeTypeNone = 0,
    MHTabItemBadgeTypeDot,
    MHTabItemBadgeTypeText
};

@interface MHTabItemBadge : NSObject

@property (nonatomic, assign) MHTabItemBadgeType type;
@property (nonatomic, copy) NSString *badgeText;

@end

@class MHTabController;

@protocol MHTabControllerDataSource <NSObject>
@required
- (NSUInteger)numberOfTabItems;
- (NSString *)titleForItemAtIndex:(NSUInteger)index;
- (UIViewController *)presentViewControlerForItemAtIndex:(NSUInteger)index;

@optional
- (MHTabItemBadge *)badgeModelForItemAtIndex:(NSUInteger)index;
- (NSUInteger)defaultTabIndex;

@end

@protocol MHTabControllerDelegate <NSObject>

@optional
- (void)tabController:(UIViewController *)tabController didScrollToTabIndex:(NSUInteger)index firstTime:(BOOL)isFirstTime;
- (void)tabController:(UIViewController *)tabController didScrollOutIndex:(NSUInteger)index; //index所在的page已经消失

@end
/**
 分栏控制器。水平方向滚动。
 */
@interface MHTabController : UIViewController

/**
 分栏浏览视图
 */
@property (nonatomic, strong, readonly) UIScrollView *tabPages;

#pragma mark - Styles
/**
 分栏头
 */
@property (nonatomic, readonly) UIView *tabHeader;
/**
 分栏头底部分割线
 */
@property (nonatomic, readonly) UIView *tabHeaderBottomLine;

#pragma mark - State

/**
 当前Tab索引。从0开始
 */
@property (nonatomic, readonly) NSUInteger currentTabIndex;

/**
 当前显示的视图控制器
 */
@property (nonatomic, readonly) UIViewController *currentViewController;

#pragma mark - DataSource & Delegate

@property (nonatomic, weak) id<MHTabControllerDataSource> dataSource;
@property (nonatomic, weak) id<MHTabControllerDelegate> delegate;

#pragma mark - Reload

- (void)reload;

#pragma mark - Scroll

- (void)scrollToTabIndex:(NSUInteger)index animated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END
