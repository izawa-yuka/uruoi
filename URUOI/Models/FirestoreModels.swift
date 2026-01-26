//
//  FirestoreModels.swift
//  URUOI
//
//  Created by USER on 2026/01/26.
//

import Foundation

// メモ: FirestoreはSwiftのDate型を自動的にTimestamp型に変換してくれます。
// Codableに準拠させることで、辞書型への変換を自動化します。

// MARK: - FirestoreContainer
/// Firestoreに保存するための器（Container）モデル
struct FirestoreContainer: Codable, Identifiable {
    let id: String // UUIDをStringとして保存
    let name: String
    let emptyWeight: Double
    let isArchived: Bool
    let createdAt: Date
    let sortOrder: Int
    
    // SwiftDataのモデルから変換するためのイニシャライザ
    init(from container: ContainerMaster) {
        self.id = container.id.uuidString
        self.name = container.name
        self.emptyWeight = container.emptyWeight
        self.isArchived = container.isArchived
        self.createdAt = container.createdAt
        self.sortOrder = container.sortOrder
    }
}

// MARK: - FirestoreRecord
/// Firestoreに保存するための記録（Record）モデル
struct FirestoreRecord: Codable, Identifiable {
    let id: String
    let containerID: String
    let startTime: Date
    let startWeight: Double
    let endTime: Date?
    let endWeight: Double?
    let catCount: Int
    let weatherCondition: String?
    let temperature: Double?
    let note: String?
    
    // SwiftDataのモデルから変換するためのイニシャライザ
    init(from record: WaterRecord) {
        self.id = record.id.uuidString
        self.containerID = record.containerID.uuidString
        self.startTime = record.startTime
        self.startWeight = record.startWeight
        self.endTime = record.endTime
        self.endWeight = record.endWeight
        self.catCount = record.catCount
        self.weatherCondition = record.weatherCondition
        self.temperature = record.temperature
        self.note = record.note
    }
}
