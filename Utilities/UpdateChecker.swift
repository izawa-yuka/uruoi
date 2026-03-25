import Foundation

struct AppStoreLookupResponse: Decodable {
    let results: [AppStoreAppInfo]
}

struct AppStoreAppInfo: Decodable {
    let version: String
}

enum UpdateChecker {
    /// App Storeの最新バージョンを確認し、アップデートが存在するかどうかを返します。
    static func checkUpdate() async throws -> Bool {
        // AppConfig.updateCheckAPIURL: https://itunes.apple.com/jp/lookup?id=6757776163
        let url = AppConfig.updateCheckAPIURL
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return false
        }
        
        let decoder = JSONDecoder()
        let storeResponse = try decoder.decode(AppStoreLookupResponse.self, from: data)
        
        guard let latestVersion = storeResponse.results.first?.version else {
            return false
        }
        
        guard let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            return false
        }
        
        // compare(_:options: .numeric) を使用してセマンティックバージョニングを比較
        // latestVersion(例: 1.11) > currentVersion(例: 1.2) の場合、orderedDescending となる
        let result = latestVersion.compare(currentVersion, options: .numeric)
        return result == .orderedDescending
    }
}
