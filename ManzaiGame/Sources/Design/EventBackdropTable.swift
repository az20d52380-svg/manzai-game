// イベントID→(場所, 時間帯) の割り当て表（アプリ側に持つ・GameCore は触らない）。
// 各イベントのセットアップ冒頭のト書きに合わせる。ト書きに無い場所は「推定」とコメント。
import SwiftUI
import GameCore

extension EventBackdrop {
    static func forEvent(_ kind: ChoiceEventKind) -> EventBackdrop {
        switch kind {
        case .justLostRehearsal:       return .init(.street, .night, sign: "稽古場") // 稽古場の前・夜
        case .styleTalk:               return .init(.keikoba, .day)     // 稽古場・昼
        case .justPassedFork:          return .init(.keikoba, .day)     // 稽古場・昼
        case .preTournamentEve:        return .init(.street, .night)    // 推定: 稽古場の帰り道・夜
        case .tsuukaBreak:             return .init(.keikoba, .day)     // 稽古場・昼休み
        case .earlyFormality:          return .init(.keikoba, .day)     // 稽古場・昼
        case .weekendInvite:           return .init(.theaterOutside, .night) // 劇場の裏口・夜（§102）＝街の通りだとト書きとずれた（10/19 目視）
        case .brokeDrinkingInvite:     return .init(.street, .night)    // 推定: 稽古場の帰り道・夜
        case .senpaiMeishi:            return .init(.yakiniku, .day)    // 焼肉屋・先輩のおごりの昼
        case .peerFoldedChair:         return .init(.keikoba, .day)     // 推定: 時間帯の記述なし→昼
        case .namelessReservationSlip: return .init(.uketsuke, .day)    // 稽古場の受付・昼
        case .lineupTop:               return .init(.gakuya, .day)      // 劇場の楽屋・ライブの日の昼
        case .photoShootOffer:         return .init(.office, .day)      // 事務所・昼
        case .taniguchiShortJob:       return .init(.keikoba, .day)     // 稽古場・月末の昼
        case .wroteOneTonight:         return .init(.famires, .night)   // 深夜のファミレス
        case .regularEmployment:       return .init(.famires, .day)     // バイト先の休憩室・昼休み（事務所は番付ボードがあり芸能事務所に見えた＝0055 と同じバイト先のファミレスに・10/19）
        case .lastTrainReview:         return .init(.station, .night)   // 駅のホーム・ライブ帰りの夜
        case .luckyThirdLine:          return .init(.keikoba, .day)     // 稽古場・昼すぎ
        case .greenroomSilentTen:      return .init(.gakuya, .evening)  // 推定: 劇場の楽屋・ライブが終わった後→夕
        case .riftWarning:             return .init(.street, .night)    // アパートの前・夜（0050 途中解散の予告）
        // 相方以外の人とのイベント（docs/choice_events_others_v1.md §2）
        case .kouhaiInvite:            return .init(.gakuya, .evening)  // 劇場の楽屋・ライブ終わりの夕方
        case .senpaiAllNight:          return .init(.theater, .night)   // 劇場のロビー・最後の出番が終わった夜
        case .stageCrewChairs:         return .init(.theater, .evening) // 劇場の客席・ライブが終わった後
        case .writerPostcards:         return .init(.kissaten, .day)    // 喫茶店・昼
        case .doukiJointLive:          return .init(.park, .day)        // 公園のベンチ・昼
        case .baitoInventory:          return .init(.famires, .night)   // バイト先のファミレス・閉店後の夜
        case .homecomingCall:          return .init(.apartment, .evening) // アパートの部屋・年末の夕方
        case .regularFanOranges:       return .init(.theaterOutside, .day) // 劇場の出口・昼の部の後
        case .officeTicketQuota:       return .init(.office, .day)      // 事務所・昼
        // 芸人の暮らしのイベント 第2束（docs/choice_events_more_v1.md §2）
        case .summerFestivalGig:       return .init(.keikoba, .day)     // 稽古場・事務所から電話が来た昼
        case .doukiOnTV:               return .init(.apartment, .night) // アパートの部屋・テレビをつけた夜
        case .theaterRenovation:       return .init(.theater, .day)     // 劇場のロビー・張り紙が出た昼
        case .classmateInAudience:     return .init(.theaterOutside, .night) // 劇場の出口→近い背景=劇場・夜の部の後
        case .partnerFever:            return .init(.keikoba, .morning) // 稽古場・相方から電話が来た朝
        case .lostNotebook:            return .init(.stationGate, .morning) // 駅の忘れ物の窓口→近い背景=駅・朝
        case .yearEndLive:             return .init(.gakuya, .night)    // 劇場の楽屋・年末のライブの後
        // 終盤イベント（late_events_cand_1108）。ト書きの場所と時間帯に合わせる
        case .lateE01:                return .init(.theaterOutside, .day) // E1 劇場の裏口。昼。（客席だとト書きとずれた＝visual_late_events_1109）
        case .lateE02:                return .init(.gakuya, .night) // E2 楽屋の廊下。夜。
        case .lateE03:                return .init(.street, .evening) // E3 駅前のビジョン。夕方。
        case .lateE04:                return .init(.office, .day) // E4 事務所の応接室。昼。
        case .lateE05:                return .init(.apartment, .night) // E5 アパート。夜。
        case .lateE06:                return .init(.office, .morning) // E6 病院の待合室。朝。
        case .lateE07:                return .init(.street, .night) // E7 居酒屋の前。夜。
        case .lateE08:                return .init(.theater, .day) // E8 劇場のロビー。昼。
        case .lateE09:                return .init(.office, .day) // E9 制作会社の会議室。昼。
        case .lateE10:                return .init(.apartment, .night) // E10 アパート。深夜。
        case .lateE11:                return .init(.keikoba, .day) // E11 稽古場。昼。
        case .lateE12:                return .init(.apartment, .night) // E12 アパートの押し入れ。夜。
        case .lateE13:                return .init(.theater, .evening) // E13 劇場の階段。夕方。
        case .lateE14:                return .init(.apartment, .morning) // E14 アパート。朝。
        case .lateE15:                return .init(.theaterOutside, .night) // E15 劇場の出口。夜。（同上）
        case .lateE16:                return .init(.office, .day) // E16 事務所の事務室。昼。
        case .lateE17:                return .init(.keikoba, .morning) // E17 稽古場。朝。
        case .lateE18:                return .init(.office, .day) // E18 事務所の応接室。昼。
        case .lateE19:                return .init(.theaterOutside, .evening) // E19 古い劇場の前。夕方。
        case .lateE20:                return .init(.apartment, .night) // E20 アパートの廊下。夜。
        case .lateN01:                return .init(.theater, .day) // N1 劇場の応接室。昼。
        case .lateN02:                return .init(.office, .evening) // N2 事務所の電話口。夕方。
        case .lateN03:                return .init(.office, .morning) // N3 劇場の事務室。朝。（客席だとト書きとずれた・エンディングの「劇場の事務室」と同じ office＝visual_late_events_1109）
        case .lateN04:                return .init(.keikoba, .day) // N4 会場の控室。昼。
        case .lateN05:                return .init(.keikoba, .evening) // N5 稽古場の入口。夕方。
        case .lateN06:                return .init(.gakuya, .evening) // N6 舞台袖。本番前。
        case .lateN07:                return .init(.theater, .day) // N7 劇場の客席。昼。
        case .lateN08:                return .init(.keikoba, .day) // N8 稽古場。昼。
        case .lateN09:                return .init(.office, .evening) // N9 劇場の事務室。夕方。
        case .lateN10:                return .init(.street, .night) // N10 商店街の店先。夜。
        case .lateN11:                return .init(.street, .evening) // N11 定食屋の前。夕方。
        case .lateN12:                return .init(.office, .evening) // N12 事務所の会議室。夕方。
        case .lateN13:                return .init(.keikoba, .day) // N13 衣装部屋。昼。
        case .lateN14:                return .init(.office, .day) // N14 事務所の受付。昼。
        case .lateN15:                return .init(.office, .day) // N15 事務所の会議室。昼。
        case .lateN16:                return .init(.office, .night) // N16 劇場の事務室。夜。
        case .lateN17:                return .init(.theater, .day) // N17 劇場の応接室。昼。
        case .lateN18:                return .init(.keikoba, .day) // N18 稽古場。昼。
        case .lateN19:                return .init(.office, .morning) // N19 事務所の掲示板の前。朝。
        case .lateN20:                return .init(.theater, .evening) // N20 劇場の受付。夕方。
        }
    }
}
