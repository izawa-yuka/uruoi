import Foundation

/// アプリ全体で使用する定数・設定
struct AppConfig {
    // 利用規約
    static let termsURL = URL(string: "https://gentlesong.tech/uruoi/terms.html")!
    
    // プライバシーポリシー
    static let privacyPolicyURL = URL(string: "https://gentlesong.tech/uruoi/privacy.html")!
    
    // よくある質問
    static let faqURL = URL(string: "https://alive-galliform-e53.notion.site/URUOI-2decf0f2e6aa80859cb6d4dcb00c6738?source=copy_link")!
    
    // お問い合わせ
    static let supportURL = URL(string: "https://docs.google.com/forms/d/e/1FAIpQLSe0Xdk_P7sMJupxluDGtE-YrroVIKzi3DHetZ65MTQ8KzWS6A/viewform?usp=dialog")!
    
    // レビュー（App Store）
    static let reviewURL = URL(string: "https://apps.apple.com/app/id6757776163?action=write-review")!
    
    // ストア画面への遷移URL（アップデート用）
    static let storeURL = URL(string: "https://apps.apple.com/app/id6757776163")!
    
    // アップデートチェックAPI（iTunes Lookup）
    static let updateCheckAPIURL = URL(string: "https://itunes.apple.com/jp/lookup?id=6757776163")!
}
