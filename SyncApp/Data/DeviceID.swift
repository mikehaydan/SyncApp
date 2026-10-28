//
//  DeviceID.swift
//  SyncApp
//
//  Created by Mykhailo Haidan on 28/10/2026.
//

import Foundation

enum DeviceID {
    static var current: String {
        let key = "sync.deviceID"
        if let saved = UserDefaults.standard.string(forKey: key) {
            return saved
        }
        let created = UUID().uuidString
        UserDefaults.standard.set(created, forKey: key)
        return created
    }
}
