//
//  ImgurAPI.swift
//  GalleryApp
//
//  Created by Dmitry Teplyakov on 12.02.2021.
//

import Foundation
import CoreData

enum ApiResult {
    case FetchPhotosSuccessful([Photo])
    case FetchPhotosFailed(String)
    case InvalidAPIKey
}

enum RequestType: String {
    case GET
}

enum Method: String {
    case getRecentPhotos = "flickr.photos.getRecent"
}

enum ImageSize: String {
    case original = "url_o"
    case medium = "url_m"
    case small = "url_s"
    case reserved = "url_b"
    case standard
}

struct ParamsAPI {
    static let method = "method"
    static let apiKey = "api_key"
    static let perPage = "per_page"
    static let format = "format"
    static let nojsoncallback = "nojsoncallback"
    static let extras = "extras"
    static let page = "page"
}

struct FlickrAPI {
    private static let ​A​P​I​K​e​y​ = "38d79f9f5702c3509ef49789a8e3c784"
    private static let baseURL = "https://api.flickr.com/services/rest"
    private static let requestProcessingOperationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.theimless.galleryApp.requestProcessingOperationQueue"
        queue.maxConcurrentOperationCount = 4
        queue.qualityOfService = .userInitiated
        return queue
    }()
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config, delegate: nil, delegateQueue: requestProcessingOperationQueue)
        return session
    }()
    
    public static func photosFromJson(jsonDict: [String:Any], inContext context: NSManagedObjectContext) -> ApiResult {
        guard let photosDict = jsonDict["photos"] as? [String:Any],
              let photosDictPayload = photosDict["photo"] as? [[String:Any]]
        else {
            let errMsg = "JSON parsing failed!"
            print("\(#function): \(errMsg)")
            return .FetchPhotosFailed(errMsg)
        }
        
        let photos = photosDictPayload.compactMap{self.photoFromJson(jsonDict: $0, inContext: context)}
        
        return .FetchPhotosSuccessful(photos)
    }
    
    public static func photoFromJson(jsonDict: [String:Any], inContext context: NSManagedObjectContext) -> Photo? {
        guard let id = jsonDict["id"] as? String,
              let server = jsonDict["server"] as? String,
              let secret = jsonDict["secret"] as? String,
              let farm = jsonDict["farm"] as? Int64,
              let title = jsonDict["title"] as? String
        else {
            print("\(#function): JSON parsing failed!")
            return nil
        }
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Photo")
        let predicate = NSPredicate(format: "id == %@", id)
        fetchRequest.predicate = predicate
        var photos: [Photo]!
        context.performAndWait {
            photos = try! context.fetch(fetchRequest) as! [Photo]
        }
        if photos.count > 0 {
            return photos.first!
        }
        
        var url: URL?
        if let urlString = jsonDict["url_o"] as? String {
            url = URL(string: urlString)
        }
        
        var photo: Photo!
        context.performAndWait {
            photo = (NSEntityDescription.insertNewObject(forEntityName: "Photo", into: context) as! Photo)
            photo.id = id
            photo.secret = secret
            photo.server = server
            photo.farm = farm
            photo.title = title
            if let unwrappedUrl = url {
                photo.url = unwrappedUrl
            }
            else {
                photo.url = Photo.buildImageUrl(id: id, server: server, farm: Int(farm), secret: secret, size: .medium)
            }
        }
        
        return photo
    }
    
    /// Extract json representation from binary data
    /// - Returns: json dictionary
    static func jsonFromData(jsonData: Data?) -> [String:Any]? {
        guard let data = jsonData,
              let jsonDict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String:Any]
        else {
            print("\(#function): JSON deserialization failed!")
            return nil
        }
        
        return jsonDict
    }
    
    /// Fetch image from remote
    /// - Parameter photo: fetch image for photo
    /// - Parameter size: image size
    public static func fetchImageFor(photo: Photo, size: ImageSize, dataTask: @escaping (Data?, URLResponse?, Error?) -> Void) {
        var url: URL?
        switch size {
        case .original:
            url = photo.url_o
        case .medium:
            url = photo.url_m
        case .small:
            url = photo.url_s
        case .reserved:
            url = photo.url_b
        case .standard:
            url = photo.url
        }
        
        self.basicRequestProcessing(url: url!, requestType: .GET, urlParams: [:], dataTaskCompletion: dataTask)
    }
    
    /// Get recent photos
    /// - Parameter page: page number
    /// - Parameter limit: limit recent photos
    public static func getRecentPhotos(page: Int, limit: Int, inContext context: NSManagedObjectContext, completion: @escaping (ApiResult) -> Void) {
        let extras = [ImageSize.original.rawValue, "media"]
        let urlParams = [ParamsAPI.method: Method.getRecentPhotos.rawValue,
                         ParamsAPI.apiKey: self.​A​P​I​K​e​y​,
                         ParamsAPI.perPage: String(limit),
                         ParamsAPI.page: String(page),
                         ParamsAPI.format: "json",
                         ParamsAPI.nojsoncallback: String(1),
                         ParamsAPI.extras: extras.joined(separator: ",")]
        guard let url = self.apiEndpointUrl(for: self.baseURL, method: .getRecentPhotos, urlParams: urlParams) else {
            print("\(#function): Cannot create request URL.")
            return
        }
        
        self.basicRequestProcessing(url: url, requestType: .GET) {
            (data, response, error) in
            
            guard let httpResponse = response as? HTTPURLResponse else {
                let errMsg = "\(#function): http response error."
                completion(.FetchPhotosFailed(errMsg))
                return
            }
            
            switch httpResponse.statusCode {
            case 100:
                completion(.InvalidAPIKey)
            case 200...299:
                guard let jsonDict = self.jsonFromData(jsonData: data) else {
                    completion(.FetchPhotosFailed(""))
                    return
                }
                
                let result = self.photosFromJson(jsonDict: jsonDict, inContext: context)
                completion(result)
            default:
                let errMsg = "\(#function): unknown error with http statusCode: \(httpResponse.statusCode)."
                completion(.FetchPhotosFailed(errMsg))
            }
        }
    }
    
    /// Prepare url for request
    /// - Parameter for: base URL endpoint
    /// - Parameter method: api method
    /// - Parameter urlParams: dictionary of url parameters, for example: ["page": "10"]
    /// - Returns: URL that ready for using in requests or nil
    private static func apiEndpointUrl(for url: String, method: Method, urlParams: [String:String]? = nil) -> URL? {
        guard var components = URLComponents(string: self.baseURL) else {
            return nil
        }
        
        components.queryItems = urlParams?.map{URLQueryItem(name: $0.key, value: $0.value)}
        return components.url
    }
    
    /// Basic common request method
    /// - Parameter url: URL instance for request
    /// - Parameter requestType: Type of http method
    /// - Parameter urlParams: URL parameters for request, for example ["page": "10"]
    /// - Parameter dataTaskCompletion: dataTask closure for processing request result
    private static func basicRequestProcessing(url: URL, requestType: RequestType, urlParams: [String:String]? = nil, dataTaskCompletion: @escaping (Data?, URLResponse?, Error?) -> Void) {
        var request = URLRequest(url: url)
        request.httpMethod = requestType.rawValue
        urlParams?.forEach{request.addValue($0.value, forHTTPHeaderField: $0.key)}
        let dataTask = self.session.dataTask(with: request) {
            (data, response, error) in
            
            dataTaskCompletion(data, response, error)
        }
        
        dataTask.resume()
    }
}
