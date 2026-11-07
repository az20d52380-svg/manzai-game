// GachaRatesView.swift
// 衣装ガチャの提供割合・ルールのページ。割合は GachaCatalog の表から生成する（手で書き写さない＝表示と実際がずれない）。
// 文面の元：docs/release/gacha_rates_page.md。数値はすべて【仮】。
import SwiftUI

struct GachaRatesView: View {
    let onClose: () -> Void

    var body: some View {
        ZStack {
            YoseColor.kinari.ignoresSafeArea()
            VStack(spacing: 0) {
                YoseHeaderBar(title: "提供割合", closeAction: onClose)
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("衣装ガチャ 提供割合・ルール（第\(GachaCatalog.rateVersion)版）").font(YoseFont.gothic(15, weight: .heavy))
                        block("衣装ガチャとは", ["舞台の二人の衣装が手に入るガチャです。衣装は見た目だけが変わり、ゲームの強さ・成績・勝敗には一切影響しません。"])
                        block("回し方と料金", [
                            "1回 \(GachaCatalog.price1)円（税込）／10回 \(GachaCatalog.price10)円（税込）【仮】",
                            "無料：ログインボーナスの札を\(GachaCatalog.loginGoal)枚ためると、1回分と交換できます。",
                            "有料の券は買った場面でそのまま回します。10回は、1回を10回回すのと同じ割合です（確定枠はありません）。",
                            "初回：はじめての1回だけ、特別の衣装が必ず出ます【仮】。",
                        ])
                        rateTables
                        block("同じ衣装が出たとき（かけら）", OutfitRarity.allCases.map { "\($0.label)：かけら\($0.shardGain)個（交換に\($0.shardCost)個）" }
                              + ["かけらは、持っていない衣装と交換できます【仮】。"])
                        block("天井", [
                            "ガチャを1回回すごとに天井ポイントが1たまります。\(GachaCatalog.pityGoal)ポイントで、好きな衣装を1着えらべます【仮】。",
                            "無料で回した分もかぞえます。すでに持っている衣装は交換先にえらべません。",
                            "\(GachaCatalog.pityGoal)回を有料で回した場合の合計は、おおよそ\(GachaCatalog.pityGoal * GachaCatalog.price1)円です。",
                        ])
                        block("ご注意", [
                            "「黒紋付」はガチャの対象外で、「広告カット」の購入に付きます。",
                            "すべての衣装をそろえても特別な特典はありません。",
                            "衣装・かけら・ポイントは iCloud に保存され、機種変更でも引き継がれます（iCloud をオフにしている場合は端末内のみ）。",
                            "購入した券は払い戻しできません（法令および Apple のルールによる場合を除く）。",
                            "お子さまの課金は、iOS のスクリーンタイムや「承認と購入のリクエスト」で制限できます。",
                            "提供割合を変えるときは、変更の前にこのページでお知らせします。",
                        ])
                    }
                    .padding(.horizontal, YoseMetrics.screenMargin).padding(.vertical, 12)
                }
            }
        }
    }

    private func block(_ title: String, _ lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(YoseFont.gothic(14, weight: .heavy)).foregroundStyle(YoseColor.sumi)
            ForEach(lines, id: \.self) { Text($0).font(YoseFont.gothic(12, weight: .bold)).foregroundStyle(YoseColor.sumi).fixedSize(horizontal: false, vertical: true) }
        }
        .padding(YoseMetrics.padH).frame(maxWidth: .infinity, alignment: .leading).yoseKifuda()
    }

    private var rateTables: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("提供割合").font(YoseFont.gothic(14, weight: .heavy))
            Text("レアリティ別").font(YoseFont.gothic(12, weight: .heavy))
            ForEach(Array(OutfitRarity.allCases.reversed()), id: \.self) { r in
                row(r.label, GachaCatalog.display(Double(r.tierPercent)), "\(GachaCatalog.items(r).count)着")
            }
            Text("衣装別").font(YoseFont.gothic(12, weight: .heavy)).padding(.top, 6)
            ForEach(Array(OutfitRarity.allCases.reversed()), id: \.self) { r in
                ForEach(GachaCatalog.items(r), id: \.self) { o in
                    row("\(r.label)　\(o.displayName)", GachaCatalog.display(GachaCatalog.percent(of: o)), "")
                }
            }
            Text("小数第3位以下は切り捨てて表示しています。割合は1回ごとに独立で、前の結果や回数で変わりません（天井の交換を除く）。")
                .font(YoseFont.gothic(11, weight: .bold)).foregroundStyle(YoseColor.haiSumi)
        }
        .padding(YoseMetrics.padH).frame(maxWidth: .infinity, alignment: .leading).yoseKifuda()
    }

    private func row(_ a: String, _ b: String, _ c: String) -> some View {
        HStack {
            Text(a).font(YoseFont.gothic(12, weight: .bold))
            Spacer()
            Text(b).font(YoseFont.number(13, weight: .heavy))
            if !c.isEmpty { Text(c).font(YoseFont.gothic(11, weight: .bold)).foregroundStyle(YoseColor.haiSumi) }
        }
        .foregroundStyle(YoseColor.sumi)
    }
}
