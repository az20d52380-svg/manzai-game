// GameConfig.swift
// バランス数値の集約点（CLAUDE.mdルール3）。全て【仮】。
// tools/balance_sim.py の CONFIG と1対1対応させ、数式を変えたら必ず両方を更新する（ルール5）。
// 対応表は docs/gamecore_design.md を参照。

/// 能力5種（Python: sense / idea / expr / chara / mental）
public enum Ability: CaseIterable, Hashable {
    case センス
    case 発想
    case 表現
    case 華
    case メンタル
}

/// 増減の対象となるステータスの鍵（Python: add() の key）
public enum StatKey {
    case ability(Ability)
    case コンビ相性
    case 体力
    case 知名度
}

public enum Training: CaseIterable, Hashable {
    case ネタ作り
    case ネタ見せ会
    case ネタ合わせ
    case ランニング・サウナ
    case フリーライブ
}

public enum Job: CaseIterable, Hashable {
    case キツい
    case 標準
    case 楽
}

public enum Rest: CaseIterable, Hashable {
    case 完全休養
    case 気分転換
    case 相方と過ごす
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

public struct OfferSpec {
    public let name: String
    public let income: Int
    public let fame: Double
    public let ability: (Ability, Double)?
    public let stamina: Double

    public init(name: String, income: Int, fame: Double, ability: (Ability, Double)?, stamina: Double) {
        self.name = name
        self.income = income
        self.fame = fame
        self.ability = ability
        self.stamina = stamina
    }
}

public struct GameConfig {
    // --- 基本（Python: WEEKS ほか） ---
    public var weeks = 48
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

    // --- 経験点割り振り【docs/exp_abilityup_impl_reply_v0.md・二区画中間。全て【仮】】 ---
    /// 割り振り1段（+1タップ）で注ぐ経験点量。UIの逐次見積もり・確定・sim/goldenボットが
    /// 全てこの刻みで pourStep を回す（単位を跨いだ一括評価を許さない＝貯め込みの1点評価上振れを構造で断つ）
    public var allocationStep = 1.0
    /// 稽古発行のうち共通枠（ネタ/舞台）へ入る割合ρ。0で同色1:1に完全縮退（ロールバック先）。
    /// 【仮・会計移設で再照準＝0】sim較正（§4-2ゲート4・ρスイープ{0/0.15/0.25/0.35}）で、共通枠のおすすめ追いつき注ぎが
    /// 素朴帯（のんびり/バランス）を+13〜17pt押し上げ、やり込み帯との順序が潰れる（発行ゲートの轍）ことが実測された。
    /// ゲート4の指示どおりρを下げ切り 0 に縮退＝共通枠は使わず同色1:1で発行（ExpGroup機構は残置・UI共通チップは0表示）。
    /// balance_sim.EXP_FREE_SHARE と同期——注ぐ側とUIはこの値を読まない。
    public var expFreeShare = 0.0
    /// 稽古が発行する経験点（粒）の供給スケール【仮・会計移設で新設】。creditTraining が能力上昇量に掛ける。
    /// 段刻みの逓減複利下振れ＋おすすめ全量注ぎで実力が予算上限に張り付き帯が潰れるため、供給を 0.48 に絞って
    /// 「上手い＝分散」と「素朴」の帯順序・水準を復元する主ツマミ（§4-2ゲート3の供給再照準）。
    /// [74/80] 到達率 やり込み44.5/のんびり23.1/バランス9.1（目標41.5/23.1/8.4）。balance_sim.EXP_SUPPLY_SCALE と同期。
    public var expSupplyScale = 0.48
    /// 行動直後に WeekRunner が recommendedPlan で粒を自動全量注ぎするか【正典分離】。
    /// true（既定）= sim/golden/ボットの決定論的「おすすめ台本」＝ここが golden の期待値の前提（既定を変えると golden 再生成が要る）。
    /// **実ゲーム（GameSession）は false に設定する** ＝ 粒がプレイヤーの手元に貯まり、AllocationView で手動割り振りする（パワプロ式の本体）。
    /// この分離により golden/sim は不変のまま、実ゲームだけプレイヤーが割り振れる。UI/注ぐ側はこの値を読まない。
    public var autoPourAllocation = true

    // --- 生活ルール【正典v2・docs/rule_holes_v0.md】 ---
    /// 借金中は稽古が半分しか身にならない（nil で無効。balance_sim.DEBT_TRAIN_FACTOR と同期）
    public var debtTrainFactor: Double? = 0.5
    /// 生活費支払い時に所持金<0なら課す生活苦（sim_career.DEBT_LIFE_PEN と同期）
    public var debtLifeStamina = -10.0
    public var debtLifeMental = -3.0
    /// 夜逃げライン: 所持金がこれを下回ったらキャリア強制終了（sim_career.BANKRUPT_LINE と同期）
    public var bankruptLine = -1_000_000
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
    public var livingCost = 100_000
    public var livingInterval = 4

    // --- 稽古（Python: TRAININGS） ---
    public var trainings: [Training: TrainingSpec] = [
        .ネタ作り:     TrainingSpec(main: (.ability(.発想), 3),     sub: (.ability(.センス), 1), cost: 0,      stamina: -20, fame: 0),
        .ネタ見せ会:     TrainingSpec(main: (.ability(.表現), 6),     sub: (.ability(.メンタル), 3), cost: 80_000, stamina: -30, fame: 0),
        .ネタ合わせ:   TrainingSpec(main: (.ability(.センス), 3),   sub: (.コンビ相性, 1),        cost: 0,      stamina: -20, fame: 0),
        .ランニング・サウナ: TrainingSpec(main: (.ability(.メンタル), 6), sub: nil,                     cost: 80_000, stamina: -10, fame: 0),
        .フリーライブ:     TrainingSpec(main: (.ability(.華), 3),       sub: (.ability(.表現), 1),    cost: 0,      stamina: -30, fame: 1),
    ]

    // --- バイト（Python: JOBS） ---
    public var jobs: [Job: (income: Int, stamina: Double)] = [
        .キツい: (income: 120_000, stamina: -30),
        .標準:   (income: 80_000,  stamina: -20),
        .楽:     (income: 40_000,  stamina: -10),
    ]

    // --- 休む（Python: RESTS） ---
    public var rests: [Rest: (recovery: Double, bonus: (StatKey, Double))] = [
        .完全休養:     (recovery: 60, bonus: (.ability(.メンタル), 2)),
        .気分転換:     (recovery: 35, bonus: (.ability(.メンタル), 1)),
        .相方と過ごす: (recovery: 20, bonus: (.コンビ相性, 1)),
    ]

    // --- オファー（Python: OFFER_MONEY / OFFER_EXP / OFFER_RATES） ---
    public var offerMoney = OfferSpec(name: "お金重視", income: 300_000, fame: 1, ability: nil, stamina: -20)
    public var offerExp   = OfferSpec(name: "経験重視", income: 150_000, fame: 3, ability: (.表現, 2), stamina: -20)
    /// (知名度がこの値未満, 発生率/週)
    public var offerRates: [(fameBelow: Double, rate: Double)] = [(20, 0.05), (50, 0.15), (80, 0.30), (999, 0.50)]

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
