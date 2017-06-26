//
//  Copyright (c) 2017 Open Whisper Systems. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class SignalAccount;
@class GroupViewHelper;
@class OWSContactsManager;
@class TSThread;

@protocol GroupViewHelperDelegate <NSObject>

- (void)groupAvatarDidChange:(UIImage *)image;

- (UIViewController *)fromViewController;

@end

#pragma mark -

typedef void (^GroupViewSuccessBlock)();

@interface GroupViewHelper : NSObject

@property (nonatomic, weak) id<GroupViewHelperDelegate> delegate;

- (void)showChangeGroupAvatarUI;

@end

NS_ASSUME_NONNULL_END
