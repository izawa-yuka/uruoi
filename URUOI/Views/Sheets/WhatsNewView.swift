import SwiftUI

struct WhatsNewView: View {
    @Environment(\.dismiss) private var dismiss
    var onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 40) {
                    // タイトル
                    Text("新機能のお知らせ")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top, 60)
                        .multilineTextAlignment(.center)
                    
                    // 新機能リスト
                    VStack(alignment: .leading, spacing: 30) {
                        featureRow(
                            icon: "pawprint.fill",
                            title: "頭数設定の追加",
                            description: "設定画面からペットの頭数を登録できるようになりました。1匹あたりの平均飲水量の計算に使われます。"
                        )
                        
                        featureRow(
                            icon: "wrench.and.screwdriver.fill",
                            title: "不具合の修正",
                            description: "平均値の計算が正しく反映されない問題や、履歴削除時の不具合などを修正しました。"
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
