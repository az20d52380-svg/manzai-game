# a11y 点検 a11y_check_1025_v0（2026-10-25）

**所見 8件／直した 6件**（文言・数値・見た目は不変）。節：§1 所見／§2 直した所／§3 未対応

## §1 所見
1. ComboKindPickerView：カードは label あり（顔は label で隠れる）。選択中の状態が読まれない → 直した。
2. IntroFlow 出会いメニュー：label「出会い方、…」あり。問題なし。
3. ReminiscencePlayer（回想・DisbandFarewell の場面）：下段の現在行 YoseSpeechBox に Names.show が通っておらず、「俺」が女性側でも画面・読み上げともそのまま → 直した（過去行 RecallScriptRow は通っていた）。
4. DisbandFarewellView 成績：見出しと成績が別々の読み上げ → 1つにまとめた。
5. 「タイトルへ ▶」：記号が読まれる → label「タイトルへ」。
6. 灰「観戦」札（Notebook 2か所・YearResult）：「観戦」だけでは意味不明 → label「観戦、出場せず客席から観た」。
7. 見飽きられた札：文字のまま読まれる。問題なし。
8. 最終決戦の票札：label あり（票札、○○に一票／封をした票札）。問題なし。

## §2 直した所
ComboKindPickerView.swift（isSelected）／IntroFlow.swift（Names.show）／EndingViews.swift（成績まとめ・ボタン label）／NotebookView.swift・YearResultView.swift（観戦 label）。ビルド・テスト成功。

## §3 未対応
- ReminiscencePlayer は全面 onTapGesture で送る（ボタン trait なし。a11y_check_1019 §1 と同形）。次の画面へ進む accessibilityAction を足す案。
- YoseSpeechBox の他の呼び出し元は未点検（Names.show が通っているか）。
