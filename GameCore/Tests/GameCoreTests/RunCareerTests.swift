// RunCareerTests.swift
// テストから一度も呼ばれていなかった公開関数（GameCareer.runCareer・Neta.fits）の挙動を確かめる。
// ★式・乱数・golden には触れない（既存の GoldenPolicy／SplitMix64 をそのまま使う）。

import XCTest
@testable import GameCore

final class RunCareerTests: XCTestCase {

    private func encoded(_ s: GameState) throws -> Data {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return try e.encode(s)
    }

    /// runCareer は「runYear を年ごとに回し、前年に3回戦以上通過なら GP シードを付ける」の手書きループと同じ結果になる
    func testRunCareerMatchesManualYearLoop() throws {
        let config = GameConfig()
        let years = 3

        var s1 = GameState(config: config)
        var p1 = GoldenPolicy()
        var r1 = SplitMix64(seed: 424243)
        let champ1 = GameCareer.runCareer(state: &s1, years: years, config: config, policy: &p1, rng: &r1, inviteSeed: 424243)

        var s2 = GameState(config: config)
        var p2 = GoldenPolicy()
        var r2 = SplitMix64(seed: 424243)
        var champ2: Int? = nil
        var prevStage = 0
        for year in 1...years {
            let o = GameCareer.runYear(state: &s2, year: year, config: config, policy: &p2, rng: &r2,
                                       gpSeeded: prevStage >= 3, inviteSeed: 424243)
            prevStage = o.roundsPassed
            if o.champion { champ2 = year; break }
            if o.bankrupt { break }
        }

        XCTAssertEqual(champ1, champ2)
        XCTAssertEqual(try encoded(s1), try encoded(s2))
        XCTAssertEqual(r1.nextUInt64(), r2.nextUInt64(), "乱数の消費量も一致する")
    }

    /// 夜逃げした年でキャリアが終わる＝優勝なし（nil）で、それ以降の年は回らない
    func testRunCareerStopsOnBankruptcy() throws {
        let config = GameConfig()
        var s = GameState(config: config)
        s.money = config.bankruptLine - 1   // 1週目の週末で夜逃げ
        var p = GoldenPolicy()
        var r = SplitMix64(seed: 99)
        let champ = GameCareer.runCareer(state: &s, years: 3, config: config, policy: &p, rng: &r)
        XCTAssertNil(champ)

        var s2 = GameState(config: config)
        s2.money = config.bankruptLine - 1
        var p2 = GoldenPolicy()
        var r2 = SplitMix64(seed: 99)
        let o = GameCareer.runYear(state: &s2, year: 1, config: config, policy: &p2, rng: &r2)
        XCTAssertTrue(o.bankrupt)
        XCTAssertEqual(try encoded(s), try encoded(s2), "1年目で終わり、2年目以降は回らない")
        XCTAssertEqual(r.nextUInt64(), r2.nextUInt64())
    }

    /// 同じシードなら同じキャリア（決定論）
    func testRunCareerIsDeterministic() throws {
        let config = GameConfig()
        func run() throws -> (Int?, Data) {
            var s = GameState(config: config)
            var p = GoldenPolicy()
            var r = SplitMix64(seed: 7)
            let c = GameCareer.runCareer(state: &s, years: 2, config: config, policy: &p, rng: &r)
            return (c, try encoded(s))
        }
        let a = try run(), b = try run()
        XCTAssertEqual(a.0, b.0)
        XCTAssertEqual(a.1, b.1)
    }

    // MARK: Neta.fits

    func testFitsFollowsNormalizedLengthFit() {
        let n = Neta(id: 0, name: "A", kata: .関係性, lengthFit: [.長尺, .短尺, .長尺], bornYear: 1)
        XCTAssertEqual(n.lengthFit, [.短尺, .長尺], "正準順・重複除去")
        XCTAssertTrue(n.fits(.短尺))
        XCTAssertFalse(n.fits(.中尺))
        XCTAssertTrue(n.fits(.長尺))
    }

    func testFitsWithEmptyLengthFit() {
        let n = Neta(id: 1, name: "B", kata: .伏線回収, lengthFit: [], bornYear: 2)
        for l in NetaLength.allCases { XCTAssertFalse(n.fits(l)) }
    }
}
