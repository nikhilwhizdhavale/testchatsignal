//
//  Copyright (c) 2017 Open Whisper Systems. All rights reserved.
//

NS_ASSUME_NONNULL_BEGIN

extern NSString *const kNSNotificationName_IsCensorshipCircumventionActiveDidChange;

@class TSStorageManager;
@class TSAccountManager;
@class AFHTTPSessionManager;

@interface OWSSignalService : NSObject

@property (nonatomic, readonly) AFHTTPSessionManager *HTTPSessionManager;

@property (atomic, readonly) BOOL isCensorshipCircumventionActive;

@property (nonatomic, readonly) BOOL hasCensoredPhoneNumber;

+ (instancetype)sharedInstance;

- (instancetype)init NS_UNAVAILABLE;

- (BOOL)isCensorshipCircumventionManuallyActivated;
- (void)setIsCensorshipCircumventionManuallyActivated:(BOOL)value;

#pragma mark - Censorship Circumvention Domain

- (NSString *)manualCensorshipCircumventionDomain;
- (void)setManualCensorshipCircumventionDomain:(NSString *)value;

- (NSString *)manualCensorshipCircumventionCountryCode;
- (void)setManualCensorshipCircumventionCountryCode:(NSString *)value;

@end

NS_ASSUME_NONNULL_END
