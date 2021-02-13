//
//  Photo+CoreDataProperties.swift
//  GalleryApp
//
//  Created by Dmitry Teplyakov on 13.02.2021.
//
//

import Foundation
import CoreData


extension Photo {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Photo> {
        return NSFetchRequest<Photo>(entityName: "Photo")
    }

    @NSManaged public var title: String
    @NSManaged public var id: String
    @NSManaged public var secret: String
    @NSManaged public var farm: Int64
    @NSManaged public var server: String
    @NSManaged public var created: Date
    @NSManaged public var url: URL

}

extension Photo : Identifiable {

}
