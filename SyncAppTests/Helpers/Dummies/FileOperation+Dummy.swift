//
//  FileOperation+Dummy.swift
//  SyncAppTests
//
//  Created by Mykhailo Haidan on 28/10/2026.
//

@testable import SyncApp
import Foundation

extension FileOperation {
    static func dummy(
        id: UUID = UUID(),
        fileID: UUID = UUID(),
        deviceID: String = "device-a",
        timestamp: Date = Date(),
        baseCursor: Int = 0,
        kind: OperationKind = .rename("Dummy"),
        serverSeq: Int? = nil,
        status: OperationStatus = .pending
    ) -> FileOperation {
        FileOperation(
            id: id,
            fileID: fileID,
            deviceID: deviceID,
            timestamp: timestamp,
            baseCursor: baseCursor,
            kind: kind,
            serverSeq: serverSeq,
            status: status
        )
    }
}
