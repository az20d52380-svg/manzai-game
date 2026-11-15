// ShareCard.swift
// SNS に出せる1枚。優勝・決勝進出・エンディングの画面に「共有」ボタン。
// 寄席看板風のカードを ImageRenderer で画像にして ShareLink で渡す。入れるのはコンビ名・結果・アプリ名だけ（個人情報・％なし）。

import SwiftUI

struct ShareCardView: View {
    let combiName: String
    let headline: String      // 例：「優勝」「決勝進出」「エンディング名」
    var detail: String? = nil // 例：「結成3年目」

    var body: some View {
        VStack(spacing: 26) {
            Text("漫才王になろう").font(.system(size: 34, weight: .heavy, design: .serif)).foregroundStyle(YoseColor.kin)
            VStack(spacing: 22) {
                Text(headline).font(.system(size: 72, weight: .heavy, design: .serif)).foregroundStyle(YoseColor.shu)
                    .minimumScaleFactor(0.4).lineLimit(1)
                Rectangle().fill(YoseColor.sumi).frame(height: 3)
                Text(combiName).font(.system(size: 52, weight: .bold, design: .serif)).foregroundStyle(YoseColor.sumi)
                    .minimumScaleFactor(0.4).lineLimit(2).multilineTextAlignment(.center)
                if let detail { Text(detail).font(.system(size: 30, weight: .bold)).foregroundStyle(YoseColor.haiSumi) }
            }
            .padding(.vertical, 44).padding(.horizontal, 36)
            .frame(maxWidth: .infinity)
            .background(YoseColor.kinari)
            .overlay(Rectangle().stroke(YoseColor.kin, lineWidth: 6))
            .overlay(Rectangle().stroke(YoseColor.sumi, lineWidth: 2).padding(10))
            Text("#漫才王になろう").font(.system(size: 26, weight: .bold)).foregroundStyle(YoseColor.kinari.opacity(0.8))
        }
        .padding(48)
        .frame(width: 720, height: 720)
        .background(LinearGradient(colors: [YoseColor.kuroUrushi, YoseColor.enji], startPoint: .top, endPoint: .bottom))
    }
}

/// 「共有」ボタン。表示時に1枚の画像を作り、ShareLink で渡す。
struct ShareCardButton: View {
    let combiName: String
    let headline: String
    var detail: String? = nil
    @State private var image: Image?

    var body: some View {
        Group {
            if let image {
                ShareLink(item: image, message: Text("漫才王になろう"),
                          preview: SharePreview("\(combiName)　\(headline)", image: image)) {
                    Label("共有", systemImage: "square.and.arrow.up")
                        .font(YoseFont.gothic(14, weight: .heavy))
                }
            } else {
                Color.clear.frame(width: 1, height: 1)
            }
        }
        .task(id: "\(combiName)|\(headline)|\(detail ?? "")") {
            let r = ImageRenderer(content: ShareCardView(combiName: combiName, headline: headline, detail: detail))
            r.scale = 2
            if let ui = r.uiImage { image = Image(uiImage: ui) }
        }
    }
}
