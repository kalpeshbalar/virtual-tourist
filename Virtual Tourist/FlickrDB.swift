//
//  FlickrDB.swift
//  Virtual Tourist
//
//  Created by Kalpesh Balar on 17/04/16.
//  Copyright © 2016 Kalpesh Balar. All rights reserved.
//

import Foundation

// MARK: - Globals
let BASE_URL = "https://api.flickr.com/services/rest/"
let METHOD_NAME = "flickr.photos.search"
let API_KEY = "05ba76c9de53bd268b1754a8e1cfc34c"
let EXTRAS = "url_m"
let SAFE_SEARCH = "1"
let DATA_FORMAT = "json"
let NO_JSON_CALLBACK = "1"
let BOUNDING_BOX_HALF_WIDTH = 1.0
let BOUNDING_BOX_HALF_HEIGHT = 1.0
let LAT_MIN = -90.0
let LAT_MAX = 90.0
let LON_MIN = -180.0
let LON_MAX = 180.0
let PER_PAGE = 20

// MARK: - String Extension

extension String {
    func toDouble() -> Double? {
        return NSNumberFormatter().numberFromString(self)?.doubleValue
    }
}

// MARK: - ViewController: UIViewController
class FlickrDB : NSObject {
    
    var session: NSURLSession
    typealias CompletionHander = (result: AnyObject!, error: NSError?) -> Void
    
    override init() {
        session = NSURLSession.sharedSession()
        super.init()
    }

    class func sharedInstance() -> FlickrDB {
        struct Singleton {
            static var sharedInstance = FlickrDB()
        }
        return Singleton.sharedInstance
    }
    
    struct Caches {
        static let imageCache = ImageCache()
    }
    
    
    func searchPhotosByLatLon(pin: Pin, completionHandler: CompletionHander) -> NSURLSessionDataTask {
        let methodArguments = [
            "method": METHOD_NAME,
            "api_key": API_KEY,
            "bbox": createBoundingBoxString(pin),
            "safe_search": SAFE_SEARCH,
            "extras": EXTRAS,
            "format": DATA_FORMAT,
            "nojsoncallback": NO_JSON_CALLBACK,
            "per_page": PER_PAGE
        ]
        return getImageFromFlickrBySearch(methodArguments, completionHandler: completionHandler)
    }
    
    // MARK: Lat/Lon Manipulation
    func createBoundingBoxString(pin: Pin) -> String {
        let latitude = pin.latitude
        let longitude = pin.longitude

        /* Fix added to ensure box is bounded by minimum and maximums */
        let bottom_left_lon = max(longitude - BOUNDING_BOX_HALF_WIDTH, LON_MIN)
        let bottom_left_lat = max(latitude - BOUNDING_BOX_HALF_HEIGHT, LAT_MIN)
        let top_right_lon = min(longitude + BOUNDING_BOX_HALF_HEIGHT, LON_MAX)
        let top_right_lat = min(latitude + BOUNDING_BOX_HALF_HEIGHT, LAT_MAX)
        
        return "\(bottom_left_lon),\(bottom_left_lat),\(top_right_lon),\(top_right_lat)"
    }
 
    
    /* Function makes first request to get a random page, then it makes a request to get an image with the random page */
    func getImageFromFlickrBySearch(methodArguments: [String : AnyObject], completionHandler: CompletionHander) -> NSURLSessionDataTask {
        let urlString = BASE_URL + escapedParameters(methodArguments)
        let url = NSURL(string: urlString)!
        let request = NSURLRequest(URL: url)
        
        let task = session.dataTaskWithRequest(request) { (data, response, error) in
            
            /* GUARD: Was there an error? */
            guard (error == nil) else {
                completionHandler(result: nil, error: error)
                print("There was an error with your request: \(error)")
                return
            }
            
            /* GUARD: Did we get a successful 2XX response? */
            guard let statusCode = (response as? NSHTTPURLResponse)?.statusCode where statusCode >= 200 && statusCode <= 299 else {
                if let response = response as? NSHTTPURLResponse {
                    print("Your request returned an invalid response! Status code: \(response.statusCode)!")
                } else if let response = response {
                    print("Your request returned an invalid response! Response: \(response)!")
                } else {
                    print("Your request returned an invalid response!")
                }
                return
            }
            
            /* GUARD: Was there any data returned? */
            guard let data = data else {
                dispatch_async(dispatch_get_main_queue(), {
                    //self.setUIEnabled(enabled: true)
                })
                print("No data was returned by the request!")
                return
            }
            
            /* Parse the data! */
            let parsedResult: AnyObject!
            do {
                parsedResult = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments)
            } catch {
                parsedResult = nil
                print("Could not parse the data as JSON: '\(data)'")
                return
            }
            //print(parsedResult)
            
            /* GUARD: Did Flickr return an error? */
            guard let stat = parsedResult["stat"] as? String where stat == "ok" else {
                print("Flickr API returned an error. See error code and message in \(parsedResult)")
                return
            }
            //print(stat)
            
            /* GUARD: Is "photos" key in our result? */
            guard let photosDictionary = parsedResult["photos"] as? NSDictionary else {
                print("Cannot find keys 'photos' in \(parsedResult)")
                return
            }
            completionHandler(result: photosDictionary, error: nil)
            //print(photosDictionary)
            
            /* GUARD: Is "pages" key in the photosDictionary? */
            guard let totalPages = photosDictionary["pages"] as? Int else {
                print("Cannot find key 'pages' in \(photosDictionary)")
                return
            }
            //print(totalPages)
            
            /* Pick a random page! */
            //let pageLimit = min(totalPages, 40)
            //let randomPage = Int(arc4random_uniform(UInt32(pageLimit))) + 1
            //self.getImageFromFlickrBySearchWithPage(methodArguments, pageNumber: randomPage)
        }
        
        task.resume()
        return task
    }
    
    func getImageFromFlickrBySearchWithPage(methodArguments: [String : AnyObject], pageNumber: Int) {
        
        /* Add the page to the method's arguments */
        var withPageDictionary = methodArguments
        withPageDictionary["page"] = pageNumber
        
        let session = NSURLSession.sharedSession()
        let urlString = BASE_URL + escapedParameters(withPageDictionary)
        let url = NSURL(string: urlString)!
        let request = NSURLRequest(URL: url)
        
        let task = session.dataTaskWithRequest(request) { (data, response, error) in
            
            /* GUARD: Was there an error? */
            guard (error == nil) else {
                dispatch_async(dispatch_get_main_queue(), {
                    //self.setUIEnabled(enabled: true)
                })
                print("There was an error with your request: \(error)")
                return
            }
            
            /* GUARD: Did we get a successful 2XX response? */
            guard let statusCode = (response as? NSHTTPURLResponse)?.statusCode where statusCode >= 200 && statusCode <= 299 else {
                dispatch_async(dispatch_get_main_queue(), {
                    //self.setUIEnabled(enabled: true)
                })
                if let response = response as? NSHTTPURLResponse {
                    print("Your request returned an invalid response! Status code: \(response.statusCode)!")
                } else if let response = response {
                    print("Your request returned an invalid response! Response: \(response)!")
                } else {
                    print("Your request returned an invalid response!")
                }
                return
            }
            
            /* GUARD: Was there any data returned? */
            guard let data = data else {
                dispatch_async(dispatch_get_main_queue(), {
                    //self.setUIEnabled(enabled: true)
                })
                print("No data was returned by the request!")
                return
            }
            
            /* Parse the data! */
            let parsedResult: AnyObject!
            do {
                parsedResult = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
            } catch {
                parsedResult = nil
                dispatch_async(dispatch_get_main_queue(), {
                    //self.setUIEnabled(enabled: true)
                })
                print("Could not parse the data as JSON: '\(data)'")
                return
            }
            
            /* GUARD: Did Flickr return an error (stat != ok)? */
            guard let stat = parsedResult["stat"] as? String where stat == "ok" else {
                dispatch_async(dispatch_get_main_queue(), {
                    //self.setUIEnabled(enabled: true)
                })
                print("Flickr API returned an error. See error code and message in \(parsedResult)")
                return
            }
            
            /* GUARD: Is the "photos" key in our result? */
            guard let photosDictionary = parsedResult["photos"] as? NSDictionary else {
                dispatch_async(dispatch_get_main_queue(), {
                    //self.setUIEnabled(enabled: true)
                })
                print("Cannot find key 'photos' in \(parsedResult)")
                return
            }
            
            /* GUARD: Is the "total" key in photosDictionary? */
            guard let totalPhotosVal = (photosDictionary["total"] as? NSString)?.integerValue else {
                dispatch_async(dispatch_get_main_queue(), {
                    //self.setUIEnabled(enabled: true)
                })
                print("Cannot find key 'total' in \(photosDictionary)")
                return
            }
            
            if totalPhotosVal > 0 {
                
                /* GUARD: Is the "photo" key in photosDictionary? */
                guard let photosArray = photosDictionary["photo"] as? [[String: AnyObject]] else {
                    dispatch_async(dispatch_get_main_queue(), {
                        //self.setUIEnabled(enabled: true)
                    })
                    print("Cannot find key 'photo' in \(photosDictionary)")
                    return
                }
                
                let randomPhotoIndex = Int(arc4random_uniform(UInt32(photosArray.count)))
                let photoDictionary = photosArray[randomPhotoIndex] as [String: AnyObject]
                let photoTitle = photoDictionary["title"] as? String /* non-fatal */
                
                /* GUARD: Does our photo have a key for 'url_m'? */
                guard let imageUrlString = photoDictionary["url_m"] as? String else {
                    dispatch_async(dispatch_get_main_queue(), {
                       // self.setUIEnabled(enabled: true)
                    })
                    print("Cannot find key 'url_m' in \(photoDictionary)")
                    return
                }
                
                let imageURL = NSURL(string: imageUrlString)
                if let imageData = NSData(contentsOfURL: imageURL!) {
                    dispatch_async(dispatch_get_main_queue(), {
                        
                       // self.setUIEnabled(enabled: true)
                        //self.defaultLabel.alpha = 0.0
                        //self.photoImageView.image = UIImage(data: imageData)
                        
                        if methodArguments["bbox"] != nil {
                            if let photoTitle = photoTitle {
                               // self.photoTitleLabel.text = "\(self.getLatLonString()) \(photoTitle)"
                            } else {
                                //self.photoTitleLabel.text = "\(self.getLatLonString()) (Untitled)"
                            }
                        } else {
                            //self.photoTitleLabel.text = photoTitle ?? "(Untitled)"
                        }
                    })
                } else {
                    dispatch_async(dispatch_get_main_queue(), {
                        //self.setUIEnabled(enabled: true)
                    })
                    print("Image does not exist at \(imageURL)")
                }
            } else {
                dispatch_async(dispatch_get_main_queue(), {
                    //self.setUIEnabled(enabled: true)
                    //self.photoTitleLabel.text = "No Photos Found. Search Again."
                    //self.defaultLabel.alpha = 1.0
                    //self.photoImageView.image = nil
                })
            }
        }
        
        task.resume()
    }
    
    // MARK: Escape HTML Parameters
    
    func escapedParameters(parameters: [String : AnyObject]) -> String {
        
        var urlVars = [String]()
        
        for (key, value) in parameters {
            
            /* Make sure that it is a string value */
            let stringValue = "\(value)"
            
            /* Escape it */
            let escapedValue = stringValue.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())
            
            /* Append it */
            urlVars += [key + "=" + "\(escapedValue!)"]
            
        }
        
        return (!urlVars.isEmpty ? "?" : "") + urlVars.joinWithSeparator("&")
    }

    func taskForImage(filePath: String, completionHandler: (imageData: NSData?, error: NSError?) ->  Void) -> NSURLSessionTask {
        
        let baseURL = NSURL(string: filePath)!
        let request = NSURLRequest(URL: baseURL)
        
        let task = session.dataTaskWithRequest(request) {data, response, downloadError in
            if let error = downloadError {
                completionHandler(imageData: nil, error: error)
            } else {
                completionHandler(imageData: data, error: nil)
            }
        }
        task.resume()
        return task
    }
}


/*
    // MARK: - All purpose task method for data
    
    func taskForResource(resource: String, parameters: [String : AnyObject], completionHandler: CompletionHander) -> NSURLSessionDataTask {
        
        var mutableParameters = parameters
        var mutableResource = resource
        
        // Add in the API Key
        mutableParameters["api_key"] = Constants.ApiKey
        
        // Substitute the id parameter into the resource
        if resource.rangeOfString(":id") != nil {
            assert(parameters[Keys.ID] != nil)
            
            mutableResource = mutableResource.stringByReplacingOccurrencesOfString(":id", withString: "\(parameters[Keys.ID]!)")
            mutableParameters.removeValueForKey(Keys.ID)
        }
        
        let urlString = Constants.BaseUrlSSL + mutableResource + TheMovieDB.escapedParameters(mutableParameters)
        let url = NSURL(string: urlString)!
        let request = NSURLRequest(URL: url)
        
        print(url)
        
        let task = session.dataTaskWithRequest(request) {data, response, downloadError in

            if let error = downloadError {
                let newError = TheMovieDB.errorForData(data, response: response, error: error)
                completionHandler(result: nil, error: newError)
            } else {
                print("Step 3 - taskForResource's completionHandler is invoked.")
                TheMovieDB.parseJSONWithCompletionHandler(data!, completionHandler: completionHandler)
            }
        }
        
        task.resume()
        
        return task
    }
    
    // MARK: - All purpose task method for images
    
    
    // MARK: - Helpers
    
    
    // Try to make a better error, based on the status_message from TheMovieDB. If we cant then return the previous error

    class func errorForData(data: NSData?, response: NSURLResponse?, error: NSError) -> NSError {
        
        if data == nil {
            return error
        }
        
        do {
            let parsedResult = try NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.AllowFragments)

            if let parsedResult = parsedResult as? [String : AnyObject], errorMessage = parsedResult[TheMovieDB.Keys.ErrorStatusMessage] as? String {
                let userInfo = [NSLocalizedDescriptionKey : errorMessage]
                return NSError(domain: "TMDB Error", code: 1, userInfo: userInfo)
            }
            
        } catch _ {}
        
        return error
    }
    
    // Parsing the JSON
    
    class func parseJSONWithCompletionHandler(data: NSData, completionHandler: CompletionHander) {
        var parsingError: NSError? = nil
        
        let parsedResult: AnyObject?
        do {
            parsedResult = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments)
        } catch let error as NSError {
            parsingError = error
            parsedResult = nil
        }
        
        if let error = parsingError {
            completionHandler(result: nil, error: error)
        } else {
            print("Step 4 - parseJSONWithCompletionHandler is invoked.")
            completionHandler(result: parsedResult, error: nil)
        }
    }*/
