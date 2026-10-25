// ComboKindPickerView.swift
// 導入（タイトル直後）の「どんなコンビにする？」。カード4枚（2×2）・1タップで決定→0.3秒で次へ（docs/combo_gender_v0.md §3）。

import SwiftUI

struct ComboKindPickerView: View {
    var onSelect: (ComboKind) -> Void
    @State private var picked: ComboKind?

    private let order: [ComboKind] = [.maleMale, .femaleFemale, .maleFemale, .femaleMale]

    var body: some View {
        VStack(spacing: 0) {
            YoseHeaderBar(title: "コンビ結成")
            VStack(spacing: 18) {
                Text("どんなコンビにする？").font(YoseFont.sectionTitle).foregroundStyle(YoseColor.sumi)
                    .padding(.top, 22)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(order, id: \.self) { kind in card(kind) }
                }
                .padding(.horizontal, YoseMetrics.screenMargin)
                // 下半分が空いていた（playtest_v13 §2-6）＝選ぶと何が変わるかを1行で
                Text("選んだ形で、台詞の「俺」「私」と見た目が変わる。\nこの周のあいだは変えられない。")
                    .font(YoseFont.gothic(13, weight: .bold)).foregroundStyle(YoseColor.haiSumi)
                    .multilineTextAlignment(.center).padding(.horizontal, YoseMetrics.screenMargin)
                Spacer(minLength: 0)
            }
        }
        .background(YoseColor.kinari.ignoresSafeArea())
    }

    private func card(_ kind: ComboKind) -> some View {
        Button {
            guard picked == nil else { return }
            picked = kind
            Haptics.confirm()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onSelect(kind) }
        } label: {
            VStack(spacing: 10) {
                HStack(spacing: 10) {   // 二人の顔（仮の色替え。左＝自分・右＝相方）
                    CharacterFace(spec: FaceCatalog.ore(for: kind), size: 52)
                    CharacterFace(spec: FaceCatalog.taniguchi(for: kind), size: 52)
                }
                .padding(.top, 6)
                Text(kind.cardTitle).font(YoseFont.gothic(17, weight: .heavy))
                Text(kind.cardSub).font(YoseFont.gothic(13, weight: .bold)).foregroundStyle(YoseColor.haiSumi)
            }
            .frame(maxWidth: .infinity, minHeight: 150)
            .overlay(RoundedRectangle(cornerRadius: 2).stroke(YoseColor.shu, lineWidth: picked == kind ? 3 : 0))
        }
        .buttonStyle(YoseButtonStyle(.secondary))
        .accessibilityLabel("\(kind.cardTitle)、\(kind.cardSub)")
        .accessibilityAddTraits(picked == kind ? .isSelected : [])
    }
}
