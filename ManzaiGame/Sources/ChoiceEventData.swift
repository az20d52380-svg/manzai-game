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
        title: "負けた次の週",
        setup: [
            Advice(name: nil, text: "稽古場の前。大会に負けた次の週の夜。"),
            Advice(name: "谷口", text: "負けてから、飯の味があんまりせえへんねん"),
            Advice(name: "俺", text: "俺もだ。ちゃんと寝てるか"),
            Advice(name: "谷口", text: "あんまりや。今夜、このあとどないする"),
        ],
        choiceLabels: [
            "A": "遅くまで残って稽古する",
            "B": "今日はまっすぐ帰って寝る",
            "C": "二人でラーメンを食べに行く",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "悔しいから、もう少し残ろう"),
                Advice(name: "谷口", text: "ほな、終電までには上がろな"),
            ],
            "B": [
                Advice(name: "俺", text: "今日は帰って寝よう。話は明日だ"),
                Advice(name: "谷口", text: "せやな。風呂入って、早よ寝るわ"),
            ],
            "C": [
                Advice(name: "俺", text: "ラーメン行こう。今日は俺が出す"),
                Advice(name: "谷口", text: "ほんまか。ありがとう、ちょっと元気出たわ"),
            ],
        ]
    )

    // MARK: 0019 型を捨てる相談

    private static let styleTalk = ChoiceEventText(
        title: "続けて落ちた週",
        setup: [
            Advice(name: nil, text: "稽古場。大会に三回続けて落ちた週の昼。"),
            Advice(name: "谷口", text: "三回続けてやと、さすがにこたえるな"),
            Advice(name: "俺", text: "顔色悪いぞ。飯、食べてるか"),
            Advice(name: "谷口", text: "まあな。毎日会うとると、ちょっと息が詰まるわ"),
        ],
        choiceLabels: [
            "A": "しばらく一人で知らない町を歩く",
            "B": "休まず毎日いっしょに稽古する",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "少し離れよう。俺は一人で、知らない町でも歩いてくる"),
                Advice(name: "谷口", text: "わかった。しばらく連絡も控えとくわ"),
            ],
            "B": [
                Advice(name: "俺", text: "離れないでいこう。毎日ここに来る"),
                Advice(name: "谷口", text: "ええよ。しんどいけど、付き合うわ"),
            ],
        ]
    )

    // MARK: 0018 通った日の分かれ道

    private static let justPassedFork = ChoiceEventText(
        title: "通った週の誘い",
        setup: [
            Advice(name: nil, text: "稽古場。予選を通った次の週の昼。"),
            Advice(name: "谷口", text: "通ってから、えらい飲み会に呼ばれるようになったな"),
            Advice(name: "俺", text: "今週だけで三つだぞ。体、もつか"),
            Advice(name: "谷口", text: "全部行ったら顔は売れるな。ほんまは家で映画でも観てたいねん"),
        ],
        choiceLabels: [
            "A": "誘われた飲み会に全部顔を出す",
            "B": "谷口の家で古い映画を観る",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "せっかく呼ばれたんだ。全部行こう"),
                Advice(name: "谷口", text: "よっしゃ。しばらく寝不足やな"),
            ],
            "B": [
                Advice(name: "俺", text: "今週は断ろう。お前の家で映画を観よう"),
                Advice(name: "谷口", text: "ええな。古いのが何本かあるねん"),
            ],
        ]
    )

    // MARK: 0010 前夜の一本

    private static let preTournamentEve = ChoiceEventText(
        title: "大会の前の夜",
        setup: [
            Advice(name: nil, text: "稽古場の帰り道。大会の前の夜。"),
            Advice(name: "谷口", text: "明日の大会、駅に集合でええか"),
            Advice(name: "俺", text: "ああ。寝坊するなよ"),
            Advice(name: "谷口", text: "わかっとる。でも緊張して、寝られへんかもしれん"),
        ],
        choiceLabels: [
            "A": "もう少しだけ稽古して帰る",
            "B": "早めに帰って、よく寝る",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "もう一回だけやろう。そのほうが落ち着く"),
                Advice(name: "谷口", text: "おう。終わったら、すぐ帰ろな"),
            ],
            "B": [
                Advice(name: "俺", text: "今日はもう帰ろう。飯食って、早く寝る"),
                Advice(name: "谷口", text: "ほな明日、駅でな"),
            ],
        ]
    )

    // MARK: 0021 慣れの外し方

    private static let tsuukaBreak = ChoiceEventText(
        title: "地元の友だち",
        setup: [
            Advice(name: nil, text: "稽古場。昼休み。"),
            Advice(name: "谷口", text: "今度、地元の連れがこっちに遊びに来るねん"),
            Advice(name: "俺", text: "そうか。久しぶりなのか"),
            Advice(name: "谷口", text: "一年ぶりやねん。お前も一緒に会わへん？"),
        ],
        choiceLabels: [
            "A": "断って、夜更かしして本を読む",
            "B": "谷口の地元の友だちに会う",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "悪い。その日は一人で、たまった本を読む"),
                Advice(name: "谷口", text: "そうか。夜更かしは、ほどほどにしいや"),
            ],
            "B": [
                Advice(name: "俺", text: "会うよ。店は俺が探しておく"),
                Advice(name: "谷口", text: "よかった。あいつらも喜ぶわ"),
            ],
        ]
    )

    // MARK: 0020 まだ敬語の残る間

    private static let earlyFormality = ChoiceEventText(
        title: "まだ敬語の頃",
        setup: [
            Advice(name: nil, text: "稽古場。組んだばかりの頃の昼。"),
            Advice(name: "谷口", text: "すんません、家ってこの近くなんですか"),
            Advice(name: "俺", text: "電車で二駅だ。敬語、まだ抜けないな"),
            Advice(name: "谷口", text: "なんか遠慮してしもて。今度、うちで飯でもどうですか"),
        ],
        choiceLabels: [
            "A": "今夜、谷口の家で朝まで話す",
            "B": "今日は帰って、ゆっくり休む",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "なら今夜行くよ。朝まで付き合う"),
                Advice(name: "谷口", text: "ほんまに？ ほな、鍋の用意しとくわ"),
            ],
            "B": [
                Advice(name: "俺", text: "今日は帰って寝るよ。また今度な"),
                Advice(name: "谷口", text: "わかりました。ほな、また今度"),
            ],
        ]
    )

    // MARK: 0011 行けない飲み会（週次抽選・低所持金帯。proposals/0011 レッドチーム済み確定テキストを転記）

    private static let brokeDrinkingInvite = ChoiceEventText(
        title: "月末の飲み会",
        setup: [
            Advice(name: nil, text: "稽古場の帰り道。月末の夜。"),
            Advice(name: "谷口", text: "先輩から飲みの誘いや。会費、けっこうするらしいで"),
            Advice(name: "俺", text: "今月は家賃を払ったら、ほとんど残らないぞ"),
            Advice(name: "谷口", text: "俺は顔出そかな思てる。お前はどうする"),
        ],
        choiceLabels: [
            "A": "谷口と先輩の飲み会に行く",
            "B": "断って、家で自炊する",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "行こう。たまには外で飲みたい"),
                Advice(name: "谷口", text: "よっしゃ。帰りは一緒に歩こな"),
            ],
            "B": [
                Advice(name: "俺", text: "今月はやめとく。冷蔵庫の残りで何か作るよ"),
                Advice(name: "谷口", text: "そうか。先輩には、よろしく言うとくわ"),
            ],
        ]
    )

    // MARK: 0013 先輩の名刺（週次抽選・奢られる帯。proposals/0013 レッドチーム済み確定テキストを転記）
    //   第三者「先輩」は関西弁の漫才の先輩＝proposal 確定テキストに準拠（谷口以外の相方は標準語だが本第三者は例外）。

    private static let senpaiMeishi = ChoiceEventText(
        title: "先輩のおごり",
        setup: [
            Advice(name: nil, text: "焼肉屋。先輩のおごりの昼。"),
            Advice(name: "先輩", text: "遠慮しないで食べろよ。お前ら、ちゃんと食ってるか"),
            Advice(name: "俺", text: "ありがとうございます。肉は久しぶりです"),
            Advice(name: "先輩", text: "今度、知り合いの集まりがあるんだ。一緒に来るか"),
            Advice(name: "谷口", text: "人の多いとこ、ちょっと苦手やねん"),
        ],
        choiceLabels: [
            "A": "先輩の集まりについて行く",
            "B": "今日はごちそうになるだけにする",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "行かせてください。ちゃんとした服で行きます"),
                Advice(name: "先輩", text: "おう。いろんな人に紹介してやる"),
                Advice(name: "谷口", text: "緊張するけど、がんばろな"),
            ],
            "B": [
                Advice(name: "俺", text: "今回は、ごちそうになるだけにさせてください"),
                Advice(name: "先輩", text: "そうか。じゃあ、もっと食え"),
                Advice(name: "谷口", text: "ほな、遠慮なくいただきます"),
            ],
        ]
    )

    // MARK: 0015 畳んだコンビの椅子（週次抽選・芸歴帯。proposals/0015 レッドチーム済み確定テキストを転記）
    //   相性帯差し替え（0-7/8-14/15-20）は本編で足す枠＝MVPは基本プール（谷口）。

    private static let peerFoldedChair = ChoiceEventText(
        title: "同期が辞める日",
        setup: [
            Advice(name: nil, text: "稽古場。同期が辞めると聞いた日。"),
            Advice(name: "谷口", text: "あいつ、来月で辞めて地元に帰るんやて"),
            Advice(name: "俺", text: "そうか。寂しくなるな"),
            Advice(name: "谷口", text: "商店街の手伝い、誰かに継いでほしいらしい。見送りもせなな"),
        ],
        choiceLabels: [
            "A": "商店街の手伝いを引き継ぐ",
            "B": "二人で駅まで見送りに行く",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "俺たちで継ごう。町の人にも顔を覚えてもらえる"),
                Advice(name: "谷口", text: "ほな決まりや。しばらく忙しなるな"),
            ],
            "B": [
                Advice(name: "俺", text: "手伝いは断ろう。見送りは二人で行こう"),
                Advice(name: "谷口", text: "せやな。最後に、ちゃんと礼言いたいわ"),
            ],
        ]
    )

    // MARK: 0028 名前の無い予約票（確定発火・選択肢なしフレーバー。proposals/0028 レッドチーム済み確定テキストを転記）
    //   俺（標準語・地の文）／谷口（関西弁）の2話者。効果なし＝会話（セットアップ→締め）を送り切って閉じる。

    private static let namelessReservationSlip = ChoiceEventText(
        title: "受付の飴",
        setup: [
            Advice(name: nil, text: "稽古場の受付。昼。"),
            Advice(name: "谷口", text: "来週の稽古場、取っといたで"),
            Advice(name: "俺", text: "ありがとう。いつも助かる"),
            Advice(name: "谷口", text: "受付の人に飴もろたわ。一個やる"),
            Advice(name: "俺", text: "もらう。帰りにお礼言っておこう"),
        ],
        choiceLabels: [:],
        afterChoice: [:]
    )

    // MARK: 0025 香盤表の一番上（週次・前座帯フレーバー。proposals/0025 レッドチーム済み確定テキストを転記）

    private static let lineupTop = ChoiceEventText(
        title: "一番最初の出番",
        setup: [
            Advice(name: nil, text: "劇場の楽屋。ライブの日の昼。"),
            Advice(name: "谷口", text: "今日、うちらが一番最初の出番やて"),
            Advice(name: "俺", text: "そうか。緊張するな"),
            Advice(name: "谷口", text: "昼飯、軽めにしとこか。おにぎり買うてきたで"),
            Advice(name: "俺", text: "ありがとう。一個もらう"),
        ],
        choiceLabels: [:],
        afterChoice: [:]
    )

    // MARK: 0022 撮られる仕事（週次・知名度20-50・選択肢あり。proposals/0022 レッドチーム済み確定テキストを転記）
    //   popup2択イベント（機構実装済み）＝rollOffer 非依存＝golden不変。A の機会費用は体力-15 で近似（週奪いはPhase2）。

    private static let photoShootOffer = ChoiceEventText(
        title: "撮影の話",
        setup: [
            Advice(name: nil, text: "事務所。昼。"),
            Advice(name: "マネージャー", text: "情報誌の撮影の話が来てる。その週は撮影で埋まるけど、どうする"),
            Advice(name: "俺", text: "その週は、稽古できないですね"),
            Advice(name: "谷口", text: "撮られるのは慣れてへんけど、お金は出るらしいで"),
        ],
        choiceLabels: [
            "A": "撮影の仕事を引き受ける",
            "B": "断って、いつも通り稽古する",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "受けます。よろしくお願いします"),
                Advice(name: "谷口", text: "ほな、髪切りに行かなあかんな"),
            ],
            "B": [
                Advice(name: "俺", text: "今回はやめておきます。すみません"),
                Advice(name: "谷口", text: "了解。その分、稽古がんばろな"),
            ],
        ]
    )

    // MARK: 0012 谷口の耳寄りな話（確定発火・金欠帯・選択肢あり。proposals/0012 レッドチーム済み確定テキストを転記）
    //   A は所持金↑・体力↓（夜勤はしんどいが芸人は皆やっている＝相方と会えなくなる前提は置かない）。

    private static let taniguchiShortJob = ChoiceEventText(
        title: "短期バイトの話",
        setup: [
            Advice(name: nil, text: "稽古場。月末の昼。"),
            Advice(name: "谷口", text: "これ見て。倉庫の短期バイト、二人で入らへん？"),
            Advice(name: "俺", text: "けっこう稼げるな。でも、夜勤か"),
            Advice(name: "谷口", text: "きついけど、二人なら続けられるやろ。稽古は昼にやろ"),
        ],
        choiceLabels: [
            "A": "二人で倉庫の夜勤に入る",
            "B": "今回は断って、今の暮らしを続ける",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "やろう。今は金が要る"),
                Advice(name: "谷口", text: "決まりや。体は削れるけど、稼ぐで"),
            ],
            "B": [
                Advice(name: "俺", text: "やめておこう。夜勤が続くのはきつい"),
                Advice(name: "谷口", text: "わかった。金のことは、また二人で考えよ"),
            ],
        ]
    )

    // MARK: 0016 書けた一本（週次・持ちネタあり・選択肢あり。proposals/0016 レッドチーム済み確定テキストを転記）
    //   B の「翌週のネタ合わせ効果アップ」は翌週バフ機構が要る＝Phase2。本文は"寝かせる"の手触りを保つ。

    private static let wroteOneTonight = ChoiceEventText(
        title: "目が冴えた夜",
        setup: [
            Advice(name: nil, text: "深夜のファミレス。稽古の帰り。"),
            Advice(name: "谷口", text: "なんか今日、目が冴えてしゃあないわ"),
            Advice(name: "俺", text: "もう夜中だぞ。明日、起きられるか"),
            Advice(name: "谷口", text: "もうちょい粘ろか。話したいこと、まだあんねん"),
        ],
        choiceLabels: [
            "A": "朝まで二人で話し込む",
            "B": "今日は帰ってぐっすり寝る",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "朝まで付き合うよ。今日は話が尽きない"),
                Advice(name: "谷口", text: "よっしゃ。始発で帰ろか"),
            ],
            "B": [
                Advice(name: "俺", text: "今日は帰ろう。明日に響く"),
                Advice(name: "谷口", text: "せやな。よう寝たら、次の稽古もはかどるやろ"),
            ],
        ]
    )

    // MARK: 0023 正社員の話（週次・金欠帯・選択肢あり。proposals/0023 レッドチーム済み確定テキストを転記）
    //   第三者「店長」＝標準語。段階2（growthBudget減算＝天井）は規律Aで後日・本文は段階1に対応。

    private static let regularEmployment = ChoiceEventText(
        title: "正社員の話",
        setup: [
            Advice(name: nil, text: "バイト先の休憩室。昼休み。"),
            Advice(name: "店長", text: "正社員にならないか。給料も上がるし、生活も落ち着くよ"),
            Advice(name: "俺", text: "ありがたいです。でも、稽古に行ける日が減りますよね"),
            Advice(name: "谷口", text: "お前の暮らしやし、お前が決めたらええで"),
        ],
        choiceLabels: [
            "A": "店長の話を受けて正社員になる",
            "B": "断って、今のままバイトを続ける",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "受けます。生活を立て直したいです"),
                Advice(name: "店長", text: "助かるよ。来月から、よろしく頼むね"),
                Advice(name: "谷口", text: "そうか。稽古は、お前の休みの日にしよ"),
            ],
            "B": [
                Advice(name: "俺", text: "すみません。今のままで続けさせてください"),
                Advice(name: "店長", text: "そうか。じゃあ、これからもよろしくね"),
                Advice(name: "谷口", text: "よう決めたな。これからも一緒にやろ"),
            ],
        ]
    )

    // MARK: 0014 終電までの反省会（週次・前座帯・選択肢あり。proposals/0014 レッドチーム済み確定テキストを転記）
    //   A の「センスまたは発想+2＝プレイヤーが1軸選ぶ」は MVP では weakerSenseIdeaPlus（低い方に決定的加算）に簡略。

    private static let lastTrainReview = ChoiceEventText(
        title: "ライブ帰りの駅",
        setup: [
            Advice(name: nil, text: "駅のホーム。ライブ帰りの夜。"),
            Advice(name: "谷口", text: "今日のお客さん、八人やったな"),
            Advice(name: "俺", text: "ああ。……さすがに疲れたな"),
            Advice(name: "谷口", text: "終電まで、まだちょっとあるで。どないする"),
        ],
        choiceLabels: [
            "A": "考えごとしながら一人で歩いて帰る",
            "B": "駅前で牛丼を食べてから帰る",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "俺は歩いて帰る。少し一人で考えたい"),
                Advice(name: "谷口", text: "そうか。あんまり考えすぎたらあかんで"),
            ],
            "B": [
                Advice(name: "俺", text: "牛丼食べて帰ろう。温かいものが食べたい"),
                Advice(name: "谷口", text: "ええな。食べたら、ちょっとは元気出るやろ"),
            ],
        ]
    )

    // MARK: 0029 三行目を一度で（週次・好調帯フレーバー。proposals/0029 レッドチーム済み確定テキストを転記）

    private static let luckyThirdLine = ChoiceEventText(
        title: "調子のいい週",
        setup: [
            Advice(name: nil, text: "稽古場。昼すぎ。"),
            Advice(name: "谷口", text: "最近、朝起きるのが楽やねん"),
            Advice(name: "俺", text: "顔色もいいな。よく寝てるのか"),
            Advice(name: "谷口", text: "毎晩、早めに寝とるねん。お前も早よ寝えや"),
            Advice(name: "俺", text: "そうする。この調子、続けたいな"),
        ],
        choiceLabels: [:],
        afterChoice: [:]
    )

    // MARK: 0027 楽屋で無言の十分（週次・噛み合い帯フレーバー。proposals/0027 レッドチーム済み確定テキストを転記）

    private static let greenroomSilentTen = ChoiceEventText(
        title: "ライブのあと",
        setup: [
            Advice(name: nil, text: "劇場の楽屋。ライブが終わった後。"),
            Advice(name: "谷口", text: "……今日は、あかんかったな"),
            Advice(name: "俺", text: "ああ。今は何も考えたくない"),
            Advice(name: "谷口", text: "ちょっと座ってから帰ろか。缶コーヒー買うてくるわ"),
            Advice(name: "俺", text: "ありがとう。少し休んでから帰ろう"),
        ],
        choiceLabels: [:],
        afterChoice: [:]
    )
}
