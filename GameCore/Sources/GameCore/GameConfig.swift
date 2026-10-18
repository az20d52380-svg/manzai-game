// GameConfig.swift
// バランス数値の集約点（CLAUDE.mdルール3）。全て【仮】。
// tools/balance_sim.py の CONFIG と1対1対応させ、数式を変えたら必ず両方を更新する（ルール5）。
// 対応表は docs/gamecore_design.md を参照。

/// 能力5種（Python: sense / idea / expr / chara / mental）
/// Codable は中断セーブ（WeekRunnerSnapshot/proposals-0039）用＝挙動・golden不変
public enum Ability: CaseIterable, Hashable, Codable {
    case センス
    case 発想
    case 表現
    case 華
    case メンタル
}

/// 経験点通貨5種（正典v3・パワプロ式・能力名と別立て＝真の多対多。docs/exp_currency_redesign_v0.md）。
/// Python: balance_sim.CURRENCIES（hirameki/goi/maai/sonzaikan/tanryoku と同順）。
/// Codable は中断セーブ（WeekRunnerSnapshot/proposals-0039）用＝挙動・golden不変
public enum ExpCurrency: CaseIterable, Hashable, Codable {
    case 閃き
    case 語彙
    case 間合い
    case 存在感
    case 胆力
}

/// 増減の対象となるステータスの鍵（Python: add() の key）
public enum StatKey {
    case ability(Ability)
    case currency(ExpCurrency)   // 稽古発行の経験点通貨（正典v3）。add() は通さない＝GameEngine.applyGrowth が分岐
    case コンビ相性
    case 体力
    case 知名度
}

public enum Training: CaseIterable, Hashable, Codable {
    case ネタ作り
    case ネタ見せ会
    case ネタ合わせ
    case ランニング・サウナ
    case フリーライブ
    // 練習の場所（お金を払う良い場所・money_items_neta_v1 §1・オーナー確定 2026-10-13）。家で書く＝ネタ作り
    case 喫茶店で書く
    case ファミレスで書く
    // お店から移した「お金を払うやり方」（1週使う練習・オーナー原則「アイテムで能力は上がらない」）
    case 作家の勉強会
    case ボイトレ
}

public enum Job: CaseIterable, Hashable, Codable {
    case キツい
    case 標準
    case 楽
}

public enum Rest: CaseIterable, Hashable, Codable {
    case 完全休養
    case 気分転換
    case 相方と過ごす
    // お金を払う休み（money_items_neta_v1 §2・オーナー案 2026-10-12）
    case サウナ
    case 温泉に一泊
}

public struct TrainingSpec {
    public let main: (StatKey, Double)
    public let sub: (StatKey, Double)?
    public let cost: Int
    public let stamina: Double
    public let fame: Double

    public init(main: (StatKey, Double), sub: (StatKey, Double)?, cost: Int, stamina: Double, fame: Double) {
        self.main = main
        self.sub = sub
        self.cost = cost
        self.stamina = stamina
        self.fame = fame
    }
}

/// Codable は中断セーブ用（pendingOffer の永続化・proposals-0039）。タプルは Codable 非対応のため
/// 内部表現を2フィールドに分け、`.ability` は計算プロパティで従来と完全に同じ型を返す＝公開API不変。
public struct OfferSpec: Codable {
    public let name: String
    public let income: Int
    public let fame: Double
    private let abilityKind: Ability?
    private let abilityAmount: Double?
    public let stamina: Double

    public var ability: (Ability, Double)? {
        guard let k = abilityKind, let a = abilityAmount else { return nil }
        return (k, a)
    }

    public init(name: String, income: Int, fame: Double, ability: (Ability, Double)?, stamina: Double) {
        self.name = name
        self.income = income
        self.fame = fame
        self.abilityKind = ability?.0
        self.abilityAmount = ability?.1
        self.stamina = stamina
    }
}

public struct GameConfig {
    // --- 基本（Python: WEEKS ほか） ---
    public var weeks = 48
    /// 1キャリアの年数（本編は結成10年で完結・master_spec_v2 §1。Python: sim_career.YEARS と同期）。
    /// 年の進め方そのもの（年初の体力全回復・成長予算・GPシード）は WeekRunner(year:) が持つ＝この値は「何年目で区切るか」だけ
    public var careerYears = 10
    public var initMoney = 300_000
    public var initStamina = 100.0
    public var initFame = 3.0
    public var initAbility = 10.0
    public var compatInit = 5.0
    public var compatCap = 20.0        // 【仮】相性の成長上限
    public var compatGrows = true      // 【TBD】ネタ合わせ/相方と過ごす で+1

    /// 成長逓減【仮】: 能力上昇量 × (1 − 現在値/D)。nil で逓減なし（balance_sim.py GROWTH_DECAY_D と同期）
    public var growthDecayD: Double? = 120

    // --- 成長経済【正典v2 2026-07-05・docs/canonical_v2_spec.md】 ---
    /// 年間成長上限カーブ: その年の上限 = max(floor, base − slope×(年−1))。予算はキャリア累計（Career.runYear が設定）
    public var capCurveBase = 6.0
    public var capCurveSlope = 0.4
    public var capCurveFloor = 2.0
    /// 成長が完成する結成年数（王者の特権で解除される・sim_career.GROWTH_END_YEAR と同期）
    public var growthEndYear = 15

    // --- 経験点割り振り【正典v3・パワプロ式5通貨。docs/exp_currency_redesign_v0.md。全て【仮】】 ---
    /// 割り振り1段（+1タップ）で注ぐ「生の伸び試行量」の上限。UIの逐次見積もり・確定・sim/goldenボットが
    /// 全てこの刻みで pourStep を回す（単位を跨いだ一括評価を許さない＝貯め込みの1点評価上振れを構造で断つ）
    public var allocationStep = 1.0
    /// 能力→通貨レシピ（Leontief固定比率＝1能力=複数通貨のブレンド。1通貨=複数能力に寄与＝真の多対多）。
    /// 重みは同じ能力内で合計1.0を目安に【仮・sim較正で確定】。balance_sim.ABILITY_RECIPE と同期。
    /// オーナー指示（2026-08-02）「パワプロは経験値をパワーそのまま使わず筋力/技術等で振り分ける」への対応。
    public var abilityRecipes: [Ability: [(ExpCurrency, Double)]] = [
        // §93 R2M@0.8 配合を供給比に合わせた。旧: センス 閃.45/間.35/胆.20・発想 閃.65/語.35・表現 語.35/間.65・華 存.70/閃.30・メンタル 存.25/胆.75
        .センス:   [(.閃き, 0.35), (.間合い, 0.40), (.胆力, 0.25)],
        .発想:     [(.閃き, 0.60), (.語彙, 0.25), (.間合い, 0.15)],
        .表現:     [(.語彙, 0.20), (.間合い, 0.60), (.胆力, 0.20)],
        .華:       [(.存在感, 0.50), (.閃き, 0.20), (.間合い, 0.30)],
        .メンタル: [(.存在感, 0.20), (.胆力, 0.80)],
    ]
    /// 稽古が発行する経験点通貨の供給スケール【仮・旧expSupplyScaleの較正値を継承】。creditCurrency が
    /// 通貨加算量に掛ける。balance_sim.EXP_SUPPLY_SCALE と同期。
    public var expSupplyScale = 0.384   // §93 旧0.48（×0.8）
    /// 正典v3-1（2026-08-03オーナー指示「能力が上がるほど必要な経験点も変動する」への対応）:
    /// 現在ランクが高いほど1段あたりの通貨消費が重くなる階段状の倍率帯。パワプロ実機リサーチで確認済み
    /// （査定値表は現在ランクが上がるほど1段の必要経験点が段階的に増える・g→sで数倍）。
    /// しきい値は Theme.rank の等級ラダー（G/F/E/D/C/B/A/S）と同じ帯＝UIの等級表示と経済上の意味を一致させる。
    /// (未満のしきい値, その帯の倍率) の昇順配列＋最終帯（S）のデフォルト倍率。balance_sim.RANK_COST_BANDS/
    /// RANK_COST_MULT_S と同期。数値は全て【仮】（sim較正で確定・docs/exp_currency_redesign_v0.md §7-1）。
    public var abilityRankCostBands: [(threshold: Double, multiplier: Double)] = [
        (15, 1.00), (25, 1.15), (35, 1.35), (45, 1.60), (55, 2.00), (70, 2.50), (90, 3.20),
    ]
    public var abilityRankCostMultS = 4.20
    /// 行動直後に WeekRunner が recommendedPlan で粒を自動全量注ぎするか【正典分離】。
    /// true（既定）= sim/golden/ボットの決定論的「おすすめ台本」＝ここが golden の期待値の前提（既定を変えると golden 再生成が要る）。
    /// **実ゲーム（GameSession）は false に設定する** ＝ 粒がプレイヤーの手元に貯まり、AllocationView で手動割り振りする（パワプロ式の本体）。
    /// この分離により golden/sim は不変のまま、実ゲームだけプレイヤーが割り振れる。UI/注ぐ側はこの値を読まない。
    public var autoPourAllocation = true   // ⚠️ golden の前提＝既定 true を反転しない（実ゲームは GameSession 側で false にする・監査F-03）

    // --- アイテム（Item.swift・docs/item_design_v0.md。全て【仮】）。Python: balance_sim.ITEMS ---
    /// お店で売る品（オーナー原則 2026-10-12「アイテムで能力は上がらない」）。能力に効く4品は売らない（持っている人の効果は残す）
    public var shopLineup: [ShopItem] = [.栄養ドリンク, .銭湯の回数券, .新幹線回数券]
    public var items: [ShopItem: ItemSpec] = [
        .栄養ドリンク: ItemSpec(price: 3_000, yearlyLimit: 6, summary: "体力が少し戻る"),
        .銭湯の回数券: ItemSpec(price: 10_000, yearlyLimit: 99, summary: "休む4回ぶん、回復が増える"),
        .中古のICレコーダー: ItemSpec(price: 30_000, yearlyLimit: nil, summary: "ネタ作りで閃きが少し多く出る（ずっと）"),
        .新幹線回数券: ItemSpec(price: 200_000, yearlyLimit: 1, summary: "今年の大阪遠征が交通費なし・疲れない"),
        .ネタ作家の勉強会: ItemSpec(price: 150_000, yearlyLimit: 2, summary: "閃きと語彙の経験点"),
        .ボイトレ短期集中: ItemSpec(price: 250_000, yearlyLimit: 1, summary: "間合いと語彙の経験点"),
        .稽古場の年契約: ItemSpec(price: 2_400_000, yearlyLimit: 1, summary: "今年の稽古がすべて少し効く"),
    ]
    public var itemDrinkStamina = 8.0
    public var itemSentoTickets = 4
    public var itemSentoRecovery = 10.0
    public var itemRecorderBonus = 1.0     // ネタ作りの主効果（閃き）に足す生の量（供給スケール前）
    public var itemStudioBonus = 1.0       // 全稽古の主効果に足す生の量（供給スケール前）
    public var itemStudyHirameki = 4.0     // 勉強会：通貨に直接（供給スケール後）
    public var itemStudyGoi = 2.0
    public var itemVoiceMaai = 4.0         // ボイトレ：通貨に直接
    public var itemVoiceGoi = 2.0

    // --- 生活ルール【正典v2・docs/rule_holes_v0.md】 ---
    /// 借金中は稽古が半分しか身にならない（nil で無効。balance_sim.DEBT_TRAIN_FACTOR と同期）
    public var debtTrainFactor: Double? = 0.5
    /// 生活費支払い時に所持金<0なら課す生活苦（sim_career.DEBT_LIFE_PEN と同期）
    public var debtLifeStamina = -10.0
    public var debtLifeMental = -3.0
    /// 夜逃げライン: 所持金がこれを下回ったらキャリア強制終了（sim_career.BANKRUPT_LINE と同期）
    public var bankruptLine = -1_000_000
    // --- 途中解散（すれ違いゲージ・docs/dissolution_rift_spec_v1.md）。Python: sim_career RIFT_*【仮】 ---
    public var riftOn = true
    public var riftGain = 0.5      // 相性が上がらなかった週 ×(上限−相性)/上限
    public var riftHeal = 3.0      // 相性が上がった週
    public var riftWarn = 50.0     // 初めて越えた週末に予告（アプリ側の選択肢イベント）
    /// 体力がこの値未満だと稽古を選べない（谷口が止める・sim_career.STAMINA_GATE と同期）
    public var staminaGate = 20.0
    /// 体調ダウン（「ケガ」という語は使わない）: 体力がこの値未満のキツいバイトで抽選（sim_career.INJURY_* と同期）
    public var injuryThreshold = 20.0
    public var injuryProbPerPoint = 0.02
    public var injuryRestWeeks = 3
    public var injuryMentalHit = -5.0

    // --- 勝負の運【正典v2・A案】 ---
    /// 「ハマった夜」: 本番ごとに burstP でスコア+burstBonus（balance_sim.BURST_P/BURST_BONUS と同期）
    public var burstP = 0.10
    public var burstBonus = 12.0

    /// 演技系4能力（センス/発想/表現/華）の上限【仮・固定】。トロフィーで D が 120 を超えた分は
    /// 「上限への到達が速く・確実になる」効果として働く（balance_sim.py ABILITY_CAP と同期）
    public var abilityCap = 120.0
    /// メンタルの上限。ブレ幅式 (1−メンタル/100) に直結するため 100 のまま（balance_sim.py MENTAL_CAP と同期）
    public var mentalCap = 100.0

    // --- 生活費（Python: LIVING_COST / LIVING_INTERVAL） ---
    public var livingCost = 140_000
    public var livingInterval = 4

    // --- 稽古（Python: TRAININGS）。正典v3: main/subは能力でなく経験点通貨を発行する（.currency）。
    //     量は旧版（能力直付け）を踏襲＝既存の較正値（expSupplyScale等）を出発点にできる【仮】。
    //     ネタ合わせのsubは相性（.コンビ相性）＝経験点通貨ではなく経済外add直結のまま不変。 ---
    public var trainings: [Training: TrainingSpec] = [
        .ネタ作り:     TrainingSpec(main: (.currency(.閃き), 3),     sub: (.currency(.語彙), 1),   cost: 0,      stamina: -20, fame: 0),
        .ネタ見せ会:     TrainingSpec(main: (.currency(.間合い), 4),  // §93 旧6
          sub: (.currency(.胆力), 3),   cost: 80_000, stamina: -30, fame: 0),
        .ネタ合わせ:   TrainingSpec(main: (.currency(.間合い), 2),  // §93 旧3
          sub: (.コンビ相性, 1),        cost: 0,      stamina: -20, fame: 0),
        .ランニング・サウナ: TrainingSpec(main: (.currency(.胆力), 6),   sub: nil,                     cost: 80_000, stamina: -10, fame: 0),
        .フリーライブ:     TrainingSpec(main: (.currency(.存在感), 3), sub: (.currency(.間合い), 1), cost: 0,      stamina: -30, fame: 1),
        // 場所【仮】（Python: PLACE_TRAININGS と同値。golden/sim の既定ボットは使わない）
        .喫茶店で書く:   TrainingSpec(main: (.currency(.閃き), 4.5),   sub: (.currency(.語彙), 1.5), cost: 10_000, stamina: -20, fame: 0),
        .ファミレスで書く: TrainingSpec(main: (.currency(.閃き), 4),   sub: (.currency(.語彙), 1),   cost: 5_000,  stamina: -30, fame: 0),
        .作家の勉強会:   TrainingSpec(main: (.currency(.閃き), 6),     sub: (.currency(.語彙), 3),   cost: 80_000, stamina: -20, fame: 0),
        .ボイトレ:       TrainingSpec(main: (.currency(.存在感), 6),   sub: (.currency(.間合い), 2), cost: 80_000, stamina: -20, fame: 0),
    ]
    /// ネタを書く場所ごとの完成度の伸び（家で書く＝ネタ作り は netaReviseGain）【仮】
    public var netaPlaceGain: [Training: Double] = [.喫茶店で書く: 10, .ファミレスで書く: 12]
    /// ネタを書く行動か（家・喫茶店・ファミレス）
    public static let netaWriteTrainings: Set<Training> = [.ネタ作り, .喫茶店で書く, .ファミレスで書く]

    // --- バイト（Python: JOBS） ---
    public var jobs: [Job: (income: Int, stamina: Double)] = [
        .キツい: (income: 96_000, stamina: -30),
        .標準:   (income: 64_000, stamina: -20),
        .楽:     (income: 32_000, stamina: -10),
    ]

    // --- 休む（Python: RESTS） ---
    public var rests: [Rest: (recovery: Double, bonus: (StatKey, Double))] = [
        .完全休養:     (recovery: 60, bonus: (.ability(.メンタル), 2)),
        .気分転換:     (recovery: 35, bonus: (.ability(.メンタル), 1)),
        .相方と過ごす: (recovery: 20, bonus: (.コンビ相性, 1)),
        // 有料【仮】（Python: PAID_RESTS/REST_COST と同値。golden/sim の既定ボットは使わない）
        .サウナ:       (recovery: 80, bonus: (.ability(.メンタル), 2)),
        .温泉に一泊:   (recovery: 100, bonus: (.ability(.メンタル), 2)),   // 相性+1 は帯を壊した（money_items_neta_v1 §6-2）
    ]
    /// 休みの費用（無い＝無料）。払えなければ完全休養になる
    public var restCosts: [Rest: Int] = [.サウナ: 10_000, .温泉に一泊: 60_000]

    // --- オファー（Python: OFFER_MONEY / OFFER_EXP / OFFER_RATES） ---
    public var offerMoney = OfferSpec(name: "お金重視", income: 240_000, fame: 1, ability: nil, stamina: -20)
    public var offerExp   = OfferSpec(name: "経験重視", income: 120_000, fame: 3, ability: (.表現, 2), stamina: -20)
    /// (知名度がこの値未満, 発生率/週)
    public var offerRates: [(fameBelow: Double, rate: Double)] = [(10, 0.05), (30, 0.15), (55, 0.30), (999, 0.50)]   // 区切り 20/50/80→10/30/55（キュー62）
    /// 知名度の「その他の伸び」（大会・回戦・オファー・イベント）＝×本値×(1−知名度/fameOtherCap)²（キュー62 案G）。Python: FAME_OTHER_MULT／FAME_OTHER_CAP
    public var fameOtherMult = 0.6
    public var fameOtherCap = 80.0

    // --- 本番スコア（Python: W_SENSE ほか・STAM_PEN） ---
    public var weightSense = 0.30
    public var weightIdea = 0.30
    public var weightExpr = 0.25
    public var weightChara = 0.15
    /// (体力がこの値未満, ペナルティ)。先頭から評価し最初に該当したものを適用【正典v2: 3段目を追加】
    public var staminaPenalties: [(below: Double, penalty: Double)] = [(10, -15), (30, -10), (50, -5)]

    // --- 大会カレンダー（Python: sim_career.py の定数群） ---
    public var calendar = CalendarConfig()

    // --- ネタ 作る/磨く/貯める（Phase 0・全て【仮】。これら自体は非スコア＝スコア寄与は下の Phase 1-a 係数のみ） ---
    /// アクティブな持ちネタ枠数（磨き対象＝鉄板枠。超過分は保管庫へ退避・v2 §9決点2）
    public var netaActiveSlots = 4
    /// `ネタ作り` 改稿の完成度上昇
    public var netaReviseGain = 8.0
    /// 0016 書けた一本（寝かせる）＝ネタ合わせ効果ブースト。netaBoostWeeks>0 の間 revise 上昇に掛ける倍率と持続週。
    /// 数値は【仮】（sim較正で確定）。golden 非対象（applyNetaRevise は gen_golden 非経路）。
    public var netaBoostMult = 1.6
    public var netaBoostWeeks = 2
    /// 0023 正社員の話（受ける）＝その年の成長天井（growthBudget）を縮める量（実力値換算）。芸に注げる時間が減る
    /// 機会費用。年初 budget は capCurveBase≈6.0（year1）＝1.5 は約1/4。数値は【仮】（sim較正）。golden 非対象。
    public var regularJobCeilingCost = 1.5
    /// 0022 撮られる仕事（受ける）＝撮影で稽古枠を奪われる週数。その週は稽古不可（UI層で自動休養化）。golden 非対象。
    public var photoShootPreoccupyWeeks = 1
    /// `ネタ見せ会`（有料稽古）のライブ完成度上昇
    public var netaLivePolishShow = 12.0
    /// `フリーライブ`（無料・営業）のライブ完成度上昇
    public var netaLivePolishFree = 6.0
    /// liveBuzz の実力重み・完成度重み（手応え=power×W+polish×W をclamp。決定論・非乱数）
    public var netaBuzzPowerW = 0.7
    public var netaBuzzPolishW = 0.5
    /// buzz 移動平均の直近寄与（neta.buzz = buzz*(1-α)+liveBuzz*α）
    public var netaBuzzAlpha = 0.4
    /// 鉄板バッジの閾値（完成度・場数・手応え）
    public var netaTeppanPolish = 80.0
    public var netaTeppanStage = 8
    public var netaTeppanBuzz = 60.0
    /// 再演バッジ＝作成からこの年数以上寝かせた
    public var netaRevivalYears = 3

    // --- ネタ Phase 1-a: スコア寄与（規律A・正典=sim_career.py の NETA_* 係数。数値は全て【仮】） ---
    // 選択中ネタが本番の実効ラインを下げる（＝スコアに足す）。selectedNetaID が無ければ恒等0＝従来の合否。
    /// 完成度係数（(polish-50)×これ）。sim NETA_COEF_COMP=0.04【採用値・優勝率±0年で較正済み】
    public var netaScoreCoefComp = 0.04
    /// 手応え係数（(buzz-50)×これ）。sim の fresh 項(0.02)を GameCore の buzz に対応させる（"反応"に忠実）
    public var netaScoreCoefBuzz = 0.02
    /// スコア補正の絶対クランプ（±）。sim NETA_CLAMP=5
    public var netaScoreClamp = 5.0
    /// 決勝2本制: 2本目が無い or 完成度不足なら実効ラインに上乗せ（＝不利）。sim NETA_SECOND_PEN=3
    public var netaSecondPenalty = 3.0
    /// 決勝2本目に求める最低完成度（これ未満は「2本目が弱い」扱い）
    public var netaSecondMinPolish = 60.0
    /// 同じネタは飽きられる（キュー60 案D）：大会で掛けた年の数×本値を補正から引く・上限 netaTiredCap 段・寝かせても戻らない。Python: V2_TIRED_PEN／V2_TIRED_CAP
    public var netaTiredPenalty = 1.0
    public var netaTiredCap = 2

    // --- S6b 勇退エンディングの会場ランク（表示専用・golden非対象。全て【仮】） ---
    /// 残金帯4段階の閾値（0=町の劇場／1=ホール／2=アリーナ／3=ドーム）
    public var venueTier1Money = 0
    public var venueTier2Money = 3_000_000
    public var venueTier3Money = 8_000_000

    // --- 週次ランダムイベント（UI層で抽選＝golden非対象。効果は決定的delta・数値は全て【仮】） ---
    /// 非大会週にイベント抽選が当たる確率（sim EVENT_RATE=0.12 と対応）
    public var weeklyEventRate = 0.12
    /// キャリア通算のイベント発火上限（sim EVENT_FIRE_CAP＝連発による希釈を防ぐ総量予算）
    public var weeklyEventCap = 15

    public init() {}
}
