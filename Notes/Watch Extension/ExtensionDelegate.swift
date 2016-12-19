//
//  ExtensionDelegate.swift
//  Watch Extension
//
//  Created by Jon Manning on 3/11/2015.
//  Copyright © 2015 Jonathon Manning. All rights reserved.
//

import WatchKit
// BEGIN watch_imports
import WatchConnectivity
// END watch_imports

// BEGIN watch_session_manager
class SessionManager : NSObject, WCSessionDelegate {
    
    
    
    
    // BEGIN watch_session_manager_noteinfo
    struct NoteInfo : Equatable {
        var name : String
        var URL : Foundation.URL?
        
        init(dictionary:[String:AnyObject]) {
            
            let name
                = dictionary[WatchMessageContentNameKey] as? String
                    ?? "(no name)"
            
            self.name = name
            
            if let URLString = dictionary[WatchMessageContentURLKey] as? String {
                self.URL = Foundation.URL(string: URLString)
            }
            
        }
        
        static func == (lhs: NoteInfo, rhs: NoteInfo) -> Bool {
            return lhs.name == rhs.name && lhs.URL == rhs.URL
        }
    }
    // END watch_session_manager_noteinfo
    
    // BEGIN watch_session_manager_noteinfo_list
    var notes : [NoteInfo] = []
    // END watch_session_manager_noteinfo_list
    
    
    // BEGIN watch_session_manager_singleton
    static let sharedSession = SessionManager()
    // END watch_session_manager_singleton
    
    // BEGIN watch_session_manager_singleton_init
    var session : WCSession { return WCSession.default() }
    
    override init() {
        super.init()
        session.delegate = self
        session.activate()
    }
    // END watch_session_manager_singleton_init
    
    // BEGIN watch_session_manager_activationdidcomplete
    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        
        // Either the session was activated, or error != nil.
        // Call each task, passing the current value of error.
        for task in deferredTasks {
            task(error)
        }
        
        // Clear the list.
        deferredTasks = []
    
    }
    // END watch_session_manager_activationdidcomplete
    
    // BEGIN watch_session_manager_deferred_tasks_variables
    // To save us some typing, we'll define a type called
    // 'DeferredSessionTask', which is a closure that accepts an 
    // optional error and returns nothing
    typealias DeferredSessionTask = (Error?) -> Void
    
    // The 'deferredTasks' array is a list of all tasks that are 
    // waiting for the session to activate
    var deferredTasks : [DeferredSessionTask] = []
    // END watch_session_manager_deferred_tasks_variables
    
    // BEGIN watch_session_manager_deferred_tasks_method
    // Runs a closure when the session becomes active. If the session is
    // already active, the closure is run immediately.
    func runTaskWhenSessionActive(completionBlock: @escaping DeferredSessionTask) {
        
        // If the session is already active, run the block immediately with no error
        if session.activationState == .activated {
            completionBlock(nil)
        } else {
            // Otherwise, add this task to the list, and request that the session activate
            deferredTasks.append(completionBlock)
            session.activate()
        }
    }
    // END watch_session_manager_deferred_tasks_method

    
    // BEGIN watch_session_manager_create_note
    func createNote(_ text:String,
         completionHandler: @escaping ([NoteInfo], Error?)->Void) {
        
        let message = [
            WatchMessageTypeKey : WatchMessageTypeCreateNoteKey,
            WatchMessageContentTextKey : text
        ]
        
        self.runTaskWhenSessionActive { (error) in
            
            if error != nil {
                completionHandler([], error)
                return
            }
            
            self.session.sendMessage(message, replyHandler: {
                reply in
                
                self.updateLocalNoteListWithReply(reply)
                
                completionHandler(self.notes, nil)
                
            }, errorHandler: {
                error in
                
                completionHandler([], error)
            })
        }
        
        
    }
    // END watch_session_manager_create_note
    
    // BEGIN watch_session_manager_update_local_note_list
    func updateLocalNoteListWithReply(_ reply:[String:Any]) {
        
        // Did we receive a dictionary in the reply?
        if let noteList = reply[WatchMessageContentListKey]
            as? [[String:AnyObject]] {
            
            // Convert all dictionaries to notes
            self.notes = noteList.map({ (dict) -> NoteInfo in
                return NoteInfo(dictionary: dict)
            })
            
        }
    }
    // END watch_session_manager_update_local_note_list
    
    // BEGIN watch_session_manager_update_list
    func updateList(_ completionHandler: @escaping ([NoteInfo], NSError?)->Void) {
        
        let message = [
            WatchMessageTypeKey : WatchMessageTypeListAllNotesKey
        ]
        
        self.runTaskWhenSessionActive { (error) in
            
            if error != nil {
                completionHandler([], error as NSError?)
                return
            }
            
            self.session.sendMessage(message, replyHandler: {
                reply in
                
                self.updateLocalNoteListWithReply(reply as [String : AnyObject])
                
                completionHandler(self.notes, nil)
                
            }, errorHandler: { error in
                print("Error! \(error)")
                completionHandler([], error as NSError?)
                
            })
        }
        
        
    }
    // END watch_session_manager_update_list
    
    // BEGIN watch_session_manager_load_note
    func loadNote(_ noteURL: URL, completionHandler: @escaping (String?, Error?) -> Void) {
        
        let message = [
            WatchMessageTypeKey: WatchMessageTypeLoadNoteKey,
            WatchMessageContentURLKey: noteURL.absoluteString
        ]
        
        self.runTaskWhenSessionActive { (error) in
            if error != nil {
                completionHandler(nil, error)
                return
            }
            
            self.session.sendMessage(message, replyHandler: {
                reply in
                
                let text = reply[WatchMessageContentTextKey] as? String
                
                completionHandler(text, nil)
            },
                                errorHandler: { error in
                                    completionHandler(nil, error)
            })
        }
        
        
        
    }
    // END watch_session_manager_load_note
    
    
}
// END watch_session_manager

class ExtensionDelegate: NSObject, WKExtensionDelegate {

    func applicationDidFinishLaunching() {
        // Perform any final initialization of your application.
        
        
    }

    func applicationDidBecomeActive() {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        
        
    }

    func applicationWillResignActive() {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, etc.
    }

}
