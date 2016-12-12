//
//  Document.swift
//  Notes
//
//  Created by Jonathon Manning on 26/08/2015.
//  Copyright © 2015 Jonathon Manning. All rights reserved.
//

import UIKit

// BEGIN import_mobilecoreservices
import MobileCoreServices
// END import_mobilecoreservices

// Type info and thumbnails

// BEGIN filewrapper_extension
extension FileWrapper {
    
    // BEGIN conforms_to_type
    var fileExtension : String? {
        return self.preferredFilename?
            .components(separatedBy: ".").last
    }
    
    func conformsToType(_ type: CFString) -> Bool {
        
        // Get the extension of this file
        guard let fileExtension = fileExtension else {
            // If we can't get a file extension, assume that it doesn't conform
            return false
        }
        
        // Get the file type of the attachment based on its extension
        guard let fileType = UTTypeCreatePreferredIdentifierForTag(
            kUTTagClassFilenameExtension, fileExtension as CFString, nil)?
            .takeRetainedValue() else {
            // If we can't figure out the file type from the extension,
            // it also doesn't conform
            return false
        }
        
        // Ask the system if this file type conforms to the provided type
        return UTTypeConformsTo(fileType, type)
    }
    // END conforms_to_type
    
    // BEGIN thumbnail_image
    func thumbnailImage() -> UIImage? {
        
        if self.conformsToType(kUTTypeImage) {
            // If it's an image, return it as a UIImage
            
            // Ensure that we can get the contents of the file
            guard let attachmentContent = self.regularFileContents else {
                return nil
            }
            
            // Attempt to convert the file's contents to text
            return UIImage(data: attachmentContent)
        }
        
        // BEGIN thumbnail_image_audio
        if (self.conformsToType(kUTTypeAudio)) {
            return UIImage(named: "Audio")
        }
        // END thumbnail_image_audio
        
        // BEGIN thumbnail_image_movie
        if (self.conformsToType(kUTTypeMovie)) {
            return UIImage(named: "Video")
        }
        // END thumbnail_image_movie
        
        // We don't know what type it is, so return nil
        return nil
    }
    // END thumbnail_image

}
// END filewrapper_extension

class Document: UIDocument {
    
    // BEGIN notification_constants
    static let alertSnoozeAction = "snooze"
    static let alertCategory = "notes-alert"
    // END notification_constants
    
    // BEGIN document_base
    var text = NSAttributedString(string: "") {
        didSet {
            self.updateChangeCount(UIDocumentChangeKind.done)
        }
    }
    
    // BEGIN location_attachment_wrapper
    var locationWrapper : FileWrapper?
    // END location_attachment_wrapper
    
    var documentFileWrapper = FileWrapper(directoryWithFileWrappers: [:])
    
    // BEGIN document_contents_for_type
    override func contents(forType typeName: String) throws -> Any {
        
        let textRTFData = try self.text.data(
            from: NSRange(0..<self.text.length),
            documentAttributes:
                [NSDocumentTypeDocumentAttribute: NSRTFTextDocumentType])
        
        if let oldTextFileWrapper = self.documentFileWrapper
            .fileWrappers?[NoteDocumentFileNames.TextFile.rawValue] {
            self.documentFileWrapper.removeFileWrapper(oldTextFileWrapper)
        }
        
        // BEGIN document_base_quicklook
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
        quickLookFolderFileWrapper.preferredFilename =
            NoteDocumentFileNames.QuickLookDirectory.rawValue
        
        // Remove the old QuickLook folder if it existed
        if let oldQuickLookFolder = self.documentFileWrapper
            .fileWrappers?[NoteDocumentFileNames.QuickLookDirectory.rawValue] {
                self.documentFileWrapper.removeFileWrapper(oldQuickLookFolder)
        }
        
        // Add the new QuickLook folder
        self.documentFileWrapper.addFileWrapper(quickLookFolderFileWrapper)
        // END document_base_quicklook
        
        // BEGIN location_attachment_save
        // checking if there is already a location saved
        if self.documentFileWrapper.fileWrappers?[NoteDocumentFileNames.locationAttachment.rawValue] == nil {
            // saving the location if there is one
            if let location = self.locationWrapper {
                self.documentFileWrapper.addFileWrapper(location)
            }
        }
        // END location_attachment_save
        
        self.documentFileWrapper.addRegularFile(withContents: textRTFData,
            preferredFilename: NoteDocumentFileNames.TextFile.rawValue)
        
        return self.documentFileWrapper
    }
    // END document_contents_for_type

    // BEGIN location_document_load
    override func load(fromContents contents: Any,
        ofType typeName: String?) throws {
        
        // Ensure that we've been given a file wrapper
        guard let fileWrapper = contents as? FileWrapper else {
            throw err(.cannotLoadFileWrappers)
        }
        
        // Ensure that this file wrapper contains the text file,
        // and that we can read it
        guard let textFileWrapper = fileWrapper
            .fileWrappers?[NoteDocumentFileNames.TextFile.rawValue],
            let textFileData = textFileWrapper.regularFileContents else {
            throw err(.cannotLoadText)
        }
        
        // Read in the RTF
        self.text = try NSAttributedString(data: textFileData,
            options: [NSDocumentTypeDocumentAttribute: NSRTFTextDocumentType],
            documentAttributes: nil)
        
        // Keep a reference to the file wrapper
        self.documentFileWrapper = fileWrapper
        
        // BEGIN location_attachment_load
        // opening the location filewrapper
        self.locationWrapper = fileWrapper.fileWrappers?[NoteDocumentFileNames.locationAttachment.rawValue]
        // END location_attachment_load
        
    }
    // END location_document_load
    // END document_base
    
    // BEGIN document_attachment_dir
    fileprivate var attachmentsDirectoryWrapper : FileWrapper? {
        
        // Ensure that we can actually work with this document
        guard let fileWrappers = self.documentFileWrapper.fileWrappers else {
            NSLog("Attempting to access document's contents, but none found!")
            return nil
        }
        
        // Try to get the attachments directory
        var attachmentsDirectoryWrapper =
            fileWrappers[NoteDocumentFileNames.AttachmentsDirectory.rawValue]
        
        // If it doesn't exist..
        if attachmentsDirectoryWrapper == nil {
            
            // Create it
            attachmentsDirectoryWrapper =
                FileWrapper(directoryWithFileWrappers: [:])
            attachmentsDirectoryWrapper?.preferredFilename =
                NoteDocumentFileNames.AttachmentsDirectory.rawValue
            
            // And then add it
            self.documentFileWrapper.addFileWrapper(attachmentsDirectoryWrapper!)
            
            // We made a change to the file, so record that
            self.updateChangeCount(UIDocumentChangeKind.done)
        }
        
        // Either way, return it
        return attachmentsDirectoryWrapper
    }
    // END document_attachment_dir
    
    // Attachments
    // BEGIN document_attachments
    dynamic var attachedFiles : [FileWrapper]? {
        
        // Get the contents of the attachments directory directory
        guard let attachmentsFileWrappers =
            attachmentsDirectoryWrapper?.fileWrappers else {
            NSLog("Can't access the attachments directory!")
            return nil
        }
        
        // attachmentsFileWrappers is a dictionary mapping filenames
        // to FileWrapper objects; we only care about the FileWrappers,
        // so return that as an array
        return Array(attachmentsFileWrappers.values)
            
    }
    // END document_attachments

    // BEGIN document_add_attachments
    @discardableResult func addAttachmentAtURL(_ url:URL) throws -> FileWrapper {
    
        // Ensure that we have a place to put attachments
        guard attachmentsDirectoryWrapper != nil else {
            throw err(.cannotAccessAttachments)
        }
        
        // Create the new attachment with this file, or throw an error
        let newAttachment = try FileWrapper(url: url,
            options: FileWrapper.ReadingOptions.immediate)
        
        // Add it to the attachments directory
        attachmentsDirectoryWrapper?.addFileWrapper(newAttachment)
        
        // Mark ourselves as needing to save
        self.updateChangeCount(UIDocumentChangeKind.done)
        
        return newAttachment
    }
    // END document_add_attachments
    
    
    // BEGIN document_url_for_attachment
    // Given an attachment, eventually returns its URL, if possible.
    // It might be nil if 1. this isn't one of our attachments or
    // 2. we failed to save, in which case the attachment may not exist
    // on disk
    func URLForAttachment(_ attachment: FileWrapper,
         completion: @escaping (URL?) -> Void) {
        
        // Ensure that this is an attachment we have
        guard let attachments = self.attachedFiles
                , attachments.contains(attachment) else {
            completion(nil)
            return
        }
        
        // Ensure that this attachment has a filename
        guard let fileName = attachment.preferredFilename else {
            completion(nil)
            return
        }
        
        self.autosave { (success) -> Void in
            if success {
                
                // We're now certain that attachments actually
                // exist on disk, so we can get their URL
                let attachmentURL = self.fileURL
                    .appendingPathComponent(
                        NoteDocumentFileNames.AttachmentsDirectory.rawValue,
                        isDirectory: true).appendingPathComponent(fileName)
                
                completion(attachmentURL)
                
            } else {
                NSLog("Failed to autosave!")
                completion(nil)
            }
        }
        
    }
    // END document_url_for_attachment
    
    
    
    // BEGIN document_add_attachment_with_data
    func addAttachmentWithData(_ data: Data, name: String) throws {
        
        guard attachmentsDirectoryWrapper != nil else {
            throw err(.cannotAccessAttachments)
        }
        
        let newAttachment = FileWrapper(regularFileWithContents: data)
        
        newAttachment.preferredFilename = name
        
        attachmentsDirectoryWrapper?.addFileWrapper(newAttachment)
        
        self.updateChangeCount(.done)
        
    }
    // END document_add_attachment_with_data
    
    // BEGIN delete_attachment
    func deleteAttachment(_ attachment:FileWrapper) throws {
        
        guard attachmentsDirectoryWrapper != nil else {
            throw err(.cannotAccessAttachments)
        }
        
        
        attachmentsDirectoryWrapper?.removeFileWrapper(attachment)
        
        self.updateChangeCount(.done)
        
    }
    // END delete_attachment
    
    // BEGIN ios_thumbnail_icon
    func iconImageDataWithSize(_ size: CGSize) -> Data? {
        UIGraphicsBeginImageContext(size)
        defer {
            UIGraphicsEndImageContext()
        }
        
        let entireImageRect = CGRect(origin: CGPoint.zero, size: size)
        
        // Fill the background with white
        let backgroundRect = UIBezierPath(rect: entireImageRect)
        UIColor.white.setFill()
        backgroundRect.fill()
        
        if (self.attachedFiles?.count)! >= 1 {
            // Render our text, and the first attachment
            let attachmentImage = self.attachedFiles?[0].thumbnailImage()
            
            let result = entireImageRect.divided(atDistance: entireImageRect.size.height / 2.0, from: CGRectEdge.minYEdge)
            
            self.text.draw(in: result.slice)
            attachmentImage?.draw(in: result.remainder)
        } else {
            // Just render our text
            self.text.draw(in: entireImageRect)
        }
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        return UIImagePNGRepresentation(image!)
    }
    // END ios_thumbnail_icon
    
    // BEGIN location_add_location
    func addLocation(withData data: Data) {
        // making sure we don't already have a location
        guard self.locationWrapper == nil else {
            return
        }
        
        let newLocation = FileWrapper(regularFileWithContents: data)
        newLocation.preferredFilename = NoteDocumentFileNames.locationAttachment.rawValue
        
        self.locationWrapper = newLocation
        
        self.updateChangeCount(.done)
    }
    // END location_add_location
}
