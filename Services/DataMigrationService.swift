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
        
        // 2. バッチ書き込みの準備
        // Note: Firestoreのバッチは最大500件まで。超える場合は分割が必要だが、
        // 個人利用であれば500件を超えることは稀と想定し、まずはシンプルに実装。
        // もしデータ量が多い場合は分割ロジックを追加する。
        
        let batch = db.batch()
        
        // コンテナの追加
        for container in containers {
            let firestoreContainer = FirestoreContainer(from: container)
            let ref = db.collection("households").document(householdID)
                        .collection("containers").document(firestoreContainer.id)
            
            try batch.setData(from: firestoreContainer, forDocument: ref)
        }
        
        // 記録の追加
        for record in records {
            let firestoreRecord = FirestoreRecord(from: record)
            let ref = db.collection("households").document(householdID)
                        .collection("records").document(firestoreRecord.id)
            
            try batch.setData(from: firestoreRecord, forDocument: ref)
        }
        
        // 3. コミット（アップロード実行）
        try await batch.commit()
        
        print("✅ データ移行完了: Containers: \(containers.count), Records: \(records.count)")
    }
    
    /// ローカルのデータを全て削除する（共有開始時の上書き用）
    /// - Parameter context: SwiftDataのコンテキスト
    func clearLocalData(context: ModelContext) throws {
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
