# ボケ点検 v1（2026-10-15 夜・オーナー指摘「まだボケてる」）

対象：DialogueData／ChoiceEventData／FanReportData／FinalsTalk／YearResultView／TournamentResultView／FinalsPresentationView／S6bView／WeekMainView／StageViews 他の画面文字列、GameCore の ChoiceEvent 等。基準：manzai-drama-voice v3/v2（キャラ会話・地の文はボケない。ユーモアは審査員講評と司会だけ）。
結論：DialogueData・ChoiceEventData・年次独白・ClimaxData は v3 書き直し済みで素直。残っていたボケは少数（下表の6行）。

## 直した（6行）
| ファイル:行 | 今の文 | なぜボケか | 直した文 |
|---|---|---|---|
| FinalsPresentationView.swift:884 | 谷口「……なあ、腹減ったな」（優勝の余韻） | 感動の場でズレた一言＝オチ。ボケ役の外し | 「……ほんまに、勝ったんやな」 |
| FanReportData.swift bandA | 語彙力なくなった。〈名〉すごい。以上。 | ネットの定型のおどけ | 〈名〉、すごかった。最後まで目が離せなかった。 |
| FanReportData.swift misFail | …これで落ちてたら私はこの賞レースを一生疑う。 | 大げさな誇張で笑わせにいく | …これで落ちてたら納得いかない。 |
| FanReportData.swift bandA | 隣の知らない人と顔見合わせて笑った。〈名〉、これは事件。 | 「事件」と大げさに盛る | 隣の知らない人と顔を見合わせた。〈名〉、これはすごい。 |
| FanReportData.swift burst/knownOnly | 客席がひとつの生き物になってた。（2か所） | 笑わせにいく比喩 | 客席の空気が一つになってた。 |

（FanReportData は客席の声＝キャラ会話ではないが、誇張・おどけだけ抜いた。数値・選び方は不変＝golden非干渉。knownOnly の同文も同時に差し替え済み。）

## 迷って残した（オーナー判断用）
- DialogueData 週頭の掛け合い「おとんの誕生日…靴下でいいんじゃないか。毎日使うし」＝実用的な返しで冗談ではないと判断。気になれば「ハンカチ」等に。
- S6bView:133 谷口「毛布、一枚しかないけどな」＝事実の補足で軽口と読めなくもない。
- 審査員講評・司会（JudgeTalk／FinalsTalk）のユーモア・ボケ行＝決定で許可されているので対象外。
- IntroFlow.swift / GameSession.swift は別作業中のため触らず（IntroFlow の会話は読んで素直）。
- ネタの題名（NetaCatalog の「商店街の福引」等）＝題名であって本文でないので対象外。
