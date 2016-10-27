//
//  Document.swift
//  Notes
//
//  Created by Jonathon Manning on 24/08/2015.
//  Copyright © 2015 Jonathon Manning. All rights reserved.
//

import Cocoa
import MapKit
import AddressBook
import CoreLocation
import QuickLook
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

fileprivate func >= <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l >= r
  default:
    return !(lhs < rhs)
  }
}


// BEGIN filewrapper_icon
extension FileWrapper {
    
    dynamic var fileExtension : String? {
        return self.preferredFilename?.components(separatedBy: ".").last
    }
    
    dynamic var thumbnailImage : NSImage {
        
        if let fileExtension = self.fileExtension {
            return NSWorkspace.shared().icon(forFileType: fileExtension)
        } else {
            return NSWorkspace.shared().icon(forFileType: "")
        }
    }
    
    func conformsToType(_ type: CFString) -> Bool {
        
        // Get the extension of this file
        guard let fileExtension = self.fileExtension else {
                // If we can't get a file extension,
                // assume that it doesn't conform
                return false
        }
        
        // Get the file type of the attachment based on its extension
        guard let fileType = UTTypeCreatePreferredIdentifierForTag(
            kUTTagClassFilenameExtension, fileExtension as CFString, nil)?
            .takeRetainedValue() else {
                // If we can't figure out the file type
                // from the extension, it also doesn't conform
                return false
        }
        
        // Ask the system if this file type conforms to the provided type
        return UTTypeConformsTo(fileType, type)
    }
}
// END filewrapper_icon

class Document: NSDocument {
    
    // BEGIN text_property
    // Main text content
    var text : NSAttributedString = NSAttributedString()
    // END text_property
    
    // Directory file wrapper
    // BEGIN document_file_wrapper
    var documentFileWrapper = FileWrapper(directoryWithFileWrappers: [:])
    // END document_file_wrapper
    
    @IBOutlet var attachmentsList : NSCollectionView!
    
    // Attachments
    // BEGIN attached_files_property
    dynamic var attachedFiles : [FileWrapper]? {
        if let attachmentsFileWrappers =
            self.attachmentsDirectoryWrapper?.fileWrappers {
                
            let attachments = Array(attachmentsFileWrappers.values)
            
            return attachments
                
        } else {
            return nil
        }
    }
    // END attached_files_property
    
    // BEGIN attachments_directory
    fileprivate var attachmentsDirectoryWrapper : FileWrapper? {
        
        guard let fileWrappers = self.documentFileWrapper.fileWrappers else {
            NSLog("Attempting to access document's contents, but none found!")
            return nil
        }
        
        var attachmentsDirectoryWrapper =
            fileWrappers[NoteDocumentFileNames.AttachmentsDirectory.rawValue]
        
        if attachmentsDirectoryWrapper == nil {
            
            attachmentsDirectoryWrapper =
                FileWrapper(directoryWithFileWrappers: [:])
            
            attachmentsDirectoryWrapper?.preferredFilename =
                NoteDocumentFileNames.AttachmentsDirectory.rawValue
            
            self.documentFileWrapper.addFileWrapper(attachmentsDirectoryWrapper!)
        }
        
        return attachmentsDirectoryWrapper
    }
    // END attachments_directory

    override class func autosavesInPlace() -> Bool {
        return true
    }

    // BEGIN osx_window_nib_name
    override var windowNibName: String? {
        //- Returns the nib file name of the document
        //- If you need to use a subclass of NSWindowController or if your 
        // document supports multiple NSWindowControllers, you should remove 
        // this property and override -makeWindowControllers instead.
        return "Document"
    }
    // END osx_window_nib_name
    
    // BEGIN did_load_nib
    override func windowControllerDidLoadNib(_ windowController:
        NSWindowController) {
        
        self.attachmentsList.register(forDraggedTypes: [NSURLPboardType])
    }
    // END did_load_nib
    
    // BEGIN read_from_file_wrapper
    override func read(from fileWrapper: FileWrapper,
        ofType typeName: String) throws {
        
        // Ensure that we have additional file wrappers in this file wrapper
        guard let fileWrappers = fileWrapper.fileWrappers else {
            throw err(.cannotLoadFileWrappers)
        }
        
        // Ensure that we can access the document text
        guard let documentTextData =
            fileWrappers[NoteDocumentFileNames.TextFile.rawValue]?
                .regularFileContents else {
            throw err(.cannotLoadText)
        }
        
        // BEGIN error_example
        // Load the text data as RTF
        guard let documentText = NSAttributedString(rtf: documentTextData,
            documentAttributes: nil) else {
            throw err(.cannotLoadText)
        }
        // END error_example
        
        // Keep the text in memory
        self.documentFileWrapper = fileWrapper
        
        self.text = documentText
        
    }
    // END read_from_file_wrapper
    
    // BEGIN file_wrapper_of_type
    override func fileWrapper(ofType typeName: String) throws -> FileWrapper {
        
        // BEGIN file_wrapper_of_type_rtf_load
        let textRTFData = try self.text.data(
            from: NSRange(0..<self.text.length),
            documentAttributes: [
                NSDocumentTypeDocumentAttribute: NSRTFTextDocumentType
            ]
        )
        // END file_wrapper_of_type_rtf_load
        
        // If the current document file wrapper already contains a
        // text file, remove it - we'll replace it with a new one
        if let oldTextFileWrapper = self.documentFileWrapper
            .fileWrappers?[NoteDocumentFileNames.TextFile.rawValue] {
            self.documentFileWrapper.removeFileWrapper(oldTextFileWrapper)
        }
        
        // BEGIN file_wrapper_of_type_quicklook
        // Create the QuickLook folder
        
        let thumbnailImageData =
            self.iconImageDataWithSize(CGSize(width: 512, height: 512))!
        let thumbnailWrapper =
            FileWrapper(regularFileWithContents: thumbnailImageData)
        
        let quicklookPreview =
            FileWrapper(regularFileWithContents: textRTFData)
        
        let quickLookFolderFileWrapper =
            FileWrapper(directoryWithFileWrappers: [
            NoteDocumentFileNames.QuickLookTextFile.rawValue: quicklookPreview,
            NoteDocumentFileNames.QuickLookThumbnail.rawValue: thumbnailWrapper
            ])
        
        quickLookFolderFileWrapper.preferredFilename
            = NoteDocumentFileNames.QuickLookDirectory.rawValue
        
        // Remove the old QuickLook folder if it existed
        if let oldQuickLookFolder = self.documentFileWrapper
            .fileWrappers?[NoteDocumentFileNames.QuickLookDirectory.rawValue] {
            self.documentFileWrapper.removeFileWrapper(oldQuickLookFolder)
        }
        
        // Add the new QuickLook folder
        self.documentFileWrapper.addFileWrapper(quickLookFolderFileWrapper)
        // END file_wrapper_of_type_quicklook
        
        // Save the text data into the file
        self.documentFileWrapper.addRegularFile(
            withContents: textRTFData,
            preferredFilename: NoteDocumentFileNames.TextFile.rawValue
        )
        
        // Return the main document's file wrapper - this is what will
        // be saved on disk
        return self.documentFileWrapper
    }
    // END file_wrapper_of_type

    // BEGIN popover
    var popover : NSPopover?
    // END popover


    // BEGIN add_attachment_method
    @IBAction func addAttachment(_ sender: NSButton) {
        
        if let viewController = AddAttachmentViewController(
            nibName:"AddAttachmentViewController", bundle:Bundle.main
            ) {
            
            // BEGIN add_attachment_method_delegate
            viewController.delegate = self
            // END add_attachment_method_delegate
            
            self.popover = NSPopover()
            
            self.popover?.behavior = .transient
            
            self.popover?.contentViewController = viewController
            
            self.popover?.show(relativeTo: sender.bounds,
                of: sender, preferredEdge: NSRectEdge.maxY)
        }
        
    }
    // END add_attachment_method
    
    
    
    // BEGIN add_attachment_at_url
    func addAttachmentAtURL(_ url:URL) throws {
        
        guard attachmentsDirectoryWrapper != nil else {
            throw err(.cannotAccessAttachments)
        }
        
        self.willChangeValue(forKey: "attachedFiles")
        
        let newAttachment = try FileWrapper(url: url,
            options: FileWrapper.ReadingOptions.immediate)
        
        attachmentsDirectoryWrapper?.addFileWrapper(newAttachment)
        
        self.updateChangeCount(.changeDone)
        self.didChangeValue(forKey: "attachedFiles")
    }
    // END add_attachment_at_url
    
}

// BEGIN document_addattachmentdelegate_extension
extension Document : AddAttachmentDelegate {
    
    // BEGIN document_addattachmentdelegate_extension_impl
    // BEGIN add_file
    func addFile() {
        
        let panel = NSOpenPanel()
        
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        
        panel.begin { (result) -> Void in
            if result == NSModalResponseOK,
                let resultURL = panel.urls.first {
            
                do {
                    // We were given a URL - copy it in!
                    try self.addAttachmentAtURL(resultURL)
                    
                    // Refresh the attachments list
                    self.attachmentsList?.reloadData()
                    
                } catch let error as NSError {
                    
                    // There was an error adding the attachment.
                    // Show the user!
                    
                    // Try to get a window to present a sheet in
                    if let window = self.windowForSheet {
                        
                        // Present the error in a sheet
                        NSApp.presentError(error,
                            modalFor: window,
                            delegate: nil,
                            didPresent: nil,
                            contextInfo: nil)
                        
                        
                    } else {
                        // No window, so present it in a dialog box
                        NSApp.presentError(error)
                    }
                }
            }
        }
        
        
    }
    // END add_file
    // END document_addattachmentdelegate_extension_impl
}
// END document_addattachmentdelegate_extension

// BEGIN collectionview_dragndrop
extension Document : NSCollectionViewDelegate {
    
    /*
    public func collectionView(_ collectionView: NSCollectionView,
                               validateDrop draggingInfo: NSDraggingInfo,
                               proposedIndexPath proposedDropIndexPath: AutoreleasingUnsafeMutablePointer<NSIndexPath>,
                               dropOperation proposedDropOperation: UnsafeMutablePointer<NSCollectionViewDropOperation>) -> NSDragOperation*/
    
    func collectionView(_ collectionView: NSCollectionView,
        validateDrop draggingInfo: NSDraggingInfo,
        proposedIndexPath proposedDropIndexPath:
            AutoreleasingUnsafeMutablePointer<NSIndexPath>,
        dropOperation proposedDropOperation:
            UnsafeMutablePointer<NSCollectionViewDropOperation>)
        -> NSDragOperation {
            
        // Indicate to the user that if they release the mouse button,
        // it will "copy" whatever they're dragging.
        return NSDragOperation.copy
    }
    
    func collectionView(_ collectionView: NSCollectionView,
        acceptDrop draggingInfo: NSDraggingInfo,
        indexPath: IndexPath,
        dropOperation: NSCollectionViewDropOperation) -> Bool {
            
        // Get the pasteboard that contains the info the user dropped
        let pasteboard = draggingInfo.draggingPasteboard()
        
        // We need to check to see if the pasteboard contains a URL.
        // If it does, we also need to create the URL from the
        // pasteboard contents. The initialiser for this is in the
        // NSURL type (not URL!), so we use that, and then convert
        // it to URL.
        
        // If the pasteboard contains a URL, and we can get that URL...
        if pasteboard.types?.contains(NSURLPboardType) == true,
            
            let url = NSURL(from: pasteboard) as? URL
        {
            // Then attempt to add that as an attachment!
            do {
                // Add it to the document
                try self.addAttachmentAtURL(url)
                
                // Reload the attachments list to display it
                attachmentsList.reloadData()
                
                // It succeeded!
                return true
            } catch let error as NSError {
                
                // Uhoh. Present the error in a dialog box.
                self.presentError(error)
                
                // It failed, so tell the system to animate the
                // dropped item back to where it came from
                return false
            }
            
        }
        
        return false
    }
    
}
// END collectionview_dragndrop

// BEGIN collectionview_datasource
extension Document : NSCollectionViewDataSource {
    
    // BEGIN collectionview_datasource_numberofitems
    func collectionView(_ collectionView: NSCollectionView,
        numberOfItemsInSection section: Int) -> Int {
            
        // The number of items is equal to the number of
        // attachments we have. If for some reason we can't
        // access attachedFiles, we have zero items.
        return self.attachedFiles?.count ?? 0
    }
    // END collectionview_datasource_numberofitems
    
    // BEGIN collectionview_datasource_item
    func collectionView(_ collectionView: NSCollectionView,
        itemForRepresentedObjectAt indexPath: IndexPath)
        -> NSCollectionViewItem {
            
        // Get the attachment that this cell should represent
        let attachment = self.attachedFiles![(indexPath as NSIndexPath).item]
        
        // Get the cell itself
        let item = collectionView
            .makeItem(withIdentifier: "AttachmentCell", for: indexPath)
            as! AttachmentCell
        
        // Display the image and file extension in the ecell
        item.imageView?.image = attachment.thumbnailImage
        item.textField?.stringValue = attachment.fileExtension ?? ""
        
        // BEGIN collectionview_datasource_item_delegate
        // Make this cell use us as its delegate
        item.delegate = self
        // END collectionview_datasource_item_delegate
        
        return item
    }
    // END collectionview_datasource_item
    
}
// END collectionview_datasource

// BEGIN document_open_selected_attachment
extension Document : AttachmentCellDelegate {
    func openSelectedAttachment(_ collectionItem: NSCollectionViewItem) {
        
        // Get the index of this item, or bail out
        guard let selectedIndex = (self.attachmentsList
            .indexPath(for: collectionItem) as NSIndexPath?)?.item else {
            return
        }
        
        // Get the attachment in question, or bail out
        guard let attachment = self.attachedFiles?[selectedIndex] else {
            return
        }
    
        // First, ensure that the document is saved
        self.autosave(withImplicitCancellability: false,
                                        completionHandler: { (error) -> Void in
            
            // BEGIN document_open_selected_attachment_location
            // If this attachment indicates that it's JSON, and we're able
            // to get JSON data out of it...
            if attachment.conformsToType(kUTTypeJSON),
                let data = attachment.regularFileContents,
                let json = try? JSONSerialization
                    .jsonObject(with: data, options: JSONSerialization.ReadingOptions())
                    as? NSDictionary  {
                
                        // And if that JSON data includes lat and long entries...
                
                        if let lat = json?["lat"] as? CLLocationDegrees,
                            let lon = json?["long"] as? CLLocationDegrees {
                            
                            // Build a coordinate from them
                            let coordinate =
                                CLLocationCoordinate2D(latitude: lat,
                                    longitude: lon)
                            
                            // Build a placemark with that coordinate
                            let placemark =
                                MKPlacemark(coordinate: coordinate,
                                    addressDictionary: nil)
                            
                            // Build a map item from that placemark...
                            let mapItem = MKMapItem(placemark: placemark)
                            
                            // And open the map item in the Maps app!
                            mapItem.openInMaps(launchOptions: nil)
                            
                        }
            } else {
                // END document_open_selected_attachment_location
                
                var url = self.fileURL
                url = url?.appendingPathComponent(
                    NoteDocumentFileNames.AttachmentsDirectory.rawValue,
                        isDirectory: true)
                
                url = url?
                    .appendingPathComponent(attachment.preferredFilename!)
                
                if let path = url?.path {
                    NSWorkspace.shared().openFile(
                        path, withApplication: nil, andDeactivate: true)
                }
                
                
                // BEGIN document_open_selected_attachment_location
            }
            // END document_open_selected_attachment_location
        })
        
    }

}
// END document_open_selected_attachment


// BEGIN attachment_view_delegate_protocol
@objc protocol AttachmentCellDelegate : NSObjectProtocol {
    func openSelectedAttachment(_ collectionViewItem : NSCollectionViewItem)
}
// END attachment_view_delegate_protocol

// Note: Not actually used in the app, but included to give
// an example of how you'd implement a flat-file document.

// These methods are not included in the main Document class
// because we're actually using readFromFileWrapper and
// fileWrapperOfType, and having implementations of readFromData and
// dataOfType in the class changes the behaviour of the NSDocument system.

// PS: These comments aren't in the book, which means that if you're
// in here and reading this, you're pretty dedicated. Hi there! Hope 
// you're doing well today! Ping us on Twitter at @thesecretlab if you liked
// the book! :)

class FlatFileDocumentExample : NSDocument {

    // BEGIN read_from_data
    override func read(from data: Data, ofType typeName: String) throws {
        // Load data from "data".
    }
    // END read_from_data

    // BEGIN data_of_type
    override func data(ofType typeName: String) throws -> Data {
        // Return an NSData object. Here's an example:
        return "Hello".data(using: String.Encoding.utf8)!
    }
    // END data_of_type
}

// Icons

extension Document {
    
    // BEGIN document_icon_data
    func iconImageDataWithSize(_ size: CGSize) -> Data? {
        
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        let entireImageRect = CGRect(origin: CGPoint.zero, size: size)
        
        // Fill the background with white
        let backgroundRect = NSBezierPath(rect: entireImageRect)
        NSColor.white.setFill()
        backgroundRect.fill()
        
        if self.attachedFiles?.count >= 1 {
            // Render our text, and the first attachment
            let attachmentImage = self.attachedFiles?[0].thumbnailImage
            
            let result = entireImageRect.divided(atDistance: entireImageRect.size.height / 2.0, from: CGRectEdge.minYEdge)
            
            self.text.draw(in: result.slice)
            
            attachmentImage?.draw(in: result.remainder)
        } else {
            // Just render our text
            self.text.draw(in: entireImageRect)
        }
        
        let bitmapRepresentation =
            NSBitmapImageRep(focusedViewRect: entireImageRect)
        
        image.unlockFocus()
        
        // Convert it to a PNG
        return bitmapRepresentation?
            .representation(using: .PNG, properties: [:])
        
        
    }
    // END document_icon_data
}

