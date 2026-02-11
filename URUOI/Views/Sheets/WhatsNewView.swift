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
                            icon: "globe",
                            title: "英語対応",
                            description: "アプリの言語が英語表示に対応しました。端末の設定に合わせて自動で切り替わります。"
                        )
                        
                        featureRow(
                            icon: "person.2.fill", // 共有アイコン
                            title: "共有機能の強化",
                            description: "相手が水を換えた時に通知が届くようになりました。また、履歴画面で「相手の記録」がひと目で分かります。"
                        )
                        
                        featureRow(
                            icon: "pawprint.fill", // 猫の足跡アイコン
                            title: "頭数設定の追加",
                            description: "設定画面から猫ちゃんの頭数を登録できるようになりました。1匹あたりの平均飲水量の計算に使われます。"
                        )
                        
                        featureRow(
                            icon: "hammer.fill", // 修復・安定性向上をイメージ
                            title: "安定性の向上",
                            description: "履歴を削除する際にアプリが終了してしまう不具合など、細かな修正を行いました。"
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
