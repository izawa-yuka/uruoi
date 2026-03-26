import Foundation
import SwiftData

/// スクリーンショット撮影用のダミーデータを生成するクラス
/// （リリースビルドにも含まれますが、開発用メニューからのみ呼び出されます）
#if DEBUG
final class DebugDataManager {
    @MainActor
    static func injectSampleData(context: ModelContext) {
        // 1. 既存データの削除
        try? context.delete(model: ContainerMaster.self)
        try? context.delete(model: WaterRecord.self)
        
        // 2. 言語判定とワードリストの準備
        let isEnglish = Locale.current.language.languageCode?.identifier == "en"
        
        let bowlNames = isEnglish 
            ? ["Living Room", "Kitchen", "Bedroom", "Cage", "Office"]
            : ["リビング", "キッチン", "寝室", "ケージ", "仕事部屋"]
            
        let memos = isEnglish 
            ? ["Refilled", "Fresh water", "Cleaned", "Drank well!", ""]
            : ["水換え", "新鮮な水", "洗った", "よく飲んだ！", ""]
            
        // 3. 器の作成
        var containers: [ContainerMaster] = []
        for name in bowlNames {
             // 少し重さをランダムに
             let emptyWeight = Double(Int.random(in: 200...400))
             let container = ContainerMaster(name: name, emptyWeight: emptyWeight)
             context.insert(container)
             containers.append(container)
        }
        
        // 4. 過去30日間のデータを生成（複数日跨ぎのテストのため量と期間を調整）
        let calendar = Calendar.current
        let today = Date()
        let catCount = AppSettings.shared.numberOfPets
        
        for i in 0..<30 {
            // 2日に1回前後のペースで水換えしたと想定（すべての日にレコードが存在しなくてもよい）
            if Int.random(in: 1...10) > 7 { continue }
            
            guard let date = calendar.date(byAdding: .day, value: -i, to: today) else { continue }
            
            // 1日あたり 1〜2件の記録
            let recordCount = Int.random(in: 1...2)
            
            for _ in 0..<recordCount {
                // 時間をランダムに分散 (朝6時〜夜10時)
                let hour = Int.random(in: 6...22)
                let minute = Int.random(in: 0...59)
                guard let startTime = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date) else { continue }
                
                // 新機能をテストするため、回収までの時間を「12時間〜96時間（0.5日〜4日）」に変更
                let durationMinutes = Int.random(in: 12*60...96*60)
                guard let endTime = calendar.date(byAdding: .minute, value: durationMinutes, to: startTime) else { continue }
                
                if endTime > Date() { continue }
                
                // 器とメモをランダム選択
                let container = containers.randomElement()!
                let memo = memos.randomElement() ?? ""
                
                // 数値の生成（複数日跨ぐため量も多めに設定）
                let startWeight = Double(Int.random(in: 500...1000))
                let endWeight = Double(Int.random(in: 50...400))
                
                if endWeight >= startWeight { continue }
                
                let record = WaterRecord(
                    containerID: container.id,
                    startTime: startTime,
                    startWeight: startWeight,
                    endTime: endTime,
                    endWeight: endWeight,
                    catCount: catCount,
                    weatherCondition: nil,
                    temperature: nil,
                    note: memo,
                    container: container
                )
                
                context.insert(record)
            }
        }
        
        try? context.save()
        print("✅ Localized sample data injected successfully: \(isEnglish ? "English" : "Japanese") mode")
    }
}
#endif
