// ChoiceEventData.swift
// 選択肢イベントの本文（正典: proposals/0010・0017・0018・0019。各docでレッドチーム済み確定テキストの転記）。
// 谷口版のみ（相方ガチャ/周回は本編未実装＝MVP1年完結のスコープ外）。manzai-choice-events + manzai-drama-voice
// 採点済（E1〜E7・A表・B表）。地の文は name=nil（ナレーション扱い）、セリフは話者名を持つ。

import GameCore

struct ChoiceEventText {
    let title: String                    // 画面上部の小見出し【仮】
    let setup: [Advice]                  // 地の文＋導入会話（タップで1つずつ送る）
    let choiceLabels: [String: String]   // 選択肢ボタンのラベル
    let afterChoice: [String: [Advice]]  // 選択後の会話
}

enum ChoiceEventData {
    static func text(for kind: ChoiceEventKind) -> ChoiceEventText {
        switch kind {
        case .justLostRehearsal: return justLostRehearsal
        case .styleTalk: return styleTalk
        case .justPassedFork: return justPassedFork
        case .preTournamentEve: return preTournamentEve
        }
    }

    // MARK: 0017 負けた日の稽古場

    private static let justLostRehearsal = ChoiceEventText(
        title: "負けた日の稽古場",
        setup: [
            Advice(name: nil, text: "負けた翌週。稽古場の鍵は、俺が開けた。二人とも、荷物は入口に置いたままだ。\n入口の脇に、前の時間の団体が畳んで積んだ、番号入りのカラーコーンが残っている。\n三番だけ、色が褪せている。"),
            Advice(name: "俺", text: "鍵、開けたぞ"),
            Advice(name: "谷口", text: "……開けたな"),
            Advice(name: "俺", text: "掘るか、畳むか。どっちでもいい。決めろ"),
            Advice(name: "谷口", text: "決められへんから、お前が今、鍵開けたんやろ"),
        ],
        choiceLabels: [
            "A": "敗因を掘る",
            "B": "今日は畳む",
            "C": "場所を変える",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "荷物、そこでいい。始めるぞ"),
                Advice(name: "谷口", text: "……声、まだ出るやろか"),
                Advice(name: "俺", text: "出るとこまででいい。止まったら、そこが今日の粗だ"),
            ],
            "B": [
                Advice(name: "俺", text: "稽古場の予約は、まだ一時間残ってる。料金は、負けた日も、勝った日も、同じだ"),
                Advice(name: "俺", text: "今日は畳む。鍵、閉めるぞ"),
                Advice(name: "谷口", text: "おう。……コーン、三番だけ褪せとるな"),
                Advice(name: "俺", text: "明日、いちばんに来る。それでいい"),
            ],
            "C": [
                Advice(name: "俺", text: "掘るのも畳むのもやめだ。飯だけ食って帰る"),
                Advice(name: "谷口", text: "ええな。負けた日の飯は、なんでか、味が濃い"),
                Advice(name: "俺", text: "奢らないぞ。割り勘だ"),
            ],
        ]
    )

    // MARK: 0019 型を捨てる相談

    private static let styleTalk = ChoiceEventText(
        title: "型を捨てる相談",
        setup: [
            Advice(name: nil, text: "三週続けて、名前は張り出しの下の方にあった。\n稽古場の白板に、同じネタのタイトルが三回、書いては消してある。\n谷口はタイトルを、漢字でも必ずカタカナで書く。消しあとのカタカナが、うっすら三つ重なっている。\n四回目は、まだ書いていない。"),
            Advice(name: "俺", text: "三回、同じ負け方をした。"),
            Advice(name: "谷口", text: "同じ負け方は、同じネタのせいか、同じ俺らのせいか、どっちや。"),
            Advice(name: "俺", text: "たぶん、両方だ。"),
        ],
        choiceLabels: [
            "A": "新機軸に作り替える",
            "B": "型を通して磨き込む",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "作り替える。今の型は、いったん崩す。"),
                Advice(name: "谷口", text: "崩すいうことは、噛み合うてるとこも一回ばらすことやで。……ええんやな。"),
                Advice(name: "俺", text: "同じ負け方を、四回目はしたくない。"),
            ],
            "B": [
                Advice(name: "俺", text: "変えない。この型のまま、精度だけ上げる。"),
                Advice(name: "谷口", text: "……せやな。俺は、この形の俺らが好きや。"),
                Advice(name: "俺", text: "好きなだけじゃ、四回目も同じところで消える。"),
            ],
        ]
    )

    // MARK: 0018 通った日の分かれ道

    private static let justPassedFork = ChoiceEventText(
        title: "通った日の分かれ道",
        setup: [
            Advice(name: nil, text: "回戦を通過した。次の戦いまで、まだ日がある。\n谷口には、勝った日のライブのフライヤーを稽古場の壁に一枚だけ貼る癖がある。\n今日で三枚目になった。三枚目は、少し曲がっていた。"),
            Advice(name: "谷口", text: "通ったなあ。……こういう時ほど、足元すくわれる言うやろ"),
            Advice(name: "俺", text: "分かってるなら、気を抜くなよ。"),
            Advice(name: "谷口", text: "分かってるのと、やめられるのは、別やねんな"),
        ],
        choiceLabels: [
            "A": "勢いで露出・場数に賭ける",
            "B": "引き締めて次戦に備える",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "乗る。動けるうちに、顔を売る。"),
                Advice(name: "谷口", text: "ええな。……転ぶ時は、先に言うてくれよ"),
            ],
            "B": [
                Advice(name: "俺", text: "締める。次で勝たなきゃ、今日のは、ただの一日で終わる。"),
                Advice(name: "谷口", text: "地味やなあ。……嫌いやないけどな、そういうの"),
            ],
        ]
    )

    // MARK: 0010 前夜の一本

    private static let preTournamentEve = ChoiceEventText(
        title: "前夜の一本",
        setup: [
            Advice(name: nil, text: "大会は明日。稽古場に、まだ二人でいる。\n稽古場の置き時計は、谷口が持ち込んだ日から四分進んでいる。直そうと言うと、\n谷口は「本番、四分早う終わる気分でちょうどええ」と言って、直さない。\nその時計で、十一時を四分過ぎた。三本目の入りだけが、まだ決まっていない。"),
        ],
        choiceLabels: [
            "A": "残って詰める",
            "B": "早めに切り上げる",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "今夜やる。朝の勘に賭けるほど、朝の自分を信用してない。"),
                Advice(name: "谷口", text: "……せやな。俺も、朝の俺はあんまり信用してへんねん。"),
            ],
            "B": [
                Advice(name: "俺", text: "今夜はここまで。半拍は、明日の勘に預ける。"),
                Advice(name: "谷口", text: "珍しいな、お前が寝る方選ぶの。……ええ判断やと思うで。"),
            ],
        ]
    )
}
