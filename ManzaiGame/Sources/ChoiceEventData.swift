// ChoiceEventData.swift
// 選択肢イベントの本文（正典: proposals/0010・0017・0018・0019・0021。各docでレッドチーム済み確定テキストの転記）。
// 谷口版のみ（相方ガチャ/周回は本編未実装＝MVP1年完結のスコープ外）。manzai-choice-events + manzai-drama-voice
// 採点済（E1〜E7・A表・B表）。地の文は name=nil（ナレーション扱い）、セリフは話者名を持つ。

import GameCore

struct ChoiceEventText {
    let title: String                    // 画面上部の小見出し【仮】
    let setup: [Advice]                  // 地の文＋導入会話（タップで1つずつ送る）
    let choiceLabels: [String: String]   // 選択肢ボタンのラベル
    let afterChoice: [String: [Advice]]  // 選択後の会話
}

/// イベントの場面（見た目の作り直し v1 §4-1）。楽屋＝昼の稽古場／夕景＝夜の日常（暗紫は使わない・明るい暖色）
enum EventScene { case keiko, dusk }

enum ChoiceEventData {
    /// 場面の既定値。夜の出来事（前夜・飲み会・書けた夜・終電・負けた日）は夕景、他は昼の稽古場【仮】
    static func scene(for kind: ChoiceEventKind) -> EventScene {
        switch kind {
        case .preTournamentEve, .brokeDrinkingInvite, .wroteOneTonight, .lastTrainReview, .justLostRehearsal:
            return .dusk
        default:
            return .keiko
        }
    }

    static func text(for kind: ChoiceEventKind) -> ChoiceEventText {
        switch kind {
        case .justLostRehearsal: return justLostRehearsal
        case .styleTalk: return styleTalk
        case .justPassedFork: return justPassedFork
        case .preTournamentEve: return preTournamentEve
        case .tsuukaBreak: return tsuukaBreak
        case .earlyFormality: return earlyFormality
        case .brokeDrinkingInvite: return brokeDrinkingInvite
        case .senpaiMeishi: return senpaiMeishi
        case .peerFoldedChair: return peerFoldedChair
        case .namelessReservationSlip: return namelessReservationSlip
        case .lineupTop: return lineupTop
        case .greenroomSilentTen: return greenroomSilentTen
        case .lastTrainReview: return lastTrainReview
        case .luckyThirdLine: return luckyThirdLine
        case .regularEmployment: return regularEmployment
        case .wroteOneTonight: return wroteOneTonight
        case .taniguchiShortJob: return taniguchiShortJob
        case .photoShootOffer: return photoShootOffer
        }
    }

    // MARK: 0017 負けた日の稽古場

    private static let justLostRehearsal = ChoiceEventText(
        title: "負けた日の稽古場",
        setup: [
            Advice(name: nil, text: "稽古場。負けた翌週の夕方。"),
            Advice(name: "俺", text: "講評、読んだか"),
            Advice(name: "谷口", text: "読んだ。言われたこと、ほとんど同じやったな"),
            Advice(name: "俺", text: "今日どうする。直すか、休むか"),
            Advice(name: "谷口", text: "お前に任せるわ。正直、まだ頭が回ってへん"),
        ],
        choiceLabels: [
            "A": "敗因を掘る",
            "B": "今日は畳む",
            "C": "場所を変える",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "直そう。崩れたところから始める"),
                Advice(name: "谷口", text: "わかった。声出るとこまでやろ"),
            ],
            "B": [
                Advice(name: "俺", text: "今日はやめよう。明日、朝から集まろう"),
                Advice(name: "谷口", text: "助かるわ。明日はちゃんと来る"),
            ],
            "C": [
                Advice(name: "俺", text: "ここじゃ考えがまとまらない。外で飯食いながら話そう"),
                Advice(name: "谷口", text: "ええな。そのほうが話せそうや"),
            ],
        ]
    )

    // MARK: 0019 型を捨てる相談

    private static let styleTalk = ChoiceEventText(
        title: "型を捨てる相談",
        setup: [
            Advice(name: nil, text: "稽古場。三週続けて落ちた週。"),
            Advice(name: "俺", text: "三回とも、同じところで落ちてる"),
            Advice(name: "谷口", text: "ネタのせいか、俺らのせいか、どっちやろな"),
            Advice(name: "俺", text: "たぶん両方だ。型ごと変えるか、このまま磨くか決めたい"),
        ],
        choiceLabels: [
            "A": "新機軸に作り替える",
            "B": "型を通して磨き込む",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "作り替えよう。今の型はいったん崩す"),
                Advice(name: "谷口", text: "わかった。噛み合うてるとこも一回ばらすことになるけど、ええんやな"),
                Advice(name: "俺", text: "ああ。同じ負け方はもうしたくない"),
            ],
            "B": [
                Advice(name: "俺", text: "変えない。この型のまま精度を上げよう"),
                Advice(name: "谷口", text: "俺もそれがええ。この形、好きやねん"),
            ],
        ]
    )

    // MARK: 0018 通った日の分かれ道

    private static let justPassedFork = ChoiceEventText(
        title: "通った日の分かれ道",
        setup: [
            Advice(name: nil, text: "楽屋。回戦を通過した夜。"),
            Advice(name: "谷口", text: "通ったな。次まで、まだ日があるで"),
            Advice(name: "俺", text: "この勢いで舞台を増やすか、次に備えて絞るか"),
            Advice(name: "谷口", text: "どっちもありやな。お前はどう思う"),
        ],
        choiceLabels: [
            "A": "勢いで露出・場数に賭ける",
            "B": "引き締めて次戦に備える",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "今は出られるだけ出よう。場数が欲しい"),
                Advice(name: "谷口", text: "よっしゃ。ライブの空き、探しとくわ"),
            ],
            "B": [
                Advice(name: "俺", text: "浮かれずに次の準備をしよう"),
                Advice(name: "谷口", text: "せやな。次で落ちたら意味ないもんな"),
            ],
        ]
    )

    // MARK: 0010 前夜の一本

    private static let preTournamentEve = ChoiceEventText(
        title: "前夜の一本",
        setup: [
            Advice(name: nil, text: "稽古場。大会の前の夜。"),
            Advice(name: "谷口", text: "明日やな。もう一回通すか"),
            Advice(name: "俺", text: "迷ってる。詰めたいけど、疲れも残したくない"),
        ],
        choiceLabels: [
            "A": "残って詰める",
            "B": "早めに切り上げる",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "あと一回だけ通そう。後半が不安だ"),
                Advice(name: "谷口", text: "わかった。終わったらすぐ帰ろな"),
            ],
            "B": [
                Advice(name: "俺", text: "今日はここまでにしよう。明日に残す"),
                Advice(name: "谷口", text: "せやな。よう寝て、明日に合わせよ"),
            ],
        ]
    )

    // MARK: 0021 慣れの外し方

    private static let tsuukaBreak = ChoiceEventText(
        title: "慣れの外し方",
        setup: [
            Advice(name: nil, text: "稽古場。ネタが仕上がってきた週。"),
            Advice(name: "谷口", text: "最近、合わせがすんなりいくな"),
            Advice(name: "俺", text: "慣れてきた。でも、慣れすぎるのも怖い"),
            Advice(name: "谷口", text: "わざと崩してみるか、このまま固めるか、やな"),
        ],
        choiceLabels: [
            "A": "あえて崩す実験に出る",
            "B": "完成した呼吸を固める",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "一回崩して、新しいことを試そう"),
                Advice(name: "谷口", text: "おもろそうや。失敗してもええ時期やしな"),
            ],
            "B": [
                Advice(name: "俺", text: "今の呼吸を固めよう。せっかく合ってきた"),
                Advice(name: "谷口", text: "わかった。このまま仕上げよか"),
            ],
        ]
    )

    // MARK: 0020 まだ敬語の残る間

    private static let earlyFormality = ChoiceEventText(
        title: "まだ敬語の残る間",
        setup: [
            Advice(name: nil, text: "稽古場。組んでまだ間もない頃。"),
            Advice(name: "谷口", text: "あの……このネタ、ここ変えてもいいですか"),
            Advice(name: "俺", text: "敬語、まだ抜けないな"),
            Advice(name: "谷口", text: "なんか、まだ遠慮してしもて"),
        ],
        choiceLabels: [
            "A": "踏み込んで言う",
            "B": "間合いを保つ",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "思ったことは遠慮なく言ってくれ。俺も言う"),
                Advice(name: "谷口", text: "……わかった。ほな、言うで"),
            ],
            "B": [
                Advice(name: "俺", text: "無理に崩さなくていい。少しずつでいいよ"),
                Advice(name: "谷口", text: "ありがとう。慣れるまで待っててな"),
            ],
        ]
    )

    // MARK: 0011 行けない飲み会（週次抽選・低所持金帯。proposals/0011 レッドチーム済み確定テキストを転記）

    private static let brokeDrinkingInvite = ChoiceEventText(
        title: "行けない飲み会",
        setup: [
            Advice(name: nil, text: "稽古場。金のない月の夜。"),
            Advice(name: "谷口", text: "先輩から飲み会の誘いや。顔出したほうがええかな"),
            Advice(name: "俺", text: "行けば顔はつながる。でも、金がない"),
            Advice(name: "谷口", text: "稽古もしたいしな。どうする"),
        ],
        choiceLabels: [
            "A": "行く",
            "B": "断って稽古場に残る",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "行こう。先輩とのつながりは大事だ"),
                Advice(name: "谷口", text: "了解。一杯だけで帰ろな"),
            ],
            "B": [
                Advice(name: "俺", text: "断って、ここで稽古しよう"),
                Advice(name: "谷口", text: "せやな。先輩には俺から謝っとくわ"),
            ],
        ]
    )

    // MARK: 0013 先輩の名刺（週次抽選・奢られる帯。proposals/0013 レッドチーム済み確定テキストを転記）
    //   第三者「先輩」は関西弁の漫才の先輩＝proposal 確定テキストに準拠（谷口以外の相方は標準語だが本第三者は例外）。

    private static let senpaiMeishi = ChoiceEventText(
        title: "先輩の名刺",
        setup: [
            Advice(name: nil, text: "焼肉屋。先輩のおごり。"),
            Advice(name: "先輩", text: "番組の人、紹介しようか。お前ら、そろそろ出てもいい頃だろ"),
            Advice(name: "俺", text: "ありがたいです。……少し考えさせてください"),
            Advice(name: "谷口", text: "ええ話やと思うけど、まだ早い気もするな"),
        ],
        choiceLabels: [
            "A": "紹介を受ける",
            "B": "飯だけ頂き、紹介は辞退する",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "お願いします。紹介してください"),
                Advice(name: "先輩", text: "おう。ちゃんと準備しとけよ"),
                Advice(name: "谷口", text: "がんばろな"),
            ],
            "B": [
                Advice(name: "俺", text: "ご飯だけいただきます。紹介は、もう少し力をつけてからで"),
                Advice(name: "先輩", text: "そうか。その気になったら言えよ"),
            ],
        ]
    )

    // MARK: 0015 畳んだコンビの椅子（週次抽選・芸歴帯。proposals/0015 レッドチーム済み確定テキストを転記）
    //   相性帯差し替え（0-7/8-14/15-20）は本編で足す枠＝MVPは基本プール（谷口）。

    private static let peerFoldedChair = ChoiceEventText(
        title: "畳んだコンビの椅子",
        setup: [
            Advice(name: nil, text: "劇場の裏。同期が解散を決めた日。"),
            Advice(name: "谷口", text: "あいつら、今日で終わりやって"),
            Advice(name: "俺", text: "出てた枠が一つ空くな"),
            Advice(name: "谷口", text: "その枠、うちに回ってくるかもしれへん"),
        ],
        choiceLabels: [
            "A": "空き枠を引き継ぐ",
            "B": "枠は取らず、送り出しだけする",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "空いた枠、引き継がせてもらおう"),
                Advice(name: "谷口", text: "わかった。あいつらのぶんまでやろ"),
            ],
            "B": [
                Advice(name: "俺", text: "枠はいい。今日は送り出すだけにしよう"),
                Advice(name: "谷口", text: "せやな。今日はそれがええ"),
            ],
        ]
    )

    // MARK: 0028 名前の無い予約票（確定発火・選択肢なしフレーバー。proposals/0028 レッドチーム済み確定テキストを転記）
    //   俺（標準語・地の文）／谷口（関西弁）の2話者。効果なし＝会話（セットアップ→締め）を送り切って閉じる。

    private static let namelessReservationSlip = ChoiceEventText(
        title: "名前の無い予約票",
        setup: [
            Advice(name: nil, text: "稽古場の受付。来週の予約。"),
            Advice(name: "俺", text: "予約票、俺たちの名前で取っておいた"),
            Advice(name: "谷口", text: "おお、ありがとう。いつも助かるわ"),
            Advice(name: "俺", text: "来週は二回取れた。どっちも使おう"),
            Advice(name: "谷口", text: "了解。ネタも二本持ってくわ"),
        ],
        choiceLabels: [:],
        afterChoice: [:]
    )

    // MARK: 0025 香盤表の一番上（週次・前座帯フレーバー。proposals/0025 レッドチーム済み確定テキストを転記）

    private static let lineupTop = ChoiceEventText(
        title: "香盤表の一番上",
        setup: [
            Advice(name: nil, text: "楽屋。香盤表が貼り出された日。"),
            Advice(name: "谷口", text: "見て。今日、うちらが一番上や"),
            Advice(name: "俺", text: "本当だ。トリ前じゃなく、トップか"),
            Advice(name: "谷口", text: "最初に出るの、緊張するな"),
            Advice(name: "俺", text: "でも客が温まる前に掴めたら強い。頭を固めよう"),
        ],
        choiceLabels: [:],
        afterChoice: [:]
    )

    // MARK: 0022 撮られる仕事（週次・知名度20-50・選択肢あり。proposals/0022 レッドチーム済み確定テキストを転記）
    //   popup2択イベント（機構実装済み）＝rollOffer 非依存＝golden不変。A の機会費用は体力-15 で近似（週奪いはPhase2）。

    private static let photoShootOffer = ChoiceEventText(
        title: "撮られる仕事",
        setup: [
            Advice(name: nil, text: "事務所。撮影の仕事の話。"),
            Advice(name: "マネージャー", text: "若手特集の撮影が来てる。丸一日かかるけど、ネタはやらなくていい"),
            Advice(name: "俺", text: "顔が出るのはありがたい。でも、一日稽古できない"),
            Advice(name: "谷口", text: "どうする。俺はどっちでもええで"),
        ],
        choiceLabels: [
            "A": "受ける",
            "B": "断って稽古に充てる",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "受けよう。名前を覚えてもらういい機会だ"),
                Advice(name: "谷口", text: "よっしゃ。ちゃんとした服、着ていかなな"),
            ],
            "B": [
                Advice(name: "俺", text: "断ろう。今は稽古を優先したい"),
                Advice(name: "谷口", text: "わかった。その分、しっかりやろ"),
            ],
        ]
    )

    // MARK: 0012 谷口の耳寄りな話（確定発火・金欠帯・選択肢あり。proposals/0012 レッドチーム済み確定テキストを転記）
    //   A の「相性成長3週停止」は compatFreeze(3)＝GameEngine.add(.コンビ相性) の inert ゲートで golden 不変。

    private static let taniguchiShortJob = ChoiceEventText(
        title: "耳寄りな話",
        setup: [
            Advice(name: nil, text: "稽古場。谷口が求人票を持ってきた。"),
            Advice(name: "谷口", text: "短期のバイト、二人で入らへん？ けっこう稼げるで"),
            Advice(name: "俺", text: "金は助かる。でも稽古の時間が減る"),
        ],
        choiceLabels: [
            "A": "二人で受ける",
            "B": "断って、稽古を選ぶ",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "やろう。今は金が要る"),
                Advice(name: "谷口", text: "決まりや。終わったら稽古しよな"),
            ],
            "B": [
                Advice(name: "俺", text: "悪い、今は稽古を選びたい"),
                Advice(name: "谷口", text: "わかった。お前がそう言うなら、そうしよ"),
            ],
        ]
    )

    // MARK: 0016 書けた一本（週次・持ちネタあり・選択肢あり。proposals/0016 レッドチーム済み確定テキストを転記）
    //   B の「翌週のネタ合わせ効果アップ」は翌週バフ機構が要る＝Phase2。本文は"寝かせる"の手触りを保つ。

    private static let wroteOneTonight = ChoiceEventText(
        title: "書けた一本",
        setup: [
            Advice(name: nil, text: "稽古場。深夜。"),
            Advice(name: "谷口", text: "書けた。これ、いけると思う"),
            Advice(name: "俺", text: "読ませてくれ。……いいな、これ"),
            Advice(name: "谷口", text: "今から詰めるか？ もう遅いけど"),
        ],
        choiceLabels: [
            "A": "今夜のうちに詰める",
            "B": "寝かせて、明日の目で見る",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "今のうちに詰めよう。熱があるうちがいい"),
                Advice(name: "谷口", text: "よっしゃ。もうひと頑張りや"),
            ],
            "B": [
                Advice(name: "俺", text: "一晩寝かせよう。明日、もう一回読む"),
                Advice(name: "谷口", text: "せやな。朝に読んだら、また違うかもしれへん"),
            ],
        ]
    )

    // MARK: 0023 正社員の話（週次・金欠帯・選択肢あり。proposals/0023 レッドチーム済み確定テキストを転記）
    //   第三者「店長」＝標準語。段階2（growthBudget減算＝天井）は規律Aで後日・本文は段階1に対応。

    private static let regularEmployment = ChoiceEventText(
        title: "正社員の話",
        setup: [
            Advice(name: nil, text: "バイト先の事務所。"),
            Advice(name: "店長", text: "正社員にならないか。給料も上がるし、生活は安定するよ"),
            Advice(name: "俺", text: "ありがたい話です。でも、ネタに使える時間が減ります"),
            Advice(name: "谷口", text: "お前の人生やし、お前が決めたらええで"),
        ],
        choiceLabels: [
            "A": "受ける",
            "B": "断る",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "受けます。生活を立て直したい"),
                Advice(name: "店長", text: "助かるよ。稽古の日は、できるだけ配慮する"),
                Advice(name: "谷口", text: "わかった。俺も時間合わせるわ"),
            ],
            "B": [
                Advice(name: "俺", text: "すみません。今は芸人一本でやりたいです"),
                Advice(name: "店長", text: "そうか。応援してるよ"),
            ],
        ]
    )

    // MARK: 0014 終電までの反省会（週次・前座帯・選択肢あり。proposals/0014 レッドチーム済み確定テキストを転記）
    //   A の「センスまたは発想+2＝プレイヤーが1軸選ぶ」は MVP では weakerSenseIdeaPlus（低い方に決定的加算）に簡略。

    private static let lastTrainReview = ChoiceEventText(
        title: "終電までの反省会",
        setup: [
            Advice(name: nil, text: "駅のホーム。フリーライブの帰り。"),
            Advice(name: "谷口", text: "今日、客八人やったな"),
            Advice(name: "俺", text: "反応も薄かった。何が悪かったんだろう"),
            Advice(name: "谷口", text: "終電まで、まだちょっとあるで"),
        ],
        choiceLabels: [
            "A": "その場で敗因を洗う",
            "B": "今日は畳んで二人で立て直す",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "今のうちに洗い出そう。忘れないうちに"),
                Advice(name: "谷口", text: "わかった。まず出だしからやな"),
            ],
            "B": [
                Advice(name: "俺", text: "今日はもう帰ろう。明日、落ち着いて話そう"),
                Advice(name: "谷口", text: "せやな。今日は疲れたわ"),
            ],
        ]
    )

    // MARK: 0029 三行目を一度で（週次・好調帯フレーバー。proposals/0029 レッドチーム済み確定テキストを転記）

    private static let luckyThirdLine = ChoiceEventText(
        title: "三行目を一度で",
        setup: [
            Advice(name: nil, text: "稽古場。ネタ合わせの途中。"),
            Advice(name: "谷口", text: "今の三行目、初めてうまくいったな"),
            Advice(name: "俺", text: "ずっと詰まってたところだ。今の感じ、忘れないうちにもう一回やろう"),
            Advice(name: "谷口", text: "よっしゃ、もう一回や"),
        ],
        choiceLabels: [:],
        afterChoice: [:]
    )

    // MARK: 0027 楽屋で無言の十分（週次・噛み合い帯フレーバー。proposals/0027 レッドチーム済み確定テキストを転記）

    private static let greenroomSilentTen = ChoiceEventText(
        title: "楽屋で無言の十分",
        setup: [
            Advice(name: nil, text: "楽屋。ウケなかったライブの後。"),
            Advice(name: "谷口", text: "……今日は、あかんかったな"),
            Advice(name: "俺", text: "頭の三十秒だけだった。そこから客が離れた"),
            Advice(name: "谷口", text: "ちょっと休んでから話そか"),
            Advice(name: "俺", text: "そうしよう。落ち着いたら、どこで離れたか確かめる"),
        ],
        choiceLabels: [:],
        afterChoice: [:]
    )
}
