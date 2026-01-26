import SwiftUI
import SwiftData
import FirebaseCore

@main
struct URUOIApp: App {
    // Firebase初期化のためのAppDelegateアダプター
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    // データベース（SwiftData）のセットアップ
    var sharedModelContainer: ModelContainer = {
        // 使用するデータモデルを定義
        let schema = Schema([
            // ⚠️ Bowl ではなく、他の画面で使っている ContainerMaster に合わせました
            ContainerMaster.self,
            WaterRecord.self
        ])
        
        // 保存先の設定
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            // データ追加ロジックは削除済みなので、ここでは単純にコンテナを返すだけです
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            // UserSettings の environmentObject も削除済み（ContentView内で @AppStorage を使うため不要）
            ContentView()
        }
        // SwiftDataのコンテナを適用
        .modelContainer(sharedModelContainer)
    }
}

// MARK: - AppDelegate
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Firebaseの初期化（ここがFirestoreを使うためのスイッチオンの役割）
        FirebaseApp.configure()
        return true
    }
}
