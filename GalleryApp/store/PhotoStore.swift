//
//  PhotoStore.swift
//  GalleryApp
//
//  Created by Dmitry Teplyakov on 12.02.2021.
//

import UIKit
import CoreData

enum ImageResult {
    case Successful(UIImage)
    case Failed(Error)
}

enum ImageError: Error {
    case NotFound
}

class PhotoStore {
    let coreDataStack = CoreDataStack(modelName: "GalleryApp")
    let imageStore = ImageStore()
    lazy var processingOperationQueue: DispatchQueue = {
        let queue = DispatchQueue(label: "me.theimless.galleryApp.PhotoStoreProcessingOperationQueue", qos: .background, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil)
        return queue
    }()
    let photoEntityName = "Photo"
    
    /// Processing photo binary data to UIImage
    /// - Parameter data: Data binary representation of photo
    /// - Returns: PhotoResult with processing result
    private func processingImageData(data: Data?, error: Error?) -> ImageResult {
        guard let photoData = data,
              let photo = UIImage(data: photoData)
        else {
            return .Failed(error!)
        }
        
        return .Successful(photo)
    }
    
    func processRecentPhotosRequest(data: Data?, error: Error?) -> ApiResult {
        guard let jsonData = data,
              let jsonDict = ImgurAPI.jsonFromData(jsonData: jsonData) else {
            return .FetchPhotosFailed("Processing error: \(error!)")
        }
                
        let result = ImgurAPI.photosFromJson(jsonDict: jsonDict, inContext: self.coreDataStack.mainQueueCtx)
        
        return result
    }
    
    /// Fetch recent photos
    /// - Parameter page: page number
    /// - Parameter limit: limit recent photos
    func fetchRecentPhotos(page: Int, limit: Int = 30, completion: @escaping (ApiResult) -> Void) {
        ImgurAPI.getRecentPhotos(page: page, limit: limit, inContext: self.coreDataStack.mainQueueCtx) {
            (photosResult) in
            
            var result = photosResult
            if case let .FetchPhotosSuccessful(photos) = result {
                let mainQueueCtx = self.coreDataStack.mainQueueCtx
                mainQueueCtx.performAndWait {
                    try! mainQueueCtx.obtainPermanentIDs(for: photos)
                }
                
                let objectIDs = photos.map{$0.objectID}
                let predicate = NSPredicate(format: "self IN %@", objectIDs)
                let sortByDateDownloads = NSSortDescriptor(key: "created", ascending: true)
                
                self.coreDataStack.saveChanges()
                
                let mainQueuePhotos = try! self.fetchMainQueuePhotos(predicate: predicate, sortDescriptors: [sortByDateDownloads])
                result = .FetchPhotosSuccessful(mainQueuePhotos)
            }
            
            completion(photosResult)
        }
    }
    
    /// Fetch image for photo from CoreData or remote host
    /// - Parameter photo: photo instance
    /// - Parameter size: size fetching image
    /// - Parameter isPreview: indicate for returns and setting previewImage or image of photo instance
    func fetchImageFor(photo: Photo, size: ImageSize, isPreview: Bool, retry: Int = 0, completion: @escaping (ImageResult) -> Void) {
        let photoId = photo.id
        var image: UIImage?
        if isPreview {
            image = self.imageStore.imagePreviewFor(id: photoId)
        }
        else {
            image = self.imageStore.imageFor(id: photoId)
        }
        
        if let unwrappedImage = image {
            completion(.Successful(unwrappedImage))
            return
        }
        
        ImgurAPI.fetchImageFor(photo: photo, size: size) {
            (data, response, error) in
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.Failed(error!))
                return
            }
            
            switch httpResponse.statusCode {
            case 200...299:
                let result = self.processingImageData(data: data, error: error)
                
                if case let .Successful(image) = result {
                    if isPreview {
                        photo.imagePreview = image
                        self.imageStore.setImagePreview(image, forId: photoId)
                    }
                    else {
                        photo.image = image
                        self.imageStore.setImage(image, forId: photoId)
                    }
                }
                
                completion(result)
            case 410:
                fallthrough
            case 404:
                print("Error: \(httpResponse.statusCode). Attempt \(retry)")
                if retry == 0 {
                    completion(.Failed(ImageError.NotFound))
                    return
                }
                
                self.fetchImageFor(photo: photo, size: .standard, isPreview: isPreview, retry: retry - 1) {
                    (result) in
                    
                    completion(result)
                }
            default:
                completion(.Failed(error!))
            }
        }
    }
    
    /// Restore notes from local persistence
    /// - Parameter completion: completion for using returned note instances
    func restorePhotosFromLocal(completion: @escaping (ApiResult) -> Void) {
        let sortByDownloadsDate = NSSortDescriptor(key: "created", ascending: false)
        
        guard let photos = try? self.fetchMainQueuePhotos(sortDescriptors: [sortByDownloadsDate]) else {
            completion(.FetchPhotosFailed(""))
            return
        }
        
        completion(.FetchPhotosSuccessful(photos))
    }
    
    /// Remove all photo entities from local persistence store
    func resetLocalPhotos() {
        let mainQueueCtx = self.coreDataStack.mainQueueCtx
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: self.photoEntityName)
        mainQueueCtx.performAndWait {
            do {
                let objects = try mainQueueCtx.fetch(fetchRequest)
                for managedObject in objects {
                    let managedObjectData = managedObject as! NSManagedObject
                    mainQueueCtx.delete(managedObjectData)
                }
                
                self.coreDataStack.saveChanges()
            }
            catch let error {
                print("Remove object error! \(error)")
            }
        }
    }
    
    func fetchMainQueuePhotos(predicate: NSPredicate? = nil, sortDescriptors: [NSSortDescriptor]? = nil) throws -> [Photo] {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: self.photoEntityName)
        fetchRequest.sortDescriptors = sortDescriptors
        fetchRequest.predicate = predicate
        let mainQueueCtx = self.coreDataStack.mainQueueCtx
        var mainQueuePhotos: [Photo]?
        var fetchRequestError: Error?
        mainQueueCtx.performAndWait {
            do {
                mainQueuePhotos = try mainQueueCtx.fetch(fetchRequest) as? [Photo]
            }
            catch let error {
                fetchRequestError = error
            }
        }
        
        guard let photos = mainQueuePhotos else {
            throw fetchRequestError!
        }
        
        return photos
    }
}
