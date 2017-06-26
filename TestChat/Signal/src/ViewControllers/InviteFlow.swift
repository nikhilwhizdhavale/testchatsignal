//  Created by Michael Kirk on 11/18/16.
//  Copyright © 2016 Open Whisper Systems. All rights reserved.

import Foundation
import Social
import ContactsUI
import MessageUI

@objc(OWSInviteFlow)
class InviteFlow: NSObject, MFMessageComposeViewControllerDelegate, MFMailComposeViewControllerDelegate, ContactsPickerDelegate {
    enum Channel {
        case message, mail, twitter
    }

    let TAG = "[ShareActions]"

    let installUrl = "https://signal.org/install/"
    let homepageUrl = "https://whispersystems.org"

    let actionSheetController: UIAlertController
    let presentingViewController: UIViewController
    let contactsManager: OWSContactsManager

    var channel: Channel?

    required init(presentingViewController: UIViewController, contactsManager: OWSContactsManager) {
        self.presentingViewController = presentingViewController
        self.contactsManager = contactsManager
        actionSheetController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        super.init()

        actionSheetController.addAction(dismissAction())
        
        if #available(iOS 9.0, *) {
            if let messageAction = messageAction() {
                actionSheetController.addAction(messageAction)
            }

            if let mailAction = mailAction() {
                actionSheetController.addAction(mailAction)
            }
        }

        if let tweetAction = tweetAction() {
            actionSheetController.addAction(tweetAction)
        }
    }

    // MARK: Twitter

    func canTweet() -> Bool {
        return SLComposeViewController.isAvailable(forServiceType: SLServiceTypeTwitter)
    }

    func tweetAction() -> UIAlertAction? {
        guard canTweet()  else {
            Logger.info("\(TAG) Twitter not supported.")
            return nil
        }

        guard let twitterViewController = SLComposeViewController(forServiceType: SLServiceTypeTwitter) else {
            Logger.error("\(TAG) unable to build twitter controller.")
            return nil
        }

        let tweetString = NSLocalizedString("SETTINGS_INVITE_TWITTER_TEXT", comment:"content of tweet when inviting via twitter")
        twitterViewController.setInitialText(tweetString)

        let tweetUrl = URL(string: installUrl)
        twitterViewController.add(tweetUrl)
        twitterViewController.add(#imageLiteral(resourceName: "twitter_sharing_image"))

        let tweetTitle = NSLocalizedString("SHARE_ACTION_TWEET", comment:"action sheet item")
        return UIAlertAction(title: tweetTitle, style: .default) { action in
            Logger.debug("\(self.TAG) Chose tweet")

            self.presentingViewController.present(twitterViewController, animated: true, completion: nil)
        }
    }

    func dismissAction() -> UIAlertAction {
        return UIAlertAction(title: NSLocalizedString("DISMISS_BUTTON_TEXT", comment:""), style: .cancel)
    }

    // MARK: ContactsPickerDelegate

    @available(iOS 9.0, *)
    func contactsPicker(_: ContactsPicker, didSelectMultipleContacts contacts: [Contact]) {
        Logger.debug("\(TAG) didSelectContacts:\(contacts)")

        guard let inviteChannel = channel else {
            Logger.error("\(TAG) unexpected nil channel after returning from contact picker.")
            return
        }

        switch inviteChannel {
        case .message:
            let phoneNumbers: [String] = contacts.map { $0.userTextPhoneNumbers.first }.filter { $0 != nil }.map { $0! }
            sendSMSTo(phoneNumbers: phoneNumbers)
        case .mail:
            let recipients: [String] = contacts.map { $0.emails.first }.filter { $0 != nil }.map { $0! }
            sendMailTo(emails: recipients)
        default:
            Logger.error("\(TAG) unexpected channel after returning from contact picker: \(inviteChannel)")
        }
    }

    @available(iOS 9.0, *)
    func contactsPicker(_: ContactsPicker, shouldSelectContact contact: Contact) -> Bool {
        guard let inviteChannel = channel else {
            Logger.error("\(TAG) unexpected nil channel in contact picker.")
            return true
        }

        switch inviteChannel {
        case .message:
            return contact.userTextPhoneNumbers.count > 0
        case .mail:
            return contact.emails.count > 0
        default:
            Logger.error("\(TAG) unexpected channel after returning from contact picker: \(inviteChannel)")
        }
        return true
    }

    // MARK: SMS

    @available(iOS 9.0, *)
    func messageAction() -> UIAlertAction? {
        guard MFMessageComposeViewController.canSendText() else {
            Logger.info("\(TAG) Device cannot send text")
            return nil
        }

        let messageTitle = NSLocalizedString("SHARE_ACTION_MESSAGE", comment: "action sheet item to open native messages app")
        return UIAlertAction(title: messageTitle, style: .default) { action in
            Logger.debug("\(self.TAG) Chose message.")
            self.channel = .message
            let picker = ContactsPicker(delegate: self, multiSelection: true, subtitleCellType: .phoneNumber)            
            let navigationController = UINavigationController(rootViewController: picker)
            self.presentingViewController.present(navigationController, animated: true)
        }
    }

    func sendSMSTo(phoneNumbers: [String]) {
        self.presentingViewController.dismiss(animated: true) {
            if #available(iOS 10.0, *) {
                // iOS10 message compose view doesn't respect some system appearence attributes.
                // Specifically, the title is white, but the navbar is gray.
                // So, we have to set system appearence before init'ing the message compose view controller in order
                // to make its colors legible.
                // Then we have to be sure to set it back in the ComposeViewControllerDelegate callback.
                UIUtil.applyDefaultSystemAppearence()
            }
            let messageComposeViewController = MFMessageComposeViewController()
            messageComposeViewController.messageComposeDelegate = self
            messageComposeViewController.recipients = phoneNumbers

            let inviteText = NSLocalizedString("SMS_INVITE_BODY", comment:"body sent to contacts when inviting to Install Signal")
            messageComposeViewController.body = inviteText.appending(" \(self.installUrl)")
            self.presentingViewController.navigationController?.present(messageComposeViewController, animated:true)
        }
    }

    // MARK: MessageComposeViewControllerDelegate

    func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
        // Revert system styling applied to make messaging app legible on iOS10.
        UIUtil.applySignalAppearence()
        self.presentingViewController.dismiss(animated: true, completion: nil)

        switch result {
        case .failed:
            let warning = UIAlertController(title: nil, message: NSLocalizedString("SEND_INVITE_FAILURE", comment:"Alert body after invite failed"), preferredStyle: .alert)
            warning.addAction(UIAlertAction(title: NSLocalizedString("DISMISS_BUTTON_TEXT", comment:""), style: .default, handler: nil))
            self.presentingViewController.present(warning, animated: true, completion: nil)
        case .sent:
            Logger.debug("\(self.TAG) user successfully invited their friends via SMS.")
        case .cancelled:
            Logger.debug("\(self.TAG) user cancelled message invite")
        }
    }

    // MARK: Mail

    @available(iOS 9.0, *)
    func mailAction() -> UIAlertAction? {
        guard MFMailComposeViewController.canSendMail() else {
            Logger.info("\(TAG) Device cannot send mail")
            return nil
        }

        let mailActionTitle = NSLocalizedString("SHARE_ACTION_MAIL", comment: "action sheet item to open native mail app")
        return UIAlertAction(title: mailActionTitle, style: .default) { action in
            Logger.debug("\(self.TAG) Chose mail.")
            self.channel = .mail

            let picker = ContactsPicker(delegate: self, multiSelection: true, subtitleCellType: .email)
            let navigationController = UINavigationController(rootViewController: picker)
            self.presentingViewController.present(navigationController, animated: true)
        }
    }

    @available(iOS 9.0, *)
    func sendMailTo(emails recipientEmails: [String]) {
        let mailComposeViewController = MFMailComposeViewController()
        mailComposeViewController.mailComposeDelegate = self

        mailComposeViewController.setBccRecipients(recipientEmails)

        let subject = NSLocalizedString("EMAIL_INVITE_SUBJECT", comment:"subject of email sent to contacts when inviting to install Signal")
        let bodyFormat = NSLocalizedString("EMAIL_INVITE_BODY", comment:"body of email sent to contacts when inviting to install Signal. Embeds {{link to install Signal}} and {{link to WhisperSystems home page}}")
        let body = String.init(format: bodyFormat, installUrl, homepageUrl)
        mailComposeViewController.setSubject(subject)
        mailComposeViewController.setMessageBody(body, isHTML: false)

        self.presentingViewController.dismiss(animated: true) {
            self.presentingViewController.navigationController?.present(mailComposeViewController, animated:true)  {
                UIUtil.applySignalAppearence();
            }
        }
    }

    // MARK: MailComposeViewControllerDelegate

    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        self.presentingViewController.dismiss(animated: true, completion: nil)

        switch result {
        case .failed:
            let warning = UIAlertController(title: nil, message: NSLocalizedString("SEND_INVITE_FAILURE", comment:"Alert body after invite failed"), preferredStyle: .alert)
            warning.addAction(UIAlertAction(title: NSLocalizedString("DISMISS_BUTTON_TEXT", comment:""), style: .default, handler: nil))
            self.presentingViewController.present(warning, animated: true, completion: nil)
        case .sent:
            Logger.debug("\(self.TAG) user successfully invited their friends via mail.")
        case .saved:
            Logger.debug("\(self.TAG) user saved mail invite.")
        case .cancelled:
            Logger.debug("\(self.TAG) user cancelled mail invite.")
        }
    }

}
