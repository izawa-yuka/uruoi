//
//  DataSyncService.swift
//  URUOI
//
//  Created by USER on 2026/01/26.
//

import Foundation
import SwiftData
import FirebaseFirestore

/// Firestoreとローカルデータの同期（受信）を担当するサービス
/// - Firestoreの変更をリアルタイムで監視し、SwiftDataに反映します。
final class DataSyncService {
    static let shared = DataSyncService()
    
    private let db = Firestore.firestore()
    private var containerListener: ListenerRegistration?
    private var recordListener: ListenerRegistration?
    
    // 同期中はループを防ぐためにフラグを立てる等の制御が必要になる場合がありますが、
    // 今回は「クラウド正」の簡易実装として、クラウドからの変更をそのまま上書きします。
    
    private init() {}
    
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
                await self.handleContainerChanges(snapshot: snapshot, context: modelContext)
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
                await self.handleRecordChanges(snapshot: snapshot, context: modelContext)
            }
        }
    }
    
    /// 同期を停止する
    func stopSync() {
        containerListener?.remove()
        containerListener = nil
        recordListener?.remove()
        recordListener = nil
        print("⏹️ 同期を停止しました")
    }
    
    // MARK: - Internal Handling
    
    /// 器の変更処理
    @MainActor
    private func handleContainerChanges(snapshot: QuerySnapshot, context: ModelContext) {
        for diff in snapshot.documentChanges {
            let doc = diff.document
            
            // FIXME: エラーハンドリング（デコード失敗時など）
            guard let firestoreContainer = try? doc.data(as: FirestoreContainer.self) else {
                print("⚠️ 器データのデコードに失敗: \(doc.documentID)")
                continue
            }
            
            // UUID変換
            guard let uuid = UUID(uuidString: firestoreContainer.id) else { continue }
            
            switch diff.type {
            case .added, .modified:
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
                    }
                } catch {
                    print("❌ SwiftData fetch error: \(error)")
                }
                
            case .removed:
                // 削除された場合、ローカルからも削除（論理削除かどうかは運用によるが、ここでは物理削除）
                let descriptor = FetchDescriptor<ContainerMaster>(predicate: #Predicate { $0.id == uuid })
                if let results = try? context.fetch(descriptor), let itemToDelete = results.first {
                    context.delete(itemToDelete)
                }
            }
        }
        
        // 保存（オートセーブが効く場合もあるが明示的に）
        try? context.save()
    }
    
    /// 記録の変更処理
    @MainActor
    private func handleRecordChanges(snapshot: QuerySnapshot, context: ModelContext) {
        for diff in snapshot.documentChanges {
            let doc = diff.document
            
            guard let firestoreRecord = try? doc.data(as: FirestoreRecord.self) else {
                print("⚠️ 記録データのデコードに失敗: \(doc.documentID)")
                continue
            }
            
            guard let uuid = UUID(uuidString: firestoreRecord.id),
                  let containerUUID = UUID(uuidString: firestoreRecord.containerID) else { continue }
            
            switch diff.type {
            case .added, .modified:
                // 親のContainerを探す（リレーションシップのため）
                let containerDescriptor = FetchDescriptor<ContainerMaster>(predicate: #Predicate { $0.id == containerUUID })
                let container = try? context.fetch(containerDescriptor).first
                
                // コンテナが存在しない場合はスキップ（後で再同期される）
                guard let container = container else {
                    print("⚠️ コンテナID \(containerUUID) が見つかりません。レコード \(uuid) の同期をスキップします。")
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
                let descriptor = FetchDescriptor<WaterRecord>(predicate: #Predicate { $0.id == uuid })
                if let results = try? context.fetch(descriptor), let itemToDelete = results.first {
                    context.delete(itemToDelete)
                }
            }
        }
        
        try? context.save()
    }

    // MARK: - Sending Methods (Local -> Cloud)
    
    /// 器をクラウドへ保存（作成・更新）
    /// - Parameters:
    ///   - container: 対象の器
    ///   - householdID: 共有ID
    func saveContainer(_ container: ContainerMaster, householdID: String) {
        let firestoreContainer = FirestoreContainer(from: container)
        let ref = db.collection("households").document(householdID)
            .collection("containers").document(firestoreContainer.id)
        
        do {
            try ref.setData(from: firestoreContainer)
        } catch {
            print("❌ 器の保存に失敗: \(error.localizedDescription)")
        }
    }
    
    /// 器をクラウドから削除
    func deleteContainer(id: UUID, householdID: String) {
        let ref = db.collection("households").document(householdID)
            .collection("containers").document(id.uuidString)
        
        ref.delete { error in
            if let error = error {
                print("❌ 器の削除に失敗: \(error.localizedDescription)")
            }
        }
    }
    
    /// 記録をクラウドへ保存（作成・更新）
    func saveRecord(_ record: WaterRecord, householdID: String) {
        let firestoreRecord = FirestoreRecord(from: record)
        let ref = db.collection("households").document(householdID)
            .collection("records").document(firestoreRecord.id)
        
        do {
            try ref.setData(from: firestoreRecord)
        } catch {
            print("❌ 記録の保存に失敗: \(error.localizedDescription)")
        }
    }
    
    /// 記録をクラウドから削除
    func deleteRecord(id: UUID, householdID: String) {
        let ref = db.collection("households").document(householdID)
            .collection("records").document(id.uuidString)
        
        ref.delete { error in
            if let error = error {
                print("❌ 記録の削除に失敗: \(error.localizedDescription)")
            }
        }
    }
}
