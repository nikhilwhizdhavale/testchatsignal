//
//  Copyright (c) 2017 Open Whisper Systems. All rights reserved.
//

import Foundation

@objc
class ProfileFetcherJob: NSObject {

    let TAG = "[ProfileFetcherJob]"

    let networkManager: TSNetworkManager
    let storageManager: TSStorageManager

    let thread: TSThread

    // This property is only accessed on the main queue.
    static var fetchDateMap = [String: Date]()

    public class func run(thread: TSThread, networkManager: TSNetworkManager) {
        ProfileFetcherJob(thread: thread, networkManager: networkManager).run()
    }

    init(thread: TSThread, networkManager: TSNetworkManager) {
        self.networkManager = networkManager
        self.storageManager = TSStorageManager.shared()

        self.thread = thread
    }

    public func run() {
        AssertIsOnMainThread()

        DispatchQueue.main.async {
            for recipientId in self.thread.recipientIdentifiers {
                self.getProfile(recipientId: recipientId)
            }
        }
    }

    public func getProfile(recipientId: String, remainingRetries: Int = 3) {

        if let lastDate = ProfileFetcherJob.fetchDateMap[recipientId] {
            let lastTimeInterval = fabs(lastDate.timeIntervalSinceNow)
            // Don't check a profile more often than every N minutes.
            //
            // Only throttle profile fetch in production builds in order to
            // facilitate debugging.
            let kGetProfileMaxFrequencySeconds = _isDebugAssertConfiguration() ? 0 : 60.0 * 5.0
            guard lastTimeInterval > kGetProfileMaxFrequencySeconds else {
                Logger.info("\(self.TAG) skipping getProfile: \(recipientId), lastTimeInterval: \(lastTimeInterval)")
                return
            }
        }
        ProfileFetcherJob.fetchDateMap[recipientId] = Date()

        Logger.error("\(self.TAG) getProfile: \(recipientId)")

        let request = OWSGetProfileRequest(recipientId: recipientId)

        self.networkManager.makeRequest(
            request,
            success: { (_: URLSessionDataTask?, responseObject: Any?) -> Void in
                guard let profileResponse = SignalServiceProfile(recipientId: recipientId, rawResponse: responseObject) else {
                    Logger.error("\(self.TAG) response object had unexpected content")
                    assertionFailure("\(self.TAG) response object had unexpected content")
                    return
                }

                self.processResponse(signalServiceProfile: profileResponse)
        },
            failure: { (_: URLSessionDataTask?, error: Error?) in
                guard let error = error else {
                    Logger.error("\(self.TAG) error in \(#function) was surpringly nil. sheesh rough day.")
                    assertionFailure("\(self.TAG) error in \(#function) was surpringly nil. sheesh rough day.")
                    return
                }

                Logger.error("\(self.TAG) failed to fetch profile for recipient: \(recipientId) with error: \(error)")

                if remainingRetries > 1 {
                    DispatchQueue.global().async {
                        self.getProfile(recipientId: recipientId, remainingRetries:remainingRetries - 1)
                    }
                }
        })
    }

    private func processResponse(signalServiceProfile: SignalServiceProfile) {
        Logger.debug("\(TAG) in \(#function) for \(signalServiceProfile)")

        verifyIdentityUpToDateAsync(recipientId: signalServiceProfile.recipientId, latestIdentityKey: signalServiceProfile.identityKey)

        // Eventually we'll want to do more things with new SignalServiceProfile fields here.
    }

    private func verifyIdentityUpToDateAsync(recipientId: String, latestIdentityKey: Data) {
        OWSDispatch.sessionStoreQueue().async {
            if OWSIdentityManager.shared().identityKey(forRecipientId: recipientId) == nil {
                // first time use, do nothing, since there's no change.
                return
            }

            if OWSIdentityManager.shared().saveRemoteIdentity(latestIdentityKey, recipientId: recipientId) {
                Logger.info("\(self.TAG) updated identity key with fetched profile for recipient: \(recipientId)")
                self.storageManager.archiveAllSessions(forContact: recipientId)
            } else {
                // no change in identity.
            }
        }
    }
}

struct SignalServiceProfile {
    let TAG = "[SignalServiceProfile]"

    public let recipientId: String
    public let identityKey: Data

    init?(recipientId: String, rawResponse: Any?) {
        self.recipientId = recipientId

        guard let responseDict = rawResponse as? [String: Any?] else {
            Logger.error("\(TAG) unexpected type: \(String(describing: rawResponse))")
            return nil
        }

        guard let identityKeyString = responseDict["identityKey"] as? String else {
            Logger.error("\(TAG) missing identity key: \(String(describing: rawResponse))")
            return nil
        }

        guard let identityKeyWithType = Data(base64Encoded: identityKeyString) else {
            Logger.error("\(TAG) unable to parse identity key: \(identityKeyString)")
            return nil
        }

        let kIdentityKeyLength = 33
        guard identityKeyWithType.count == kIdentityKeyLength else {
            Logger.error("\(TAG) malformed key \(identityKeyString) with decoded length: \(identityKeyWithType.count)")
            return nil
        }

        // `removeKeyType` is an objc category method only on NSData, so temporarily cast.
        self.identityKey = (identityKeyWithType as NSData).removeKeyType() as Data
    }
}
