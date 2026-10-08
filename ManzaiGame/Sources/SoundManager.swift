// SoundManager.swift
// 音の一元管理（View層のみ・golden非干渉）。商用最低ライン=「全タップに音＋100ms以内の反応」
// （sellable_basics_research §4）。SEは多重再生プール・BGMはクロスフェード。
// 音量は SettingsView の @AppStorage("vol_se")/("vol_bgm") を毎回読む（0..1・既定0.8/0.6）。
// 素材クレジット: Resources/Audio/CREDITS.md（魔王魂のみアプリ内表記必須＝SettingsView）。

import AVFoundation
import SwiftUI

/// SE の語彙（ファイル名 se_*.mp3 と1対1）。呼び出し側はこの enum だけを知る。
enum SE: String {
    case tap = "se_tap"                    // 決定・実行
    case cursor = "se_cursor"              // カーソル・タブ・カテゴリ開閉
    case cancel = "se_cancel"              // 戻る・閉じる
    case deny = "se_deny"                  // 押せない（体力/¥不足）
    case success = "se_success"            // 成功・確定
    case rankup = "se_rankup"              // 等級/ランクアップ
    case drumroll = "se_drumroll"          // 開示前のタメ
    case tada = "se_tada"                  // ジャジャーン（開示）
    case fanfare = "se_fanfare"            // 優勝ファンファーレ
    case don = "se_don"                    // ドン（衝撃）
    case taiko = "se_taiko"                // 太鼓ドン（判の押印・通過）
    case taiko2 = "se_taiko2"              // 和太鼓ドドン（敗退の重さ）
    case grain = "se_grain"                // キラキラ（粒獲得）
    case kira = "se_kira"                  // キラッ（バッジ・小華）
    case transition = "se_transition"      // シーン切替
    case event = "se_event"                // イベント発生
    case shakin = "se_shakin"              // シャキーン（S級）
    case pop = "se_pop"                    // パッ（チップ出現）
    case money = "se_money"                // お金ジャラジャラ
    case laughSmall = "se_laugh_small"     // クスッ（小ウケ）
    case applauseSmall = "se_applause_small" // 拍手・小
    case applauseHall = "se_applause_hall"   // 拍手・会場
    case cheerMid = "se_cheer_mid"         // 歓声（中ウケ＝どっ）
    case cheerBig = "se_cheer_big"         // 大歓声（大爆笑）
}

/// BGM の語彙（ファイル名 bgm_*.mp3 と1対1）。
enum BGM: String {
    case daily = "bgm_daily"       // 育成（アコースティック・日常）
    case tension = "bgm_tension"   // 大会結果（ピアノ・緊張）
    case finals = "bgm_finals"     // 決勝（オーケストラ・番組）
}

/// 使い方: `Sound.play(.tap)` / `Sound.bgm(.daily)` / `Sound.stopBGM()`。
/// スレッド: 全APIはメインスレッド前提（SwiftUIのアクションから呼ぶ）。
enum Sound {
    static let shared = SoundEngine()
    static func play(_ se: SE) { shared.play(se) }
    static func bgm(_ track: BGM) { shared.playBGM(track) }
    static func stopBGM(fade: TimeInterval = 0.6) { shared.stopBGM(fade: fade) }
    /// BGM を一時的に絞る（factor=0..1・溜めや開演の暗転用）。duck(1) で戻す。進行中のフェードは取り消して上書きする。
    static func duck(_ factor: Float, over duration: TimeInterval = 0.3) { shared.duck(factor, over: duration) }
    /// 効果音を一時的に止める（「全SE断」の間）。false で戻す。
    static func hushSE(_ on: Bool) { shared.seHushed = on }
}

final class SoundEngine {
    private var sePlayers: [String: [AVAudioPlayer]] = [:]   // SEごとの多重プール（連打対応・最大3面）
    private var bgmPlayer: AVAudioPlayer?
    private var currentBGM: BGM?
    /// BGM の一時的な絞り（1=設定どおり）。開演の暗転・決勝の溜めで使う。
    private var duckFactor: Float = 1
    /// 「全SE断」の間は効果音を鳴らさない
    var seHushed = false
    /// プレイヤーごとの進行中フェード（新しいフェードを始める時に取り消す＝フェード同士が音量を奪い合わない）
    private var fadeTimers: [ObjectIdentifier: Timer] = [:]

    init() {
        // ambient = マナー(消音)スイッチを尊重＋他アプリ音と混ざれる（ゲームの標準）
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private var seVolume: Float {
        Float(UserDefaults.standard.object(forKey: "vol_se") as? Double ?? 0.8)
    }
    private var bgmVolume: Float {
        Float(UserDefaults.standard.object(forKey: "vol_bgm") as? Double ?? 0.6)
    }

    func play(_ se: SE) {
        let vol = seVolume
        guard vol > 0.01, !seHushed else { return }
        guard let url = Bundle.main.url(forResource: se.rawValue, withExtension: "mp3") else { return }
        var pool = sePlayers[se.rawValue] ?? []
        // 空いている面を探す（鳴っていないプレイヤーを再利用）
        if let idle = pool.first(where: { !$0.isPlaying }) {
            idle.volume = vol
            idle.currentTime = 0
            idle.play()
            return
        }
        guard pool.count < 3, let p = try? AVAudioPlayer(contentsOf: url) else { return }
        p.volume = vol
        p.prepareToPlay()
        p.play()
        pool.append(p)
        sePlayers[se.rawValue] = pool
    }

    func playBGM(_ track: BGM) {
        guard currentBGM != track else {
            if let p = bgmPlayer { cancelFade(p); p.volume = bgmVolume * duckFactor }   // 同曲なら音量だけ追従
            return
        }
        currentBGM = track
        let old = bgmPlayer
        fadeOut(old, over: 0.5)
        guard let url = Bundle.main.url(forResource: track.rawValue, withExtension: "mp3"),
              let p = try? AVAudioPlayer(contentsOf: url) else { bgmPlayer = nil; return }
        p.numberOfLoops = -1
        p.volume = 0
        p.prepareToPlay()
        p.play()
        bgmPlayer = p
        fadeIn(p, to: bgmVolume * duckFactor, over: 0.8)
    }

    func duck(_ factor: Float, over duration: TimeInterval) {
        duckFactor = max(0, min(1, factor))
        guard let p = bgmPlayer else { return }
        fade(p, to: bgmVolume * duckFactor, over: duration, stopAtEnd: false)
    }

    func stopBGM(fade: TimeInterval) {
        currentBGM = nil
        fadeOut(bgmPlayer, over: fade)
        bgmPlayer = nil
    }

    /// 設定スライダー変更の即時反映（SettingsView から呼ぶ）
    func refreshBGMVolume() { bgmPlayer?.volume = bgmVolume * duckFactor }

    // MARK: フェード（Timerベース・0.05s刻み・プレイヤーごとに取り消し可能）

    private func cancelFade(_ p: AVAudioPlayer) {
        fadeTimers.removeValue(forKey: ObjectIdentifier(p))?.invalidate()
    }

    /// 今の音量から target へ線形に動かす。同じプレイヤーの進行中フェードは取り消す。
    private func fade(_ p: AVAudioPlayer, to target: Float, over duration: TimeInterval, stopAtEnd: Bool) {
        cancelFade(p)
        let start = p.volume
        let steps = max(1, Int(duration / 0.05))
        var n = 0
        let key = ObjectIdentifier(p)
        fadeTimers[key] = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] t in
            n += 1
            p.volume = start + (target - start) * Float(n) / Float(steps)
            if n >= steps {
                t.invalidate()
                self?.fadeTimers.removeValue(forKey: key)
                if stopAtEnd { p.stop() }
            }
        }
    }

    private func fadeIn(_ p: AVAudioPlayer, to target: Float, over duration: TimeInterval) {
        fade(p, to: target, over: duration, stopAtEnd: false)
    }

    private func fadeOut(_ p: AVAudioPlayer?, over duration: TimeInterval) {
        guard let p, p.isPlaying else { return }
        fade(p, to: 0, over: duration, stopAtEnd: true)
    }
}
