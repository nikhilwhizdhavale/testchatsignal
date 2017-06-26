//
//  Copyright (c) 2017 Open Whisper Systems. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "OWSContactsManager.h"

/**
 *
 * ContactTableViewCell displays a contact from a Contact object.
 *
 */

NS_ASSUME_NONNULL_BEGIN

extern NSString *const kContactsTable_CellReuseIdentifier;

@class OWSContactsManager;
@class SignalAccount;
@class TSThread;

@interface ContactTableViewCell : UITableViewCell

@property (nonatomic, nullable) NSString *accessoryMessage;

+ (nullable NSString *)reuseIdentifier;

+ (CGFloat)rowHeight;

- (void)configureWithSignalAccount:(SignalAccount *)signalAccount contactsManager:(OWSContactsManager *)contactsManager;

- (void)configureWithRecipientId:(NSString *)recipientId contactsManager:(OWSContactsManager *)contactsManager;

- (void)configureWithThread:(TSThread *)thread contactsManager:(OWSContactsManager *)contactsManager;

- (void)addVerifiedSubtitle;

@end

NS_ASSUME_NONNULL_END
