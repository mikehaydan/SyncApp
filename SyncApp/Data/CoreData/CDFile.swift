//
//  CDFile.swift
//  SyncApp
//
//  Created by Mykhailo Haidan on 28/10/2026.
//

import CoreData

@objc(CDFile)
final class CDFile: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var folderID: UUID
    @NSManaged var tags: Data
}
