//
//  MasterViewController.swift
//  Notes-iOS
//
//  Created by Jonathon Manning on 25/08/2015.
//  Copyright © 2015 Jonathon Manning. All rights reserved.
//

import UIKit
import CoreSpotlight

// BEGIN file_collection_view_cell
class FileCollectionViewCell : UICollectionViewCell {
    @IBOutlet weak var fileNameLabel : UILabel?
    
    @IBOutlet weak var imageView : UIImageView?
    
    // BEGIN file_collection_view_cell_delete_support
    @IBOutlet weak var deleteButton : UIButton?
    
    // BEGIN file_collection_view_cell_delete_support_editing
    func setEditing(_ editing: Bool, animated:Bool) {
        let alpha : CGFloat = editing ? 1.0 : 0.0
        if animated {
            UIView.animate(withDuration: 0.25, animations: { () -> Void in
                self.deleteButton?.alpha = alpha
            }) 
        } else {
            self.deleteButton?.alpha = alpha
        }
    }
    // END file_collection_view_cell_delete_support_editing
    
    // BEGIN file_collection_view_cell_delete_support_handler
    var deletionHander : ((Void) -> Void)?
    // END file_collection_view_cell_delete_support_handler
    
    // BEGIN file_collection_view_cell_delete_support_action
    @IBAction func deleteTapped() {
        deletionHander?()
    }
    // END file_collection_view_cell_delete_support_action
    
    // END file_collection_view_cell_delete_support
    
    // BEGIN file_collection_view_cell_rename_support_handler
    var renameHander : ((Void) -> Void)?
    
    @IBAction func renameTapped() {
        renameHander?()
    }
    // END file_collection_view_cell_rename_support_handler
    
}
// END file_collection_view_cell

// BEGIN document_list_view_controller
class DocumentListViewController: UICollectionViewController {
// END document_list_view_controller
    
    // BEGIN icloud_available
    class var iCloudAvailable : Bool {
        
        if UserDefaults.standard
            .bool(forKey: NotesUseiCloudKey) == false {
            
            return false
        }
        
        return FileManager.default.ubiquityIdentityToken != nil
    }
    // END icloud_available
    
    // BEGIN metadata_query_properties
    var queryDidFinishGatheringObserver : AnyObject?
    var queryDidUpdateObserver: AnyObject?
    
    var metadataQuery : NSMetadataQuery = {
        let metadataQuery = NSMetadataQuery()
        
        metadataQuery.searchScopes =
                [NSMetadataQueryUbiquitousDocumentsScope]
        
        metadataQuery.predicate = NSPredicate(format: "%K LIKE '*.note'",
            NSMetadataItemFSNameKey)
        metadataQuery.sortDescriptors = [
            NSSortDescriptor(key: NSMetadataItemFSContentChangeDateKey,
                ascending: false)
        ]
        
        return metadataQuery
    }()
    // END metadata_query_properties
    
    // BEGIN file_list_property
    var availableFiles : [URL] = []
    // END file_list_property
    
    // BEGIN restore_user_activity_state
    override func restoreUserActivityState(_ activity: NSUserActivity) {
        // We're being told to open a document
        
        if let url = activity.userInfo?[NSUserActivityDocumentURLKey] as? URL {
            
            // Open the document
            self.performSegue(withIdentifier: "ShowDocument", sender: url)
        }
        
        // BEGIN restore_user_activity_state_watch
        // This is coming from the watch
        if let urlString = activity
                .userInfo?[WatchHandoffDocumentURL] as? String,
            let url = URL(string: urlString) {
                // Open the document
                self.performSegue(withIdentifier: "ShowDocument", sender: url)
        }
        // END restore_user_activity_state_watch
        
        
        
        // BEGIN restore_user_activity_state_search
        // We're coming from a search result
        if let searchableItemIdentifier = activity
                .userInfo?[CSSearchableItemActivityIdentifier] as? String,
            let url = URL(string: searchableItemIdentifier) {
            // Open the document
            self.performSegue(withIdentifier: "ShowDocument", sender: url)
        }
        // END restore_user_activity_state_search
        
    }
    // END restore_user_activity_state
    
    // BEGIN doc_list_view_did_load
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // BEGIN doc_list_view_did_load_create
        let addButton = UIBarButtonItem(barButtonSystemItem: .add,
            target: self, action: #selector(DocumentListViewController.createDocument))
        self.navigationItem.rightBarButtonItem = addButton
        // END doc_list_view_did_load_create
        
        self.queryDidUpdateObserver = NotificationCenter.default
            .addObserver(forName: NSNotification.Name.NSMetadataQueryDidUpdate,
                object: metadataQuery,
                queue: OperationQueue.main) { (notification) in
                    self.queryUpdated()
        }
        self.queryDidFinishGatheringObserver = NotificationCenter.default
            .addObserver(forName: NSNotification.Name.NSMetadataQueryDidFinishGathering,
                object: metadataQuery,
                queue: OperationQueue.main) { (notification) in
                    self.queryUpdated()
        }
        
        // BEGIN doc_list_view_did_load_edit_support
        self.navigationItem.leftBarButtonItem = self.editButtonItem
        // END doc_list_view_did_load_edit_support
        
        // BEGIN prompt_for_icloud
        let hasPromptedForiCloud = UserDefaults.standard
            .bool(forKey: NotesHasPromptedForiCloudKey)
        
        if hasPromptedForiCloud == false {
            let alert = UIAlertController(title: "Use iCloud?",
                message: "Do you want to store your documents in iCloud, " +
                "or store them locally?",
                preferredStyle: UIAlertControllerStyle.alert)
            
            alert.addAction(UIAlertAction(title: "iCloud",
                style: .default,
                handler: { (action) in
                    
                UserDefaults.standard
                    .set(true, forKey: NotesUseiCloudKey)
                
                self.metadataQuery.start()
            }))
            
            
            alert.addAction(UIAlertAction(title: "Local Only", style: .default,
                handler: { (action) in
                
                UserDefaults.standard
                    .set(false, forKey: NotesUseiCloudKey)
                
                self.refreshLocalFileList()
            }))
            
            self.present(alert, animated: true, completion: nil)
            
            UserDefaults.standard
                .set(true, forKey: NotesHasPromptedForiCloudKey)
            
        } else {
            metadataQuery.start()
            refreshLocalFileList()
        }
        // END prompt_for_icloud
        
        
    }
    // END doc_list_view_did_load
    
    // BEGIN refresh_local_files
    func refreshLocalFileList() {
        
        do {
            var localFiles = try FileManager.default
                .contentsOfDirectory(
                    at: DocumentListViewController.localDocumentsDirectoryURL,
                    includingPropertiesForKeys: [URLResourceKey.nameKey],
                    options: [
                        .skipsPackageDescendants,
                        .skipsSubdirectoryDescendants
                    ]
                )
            
            localFiles = localFiles.filter({ (url) in
                return url.pathExtension == "note"
            })
            
            if (DocumentListViewController.iCloudAvailable) {
                // Move these files into iCloud
                for file in localFiles {
                    if let ubiquitousDestinationURL =
                        DocumentListViewController
                            .ubiquitousDocumentsDirectoryURL?
                            .appendingPathComponent(file.lastPathComponent) {
                                do {
                                    try FileManager.default
                                        .setUbiquitous(true,
                                                       itemAt: file,
                                                       destinationURL:
                                                        ubiquitousDestinationURL)
                                } catch let error as NSError {
                                    NSLog("Failed to move file \(file) " +
                                        "to iCloud: \(error)")
                                }
                    }
                    
                    
                    
                }
            } else {
                // Add these files to the list of files we know about
                availableFiles.append(contentsOf: localFiles)
            }

        } catch let error as NSError {
            NSLog("Failed to list local documents: \(error)")
        }
        
    }
    // END refresh_local_files
    
    // BEGIN document_list_editing
    override func setEditing(_ editing: Bool, animated: Bool) {
        
        super.setEditing(editing, animated: animated)
        
        for visibleCell in self.collectionView?.visibleCells
            as! [FileCollectionViewCell] {
                
            visibleCell.setEditing(editing, animated: animated)
        }
    }
    // END document_list_editing
    
    // BEGIN query_updated
    func queryUpdated() {
        self.collectionView?.reloadData()
        
        // Ensure that the metadata query's results can be accessed
        guard let items = self.metadataQuery.results as? [NSMetadataItem]  else {
            return
        }
        
        // Ensure that iCloud is available - if it's unavailable,
        // we shouldn't bother looking for files.
        guard DocumentListViewController.iCloudAvailable else {
            return;
        }
        
        // Clear the list of files we know about.
        availableFiles = []
        
        // Discover any local files, which don't need to be downloaded.
        refreshLocalFileList()

        for item in items {
            
            // Ensure that we can get the file URL for this item
            guard let url =
                item.value(forAttribute: NSMetadataItemURLKey) as? URL else {
                // We need to have the URL to access it, so move on
                // to the next file by breaking out of this loop
                continue
            }
            
            // Add it to the list of available files
            availableFiles.append(url)
            
            // BEGIN query_updated_download
            // Check to see if we already have the latest version downloaded
            if itemIsOpenable(url) == true {
                // We only need to download if it isn't already openable
                continue
            }
            
            // Ask the system to try to download it
            do {
                try FileManager.default
                    .startDownloadingUbiquitousItem(at: url)
                
            } catch let error as NSError {                
                // Problem! :(
                print("Error downloading item! \(error)")
                
            }
            // END query_updated_download

        }
        
        
    }
    // END query_updated
    
    // MARK: - Collection View
    
    override func numberOfSections(
        in collectionView: UICollectionView) -> Int {
            
        // We only ever have one section
        return 1
    }
    
    // BEGIN collection_view_datasource
    override func collectionView(_ collectionView: UICollectionView,
        numberOfItemsInSection section: Int) -> Int {
        
        // There are as many cells as there are items in iCloud
        return self.availableFiles.count
    }
    
    // BEGIN cellforitematindexpath
    override func collectionView(_ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        // Get our cell
        let cell = collectionView
            .dequeueReusableCell(withReuseIdentifier: "FileCell",
                for: indexPath) as! FileCollectionViewCell
        
        
        // Get this object from the list of known files
        let url = availableFiles[(indexPath as NSIndexPath).row]
            
        // Get the display name
        var fileName : AnyObject?
        do {
            try (url as NSURL).getResourceValue(&fileName, forKey: URLResourceKey.nameKey)
            
            if let fileName = fileName as? String {
                cell.fileNameLabel!.text = fileName
            }
        } catch {
            cell.fileNameLabel!.text = "Loading..."
        }
            
        // BEGIN cellforitematindexpath_quicklook
        // Get the thumbnail image, if it exists
        let thumbnailImageURL =
            url
                .appendingPathComponent(
                    NoteDocumentFileNames.QuickLookDirectory.rawValue,
                    isDirectory: true)
                .appendingPathComponent(
                    NoteDocumentFileNames.QuickLookThumbnail.rawValue,
                    isDirectory: false)
    
        if let image = UIImage(contentsOfFile: thumbnailImageURL.path) {
            cell.imageView?.image = image
        } else {
            cell.imageView?.image = nil
        }
        // END cellforitematindexpath_quicklook
        
        // BEGIN cellforitematindexpath_editing
        cell.setEditing(self.isEditing, animated: false)
        cell.deletionHander = {
            self.deleteDocumentAtURL(url)
        }
        // END cellforitematindexpath_editing
            
        // BEGIN cellforitematindexpath_renaming
        
        let labelTapRecognizer = UITapGestureRecognizer(target: cell,
                                                        action: #selector(FileCollectionViewCell.renameTapped))
        
        cell.fileNameLabel?.gestureRecognizers = [labelTapRecognizer]
        
        cell.renameHander = {
            self.renameDocumentAtURL(url)
        }
        // END cellforitematindexpath_renaming
        
        // BEGIN cellforitematindexpath_openable
        // If this cell is openable, make it fully visible, and
        // make the cell able to be touched
        if itemIsOpenable(url) {
            cell.alpha = 1.0
            cell.isUserInteractionEnabled = true
        } else {
            // But if it's not, make it semitransparent, and
            // make the cell not respond to input
            cell.alpha = 0.5
            cell.isUserInteractionEnabled = false
        }
        // END cellforitematindexpath_openable
        
        
        return cell
        
    }
    // END cellforitematindexpath
    // END collection_view_datasource
    
    // BEGIN rename_document_func
    func renameDocumentAtURL(_ url: URL) {
        
        // Create an alert box
        let renameBox = UIAlertController(title: "Rename Document",
                                          message: nil, preferredStyle: .alert)
        
        // Add a text field to it that contains its current name, sans ".note"
        renameBox.addTextField(configurationHandler: { (textField) -> Void in
            let filename = url.lastPathComponent
                .replacingOccurrences(of: ".note", with: "")
            textField.text = filename
        })
        
        // Add the cancel button, which does nothing
        renameBox.addAction(UIAlertAction(title: "Cancel",
            style: .cancel, handler: nil))
        
        // Add the rename button, which actually does the renaming
        renameBox.addAction(UIAlertAction(title: "Rename",
            style: .default) { (action) in
            
            // Attempt to construct a destination URL from 
            // the name the user provided
            if let newName = renameBox.textFields?.first?.text
                 {
                        let destinationURL = url.deletingLastPathComponent()
                            .appendingPathComponent(newName + ".note")
                        
                        let fileCoordinator =
                            NSFileCoordinator(filePresenter: nil)
                        
                        // Indicate that we intend to do writing
                        fileCoordinator.coordinate(writingItemAt: url,
                            options: [],
                            writingItemAt: destinationURL,
                            options: [],
                            error: nil,
                            byAccessor: { (origin, destination) -> Void in
                                
                                do {
                                    // Perform the actual move
                                    try FileManager.default
                                        .moveItem(at: origin,
                                            to: destination)
                                    
                                    // Remove the original URL from the file
                                    // list by filtering it out
                                    self.availableFiles =
                                        self.availableFiles.filter { $0 != url }
                                    
                                    // Add the new URL to the file list
                                    self.availableFiles.append(destination)
                                    
                                    // Refresh our collection of files
                                    self.collectionView?.reloadData()
                                } catch let error as NSError {
                                    NSLog("Failed to move \(origin) to " +
                                        "\(destination): \(error)")
                                }
                                
                        })
                        
            }
            })
        
        // Finally, present the box.
        
        self.present(renameBox, animated: true, completion: nil)
    }
    // END rename_document_func
    
    // BEGIN delete_document
    func deleteDocumentAtURL(_ url: URL) {
        
        let fileCoordinator = NSFileCoordinator(filePresenter: nil)
        fileCoordinator.coordinate(writingItemAt: url,
            options: .forDeleting, error: nil) { (urlForModifying) -> Void in
            do {
                try FileManager.default
                    .removeItem(at: urlForModifying)
                
                // Remove the URL from the list
                
                self.availableFiles = self.availableFiles.filter {
                    $0 != url
                }
                
                // Update the collection
                self.collectionView?.reloadData()
                
            } catch let error as NSError {
                let alert = UIAlertController(title: "Error deleting",
                    message: error.localizedDescription,
                    preferredStyle: UIAlertControllerStyle.alert)
                
                alert.addAction(UIAlertAction(title: "Done",
                    style: .default, handler: nil))
                
                self.present(alert,
                                           animated: true,
                                           completion: nil)
            }
        }
    }
    // END delete_document
    
    // BEGIN item_is_openable
    // Returns true if the document can be opened right now
    func itemIsOpenable(_ url:URL?) -> Bool {
        
        // Return false if item is nil
        guard let itemURL = url else {
            return false
        }
        
        // Return true if we don't have access to iCloud (which means
        // that it's not possible for it to be in conflict - we'll always have
        // the latest copy)
        if DocumentListViewController.iCloudAvailable == false {
            return true
        }
        
        // Ask the system for the download status
        var downloadStatus : AnyObject?
        do {
            try (itemURL as NSURL).getResourceValue(&downloadStatus,
                forKey: URLResourceKey.ubiquitousItemDownloadingStatusKey)
        } catch let error as NSError {
            NSLog("Failed to get downloading status for \(itemURL): \(error)")
            // If we can't get that, we can't open it
            return false
        }
        
        // Return true if this file is the most current version
        if downloadStatus as? URLUbiquitousItemDownloadingStatus
            == URLUbiquitousItemDownloadingStatus.current {
            
            return true
        } else {
            return false
        }
    }
    // END item_is_openable
    
    // BEGIN open_doc_at_path
    func openDocumentWithPath(_ path : String)  {
        
        // Build a file URL from this path
        let url = URL(fileURLWithPath: path)
        
        // Open this document
        self.performSegue(withIdentifier: "ShowDocument", sender: url)
        
    }
    // END open_doc_at_path
    
    // BEGIN documents_urls
    class var localDocumentsDirectoryURL : URL {
        return FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask).first!
    }
    
    class var ubiquitousDocumentsDirectoryURL : URL? {
        return FileManager.default
            .url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents")
    }
    // END documents_urls
    
    
    // BEGIN create_document
    func createDocument() {
        
        // Create a unique name for this new document by adding a random number
        let documentName = "Document \(arc4random()).note"
        
        // Work out where we're going to store it, temporarily
        let documentDestinationURL = DocumentListViewController
            .localDocumentsDirectoryURL
            .appendingPathComponent(documentName)
        
        // Create the document and try to save it locally
        let newDocument = Document(fileURL:documentDestinationURL)
        newDocument.save(to: documentDestinationURL,
            for: .forCreating) { (success) -> Void in
            
            if (DocumentListViewController.iCloudAvailable) {
                
                // If we have the ability to use iCloud...
                // If we successfully created it, attempt to move it to iCloud
                if success == true, let ubiquitousDestinationURL =
                    DocumentListViewController.ubiquitousDocumentsDirectoryURL?
                        .appendingPathComponent(documentName) {
                            
                    // Perform the move to iCloud in the background
                    OperationQueue().addOperation { () -> Void in
                        do {
                            try FileManager.default
                                .setUbiquitous(true,
                                    itemAt: documentDestinationURL,
                                    destinationURL: ubiquitousDestinationURL)
                            
                            OperationQueue.main
                                .addOperation { () -> Void in
                                
                                self.availableFiles
                                    .append(ubiquitousDestinationURL)
                                
                                // BEGIN create_document_open
                                // Open the document
                                self.openDocumentWithPath(ubiquitousDestinationURL.path)
                                // END create_document_open
                                
                                self.collectionView?.reloadData()
                            }
                        } catch let error as NSError {
                            NSLog("Error storing document in iCloud! " +
                                "\(error.localizedDescription)")
                        }
                    }
                }
            } else {
                // We can't save it to iCloud, so it stays in local storage.
                
                self.availableFiles.append(documentDestinationURL)
                self.collectionView?.reloadData()
                
                // BEGIN create_document_open
                // Just open it locally
                self.openDocumentWithPath(documentDestinationURL.path)
                // END create_document_open
            }
        }
    }
    // END create_document
    
    // BEGIN did_select_item_at_index_path
    override func collectionView(_ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath) {
        
        // Did we select a cell that has an item that is openable?
        let selectedItem = availableFiles[(indexPath as NSIndexPath).row]
            
        if itemIsOpenable(selectedItem) {
            self.performSegue(withIdentifier: "ShowDocument", sender: selectedItem)
        }
        
    }
    // END did_select_item_at_index_path

    // BEGIN prepare_for_segue_list
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        // If the segue is "ShowDocument" and the destination view controller
        // is a DocumentViewController...
        if segue.identifier == "ShowDocument",
            let documentVC = segue.destination
                as? DocumentViewController
        {
         
            // If it's a URL we can open...
            if let url = sender as? URL {
                // Provide the url to the view controller
                documentVC.documentURL = url
            } else {
                // it's something else, oh no!
                fatalError("ShowDocument segue was called with an " +
                    "invalid sender of type \(type(of: sender))")
            }
            
            
        }
    }
    // END prepare_for_segue_list
    
}

