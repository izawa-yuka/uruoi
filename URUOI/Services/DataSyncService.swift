//
//  DataSyncService.swift
//  URUOI
//
//  Created by USER on 2026/01/26.
//

import Foundation
import SwiftData
import FirebaseFirestore

enum PendingSyncOperation: Codable, Equatable {
    case saveContainer(householdID: String, container: FirestoreContainer)
    case deleteContainer(householdID: String, id: String)
    case saveRecord(householdID: String, record: FirestoreRecord)
    case deleteRecord(householdID: String, id: String)
}

struct PendingSyncOperationStore {
    let key: String
    let userDefaults: UserDefaults

    func load() -> [PendingSyncOperation] {
        guard let data = userDefaults.data(forKey: key) else { return [] }
        do {
            return try JSONDecoder().decode([PendingSyncOperation].self, from: data)
        } catch {
            userDefaults.removeObject(forKey: key)
            print("❌ 保留中の同期データ復元に失敗: \(error.localizedDescription)")
            return []
        }
    }

    func save(_ operations: [PendingSyncOperation]) {
        guard !operations.isEmpty else {
            userDefaults.removeObject(forKey: key)
            return
        }

        do {
            let data = try JSONEncoder().encode(operations)
            userDefaults.set(data, forKey: key)
        } catch {
            print("❌ 保留中の同期データ保存に失敗: \(error.localizedDescription)")
        }
    }
}

/// Firestoreとローカルデータの同期（受信）を担当するサービス
/// - Firestoreの変更をリアルタイムで監視し、SwiftDataに反映します。
final class DataSyncService {
    static let shared = DataSyncService()
    
    private let db = Firestore.firestore()
    private let pendingOperationStore = PendingSyncOperationStore(
        key: "DataSyncService.pendingOperations",
        userDefaults: .standard
    )
    private var containerListener: ListenerRegistration?
    private var recordListener: ListenerRegistration?
    private var pendingOperations: [PendingSyncOperation] = []
    private var pendingRetryTask: Task<Void, Never>?
    
    // 同期中はループを防ぐためにフラグを立てる等の制御が必要になる場合がありますが、
    // 今回は「クラウド正」の簡易実装として、クラウドからの変更をそのまま上書きします。
    
    private init() {
        loadPendingOperations()
    }
    
    /// 同期を開始する
    /// - Parameters:
    ///   - householdID: 監視対象の共有用ID
    ///   - modelContext: SwiftDataのコンテキスト
    func startSync(householdID: String, modelContext: ModelContext) {
        // 既存のリスナーがあれば解除
        stopSync()
        
        print("🔄 同期を開始します (Household: \(householdID))")
        
        // 1. 器（Container）の監視
        let containersRef = db.collection("households").document(householdID).collection("containers")
        containerListener = containersRef.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ 器の同期エラー: \(error.localizedDescription)")
                return
            }
            
            guard let snapshot = snapshot else { return }
            
            Task {
                self.handleContainerChanges(snapshot: snapshot, context: modelContext)
            }
        }
        
        // 2. 記録（Record）の監視
        let recordsRef = db.collection("households").document(householdID).collection("records")
        recordListener = recordsRef.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ 記録の同期エラー: \(error.localizedDescription)")
                return
            }
            
            guard let snapshot = snapshot else { return }
            
            Task {
                self.handleRecordChanges(snapshot: snapshot, context: modelContext)
            }
        }

        Task {
            await retryPendingWrites()
        }
    }
    
    /// 同期を停止する
    func stopSync() {
        containerListener?.remove()
        containerListener = nil
        recordListener?.remove()
        recordListener = nil
        pendingRetryTask?.cancel()
        pendingRetryTask = nil
        print("⏹️ 同期を停止しました")
    }

    func retryPendingWrites() async {
        guard !pendingOperations.isEmpty else { return }

        let operations = pendingOperations
        var failedOperations: [PendingSyncOperation] = []

        for operation in operations {
            do {
                try await send(operation)
            } catch {
                failedOperations.append(operation)
                print("❌ 保留中の同期再送に失敗: \(error.localizedDescription)")
            }
        }

        pendingOperations = failedOperations
        savePendingOperations()

        if !pendingOperations.isEmpty {
            schedulePendingRetry()
        }
    }

    private func schedulePendingRetry() {
        guard pendingRetryTask == nil || pendingRetryTask?.isCancelled == true else { return }
        pendingRetryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(15))
            guard !Task.isCancelled else { return }
            self?.pendingRetryTask = nil
            await self?.retryPendingWrites()
        }
    }

    private func loadPendingOperations() {
        pendingOperations = pendingOperationStore.load()
    }

    private func savePendingOperations() {
        pendingOperationStore.save(pendingOperations)
    }
    
    // MARK: - Internal Handling
    
    /// 器の変更処理
    @MainActor
    private func handleContainerChanges(snapshot: QuerySnapshot, context: ModelContext) {
        for diff in snapshot.documentChanges {
            let doc = diff.document
            
            switch diff.type {
            case .added, .modified:
                guard let firestoreContainer = try? doc.data(as: FirestoreContainer.self) else {
                    print("⚠️ 器データのデコードに失敗: \(doc.documentID)")
                    continue
                }
                guard let uuid = UUID(uuidString: firestoreContainer.id) else { continue }

                // ローカルに存在するか確認
                let descriptor = FetchDescriptor<ContainerMaster>(predicate: #Predicate { $0.id == uuid })
                
                do {
                    let results = try context.fetch(descriptor)
                    
                    if let existingContainer = results.first {
                        // 更新: 本当は変更があったフィールドだけ更新するのが効率的ですが、今回は全上書き
                        existingContainer.name = firestoreContainer.name
                        existingContainer.emptyWeight = firestoreContainer.emptyWeight
                        existingContainer.isArchived = firestoreContainer.isArchived
                        existingContainer.sortOrder = firestoreContainer.sortOrder
                        // createdAtは基本変えないが念のため
                        existingContainer.createdAt = firestoreContainer.createdAt
                        linkRecords(to: existingContainer, containerID: uuid, context: context)
                    } else {
                        // 新規作成
                        let newContainer = ContainerMaster(
                            id: uuid,
                            name: firestoreContainer.name,
                            emptyWeight: firestoreContainer.emptyWeight,
                            isArchived: firestoreContainer.isArchived,
                            createdAt: firestoreContainer.createdAt,
                            sortOrder: firestoreContainer.sortOrder
                        )
                        context.insert(newContainer)
                        linkRecords(to: newContainer, containerID: uuid, context: context)
                    }
                } catch {
                    print("❌ SwiftData fetch error: \(error)")
                }
                
            case .removed:
                // 削除された場合、ローカルからも削除（論理削除かどうかは運用によるが、ここでは物理削除）
                guard let uuid = UUID(uuidString: doc.documentID) else { continue }
                let descriptor = FetchDescriptor<ContainerMaster>(predicate: #Predicate { $0.id == uuid })
                if let results = try? context.fetch(descriptor), let itemToDelete = results.first {
                    context.delete(itemToDelete)
                }
            }
        }
        
        // 保存（オートセーブが効く場合もあるが明示的に）
        do {
            try context.save()
        } catch {
            context.rollback()
            print("❌ 器同期データの保存に失敗: \(error.localizedDescription)")
        }
    }
    
    /// 記録の変更処理
    @MainActor
    private func handleRecordChanges(snapshot: QuerySnapshot, context: ModelContext) {
        for diff in snapshot.documentChanges {
            let doc = diff.document
            
            switch diff.type {
            case .added, .modified:
                guard let firestoreRecord = try? doc.data(as: FirestoreRecord.self) else {
                    print("⚠️ 記録データのデコードに失敗: \(doc.documentID)")
                    continue
                }
                guard let uuid = UUID(uuidString: firestoreRecord.id),
                      let containerUUID = UUID(uuidString: firestoreRecord.containerID) else { continue }

                // 親のContainerを探す（リレーションシップのため）
                let containerDescriptor = FetchDescriptor<ContainerMaster>(predicate: #Predicate { $0.id == containerUUID })
                let container: ContainerMaster?
                do {
                    container = try context.fetch(containerDescriptor).first
                } catch {
                    print("❌ 親コンテナの取得に失敗: \(error.localizedDescription)")
                    continue
                }
                guard let container else {
                    print("⚠️ 親コンテナがないため記録同期を保留: \(doc.documentID)")
                    continue
                }
                
                // レコードを探す
                let descriptor = FetchDescriptor<WaterRecord>(predicate: #Predicate { $0.id == uuid })
                
                do {
                    let results = try context.fetch(descriptor)
                    
                    if let existingRecord = results.first {
                        // 更新
                        existingRecord.startTime = firestoreRecord.startTime
                        existingRecord.startWeight = firestoreRecord.startWeight
                        existingRecord.endTime = firestoreRecord.endTime
                        existingRecord.endWeight = firestoreRecord.endWeight
                        existingRecord.catCount = firestoreRecord.catCount
                        existingRecord.weatherCondition = firestoreRecord.weatherCondition
                        existingRecord.temperature = firestoreRecord.temperature
                        existingRecord.note = firestoreRecord.note
                        existingRecord.containerID = containerUUID
                        existingRecord.container = container
                        existingRecord.createdByDeviceID = firestoreRecord.createdByDeviceID
                    } else {
                        // 新規作成
                        let newRecord = WaterRecord(
                            id: uuid,
                            containerID: containerUUID,
                            startTime: firestoreRecord.startTime,
                            startWeight: firestoreRecord.startWeight,
                            endTime: firestoreRecord.endTime,
                            endWeight: firestoreRecord.endWeight,
                            catCount: firestoreRecord.catCount,
                            weatherCondition: firestoreRecord.weatherCondition,
                            temperature: firestoreRecord.temperature,
                            note: firestoreRecord.note,
                            container: container,
                            createdByDeviceID: firestoreRecord.createdByDeviceID
                        )
                        context.insert(newRecord)
                    }
                } catch {
                    print("❌ SwiftData fetch error (record): \(error)")
                }
                
            case .removed:
                guard let uuid = UUID(uuidString: doc.documentID) else { continue }
                let descriptor = FetchDescriptor<WaterRecord>(predicate: #Predicate { $0.id == uuid })
                if let results = try? context.fetch(descriptor), let itemToDelete = results.first {
                    context.delete(itemToDelete)
                }
            }
        }
        
        do {
            try context.save()
        } catch {
            context.rollback()
            print("❌ 記録同期データの保存に失敗: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func linkRecords(to container: ContainerMaster, containerID: UUID, context: ModelContext) {
        let descriptor = FetchDescriptor<WaterRecord>(
            predicate: #Predicate { $0.containerID == containerID }
        )
        do {
            let records = try context.fetch(descriptor)
            for record in records {
                if record.container?.id != containerID {
                    record.container = container
                }
            }
        } catch {
            print("❌ コンテナと記録の紐づけに失敗: \(error.localizedDescription)")
        }
    }

    // MARK: - Sending Methods (Local -> Cloud)
    
    /// 器をクラウドへ保存（作成・更新）
    /// - Parameters:
    ///   - container: 対象の器
    ///   - householdID: 共有ID
    func saveContainer(_ container: ContainerMaster, householdID: String) async throws {
        let firestoreContainer = FirestoreContainer(from: container)
        let ref = db.collection("households").document(householdID)
            .collection("containers").document(firestoreContainer.id)

        let data = try Firestore.Encoder().encode(firestoreContainer)
        try await ref.setData(data)
    }

    func enqueueSaveContainer(_ container: ContainerMaster, householdID: String) {
        let firestoreContainer = FirestoreContainer(from: container)
        pendingOperations.append(.saveContainer(householdID: householdID, container: firestoreContainer))
        savePendingOperations()
        schedulePendingRetry()
    }
    
    /// 器をクラウドから削除
    func deleteContainer(id: UUID, householdID: String) async throws {
        let ref = db.collection("households").document(householdID)
            .collection("containers").document(id.uuidString)

        try await ref.delete()
    }

    func enqueueDeleteContainer(id: UUID, householdID: String) {
        pendingOperations.append(.deleteContainer(householdID: householdID, id: id.uuidString))
        savePendingOperations()
        schedulePendingRetry()
    }
    
    /// 記録をクラウドへ保存（作成・更新）
    func saveRecord(_ record: WaterRecord, householdID: String) async throws {
        let firestoreRecord = FirestoreRecord(from: record)
        let ref = db.collection("households").document(householdID)
            .collection("records").document(firestoreRecord.id)

        let data = try Firestore.Encoder().encode(firestoreRecord)
        try await ref.setData(data)
    }

    func enqueueSaveRecord(_ record: WaterRecord, householdID: String) {
        let firestoreRecord = FirestoreRecord(from: record)
        pendingOperations.append(.saveRecord(householdID: householdID, record: firestoreRecord))
        savePendingOperations()
        schedulePendingRetry()
    }
    
    /// 記録をクラウドから削除
    func deleteRecord(id: UUID, householdID: String) async throws {
        let ref = db.collection("households").document(householdID)
            .collection("records").document(id.uuidString)

        try await ref.delete()
    }

    func enqueueDeleteRecord(id: UUID, householdID: String) {
        pendingOperations.append(.deleteRecord(householdID: householdID, id: id.uuidString))
        savePendingOperations()
        schedulePendingRetry()
    }

    private func send(_ operation: PendingSyncOperation) async throws {
        switch operation {
        case .saveContainer(let householdID, let container):
            let ref = db.collection("households").document(householdID)
                .collection("containers").document(container.id)
            let data = try Firestore.Encoder().encode(container)
            try await ref.setData(data)
        case .deleteContainer(let householdID, let id):
            let ref = db.collection("households").document(householdID)
                .collection("containers").document(id)
            try await ref.delete()
        case .saveRecord(let householdID, let record):
            let ref = db.collection("households").document(householdID)
                .collection("records").document(record.id)
            let data = try Firestore.Encoder().encode(record)
            try await ref.setData(data)
        case .deleteRecord(let householdID, let id):
            let ref = db.collection("households").document(householdID)
                .collection("records").document(id)
            try await ref.delete()
        }
    }
}
