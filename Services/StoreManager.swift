//
//  StoreManager.swift
//  URUOI
//
//  Created by USER on 2026/01/01.
//

import Foundation
import StoreKit

@Observable
final class StoreManager {
    static let shared = StoreManager()
    
    var isProMember: Bool = false
    var products: [Product] = []
    private var updates: Task<Void, Never>? = nil

    private init() {
        // トランザクション監視を開始
        updates = newTransactionListenerTask()
        
        // 起動時に製品情報のロードと権利確認を行う
        Task {
            await loadProducts()
            await updatePurchasedStatus()
        }
    }
    
    deinit {
        updates?.cancel()
    }
    
    struct ProductID {
        /// 買い切りプラン（非消耗型）
        static let lifetime = "com.hebereke.uruoi.lifetime"
        
        /// 月額サブスクリプション
        static let monthly = "com.hebereke.uruoi.monthly"
        
        /// 年額サブスクリプション
        static let yearly = "com.hebereke.uruoi.yearly"
        
        static var all: Set<String> {
            [lifetime, monthly, yearly]
        }
    }
    
    // MARK: - API
    
    @MainActor
    func loadProducts() async {
        do {
            self.products = try await Product.products(for: ProductID.all)
        } catch {
            print("Failed to load products: \(error)")
        }
    }
    
    @MainActor
    func purchaseLifetime() async {
        guard let product = products.first(where: { $0.id == ProductID.lifetime }) else {
            print("Lifetime product not found")
            return
        }
        try? await purchase(product)
    }
    
    @MainActor
    func purchaseSubscription(planId: String) async {
        guard let product = products.first(where: { $0.id == planId }) else {
            print("Subscription product \(planId) not found")
            return
        }
        try? await purchase(product)
    }
    
    @MainActor
    func restorePurchases() async throws {
        try? await AppStore.sync()
        await updatePurchasedStatus()
    }
    
    // MARK: - Internal Logic
    
    @MainActor
    private func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            // 署名検証
            let transaction = try checkVerified(verification)
            
            // 権利付与
            await updatePurchasedStatus()
            
            // トランザクション完了
            await transaction.finish()
            
        case .userCancelled, .pending:
            break
        @unknown default:
            break
        }
    }

    private func newTransactionListenerTask() -> Task<Void, Never> {
        Task(priority: .background) {
            for await verification in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(verification)
                    await self.updatePurchasedStatus()
                    await transaction.finish()
                } catch {
                    print("Transaction failed verification")
                }
            }
        }
    }
    
    enum PlanStatus {
        case lifetime
        case monthly
        case yearly
        case free
    }
    
    var currentPlan: PlanStatus = .free

    // ... (existing code helpers if needed)

    @MainActor
    func updatePurchasedStatus() async {
        var hasActiveStatus = false
        var activePlan: PlanStatus = .free
        
        // 現在の有効な権利を確認
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                // 該当するプロダクトIDであれば有効とみなす
                if ProductID.all.contains(transaction.productID) {
                    hasActiveStatus = true
                    
                    // プラン判定
                    switch transaction.productID {
                    case ProductID.lifetime:
                        activePlan = .lifetime
                    case ProductID.monthly:
                        activePlan = .monthly
                    case ProductID.yearly:
                        activePlan = .yearly
                    default:
                        break
                    }
                }
            } catch {
                print("Failed to verify entitlement")
            }
        }
        
        self.isProMember = hasActiveStatus
        self.currentPlan = activePlan
        
        // AppStorageとの同期は View 側で行われているケースが多いが、
        // ここでも念のため同期しておく（SettingsViewModelなどがUserDefaultsを見ているため）
        UserDefaults.standard.set(hasActiveStatus, forKey: "isProMember")
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        // JWS署名の検証
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    enum StoreError: Error {
        case failedVerification
    }
}

