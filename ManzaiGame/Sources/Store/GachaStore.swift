// GachaStore.swift
// 衣装ガチャの持ち物の保存。ゲームのセーブとは別キー（周回リセットで消さない）。端末の UserDefaults ＋ iCloud（NSUbiquitousKeyValueStore）で機種変更でも残す。
// iCloud が使えない時（オフ・未署名の検証ビルド）は端末内のみ。

import Foundation

@MainActor
final class GachaStore: ObservableObject {
    static let shared = GachaStore()
    static let key = "gacha_state_v1"

    @Published private(set) var state: GachaState
    private let defaults: UserDefaults
    private let cloud: NSUbiquitousKeyValueStore?

    init(defaults: UserDefaults = .standard, useCloud: Bool = true) {
        self.defaults = defaults
        self.cloud = useCloud ? NSUbiquitousKeyValueStore.default : nil
        var s = Self.decode(defaults.data(forKey: Self.key))
        if let c = cloud, let d = c.data(forKey: Self.key) { s = s.merged(with: Self.decode(d)) }
        state = s
        if let c = cloud {
            NotificationCenter.default.addObserver(forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                                                   object: c, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.pullFromCloud() }
            }
            c.synchronize()
        }
    }

    private static func decode(_ data: Data?) -> GachaState {
        guard let data, var s = try? JSONDecoder().decode(GachaState.self, from: data) else { return GachaState() }
        if s.totalPulls == 0 && s.freeTickets == 0 { s.freeTickets = 1 }   // 一度も回していない既存データにも「はじめての1回」分を渡す
        return s
    }

    private func pullFromCloud() {
        guard let c = cloud, let d = c.data(forKey: Self.key) else { return }
        let merged = state.merged(with: Self.decode(d))
        if merged != state { state = merged; persist() }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: Self.key)
        cloud?.set(data, forKey: Self.key)
        cloud?.synchronize()
    }

    /// 状態を変えて保存する唯一の入口
    @discardableResult
    func mutate<T>(_ body: (inout GachaState) -> T) -> T {
        var s = state
        let r = body(&s)
        state = s
        persist()
        return r
    }

    /// 持っているか（黒紋付は広告カットの購入に付く）
    func owns(_ o: StageOutfit) -> Bool {
        if o == .kuromontsuki { return StoreManager.shared.isAdFree }
        return state.owns(o)
    }

    // 画面から使う操作
    func pull(count: Int) -> [PullResult] {
        var g = SystemRandomNumberGenerator()
        return mutate { s in (0..<count).compactMap { _ in s.pullOne(&g) } }
    }
    func credit(txID: String, count: Int) { mutate { $0.credit(txID: txID, count: count) } }
    func claimLogin(today: String = GachaState.dayKey()) -> Bool { mutate { $0.claimLogin(today: today) } }
    func exchangeShards(for o: StageOutfit) -> Bool { mutate { $0.exchangeShards(for: o) } }
    func exchangePity(for o: StageOutfit) -> Bool { mutate { $0.exchangePity(for: o) } }
}
