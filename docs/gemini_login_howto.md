# Gemini CLI を AI Pro のアカウントでつなぎ直す手順（2026-10-15）

いま：CLI は「APIキー（無料枠）」でつながっている → AI Pro の特典が効いていない。Argon は無料枠が0なので使えなかった。

## ログアウト→ログイン（ターミナルで上から）
1. CLI を開く：`cd ~/manzai-game && gemini`
2. 入力欄に `/auth` と打って Enter → つなぎ方の選び直し画面が出る。
   - 「Sign out / Logout」があれば先に選ぶ → もう一度 `/auth`。
3. 「Login with Google」を選ぶ → ブラウザが開く → AI Pro に入っている Google アカウントを選んで許可。
4. ターミナルに戻ったら完了。入力欄に `/model` と打つと、選べるモデル（3.1 Pro・Argon など）が出る。
5. `/quit` で閉じる。

## モデルの選ばれ方
- 何も指定しない＝「自動」（質問ごとに Pro と Flash を振り分け）。
- Claude が使う時は毎回 `-m gemini-3.1-pro-preview` のように名前を指定して固定する（Argon が使えれば `-m gemini-4-argon`）。
- 思考の深さは CLI に切り替えの指定が無く、モデルの標準のまま。

ログインできたら一言ください。Claude が Argon と 3.1 Pro が通るか試します。
