// FontLoader.swift
// ゲームフォント（M PLUS Rounded 1c・OFL）の実行時登録。Info.plist(UIAppFonts) を汚さず
// CTFontManager でプロセスに登録する（GENERATE_INFOPLIST_FILE 構成のまま完結）。
// リサーチ根拠: 「システム標準フォントを使った瞬間に素人に見える。商用可ゲームフォント1書体に
// 統一するだけで一段変わる」（sellable_basics_research §5）。

import CoreText
import SwiftUI
import UIKit

enum FontLoader {
    private static var registered = false

    /// アプリ起動時に1回呼ぶ（ManzaiGameApp.init）。失敗してもクラッシュしない（system丸ゴにフォールバック）。
    static func registerAll() {
        guard !registered else { return }
        registered = true
        for name in ["MPLUSRounded1c-Medium", "MPLUSRounded1c-Bold",
                     "MPLUSRounded1c-ExtraBold", "MPLUSRounded1c-Black"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    /// 登録済みか（Font.maru のフォールバック判定用）。ファイル名は MPLUSRounded1c-*.ttf だが、
    /// フォント内部の PostScript 名は RoundedMplus1c-*（2026-10-08 判明。名前違いで全量が system 丸ゴに落ちていた）。
    /// 4太さすべてが登録できた時だけ true（1つ欠けると .custom が標準書体に落ちて混ざる）。初回参照で1回だけ調べる（registerAll は App.init で先に済む）
    /// code_review_finalstalk_misc_1118 #6
    static let isAvailable: Bool = ["RoundedMplus1c-Medium", "RoundedMplus1c-Bold", "RoundedMplus1c-ExtraBold", "RoundedMplus1c-Black"]
        .allSatisfy { UIFont(name: $0, size: 12) != nil }
}
