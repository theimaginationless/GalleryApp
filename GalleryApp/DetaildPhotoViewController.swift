//
//  DetaildPhotoViewController.swift
//  GalleryApp
//
//  Created by Dmitry Teplyakov on 13.02.2021.
//

import UIKit

class DetailPhotoViewController: UIViewController {
    @IBOutlet weak var photoImageView: UIImageView!
    @IBOutlet weak var downloadDateLabel: UILabel!
    @IBOutlet weak var imageResolutionLabel: UILabel!
    @IBOutlet weak var loadingActivityIndicator: UIActivityIndicatorView!
    var photo: Photo!
    var photoStore: PhotoStore!
    lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .medium
        return formatter
    }()
    
    private func setupFor(image: UIImage?) {
        if let unwrapedImage = image {
            self.loadingActivityIndicator.stopAnimating()
            self.imageResolutionLabel.text = "\(Int(unwrapedImage.size.width))x\(Int(unwrapedImage.size.height))"
        }
        else {
            self.loadingActivityIndicator.startAnimating()
            self.imageResolutionLabel.text = NSLocalizedString("None", comment: "Empty label placeholder")
        }
        
        self.photoImageView.image = image
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.loadingActivityIndicator.startAnimating()
        self.downloadDateLabel.numberOfLines = 0
        self.downloadDateLabel.text = self.dateFormatter.string(from: self.photo.created)
        self.title = photo.title
        if let image = photo.image {
            self.setupFor(image: image)
        }
        else {
            self.photoStore.fetchImageFor(photo: self.photo, size: .reserved, isPreview: false) {
                (imageResult) in
                
                OperationQueue.main.addOperation {
                    switch imageResult {
                    case let .Successful(image):
                        self.setupFor(image: image)
                    case let .Failed(error):
                        print("\(#function): Error: \(error)")
                    }
                }
            }
        }
    }
}
