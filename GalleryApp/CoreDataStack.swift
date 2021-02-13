//
//  CoreDataStack.swift
//  GalleryApp
//
//  Created by Dmitry Teplyakov on 13.02.2021.
//

import Foundation
import CoreData

class CoreDataStack {
    let managedObjectModelName: String
    private lazy var managedObjectModel: NSManagedObjectModel = {
        let modelURL = Bundle.main.url(forResource: self.managedObjectModelName, withExtension: "momd")!
        return NSManagedObjectModel(contentsOf: modelURL)!
    }()
    private lazy var appDocumentsDirectory: URL = {
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return urls.first!
    }()
    private lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator = {
        var coordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        let pathComponent = "\(self.managedObjectModelName).sqlite"
        let url = self.appDocumentsDirectory.appendingPathComponent(pathComponent)
        let store = try! coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: nil)
        return coordinator
    }()
    lazy var privateQueueCtx: NSManagedObjectContext = {
        let poc = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        poc.persistentStoreCoordinator = self.persistentStoreCoordinator
        poc.name = "me.theimless.galleryApp.PrivateQueueContext"
        return poc
    }()
    lazy var mainQueueCtx: NSManagedObjectContext = {
        let moc = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        moc.parent = self.privateQueueCtx
        moc.name = "me.theimless.galleryApp.MainQueueContext"
        return moc
    }()
    
    func saveChanges() {
        self.mainQueueCtx.performAndWait {
            do {
                if self.mainQueueCtx.hasChanges {
                    try self.mainQueueCtx.save()
                }
            }
            catch let localError {
                print("Error saving \(self.mainQueueCtx.name!) context:\n\(localError)")
            }
        }
        
        self.privateQueueCtx.perform {
            do {
                if self.privateQueueCtx.hasChanges {
                    try self.privateQueueCtx.save()
                }
            }
            catch let localError {
                print("Error saving \(self.privateQueueCtx.name!) context:\n\(localError)")
            }
        }
    }
    
    required init(modelName: String) {
        self.managedObjectModelName = modelName
    }
}
