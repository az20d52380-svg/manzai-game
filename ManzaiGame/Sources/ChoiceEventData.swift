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

enum ChoiceEventData {
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

    // MARK: 0021 慣れの外し方

    private static let tsuukaBreak = ChoiceEventText(
        title: "慣れの外し方",
        setup: [
            Advice(name: nil, text: "稽古場のホワイトボードに、三本目の段取りが消されずに残っている。\nいつからか、二人にしか読めない略字になった。「A→タ→落」。\n書いた俺と、読める谷口。それで足りている。\n今日も、目配せだけで一本通した。オチの場所を、客より先に二人が知っている。"),
            Advice(name: "谷口", text: "最近、俺ら目ぇ合わすだけで一本終わるな"),
            Advice(name: "俺", text: "終わる。"),
            Advice(name: "谷口", text: "気持ちええけど、こわいやつやな、それ"),
        ],
        choiceLabels: [
            "A": "あえて崩す実験に出る",
            "B": "完成した呼吸を固める",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "一回、崩す。二人にだけ通じる呼吸は、劇場の後ろまで届かない。"),
                Advice(name: "谷口", text: "……やろな。お前がそのボード消すの、そろそろやと思とった"),
            ],
            "B": [
                Advice(name: "俺", text: "今は固める。崩すのは、固まってからでいい。"),
                Advice(name: "谷口", text: "ええよ。……この略字、もうちょい二人で使い倒そか"),
            ],
        ]
    )

    // MARK: 0020 まだ敬語の残る間

    private static let earlyFormality = ChoiceEventText(
        title: "まだ敬語の残る間",
        setup: [
            Advice(name: nil, text: "コンビを組んで、まだ月が浅い。稽古場のパイプ椅子は、二脚とも壁際に畳んだままだ。\n谷口はネタ帳を、いつも両手で返してくる。俺が片手で受け取ると、\n受け渡しのあいだに、拳ひとつ分の隙間が空く。\n稽古の帰りぎわ、俺のツッコミについて谷口が何か言いかけて、やめた。\n俺の方も、一個、言いかけて、飲み込んでいる。"),
        ],
        choiceLabels: [
            "A": "踏み込んで言う",
            "B": "間合いを保つ",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "一個、言っていいか。お前のボケ、俺はまだ半分しか信じてない。"),
                Advice(name: "谷口", text: "……はっきり言うやん。ええよ、残りの半分、稽古で埋めさしたるわ。"),
                Advice(name: "俺", text: "今、初めて片手でネタ帳を寄越したな。"),
            ],
            "B": [
                Advice(name: "俺", text: "……いや、なんでもない。今日はここまでにしよう。"),
                Advice(name: "谷口", text: "せやな。ほな、また明日。"),
                Advice(name: "俺", text: "ネタ帳は、今日は俺が仕舞っておく。"),
            ],
        ]
    )

    // MARK: 0011 行けない飲み会（週次抽選・低所持金帯。proposals/0011 レッドチーム済み確定テキストを転記）

    private static let brokeDrinkingInvite = ChoiceEventText(
        title: "行けない飲み会",
        setup: [
            Advice(name: nil, text: "谷口の携帯が、鳴って、切れて、また鳴った。\n稽古場の照明は、壁の箱に百円玉を入れると一時間だけつく。今夜の残りは、その百円玉で数えられる程度だ。"),
            Advice(name: "谷口", text: "今日、同期が集まるらしいわ。会費、ひとり四千円やて"),
            Advice(name: "俺", text: "今月の稽古場代、残りがちょうど四千円なんだよな"),
        ],
        choiceLabels: [
            "A": "行く",
            "B": "断って稽古場に残る",
        ],
        afterChoice: [
            "A": [
                Advice(name: "谷口", text: "久しぶりに、みんなの顔見たわ"),
                Advice(name: "俺", text: "その分、来週は箱に入れる百円玉を、一枚ずつ数えることになる"),
            ],
            "B": [
                Advice(name: "谷口", text: "……なら、俺も残るわ"),
                Advice(name: "俺", text: "払わずに済んだ会費が、二人で八千円。箱の照明なら、八十時間ぶんだ"),
            ],
        ]
    )

    // MARK: 0013 先輩の名刺（週次抽選・奢られる帯。proposals/0013 レッドチーム済み確定テキストを転記）
    //   第三者「先輩」は関西弁の漫才の先輩＝proposal 確定テキストに準拠（谷口以外の相方は標準語だが本第三者は例外）。

    private static let senpaiMeishi = ChoiceEventText(
        title: "先輩の名刺",
        setup: [
            Advice(name: nil, text: "先輩が肉を焼き終えるより先に、伝票を裏返した。番組の名前が入った名刺を一枚、焼き網の縁に置く。角が、熱で少しずつ反っていく。"),
            Advice(name: "先輩", text: "ここは俺が持つ。……で、一個、顔繋いどこか？"),
            Advice(name: "俺", text: "ありがとうございます。……その話、少し考えさせてください。"),
            Advice(name: "谷口", text: "先輩、こいつ、肉より先に伝票見る男なんですわ。"),
        ],
        choiceLabels: [
            "A": "紹介を受ける",
            "B": "飯だけ頂き、紹介は辞退する",
        ],
        afterChoice: [
            "A": [
                Advice(name: "先輩", text: "ええ度胸や。番号、今日中に鳴らせ。"),
                Advice(name: "俺", text: "はい。……この名刺、反ってますね。伸ばして持っときます。"),
                Advice(name: "谷口", text: "反ったやつ伸ばして使うの、こいつの得意技なんですわ。"),
            ],
            "B": [
                Advice(name: "先輩", text: "そうか。……まあ、飯は残さず食え。"),
                Advice(name: "俺", text: "はい。いただきます。……この一本は、また今度で。"),
                Advice(name: "谷口", text: "すんません、うちのが。……先輩、この反った名刺、もらといてええですか。"),
            ],
        ]
    )

    // MARK: 0015 畳んだコンビの椅子（週次抽選・芸歴帯。proposals/0015 レッドチーム済み確定テキストを転記）
    //   相性帯差し替え（0-7/8-14/15-20）は本編で足す枠＝MVPは基本プール（谷口）。

    private static let peerFoldedChair = ChoiceEventText(
        title: "畳んだコンビの椅子",
        setup: [
            Advice(name: nil, text: "同期のコンビが、今日で畳む。片方が辞める。もう一方は、一人でどうするかまだ決めていないらしい。\n谷口が倉庫から折り畳みのパイプ椅子を一脚提げてきた。あいつがいつも座っていた椅子だ。座面は片側だけ沈んでいて、座り方の癖がそのまま型になって残っている。背もたれには、コンビ名を書いたガムテを剥がした跡が、粘って光っている。\n枠はひとつ。座れるのは、ひとりずつだ。当たり前のことを、わざわざ確かめた。"),
            Advice(name: "谷口", text: "あいつら、今日で解散やって。倉庫のこれ、俺らにくれるって"),
            Advice(name: "俺", text: "あいつの出番枠、来月から空くらしい"),
        ],
        choiceLabels: [
            "A": "空き枠を引き継ぐ",
            "B": "枠は取らず、送り出しだけする",
        ],
        afterChoice: [
            "A": [
                Advice(name: "俺", text: "枠は、取る。場数がいる"),
                Advice(name: "谷口", text: "取ろか。……座り心地は、あんま良ないやろけどな"),
            ],
            "B": [
                Advice(name: "俺", text: "枠はいい。今取る枠じゃない"),
                Advice(name: "谷口", text: "ほな、見送りだけ行こか。あいつ、俺らが来たら椅子の話しかせえへんやろけど"),
            ],
        ]
    )

    // MARK: 0028 名前の無い予約票（確定発火・選択肢なしフレーバー。proposals/0028 レッドチーム済み確定テキストを転記）
    //   俺（標準語・地の文）／谷口（関西弁）の2話者。効果なし＝会話（セットアップ→締め）を送り切って閉じる。

    private static let namelessReservationSlip = ChoiceEventText(
        title: "名前の無い予約票",
        setup: [
            Advice(name: nil, text: "来週の稽古場を押さえに、受付の予約票をめくった。\nうちの枠は、決まって二段で書く。上に俺、下に谷口。二人で一枠。\n前の週の欄に、平日の朝いちが埋まっていた。上の段に、谷口の名前だけ。下の段は空いている。時刻の「9」の、丸の閉じ方が甘い。あいつの字だ。"),
            Advice(name: "谷口", text: "あー、それな。あの日、たまたま場所空いとったから、ちょっと横になってただけや"),
            Advice(name: "俺", text: "そうか。来週は、いつもの土曜で押さえとく。"),
            Advice(name: nil, text: "予約票を閉じた。\n朝いちの枠は、半額になる時間だ。横になるだけなら、もっと安い場所がいくらでもある。\n来週の土曜の欄に、二人分の名前を、上から順に書いた。"),
        ],
        choiceLabels: [:],
        afterChoice: [:]
    )
}
