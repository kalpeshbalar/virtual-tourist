//
//  PhotoViewController.swift
//  Virtual Tourist
//
//  Created by Kalpesh Balar on 17/04/16.
//  Copyright © 2016 Kalpesh Balar. All rights reserved.
//

import UIKit
import MapKit
import CoreData


class PhotoViewController: UIViewController, NSFetchedResultsControllerDelegate, UICollectionViewDataSource {
    
    var pin: Pin!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var flowLayout: UICollectionViewFlowLayout!
    
    var shouldReloadCollectionView = false
    var blockOperation:NSBlockOperation?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let pincoordinate = CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)
        let annotation = MKPointAnnotation()
        annotation.coordinate = pincoordinate
        mapView.addAnnotation(annotation)
        let mapRegion:MKCoordinateRegion? = MKCoordinateRegion(center: pincoordinate, span: MKCoordinateSpan(latitudeDelta: 1.0, longitudeDelta: 1.0))
        self.mapView.setRegion(mapRegion!, animated: true)

        do {
            try fetchedResultsController.performFetch()
        } catch {
            print(error)
        }
        fetchedResultsController.delegate = self
        collectionView.dataSource = self
        print("Hello")
        let space: CGFloat = 3.0
        let width: CGFloat = (self.view.frame.size.width - (2*space)) / 3.0
        //let height: CGFloat = (self.view.frame.size.height - (2*space)) / 3.0
        
        flowLayout.minimumInteritemSpacing = space
        flowLayout.minimumLineSpacing = space
        flowLayout.itemSize = CGSizeMake(width, width)
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        if pin.photos.isEmpty {
            
            FlickrDB.sharedInstance().searchPhotosByLatLon(pin) { JSONResult, error  in
                if let error = error {
                    print(error)
                } else {
                    if let photosDictionaries = JSONResult.valueForKey("photo") as? [[String : AnyObject]] {
                        
                        // Parse the array of movies dictionaries
                        let _ = photosDictionaries.map() { (dictionary: [String : AnyObject]) -> Photo in
                            //print(dictionary)
                            //print(dictionary[Photo.Keys.ID])
                            let photo = Photo(dictionary: dictionary, context: self.sharedContext)
                            
                            photo.pin = self.pin
                            return photo
                        }
                        
                        // Update the table on the main thread
                        dispatch_async(dispatch_get_main_queue()) {
                            self.collectionView.reloadData()
                        }
                        
                        // Save the context
                        self.saveContext()
                        
                    } else {
                        let error = NSError(domain: "Photo for Pin Parsing. Cant find cast in \(JSONResult)", code: 0, userInfo: nil)
                        print(error)
                    }
                }
            }
        }
    }

    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext
    }
    
    func saveContext() {
        CoreDataStackManager.sharedInstance().saveContext()
    }

    lazy var fetchedResultsController: NSFetchedResultsController = {
        
        // Create the fetch request
        let fetchRequest = NSFetchRequest(entityName: "Photo")
        fetchRequest.predicate = NSPredicate(format: "pin == %@", self.pin);
        
        // Add a sort descriptor. This enforces a sort order on the results that are generated
        // In this case we want the events sored by their timeStamps.
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "title", ascending: false)]
        
        // Create the Fetched Results Controller
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.sharedContext, sectionNameKeyPath: nil, cacheName: nil)
        
        // Return the fetched results controller. It will be the value of the lazy variable
        return fetchedResultsController
    } ()
    
    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        self.shouldReloadCollectionView = false
        self.blockOperation = NSBlockOperation()
    }
    
    func controller(controller: NSFetchedResultsController, didChangeSection sectionInfo: NSFetchedResultsSectionInfo,
        atIndex sectionIndex: Int, forChangeType type: NSFetchedResultsChangeType) {
        let collectionView = self.collectionView
        switch type {
            case NSFetchedResultsChangeType.Insert:
                self.blockOperation?.addExecutionBlock({
                    collectionView.insertSections(NSIndexSet(index: sectionIndex))
                })
            case NSFetchedResultsChangeType.Delete:
                self.blockOperation?.addExecutionBlock({
                    collectionView.deleteSections( NSIndexSet(index: sectionIndex) )
                })
            case NSFetchedResultsChangeType.Update:
                self.blockOperation?.addExecutionBlock({
                    collectionView.reloadSections( NSIndexSet(index: sectionIndex ) )
                })
            default:()
        }
    }
    
    
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        let collectionView = self.collectionView
        switch type {
            case NSFetchedResultsChangeType.Insert:
                if collectionView.numberOfSections() > 0 {
                    if collectionView.numberOfItemsInSection( newIndexPath!.section ) == 0 {
                        self.shouldReloadCollectionView = true
                    } else {
                        self.blockOperation?.addExecutionBlock({
                            collectionView.insertItemsAtIndexPaths( [newIndexPath!] )
                        })
                    }
                } else {
                    self.shouldReloadCollectionView = true
                }
            case NSFetchedResultsChangeType.Delete:
                if collectionView.numberOfItemsInSection( indexPath!.section ) == 1 {
                    self.shouldReloadCollectionView = true
                } else {
                    self.blockOperation?.addExecutionBlock({
                        collectionView.deleteItemsAtIndexPaths( [indexPath!] )
                    })
                }
            case NSFetchedResultsChangeType.Update:
                self.blockOperation?.addExecutionBlock({
                    collectionView.reloadItemsAtIndexPaths( [indexPath!] )
                })
            case NSFetchedResultsChangeType.Move:
                self.blockOperation?.addExecutionBlock({
                    collectionView.moveItemAtIndexPath( indexPath!, toIndexPath: newIndexPath! )
                })
            default:()
        }
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        if self.shouldReloadCollectionView {
            self.collectionView.reloadData()
        } else {
            self.collectionView.performBatchUpdates({self.blockOperation?.start()}, completion: nil )
        }
    }

    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let sectionInfo = self.fetchedResultsController.sections![section] as NSFetchedResultsSectionInfo
        return sectionInfo.numberOfObjects
    }

    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("PhotoCollectionViewCell", forIndexPath: indexPath) as! PhotoCollectionViewCell
        let photo = fetchedResultsController.objectAtIndexPath(indexPath) as! Photo

        configureCell(cell, photo: photo)
        return cell
    }
    
    func configureCell(cell: PhotoCollectionViewCell, photo: Photo) {
       
        cell.imageView!.image = nil
        
        var posterImage = UIImage(named: "posterPlaceHoldr")
        
        if photo.imagePath == nil || photo.imagePath == "" {
            posterImage = UIImage(named: "noImage")
        } else if photo.photoImage != nil {
            posterImage = photo.photoImage
        }
            
        else { // This is the interesting case. The movie has an image name, but it is not downloaded yet.
            
            // Start the task that will eventually download the image
            let task = FlickrDB.sharedInstance().taskForImage(photo.imagePath!) { data, error in
                
                if let error = error {
                    print("Poster download error: \(error.localizedDescription)")
                }
                
                if let data = data {
                    // Craete the image
                    let image = UIImage(data: data)
                    
                    // update the model, so that the infrmation gets cashed
                    photo.photoImage = image
                    
                    // update the cell later, on the main thread
                    dispatch_async(dispatch_get_main_queue()) {
                        cell.imageView!.image = image
                    }
                }
            }
        }
    }
}



