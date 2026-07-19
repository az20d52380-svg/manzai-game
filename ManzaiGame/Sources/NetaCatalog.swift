// NetaCatalog.swift
// ネタの表示名・自動命名・型/尺の既定値カタログ。正典: docs/neta_system_redesign_v2.md §2-1/§9決点2,3。
// 表示専用・純データ（RandomSourceを一切使わない・決定論）。GameSession から呼ばれる Phase 0 の付帯データ。
// 題材名は全て一般名詞の組み合わせ＝実在の漫才ネタ・語録を一切参照しない（架空名厳守）。

import GameCore

enum NetaCatalog {

    /// 型の表示名（v2 §2-1・旧名継続案）。内部enum名は判定に使わず、相性表（multiyear §2-3）とは
    /// enumのcase名で1対1接続する。表示名はここだけ差し替えられる。
    static func displayName(_ k: NetaKata) -> String {
        switch k {
        case .王道しゃべくり: return "王道しゃべくり"
        case .関係性: return "関係性"
        case .伏線回収: return "伏線回収"
        case .リターン: return "リターン型"
        case .非定型: return "飛び道具"
        case .瞬発: return "畳みかけ"
        case .華先行: return "つかみ型"
        }
    }

    /// 尺の表示名
    static func displayName(_ l: NetaLength) -> String {
        switch l {
        case .短尺: return "短尺"
        case .中尺: return "中尺"
        case .長尺: return "長尺"
        }
    }

    /// 自動割当の型（決定論・nextNetaID を種にした周回）。プレイヤーは後から changeNetaKata で組み替え可（v2 §3-1補）。
    static func autoKata(forID id: Int) -> NetaKata {
        let all = NetaKata.allCases
        return all[((id % all.count) + all.count) % all.count]
    }

    /// 型ごとの既定映え尺（v2 §1-Fの性質を反映した分類・純粋に表示の合う/合わない判定用・数値には無関係）。
    static func defaultLengthFit(for kata: NetaKata) -> [NetaLength] {
        switch kata {
        case .王道しゃべくり: return [.中尺, .長尺]
        case .関係性: return [.中尺, .長尺]
        case .伏線回収: return [.長尺]
        case .リターン: return [.中尺, .長尺]
        case .非定型: return [.短尺, .中尺]
        case .瞬発: return [.短尺, .中尺]
        case .華先行: return [.短尺]
        }
    }

    /// 自動命名（一般名詞の題材ラベル・実在ネタ非模倣）。プレイヤーは後から renameNeta で改名可。
    /// 決定論（id を種にした周回）＝golden非対象・乱数非消費。
    static func autoName(forID id: Int) -> String {
        let i = ((id % names.count) + names.count) % names.count
        return names[i]
    }

    private static let names: [String] = [
        "商店街の福引", "終電の二人", "引っ越しの日", "同窓会の名簿", "コンビニの夜勤",
        "健康診断の結果", "忘れ物の傘", "分譲マンションの内見", "婚活パーティー", "家庭教師の初回",
        "公園のラジオ体操", "図書館の返却期限", "銭湯の番台", "実家からの荷物", "免許更新の講習",
        "町内会の回覧板", "駅前の似顔絵", "フリマアプリの取引", "卒業アルバムの一言", "満員電車",
        "忘年会の余興", "田舎の親戚", "新入社員の挨拶", "老人ホームの面会", "結婚式のスピーチ",
        "引っ越し業者の見積もり", "通販番組の司会", "就活の面接練習", "温泉旅館の仲居", "デパートの屋上",
        "給食当番", "町の電気屋", "回転寿司のレーン", "銀行の窓口", "免許合宿の教官",
        "落し物センター", "夜行バスの隣席", "健康食品の訪問販売", "保護者会の役員決め", "ラーメン屋の行列",
        "動物園の飼育員", "交番のお巡りさん", "病院の待合室", "スーパーの試食コーナー", "カラオケの選曲",
        "引っ越し先の隣人", "遠足のしおり", "宅配便の再配達", "区役所の窓口", "自転車のパンク",
    ]
}
