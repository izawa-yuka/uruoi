//
//  FamilySharingView.swift
//  URUOI
//
//  Created by USER on 2026/01/26.
//

import SwiftUI
import SwiftData

struct FamilySharingView: View {
    @Environment(\.modelContext) private var modelContext
    // 共有用IDを保存（これがある＝家族共有が有効）
    @AppStorage("householdID") private var householdID: String = ""
    // 自分が作成した共有用IDの履歴
    @AppStorage("createdHouseholdID") private var createdHouseholdID: String = ""
    
    @State private var isMigrating = false
    @State private var joinInputID = ""
    @State private var errorMessage = ""
    @State private var showingErrorAlert = false
    @State private var showingJoinAlert = false
    @State private var showingSuccessAlert = false
    @State private var successMessage = ""
    @State private var showingRestoreAlert = false // 復元時の確認用
    @State private var restoreAlertMessage = "" // 復元時のメッセージ（動的）
    @State private var showingRecreateAlert = false // 作り直し時の確認用

    var body: some View {
        List {
            // MARK: - 説明セクション
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("家族共有機能（ベータ版）")
                        .font(.headline)
                    Text("「共有用ID」を使うことで、家族みんなで同じ記録を見ることができます。\n現在のデータはクラウドに安全にバックアップされます。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }
            
            if householdID.isEmpty {
                // MARK: - 未設定の場合
                
                // 1. 新しく共有用IDを作成する（または復元）
                Section(header: Text("はじめての方")) {
                    if !createdHouseholdID.isEmpty {
                        // 履歴がある場合：復元ボタンをメインに
                        VStack(alignment: .leading, spacing: 12) {
                            Text("以前作成した共有用IDが見つかりました")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Button {
                                let idToRestore = createdHouseholdID
                                isMigrating = true
                                Task {
                                    do {
                                        if let date = try await DataMigrationService.shared.fetchLastRecordDate(householdID: idToRestore) {
                                            let formatter = DateFormatter()
                                            formatter.dateStyle = .medium
                                            formatter.timeStyle = .short
                                            formatter.locale = Locale(identifier: "ja_JP")
                                            let dateString = formatter.string(from: date)
                                            restoreAlertMessage = "最終更新: \(dateString)\n\n以前のIDを復元すると、現在この端末に入っているデータは全て削除され、クラウド上のデータに上書きされます。\nよろしいですか？"
                                        } else {
                                            restoreAlertMessage = "データが見つかりませんでしたが、復元しますか？\n（クラウド上のデータに上書きされます）"
                                        }
                                    } catch {
                                        restoreAlertMessage = "データの確認に失敗しました。\nそれでも復元しますか？"
                                    }
                                    DispatchQueue.main.async {
                                        isMigrating = false
                                        showingRestoreAlert = true
                                    }
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                        .foregroundStyle(.blue)
                                    VStack(alignment: .leading) {
                                        Text("以前のIDを復元する")
                                            .fontWeight(.medium)
                                        Text("ID: \(createdHouseholdID)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .disabled(isMigrating)
                            
                            Divider()
                            
                            Button {
                                showingRecreateAlert = true
                            } label: {
                                Text("新しく作り直す")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .disabled(isMigrating)
                        }
                        .padding(.vertical, 4)
                        
                    } else {
                        // 履歴がない場合：通常通り新規作成
                        Button {
                            createHousehold()
                        } label: {
                            HStack {
                                Image(systemName: "house.fill")
                                    .foregroundStyle(.blue)
                                Text("共有用IDを作成する")
                                    .fontWeight(.medium)
                            }
                        }
                        .disabled(isMigrating)
                    }
                }
                
                // 2. 既存の共有に参加する
                Section(header: Text("家族から招待された方")) {
                    VStack(alignment: .leading) {
                        TextField("教えてもらったIDを入力", text: $joinInputID)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                        
                        Button {
                            // いきなり参加せず、確認アラートを出す
                            if !joinInputID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                showingJoinAlert = true
                            }
                        } label: {
                            Text("共有を受ける")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(joinInputID.isEmpty || isMigrating)
                        .padding(.top, 4)
                    }
                    .padding(.vertical, 4)
                }
                
            } else {
                // MARK: - 設定済みの場合
                
                Section(header: Text("現在の共有設定")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("共有用ID")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        HStack {
                            Text(householdID)
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            Button {
                                UIPasteboard.general.string = householdID
                                successMessage = "IDをコピーしました"
                                showingSuccessAlert = true
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.body)
                            }
                            .buttonStyle(.borderless) // リスト内でのボタン競合を防ぐ
                        }
                    }
                    .padding(.vertical, 4)
                    
                    Text("このIDを家族に伝えて、「共有を受ける」をしてもらうことでデータを共有できます。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Section {
                    Button(role: .destructive) {
                        // ログアウト処理（IDを消すだけ。データはクラウドに残る）
                        householdID = ""
                    } label: {
                        Text("家族共有を解除する")
                    }
                } footer: {
                    Text("共有を解除してもデータは消えません。再度同じIDを入力すれば元に戻ります。")
                }
            }
            
            // MARK: - 進捗表示
            if isMigrating {
                Section {
                    HStack {
                        ProgressView()
                            .padding(.trailing, 8)
                        Text("処理中...")
                    }
                }
            }
        }
        .navigationTitle("家族共有")
        .alert("エラー", isPresented: $showingErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("完了", isPresented: $showingSuccessAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(successMessage)
        }
        // 共有開始時の確認アラート
        .alert("データの確認", isPresented: $showingJoinAlert) {
            Button("キャンセル", role: .cancel) { }
            Button("上書きして共有を受ける", role: .destructive) {
                confirmJoinHousehold(id: joinInputID)
            }
        } message: {
            Text("共有を受けると、現在この端末に入っているデータは全て削除され、共有データの情報に上書きされます。\nよろしいですか？")
        }
        // 復元時の確認アラート
        .alert("データの復元", isPresented: $showingRestoreAlert) {
            Button("キャンセル", role: .cancel) { }
            Button("上書きして復元", role: .destructive) {
                confirmJoinHousehold(id: createdHouseholdID)
            }
        } message: {
            Text(restoreAlertMessage)
        }
        // 作り直し時の確認アラート
        .alert("作り直しについて", isPresented: $showingRecreateAlert) {
            Button("キャンセル", role: .cancel) { }
            Button("新しく作る", role: .destructive) {
                createHousehold()
            }
        } message: {
            Text("新しくIDを作成すると、以前のID履歴が上書きされます。\n（古いIDのデータはクラウドに残りますが、このアプリからはアクセスできなくなります）\n\nよろしいですか？")
        }
    }
    
    // MARK: - Actions
    
    /// 新しい共有用IDを作成し、データを移行する
    private func createHousehold() {
        isMigrating = true
        let newID = UUID().uuidString
        
        Task {
            do {
                // 1. ローカルデータを移行
                try await DataMigrationService.shared.migrateToFirestore(householdID: newID, context: modelContext)
                
                // 2. 成功したらIDを保存
                DispatchQueue.main.async {
                    self.householdID = newID
                    self.createdHouseholdID = newID // 履歴にも保存
                    
                    // Force Sync Start
                    DataSyncService.shared.startSync(householdID: newID, modelContext: self.modelContext)
                    
                    self.isMigrating = false
                    self.successMessage = "共有用IDを作成しました！\nまずは古いデータがクラウドにコピーされました。"
                    self.showingSuccessAlert = true
                }
            } catch {
                DispatchQueue.main.async {
                    self.isMigrating = false
                    self.errorMessage = "データの移行に失敗しました。\n\(error.localizedDescription)"
                    self.showingErrorAlert = true
                }
            }
        }
    }
    
    /// 既存の共有に参加する（確認後の実行）
    /// 既存の共有に参加する（確認後の実行）
    /// - Parameter id: 参加または復元するID
    private func confirmJoinHousehold(id: String) {
        let targetID = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !targetID.isEmpty else { return }
        
        isMigrating = true // ロック
        
        Task {
            do {
                // 1. ローカルデータを全削除
                try DataMigrationService.shared.clearLocalData(context: modelContext)
                
                // 2. IDを設定（これによりContentViewで同期が開始される）
                DispatchQueue.main.async {
                    self.householdID = targetID
                    
                    // Force Sync Start
                    DataSyncService.shared.startSync(householdID: targetID, modelContext: self.modelContext)
                    
                    self.isMigrating = false
                    
                    if targetID == self.createdHouseholdID {
                         self.successMessage = "以前のIDを復元しました！\nまもなくデータが同期されます。"
                    } else {
                         self.successMessage = "共有を受けました！\nまもなくデータが同期されます。"
                    }
                    
                    self.showingSuccessAlert = true
                    self.joinInputID = "" // 入力欄クリア
                }
            } catch {
                DispatchQueue.main.async {
                    self.isMigrating = false
                    self.errorMessage = "データの削除に失敗しました。\n\(error.localizedDescription)"
                    self.showingErrorAlert = true
                }
            }
        }
    }
    
    // 古い joinHousehold は削除
}

#Preview {
    NavigationView {
        FamilySharingView()
    }
}
