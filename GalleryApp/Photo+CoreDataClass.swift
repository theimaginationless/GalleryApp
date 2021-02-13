//
//  Photo+CoreDataClass.swift
//  GalleryApp
//
//  Created by Dmitry Teplyakov on 13.02.2021.
//
//

import UIKit
import CoreData

@objc(Photo)
public class Photo: NSManagedObject {
    class func buildImageUrl(id: String, server: String, farm: Int, secret: String, size: ImageSize) -> URL {
        var sizeString = ""
        switch size {
        case .original:
            sizeString = "_o"
        case .medium:
            sizeString = "_m"
        case .small:
            sizeString = "_s"
        case .reserved:
            sizeString = "_b"
        case .standard:
            break
        }
        let urlString = "https://farm\(farm).staticflickr.com/\(server)/\(id)_\(secret)\(sizeString).jpg"
        return URL(string: urlString)!
    }
    
    var image: UIImage?
    var imagePreview: UIImage?
    lazy var url_s: URL = {
        Photo.buildImageUrl(id: self.id, server: self.server, farm: Int(self.farm), secret: self.secret, size: .small)
    }()
    lazy var url_m: URL = {
        Photo.buildImageUrl(id: self.id, server: self.server, farm: Int(self.farm), secret: self.secret, size: .medium)
    }()
    lazy var url_o: URL = {
        Photo.buildImageUrl(id: self.id, server: self.server, farm: Int(self.farm), secret: self.secret, size: .original)
    }()
    lazy var url_b: URL = {
        Photo.buildImageUrl(id: self.id, server: self.server, farm: Int(self.farm), secret: self.secret, size: .reserved)
    }()
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        self.title = ""
        self.id = ""
        self.secret = ""
        self.farm = 0
        self.server = ""
        self.url = URL(string: "empty")!
        self.created = Date()
    }
}
