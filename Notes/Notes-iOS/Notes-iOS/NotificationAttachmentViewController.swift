//
//  NotificationAttachmentViewController.swift
//  Notes
//
//  Created by Jon Manning on 30/09/2015.
//  Copyright © 2015 Jonathon Manning. All rights reserved.
//

import UIKit

// BEGIN notification_vc_attachment_protocol
class NotificationAttachmentViewController: UIViewController, AttachmentViewer {
    
    var document : Document?
    var attachmentFile : FileWrapper?
// END notification_vc_attachment_protocol
    
    @IBOutlet var datePicker : UIDatePicker!

    // BEGIN notification_vc_impl
    
    // BEGIN notification_observer
    var notificationSettingsWereRegisteredObserver : AnyObject?
    // END notification_observer
    
    
    /// BEGIN notification_view_will_appear
    override func viewWillAppear(_ animated:Bool) {
        
        if let notification = self.document?.localNotification {
            let cancelButton = UIBarButtonItem(barButtonSystemItem: .trash,
                target: self, action: #selector(NotificationAttachmentViewController.clearNotificationAndClose))
            
            self.navigationItem.leftBarButtonItem = cancelButton
            
            self.datePicker.date = notification.fireDate ?? Date()
            
        } else {
            let cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel,
                target: self, action: #selector(NotificationAttachmentViewController.clearNotificationAndClose))
            self.navigationItem.leftBarButtonItem = cancelButton
            
            self.datePicker.date = Date()
        }
        
        // Now add the Done button that adds the attachment
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done,
            target: self, action: #selector(NotificationAttachmentViewController.setNotificationAndClose))
        self.navigationItem.rightBarButtonItem = doneButton

        // Register for changes to user notification settings
        notificationSettingsWereRegisteredObserver = NotificationCenter.default.addObserver(
                forName: NSNotification.Name(rawValue: NotesApplicationDidRegisterUserNotificationSettings),
                object: nil, queue: nil,
                using: { (notification) -> Void in
                    
                    if let settings = UIApplication.shared
                        .currentUserNotificationSettings ,
                        settings.types.contains(.alert) == true {
                            self.datePicker.isEnabled = true
                            self.datePicker.isUserInteractionEnabled = true
                            doneButton.isEnabled = true
                    }
            })
        
        // If the app doesn't already have access, register for access
        if let settings = UIApplication.shared
            .currentUserNotificationSettings
            , settings.types.contains(.alert) != true {
                
                let action = UIMutableUserNotificationAction()
                action.identifier = Document.alertSnoozeAction
                action.activationMode = .background
                action.title = "Snooze"
                
                let category = UIMutableUserNotificationCategory()
                category.identifier = Document.alertCategory
            
                category.setActions(
                    [action],
                    for: UIUserNotificationActionContext.default)
            
                category.setActions(
                    [action],
                    for: UIUserNotificationActionContext.minimal)
                
                let settings = UIUserNotificationSettings(types: .alert,
                                                          categories: [category])
                
                UIApplication.shared
                    .registerUserNotificationSettings(settings)
                
                self.datePicker.isEnabled = false
                self.datePicker.isUserInteractionEnabled = false
                doneButton.isEnabled = false
        }
    }
    // END notification_view_will_appear
    
    // BEGIN notification_save_and_close
    func setNotificationAndClose() {
        
        // Prepare and add the notification if the date picker
        // isn't set in the future
        let date : Date
        
        if self.datePicker.date.timeIntervalSinceNow < 5 {
            date = Date(timeIntervalSinceNow: 5)
        } else {
            date = self.datePicker.date
        }
        
        let notification = UILocalNotification()
        notification.fireDate = date
        
        notification.alertTitle = "Notes Alert"
        notification.alertBody = "Check out your document!"
        
        notification.category = Document.alertCategory
        
        self.document?.localNotification = notification
    
        self.presentingViewController?.dismiss(animated: true,
            completion: nil)
    }
    // END notification_save_and_close
    
    // BEGIN notification_clear_and_close
    func clearNotificationAndClose() {
        self.document?.localNotification = nil
        self.presentingViewController?.dismiss(animated: true,
            completion: nil)
    }
    // END notification_clear_and_close
    // END notification_vc_impl

}
