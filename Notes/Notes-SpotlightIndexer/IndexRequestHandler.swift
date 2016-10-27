//
//  IndexRequestHandler.swift
//  Notes-SpotlightIndexer
//
//  Created by Jon Manning on 12/10/2015.
//  Copyright © 2015 Jonathon Manning. All rights reserved.
//

// BEGIN index_handler
import CoreSpotlight

// BEGIN index_handler_uikit
import UIKit
// END index_handler_uikit

class IndexRequestHandler: CSIndexExtensionRequestHandler {
    
    // BEGIN index_available_files
    var availableFiles : [URL] {
        
        let fileManager = FileManager.default
        
        var allFiles : [URL] = []
        
        // Get the list of all local files
        if let localDocumentsFolder
            = fileManager.urls(for: .documentDirectory,
                in: .userDomainMask).first {
            do {
                
                let localFiles = try fileManager
                    .contentsOfDirectory(atPath: localDocumentsFolder.path)
                    .map({
                        localDocumentsFolder.appendingPathComponent($0,
                            isDirectory: false)
                    })
                
                allFiles.append(contentsOf: localFiles)
            } catch {
                NSLog("Failed to get list of local files!")
            }
        }
        
        // Get the list of documents in iCloud
        if let documentsFolder = fileManager
            .url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents", isDirectory: true) {
            do {
                
                // Get the list of files
                let iCloudFiles = try fileManager
                    .contentsOfDirectory(atPath: documentsFolder.path)
                    .map({
                        documentsFolder.appendingPathComponent($0,
                            isDirectory: false)
                    })
                
                allFiles.append(contentsOf: iCloudFiles)
                
                
            } catch  {
                // Log an error and return the empty array
                NSLog("Failed to get contents of iCloud container")
                return []
            }
                
        }
        
        // Filter these to only those that end in ".note",
        // and return NSURLs of these
        
        return allFiles
            .filter({ $0.lastPathComponent.hasSuffix(".note") })
        
    }
    // END index_available_files
    
    // BEGIN index_item_for_url
    func itemForURL(_ url: URL) -> CSSearchableItem? {
        
        // If this URL doesn't exist, return nil
        if (url as NSURL).checkResourceIsReachableAndReturnError(nil) == false {
            return nil
        }
        
        // Replace this with your own type identifier
        let attributeSet = CSSearchableItemAttributeSet(
            itemContentType: "au.com.secretlab.Note")
        
        attributeSet.title = url.lastPathComponent
        
        // Get the text in this file
        let textFileURL = url.appendingPathComponent(
            NoteDocumentFileNames.TextFile.rawValue)
        
        if let textData = try? Data(contentsOf: textFileURL),
           let text = try? NSAttributedString(data: textData,
               options: [NSDocumentTypeDocumentAttribute: NSRTFTextDocumentType],
               documentAttributes: nil) {
                    
                    attributeSet.contentDescription = text.string
                    
        } else {
            attributeSet.contentDescription = ""
        }
        
        let item =
            CSSearchableItem(uniqueIdentifier: url.absoluteString,
            domainIdentifier: "au.com.secretlab.Notes",
            attributeSet: attributeSet)
        
        return item
    }
    // END index_item_for_url

    
    // BEGIN index_reindex_all
    override func searchableIndex(_ searchableIndex: CSSearchableIndex,
        reindexAllSearchableItemsWithAcknowledgementHandler
            acknowledgementHandler: @escaping () -> Void) {
        
        // Reindex all data with the provided index
        
        let files = availableFiles
        
        var allItems : [CSSearchableItem] = []
        
        for file in files {
            if let item = itemForURL(file) {
                allItems.append(item)
            }
            
        }
        
        searchableIndex.indexSearchableItems(allItems) { (error) -> Void in
            acknowledgementHandler()
        }
        
    }
    // END index_reindex_all

    // BEGIN index_reindex
    override func searchableIndex(_ searchableIndex: CSSearchableIndex,
                  reindexSearchableItemsWithIdentifiers identifiers: [String],
                                      acknowledgementHandler: @escaping () -> Void) {
        
        // Reindex any items with the given identifiers and the provided index
        
        var itemsToIndex : [CSSearchableItem] = []
        var itemsToRemove : [String] = []
        
        for identifier in identifiers {
            
            if let url = URL(string: identifier), let item = itemForURL(url) {
                itemsToIndex.append(item)
            } else {
                itemsToRemove.append(identifier)
            }
        }
        
        searchableIndex.indexSearchableItems(itemsToIndex) { (error) -> Void in
            searchableIndex
                .deleteSearchableItems(withIdentifiers: itemsToRemove) {
                    (error) -> Void in
                    acknowledgementHandler()
                }
        }
        
        
    }
    // END index_reindex

}

// END index_handler
