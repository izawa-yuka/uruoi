//
//  AppSettings.swift
//  URUOI
//
//  Created by USER on 2026/01/01.
//

import Foundation
import SwiftUI

/// アプリの設定を管理（UserDefaults/AppStorage）
@Observable
final class AppSettings {
    static let shared = AppSettings()
    
    @ObservationIgnored
    @AppStorage("defaultCatCount") var defaultCatCount: Int = 2
    
    @ObservationIgnored
    @AppStorage("alertThreshold") var alertThreshold: Int = 50 // ml
    
    @ObservationIgnored
    @AppStorage("isProMember") var isProMember: Bool = false
    
    // 【重要】ここが追加されている必要があります
    @ObservationIgnored
    @ObservationIgnored
    @AppStorage("waterReminderDays") var waterReminderDays: Int = 1
    
    @ObservationIgnored
    @AppStorage("isWaterAlertEnabled") var isWaterAlertEnabled: Bool = true
    
    private init() {}
}
