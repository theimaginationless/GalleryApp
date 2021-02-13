//
//  GalleryCollectionViewCell.swift
//  GalleryApp
//
//  Created by Dmitry Teplyakov on 12.02.2021.
//

import UIKit

class GalleryCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var loadingActivityIndicator: UIActivityIndicatorView!
    var photoId: String!
    
    override func prepareForReuse() {
        self.updateWith(image: nil, photoId: "")
        super.prepareForReuse()
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.updateWith(image: nil, photoId: "")
    }
    
    func updateWith(image: UIImage?, photoId: String) {
        self.photoId = photoId
        if let unwrappedImage = image {
            self.imageView.image = unwrappedImage
            self.loadingActivityIndicator.stopAnimating()
        }
        else {
            self.imageView.image = nil
            self.loadingActivityIndicator.startAnimating()
        }
    }
}
