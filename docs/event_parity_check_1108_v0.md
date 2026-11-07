# 選択肢イベント効果の突き合わせ（Swift ↔ Python 鏡像）1108 v0

## 結論
- 一致 62 / 不一致 0 / 未対応 0（Python キー29＝`_app_apply` 13 + `_others_apply` 16、Swift case 36）。効果は現時点で全て同値。
- Python ボットが一度も選ばない Swift 選択肢は styleTalk/A のみ（ボットは B 固定の方針。仕様どおり）。
- 読めなかった効果なし（growthCeiling・rift は記録のみで比較対象外）。

## 方法
`tools/check_event_parity.py`（読むだけ・不一致で終了コード1）。ChoiceEvent.swift の `choices(for:)` を正規表現で読み、
Python の `_app_apply`/`_others_apply` を状態格子（体力15値×所持金23値×能力配置2、知名度50・メンタル50・相性10＝クランプ非発動）で実行して
前後差分を取り、Swift のどれかの選択肢（weakest/weaker は状態で解決）と完全一致するか判定。
対応表（Python キー→Swift case）はスクリプト内 KEYMAP。netaBoost(2週)・preoccupy(1週)・regularJobCeilingCost(1.5)は GameConfig 既定を固定値で照合。

## 不一致の表
なし。

## 読めなかった物
なし（growthCeiling／rift は Python 鏡像に無い効果として記録のみ）。

## 限界
- ゲート（`gate:`）条件と Python 方針の閾値（例: 所持金>=X）は照合していない。差分一致のみ。
- 発火帯（weeklyBandFireable と `_app_band`/`_others_fireable`）は対象外。
- Python 鏡像が無い Swift case（regularEmployment=廃止, riftWarning, weekendInvite, フレーバー4種）は対象外。
- ボットが何もしない状態（所持金不足で効果なし）2件は不一致扱いにしていない。
- GameConfig の既定値はスクリプト内に固定で写している（変わったら要更新）。
