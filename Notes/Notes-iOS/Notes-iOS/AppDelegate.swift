//
//  AppDelegate.swift
//  Notes-iOS
//
//  Created by Jonathon Manning on 25/08/2015.
//  Copyright © 2015 Jonathon Manning. All rights reserved.
//

import UIKit
// BEGIN ios_watch_connectivity
import WatchConnectivity
// END ios_watch_connectivity

// BEGIN settings_notification_name
let NotesApplicationDidRegisterUserNotificationSettings
    = "NotesApplicationDidRegisterUserNotificationSettings"
// END settings_notification_name


// BEGIN ios_watch_wcsessiondelegate
extension AppDelegate : WCSessionDelegate {
    @available(iOS 9.3, *)
    public func sessionDidDeactivate(_ session: WCSession) {
        
    }
    
    @available(iOS 9.3, *)
    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        
    }
    
    @available(iOS 9.3, *)
    public func sessionDidBecomeInactive(_ session: WCSession) {
        
    }
    
    
    // BEGIN ios_watch_wcsessiondelegate_didrececivemessage
    func session(_ session: WCSession,
        didReceiveMessage message: [String : Any],
        replyHandler: @escaping ([String : Any]) -> Void) {
        
        if let messageName = message[WatchMessageTypeKey] as? String {
            
            switch messageName {
            case WatchMessageTypeListAllNotesKey:
                handleListAllNotes(replyHandler)
            case WatchMessageTypeLoadNoteKey:
                if let urlString = message[WatchMessageContentURLKey] as? String,
                    let url = URL(string: urlString) {
                    handleLoadNote(url, replyHandler: replyHandler)
                } else {
                    // If there's no URL, then fall through to the default case
                    fallthrough
                }
            case WatchMessageTypeCreateNoteKey:
                if let textForNote = message[WatchMessageContentTextKey]
                    as? String {
                    
                    handleCreateNote(textForNote, replyHandler: replyHandler)
                } else {
                    // No text provided? Fall through to the default case
                    fallthrough
                }
                
                
            default:
                // Don't know what this is, so reply with the empty dictionary
                replyHandler([:])
            }
        }
    }
    // END ios_watch_wcsessiondelegate_didrececivemessage
    
    // BEGIN ios_watch_wcsessiondelegate_handlecreatenote
    func handleCreateNote(_ text: String,
         replyHandler: @escaping ([String:Any]) -> Void) {
        
        let documentName = "Document \(arc4random()) from Watch.note"
        
        // Determine where the file should be saved locally 
        // (before moving to iCloud)
        guard let documentsFolder = FileManager.default
            .urls(for: .documentDirectory,
            in: .userDomainMask).first else {
                self.handleListAllNotes(replyHandler)
                return
        }
        
        let documentDestinationURL = documentsFolder
            .appendingPathComponent(documentName)
        
        
        guard let ubiquitousDocumentsDirectoryURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents") else {
                self.handleListAllNotes(replyHandler)
                return
        }
        
        // Prepare the document and try to save it locally
        let newDocument = Document(fileURL:documentDestinationURL)
        newDocument.text = NSAttributedString(string: text)
        
        // Try to save it locally
        newDocument.save(to: documentDestinationURL,
            for: .forCreating) { (success) -> Void in
                
                // Did the save succeed? If not, just reply with the 
                // list of notes.
                guard success == true else {
                    self.handleListAllNotes(replyHandler)
                    return
                }
                
                // Ok, it succeeded!
                
                // Move it to iCloud
                let ubiquitousDestinationURL = ubiquitousDocumentsDirectoryURL
                    .appendingPathComponent(documentName)
                
                // Perform the move to iCloud in the background
                OperationQueue().addOperation { () -> Void in
                    do {
                        try FileManager.default
                            .setUbiquitous(true,
                                itemAt: documentDestinationURL,
                                destinationURL: ubiquitousDestinationURL)
                        
                        
                    } catch let error as NSError {
                        NSLog("Error storing document in iCloud! " +
                            "\(error.localizedDescription)")
                    }
                    
                    OperationQueue.main
                        .addOperation { () -> Void in
                        // Pass back the list of everything currently in iCloud
                        self.handleListAllNotes(replyHandler)
                    }
                }
                
        }
    }
    // END ios_watch_wcsessiondelegate_handlecreatenote

    // BEGIN ios_watch_wcsessiondelegate_handlelistallnotes
    func handleListAllNotes(_ replyHandler: ([String:Any]) -> Void) {
        
        let fileManager = FileManager.default
        
        var allFiles : [URL] = []
        
        do {
            
            // Add the list of cloud documents
            if let documentsFolder = fileManager
                .url(forUbiquityContainerIdentifier: nil)?
                .appendingPathComponent("Documents", isDirectory: true)  {
                let cloudFiles = try fileManager
                    .contentsOfDirectory(atPath: documentsFolder.path)
                    .map({
                        documentsFolder.appendingPathComponent($0,
                            isDirectory: false)
                    })
                allFiles.append(contentsOf: cloudFiles)
            }
            
            // Add the list of all local documents
            
            if let localDocumentsFolder
                = fileManager.urls(for: .documentDirectory,
                    in: .userDomainMask).first {
                
                let localFiles =
                    try fileManager
                    .contentsOfDirectory(atPath: localDocumentsFolder.path)
                    .map({
                        localDocumentsFolder.appendingPathComponent($0,
                            isDirectory: false)
                    })
                allFiles.append(contentsOf: localFiles)
            }
            
            // Filter these to only those that end in ".note",
            
            let noteFiles = allFiles
                .filter({
                    $0.lastPathComponent.hasSuffix(".note")
                })
            
            // Convert this list into an array of dictionaries, each 
            // containing the note's name and URL
            let results = noteFiles.map({ url in
                
                [
                    WatchMessageContentNameKey: url.lastPathComponent,
                    WatchMessageContentURLKey: url.absoluteString
                ]
                
            })
            
            // Bundle up this into our reply dictionary
            let reply = [
                WatchMessageContentListKey: results
            ]
            
            replyHandler(reply as [String : AnyObject])
            
        } catch let error as NSError {
            // Log an error and return the empty array
            NSLog("Failed to get contents of Documents folder: \(error)")
            replyHandler([:])
        }
        
    }
    // END ios_watch_wcsessiondelegate_handlelistallnotes
    
    // BEGIN ios_watch_wcsessiondelegate_handleloadnote
    func handleLoadNote(_ url: URL,
        replyHandler: @escaping ([String:Any]) -> Void) {
        let document = Document(fileURL:url)
        document.open { success in
            
            // Ensure that we successfully opened the document
            guard success == true else {
                // If we didn't, reply with an empty dictionary and bail out
                replyHandler([:])
                return
            }
            
            let reply = [
                WatchMessageContentTextKey: document.text.string
            ]
            
            // Close; don't provide a completion handler, because
            // we've not making changes and therefore don't care
            // if a save succeeds or not
            document.close(completionHandler: nil)
            
            replyHandler(reply as [String : AnyObject])
        }
        
    }
    // END ios_watch_wcsessiondelegate_handleloadnote
}
// END ios_watch_wcsessiondelegate

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    // BEGIN home_action_type
    let createNoteActionType = "au.com.secretlab.Notes.new-note"
    // END home_action_type
    
    
    func application(_ application: UIApplication,
         didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?)
        -> Bool {
        
        // BEGIN access_to_icloud
        // Ensure we've got access to iCloud
        let backgroundQueue = OperationQueue()
        backgroundQueue.addOperation() {
            // Pass 'nil' to this method to get the URL for the first
            // iCloud container listed in the app's entitlements
            let ubiquityContainerURL = FileManager.default
                .url(forUbiquityContainerIdentifier: nil)
            print("Ubiquity container URL: \(ubiquityContainerURL)")
        }
        // END access_to_icloud
        
        // BEGIN ios_watch_did_finish_launching
        WCSession.default().delegate = self
        WCSession.default().activate()
        // END ios_watch_did_finish_launching
        
        // BEGIN home_action_launch
        // Did we launch as a result of using a shortcut option?
        if let shortcutItem = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem {
            
            // We did! Was it the 'create note' shortcut?
            if shortcutItem.type == createNoteActionType {
                // Create a new document.
                createNewDocument()
            }
            
            // Return false to indicate that 'performActionForShortcutItem' doesn't need to be called
            return false
        }
        // END home_action_launch
        
        return true
    }
    
    // BEGIN home_action_createNewDocument
    func createNewDocument() {
        
        
        // Ensure that the root view controller is a navigation controller
        guard let navigationController = self.window?.rootViewController as? UINavigationController else {
            fatalError("The root view controller is not a navigation controller!")
        }
        
        // Ensure that the navigation controller's root view controller is the Document List
        guard let documentList = navigationController.viewControllers.first as? DocumentListViewController else {
            fatalError("The navigation controller's first view controller is not a DocumentListViewController!")
        }
        
        // Move back to the root view controller
        navigationController.popToRootViewController(animated: false)
        
        // Ask the document list to create a new document
        documentList.createDocument()
    }
    // END home_action_createNewDocument
    
    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        
        if shortcutItem.type == createNoteActionType {
            createNewDocument()
            
            completionHandler(true)
        } else {
            completionHandler(false)
        }

        
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive 
        // state. This can occur for certain types of temporary interruptions 
        // (such as an incoming phone call or SMS message) or when the user 
        // quits the application and it begins the transition to the background
        // state.
        // Use this method to pause ongoing tasks, disable timers, and throttle 
        // down OpenGL ES frame rates. Games should use this method to pause the 
        // game.
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, 
        // invalidate timers, and store enough application state information to 
        // restore your application to its current state in case it is terminated 
        // later.
        // If your application supports background execution, this method is 
        // called instead of applicationWillTerminate: when the user quits.
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive 
        // state; here you can undo many of the changes made on entering the
        // background.
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the 
        // application was inactive. If the application was previously in the 
        // background, optionally refresh the user interface.
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if 
        // appropriate. See also applicationDidEnterBackground:.
    }
    
    // BEGIN open_url
    func application(_ app: UIApplication, open url: URL,
         options: [UIApplicationOpenURLOptionsKey : Any]) -> Bool {
        
        if url.scheme == "notes" {
            
            // Return to the list of documents
            if let navigationController =
                self.window?.rootViewController as? UINavigationController {
                
                navigationController.popToRootViewController(animated: false)
                
                 (navigationController.topViewController
                    as? DocumentListViewController)?.openDocumentWithPath(url.path)
            }
            
            return true
            
        }
        
        return false
    }
    // END open_url
    
    
    // BEGIN application_continue_activity
    func application(_ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([Any]?) -> Void) -> Bool {
        
        // Return to the list of documents
        if let navigationController =
            self.window?.rootViewController as? UINavigationController {
            
            navigationController.popToRootViewController(animated: false)
            
            // We're now at the list of documents; tell the restoration 
            // system that this view controller needs to be informed
            // that we're continuing the activity
            if let topViewController = navigationController.topViewController {
                restorationHandler([topViewController])
            }
            
            return true
        }
        return false
    }
    // END application_continue_activity
    
    
}

