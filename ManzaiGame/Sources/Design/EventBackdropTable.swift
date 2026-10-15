// イベントID→(場所, 時間帯) の割り当て表（アプリ側に持つ・GameCore は触らない）。
// 各イベントのセットアップ冒頭のト書きに合わせる。ト書きに無い場所は「推定」とコメント。
import SwiftUI
import GameCore

extension EventBackdrop {
    static func forEvent(_ kind: ChoiceEventKind) -> EventBackdrop {
        switch kind {
        case .justLostRehearsal:       return .init(.keikoba, .night)   // 稽古場の前・夜
        case .styleTalk:               return .init(.keikoba, .day)     // 稽古場・昼
        case .justPassedFork:          return .init(.keikoba, .day)     // 稽古場・昼
        case .preTournamentEve:        return .init(.park, .night)      // 推定: 稽古場の帰り道(場所) ・夜
        case .tsuukaBreak:             return .init(.keikoba, .day)     // 稽古場・昼休み
        case .earlyFormality:          return .init(.keikoba, .day)     // 稽古場・昼
        case .brokeDrinkingInvite:     return .init(.park, .night)      // 推定: 稽古場の帰り道(場所)・夜
        case .senpaiMeishi:            return .init(.yakiniku, .day)    // 焼肉屋・先輩のおごりの昼
        case .peerFoldedChair:         return .init(.keikoba, .day)     // 推定: 時間帯の記述なし→昼
        case .namelessReservationSlip: return .init(.uketsuke, .day)    // 稽古場の受付・昼
        case .lineupTop:               return .init(.gakuya, .day)      // 劇場の楽屋・ライブの日の昼
        case .photoShootOffer:         return .init(.office, .day)      // 事務所・昼
        case .taniguchiShortJob:       return .init(.keikoba, .day)     // 稽古場・月末の昼
        case .wroteOneTonight:         return .init(.famires, .night)   // 深夜のファミレス
        case .regularEmployment:       return .init(.office, .day)      // 推定: バイト先の休憩室→事務所に近い・昼休み
        case .lastTrainReview:         return .init(.station, .night)   // 駅のホーム・ライブ帰りの夜
        case .luckyThirdLine:          return .init(.keikoba, .day)     // 稽古場・昼すぎ
        case .greenroomSilentTen:      return .init(.gakuya, .evening)  // 推定: 劇場の楽屋・ライブが終わった後→夕
        // 相方以外の人とのイベント（docs/choice_events_others_v1.md §2）
        case .kouhaiInvite:            return .init(.gakuya, .evening)  // 劇場の楽屋・ライブ終わりの夕方
        case .senpaiAllNight:          return .init(.theater, .night)   // 劇場のロビー・最後の出番が終わった夜
        case .stageCrewChairs:         return .init(.theater, .evening) // 劇場の客席・ライブが終わった後
        case .writerPostcards:         return .init(.kissaten, .day)    // 喫茶店・昼
        case .doukiJointLive:          return .init(.park, .day)        // 公園のベンチ・昼
        case .baitoInventory:          return .init(.famires, .night)   // バイト先のファミレス・閉店後の夜
        case .homecomingCall:          return .init(.apartment, .evening) // アパートの部屋・年末の夕方
        case .regularFanOranges:       return .init(.theater, .day)     // 劇場の出口・昼の部の後
        case .officeTicketQuota:       return .init(.office, .day)      // 事務所・昼
        }
    }
}
