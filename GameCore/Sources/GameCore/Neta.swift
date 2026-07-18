// Neta.swift
// 持ちネタ（レパートリー）の個体。正典: docs/neta_system_redesign_v2.md（作る→ライブで磨く→持ちネタに貯まる→大会で選ぶ）。
// ★golden非干渉（Phase 0）: このファイルのどの型・関数も RandomSource を一切呼ばない・GameEngine.perform の式に触れない。
//   ネタは perform の入力（jitsuryoku + compat + roll + penalty＝GameEngine.swift:158）に一切入らない＝合否スコア不変。
//   「反応で磨く（当たり外れ）」「選択が勝敗に効く」はスコア/乱数を要する＝Phase 1（規律A・別便）。本ファイルは非スコアの器。
// 数値は全て【仮】。型は「ネタが持つ1属性」＝年単位の選択ではない（旧Fable案の年始型選択は却下・v2 §1-G）。

/// ネタの型＝1本のネタが持つ属性（judge_preference_research_v0.md §5／multiyear §2-3 の7型と1対1）。
public enum NetaKata: String, Codable, CaseIterable {
    case 王道しゃべくり   // 会話の純度・間
    case 関係性         // 二人の歴史・掛け合い
    case 伏線回収        // 多層構成
    case リターン        // 天丼・帰る場所（反復）
    case 非定型         // 新しい型の発明（実験）
    case 瞬発          // 畳みかけ・勢い押し
    case 華先行         // つかみ・存在感で持つ
}

/// 尺＝実在漫才の第一制約（1回戦2分／準々〜決勝4分。v2 §1-F）。Phase 0 は選択時の"合う/合わない"表示のみ（合否非干渉）。
public enum NetaLength: String, Codable, CaseIterable {
    case 短尺   // 詰めて2分で成立する型
    case 中尺   // 3分で映える
    case 長尺   // 4分の展開・伏線が生きる型
}

/// 戦績スタンプ（表示専用・非スコア）。ネタ帳で「このネタで3回戦通過」等の育った実感に使う。
public struct NetaStamp: Codable, Equatable {
    public let year: Int
    public let stage: String   // "GP3回戦" 等（StageResult.name をそのまま）
    public let passed: Bool
    public init(year: Int, stage: String, passed: Bool) {
        self.year = year; self.stage = stage; self.passed = passed
    }
}

/// 持ちネタ1個体。exp*（GameState.swift:30-38）と同じ純Swift・RandomSource非依存・Codable。
public struct Neta: Codable, Identifiable, Equatable {
    public let id: Int                   // 生成連番（セーブ安定・表示ソート用）
    public var name: String              // 題材名（自動生成 or プレイヤー命名・一般名詞のみ／v2 §9-決点3）
    public var kata: NetaKata            // 型＝1属性。let→var（磨く中で1度だけ組み替え可・v2 §3-1補）
    /// このネタが映える尺。★Set でなく正準ソート済み配列＝Codable のバイト列が決定論（v2 §6-1補・Set順序の不安定を回避）
    public var lengthFit: [NetaLength]
    public var polish: Double            // 完成度 0..100（稽古・ライブで上がる資産・下がらない）
    public var buzz: Double              // 手応え 0..100（ライブ反応の移動平均）。★Phase 0 は決定論=実力×完成度従属（限界は v2 §3-2補）
    public let bornYear: Int             // 作成年（芸歴年・「古いネタも再演」の証拠・v2 §1-D）
    public var stageCount: Int           // 通算ライブ数（"漫才はドラクエ"の経験値・v2 §1-B）
    public var isDown: Bool              // おろし済（初披露を経たか・v2 §1-B）。false=未おろし
    public var exposure: Double          // 露出度（大会で使うほど+。"広く知られた度"の表示のみ・非スコア・v2 §3-2補）
    public var record: [NetaStamp]       // 戦績スタンプ列（表示専用）
    public var lastUsedTaikaiYear: Int?  // 同系統での連投目減り/再演肯定の判定に使う年（v2 §4-2）

    /// 新ネタ生成（polish=30 の初期状態）。lengthFit は正準順（NetaLength.allCases 順）に正規化してから保持。
    public init(id: Int, name: String, kata: NetaKata, lengthFit: [NetaLength], bornYear: Int) {
        self.id = id
        self.name = name
        self.kata = kata
        self.lengthFit = NetaLength.allCases.filter { lengthFit.contains($0) }   // 正準ソート＋重複除去
        self.polish = 30
        self.buzz = 0
        self.bornYear = bornYear
        self.stageCount = 0
        self.isDown = false
        self.exposure = 0
        self.record = []
        self.lastUsedTaikaiYear = nil
    }

    /// この尺に映えるか（純関数・表示専用）
    public func fits(_ length: NetaLength) -> Bool { lengthFit.contains(length) }

    // MARK: 派生状態（純関数・表示専用・非スコア）— ネタ帳のバッジに使う

    /// 鉄板＝高完成度×場数×安定した手応え（v2 §1-E「鉄板3本あれば一流」）。数値は全て【仮】。
    public func isTeppan(config: GameConfig) -> Bool {
        polish >= config.netaTeppanPolish && stageCount >= config.netaTeppanStage && buzz >= config.netaTeppanBuzz
    }

    /// 数年寝かせたネタの再演（v2 §1-D「20年前のネタを今やる」）。表示・講評分岐に使う。
    public func isRevival(currentYear: Int, config: GameConfig) -> Bool {
        currentYear - bornYear >= config.netaRevivalYears
    }

    // MARK: ライブの手応え（純関数・RandomSource を一切呼ばない＝golden非干渉）

    /// ライブ1回の手応え。実在: 今の実力×ネタの完成度で沸きが決まる（v2 §3-2）。数値は全て【仮】。
    /// ★Phase 0 は決定論（客層の当たり外れ＝乱数は入れない）＝"低反応という情報"は生まれない（限界は v2 §3-2補・§9決点6）。
    /// 真に"反応で磨く"には客層依存の乱数＝Phase 1（規律A）。ここで乱数を引くと消費順が動き golden が壊れる。
    public static func liveBuzz(state s: GameState, neta: Neta, config: GameConfig) -> Double {
        let power = GameEngine.jitsuryoku(s, config: config)   // 参照のみ・perform の乱数には触れない（GameEngine.swift:51）
        let raw = power * config.netaBuzzPowerW + neta.polish * config.netaBuzzPolishW
        return GameEngine.clamp(raw, 0, 100)
    }
}
