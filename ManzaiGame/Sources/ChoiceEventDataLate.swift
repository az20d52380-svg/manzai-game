// ChoiceEventDataLate.swift（自動生成の本文転記・late_events_cand_1108）
// 出典: docs/late_game_content_v0.md §2 の E1〜E20（6年目以降）／docs/late_game_events_draft_1107.md の N1〜N20（11年目以降）。
// 文面は下書きのまま（一人称の「俺」だけ地の札 "俺" に任せる＝Names.show が形に合わせる）。効果は GameCore の ChoiceEventLate.swift。

import GameCore

extension ChoiceEventData {
    /// 終盤イベント40本の本文（lateE01…lateN20）。それ以外の kind は nil
    static func lateText(for kind: ChoiceEventKind) -> ChoiceEventText? {
        switch kind {
        case .lateE01: return lateE01
        case .lateE02: return lateE02
        case .lateE03: return lateE03
        case .lateE04: return lateE04
        case .lateE05: return lateE05
        case .lateE06: return lateE06
        case .lateE07: return lateE07
        case .lateE08: return lateE08
        case .lateE09: return lateE09
        case .lateE10: return lateE10
        case .lateE11: return lateE11
        case .lateE12: return lateE12
        case .lateE13: return lateE13
        case .lateE14: return lateE14
        case .lateE15: return lateE15
        case .lateE16: return lateE16
        case .lateE17: return lateE17
        case .lateE18: return lateE18
        case .lateE19: return lateE19
        case .lateE20: return lateE20
        case .lateN01: return lateN01
        case .lateN02: return lateN02
        case .lateN03: return lateN03
        case .lateN04: return lateN04
        case .lateN05: return lateN05
        case .lateN06: return lateN06
        case .lateN07: return lateN07
        case .lateN08: return lateN08
        case .lateN09: return lateN09
        case .lateN10: return lateN10
        case .lateN11: return lateN11
        case .lateN12: return lateN12
        case .lateN13: return lateN13
        case .lateN14: return lateN14
        case .lateN15: return lateN15
        case .lateN16: return lateN16
        case .lateN17: return lateN17
        case .lateN18: return lateN18
        case .lateN19: return lateN19
        case .lateN20: return lateN20
        default: return nil
        }
    }

    // MARK: E1 後輩の相談
    private static let lateE01 = ChoiceEventText(
        title: "後輩の相談",
        setup: [
            Advice(name: nil, text: "劇場の裏口。昼。"),
            Advice(name: "村瀬", text: "相談があります。今、少しいいですか"),
            Advice(name: "俺", text: "いいよ。どうした"),
            Advice(name: "村瀬", text: "バイトと稽古が両立できなくて、辞めようか迷っています"),
            Advice(name: "谷口", text: "聞いてあげたら。急ぎの用事はないでしょ"),
        ],
        choiceLabels: [
            "A": "時間をとって聞く",
            "B": "事務所に相談を回す",
        ],
        afterChoice: [
            "A": [
                Advice(name: "村瀬", text: "ありがとうございます。続けてみます"),
                Advice(name: "俺", text: "また話そう"),
            ],
            "B": [
                Advice(name: "村瀬", text: "分かりました。中条さんに話します"),
                Advice(name: "俺", text: "お願いね。無理しないでね"),
            ],
        ]
    )

    // MARK: E2 後輩に抜かれる
    private static let lateE02 = ChoiceEventText(
        title: "後輩に抜かれる",
        setup: [
            Advice(name: nil, text: "楽屋の廊下。夜。"),
            Advice(name: "谷口", text: "村瀬たち、今日の大会で決勝に進んだって"),
            Advice(name: "俺", text: "そっか。早いね"),
            Advice(name: "谷口", text: "連絡、してみる？"),
            Advice(name: "俺", text: "どうしようか"),
        ],
        choiceLabels: [
            "A": "おめでとうと連絡する",
            "B": "見ないで帰って寝る",
        ],
        afterChoice: [
            "A": [
                Advice(name: "谷口", text: "うん。きっと喜ぶよ"),
                Advice(name: "俺", text: "こっちも頑張る"),
            ],
            "B": [
                Advice(name: "俺", text: "今日は帰ろう"),
                Advice(name: "谷口", text: "そうだね。明日からだね"),
            ],
        ]
    )

    // MARK: E3 先輩が売れる
    private static let lateE03 = ChoiceEventText(
        title: "先輩が売れる",
        setup: [
            Advice(name: nil, text: "駅前のビジョン。夕方。"),
            Advice(name: "谷口", text: "あそこに映っているの、宇佐美さんだ"),
            Advice(name: "俺", text: "本当だ。番組が決まったんだね"),
            Advice(name: "谷口", text: "知らなかった。すごい"),
            Advice(name: "俺", text: "お祝い、何か送る？"),
        ],
        choiceLabels: [
            "A": "宇佐美さんにお祝いを送る",
            "B": "見なかったことにして帰る",
        ],
        afterChoice: [
            "A": [
                Advice(name: "宇佐美", text: "ありがとう。今度、ご飯でも行こう"),
                Advice(name: "俺", text: "ぜひお願いします"),
            ],
            "B": [
                Advice(name: "俺", text: "今日は帰ろう"),
                Advice(name: "谷口", text: "うん。そうしよう"),
            ],
        ]
    )

    // MARK: E4 先輩が辞める
    private static let lateE04 = ChoiceEventText(
        title: "先輩が辞める",
        setup: [
            Advice(name: nil, text: "事務所の応接室。昼。"),
            Advice(name: "野々村", text: "来月で、芸人を辞めます"),
            Advice(name: "俺", text: "そうなんですか。突然ですね"),
            Advice(name: "野々村", text: "家族のことで、決めました"),
            Advice(name: "野々村", text: "最後に、一言だけ言っておく"),
        ],
        choiceLabels: [
            "A": "最後まで話を聞く",
            "B": "お礼を言って短く終える",
        ],
        afterChoice: [
            "A": [
                Advice(name: "野々村", text: "続けてくれ。それだけだ"),
                Advice(name: "谷口", text: "はい。ありがとうございました"),
            ],
            "B": [
                Advice(name: "俺", text: "長い間、お世話になりました"),
                Advice(name: "野々村", text: "元気で"),
            ],
        ]
    )

    // MARK: E5 実家からの電話
    private static let lateE05 = ChoiceEventText(
        title: "実家からの電話",
        setup: [
            Advice(name: nil, text: "アパート。夜。"),
            Advice(name: "母", text: "元気にしてる？ ご飯、食べてる？"),
            Advice(name: "俺", text: "食べてるよ。大丈夫"),
            Advice(name: "母", text: "たまには帰っておいで。父さんも会いたがってる"),
            Advice(name: "俺", text: "分かった。考えてみる"),
        ],
        choiceLabels: [
            "A": "週末に帰る約束をする",
            "B": "忙しいと断る",
        ],
        afterChoice: [
            "A": [
                Advice(name: "母", text: "待ってるね"),
                Advice(name: "俺", text: "土曜に行く"),
            ],
            "B": [
                Advice(name: "母", text: "そう。無理しないでね"),
                Advice(name: "俺", text: "また連絡する"),
            ],
        ]
    )

    // MARK: E6 親の体調
    private static let lateE06 = ChoiceEventText(
        title: "親の体調",
        setup: [
            Advice(name: nil, text: "病院の待合室。朝。"),
            Advice(name: "父", text: "わざわざ来なくてよかったのに"),
            Advice(name: "俺", text: "近くまで来たから。具合はどう"),
            Advice(name: "父", text: "検査は問題なかった。心配をかけたな"),
            Advice(name: "俺", text: "それならよかった"),
        ],
        choiceLabels: [
            "A": "付き添ってから稽古に戻る",
            "B": "ついでに実家で一泊する",
        ],
        afterChoice: [
            "A": [
                Advice(name: "父", text: "ありがとう。気をつけて"),
                Advice(name: "俺", text: "またすぐ来る"),
            ],
            "B": [
                Advice(name: "父", text: "泊まっていけ。母さんも喜ぶ"),
                Advice(name: "俺", text: "じゃあ、そうする"),
            ],
        ]
    )

    // MARK: E7 同期の解散
    private static let lateE07 = ChoiceEventText(
        title: "同期の解散",
        setup: [
            Advice(name: nil, text: "居酒屋の前。夜。"),
            Advice(name: "石黒", text: "俺たち、今月で解散する"),
            Advice(name: "俺", text: "そっか。決めたんだね"),
            Advice(name: "石黒", text: "後悔はしてない。ただ、少し寂しい"),
            Advice(name: "谷口", text: "最後のライブ、行ってもいい？"),
        ],
        choiceLabels: [
            "A": "最後のライブを見に行く",
            "B": "手紙を書いて渡す",
        ],
        afterChoice: [
            "A": [
                Advice(name: "石黒", text: "来てくれてありがとう"),
                Advice(name: "俺", text: "お疲れ。よかったよ"),
            ],
            "B": [
                Advice(name: "石黒", text: "読んだ。ありがとう"),
                Advice(name: "俺", text: "元気でね"),
            ],
        ]
    )

    // MARK: E8 同期のコンビ再結成
    private static let lateE08 = ChoiceEventText(
        title: "同期のコンビ再結成",
        setup: [
            Advice(name: nil, text: "劇場のロビー。昼。"),
            Advice(name: "石黒", text: "新しい相方が見つかった。来月から出る"),
            Advice(name: "俺", text: "そっか。よかったね"),
            Advice(name: "石黒", text: "見に来てほしい。一度でいいから"),
            Advice(name: "谷口", text: "行ってみよう。同じ日に出るみたいだし"),
        ],
        choiceLabels: [
            "A": "同じ日に出て見届ける",
            "B": "別の日にゆっくり見る",
        ],
        afterChoice: [
            "A": [
                Advice(name: "石黒", text: "ありがとう。負けないぞ"),
                Advice(name: "俺", text: "こちらこそ"),
            ],
            "B": [
                Advice(name: "石黒", text: "分かった。いつでもいい"),
                Advice(name: "俺", text: "必ず行く"),
            ],
        ]
    )

    // MARK: E9 初めての会議室
    private static let lateE09 = ChoiceEventText(
        title: "初めての会議室",
        setup: [
            Advice(name: nil, text: "制作会社の会議室。昼。"),
            Advice(name: "岡部", text: "番組のコーナーに出てもらえませんか。三分です"),
            Advice(name: "俺", text: "ありがとうございます。何をすればいいですか"),
            Advice(name: "岡部", text: "紹介VTRの後に、一言だけです"),
            Advice(name: "谷口", text: "一言でも、出られるなら"),
        ],
        choiceLabels: [
            "A": "引き受ける",
            "B": "ライブを優先して断る",
        ],
        afterChoice: [
            "A": [
                Advice(name: "岡部", text: "助かります。台本は後で送ります"),
                Advice(name: "俺", text: "お願いします"),
            ],
            "B": [
                Advice(name: "岡部", text: "分かりました。また次の機会に"),
                Advice(name: "俺", text: "すみません"),
            ],
        ]
    )

    // MARK: E10 編集で消えた場面
    private static let lateE10 = ChoiceEventText(
        title: "編集で消えた場面",
        setup: [
            Advice(name: nil, text: "アパート。深夜。"),
            Advice(name: "谷口", text: "今日の放送、見た？"),
            Advice(name: "俺", text: "見た。ほとんど映らなかったね"),
            Advice(name: "谷口", text: "でも、名前は出ていたよ"),
            Advice(name: "俺", text: "そっか。次に出る時は、短くても集中しよう"),
        ],
        choiceLabels: [
            "A": "録画を見返して反省する",
            "B": "早く寝て切り替える",
        ],
        afterChoice: [
            "A": [
                Advice(name: "谷口", text: "付き合うよ"),
                Advice(name: "俺", text: "ありがとう。もう一回見よう"),
            ],
            "B": [
                Advice(name: "谷口", text: "その方がいい。おやすみ"),
                Advice(name: "俺", text: "おやすみ"),
            ],
        ]
    )

    // MARK: E11 昔のネタの依頼
    private static let lateE11 = ChoiceEventText(
        title: "昔のネタの依頼",
        setup: [
            Advice(name: nil, text: "稽古場。昼。"),
            Advice(name: "大塚", text: "昔の舞台、また見たいというお客さんが多いです"),
            Advice(name: "俺", text: "そう言ってもらえるのは嬉しいです"),
            Advice(name: "大塚", text: "あのネタを、今月だけやってもらえませんか"),
            Advice(name: "谷口", text: "どうする？ 新しいのも作りたいけど"),
        ],
        choiceLabels: [
            "A": "昔のネタを今の形でやる",
            "B": "新しいものを優先する",
        ],
        afterChoice: [
            "A": [
                Advice(name: "大塚", text: "助かります。席が埋まりそうです"),
                Advice(name: "俺", text: "分かりました"),
            ],
            "B": [
                Advice(name: "大塚", text: "そうですか。次を楽しみにしています"),
                Advice(name: "俺", text: "頑張ります"),
            ],
        ]
    )

    // MARK: E12 押し入れのノート
    private static let lateE12 = ChoiceEventText(
        title: "押し入れのノート",
        setup: [
            Advice(name: nil, text: "アパートの押し入れ。夜。"),
            Advice(name: "谷口", text: "押し入れから古いノートが出てきた"),
            Advice(name: "俺", text: "どれくらいある？"),
            Advice(name: "谷口", text: "全部で十冊くらい。捨てる？"),
            Advice(name: "俺", text: "中を少し見てからにしよう"),
        ],
        choiceLabels: [
            "A": "一晩かけて読み返す",
            "B": "整理して半分捨てる",
        ],
        afterChoice: [
            "A": [
                Advice(name: "谷口", text: "面白いところ、残ってるね"),
                Advice(name: "俺", text: "使えそうなのを写しておく"),
            ],
            "B": [
                Advice(name: "谷口", text: "部屋が広くなった"),
                Advice(name: "俺", text: "残した分は、また使おう"),
            ],
        ]
    )

    // MARK: E13 階段で息が切れる
    private static let lateE13 = ChoiceEventText(
        title: "階段で息が切れる",
        setup: [
            Advice(name: nil, text: "劇場の階段。夕方。"),
            Advice(name: "谷口", text: "ちょっと待って。息が上がった"),
            Advice(name: "俺", text: "大丈夫？ 座ろう"),
            Advice(name: "谷口", text: "昔はこの階段、平気だったのにね"),
            Advice(name: "俺", text: "無理はよくない。少し休もう"),
        ],
        choiceLabels: [
            "A": "ゆっくり休んでから稽古する",
            "B": "そのまま稽古を続ける",
        ],
        afterChoice: [
            "A": [
                Advice(name: "谷口", text: "ありがとう。少し楽になった"),
                Advice(name: "俺", text: "焦らないで行こう"),
            ],
            "B": [
                Advice(name: "谷口", text: "続けよう。体は後で戻す"),
                Advice(name: "俺", text: "無理だと思ったら言って"),
            ],
        ]
    )

    // MARK: E14 健康診断の結果
    private static let lateE14 = ChoiceEventText(
        title: "健康診断の結果",
        setup: [
            Advice(name: nil, text: "アパート。朝。"),
            Advice(name: "俺", text: "結果が届いた。数値が少し悪い"),
            Advice(name: "谷口", text: "何か言われた？"),
            Advice(name: "俺", text: "睡眠と食事を見直すように、だって"),
            Advice(name: "谷口", text: "今日から気をつけよう"),
        ],
        choiceLabels: [
            "A": "食事と睡眠を整える",
            "B": "今まで通りにする",
        ],
        afterChoice: [
            "A": [
                Advice(name: "谷口", text: "いい習慣になるよ"),
                Advice(name: "俺", text: "続けてみる"),
            ],
            "B": [
                Advice(name: "谷口", text: "ほどほどにね"),
                Advice(name: "俺", text: "分かってる"),
            ],
        ]
    )

    // MARK: E15 劇場の若い客
    private static let lateE15 = ChoiceEventText(
        title: "劇場の若い客",
        setup: [
            Advice(name: nil, text: "劇場の出口。夜。"),
            Advice(name: "白井", text: "今日もよかったよ。いつも見てる"),
            Advice(name: "俺", text: "ありがとうございます。いつも来てくれますね"),
            Advice(name: "白井", text: "最近は若い人が増えたね。みんなスマホで撮ってる"),
            Advice(name: "谷口", text: "覚えてもらえているなら、嬉しいね"),
        ],
        choiceLabels: [
            "A": "若い客にも声をかける",
            "B": "常連さんを大事にする",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "若いお客さんにも、帰りに声をかけてみます"),
                Advice(name: "白井", text: "いいね。きっと喜ぶよ"),
            ],
            "B": [
                Advice(name: "白井", text: "ありがとう。また来るよ"),
                Advice(name: "俺", text: "お待ちしています"),
            ],
        ]
    )

    // MARK: E16 中堅の肩書き
    private static let lateE16 = ChoiceEventText(
        title: "中堅の肩書き",
        setup: [
            Advice(name: nil, text: "事務所の事務室。昼。"),
            Advice(name: "中条", text: "今月から、二人は『中堅』の扱いになる"),
            Advice(name: "俺", text: "そうですか。自分ではまだ実感がないです"),
            Advice(name: "中条", text: "後輩に教える仕事も増える。覚えておいてくれ"),
            Advice(name: "谷口", text: "責任が重くなるね"),
        ],
        choiceLabels: [
            "A": "後輩の勉強会を引き受ける",
            "B": "自分たちの稽古に集中する",
        ],
        afterChoice: [
            "A": [
                Advice(name: "中条", text: "助かる。月に一度だけだ"),
                Advice(name: "俺", text: "分かりました"),
            ],
            "B": [
                Advice(name: "中条", text: "分かった。無理は言わない"),
                Advice(name: "俺", text: "すみません"),
            ],
        ]
    )

    // MARK: E17 長い休みの提案
    private static let lateE17 = ChoiceEventText(
        title: "長い休みの提案",
        setup: [
            Advice(name: nil, text: "稽古場。朝。"),
            Advice(name: "谷口", text: "ずっと走ってきたよね。三日だけ休まない？"),
            Advice(name: "俺", text: "休むの？ 大会が近いんじゃない？"),
            Advice(name: "谷口", text: "次まで時間はある。体を戻したい"),
            Advice(name: "俺", text: "そうだね。考えておく"),
        ],
        choiceLabels: [
            "A": "三日休む",
            "B": "予定どおり稽古する",
        ],
        afterChoice: [
            "A": [
                Advice(name: "谷口", text: "ありがとう。体を戻すよ"),
                Advice(name: "俺", text: "分かった。稽古場は閉めておく"),
            ],
            "B": [
                Advice(name: "谷口", text: "分かった。続けよう"),
                Advice(name: "俺", text: "その代わり、夜は早く寝よう"),
            ],
        ]
    )

    // MARK: E18 事務所の新しい契約
    private static let lateE18 = ChoiceEventText(
        title: "事務所の新しい契約",
        setup: [
            Advice(name: nil, text: "事務所の応接室。昼。"),
            Advice(name: "中条", text: "契約の更新があります。条件が少し変わります"),
            Advice(name: "俺", text: "どう変わるんですか"),
            Advice(name: "中条", text: "ギャラの割合が上がる代わりに、営業の本数が増えます"),
            Advice(name: "谷口", text: "悪くない話だね"),
        ],
        choiceLabels: [
            "A": "条件を受け入れる",
            "B": "今の条件のままにする",
        ],
        afterChoice: [
            "A": [
                Advice(name: "中条", text: "ありがとう。来月から始めます"),
                Advice(name: "俺", text: "お願いします"),
            ],
            "B": [
                Advice(name: "中条", text: "分かった。そのまま続けよう"),
                Advice(name: "俺", text: "ありがとうございます"),
            ],
        ]
    )

    // MARK: E19 最初の劇場の閉館
    private static let lateE19 = ChoiceEventText(
        title: "最初の劇場の閉館",
        setup: [
            Advice(name: nil, text: "最初に出た劇場の前。夕方。"),
            Advice(name: "大塚", text: "二人が最初に出たこの劇場、今月で閉まるそうです"),
            Advice(name: "俺", text: "そうですか。ここから始まったんですよね"),
            Advice(name: "大塚", text: "最後の舞台に、二人を呼びたいそうです"),
            Advice(name: "谷口", text: "出られるなら、出たいね"),
        ],
        choiceLabels: [
            "A": "最後の舞台に出る",
            "B": "客席から見送る",
        ],
        afterChoice: [
            "A": [
                Advice(name: "大塚", text: "ありがとう。向こうに伝えておきます"),
                Advice(name: "俺", text: "精一杯やります"),
            ],
            "B": [
                Advice(name: "大塚", text: "分かりました。席を取っておきます"),
                Advice(name: "俺", text: "最後まで見届けます"),
            ],
        ]
    )

    // MARK: E20 結成の年の写真
    private static let lateE20 = ChoiceEventText(
        title: "結成の年の写真",
        setup: [
            Advice(name: nil, text: "アパートの廊下。夜。"),
            Advice(name: "谷口", text: "前に撮った写真、見つけた。結成の年のやつ"),
            Advice(name: "俺", text: "若いね。やせてる"),
            Advice(name: "谷口", text: "今も、同じ劇場で舞台に立ってる"),
            Advice(name: "俺", text: "そうだね。続けてきたね"),
        ],
        choiceLabels: [
            "A": "写真を部屋に飾る",
            "B": "写真は箱にしまう",
        ],
        afterChoice: [
            "A": [
                Advice(name: "谷口", text: "いいね。いい額もある"),
                Advice(name: "俺", text: "また頑張れる気がする"),
            ],
            "B": [
                Advice(name: "谷口", text: "分かった。大事にしよう"),
                Advice(name: "俺", text: "また十年後に見よう"),
            ],
        ]
    )

    // MARK: N1 小さな取材
    private static let lateN01 = ChoiceEventText(
        title: "小さな取材",
        setup: [
            Advice(name: nil, text: "劇場の応接室。昼。"),
            Advice(name: "真壁", text: "十年以上続けている理由を聞かせてください"),
            Advice(name: "谷口", text: "ここは任せて"),
            Advice(name: "俺", text: "頼むよ。補足は{me}がする"),
        ],
        choiceLabels: [
            "A": "二人で丁寧に答える",
            "B": "短く断る",
        ],
        afterChoice: [
            "A": [
                Advice(name: "真壁", text: "いい話が聞けました。記事にします"),
                Advice(name: "谷口", text: "ありがとうございます"),
            ],
            "B": [
                Advice(name: "俺", text: "すみません、今は稽古を優先したいので"),
                Advice(name: "真壁", text: "分かりました。また機会があれば"),
            ],
        ]
    )

    // MARK: N2 ラジオの代役
    private static let lateN02 = ChoiceEventText(
        title: "ラジオの代役",
        setup: [
            Advice(name: nil, text: "事務所の電話口。夕方。"),
            Advice(name: "中条", text: "隣の県の局で、桐山さんの番組の代役を探しているんです"),
            Advice(name: "谷口", text: "一時間なら、できると思う"),
            Advice(name: "俺", text: "明日の朝だと、今夜のうちに移動だね"),
        ],
        choiceLabels: [
            "A": "今夜のうちに電車で向かう",
            "B": "断って、今夜は家で休む",
        ],
        afterChoice: [
            "A": [
                Advice(name: "中条", text: "助かります。桐山さんにも伝えます"),
                Advice(name: "俺", text: "電車の中で寝ておこう"),
            ],
            "B": [
                Advice(name: "俺", text: "今回は見送らせてください"),
                Advice(name: "中条", text: "分かりました。次の機会に"),
            ],
        ]
    )

    // MARK: N3 小学校の公演
    private static let lateN03 = ChoiceEventText(
        title: "小学校の公演",
        setup: [
            Advice(name: nil, text: "劇場の事務室。朝。"),
            Advice(name: "大塚", text: "地元の小学校から公演の依頼です。午前と午後の二回です"),
            Advice(name: "谷口", text: "子どもの前に立つのは初めてだね"),
            Advice(name: "俺", text: "午前だけでもいいですか"),
            Advice(name: "大塚", text: "はい。先生もそれでいいそうです"),
        ],
        choiceLabels: [
            "A": "午前も午後も、二回とも行く",
            "B": "午前の一回だけ行く",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "二回とも行きます"),
                Advice(name: "谷口", text: "一日がかりだね。頑張ろう"),
            ],
            "B": [
                Advice(name: "俺", text: "午前の一回だけお願いします"),
                Advice(name: "谷口", text: "うん。午後はゆっくりしよう"),
            ],
        ]
    )

    // MARK: N4 若手大会の審査員
    private static let lateN04 = ChoiceEventText(
        title: "若手大会の審査員",
        setup: [
            Advice(name: nil, text: "会場の控室。昼。"),
            Advice(name: "岡部", text: "今日の若手大会、審査員が二人急に来られなくなったんです"),
            Advice(name: "谷口", text: "二人で審査員席に座るってことですか"),
            Advice(name: "岡部", text: "はい。経験のある方にお願いしたいんです"),
        ],
        choiceLabels: [
            "A": "審査員を引き受ける",
            "B": "断って、今日は帰って休む",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "緊張しますけど、若い人たちを見てみたいです"),
                Advice(name: "谷口", text: "うん。勉強になるはず"),
            ],
            "B": [
                Advice(name: "俺", text: "まだ出る側でいたいです"),
                Advice(name: "岡部", text: "分かりました"),
            ],
        ]
    )

    // MARK: N5 稽古場の更新
    private static let lateN05 = ChoiceEventText(
        title: "稽古場の更新",
        setup: [
            Advice(name: nil, text: "稽古場の入口。夕方。"),
            Advice(name: "大塚", text: "来月から、稽古場の使用料が少し上がります"),
            Advice(name: "谷口", text: "続けられない額じゃないけど"),
            Advice(name: "俺", text: "どうしようか"),
        ],
        choiceLabels: [
            "A": "今のまま借り続ける",
            "B": "安い会場に移る",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "ここが一番、声が通る"),
                Advice(name: "谷口", text: "分かった。二人で割ろう"),
            ],
            "B": [
                Advice(name: "谷口", text: "通うのは少し遠くなるね"),
                Advice(name: "俺", text: "少しの間、我慢しよう"),
            ],
        ]
    )

    // MARK: N6 声がかすれる
    private static let lateN06 = ChoiceEventText(
        title: "声がかすれる",
        setup: [
            Advice(name: nil, text: "舞台袖。本番前。"),
            Advice(name: "谷口", text: "今日は声が出にくいんだ"),
            Advice(name: "俺", text: "喉が荒れてるな。無理をしない方がいい"),
            Advice(name: "谷口", text: "でも、出たいんだ"),
        ],
        choiceLabels: [
            "A": "声を抑えて、短めに話す",
            "B": "出番を短くしてもらう",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "ゆっくり、短めに話そう"),
                Advice(name: "谷口", text: "そうだね。そっちでいこう"),
            ],
            "B": [
                Advice(name: "大塚", text: "分かりました。調整します"),
                Advice(name: "谷口", text: "ありがとう。助かるよ"),
            ],
        ]
    )

    // MARK: N7 客席が空いた日
    private static let lateN07 = ChoiceEventText(
        title: "客席が空いた日",
        setup: [
            Advice(name: nil, text: "劇場の客席。昼。"),
            Advice(name: "大塚", text: "今日は平日で、昼の客席があまり埋まっていません"),
            Advice(name: "谷口", text: "それでも、来てくれた人にはちゃんと見せたいな"),
            Advice(name: "俺", text: "でも夜の回もあるし、少し疲れてるんだよね"),
        ],
        choiceLabels: [
            "A": "昼の回もいつもどおり出る",
            "B": "昼の回を短くしてもらい、夜まで休む",
        ],
        afterChoice: [
            "A": [
                Advice(name: "谷口", text: "前の列の人、最後まで残ってくれてるね"),
                Advice(name: "俺", text: "ありがたいな"),
            ],
            "B": [
                Advice(name: "俺", text: "昼は短くしてもらって、夜まで休もう"),
                Advice(name: "谷口", text: "そうだね。少し残念だけど、休んでおこう"),
            ],
        ]
    )

    // MARK: N8 谷口にナレーションの話
    private static let lateN08 = ChoiceEventText(
        title: "谷口にナレーションの話",
        setup: [
            Advice(name: nil, text: "稽古場。昼。"),
            Advice(name: "谷口", text: "前に会った制作会社から、ナレーションの話があったんだ"),
            Advice(name: "俺", text: "いい話じゃない？"),
            Advice(name: "谷口", text: "コンビの稽古と重なる日があるんだ"),
        ],
        choiceLabels: [
            "A": "谷口に受けるよう勧める",
            "B": "コンビの稽古を優先する",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "重なる日は{me}が合わせる。やってみて"),
                Advice(name: "谷口", text: "ありがとう。頑張るよ"),
            ],
            "B": [
                Advice(name: "谷口", text: "そうだね。まずは二人の舞台が先だ"),
                Advice(name: "俺", text: "落ち着いたらまた考えよう"),
            ],
        ]
    )

    // MARK: N9 ファンレター
    private static let lateN09 = ChoiceEventText(
        title: "ファンレター",
        setup: [
            Advice(name: nil, text: "劇場の事務室。夕方。"),
            Advice(name: "大塚", text: "手紙が届いています。もう何年も見てくれている方からです"),
            Advice(name: "谷口", text: "読んでいい？"),
            Advice(name: "俺", text: "もうすぐ出番だけど、どうしようか"),
        ],
        choiceLabels: [
            "A": "今、二人で読む",
            "B": "楽屋に持ち帰ってあとで読む",
        ],
        afterChoice: [
            "A": [
                Advice(name: "谷口", text: "この手紙、結成の頃のことも書いてある"),
                Advice(name: "俺", text: "大事に取っておこう"),
            ],
            "B": [
                Advice(name: "俺", text: "舞台のあとで、ゆっくり読もう"),
                Advice(name: "谷口", text: "そうしよう"),
            ],
        ]
    )

    // MARK: N10 商店街の店主の言葉
    private static let lateN10 = ChoiceEventText(
        title: "商店街の店主の言葉",
        setup: [
            Advice(name: nil, text: "商店街の店先。夜。"),
            Advice(name: "店主", text: "稽古の帰りかい。最近、二人とも顔色がいいね"),
            Advice(name: "谷口", text: "そう見えますか"),
            Advice(name: "店主", text: "うん。前は疲れて見えたから、安心したよ"),
        ],
        choiceLabels: [
            "A": "今の暮らしを続けると伝える",
            "B": "公演のチラシを貼らせてもらう",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "ありがとうございます。この調子で続けます"),
                Advice(name: "店主", text: "体を大事にね"),
            ],
            "B": [
                Advice(name: "谷口", text: "今度の公演のチラシ、お店に貼ってもらえますか"),
                Advice(name: "店主", text: "いいよ。持っておいで"),
            ],
        ]
    )

    // MARK: N11 定食屋の前で
    private static let lateN11 = ChoiceEventText(
        title: "定食屋の前で",
        setup: [
            Advice(name: nil, text: "定食屋の前。夕方。"),
            Advice(name: "野々村", text: "久しぶり。まだ劇場に出てるのか"),
            Advice(name: "谷口", text: "はい。毎月、出ています"),
            Advice(name: "野々村", text: "それなら、知り合いの店の開店祝いに出てくれないか"),
        ],
        choiceLabels: [
            "A": "話を聞く",
            "B": "仕事は自分たちで探すと断る",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "ぜひ、詳しくお願いします"),
                Advice(name: "野々村", text: "連絡先を渡しておく"),
            ],
            "B": [
                Advice(name: "俺", text: "ありがたいですが、今回は自分たちで探します"),
                Advice(name: "野々村", text: "そうか。頑張れ"),
            ],
        ]
    )

    // MARK: N12 年末の事務所の幹事
    private static let lateN12 = ChoiceEventText(
        title: "年末の事務所の幹事",
        setup: [
            Advice(name: nil, text: "事務所の会議室。夕方。"),
            Advice(name: "中条", text: "年末の事務所の集まり、幹事を決めたいんです"),
            Advice(name: "谷口", text: "石黒さんも来るよね"),
            Advice(name: "俺", text: "段取りが多いな"),
        ],
        choiceLabels: [
            "A": "幹事を引き受ける",
            "B": "別の人に回す",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "分かりました。やります"),
                Advice(name: "中条", text: "ありがとう。助かります"),
            ],
            "B": [
                Advice(name: "俺", text: "今回は、ほかの方にお願いできませんか"),
                Advice(name: "中条", text: "分かりました。探します"),
            ],
        ]
    )

    // MARK: N13 新しい衣装
    private static let lateN13 = ChoiceEventText(
        title: "新しい衣装",
        setup: [
            Advice(name: nil, text: "衣装部屋。昼。"),
            Advice(name: "谷口", text: "舞台の衣装、袖が少しほつれてきたね"),
            Advice(name: "俺", text: "十年以上着てる衣装だからな"),
            Advice(name: "谷口", text: "新しく作るか、直して使うか"),
        ],
        choiceLabels: [
            "A": "新しく仕立てる",
            "B": "直して使い続ける",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "次の舞台は、新しい衣装で出よう"),
                Advice(name: "谷口", text: "うん。気持ちが入りそう"),
            ],
            "B": [
                Advice(name: "谷口", text: "直せば、まだ着られるよ"),
                Advice(name: "俺", text: "それでいこう"),
            ],
        ]
    )

    // MARK: N14 会社の新人研修
    private static let lateN14 = ChoiceEventText(
        title: "会社の新人研修",
        setup: [
            Advice(name: nil, text: "事務所の受付。昼。"),
            Advice(name: "中条", text: "取引先の新人研修で、話をしてもらえませんか"),
            Advice(name: "谷口", text: "会社の人の前で話すの？"),
            Advice(name: "俺", text: "平日なら空いてるよ"),
        ],
        choiceLabels: [
            "A": "研修に出る",
            "B": "断る",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "いつもどおり話そう"),
                Advice(name: "谷口", text: "分かった。スーツを出しておくね"),
            ],
            "B": [
                Advice(name: "俺", text: "ほかの方の方が向いていると思います"),
                Advice(name: "中条", text: "分かりました"),
            ],
        ]
    )

    // MARK: N15 配信ライブの提案
    private static let lateN15 = ChoiceEventText(
        title: "配信ライブの提案",
        setup: [
            Advice(name: nil, text: "事務所の会議室。昼。"),
            Advice(name: "中条", text: "劇場の舞台を、有料で配信しませんか"),
            Advice(name: "谷口", text: "いいかもしれない"),
            Advice(name: "俺", text: "編集の手間はどうなりますか"),
        ],
        choiceLabels: [
            "A": "配信を始める",
            "B": "今は劇場だけでやる",
        ],
        afterChoice: [
            "A": [
                Advice(name: "中条", text: "分かりました。準備を進めます"),
                Advice(name: "谷口", text: "やってみよう"),
            ],
            "B": [
                Advice(name: "俺", text: "まだ、目の前のお客さんに集中したいです"),
                Advice(name: "中条", text: "分かりました。また相談しましょう"),
            ],
        ]
    )

    // MARK: N16 倉庫から出てきた録音
    private static let lateN16 = ChoiceEventText(
        title: "倉庫から出てきた録音",
        setup: [
            Advice(name: nil, text: "劇場の事務室。夜。"),
            Advice(name: "大塚", text: "倉庫を片づけたら、お二人の昔の録音が出てきました"),
            Advice(name: "谷口", text: "結成の頃のかな"),
            Advice(name: "俺", text: "聞くのが怖いな"),
        ],
        choiceLabels: [
            "A": "その場で最後まで聞く",
            "B": "聞かずに預かってもらう",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "二人とも、声が若いな"),
                Advice(name: "谷口", text: "あの頃は緊張してたんだね"),
            ],
            "B": [
                Advice(name: "俺", text: "今は明日のことを考えよう"),
                Advice(name: "谷口", text: "分かった。大塚さん、もう少し預かってください"),
            ],
        ]
    )

    // MARK: N17 王者の重圧（優勝経験者のみ）
    private static let lateN17 = ChoiceEventText(
        title: "王者の重圧",
        setup: [
            Advice(name: nil, text: "劇場の応接室。昼。"),
            Advice(name: "真壁", text: "次の大会では、王者として見られると思います"),
            Advice(name: "谷口", text: "なんだか落ち着かないね"),
            Advice(name: "俺", text: "勝って当然と言われるのは、初めてだな"),
        ],
        choiceLabels: [
            "A": "重さを認めて、稽古を増やす",
            "B": "肩書きは忘れて、普段どおりに臨む",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "正直、怖い。だから稽古を増やしたい"),
                Advice(name: "谷口", text: "うん。付き合うよ"),
            ],
            "B": [
                Advice(name: "谷口", text: "いつもの舞台と思えばいいかな"),
                Advice(name: "俺", text: "そう思うことにするよ"),
            ],
        ]
    )

    // MARK: N18 王座を失った翌年（優勝経験者のみ）
    private static let lateN18 = ChoiceEventText(
        title: "王座を失った翌年",
        setup: [
            Advice(name: nil, text: "稽古場。昼。"),
            Advice(name: "谷口", text: "去年の大会で、王座を譲ってから一年か"),
            Advice(name: "俺", text: "あの結果は、今でも覚えてる"),
            Advice(name: "谷口", text: "今年の大会は、どう向き合おうか"),
        ],
        choiceLabels: [
            "A": "もう一度、王座を取りに行く",
            "B": "結果にこだわらず、舞台を楽しむ",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "取り返したい。そのための稽古をしよう"),
                Advice(name: "谷口", text: "分かった。計画を立てよう"),
            ],
            "B": [
                Advice(name: "谷口", text: "今年は肩の力を抜いてやろう"),
                Advice(name: "俺", text: "そうだね。無理はしないでいこう"),
            ],
        ]
    )

    // MARK: N19 連覇中の年の予定（優勝経験者のみ）
    private static let lateN19 = ChoiceEventText(
        title: "連覇中の年の予定",
        setup: [
            Advice(name: nil, text: "事務所の掲示板の前。朝。"),
            Advice(name: "谷口", text: "今年の予定表、もう貼り出されたね"),
            Advice(name: "俺", text: "今年も大会まで出番が多いな"),
            Advice(name: "谷口", text: "うん。それで最近、稽古が減ってるのが心配なんだ"),
        ],
        choiceLabels: [
            "A": "来週から稽古の時間を増やす",
            "B": "今の予定のまま、無理をしない",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "そうだね。来週から増やそう"),
                Advice(name: "谷口", text: "分かった。予定を組み直そう"),
            ],
            "B": [
                Advice(name: "俺", text: "連覇中だし、今の予定は変えたくないな"),
                Advice(name: "谷口", text: "分かった。じゃあ、体調には気をつけよう"),
            ],
        ]
    )

    // MARK: N20 受付の学生に聞かれる（優勝経験者のみ）
    private static let lateN20 = ChoiceEventText(
        title: "受付の学生に聞かれる",
        setup: [
            Advice(name: nil, text: "劇場の受付。夕方。"),
            Advice(name: "学生", text: "来月、初めての面接なんです。優勝したあとも緊張しますか"),
            Advice(name: "谷口", text: "どう答えようか"),
            Advice(name: "俺", text: "正直に話すしかないな"),
        ],
        choiceLabels: [
            "A": "毎回緊張すると正直に話す",
            "B": "前の晩の過ごし方を教える",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "優勝しても、毎回緊張するよ"),
                Advice(name: "学生", text: "そうなんですね。少し安心しました"),
            ],
            "B": [
                Advice(name: "谷口", text: "前の晩は、早く寝るといいよ"),
                Advice(name: "学生", text: "ありがとうございます。やってみます"),
            ],
        ]
    )

}
