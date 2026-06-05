//
//  DataMigrationService.swift
//  URUOI
//
//  Created by USER on 2026/01/26.
//

import Foundation
import SwiftData
import FirebaseFirestore

/// データの移行（ローカル → Firestore）を担当するサービス
/// シングルトンとして実装
final class DataMigrationService {
    static let shared = DataMigrationService()

    private let db = Firestore.firestore()

    private init() {}

    /// ローカルのデータをFirestoreへコピーする
    /// - Parameters:
    ///   - householdID: 移行先の共有用ID
    ///   - context: SwiftDataのコンテキスト（データ取得用）
    func migrateToFirestore(householdID: String, context: ModelContext) async throws {
        // 1. ローカルデータの取得
        let containerDescriptor = FetchDescriptor<ContainerMaster>()
        let recordDescriptor = FetchDescriptor<WaterRecord>()

        let containers = try context.fetch(containerDescriptor)
        let records = try context.fetch(recordDescriptor)

        // データがない場合は何もしない
        if containers.isEmpty && records.isEmpty {
            return
        }

        // 2. Firestoreのバッチ上限を避けるため、450件ごとに分割して書き込む
        let batchLimit = 450
        var batch = db.batch()
        var writeCount = 0

        // コンテナの追加
        for container in containers {
            let firestoreContainer = FirestoreContainer(from: container)
            let ref = db.collection("households").document(householdID)
                        .collection("containers").document(firestoreContainer.id)

            try batch.setData(from: firestoreContainer, forDocument: ref)
            writeCount += 1
            if writeCount >= batchLimit {
                try await batch.commit()
                batch = db.batch()
                writeCount = 0
            }
        }

        // 記録の追加
        for record in records {
            let firestoreRecord = FirestoreRecord(from: record)
            let ref = db.collection("households").document(householdID)
                        .collection("records").document(firestoreRecord.id)

            try batch.setData(from: firestoreRecord, forDocument: ref)
            writeCount += 1
            if writeCount >= batchLimit {
                try await batch.commit()
                batch = db.batch()
                writeCount = 0
            }
        }

        // 3. コミット（アップロード実行）
        if writeCount > 0 {
            try await batch.commit()
        }

        print("✅ データ移行完了: Containers: \(containers.count), Records: \(records.count)")
    }

    /// ローカルのデータを全て削除する（共有開始時の上書き用）
    /// - Parameter context: SwiftDataのコンテキスト
    func clearLocalData(context: ModelContext) throws {
        do {
            // 全てのコンテナと記録を取得して削除
            // deleteRule: .cascade が設定されているため、Containerを削除すればRecordも消えるはずだが、
            // 念のため明示的に削除を行う（あるいはContainerIDを持たないRecordがある可能性も考慮）

            // 1. レコードの削除
            try context.delete(model: WaterRecord.self)

            // 2. コンテナの削除
            try context.delete(model: ContainerMaster.self)

            // 3. 保存
            try context.save()

            print("🗑️ ローカルデータを全削除しました")
        } catch {
            context.rollback()
            throw error
        }
    }

    /// 共有先データを取得できることを確認してから、ローカルを置き換える
    @MainActor
    func replaceLocalDataFromCloud(householdID: String, context: ModelContext) async throws {
        let householdRef = db.collection("households").document(householdID)
        async let containersSnapshot = householdRef.collection("containers").getDocuments()
        async let recordsSnapshot = householdRef.collection("records").getDocuments()
        let (containers, records) = try await (containersSnapshot, recordsSnapshot)

        let cloudContainers = try containers.documents.map { try $0.data(as: FirestoreContainer.self) }
        guard !cloudContainers.isEmpty else {
            throw DataMigrationError.emptyCloudData
        }
        let cloudRecords = try records.documents.map { try $0.data(as: FirestoreRecord.self) }

        do {
            try context.delete(model: WaterRecord.self)
            try context.delete(model: ContainerMaster.self)

            var containerByID: [UUID: ContainerMaster] = [:]
            for cloudContainer in cloudContainers {
                guard let containerID = UUID(uuidString: cloudContainer.id) else { continue }
                let container = ContainerMaster(
                    id: containerID,
                    name: cloudContainer.name,
                    emptyWeight: cloudContainer.emptyWeight,
                    isArchived: cloudContainer.isArchived,
                    createdAt: cloudContainer.createdAt,
                    sortOrder: cloudContainer.sortOrder
                )
                containerByID[containerID] = container
                context.insert(container)
            }

            for cloudRecord in cloudRecords {
                guard let recordID = UUID(uuidString: cloudRecord.id),
                      let containerID = UUID(uuidString: cloudRecord.containerID) else {
                    continue
                }
                guard let container = containerByID[containerID] else {
                    print("⚠️ 親コンテナがない記録をスキップ: \(cloudRecord.id)")
                    continue
                }
                let record = WaterRecord(
                    id: recordID,
                    containerID: containerID,
                    startTime: cloudRecord.startTime,
                    startWeight: cloudRecord.startWeight,
                    endTime: cloudRecord.endTime,
                    endWeight: cloudRecord.endWeight,
                    catCount: cloudRecord.catCount,
                    weatherCondition: cloudRecord.weatherCondition,
                    temperature: cloudRecord.temperature,
                    note: cloudRecord.note,
                    container: container,
                    createdByDeviceID: cloudRecord.createdByDeviceID
                )
                context.insert(record)
            }

            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    /// 共有先に器データが存在するか確認する
    /// - Parameter householdID: 確認する共有用ID
    /// - Returns: containers に1件以上ある場合は true
    func hasCloudData(householdID: String) async throws -> Bool {
        let householdRef = db.collection("households").document(householdID)
        let containers = try await householdRef.collection("containers").limit(to: 1).getDocuments()
        return !containers.documents.isEmpty
    }

    /// 最新の記録日時を取得する（復元時の確認用）
    /// - Parameter householdID: 共有用ID
    /// - Returns: 最新の records.startTime（データがない場合はnil）
    func fetchLastRecordDate(householdID: String) async throws -> Date? {
        let snapshot = try await db.collection("households").document(householdID)
            .collection("records")
            .order(by: "startTime", descending: true)
            .limit(to: 1)
            .getDocuments()

        guard let document = snapshot.documents.first else {
            return nil
        }

        let record = try document.data(as: FirestoreRecord.self)
        return record.startTime
    }
}

enum DataMigrationError: LocalizedError {
    case emptyCloudData

    var errorDescription: String? {
        switch self {
        case .emptyCloudData:
            return "共有用IDが見つからないか、共有データが空です。IDを確認してください。"
        }
    }
}
