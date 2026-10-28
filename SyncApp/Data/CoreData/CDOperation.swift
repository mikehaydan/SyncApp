//
//  CDOperation.swift
//  SyncApp
//
//  Created by Mykhailo Haidan on 28/10/2026.
//

import CoreData

@objc(CDOperation)
final class CDOperation: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var fileID: UUID
    @NSManaged var deviceID: String
    @NSManaged var timestamp: Date
    @NSManaged var baseCursor: Int64
    @NSManaged var serverSeq: Int64
    @NSManaged var status: String
    @NSManaged var payload: Data
}
