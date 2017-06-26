//
//  Copyright (c) 2017 Open Whisper Systems. All rights reserved.
//

#import "FingerprintViewController.h"
#import "Environment.h"
#import "FingerprintViewScanController.h"
#import "OWSBezierPathView.h"
#import "OWSContactsManager.h"
#import "Signal-Swift.h"
#import "UIColor+OWS.h"
#import "UIFont+OWS.h"
#import "UIUtil.h"
#import "UIView+OWS.h"
#import <SignalServiceKit/NSDate+millisecondTimeStamp.h>
#import <SignalServiceKit/OWSError.h>
#import <SignalServiceKit/OWSFingerprint.h>
#import <SignalServiceKit/OWSFingerprintBuilder.h>
#import <SignalServiceKit/OWSIdentityManager.h>
#import <SignalServiceKit/TSInfoMessage.h>
#import <SignalServiceKit/TSStorageManager+SessionStore.h>
#import <SignalServiceKit/TSStorageManager+keyingMaterial.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^CustomLayoutBlock)();

@interface CustomLayoutView : UIView

@property (nonatomic) CustomLayoutBlock layoutBlock;

@end

#pragma mark -

@implementation CustomLayoutView

- (instancetype)init
{
    if (self = [super init]) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
    }
    return self;
}

- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder]) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    self.layoutBlock();
}

@end

#pragma mark -

@interface FingerprintViewController () <OWSCompareSafetyNumbersActivityDelegate>

@property (nonatomic) NSString *recipientId;
@property (nonatomic) NSData *identityKey;
@property (nonatomic) TSStorageManager *storageManager;
@property (nonatomic) OWSFingerprint *fingerprint;
@property (nonatomic) NSString *contactName;

@property (nonatomic) UIBarButtonItem *shareButton;

@property (nonatomic) UILabel *verificationStateLabel;
@property (nonatomic) UILabel *verifyUnverifyButtonLabel;

@end

#pragma mark -

@implementation FingerprintViewController

+ (void)presentFromViewController:(UIViewController *)viewController recipientId:(NSString *)recipientId
{
    OWSAssert(recipientId.length > 0);

    OWSRecipientIdentity *_Nullable recipientIdentity =
        [[OWSIdentityManager sharedManager] recipientIdentityForRecipientId:recipientId];
    if (!recipientIdentity) {
        [OWSAlerts showAlertWithTitle:NSLocalizedString(@"CANT_VERIFY_IDENTITY_ALERT_TITLE",
                                          @"Title for alert explaining that a user cannot be verified.")
                              message:NSLocalizedString(@"CANT_VERIFY_IDENTITY_ALERT_MESSAGE",
                                          @"Message for alert explaining that a user cannot be verified.")];
        return;
    }

    FingerprintViewController *fingerprintViewController = [FingerprintViewController new];
    [fingerprintViewController configureWithRecipientId:recipientId];
    UINavigationController *navigationController =
        [[UINavigationController alloc] initWithRootViewController:fingerprintViewController];
    [viewController presentViewController:navigationController animated:YES completion:nil];
}

- (instancetype)init
{
    self = [super init];

    if (!self) {
        return self;
    }

    [self observeNotifications];

    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)observeNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(identityStateDidChange:)
                                                 name:kNSNotificationName_IdentityStateDidChange
                                               object:nil];
}

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

    self.title = NSLocalizedString(@"PRIVACY_VERIFICATION_TITLE", @"Navbar title");

    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop
                                                      target:self
                                                      action:@selector(closeButton)];
    self.shareButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction
                                                                     target:self
                                                                     action:@selector(didTapShareButton)];
    self.navigationItem.rightBarButtonItem = self.shareButton;

    [self createViews];
}

- (void)createViews
{
    UIColor *darkGrey = [UIColor colorWithRGBHex:0x404040];

    self.view.backgroundColor = [UIColor whiteColor];

    // Verify/Unverify Button
    UIView *verifyUnverifyButton = [UIView new];
    [verifyUnverifyButton
        addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self
                                                                     action:@selector(verifyUnverifyButtonTapped:)]];
    [self.view addSubview:verifyUnverifyButton];
    [verifyUnverifyButton autoPinWidthToSuperview];
    [verifyUnverifyButton autoPinToBottomLayoutGuideOfViewController:self withInset:0];

    UIView *verifyUnverifyPillbox = [UIView new];
    verifyUnverifyPillbox.backgroundColor = [UIColor ows_materialBlueColor];
    verifyUnverifyPillbox.layer.cornerRadius = 3.f;
    verifyUnverifyPillbox.clipsToBounds = YES;
    [verifyUnverifyButton addSubview:verifyUnverifyPillbox];
    [verifyUnverifyPillbox autoHCenterInSuperview];
    [verifyUnverifyPillbox autoPinEdgeToSuperviewEdge:ALEdgeTop withInset:ScaleFromIPhone5To7Plus(10.f, 15.f)];
    [verifyUnverifyPillbox autoPinEdgeToSuperviewEdge:ALEdgeBottom withInset:ScaleFromIPhone5To7Plus(10.f, 20.f)];

    UILabel *verifyUnverifyButtonLabel = [UILabel new];
    self.verifyUnverifyButtonLabel = verifyUnverifyButtonLabel;
    verifyUnverifyButtonLabel.font = [UIFont ows_mediumFontWithSize:ScaleFromIPhone5To7Plus(14.f, 20.f)];
    verifyUnverifyButtonLabel.textColor = [UIColor whiteColor];
    verifyUnverifyButtonLabel.textAlignment = NSTextAlignmentCenter;
    [verifyUnverifyPillbox addSubview:verifyUnverifyButtonLabel];
    [verifyUnverifyButtonLabel autoPinWidthToSuperviewWithMargin:ScaleFromIPhone5To7Plus(50.f, 50.f)];
    [verifyUnverifyButtonLabel autoPinHeightToSuperviewWithMargin:ScaleFromIPhone5To7Plus(8.f, 8.f)];

    // Learn More
    UIView *learnMoreButton = [UIView new];
    [learnMoreButton
        addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self
                                                                     action:@selector(learnMoreButtonTapped:)]];
    [self.view addSubview:learnMoreButton];
    [learnMoreButton autoPinWidthToSuperview];
    [learnMoreButton autoPinEdge:ALEdgeBottom toEdge:ALEdgeTop ofView:verifyUnverifyButton withOffset:0];

    UILabel *learnMoreLabel = [UILabel new];
    learnMoreLabel.attributedText = [[NSAttributedString alloc]
        initWithString:NSLocalizedString(@"PRIVACY_SAFETY_NUMBERS_LEARN_MORE",
                           @"Label for a link to more information about safety numbers and verification.")
            attributes:@{
                NSUnderlineStyleAttributeName : @(NSUnderlineStyleSingle | NSUnderlinePatternSolid),
            }];
    learnMoreLabel.font = [UIFont ows_regularFontWithSize:ScaleFromIPhone5To7Plus(13.f, 16.f)];
    learnMoreLabel.textColor = [UIColor ows_materialBlueColor];
    learnMoreLabel.textAlignment = NSTextAlignmentCenter;
    [learnMoreButton addSubview:learnMoreLabel];
    [learnMoreLabel autoPinWidthToSuperviewWithMargin:16.f];
    [learnMoreLabel autoPinEdgeToSuperviewEdge:ALEdgeTop withInset:ScaleFromIPhone5To7Plus(5.f, 10.f)];
    [learnMoreLabel autoPinEdgeToSuperviewEdge:ALEdgeBottom withInset:ScaleFromIPhone5To7Plus(5.f, 10.f)];

    // Instructions
    NSString *instructionsFormat = NSLocalizedString(@"PRIVACY_VERIFICATION_INSTRUCTIONS",
        @"Paragraph(s) shown alongside the safety number when verifying privacy with {{contact name}}");
    UILabel *instructionsLabel = [UILabel new];
    instructionsLabel.text = [NSString stringWithFormat:instructionsFormat, self.contactName];
    instructionsLabel.font = [UIFont ows_regularFontWithSize:ScaleFromIPhone5To7Plus(11.f, 14.f)];
    instructionsLabel.textColor = darkGrey;
    instructionsLabel.textAlignment = NSTextAlignmentCenter;
    instructionsLabel.numberOfLines = 0;
    instructionsLabel.lineBreakMode = NSLineBreakByWordWrapping;
    [self.view addSubview:instructionsLabel];
    [instructionsLabel autoPinWidthToSuperviewWithMargin:16.f];
    [instructionsLabel autoPinEdge:ALEdgeBottom toEdge:ALEdgeTop ofView:learnMoreButton withOffset:0];

    // Fingerprint Label
    UILabel *fingerprintLabel = [UILabel new];
    fingerprintLabel.text = self.fingerprint.displayableText;
    fingerprintLabel.font = [UIFont fontWithName:@"Menlo-Regular" size:ScaleFromIPhone5To7Plus(20.f, 23.f)];
    fingerprintLabel.textColor = darkGrey;
    fingerprintLabel.numberOfLines = 3;
    fingerprintLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    fingerprintLabel.adjustsFontSizeToFitWidth = YES;
    [fingerprintLabel
        addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self
                                                                     action:@selector(fingerprintLabelTapped:)]];
    fingerprintLabel.userInteractionEnabled = YES;
    [self.view addSubview:fingerprintLabel];
    [fingerprintLabel autoPinWidthToSuperviewWithMargin:ScaleFromIPhone5To7Plus(50.f, 60.f)];
    [fingerprintLabel autoPinEdge:ALEdgeBottom toEdge:ALEdgeTop ofView:instructionsLabel withOffset:-ScaleFromIPhone5To7Plus(8.f, 15.f)];

    // Fingerprint Image
    CustomLayoutView *fingerprintView = [CustomLayoutView new];
    [self.view addSubview:fingerprintView];
    [fingerprintView autoPinWidthToSuperview];
    [fingerprintView autoPinEdge:ALEdgeBottom toEdge:ALEdgeTop ofView:fingerprintLabel withOffset:-ScaleFromIPhone5To7Plus(10.f, 15.f)];
    [fingerprintView
        addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self
                                                                     action:@selector(fingerprintViewTapped:)]];
    fingerprintView.userInteractionEnabled = YES;

    OWSBezierPathView *fingerprintCircle = [OWSBezierPathView new];
    [fingerprintCircle setConfigureShapeLayerBlock:^(CAShapeLayer *layer, CGRect bounds) {
        layer.fillColor = [UIColor colorWithWhite:0.9f alpha:1.f].CGColor;
        CGFloat size = MIN(bounds.size.width, bounds.size.height);
        CGRect circle = CGRectMake((bounds.size.width - size) * 0.5f, (bounds.size.height - size) * 0.5f, size, size);
        layer.path = [UIBezierPath bezierPathWithOvalInRect:circle].CGPath;
    }];
    [fingerprintView addSubview:fingerprintCircle];
    [fingerprintCircle autoPinWidthToSuperview];
    [fingerprintCircle autoPinHeightToSuperview];

    UIImageView *fingerprintImageView = [UIImageView new];
    fingerprintImageView.image = self.fingerprint.image;
    // Don't antialias QR Codes.
    fingerprintImageView.layer.magnificationFilter = kCAFilterNearest;
    fingerprintImageView.layer.minificationFilter = kCAFilterNearest;
    [fingerprintView addSubview:fingerprintImageView];

    UILabel *scanLabel = [UILabel new];
    scanLabel.text = NSLocalizedString(@"PRIVACY_TAP_TO_SCAN", @"Button that shows the 'scan with camera' view.");
    scanLabel.font = [UIFont ows_mediumFontWithSize:ScaleFromIPhone5To7Plus(14.f, 16.f)];
    scanLabel.textColor = [UIColor colorWithWhite:0.15f alpha:1.f];
    [scanLabel sizeToFit];
    [fingerprintView addSubview:scanLabel];

    fingerprintView.layoutBlock = ^{
        CGFloat size = round(MIN(fingerprintView.width, fingerprintView.height) * 0.675f);
        fingerprintImageView.frame = CGRectMake(
            round((fingerprintView.width - size) * 0.5f), round((fingerprintView.height - size) * 0.5f), size, size);
        CGFloat scanY = round(fingerprintImageView.bottom
            + ((fingerprintView.height - fingerprintImageView.bottom) - scanLabel.height) * 0.33f);
        scanLabel.frame = CGRectMake(
            round((fingerprintView.width - scanLabel.width) * 0.5f), scanY, scanLabel.width, scanLabel.height);
    };

    // Verification State
    UILabel *verificationStateLabel = [UILabel new];
    self.verificationStateLabel = verificationStateLabel;
    verificationStateLabel.font = [UIFont ows_mediumFontWithSize:ScaleFromIPhone5To7Plus(16.f, 20.f)];
    verificationStateLabel.textColor = darkGrey;
    verificationStateLabel.textAlignment = NSTextAlignmentCenter;
    verificationStateLabel.numberOfLines = 0;
    verificationStateLabel.lineBreakMode = NSLineBreakByWordWrapping;
    [self.view addSubview:verificationStateLabel];
    [verificationStateLabel autoPinWidthToSuperviewWithMargin:16.f];
    [verificationStateLabel autoPinToTopLayoutGuideOfViewController:self withInset:ScaleFromIPhone5To7Plus(15.f, 20.f)];
    [verificationStateLabel autoPinEdge:ALEdgeBottom
                                 toEdge:ALEdgeTop
                                 ofView:fingerprintView
                             withOffset:-ScaleFromIPhone5To7Plus(10.f, 15.f)];

    [self updateVerificationStateLabel];
}

- (void)updateVerificationStateLabel
{
    OWSAssert(self.recipientId.length > 0);

    BOOL isVerified = [[OWSIdentityManager sharedManager] verificationStateForRecipientId:self.recipientId]
        == OWSVerificationStateVerified;

    if (isVerified) {
        NSMutableAttributedString *labelText = [NSMutableAttributedString new];

        if (isVerified) {
            // Show a "checkmark" if this user is verified.
            [labelText
                appendAttributedString:[[NSAttributedString alloc]
                                           initWithString:@"\uf00c "
                                               attributes:@{
                                                   NSFontAttributeName : [UIFont
                                                       ows_fontAwesomeFont:self.verificationStateLabel.font.pointSize],
                                               }]];
        }

        [labelText
            appendAttributedString:
                [[NSAttributedString alloc]
                    initWithString:[NSString stringWithFormat:NSLocalizedString(@"PRIVACY_IDENTITY_IS_VERIFIED_FORMAT",
                                                                  @"Label indicating that the user is verified. Embeds "
                                                                  @"{{the user's name or phone number}}."),
                                             self.contactName]]];
        self.verificationStateLabel.attributedText = labelText;

        self.verifyUnverifyButtonLabel.text = NSLocalizedString(
            @"PRIVACY_UNVERIFY_BUTTON", @"Button that lets user mark another user's identity as unverified.");
    } else {
        self.verificationStateLabel.text = [NSString
            stringWithFormat:NSLocalizedString(@"PRIVACY_IDENTITY_IS_NOT_VERIFIED_FORMAT",
                                 @"Label indicating that the user is not verified. Embeds {{the user's name or phone "
                                 @"number}}."),
            self.contactName];

        NSMutableAttributedString *buttonText = [NSMutableAttributedString new];
        // Show a "checkmark" if this user is not verified.
        [buttonText
            appendAttributedString:[[NSAttributedString alloc]
                                       initWithString:@"\uf00c  "
                                           attributes:@{
                                               NSFontAttributeName : [UIFont
                                                   ows_fontAwesomeFont:self.verifyUnverifyButtonLabel.font.pointSize],
                                           }]];
        [buttonText appendAttributedString:
                        [[NSAttributedString alloc]
                            initWithString:NSLocalizedString(@"PRIVACY_VERIFY_BUTTON",
                                               @"Button that lets user mark another user's identity as verified.")]];
        self.verifyUnverifyButtonLabel.attributedText = buttonText;
    }

    [self.view setNeedsLayout];
}

- (void)viewWillAppear:(BOOL)animated
{
    // In case we're returning from activity view that needed default system styles.
    [UIUtil applySignalAppearence];
}

#pragma mark -

- (void)showSharingActivityWithCompletion:(nullable void (^)(void))completionHandler
{
    DDLogDebug(@"%@ Sharing safety numbers", self.tag);

    OWSCompareSafetyNumbersActivity *compareActivity = [[OWSCompareSafetyNumbersActivity alloc] initWithDelegate:self];

    NSString *shareFormat = NSLocalizedString(@"SAFETY_NUMBER_SHARE_FORMAT", @"Snippet to share {{safety number}} with a friend. sent e.g. via SMS");
    NSString *shareString = [NSString stringWithFormat:shareFormat, self.fingerprint.displayableText];

    UIActivityViewController *activityController =
        [[UIActivityViewController alloc] initWithActivityItems:@[ shareString ]
                                          applicationActivities:@[ compareActivity ]];

    activityController.completionWithItemsHandler = ^void(UIActivityType __nullable activityType, BOOL completed, NSArray * __nullable returnedItems, NSError * __nullable activityError){
        if (completionHandler) {
            completionHandler();
        }
        [UIUtil applySignalAppearence];
    };

    // This value was extracted by inspecting `activityType` in the activityController.completionHandler
    NSString *const iCloudActivityType = @"com.apple.CloudDocsUI.AddToiCloudDrive";
    activityController.excludedActivityTypes = @[
        UIActivityTypePostToFacebook,
        UIActivityTypePostToWeibo,
        UIActivityTypeAirDrop,
        UIActivityTypePostToTwitter,
        iCloudActivityType // This isn't being excluded. RADAR https://openradar.appspot.com/27493621
    ];

    [UIUtil applyDefaultSystemAppearence];
    [self presentViewController:activityController animated:YES completion:nil];
}

#pragma mark - OWSCompareSafetyNumbersActivityDelegate

- (void)compareSafetyNumbersActivitySucceededWithActivity:(OWSCompareSafetyNumbersActivity *)activity
{
    [self showVerificationSucceeded];
}

- (void)compareSafetyNumbersActivity:(OWSCompareSafetyNumbersActivity *)activity failedWithError:(NSError *)error
{
    [self showVerificationFailedWithError:error];
}

- (void)showVerificationSucceeded
{
    [FingerprintViewScanController showVerificationSucceeded:self
                                                 identityKey:self.identityKey
                                                 recipientId:self.recipientId
                                                 contactName:self.contactName
                                                         tag:self.tag];
}

- (void)showVerificationFailedWithError:(NSError *)error
{

    [FingerprintViewScanController showVerificationFailedWithError:error
                                                    viewController:self
                                                        retryBlock:nil
                                                       cancelBlock:^{
                                                           // Do nothing.
                                                       }
                                                               tag:self.tag];
}

#pragma mark - Action

- (void)closeButton
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)didTapShareButton
{
    [self showSharingActivityWithCompletion:nil];
}

- (void)showScanner
{
    FingerprintViewScanController *scanView = [FingerprintViewScanController new];
    [scanView configureWithRecipientId:self.recipientId];
    [self.navigationController pushViewController:scanView animated:YES];
}

- (void)learnMoreButtonTapped:(UIGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer.state == UIGestureRecognizerStateRecognized) {
        NSString *learnMoreURL = @"https://support.whispersystems.org/hc/en-us/articles/"
                                 @"213134107";
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:learnMoreURL]];
    }
}

- (void)fingerprintLabelTapped:(UIGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer.state == UIGestureRecognizerStateRecognized) {
        [self showSharingActivityWithCompletion:nil];
    }
}

- (void)fingerprintViewTapped:(UIGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer.state == UIGestureRecognizerStateRecognized) {
        [self showScanner];
    }
}

- (void)verifyUnverifyButtonTapped:(UIGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer.state == UIGestureRecognizerStateRecognized) {
        BOOL isVerified = [[OWSIdentityManager sharedManager] verificationStateForRecipientId:self.recipientId]
            == OWSVerificationStateVerified;
        [[OWSIdentityManager sharedManager]
             setVerificationState:(isVerified ? OWSVerificationStateDefault : OWSVerificationStateVerified)identityKey
                                 :self.identityKey
                      recipientId:self.recipientId
            isUserInitiatedChange:YES];

        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

#pragma mark - Notifications

- (void)identityStateDidChange:(NSNotification *)notification
{
    OWSAssert([NSThread isMainThread]);

    [self updateVerificationStateLabel];
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
