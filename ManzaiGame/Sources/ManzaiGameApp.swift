// ManzaiGameApp.swift
// MVP（1年48週版）の起動点。UIは GameCore（純Swift）に一切ロジックを持たせない（CLAUDE.mdルール1）。

import SwiftUI

@main
struct ManzaiGameApp: App {
    init() {
        FontLoader.registerAll()   // ゲームフォント（M PLUS Rounded 1c）をプロセス登録
        _ = StoreManager.shared     // 起動時から Transaction.updates を聞く（承認待ち・別端末の購入を取りこぼさない・code_review_2026-10-19b §2-6）
    }
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
