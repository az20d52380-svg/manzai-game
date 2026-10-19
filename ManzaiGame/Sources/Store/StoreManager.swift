// StoreManager.swift
// StoreKit 2 の購入管理。商品取得・購入・復元・Transaction.updates 監視・所有の記憶（非消耗型）。
// 所有は Apple 側の購入記録が正（ゲームのセーブとは別管理＝周回リセットで消さない）。
// 起動時に AppStore.sync() は呼ばない（Apple ID のパスワード入力が出るため）。復元は設定画面のボタンから。

import Foundation
import StoreKit

@MainActor
final class StoreManager: ObservableObject {
    static let shared = StoreManager()

    @Published private(set) var products: [String: Product] = [:]
    @Published private(set) var ownedIDs: Set<String> = []
    @Published private(set) var lastMessage: String?

    private static let cacheKey = "store_owned_ids"   // 通信前でも直前の所有を出すための控え（正は currentEntitlements）
    private var updatesTask: Task<Void, Never>?

    private init() {
        ownedIDs = Set(UserDefaults.standard.stringArray(forKey: Self.cacheKey) ?? [])
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(result)
            }
        }
        Task { await refresh() }
    }

    deinit { updatesTask?.cancel() }

    func owns(_ id: String) -> Bool { ownedIDs.contains(id) }
    var isAdFree: Bool { owns(StoreIDs.adFree) }

    /// 商品の読み込み＋所有の読み直し
    func refresh() async {
        do {
            let list = try await Product.products(for: StoreIDs.all)
            products = Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
        } catch {
            // 画面を開いただけの読み込み失敗では知らせを立てない（オフライン起動で出続けた・code_review_2026-10-19b §2-5）。購入・復元を押した時だけ知らせる
        }
        await updateEntitlements()
    }

    /// 購入。成功したら true
    @discardableResult
    func purchase(_ id: String) async -> Bool {
        guard let product = products[id] else { lastMessage = "商品が見つかりません"; return false }
        do {
            switch try await product.purchase() {
            case .success(let result):
                await handle(result)
                return owns(id)
            case .userCancelled:
                return false
            case .pending:
                lastMessage = "購入は承認待ちです"
                return false
            @unknown default:
                return false
            }
        } catch {
            lastMessage = "購入できませんでした"
            return false
        }
    }

    /// 購入を復元（審査で必須）。成功したら true
    @discardableResult
    func restore() async -> Bool {
        do {
            try await AppStore.sync()
            await updateEntitlements()
            lastMessage = ownedIDs.isEmpty ? "復元できる購入はありませんでした" : "購入を復元しました"
            return true
        } catch StoreKitError.userCancelled {
            return false   // 自分でやめた時は何も出さない
        } catch {
            lastMessage = "復元できませんでした。通信状況を確かめて、もう一度お試しください"
            return false
        }
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let tx) = result else { return }
        await tx.finish()
        await updateEntitlements()
    }

    private func updateEntitlements() async {
        var ids: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result, tx.revocationDate == nil { ids.insert(tx.productID) }
        }
        ownedIDs = ids
        UserDefaults.standard.set(Array(ids), forKey: Self.cacheKey)
    }
}
