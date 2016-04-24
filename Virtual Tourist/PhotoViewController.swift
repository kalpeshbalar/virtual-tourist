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
        addPin()
        updateFlowLayout()

        do {
            try fetchedResultsController.performFetch()
        } catch {
            print(error)
        }
        
        fetchedResultsController.delegate = self
    }

    func addPin() {
        let pincoordinate = CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)
        let annotation = MKPointAnnotation()
        annotation.coordinate = pincoordinate
        mapView.addAnnotation(annotation)
        let mapRegion:MKCoordinateRegion? = MKCoordinateRegion(center: pincoordinate, span: MKCoordinateSpan(latitudeDelta: 1.0, longitudeDelta: 1.0))
        self.mapView.setRegion(mapRegion!, animated: true)
    }
    
    func updateFlowLayout() {
        let space: CGFloat = 2.0
        let width: CGFloat = (self.view.frame.size.width - (2*space)) / 3.0
        
        flowLayout.minimumInteritemSpacing = space
        flowLayout.minimumLineSpacing = space
        flowLayout.itemSize = CGSizeMake(width, width)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        if pin.photos.isEmpty {
            self.reloadCollection(nil)
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
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "title", ascending: false)]
        
        // Create the Fetched Results Controller
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.sharedContext, sectionNameKeyPath: nil, cacheName: nil)
        
        // Return the fetched results controller. It will be the value of the lazy variable
        return fetchedResultsController
    }()
    
    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        self.shouldReloadCollectionView = false
        self.blockOperation = NSBlockOperation()
    }
    
    func controller(controller: NSFetchedResultsController, didChangeSection sectionInfo: NSFetchedResultsSectionInfo,
        atIndex sectionIndex: Int, forChangeType type: NSFetchedResultsChangeType) {
        switch type {
            case NSFetchedResultsChangeType.Insert:
                self.blockOperation?.addExecutionBlock({
                    self.collectionView.insertSections(NSIndexSet(index: sectionIndex))
                })
            case NSFetchedResultsChangeType.Delete:
                self.blockOperation?.addExecutionBlock({
                    self.collectionView.deleteSections( NSIndexSet(index: sectionIndex) )
                })
            case NSFetchedResultsChangeType.Update:
                self.blockOperation?.addExecutionBlock({
                    self.collectionView.reloadSections( NSIndexSet(index: sectionIndex ) )
                })
            default:()
        }
    }
    
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        switch type {
            case NSFetchedResultsChangeType.Insert:
                self.blockOperation?.addExecutionBlock({
                    self.collectionView.insertItemsAtIndexPaths( [newIndexPath!] )
                })
            case NSFetchedResultsChangeType.Delete:
                if self.collectionView.numberOfItemsInSection( indexPath!.section ) == 1 {
                    self.shouldReloadCollectionView = true
                } else {
                    self.blockOperation?.addExecutionBlock({
                        self.collectionView.deleteItemsAtIndexPaths( [indexPath!] )
                    })
                }
            case NSFetchedResultsChangeType.Update:
                self.blockOperation?.addExecutionBlock({
                    self.collectionView.reloadItemsAtIndexPaths( [indexPath!] )
                })
            case NSFetchedResultsChangeType.Move:
                self.blockOperation?.addExecutionBlock({
                    self.collectionView.moveItemAtIndexPath( indexPath!, toIndexPath: newIndexPath! )
                })
        }
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        self.collectionView.reloadData()
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
    
    func collectionView(collectionView: UICollectionView!, didSelectItemAtIndexPath indexPath: NSIndexPath!)
    {
        let photo = fetchedResultsController.objectAtIndexPath(indexPath) as! Photo
        
        FlickrDB.Caches.imageCache.deleteImageWithIdentifier(photo.imagePath)

        sharedContext.deleteObject(photo)
        self.saveContext()
    }
    
    func configureCell(cell: PhotoCollectionViewCell, photo: Photo) {

        var posterImage = UIImage(named: "posterPlaceHoldr")
        cell.imageView!.image = nil
        
        if photo.imagePath == nil || photo.imagePath == "" {
            posterImage = UIImage(named: "noImage")
        } else if photo.photoImage != nil {
            //print("Loading Image from memory")
            posterImage = photo.photoImage
        }
            
        else { // This is the interesting case. The movie has an image name, but it is not downloaded yet.
            //print("Downloading Image")
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
            //cell.taskToCancelifCellIsReused = task
        }
        cell.imageView!.image = posterImage
    }
    
    
    @IBAction func reloadCollection(sender: AnyObject?) {
        for photo in pin.photos {
            sharedContext.deleteObject(photo)
        }
        self.saveContext()
        FlickrDB.sharedInstance().searchPhotosByLatLon(pin) { JSONResult, error  in
            if let error = error {
                print(error)
            } else {
                if let photosDictionaries = JSONResult.valueForKey("photo") as? [[String : AnyObject]] {
                    
                    // Parse the array of photo dictionaries
                    let _ = photosDictionaries.map() { (dictionary: [String : AnyObject]) -> Photo in
    
                        let photo = Photo(dictionary: dictionary, context: self.sharedContext)
                        
                        photo.pin = self.pin
                        return photo
                    }
                    
                    // Update the collection on the main thread
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