// YoseFXPreview.swift  DEBUG専用：演出を1つずつ単独で再生する目視フック。
// 使い方: MZ_FX=burst|pass|champion|cutin|rankup|rankup_multi|yearturn|streak|money （RootView の MZ_UI と同じ並びで env を渡す）
#if DEBUG
import SwiftUI

struct YoseFXPreview: View {
    let kind: String
    @State private var fire = 0
    @State private var show = false
    @State private var stamped = false
    @State private var loop = 0

    var body: some View {
        ZStack {
            YoseColor.kinari.ignoresSafeArea()
            switch kind {
            case "rankup", "rankup_multi":
                if show { YoseRankUpOverlay(items: Self.sampleItems(multi: kind == "rankup_multi"), totalPower: 134, powerDelta: 4) { show = false; relaunch() } }
            case "yearturn":
                if show { YoseYearTurnCurtainView(summary: YearTurnSummary(combiName: "満月ロケット", previousYear: 1, newYear: 2, power: 104, fame: 32, money: 150_000, netaCount: 4)) { show = false; relaunch() } }
            case "burst", "cutin":
                // 週画面の見立て（練習ボタン押下直後）の上を貫通する大成功カットイン
                ZStack {
                    VStack(spacing: 14) {
                        Text("1年目 3月 2週").font(YoseFont.gothic(16, weight: .heavy)).foregroundStyle(YoseColor.sumi)
                        Text("練習：ネタ合わせ").font(YoseFont.gothic(13)).foregroundStyle(YoseColor.haiSumi)
                    }.offset(y: -240)
                    if show { YoseBigSuccessCutIn { show = false; relaunch() } }
                }
            case "streak":
                Text("能力 42 → 46").font(YoseFont.number(34, weight: .black)).padding(30)
                    .background(YoseColor.washi).yoseKifuda().yoseLightStreak(trigger: fire)
            case "pass":
                if show { YosePassCelebrationView { show = false; relaunch() } }
            case "champion":
                YoseChampionCelebrationView(duoName: "満月ロケット", partnerName: "谷口") { }
            default:
                Text("MZ_FX 未定義: \(kind)")
            }
        }
        .task { await play() }
    }

    private func play() async {
        try? await Task.sleep(nanoseconds: 300_000_000)
        show = true; stamped = true; fire += 1
        if kind == "streak" {
            while !Task.isCancelled { try? await Task.sleep(nanoseconds: 1_600_000_000); stamped.toggle(); fire += 1 }
        }
    }
    private func relaunch() { Task { try? await Task.sleep(nanoseconds: 800_000_000); show = true } }

    static func sampleItems(multi: Bool) -> [RankUpItem] {
        var a = [RankUpItem(abilityName: "表現", abilityShort: "表", abilityColor: Theme.abilityColor(.表現), fromRank: "F", toRank: "E", beforeValue: 24, afterValue: 26)]
        if multi {
            a.append(RankUpItem(abilityName: "センス", abilityShort: "セ", abilityColor: Theme.abilityColor(.センス), fromRank: "G", toRank: "F", beforeValue: 14, afterValue: 16))
            a.append(RankUpItem(abilityName: "華", abilityShort: "華", abilityColor: Theme.abilityColor(.華), fromRank: "E", toRank: "D", beforeValue: 34, afterValue: 36))
        }
        return a
    }
}
#endif
