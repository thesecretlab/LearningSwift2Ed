//
//  InterfaceController.swift
//  Watch Extension
//
//  Created by Jon Manning on 3/11/2015.
//  Copyright © 2015 Jonathon Manning. All rights reserved.
//

import WatchKit
import Foundation

// BEGIN watch_noterow_controller
class NoteRow : NSObject {
    
    // BEGIN watch_noterow_controller_namelabel
    @IBOutlet var nameLabel: WKInterfaceLabel!
    // END watch_noterow_controller_namelabel
    
}
// END watch_noterow_controller


class NoteListInterfaceController: WKInterfaceController {

    @IBOutlet var noteListTable: WKInterfaceTable!
    
    var displayedNotes : [SessionManager.NoteInfo] = []
    
    // BEGIN watch_handle_user_activity
    override func handleUserActivity(_ userInfo: [AnyHashable: Any]?) {
        if userInfo?["editing"] as? Bool == true {
            // Start creating a note
            createNote()
            
            // Clear the user activity
            invalidateUserActivity()            
        }
    }
    // END watch_handle_user_activity
    
    // BEGIN watch_create_note
    @IBAction func createNote() {
        
        let suggestions = [
            "Awesome note!",
            "What a great test note!",
            "I love purchasing and reading books from O'Reilly Media!"
        ]
        
        self.presentTextInputController(withSuggestions: suggestions,
            allowedInputMode: WKTextInputMode.plain) {
            (results) -> Void in
            
                if let text = results?.first as? String {
                    SessionManager
                        .sharedSession
                        .createNote(text, completionHandler: { notes, error in
                        self.updateListWithNotes(notes)
                    })
                }
        }
    }
    // END watch_create_note
    
    // BEGIN watch_update_list_with_notes
    func updateListWithNotes(_ notes: [SessionManager.NoteInfo]) {
        
        // Have the notes changed? Don't do anything if not.
        if notes == self.displayedNotes {
            return
        }
        
        self.noteListTable.setNumberOfRows(notes.count, withRowType: "NoteRow")
        
        for (i, note) in notes.enumerated() {
            if let row = self.noteListTable.rowController(at: i) as? NoteRow {
                row.nameLabel.setText(note.name)
            }
        }
        
        self.displayedNotes = notes
    }
    // END watch_update_list_with_notes
    
    // BEGIN watch_list_activate
    override func willActivate() {
        SessionManager.sharedSession.updateList() { notes, error in
            self.updateListWithNotes(notes)
        }
    }
    // END watch_list_activate
    
    // BEGIN watch_list_context_for_segue
    override func contextForSegue(withIdentifier segueIdentifier: String,
        in table: WKInterfaceTable, rowIndex: Int) -> Any? {
        
        // Was this the ShowNote segue?
        if segueIdentifier == "ShowNote" {
            // Pass the URL for the selected note to the interface controller
            return SessionManager.sharedSession.notes[rowIndex].URL
        }
        
        return nil
    }
    // END watch_list_context_for_segue


}
