import Foundation
import SwiftData

@Model
final class Bowl {
    var name: String
    var weight: Double
    // 他に必要な項目があれば追加してください
    
    init(name: String, weight: Double) {
        self.name = name
        self.weight = weight
    }
}
