//
//  VideoPurchaseStore.swift
//  blog.k100
//

import Foundation
import Combine
import StoreKit

@MainActor
final class VideoPurchaseStore: ObservableObject {
    @Published var products: [Product] = []
    @Published var purchasedProductIds: Set<String> = []

    private var updateTask: Task<Void, Never>?

    init() {
        updateTask = listenForTransactions()
    }

    deinit {
        updateTask?.cancel()
    }

    func loadProducts(productIds: [String]) async {
        let uniqueIds = Array(Set(productIds)).filter { !$0.isEmpty }

        guard !uniqueIds.isEmpty else {
            products = []
            print("⚠️ productIds が空です")
            return
        }

        do {
            products = try await Product.products(for: uniqueIds)
            print("✅ StoreKit 商品取得:", products.map { $0.id })
        } catch {
            products = []
            print("❌ StoreKit 商品取得失敗:", error.localizedDescription)
        }
    }

    func purchase(product: Product) async {
        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                purchasedProductIds.insert(transaction.productID)
                await transaction.finish()
                print("✅ 購入成功:", transaction.productID)

            case .userCancelled:
                print("⚠️ 購入キャンセル")

            case .pending:
                print("⏳ 購入保留中")

            @unknown default:
                print("⚠️ 不明な購入結果")
            }

        } catch {
            print("❌ 購入失敗:", error.localizedDescription)
        }
    }

    func updatePurchasedProducts() async {
        purchasedProductIds.removeAll()

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                purchasedProductIds.insert(transaction.productID)
            } catch {
                print("❌ 購入済み検証失敗")
            }
        }

        print("✅ 購入済み商品:", purchasedProductIds)
    }

    func isPurchased(productId: String) -> Bool {
        guard !productId.isEmpty else { return false }
        return purchasedProductIds.contains(productId)
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe):
            return safe

        case .unverified:
            throw NSError(
                domain: "StoreKitVerification",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "購入情報を検証できませんでした"]
            )
        }
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            guard let self else { return }

            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    self.purchasedProductIds.insert(transaction.productID)
                    await transaction.finish()
                    print("✅ Transaction update:", transaction.productID)
                } catch {
                    print("❌ Transaction update 検証失敗")
                }
            }
        }
    }
}
