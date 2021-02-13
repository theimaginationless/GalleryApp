//
//  ImageStore.swift
//  GalleryApp
//
//  Created by Dmitry Teplyakov on 13.02.2021.
//

import UIKit

class ImageStore {
    let cache = NSCache<NSString, UIImage>()
    private let previewKeyPrefix = "preview"
    lazy var docDirectories = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    lazy var documentDirectory = self.docDirectories.first!
    
    func setImage(_ image: UIImage, forId id: String) {
        let imageURL = self.imageURLFor(id: id)
        
        if let data = image.jpegData(compressionQuality: 1) {
            try! data.write(to: imageURL)
        }
        self.cache.setObject(image, forKey: NSString(string: id))
    }
    
    func imageFor(id: String) -> UIImage? {
        if let image = self.cache.object(forKey: NSString(string: id)) {
            return image
        }

        let imageURL = self.imageURLFor(id: id)
        guard let image = UIImage(contentsOfFile: imageURL.path) else {
            return nil
        }

        self.cache.setObject(image, forKey: NSString(string: id))
        return image
    }
    
    func deleteImageFor(id: String) {
        self.cache.removeObject(forKey: NSString(string: id))
        let imageURL = self.imageURLFor(id: id)
        try! FileManager.default.removeItem(atPath: imageURL.path)
    }
    
    func setImagePreview(_ image: UIImage, forId id: String) {
        self.setImage(image, forId: "\(self.previewKeyPrefix)_\(id)")
    }
    
    func imagePreviewFor(id: String) -> UIImage? {
        return self.imageFor(id: "\(self.previewKeyPrefix)_\(id)")
    }
    
    func deleteImagePreviewFor(id: String) {
        self.deleteImageFor(id: "\(self.previewKeyPrefix)_\(id)")
    }
    
    func imageURLFor(id: String) -> URL {
        return documentDirectory.appendingPathComponent(id)
    }
    
    func imagePreviewURLFor(id: String) -> URL {
        return documentDirectory.appendingPathComponent("\(self.previewKeyPrefix)_\(id)")
    }
    
    func resetAllImages() {
        let urls = try! FileManager.default.contentsOfDirectory(atPath: self.documentDirectory.path)
        urls.forEach{try? FileManager.default.removeItem(atPath: $0)}
    }
}
