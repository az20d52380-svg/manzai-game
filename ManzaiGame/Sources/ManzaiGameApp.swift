// ManzaiGameApp.swift
// MVP（1年48週版）の起動点。UIは GameCore（純Swift）に一切ロジックを持たせない（CLAUDE.mdルール1）。

import SwiftUI

@main
struct ManzaiGameApp: App {
    init() {
        FontLoader.registerAll()   // ゲームフォント（M PLUS Rounded 1c）をプロセス登録
    }
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
