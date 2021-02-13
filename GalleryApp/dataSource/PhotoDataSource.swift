//
//  PhotoDataSource.swift
//  GalleryApp
//
//  Created by Dmitry Teplyakov on 13.02.2021.
//

import UIKit

class PhotoDataSource: NSObject, UICollectionViewDataSource {
    var photos = [Photo]()
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return photos.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let identifier = "GalleryCollectionViewCell"
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: identifier, for: indexPath) as! GalleryCollectionViewCell
        let photo = self.photos[indexPath.row]
        cell.updateWith(image: photo.image, photoId: photo.id)
        return cell
    }
    
}
