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
                if show { YoseYearTurnCurtainView(summary: YearTurnSummary(combiName: "（見本）", previousYear: 1, newYear: 2, power: 104, fame: 32, money: 150_000, netaCount: 4)) { show = false; relaunch() } }
            case "burst":
                VStack(spacing: 30) {
                    Text("\(100 + fire)").font(YoseFont.number(60, weight: .black)).foregroundStyle(YoseColor.sumi)
                        .yoseNumberPop(value: fire)
                    Text("経験点バースト").font(YoseFont.gothic(14))
                }
                .overlay { YoseBurstParticles(trigger: fire, count: 24, radius: 120).frame(width: 300, height: 300) }
            case "streak":
                Text("能力 42 → 46").font(YoseFont.number(34, weight: .black)).padding(30)
                    .background(YoseColor.washi).yoseKifuda().yoseLightStreak(trigger: fire)
            case "pass":
                ZStack {
                    YoseHarigamiCard { Text("予選通過").font(YoseFont.mincho(28)).padding(40) }
                    YoseAnimatedHanko(text: "突破", isStamped: stamped, isSquare: true, angle: -8).offset(x: 80, y: -30).scaleEffect(1.6)
                }.yoseShake(trigger: fire, intensity: .medium)
            case "champion":
                YoseChampionCelebrationView(duoName: "満月ロケット", partnerName: "谷口") { }
            case "cutin":
                ZStack {
                    YoseSpeedLinesView(lineCount: 32)
                    YoseCutInBanner(title: "手応え抜群！ハマった！！", subtitle: "練習大成功", stampText: "大成功", isPresented: show)
                }
            default:
                Text("MZ_FX 未定義: \(kind)")
            }
        }
        .task { await play() }
    }

    private func play() async {
        try? await Task.sleep(nanoseconds: 300_000_000)
        show = true; stamped = true; fire += 1
        if kind == "burst" || kind == "streak" || kind == "pass" {
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
