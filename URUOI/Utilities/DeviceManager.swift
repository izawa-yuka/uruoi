//
//  DeviceManager.swift
//  URUOI
//
//  自身のデバイスを識別するためのユーティリティ
//  家族共有機能で「誰が記録したか」を判別するために使用します。
//

import UIKit

/// デバイスIDを管理するユーティリティ
/// - アプリの再インストールで `identifierForVendor` が変わる場合に備え、
///   初回取得時にUserDefaultsへ保存し、以降は安定したIDを返します。
enum DeviceManager {
    private static let key = "savedDeviceID"
    
    /// 現在のデバイスID（安定版）
    /// - 初回取得時にUserDefaultsへ保存し、以降はそこから読み出します。
    /// - 万が一取得できない場合は空文字を返します。
    static var currentDeviceID: String {
        // すでに保存済みならそれを返す
        if let saved = UserDefaults.standard.string(forKey: key), !saved.isEmpty {
            return saved
        }
        
        // 初回: identifierForVendor から取得して保存
        let id = UIDevice.current.identifierForVendor?.uuidString ?? ""
        if !id.isEmpty {
            UserDefaults.standard.set(id, forKey: key)
        }
        return id
    }
}
