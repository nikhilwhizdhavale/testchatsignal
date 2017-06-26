//
//  Copyright (c) 2017 Open Whisper Systems. All rights reserved.
//

#import "FingerprintViewScanController.h"
#import "Environment.h"
#import "OWSContactsManager.h"
#import "OWSQRCodeScanningViewController.h"
#import "Signal-Swift.h"
#import "UIColor+OWS.h"
#import "UIFont+OWS.h"
#import "UIUtil.h"
#import "UIView+OWS.h"
#import "UIViewController+CameraPermissions.h"
#import <SignalServiceKit/OWSError.h>
#import <SignalServiceKit/OWSFingerprint.h>
#import <SignalServiceKit/OWSFingerprintBuilder.h>
#import <SignalServiceKit/OWSIdentityManager.h>

NS_ASSUME_NONNULL_BEGIN

@interface FingerprintViewScanController () <OWSQRScannerDelegate>

@property (nonatomic) TSStorageManager *storageManager;
@property (nonatomic) NSString *recipientId;
@property (nonatomic) NSData *identityKey;
@property (nonatomic) OWSFingerprint *fingerprint;
@property (nonatomic) NSString *contactName;
@property (nonatomic) OWSQRCodeScanningViewController *qrScanningController;

@end

#pragma mark -

@implementation FingerprintViewScanController

- (void)configureWithRecipientId:(NSString *)recipientId
{
    OWSAssert(recipientId.length > 0);

    self.recipientId = recipientId;

    self.storageManager = [TSStorageManager sharedManager];

    OWSContactsManager *contactsManager = [Environment getCurrent].contactsManager;
    self.contactName = [contactsManager displayNameForPhoneIdentifier:recipientId];

    OWSRecipientIdentity *_Nullable recipientIdentity =
        [[OWSIdentityManager sharedManager] recipientIdentityForRecipientId:recipientId];
    OWSAssert(recipientIdentity);
    // By capturing the identity key when we enter these views, we prevent the edge case
    // where the user verifies a key that we learned about while this view was open.
    self.identityKey = recipientIdentity.identityKey;

    OWSFingerprintBuilder *builder =
        [[OWSFingerprintBuilder alloc] initWithStorageManager:self.storageManager contactsManager:contactsManager];
    self.fingerprint =
        [builder fingerprintWithTheirSignalId:recipientId theirIdentityKey:recipientIdentity.identityKey];
}

- (void)loadView
{
    [super loadView];

    self.title = NSLocalizedString(@"SCAN_QR_CODE_VIEW_TITLE", @"Title for the 'scan QR code' view.");

    [self createViews];
}

- (void)createViews
{
    UIColor *darkGrey = [UIColor colorWithRGBHex:0x404040];

    self.view.backgroundColor = [UIColor blackColor];

    self.qrScanningController = [OWSQRCodeScanningViewController new];
    self.qrScanningController.scanDelegate = self;
    [self.view addSubview:self.qrScanningController.view];
    [self.qrScanningController.view autoPinWidthToSuperview];
    [self.qrScanningController.view autoPinToTopLayoutGuideOfViewController:self withInset:0];

    UIView *footer = [UIView new];
    footer.backgroundColor = darkGrey;
    [self.view addSubview:footer];
    [footer autoPinWidthToSuperview];
    [footer autoPinToBottomLayoutGuideOfViewController:self withInset:0];
    [footer autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.qrScanningController.view];

    UILabel *cameraInstructionLabel = [UILabel new];
    cameraInstructionLabel.text
        = NSLocalizedString(@"SCAN_CODE_INSTRUCTIONS", @"label presented once scanning (camera) view is visible.");
    cameraInstructionLabel.font = [UIFont ows_regularFontWithSize:ScaleFromIPhone5To7Plus(14.f, 18.f)];
    cameraInstructionLabel.textColor = [UIColor whiteColor];
    cameraInstructionLabel.textAlignment = NSTextAlignmentCenter;
    cameraInstructionLabel.numberOfLines = 0;
    cameraInstructionLabel.lineBreakMode = NSLineBreakByWordWrapping;
    [footer addSubview:cameraInstructionLabel];
    [cameraInstructionLabel autoPinWidthToSuperviewWithMargin:ScaleFromIPhone5To7Plus(16.f, 30.f)];
    CGFloat instructionsVMargin = ScaleFromIPhone5To7Plus(10.f, 20.f);
    [cameraInstructionLabel autoPinEdgeToSuperviewEdge:ALEdgeBottom withInset:instructionsVMargin];
    [cameraInstructionLabel autoPinEdgeToSuperviewEdge:ALEdgeTop withInset:instructionsVMargin];
}

- (void)viewWillAppear:(BOOL)animated
{
    // In case we're returning from activity view that needed default system styles.
    [UIUtil applySignalAppearence];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:YES];
}

#pragma mark - Action


- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    [self ows_askForCameraPermissions:^{

        // Camera stops capturing when "sharing" while in capture mode.
        // Also, it's less obvious whats being "shared" at this point,
        // so just disable sharing when in capture mode.

        DDLogInfo(@"%@ Showing Scanner", self.tag);

        [self.qrScanningController startCapture];
    }
        failureCallback:^{
            [self.navigationController popViewControllerAnimated:YES];
        }];
}

#pragma mark - OWSQRScannerDelegate

- (void)controller:(OWSQRCodeScanningViewController *)controller didDetectQRCodeWithData:(NSData *)data
{
    [self verifyCombinedFingerprintData:data];
}

- (void)verifyCombinedFingerprintData:(NSData *)combinedFingerprintData
{
    NSError *error;
    if ([self.fingerprint matchesLogicalFingerprintsData:combinedFingerprintData error:&error]) {
        [self showVerificationSucceeded];
    } else {
        [self showVerificationFailedWithError:error];
    }
}

- (void)showVerificationSucceeded
{
    [self.class showVerificationSucceeded:self
                              identityKey:self.identityKey
                              recipientId:self.recipientId
                              contactName:self.contactName
                                      tag:self.tag];
}

- (void)showVerificationFailedWithError:(NSError *)error
{

    [self.class showVerificationFailedWithError:error
        viewController:self
        retryBlock:^{
            [self.qrScanningController startCapture];
        }
        cancelBlock:^{
            [self.navigationController popViewControllerAnimated:YES];
        }
        tag:self.tag];
}

+ (void)showVerificationSucceeded:(UIViewController *)viewController
                      identityKey:(NSData *)identityKey
                      recipientId:(NSString *)recipientId
                      contactName:(NSString *)contactName
                              tag:(NSString *)tag
{
    OWSAssert(viewController);
    OWSAssert(identityKey.length > 0);
    OWSAssert(recipientId.length > 0);
    OWSAssert(contactName.length > 0);
    OWSAssert(tag.length > 0);

    DDLogInfo(@"%@ Successfully verified safety numbers.", tag);

    NSString *successTitle = NSLocalizedString(@"SUCCESSFUL_VERIFICATION_TITLE", nil);
    NSString *dismissText = NSLocalizedString(@"DISMISS_BUTTON_TEXT", nil);
    NSString *descriptionFormat = NSLocalizedString(
        @"SUCCESSFUL_VERIFICATION_DESCRIPTION", @"Alert body after verifying privacy with {{other user's name}}");
    NSString *successDescription = [NSString stringWithFormat:descriptionFormat, contactName];
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:successTitle
                                                                             message:successDescription
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    [alertController
        addAction:[UIAlertAction
                      actionWithTitle:NSLocalizedString(@"FINGERPRINT_SCAN_VERIFY_BUTTON",
                                          @"Button that marks user as verified after a successful fingerprint scan.")
                                style:UIAlertActionStyleDefault
                              handler:^(UIAlertAction *action) {
                                  [OWSIdentityManager.sharedManager setVerificationState:OWSVerificationStateVerified
                                                                             identityKey:identityKey
                                                                             recipientId:recipientId
                                                                         isUserInitiatedChange:YES];
                                  [viewController dismissViewControllerAnimated:true completion:nil];
                              }]];
    UIAlertAction *dismissAction =
        [UIAlertAction actionWithTitle:dismissText
                                 style:UIAlertActionStyleDefault
                               handler:^(UIAlertAction *action) {
                                   [viewController dismissViewControllerAnimated:true completion:nil];
                               }];
    [alertController addAction:dismissAction];

    [viewController presentViewController:alertController animated:YES completion:nil];
}

+ (void)showVerificationFailedWithError:(NSError *)error
                         viewController:(UIViewController *)viewController
                             retryBlock:(void (^_Nullable)())retryBlock
                            cancelBlock:(void (^_Nonnull)())cancelBlock
                                    tag:(NSString *)tag
{
    OWSAssert(viewController);
    OWSAssert(cancelBlock);
    OWSAssert(tag.length > 0);

    DDLogInfo(@"%@ Failed to verify safety numbers.", tag);

    NSString *_Nullable failureTitle;
    if (error.code != OWSErrorCodeUserError) {
        failureTitle = NSLocalizedString(@"FAILED_VERIFICATION_TITLE", @"alert title");
    } // else no title. We don't want to show a big scary "VERIFICATION FAILED" when it's just user error.

    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:failureTitle
                                                                             message:error.localizedDescription
                                                                      preferredStyle:UIAlertControllerStyleAlert];

    if (retryBlock) {
        [alertController
            addAction:[UIAlertAction
                          actionWithTitle:NSLocalizedString(@"RETRY_BUTTON_TEXT",
                                              @"Generic text for button that retries whatever the last action was.")
                                    style:UIAlertActionStyleDefault
                                  handler:^(UIAlertAction *action) {
                                      retryBlock();
                                  }]];
    }

    UIAlertAction *dismissAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"TXT_CANCEL_TITLE", nil)
                                                            style:UIAlertActionStyleCancel
                                                          handler:^(UIAlertAction *action) {
                                                              cancelBlock();
                                                          }];
    [alertController addAction:dismissAction];

    [viewController presentViewController:alertController animated:YES completion:nil];

    DDLogWarn(@"%@ Identity verification failed with error: %@", tag, error);
}

- (void)dismissViewControllerAnimated:(BOOL)animated completion:(nullable void (^)(void))completion
{
    self.qrScanningController.view.hidden = YES;

    [super dismissViewControllerAnimated:animated completion:completion];
}

#pragma mark - Logging

+ (NSString *)tag
{
    return [NSString stringWithFormat:@"[%@]", self.class];
}

- (NSString *)tag
{
    return self.class.tag;
}

@end

NS_ASSUME_NONNULL_END
