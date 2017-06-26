//
//  Copyright (c) 2017 Open Whisper Systems. All rights reserved.
//

#import "NotificationsManager.h"
#import "Environment.h"
#import "OWSContactsManager.h"
#import "PropertyListPreferences.h"
#import "PushManager.h"
#import "Signal-Swift.h"
#import <AudioToolbox/AudioServices.h>
#import <SignalServiceKit/TSCall.h>
#import <SignalServiceKit/TSContactThread.h>
#import <SignalServiceKit/TSErrorMessage.h>
#import <SignalServiceKit/TSIncomingMessage.h>
#import <SignalServiceKit/TextSecureKitEnv.h>
#import <SignalServiceKit/Threading.h>

@interface NotificationsManager ()

@property (nonatomic) SystemSoundID newMessageSound;
@property (nonatomic, readonly) NSMutableDictionary<NSString *, UILocalNotification *> *currentNotifications;
@property (nonatomic, readonly) NotificationType notificationPreviewType;

@property (nonatomic, readonly) NSMutableArray<NSDate *> *notificationHistory;

@end

#pragma mark -

@implementation NotificationsManager

- (instancetype)init
{
    self = [super init];
    if (!self) {
        return self;
    }

    _currentNotifications = [NSMutableDictionary new];

    NSURL *newMessageURL = [[NSBundle mainBundle] URLForResource:@"NewMessage" withExtension:@"aifc"];
    AudioServicesCreateSystemSoundID((__bridge CFURLRef)newMessageURL, &_newMessageSound);

    _notificationHistory = [NSMutableArray new];

    OWSSingletonAssert();

    return self;
}

#pragma mark - Signal Calls

/**
 * Notify user for incoming WebRTC Call
 */
- (void)presentIncomingCall:(SignalCall *)call callerName:(NSString *)callerName
{
    DDLogDebug(@"%@ incoming call from: %@", self.tag, call.remotePhoneNumber);

    UILocalNotification *notification = [UILocalNotification new];
    notification.category = PushManagerCategoriesIncomingCall;
    // Rather than using notification sounds, we control the ringtone and repeat vibrations with the CallAudioManager.
    // notification.soundName = @"r.caf";
    NSString *localCallId = call.localId.UUIDString;
    notification.userInfo = @{ PushManagerUserInfoKeysLocalCallId : localCallId };

    NSString *alertMessage;
    switch (self.notificationPreviewType) {
        case NotificationNoNameNoPreview: {
            alertMessage = NSLocalizedString(@"INCOMING_CALL", @"notification body");
            break;
        }
        case NotificationNameNoPreview:
        case NotificationNamePreview: {
            alertMessage =
                [NSString stringWithFormat:NSLocalizedString(@"INCOMING_CALL_FROM", @"notification body"), callerName];
            break;
        }
    }
    notification.alertBody = [NSString stringWithFormat:@"☎️ %@", alertMessage];

    [self presentNotification:notification identifier:localCallId];
}

/**
 * Notify user for missed WebRTC Call
 */
- (void)presentMissedCall:(SignalCall *)call callerName:(NSString *)callerName
{
    UILocalNotification *notification = [UILocalNotification new];
    notification.category = PushManagerCategoriesMissedCall;
    NSString *localCallId = call.localId.UUIDString;
    notification.userInfo = @{
        PushManagerUserInfoKeysLocalCallId : localCallId,
        PushManagerUserInfoKeysCallBackSignalRecipientId : call.remotePhoneNumber
    };


    NSString *alertMessage;
    switch (self.notificationPreviewType) {
        case NotificationNoNameNoPreview: {
            alertMessage = [CallStrings missedCallNotificationBodyWithoutCallerName];
            break;
        }
        case NotificationNameNoPreview:
        case NotificationNamePreview: {
            alertMessage = (([UIDevice currentDevice].supportsCallKit &&
                             [[Environment getCurrent].preferences isCallKitPrivacyEnabled])
                            ? [CallStrings missedCallNotificationBodyWithoutCallerName]
                            : [NSString stringWithFormat:[CallStrings missedCallNotificationBodyWithCallerName], callerName]);
            break;
        }
    }
    notification.alertBody = [NSString stringWithFormat:@"☎️ %@", alertMessage];

    [self presentNotification:notification identifier:localCallId];
}


- (void)presentMissedCallBecauseOfNewIdentity:(SignalCall *)call callerName:(NSString *)callerName
{
    TSContactThread *thread = [TSContactThread getOrCreateThreadWithContactId:call.remotePhoneNumber];
    OWSAssert(thread != nil);

    UILocalNotification *notification = [UILocalNotification new];
    // Use category which allows call back
    notification.category = PushManagerCategoriesMissedCall;
    NSString *localCallId = call.localId.UUIDString;
    notification.userInfo = @{
        PushManagerUserInfoKeysLocalCallId : localCallId,
        PushManagerUserInfoKeysCallBackSignalRecipientId : call.remotePhoneNumber,
        Signal_Thread_UserInfo_Key : thread.uniqueId
    };

    NSString *alertMessage;
    switch (self.notificationPreviewType) {
        case NotificationNoNameNoPreview: {
            alertMessage = [CallStrings missedCallWithIdentityChangeNotificationBodyWithoutCallerName];
            break;
        }
        case NotificationNameNoPreview:
        case NotificationNamePreview: {
            alertMessage = (([UIDevice currentDevice].supportsCallKit &&
                                [[Environment getCurrent].preferences isCallKitPrivacyEnabled])
                    ? [CallStrings missedCallWithIdentityChangeNotificationBodyWithoutCallerName]
                    : [NSString
                          stringWithFormat:[CallStrings missedCallWithIdentityChangeNotificationBodyWithCallerName],
                          callerName]);
            break;
        }
    }
    notification.alertBody = [NSString stringWithFormat:@"☎️ %@", alertMessage];

    [self presentNotification:notification identifier:localCallId];
}

- (void)presentMissedCallBecauseOfNoLongerVerifiedIdentity:(SignalCall *)call callerName:(NSString *)callerName
{
    TSContactThread *thread = [TSContactThread getOrCreateThreadWithContactId:call.remotePhoneNumber];
    OWSAssert(thread != nil);

    UILocalNotification *notification = [UILocalNotification new];
    // Use category which does not allow call back
    notification.category = PushManagerCategoriesMissedCallFromNoLongerVerifiedIdentity;
    NSString *localCallId = call.localId.UUIDString;
    notification.userInfo = @{
        PushManagerUserInfoKeysLocalCallId : localCallId,
        PushManagerUserInfoKeysCallBackSignalRecipientId : call.remotePhoneNumber,
        Signal_Thread_UserInfo_Key : thread.uniqueId
    };

    NSString *alertMessage;
    switch (self.notificationPreviewType) {
        case NotificationNoNameNoPreview: {
            alertMessage = [CallStrings missedCallWithIdentityChangeNotificationBodyWithoutCallerName];
            break;
        }
        case NotificationNameNoPreview:
        case NotificationNamePreview: {
            alertMessage = (([UIDevice currentDevice].supportsCallKit &&
                                [[Environment getCurrent].preferences isCallKitPrivacyEnabled])
                    ? [CallStrings missedCallWithIdentityChangeNotificationBodyWithoutCallerName]
                    : [NSString
                          stringWithFormat:[CallStrings missedCallWithIdentityChangeNotificationBodyWithCallerName],
                          callerName]);
            break;
        }
    }
    notification.alertBody = [NSString stringWithFormat:@"☎️ %@", alertMessage];

    [self presentNotification:notification identifier:localCallId];
}

#pragma mark - Signal Messages

- (void)notifyUserForErrorMessage:(TSErrorMessage *)message inThread:(TSThread *)thread {
    OWSAssert(message);
    OWSAssert(thread);

    if (thread.isMuted) {
        return;
    }

    BOOL shouldPlaySound = [self shouldPlaySoundForNotification];

    NSString *messageDescription = message.description;

    if (([UIApplication sharedApplication].applicationState != UIApplicationStateActive) && messageDescription) {
        UILocalNotification *notification = [[UILocalNotification alloc] init];
        notification.userInfo             = @{Signal_Thread_UserInfo_Key : thread.uniqueId};
        if (shouldPlaySound) {
            notification.soundName = @"NewMessage.aifc";
        }

        NSString *alertBodyString = @"";

        NSString *authorName = [thread name];
        switch (self.notificationPreviewType) {
            case NotificationNamePreview:
            case NotificationNameNoPreview:
                alertBodyString = [NSString stringWithFormat:@"%@: %@", authorName, messageDescription];
                break;
            case NotificationNoNameNoPreview:
                alertBodyString = messageDescription;
                break;
        }
        notification.alertBody = alertBodyString;

        [[PushManager sharedManager] presentNotification:notification checkForCancel:NO];
    } else {
        if (shouldPlaySound && [Environment.preferences soundInForeground]) {
            AudioServicesPlayAlertSound(_newMessageSound);
        }
    }
}

- (void)notifyUserForIncomingMessage:(TSIncomingMessage *)message
                            inThread:(TSThread *)thread
                     contactsManager:(id<ContactsManagerProtocol>)contactsManager
{
    OWSAssert(message);
    OWSAssert(thread);
    OWSAssert(contactsManager);

    if (thread.isMuted) {
        return;
    }

    BOOL shouldPlaySound = [self shouldPlaySoundForNotification];

    NSString *messageDescription = message.description;
    NSString *senderName = [contactsManager displayNameForPhoneIdentifier:message.authorId];
    NSString *groupName = [thread.name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (groupName.length < 1) {
        groupName = NSLocalizedString(@"NEW_GROUP_DEFAULT_TITLE", @"");
    }

    if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive && messageDescription) {
        UILocalNotification *notification = [[UILocalNotification alloc] init];
        if (shouldPlaySound) {
            notification.soundName = @"NewMessage.aifc";
        }

        switch (self.notificationPreviewType) {
            case NotificationNamePreview:
                notification.category = Signal_Full_New_Message_Category;
                notification.userInfo =
                    @{Signal_Thread_UserInfo_Key : thread.uniqueId, Signal_Message_UserInfo_Key : message.uniqueId};

                if ([thread isGroupThread]) {
                    NSString *threadName = [NSString stringWithFormat:@"\"%@\"", groupName];
                    // TODO: Format parameters might change order in l10n.  We should use named parameters.
                    notification.alertBody =
                        [NSString stringWithFormat:NSLocalizedString(@"APN_MESSAGE_IN_GROUP_DETAILED", nil),
                                  senderName,
                                  threadName,
                                  messageDescription];
                } else {
                    notification.alertBody = [NSString stringWithFormat:@"%@: %@", senderName, messageDescription];
                }
                break;
            case NotificationNameNoPreview: {
                notification.userInfo = @{Signal_Thread_UserInfo_Key : thread.uniqueId};
                if ([thread isGroupThread]) {
                    notification.alertBody = [NSString
                        stringWithFormat:@"%@ \"%@\"", NSLocalizedString(@"APN_MESSAGE_IN_GROUP", nil), groupName];
                } else {
                    notification.alertBody =
                        [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"APN_MESSAGE_FROM", nil), senderName];
                }
                break;
            }
            case NotificationNoNameNoPreview:
                notification.alertBody = NSLocalizedString(@"APN_Message", nil);
                break;
            default:
                DDLogWarn(@"unknown notification preview type: %lu", (unsigned long)self.notificationPreviewType);
                notification.alertBody = NSLocalizedString(@"APN_Message", nil);
                break;
        }

        [[PushManager sharedManager] presentNotification:notification checkForCancel:YES];
    } else {
        if (shouldPlaySound && [Environment.preferences soundInForeground]) {
            AudioServicesPlayAlertSound(_newMessageSound);
        }
    }
}

- (BOOL)shouldPlaySoundForNotification
{
    @synchronized(self)
    {
        // Play no more than 2 notification sounds in a given
        // five-second window.
        const CGFloat kNotificationWindowSeconds = 5.f;
        const NSUInteger kMaxNotificationRate = 2;

        // Cull obsolete notification timestamps from the thread's notification history.
        while (self.notificationHistory.count > 0) {
            NSDate *notificationTimestamp = self.notificationHistory[0];
            CGFloat notificationAgeSeconds = fabs(notificationTimestamp.timeIntervalSinceNow);
            if (notificationAgeSeconds > kNotificationWindowSeconds) {
                [self.notificationHistory removeObjectAtIndex:0];
            } else {
                break;
            }
        }

        // Ignore notifications if necessary.
        BOOL shouldPlaySound = self.notificationHistory.count < kMaxNotificationRate;

        if (shouldPlaySound) {
            // Add new notification timestamp to the thread's notification history.
            NSDate *newNotificationTimestamp = [NSDate new];
            [self.notificationHistory addObject:newNotificationTimestamp];

            return YES;
        } else {
            DDLogDebug(@"Skipping sound for notification");
            return NO;
        }
    }
}

#pragma mark - Util

- (NotificationType)notificationPreviewType
{
    PropertyListPreferences *prefs = [Environment getCurrent].preferences;
    return prefs.notificationPreviewType;
}

- (void)presentNotification:(UILocalNotification *)notification identifier:(NSString *)identifier
{
    DispatchMainThreadSafe(^{
        // Replace any existing notification
        // e.g. when an "Incoming Call" notification gets replaced with a "Missed Call" notification.
        if (self.currentNotifications[identifier]) {
            [self cancelNotificationWithIdentifier:identifier];
        }

        [[UIApplication sharedApplication] scheduleLocalNotification:notification];
        DDLogDebug(@"%@ presenting notification with identifier: %@", self.tag, identifier);

        self.currentNotifications[identifier] = notification;
    });
}

- (void)cancelNotificationWithIdentifier:(NSString *)identifier
{
    DispatchMainThreadSafe(^{
        UILocalNotification *notification = self.currentNotifications[identifier];
        if (!notification) {
            DDLogWarn(
                @"%@ Couldn't cancel notification because none was found with identifier: %@", self.tag, identifier);
            return;
        }
        [self.currentNotifications removeObjectForKey:identifier];

        [[UIApplication sharedApplication] cancelLocalNotification:notification];
    });
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
