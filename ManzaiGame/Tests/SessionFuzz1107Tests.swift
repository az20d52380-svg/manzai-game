import XCTest
import GameCore
@testable import ManzaiGame

/// でたらめな順の操作で通す点検（種を固定）：落ちない・止まらない・保存→復元で状態が変わらない・年表が崩れない。
/// 台本どおりの通しテストでは踏まない順（買い物と週の間の閉じる／引退させたネタの選択／大会を休む 等）を拾う。
final class SessionFuzz1107Tests: IsolatedStoreTestCase {
    private func json(_ s: GameSession, _ label: String) -> Data {
        let e = JSONEncoder(); e.outputFormatting = .sortedKeys
        do { return try e.encode(s.state) } catch { XCTFail("\(label) 状態を書けない（NaN 等）: \(error)"); return Data() }
    }

    private func stepName(_ p: WeekRunner<SplitMix64>.Phase) -> String {
        String(String(describing: p).prefix { $0 != "(" })
    }

    private func play(seed: UInt64, start: GameState?, kind: ComboKind) -> String? {
        var rng = FuzzRNG(x: seed &* 7919 &+ 13)
        func dice(_ n: Int) -> Int { Int(rng.next() % UInt64(n)) }
        GameSession.store.removeObject(forKey: "manzai.save.v1")
        var s = GameSession(seed: seed, startState: start, comboKind: kind)
        var steps = 0
        while steps < 40000 {
            steps += 1
            let where_ = "seed=\(seed) y=\(s.year) w=\(s.week) step=\(steps)"

            // 閉じて開き直す（バックグラウンドの保存→起動）
            if dice(40) == 0, !(s.finished && s.careerOver) {
                let before = json(s, where_); let (y, w, h) = (s.year, s.week, s.yearHistory)
                let (p, ev, res, prize, lg) = (stepName(s.phase), s.pendingChoiceEvent?.id, s.pendingResult != nil, s.totalPrize, s.log)
                s.saveNow()
                let r = GameSession.loadedOrNew()
                XCTAssertEqual(stepName(r.phase), p, "段 \(where_)")   // 中身は辞書の並びで文字列が揺れる＝種類だけ比べる（状態は json で並びを揃えて比べる）
                XCTAssertEqual(r.pendingChoiceEvent?.id, ev, "イベント \(where_)")
                XCTAssertEqual(r.pendingResult != nil, res, "結果 \(where_)")
                XCTAssertEqual(r.totalPrize, prize, "賞金 \(where_)")
                XCTAssertEqual(r.log, lg, "記録 \(where_)")
                XCTAssertEqual(r.year, y, where_); XCTAssertEqual(r.week, w, where_); XCTAssertEqual(r.yearHistory, h, where_)
                XCTAssertEqual(json(r, where_), before, "保存→復元で状態が変わった \(where_)")
                s = r
            }
            // 週の合間の寄り道（お店・ネタ帳・能力アップ）
            if dice(6) == 0 {
                switch dice(9) {
                case 0: _ = s.buyItem(ShopItem.allCases[dice(ShopItem.allCases.count)])
                case 1: _ = s.moveRoom(to: dice(5))
                case 2: _ = s.learnSkill(Skill.allCases[dice(Skill.allCases.count)])
                case 3: _ = s.allocate((0..<dice(5)).map { _ in Ability.allCases[dice(Ability.allCases.count)] })
                case 4: _ = s.allocate(s.recommendedAllocation())
                case 5: if let n = s.state.netas.randomElement(using: &rng) { s.retireNeta(n.id) }
                case 6: if let n = s.state.netas.randomElement(using: &rng) { s.recallNeta(n.id) }
                case 7: s.selectNeta(s.state.netas.randomElement(using: &rng)?.id)
                default: if dice(2) == 0 { s.beginNewWrite() } else if let n = s.state.netas.randomElement(using: &rng) { s.setWriteNeta(n.id) }
                }
            }

            if s.winFinale { s.acknowledgeWin(); continue }
            if s.finished {
                if s.careerOver {
                    XCTAssertNotNil(s.endingID, "結末が無い seed=\(seed)")
                    XCTAssertEqual(s.yearHistory.map(\.year), Array(1...s.year), "年表 seed=\(seed)")
                    return nil
                }
                if s.canChooseRetire, dice(4) == 0 { s.retireAfterWin(); continue }
                s.startNextYear(); continue
            }
            if s.watchingFinal { s.finishWatchingFinal(winner: "—"); continue }
            if s.pendingChoiceEvent != nil {
                let cs = s.availableEventChoices()
                if !cs.isEmpty { s.applyEventChoice(cs[dice(cs.count)].id) }
                s.dismissChoiceEvent(); continue
            }
            if s.pendingResult != nil { s.acknowledgeResult(); continue }
            switch s.phase {
            case .tournamentDecision:
                s.decideTournament([Travel.新幹線, Travel.夜行バス, nil][dice(3)])
            case .freeAction(let offer):
                switch dice(offer == nil ? 3 : 4) {
                case 0: s.choose(.train(Training.allCases[dice(Training.allCases.count)]))
                case 1: s.choose(.job(Job.allCases[dice(Job.allCases.count)]))
                case 2: s.choose(.rest(Rest.allCases[dice(Rest.allCases.count)]))
                default: s.choose(.acceptOffer)
                }
            case .gpRound, .gpRevival, .gpFinal: s.advanceAuto()
            default: return "止まった \(s.phase) \(where_)"
            }
        }
        return "手数の上限 seed=\(seed) y=\(s.year) w=\(s.week)"
    }

    func testRandomOrderDefaultStart() {
        for seed in UInt64(100)..<112 { let r = play(seed: seed, start: nil, kind: seed % 2 == 0 ? .maleMale : .femaleFemale); XCTAssertNil(r, r ?? "") }
    }

    /// 周回の点が多い開始（初期の経験点・所持金が増える）でも同じように通る。点はキャリアで増えるだけ
    func testRandomOrderWithMetaPoints() {
        for (i, pts) in [10, 24, 36, 38].enumerated() {
            let female = i % 2 == 1
            let before = TrophyBook.points
            let start = GameState(config: GameConfig(), metaPoints: pts, femaleCombo: female)
            let r = play(seed: 300 + UInt64(i), start: start, kind: female ? .femaleFemale : .maleMale)
            XCTAssertNil(r, r ?? "")
            XCTAssertGreaterThanOrEqual(TrophyBook.points, before)
        }
    }

    func testRandomOrderMaxedStart() {
        for seed in UInt64(200)..<206 { let r = play(seed: seed, start: GameSession.debugMaxedState(), kind: seed % 2 == 0 ? .maleMale : .femaleFemale); XCTAssertNil(r, r ?? "") }
    }
}

/// 操作を選ぶ用の乱数（ゲーム本体の乱数列とは別物）
private struct FuzzRNG: RandomNumberGenerator {
    var x: UInt64
    mutating func next() -> UInt64 {
        x &+= 0x9E3779B97F4A7C15
        var z = x
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
