import SwiftUI

// カスタム角丸を特定の角のみに適用する拡張
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
    
    /// アプリ全体で統一されたドロップシャドウを適用（くっきりとした質感）
    func commonShadow() -> some View {
        self.shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Corner Radius Constants
extension CGFloat {
    /// カード用の角丸
    static let cardCornerRadius: CGFloat = 16
    /// ボタン用の角丸
    static let buttonCornerRadius: CGFloat = 12
    /// アラート用の角丸
    static let alertCornerRadius: CGFloat = 12
    /// テキストフィールド用の角丸
    static let textFieldCornerRadius: CGFloat = 12
}

// MARK: - Custom TextField Style
extension View {
    /// アプリ共通のテキストフィールドスタイル（白背景、角丸枠線）
    func customTextFieldStyle() -> some View {
        self
            .textFieldStyle(.plain)
            .padding(12)
            .background(Color.white)
            .cornerRadius(.buttonCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: .buttonCornerRadius)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
    }
    
    /// 数値入力用キーボードに「完了」ボタンを追加（safeAreaInset方式）
    func keyboardToolbar(focus: FocusState<Bool>.Binding) -> some View {
        self.safeAreaInset(edge: .bottom) {
            if focus.wrappedValue {
                VStack(spacing: 0) {
                    Divider()
                    HStack {
                        Spacer()
                        Button("完了") {
                            focus.wrappedValue = false
                        }
                        .fontWeight(.bold)
                        .foregroundColor(.appMain)
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                    }
                    .background(Color(uiColor: .systemBackground))
                }
            }
        }
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

