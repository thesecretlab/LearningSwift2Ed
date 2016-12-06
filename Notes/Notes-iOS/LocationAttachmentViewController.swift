//
//  LocationAttachmentViewController.swift
//  Notes
//
//  Created by Tim Nugent on 2/12/16.
//  Copyright © 2016 Jonathon Manning. All rights reserved.
//

import UIKit
// BEGIN mapkit_frameworks
import MapKit
// END mapkit_frameworks

class LocationAttachmentViewController: UIViewController {

    // BEGIN map_location_attachment_property
    var locationAttachment: FileWrapper?
    // END map_location_attachment_property
    
    // BEGIN map_mapview_property
    @IBOutlet weak var mapview: MKMapView?
    // END map_mapview_property

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    // BEGIN map_viewWillAppear
    override func viewWillAppear(_ animated: Bool) {
        if let data = locationAttachment?.regularFileContents {
            do {
                guard let loadedData =
                    try JSONSerialization.jsonObject(with: data,
                                options: JSONSerialization.ReadingOptions())
                        as? [String:CLLocationDegrees] else {
                    return
                }
                
                if let latitude = loadedData["lat"],
                    let longitude = loadedData["long"] {
                    let coordinate = CLLocationCoordinate2D(latitude: latitude,
                                                           longitude: longitude)
                    
                    // create a new annotation to show on the map
                    let annotation = MKPointAnnotation()
                    annotation.coordinate = coordinate
                    annotation.title = "Note created here"
                    
                    self.mapview?.addAnnotation(annotation)
                    
                    // moving the map to focus on the annotation
                    self.mapview?.setCenter(coordinate, animated: true)
                }
            }
            catch let error as NSError {
                print("failed to load location: \(error)")
            }
        }
    }
    // END map_viewWillAppear

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
