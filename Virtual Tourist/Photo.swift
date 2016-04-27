//
//  Photo.swift
//  Virtual Tourist
//
//  Created by Kalpesh Balar on 17/04/16.
//  Copyright © 2016 Kalpesh Balar. All rights reserved.
//

import UIKit
import CoreData

class Photo : NSManagedObject {
    
    struct Keys {
        static let ID = "id"
        static let Title = "title"
        static let ImagePath = "url_m"
    }
    
    @NSManaged var title: String
    @NSManaged var id: NSNumber
    @NSManaged var imagePath: String?
    @NSManaged var pin: Pin?
    
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    init(dictionary: [String : AnyObject], context: NSManagedObjectContext) {
        
        // Core Data
        let entity =  NSEntityDescription.entityForName("Photo", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        
        // Dictionary
        id = (dictionary[Keys.ID] as! NSString).integerValue
        title = dictionary[Keys.Title] as! String
        imagePath = dictionary[Keys.ImagePath] as? String
    }
    
    var photoImage: UIImage? {
        get {
            return FlickrDB.Caches.imageCache.imageWithIdentifier("\(id)")
        }
        
        set {
            FlickrDB.Caches.imageCache.storeImage(newValue, withIdentifier: "\(id)")
        }
    }
    
    override func prepareForDeletion() {
        FlickrDB.Caches.imageCache.deleteImageWithIdentifier("\(id)")
    }
}