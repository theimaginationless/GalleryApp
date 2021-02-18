//
//  GalleryCollectionViewController.swift
//  GalleryApp
//
//  Created by Dmitry Teplyakov on 12.02.2021.
//

import UIKit

class GalleryCollectionViewController: UICollectionViewController {
    var photoStore: PhotoStore!
    var photoDataSource = PhotoDataSource()
    var refreshControl: UIRefreshControl!
    var deferredCells = Set<GalleryCollectionViewCell>()
    let reachability = try! Reachability()
    var currentPage = 1
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.collectionView.dataSource = self.photoDataSource
        self.collectionView.delegate = self
        self.refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(self.forcedReloadAction), for: .valueChanged)
        self.collectionView.refreshControl = refreshControl
        self.initialLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.processingAllDeferredCells), name: .reachabilityChanged, object: reachability)
        do {
            try reachability.startNotifier()
        }
        catch {
            print("could not start reachability notifier")
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        reachability.stopNotifier()
        NotificationCenter.default.removeObserver(self, name: .reachabilityChanged, object: reachability)
    }
    
    func initialLoad() {
        self.photoStore.restorePhotosFromLocal {
            (photosResult) in
            
            let sortByDateDownloads = NSSortDescriptor(key: "created", ascending: true)
            let photos = try! self.photoStore.fetchMainQueuePhotos(sortDescriptors: [sortByDateDownloads])
            OperationQueue.main.addOperation {
                if photos.count == 0 {
                    self.forcedReload()
                    return
                }
                self.photoDataSource.photos = photos
                self.collectionView.reloadData()
            }
        }
    }
    
    func forcedReload(completion: (() -> Void)? = nil) {
        self.photoStore.fetchRecentPhotos(page: self.currentPage) {
            (photosResult) in
            
            let sortByDateDownloads = NSSortDescriptor(key: "created", ascending: true)
            let photos = try! self.photoStore.fetchMainQueuePhotos(sortDescriptors: [sortByDateDownloads])
            OperationQueue.main.addOperation {
                self.photoDataSource.photos = photos
                self.collectionView.reloadData()
                if let completion = completion {
                    completion()
                }
            }
        }
    }
    
    @objc func forcedReloadAction() {
        self.photoDataSource.photos.removeAll()
        self.photoStore.imageStore.resetAllImages()
        self.photoStore.resetLocalPhotos()
        self.collectionView.reloadSections(IndexSet(integer: 0))
        self.currentPage = 1
        self.forcedReload {
            self.refreshControl.endRefreshing()
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        let photosCount = self.photoDataSource.photos.count
        if indexPath.row == photosCount - 1 {
            self.loadMore(indexPath: IndexPath(row: photosCount, section: 0))
        }

        let photo = self.photoDataSource.photos[indexPath.row]
        self.photoStore.fetchImageFor(photo: photo, size: .medium, isPreview: true) {
            (imageResult) in

            OperationQueue.main.addOperation {
                switch imageResult {
                case let .Successful(image):
                    if let galleryCell = cell as? GalleryCollectionViewCell {
                        galleryCell.updateWith(image: image, photoId: photo.id)
                        photo.imagePreview = image
                        DispatchQueue.global(qos: .background).async {
                            self.photoStore.fetchImageFor(photo: photo, size: .original, isPreview: false) {
                                (imageResult) in

                                switch imageResult {
                                case let .Successful(image):
                                    photo.image = image
                                case let .Failed(error):
                                    switch error {
                                    case ImageError.NotFound:
                                        fallthrough
                                    default:
                                        let err = error as NSError
                                        if err.domain == NSURLErrorDomain {
                                            self.deferredCells.insert(galleryCell)
                                        }
                                        
                                        print("\(#function): Error: \(error)")
                                    }
                                }
                            }
                        }
                    }
                case let .Failed(error):
                    let err = error as NSError
                    if err.domain == NSURLErrorDomain {
                        self.deferredCells.insert(cell as! GalleryCollectionViewCell)
                    }
                    
                    print("\(#function): Error: \(error)")
                }
            }
        }
    }
    
    @objc func processingAllDeferredCells() {
        let deferredArray = self.deferredCells.map{$0.copy()} as! [GalleryCollectionViewCell]
        self.deferredCells.removeAll()
        let deferredSet = Set<GalleryCollectionViewCell>(deferredArray)
        deferredSet.forEach{self.processingDeferredCell(cell: $0)}
    }
    
    func processingDeferredCell(cell: GalleryCollectionViewCell) {
        let photo = self.photoDataSource.photos.first{$0.id == cell.photoId}!
        self.photoStore.fetchImageFor(photo: photo, size: .medium, isPreview: true) {
            (imageResult) in

            OperationQueue.main.addOperation {
                switch imageResult {
                case let .Successful(image):
                    cell.updateWith(image: image, photoId: photo.id)
                    photo.imagePreview = image
                    DispatchQueue.global(qos: .background).async {
                        self.photoStore.fetchImageFor(photo: photo, size: .original, isPreview: false) {
                            (imageResult) in

                            switch imageResult {
                            case let .Successful(image):
                                photo.image = image
                            case let .Failed(error):
                                switch error {
                                case ImageError.NotFound:
                                    fallthrough
                                default:
                                    let err = error as NSError
                                    if err.domain == NSURLErrorDomain {
                                        self.deferredCells.insert(cell)
                                    }
                                    
                                    print("\(#function): Error: \(error)")
                                }
                            }
                        }
                    }
                case let .Failed(error):
                    let err = error as NSError
                    if err.domain == NSURLErrorDomain {
                        self.deferredCells.insert(cell)
                    }
                    
                    print("\(#function): Error: \(error)")
                }
            }
        }
    }
    
    func loadMore(indexPath: IndexPath) {
        self.photoStore.fetchRecentPhotos(page: self.currentPage + 1) {
            (photosResult) in
            var indexPaths: [IndexPath]?
            OperationQueue.main.addOperation {
                switch photosResult {
                case let .FetchPhotosSuccessful(photosArray):
                    var row = indexPath.row
                    indexPaths = photosArray.map{
                        item in
                        let newIndexPath = IndexPath(row: row, section: indexPath.section)
                        row += 1
                        return newIndexPath
                    }
                    
                    self.currentPage += 1
                    self.photoDataSource.photos.append(contentsOf: photosArray)
                default:
                    return
                }
                
                if let unwrappedIndexPath = indexPaths {
                    self.collectionView.insertItems(at: unwrappedIndexPath)
                }
                else {
                    self.collectionView.reloadData()
                }
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
        case "ShowDetailPhotoViewController":
            let destination = segue.destination as! DetailPhotoViewController
            let cell = sender as! GalleryCollectionViewCell
            let photoId = cell.photoId
            let photo = self.photoDataSource.photos.first(where: {$0.id == photoId})!
            destination.photo = photo
            destination.photoStore = self.photoStore
        default:
            return
        }
    }
    
    func loadPhotosFor(indexPaths: [IndexPath]) {
        for indexPath in indexPaths {
            let photo = self.photoDataSource.photos[indexPath.row]
            self.photoStore.fetchImageFor(photo: photo, size: .medium, isPreview: true) {
                (imageResult) in
                
                OperationQueue.main.addOperation {
                    switch imageResult {
                    case let .Successful(image):
                        photo.imagePreview = image
                        self.photoStore.fetchImageFor(photo: photo, size: .original, isPreview: false) {
                            (imageResult) in
                            
                            switch imageResult {
                            case let .Successful(image):
                                photo.image = image
                            case let .Failed(error):
                                switch error {
                                case ImageError.NotFound:
                                    fallthrough
                                default:
                                    print("\(#function): Error: \(error)\n\(photo.id)")
                                }
                            }
                        }
                    case let .Failed(error):
                        print("\(#function): Error: \(error)")
                    }
                }
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        let totalLoadedPhotos = self.photoDataSource.photos
        let totalIndicesCount = totalLoadedPhotos.count - 1
        let totalIndicesSet = Set(0...totalIndicesCount)
        let visibleIndices = self.collectionView.indexPathsForVisibleItems.map{$0.row}
        let visibleIndicesSet = Set(visibleIndices)
        let indicesForFree = totalIndicesSet.subtracting(visibleIndicesSet)
        indicesForFree.forEach{self.photoDataSource.photos[$0].image = nil}
        print("Total free images: \(indicesForFree.count)")
    }
}
