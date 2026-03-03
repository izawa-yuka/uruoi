import SwiftUI

struct WhatsNewView: View {
    @Environment(\.dismiss) private var dismiss
    var onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    // タイトル
                    Text("アップデートのお知らせ")
                        .font(.title) // 文字サイズを調整して収まりやすく
                        .fontWeight(.bold)
                        .padding(.top, 50)
                        .multilineTextAlignment(.center)
                    
                    // はじめの挨拶
                    Text("いつもURUOIをご利用いただきありがとうございます\n今回のアップデート内容は以下の通りです。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.top, 16)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                    
                    // アップデート内容リスト
                    VStack(alignment: .leading, spacing: 28) {
                        featureRow(
                            icon: "person.crop.circle.fill", // 👤 家族の記録アイコン（履歴画面と同じ系統）
                            title: "家族の記録アイコンを追加",
                            description: "家族共有をご利用の際、自分以外が追加した記録にアイコンが付き、誰が記録したかひと目でわかるようになりました。"
                        )
                        
                        featureRow(
                            icon: "bandage.fill", // 🩹 不具合修正（虫から絆創膏へ変更）
                            title: "履歴画面の不具合を修正",
                            description: "履歴のデータが順不同に表示される、または一部反映されないことがある問題を修正し、常に最新の記録が正確に並ぶよう改善しました。"
                        )
                        
                        featureRow(
                            icon: "star.fill", // ⭐️ レビューのお願い
                            title: "レビューのお願い",
                            description: "設定タブからストアのレビュー画面へ直接アクセスできるようになりました。今後の開発の励みになりますので、使い心地などぜひお聞かせください！"
                        )
                        
                        featureRow(
                            icon: "wrench.adjustable.fill", // 🔧 軽微な修正
                            title: "その他の改善",
                            description: "その他、軽微な修正と動作の安定性向上を行いました。"
                        )
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 40)
            }
            
            // 下部ボタンエリア
            VStack {
                Button(action: {
                    onContinue()
                    dismiss()
                }) {
                    Text("続ける")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.appMain)
                        .cornerRadius(14)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
            .background(Color(UIColor.systemBackground))
        }
    }
    
    // 新機能の行コンポーネント
    // LocalizedStringKeyを受け取るように変更して、多言語対応しやすくしました
    private func featureRow(icon: String, title: LocalizedStringKey, description: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundColor(.appMain)
                .frame(width: 40)
                .padding(.top, 4)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
                
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    WhatsNewView(onContinue: {})
}
