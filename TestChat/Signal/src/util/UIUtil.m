//
//  Copyright (c) 2017 Open Whisper Systems. All rights reserved.
//

#import "UIUtil.h"

#define CONTACT_PICTURE_VIEW_BORDER_WIDTH 0.5f

@implementation UIUtil

+ (void)applyRoundedBorderToImageView:(UIImageView *)imageView
{
    imageView.layer.borderWidth = CONTACT_PICTURE_VIEW_BORDER_WIDTH;
    imageView.layer.borderColor = [UIColor clearColor].CGColor;
    imageView.layer.cornerRadius = CGRectGetWidth(imageView.frame) / 2;
    imageView.layer.masksToBounds = YES;
}

+ (void)removeRoundedBorderToImageView:(UIImageView *__strong *)imageView {
    [[*imageView layer] setBorderWidth:0];
    [[*imageView layer] setCornerRadius:0];
}

+ (completionBlock)modalCompletionBlock {
    completionBlock block = ^void() {
      [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];
    };

    return block;
}

+ (void)applyDefaultSystemAppearence
{
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault];
    [[UINavigationBar appearance] setBarStyle:UIBarStyleDefault];
    [[UINavigationBar appearance] setTintColor:[UIColor blackColor]];
    [[UIBarButtonItem appearance] setTintColor:[UIColor blackColor]];
    [[UINavigationBar appearance] setTitleTextAttributes:@{
                                                           NSForegroundColorAttributeName : [UIColor blackColor],
                                                           }];
}

+ (void)applySignalAppearence
{
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];
    [[UINavigationBar appearance] setBarTintColor:[UIColor ows_materialBlueColor]];
    [[UINavigationBar appearance] setTintColor:[UIColor whiteColor]];

    [[UIBarButtonItem appearanceWhenContainedIn:[UISearchBar class], nil] setTintColor:[UIColor ows_materialBlueColor]];

    [[UISwitch appearance] setOnTintColor:[UIColor ows_materialBlueColor]];
    [[UIToolbar appearance] setTintColor:[UIColor ows_materialBlueColor]];
    [[UIBarButtonItem appearance] setTintColor:[UIColor whiteColor]];

    // If we set NSShadowAttributeName, the NSForegroundColorAttributeName value is ignored.
    [[UINavigationBar appearance] setTitleTextAttributes:@{
                                                           NSForegroundColorAttributeName : [UIColor whiteColor],
                                                           }];
}

@end
