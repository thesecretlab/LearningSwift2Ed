//
//  TodayViewController.swift
//  Notes-TodayScreen
//
//  Created by Jonathon Manning on 3/09/2015.
//  Copyright © 2015 Jonathon Manning. All rights reserved.
//

import UIKit
import NotificationCenter

// BEGIN ext_tableview_protocols
class TodayViewController: UIViewController, NCWidgetProviding,
    UITableViewDelegate, UITableViewDataSource
// END ext_tableview_protocols
{
    
    // BEGIN ext_file_list
    var fileList : [URL] = []
    // END ext_file_list
    
    // BEGIN ext_load_available_files
    func loadAvailableFiles() -> [URL] {
        
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
                                localDocumentsFolder
                                    .appendingPathComponent($0,
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
    // END ext_load_available_files
    
    // BEGIN view_did_load
    override func viewDidLoad() {
        super.viewDidLoad()
        
        fileList = loadAvailableFiles()
        
        // We have nothing to show until we attempt to list the files, 
        // so default to a very small size
        self.preferredContentSize = CGSize(width: 0, height: 1)
        
        let containerURL = FileManager.default
            .url(forUbiquityContainerIdentifier: nil)
        
        NSLog("Extension's container: \(containerURL)")
    }
    // END view_did_load
    
    @IBOutlet weak var tableView: UITableView!
    
    // BEGIN ext_update
    func widgetPerformUpdate(completionHandler:
        (@escaping (NCUpdateResult) -> Void)) {
        // Perform any setup necessary in order to update the view.

        // If an error is encountered, use NCUpdateResult.Failed
        // If there's no update required, use NCUpdateResult.NoData
        // If there's an update, use NCUpdateResult.NewData
        
        let newFileList = loadAvailableFiles()
        
        self.preferredContentSize = self.tableView.contentSize
        
        if newFileList == fileList {
            completionHandler(.noData)
        } else {
            fileList = newFileList
            
            completionHandler(.newData)
        }
    }
    // END ext_update
    
    // BEGIN ext_tableview_datasource
    func tableView(_ tableView: UITableView,
         numberOfRowsInSection section: Int) -> Int {
        
        return fileList.count
    }
    
    func tableView(_ tableView: UITableView,
         cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView
            .dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        
        let url = fileList[(indexPath as NSIndexPath).row]
        
        var fileName : AnyObject?
        _ = try? (url as NSURL).getResourceValue(&fileName, forKey: URLResourceKey.nameKey)
        let name = fileName as? String ?? "Note"
        
        cell.textLabel?.text = name
        
        return cell
    }
    // END ext_tableview_datasource
    
    // BEGIN ext_open_document
    func tableView(_ tableView: UITableView,
         didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        let url = fileList[(indexPath as NSIndexPath).row]
        
        var appURLComponents = URLComponents()
        appURLComponents.scheme = "notes"
        appURLComponents.host = nil
        appURLComponents.path = url.path
        
        if let appURL = appURLComponents.url {
            self.extensionContext?.open(appURL, completionHandler: nil)
        }
    }
    // END ext_open_document
    
}
