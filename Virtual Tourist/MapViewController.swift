//
//  MapViewController.swift
//  Virtual Tourist
//
//  Created by Kalpesh Balar on 01/04/16.
//  Copyright © 2016 Kalpesh Balar. All rights reserved.
//

import UIKit
import MapKit
import CoreData


class MapViewController: UIViewController {

    @IBOutlet weak var mapView: MKMapView!

    var pins = [Pin]()
    var annotation: MyAnnotation!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mapView.delegate = self
  
        let uilgr = UILongPressGestureRecognizer(target: self, action: "addPin:")
        uilgr.minimumPressDuration = 1.0
        mapView.addGestureRecognizer(uilgr)
        
        pins = fetchAllPins()
        
        for pin in pins {
            let pincoordinate = CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)
            let annotation = MyAnnotation()
            annotation.pin = pin
            annotation.coordinate = pincoordinate
            mapView.addAnnotation(annotation)
        }        
    }
    
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext
    }

    func saveContext() {
        CoreDataStackManager.sharedInstance().saveContext()
    }
    
    
    func fetchAllPins() -> [Pin] {
        
        // Create the Fetch Request
        let fetchRequest = NSFetchRequest(entityName: "Pin")
        
        // Execute the Fetch Request
        do {
            return try sharedContext.executeFetchRequest(fetchRequest) as! [Pin]
        } catch _ {
            return [Pin]()
        }
    }
    
    func addPin(gestureRecognizer:UIGestureRecognizer){

        let touchPoint = gestureRecognizer.locationInView(mapView)
        let newCoordinates = mapView.convertPoint(touchPoint, toCoordinateFromView: mapView)
    
        switch gestureRecognizer.state {
            case .Began:
                let dictionary: [String : AnyObject] = [
                    Pin.Keys.lat : newCoordinates.latitude,
                    Pin.Keys.lon : newCoordinates.longitude
                ]
                let pin = Pin(dictionary: dictionary, context: sharedContext)

                annotation = MyAnnotation()
                annotation.pin = pin
                annotation.coordinate = newCoordinates
    
                dispatch_async(dispatch_get_main_queue()) {
                    self.mapView.addAnnotation(self.annotation)
                }
            case .Changed:
                dispatch_async(dispatch_get_main_queue()) {
                    self.annotation.coordinate = newCoordinates
                    self.annotation.pin.latitude = newCoordinates.latitude
                    self.annotation.pin.longitude = newCoordinates.longitude
                }
            case .Ended:
                saveContext()
            default:
                return
        }
    }
}


extension MapViewController: MKMapViewDelegate {
    
    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
       
        let reuseId = "udacity"
        var pinView = mapView.dequeueReusableAnnotationViewWithIdentifier(reuseId) as? MKPinAnnotationView
        if pinView == nil {
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            pinView!.canShowCallout = false
            pinView!.animatesDrop = true
            pinView!.pinTintColor = UIColor.purpleColor()
        }
        else {
            pinView!.annotation = annotation
        }
        return pinView
    }
    
    func mapView(mapView: MKMapView, didSelectAnnotationView view: MKAnnotationView) {
        
        mapView.deselectAnnotation(view.annotation, animated: false)
        
        let annotation = view.annotation as? MyAnnotation
        let pin = annotation?.pin
        
        let controller = storyboard!.instantiateViewControllerWithIdentifier("PhotoViewController") as! PhotoViewController
        controller.pin = pin
        
        self.navigationController!.pushViewController(controller, animated: true)
    }
}