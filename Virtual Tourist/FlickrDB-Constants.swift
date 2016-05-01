//
//  FlickrDB-Constants.swift
//  Virtual Tourist
//
//  Created by Kalpesh Balar on 01/05/16.
//  Copyright © 2016 Kalpesh Balar. All rights reserved.
//

import Foundation

extension FlickrDB {

     struct Constants {
        // MARK: - Globals
        static let BASE_URL = "https://api.flickr.com/services/rest/"
        static let METHOD_NAME = "flickr.photos.search"
        static let API_KEY = "05ba76c9de53bd268b1754a8e1cfc34c"
        static let EXTRAS = "url_m"
        static let SAFE_SEARCH = "1"
        static let DATA_FORMAT = "json"
        static let NO_JSON_CALLBACK = "1"
        static let BOUNDING_BOX_HALF_WIDTH = 1.0
        static let BOUNDING_BOX_HALF_HEIGHT = 1.0
        static let LAT_MIN = -90.0
        static let LAT_MAX = 90.0
        static let LON_MIN = -180.0
        static let LON_MAX = 180.0
        static let PER_PAGE = 12.0
    }
}