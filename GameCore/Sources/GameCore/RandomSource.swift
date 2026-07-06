// RandomSource.swift
// 乱数はシード固定可能なものを注入する（CLAUDE.mdルール2）。
// ゲームロジックは RandomSource プロトコルにのみ依存し、テストではスタブに差し替える。

public protocol RandomSource {
    /// [0, 1) の一様乱数
    mutating func nextUniform() -> Double
}

extension RandomSource {
    /// range 内の一様乱数
    public mutating func uniform(in range: ClosedRange<Double>) -> Double {
        range.lowerBound + (range.upperBound - range.lowerBound) * nextUniform()
    }
}

/// SplitMix64。シード固定で全プラットフォーム同一列を生成する決定的乱数源。
/// Codable準拠は中断セーブの土台（内部stateを保存すれば再開後も乱数列がずれない）。
public struct SplitMix64: RandomSource, Codable {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    public mutating func nextUInt64() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    public mutating func nextUniform() -> Double {
        // 上位53bitを使い [0,1) を等間隔で埋める
        Double(nextUInt64() >> 11) * (1.0 / 9_007_199_254_740_992.0)
    }
}
