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
enum EventScene { case keiko, dusk, gakuya, yakiniku, station, famires, office }

enum ChoiceEventData {
    /// 場面の既定値。夜の出来事（前夜・飲み会・書けた夜・終電・負けた日）は夕景、他は昼の稽古場【仮】
    static func scene(for kind: ChoiceEventKind) -> EventScene {
        switch kind {
        // ト書きの場所が絵に出る（表示だけ）: 楽屋・焼肉屋・駅のホーム・ファミレス・事務所
        case .lineupTop, .greenroomSilentTen: return .gakuya
        case .senpaiMeishi: return .yakiniku
        case .lastTrainReview: return .station
        case .wroteOneTonight: return .famires
        case .photoShootOffer: return .office
        case .preTournamentEve, .brokeDrinkingInvite, .justLostRehearsal, .weekendInvite:
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
        case .weekendInvite: return weekendInvite
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
        case .riftWarning: return riftWarning
        case .kouhaiInvite: return kouhaiInvite
        case .senpaiAllNight: return senpaiAllNight
        case .stageCrewChairs: return stageCrewChairs
        case .writerPostcards: return writerPostcards
        case .doukiJointLive: return doukiJointLive
        case .baitoInventory: return baitoInventory
        case .homecomingCall: return homecomingCall
        case .regularFanOranges: return regularFanOranges
        case .officeTicketQuota: return officeTicketQuota
        case .summerFestivalGig: return summerFestivalGig
        case .doukiOnTV: return doukiOnTV
        case .theaterRenovation: return theaterRenovation
        case .classmateInAudience: return classmateInAudience
        case .partnerFever: return partnerFever
        case .lostNotebook: return lostNotebook
        case .yearEndLive: return yearEndLive
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

    // MARK: §102 先輩の誘い（週末に不定期に来る軽い気分転換。ボケない・短く）
    private static let weekendInvite = ChoiceEventText(
        title: "先輩から誘い",
        setup: [
            Advice(name: nil, text: "劇場の裏口。先輩が声をかけてきた。"),
            Advice(name: "先輩", text: "今夜、軽く飲みに行かへんか。割り勘でええよ"),
            Advice(name: "谷口", text: "俺は行ってもええと思てる。お前はどうする"),
        ],
        choiceLabels: [
            "A": "行く（5,000円）",
            "B": "断る",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "行きます。たまには気分転換も必要です"),
                Advice(name: "谷口", text: "ほな行こか。ええ夜になるとええな"),
            ],
            "B": [
                Advice(name: "俺", text: "今夜はやめておきます。また誘ってください"),
                Advice(name: "先輩", text: "おう、またな"),
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

    // MARK: - 相方以外の人とのイベント（docs/choice_events_others_v1.md・2026-10-15 オーナー指示）
    //   第三者は標準語・谷口は関西弁。正典v3（ボケない・日常会話）＋研究 research_event_fun_v0 §4 案A（固有物1つ＋人柄1つ・選択後は反応で返す）。

    // MARK: 0050 会わない週が続いた（途中解散の予告・docs/endings_spec_v1.md §4 逐語。採番は 0041 が使用済みのため 0050）

    private static let riftWarning = ChoiceEventText(
        title: "会わない週が続いた",
        setup: [
            Advice(name: nil, text: "夜。アパートの前。"),
            Advice(name: "谷口", text: "近く通ったから寄ってん。最近、全然会うてへんな"),
            Advice(name: "俺", text: "そうだな。バイトが続いてた"),
            Advice(name: "谷口", text: "俺もや。……なあ、俺らこのままでええんかな"),
        ],
        choiceLabels: [
            "A": "部屋に上がってもらい、夜通し話す",
            "B": "今夜は遅いので、また今度にする",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "上がってくれ。ちゃんと話そう"),
                Advice(name: "谷口", text: "うん。言いたいこと、たまってたんや"),
            ],
            "B": [
                Advice(name: "俺", text: "今日はもう遅い。また今度な"),
                Advice(name: "谷口", text: "……そうか。ほな、来週の水曜は空けといてな"),
            ],
        ]
    )

    // MARK: 0041 後輩の誘い

    private static let kouhaiInvite = ChoiceEventText(
        title: "後輩の誘い",
        setup: [
            Advice(name: nil, text: "劇場の楽屋。ライブ終わりの夕方。"),
            Advice(name: "浅見", text: "お疲れさまです。今日、初めてこの劇場に出られました"),
            Advice(name: "俺", text: "おめでとう。ずっと出たがってたもんな"),
            Advice(name: "浅見", text: "それで、駅前の『とり政』で一杯どうですか。うちの相方も来ます"),
            Advice(name: "谷口", text: "行ったら俺らのおごりやな。俺も一年目、先輩に唐揚げおごってもろたわ"),
        ],
        choiceLabels: [
            "A": "浅見たちに、とり政でおごる",
            "B": "今日は断って、まっすぐ帰る",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "行こう。今日は俺たちが出す"),
                Advice(name: "浅見", text: "ありがとうございます。相方、呼んできます"),
                Advice(name: "谷口", text: "やっと、先輩らしいことできるな"),
            ],
            "B": [
                Advice(name: "俺", text: "ごめん、今日は帰る。また今度な"),
                Advice(name: "浅見", text: "分かりました。次の出番の後に、また声かけます"),
                Advice(name: "谷口", text: "帰ってよう寝よ。……ちょっと悪いことしたな"),
            ],
        ]
    )

    // MARK: 0042 先輩の誘い

    private static let senpaiAllNight = ChoiceEventText(
        title: "先輩の誘い",
        setup: [
            Advice(name: nil, text: "劇場のロビー。最後の出番が終わった夜。"),
            Advice(name: "堀口", text: "お前ら、このあと空いてるか。朝までやってるもつ鍋屋に行くぞ"),
            Advice(name: "俺", text: "堀口さん、明日も早いんじゃないですか"),
            Advice(name: "堀口", text: "明日は昼からだから平気だ。売れなかった頃の話、聞かせてやる"),
            Advice(name: "谷口", text: "堀口さんの昔の話、ためになるで。けど、朝までは体きついな"),
        ],
        choiceLabels: [
            "A": "朝まで堀口さんについて行く",
            "B": "今日は遠慮して帰る",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "ご一緒します。朝まで付き合います"),
                Advice(name: "堀口", text: "よし。じゃあ、俺が一年目の頃の話からな"),
                Advice(name: "谷口", text: "話、忘れんうちにメモしとこ"),
            ],
            "B": [
                Advice(name: "俺", text: "すみません、今日は帰ります"),
                Advice(name: "堀口", text: "おう。また誘うからな"),
            ],
        ]
    )

    // MARK: 0043 片付けの手伝い

    private static let stageCrewChairs = ChoiceEventText(
        title: "片付けの手伝い",
        setup: [
            Advice(name: nil, text: "劇場の客席。ライブが終わった後。"),
            Advice(name: "柏木", text: "ごめん、片付けの人が一人休みでさ。椅子を並べ直すの、手伝ってくれる？"),
            Advice(name: "俺", text: "全部ですか。二百席ありますよね"),
            Advice(name: "柏木", text: "二人いれば三十分で終わるよ。支配人にも、名前を伝えておくから"),
            Advice(name: "谷口", text: "俺、前のバイトで椅子並べてたから、慣れてんねん"),
        ],
        choiceLabels: [
            "A": "二人で客席の椅子を並べ直す",
            "B": "お礼を言って、先に帰る",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "やります。端の列から並べます"),
                Advice(name: "柏木", text: "助かった。二人の名前、ちゃんと覚えたよ"),
                Advice(name: "谷口", text: "ほんまに三十分で終わったな。けっこう疲れたわ"),
            ],
            "B": [
                Advice(name: "俺", text: "すみません、今日は先に帰ります"),
                Advice(name: "柏木", text: "いいよいいよ。お疲れさま"),
                Advice(name: "谷口", text: "ほな、駅まで一緒に帰ろか"),
            ],
        ]
    )

    // MARK: 0044 ハガキの仕分け

    private static let writerPostcards = ChoiceEventText(
        title: "ハガキの仕分け",
        setup: [
            Advice(name: nil, text: "喫茶店。作家の戸田さんに呼ばれた昼。"),
            Advice(name: "戸田", text: "深夜ラジオに届くハガキの仕分け、手伝ってくれないかな。週に一回、夜中なんだ"),
            Advice(name: "俺", text: "夜中ですか。お金は出ますか"),
            Advice(name: "戸田", text: "少しだけど出すよ。夜食も付くから、気軽においで"),
            Advice(name: "谷口", text: "俺、夜はすぐ眠なるねん。お前が決めてええで"),
        ],
        choiceLabels: [
            "A": "ハガキの仕分けを引き受ける",
            "B": "夜は練習に使いたいと断る",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "やります。来週からお願いします"),
                Advice(name: "戸田", text: "助かるよ。思ってるより、ハガキは多いからね"),
                Advice(name: "谷口", text: "変わったハガキあったら、俺にも教えてな"),
            ],
            "B": [
                Advice(name: "俺", text: "すみません。夜は二人で練習したいんです"),
                Advice(name: "戸田", text: "分かった。夜の練習、がんばってね"),
                Advice(name: "谷口", text: "ほな、夜は毎日うちに集合な"),
            ],
        ]
    )

    // MARK: 0045 同期からの誘い

    private static let doukiJointLive = ChoiceEventText(
        title: "同期からの誘い",
        setup: [
            Advice(name: nil, text: "公園のベンチ。同期の真鍋と会った昼。"),
            Advice(name: "真鍋", text: "今度、二組で小さい会場を借りて、ライブをやらないか"),
            Advice(name: "俺", text: "会場代は、いくらかかるんだ"),
            Advice(name: "真鍋", text: "二組で割って、一組一万円だ。お客さんを三十人呼べたら赤字にはならない"),
            Advice(name: "谷口", text: "真鍋とやるんか。あいつらには、負けたないな"),
        ],
        choiceLabels: [
            "A": "真鍋たちと二組でライブをやる",
            "B": "お金が厳しいので、今回は断る",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "やろう。チラシは俺が作る"),
                Advice(name: "真鍋", text: "決まりだな。三十人、両方で呼ぼう"),
                Advice(name: "谷口", text: "知り合い、全員に声かけるわ"),
            ],
            "B": [
                Advice(name: "俺", text: "悪い、今回はやめておく。お金が厳しいんだ"),
                Advice(name: "真鍋", text: "そうか。会場は、他の組を誘ってみる"),
                Advice(name: "谷口", text: "次に誘われた時のために、二人で貯めとこな"),
            ],
        ]
    )

    // MARK: 0046 棚卸しの夜

    private static let baitoInventory = ChoiceEventText(
        title: "棚卸しの夜",
        setup: [
            Advice(name: nil, text: "バイト先のファミレス。閉店後の夜。"),
            Advice(name: "矢島", text: "来週の木曜、夜通しで棚卸しがあるんだ。入れないかな"),
            Advice(name: "俺", text: "夜通しですか。次の日は昼から稽古なんです"),
            Advice(name: "矢島", text: "深夜の手当がつくから、いつもの倍近く出るよ。無理なら他を当たる"),
        ],
        choiceLabels: [
            "A": "夜通しの棚卸しに入る",
            "B": "次の日の稽古のために断る",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "入ります。今月、ちょうど厳しかったので"),
                Advice(name: "矢島", text: "助かるよ。夜食は出すからね"),
            ],
            "B": [
                Advice(name: "俺", text: "すみません。次の日の稽古に、ちゃんと出たいんです"),
                Advice(name: "矢島", text: "分かった。体は大事にしてね"),
            ],
        ]
    )

    // MARK: 0047 母からの電話

    private static let homecomingCall = ChoiceEventText(
        title: "母からの電話",
        setup: [
            Advice(name: nil, text: "アパートの部屋。年末の夕方。"),
            Advice(name: "母", text: "お正月は帰ってくるの？ お父さん、毎日カレンダーを見てるよ"),
            Advice(name: "俺", text: "まだ分からない。稽古もあるし"),
            Advice(name: "母", text: "切符、今のうちに取れば安いって。顔だけでも見せなさい"),
            Advice(name: "谷口", text: "帰ったらええやん。俺も大阪、帰ろかな"),
        ],
        choiceLabels: [
            "A": "正月は実家に帰る",
            "B": "帰らずに、こっちで稽古する",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "帰るよ。切符、明日取る"),
                Advice(name: "母", text: "よかった。お父さんにも言っておくね"),
                Advice(name: "谷口", text: "三日くらい、ゆっくりしてきいや"),
            ],
            "B": [
                Advice(name: "俺", text: "ごめん、今年は帰らない。春には一回帰るから"),
                Advice(name: "母", text: "そう。体だけは気をつけてね"),
                Advice(name: "谷口", text: "ほな、正月も稽古やな。おかんには、ちゃんと電話しときや"),
            ],
        ]
    )

    // MARK: 0048 いつものお客さん

    private static let regularFanOranges = ChoiceEventText(
        title: "いつものお客さん",
        setup: [
            Advice(name: nil, text: "劇場の出口。昼の部が終わった後。"),
            Advice(name: "佐伯", text: "今日もよかったよ。このみかん、二人で食べて"),
            Advice(name: "俺", text: "佐伯さん、いつもありがとうございます"),
            Advice(name: "佐伯", text: "今度、友だちも連れてくるからね"),
            Advice(name: "谷口", text: "出口に残って、お客さんに挨拶してこか。バイト、遅れるかもしれんけど"),
        ],
        choiceLabels: [
            "A": "出口に残ってお客さんに挨拶する",
            "B": "バイトに間に合うよう急いで出る",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "残ろう。一人ずつお礼を言おう"),
                Advice(name: "佐伯", text: "次は友だちに、二人の名前を教えておくね"),
                Advice(name: "谷口", text: "バイト先には、遅れるって電話しとくわ"),
            ],
            "B": [
                Advice(name: "俺", text: "すみません、今日はバイトなので急ぎます"),
                Advice(name: "佐伯", text: "いいのよ。また来るからね"),
            ],
        ]
    )

    // MARK: 0049 ライブのチケット

    private static let officeTicketQuota = ChoiceEventText(
        title: "ライブのチケット",
        setup: [
            Advice(name: nil, text: "事務所。来月のライブの話をされた昼。"),
            Advice(name: "中条", text: "来月の事務所ライブ、一組十枚ずつチケットを売ってほしいの"),
            Advice(name: "俺", text: "十枚ですか。売れなかった分は、どうなりますか"),
            Advice(name: "中条", text: "残った分は、出る人で買い取りなの。ごめんね"),
            Advice(name: "谷口", text: "駅前で手売りしたら、なんとかなるやろ"),
        ],
        choiceLabels: [
            "A": "週末、駅前でチケットを手売りする",
            "B": "手売りはせず、残りを買い取る",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "週末、駅前に立とう。二人で声をかけよう"),
                Advice(name: "谷口", text: "寒いけど、がんばろな。知らん人に声かけるの、初めてやわ"),
            ],
            "B": [
                Advice(name: "俺", text: "今回は買い取ろう。立つ時間を稽古に回したい"),
                Advice(name: "中条", text: "分かった。じゃあ十枚、先に渡しておくね"),
                Advice(name: "谷口", text: "空いた週末は、二人で稽古やな"),
            ],
        ]
    )

    // ===== 芸人の暮らしのイベント 第2束（docs/choice_events_more_v1.md・2026-10-16）=====
    // 正典v3（キャラ会話はボケない・日常会話）。新しい人物は架空（石黒・宮内・小野寺・駅員・野々村）。第三者は標準語。

    // MARK: 0051 夏祭りの営業

    private static let summerFestivalGig = ChoiceEventText(
        title: "夏祭りの営業",
        setup: [
            Advice(name: nil, text: "稽古場。事務所の中条さんから電話が来た昼。"),
            Advice(name: "中条", text: "来月、ショッピングモールの夏祭りで、外のステージに出てほしいの"),
            Advice(name: "俺", text: "外ですか。昼の一番暑い時間ですよね"),
            Advice(name: "中条", text: "二時から三回。一組一万二千円で、お弁当も出るよ"),
            Advice(name: "谷口", text: "日なたで三回はきついな。けど、ちゃんとお金になるで"),
        ],
        choiceLabels: [
            "A": "夏祭りのステージに出る",
            "B": "断って、その日は家で休む",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "出ます。三回とも二人で行きます"),
                Advice(name: "中条", text: "ありがとう。帽子とタオルは、自分で持ってきてね"),
                Advice(name: "谷口", text: "帰りに冷たいもん食べよな。日焼け止めも買わな"),
            ],
            "B": [
                Advice(name: "俺", text: "すみません。今月は体を休めたいんです"),
                Advice(name: "中条", text: "分かった。秋のお祭りの時に、また声をかけるね"),
                Advice(name: "谷口", text: "その日は家で、冷房つけて寝とくわ"),
            ],
        ]
    )

    // MARK: 0052 同期がテレビに出た夜

    private static let doukiOnTV = ChoiceEventText(
        title: "同期のテレビ",
        setup: [
            Advice(name: nil, text: "アパートの部屋。テレビをつけた夜。"),
            Advice(name: "谷口", text: "あ、石黒らや。夜の番組に出とる"),
            Advice(name: "俺", text: "本当だ。同期で最初のテレビだな"),
            Advice(name: "谷口", text: "昼にメール来とってん。見てくれって"),
            Advice(name: "俺", text: "そうか。ちゃんと映ってるな"),
            Advice(name: "谷口", text: "……あいつら、先に行ってもうたな"),
        ],
        choiceLabels: [
            "A": "番組を最後まで二人で見る",
            "B": "テレビを消して、銭湯に行く",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "最後まで見よう。終わったら石黒に連絡する"),
                Advice(name: "谷口", text: "うん。あいつ、ずっと緊張した顔しとるな"),
            ],
            "B": [
                Advice(name: "俺", text: "消そう。銭湯に行って、今日はもう寝よう"),
                Advice(name: "谷口", text: "せやな。石黒には、明日おめでとう言うわ"),
            ],
        ]
    )

    // MARK: 0053 いつもの劇場の改装

    private static let theaterRenovation = ChoiceEventText(
        title: "劇場の改装",
        setup: [
            Advice(name: nil, text: "劇場のロビー。張り紙が出た昼。"),
            Advice(name: "宮内", text: "来月から二か月、改装で劇場を閉めるの。椅子と空調を新しくするんだって"),
            Advice(name: "俺", text: "二か月もですか。その間の出番は、どうなりますか"),
            Advice(name: "宮内", text: "隣町の劇場なら、出られる日を紹介できるよ。電車で四十分かかるけど"),
            Advice(name: "谷口", text: "電車代は毎週かかるな。けど、向こうのお客さんに見てもらえるで"),
        ],
        choiceLabels: [
            "A": "隣町の劇場に通って出る",
            "B": "閉まっている間は公園で練習する",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "紹介してください。隣町に通います"),
                Advice(name: "宮内", text: "伝えておくね。向こうは客席が広いよ"),
                Advice(name: "谷口", text: "定期券、買うたほうが安いかもしれんな"),
            ],
            "B": [
                Advice(name: "俺", text: "二か月は、二人の練習にあてます"),
                Advice(name: "宮内", text: "分かった。新しい椅子、楽しみにしててね"),
                Advice(name: "谷口", text: "公園やったら、お金もかからんしな"),
            ],
        ]
    )

    // MARK: 0054 同級生が客席に

    private static let classmateInAudience = ChoiceEventText(
        title: "高校の同級生",
        setup: [
            Advice(name: nil, text: "劇場の出口。夜の部が終わった後。"),
            Advice(name: "小野寺", text: "久しぶり。高校で同じクラスだった小野寺だよ"),
            Advice(name: "俺", text: "小野寺か。来てくれたのか"),
            Advice(name: "小野寺", text: "会社の同期と五人で来た。このあと飲みに行くから、一緒に来いよ"),
            Advice(name: "谷口", text: "俺はどっちでもええで。行くんやったら、明日の稽古に遅れんといてな"),
        ],
        choiceLabels: [
            "A": "小野寺たちの飲み会に行く",
            "B": "今日は断って、谷口と帰る",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "行くよ。少しだけな"),
                Advice(name: "小野寺", text: "よし。会社の人に、次のライブのことを話しておくよ"),
                Advice(name: "谷口", text: "また明日な。飲みすぎんといてや"),
            ],
            "B": [
                Advice(name: "俺", text: "ごめん、今日は帰る。また見に来てくれ"),
                Advice(name: "小野寺", text: "分かった。今度、ご飯にゆっくり行こう"),
                Advice(name: "谷口", text: "ええんか。帰りにコンビニ寄ってこ"),
            ],
        ]
    )

    // MARK: 0055 相方の熱

    private static let partnerFever = ChoiceEventText(
        title: "相方の熱",
        setup: [
            Advice(name: nil, text: "稽古場。谷口から電話が来た朝。"),
            Advice(name: "谷口", text: "ごめん、熱が出てしもた。三十八度ある"),
            Advice(name: "俺", text: "大丈夫か。病院は行ったのか"),
            Advice(name: "谷口", text: "昼から行く。今日の稽古、休ませてな"),
            Advice(name: "俺", text: "分かった。何か要るものはあるか"),
            Advice(name: "谷口", text: "寝とったら治る。お前は気にせんと、練習しとって"),
        ],
        choiceLabels: [
            "A": "飲み物と果物を買って、谷口の家に行く",
            "B": "一人で稽古場に残って練習する",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "今から行く。スポーツドリンクとりんご、買っていく"),
                Advice(name: "谷口", text: "来てくれたんか。部屋、散らかっとるけど上がって"),
            ],
            "B": [
                Advice(name: "俺", text: "分かった。今日は一人でやっておく"),
                Advice(name: "谷口", text: "うん。治ったら、すぐ追いつくわ"),
            ],
        ]
    )

    // MARK: 0056 なくしたノート

    private static let lostNotebook = ChoiceEventText(
        title: "なくしたノート",
        setup: [
            Advice(name: nil, text: "駅の忘れ物の窓口。朝。"),
            Advice(name: "谷口", text: "二人のノート、ゆうべの電車の網棚に置いてきてしもてん"),
            Advice(name: "俺", text: "組んだ日から書いてるノートだよな"),
            Advice(name: "駅員", text: "終点の駅に届いているそうです。取りに行くなら、今日中にお願いします"),
            Advice(name: "谷口", text: "終点まで一時間かかるんや。ほんまにごめん"),
        ],
        choiceLabels: [
            "A": "終点の駅までノートを取りに行く",
            "B": "あきらめて、新しいノートを買う",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "取りに行こう。今日の稽古は夕方からにする"),
                Advice(name: "谷口", text: "ありがとう。電車代は俺が出すわ"),
            ],
            "B": [
                Advice(name: "俺", text: "もういい。新しいノートを買って、一から書こう"),
                Advice(name: "谷口", text: "うん。今度のは、表に二人の名前を書いとくわ"),
            ],
        ]
    )

    // MARK: 0057 年末のライブ

    private static let yearEndLive = ChoiceEventText(
        title: "年末のライブ",
        setup: [
            Advice(name: nil, text: "劇場の楽屋。年末のライブが終わった夜。"),
            Advice(name: "野々村", text: "このあと、事務所の打ち上げがある。会費は一人五千円だ"),
            Advice(name: "俺", text: "野々村さん、事務所の人は全員来るんですか"),
            Advice(name: "野々村", text: "社長も来る。来年の話も、そこで出るかもしれないな"),
            Advice(name: "谷口", text: "今年の年越しそば、まだやったな。駅前の店、まだ開いとるで"),
        ],
        choiceLabels: [
            "A": "打ち上げに最後まで残る",
            "B": "二人で駅前のそば屋に行く",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "行きます。最後までいます"),
                Advice(name: "野々村", text: "よし。社長には、俺から二人の名前を伝えておく"),
                Advice(name: "谷口", text: "そばは、来年の楽しみにとっとくわ"),
            ],
            "B": [
                Advice(name: "俺", text: "すみません、今年は二人で帰ります"),
                Advice(name: "野々村", text: "そうか。よいお年を"),
                Advice(name: "谷口", text: "店、まだ開いててよかったな。熱いうちに食べよ"),
            ],
        ]
    )
}
