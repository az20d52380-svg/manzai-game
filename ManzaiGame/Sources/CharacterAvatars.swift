// CharacterAvatars.swift
// 手続き生成の顔グラ（View層のみ・golden非干渉）。パワプロ・サクセスの文法＝会話や採点で
// 「誰が言っているか／誰が点を出したか」を顔で見せる。イラスト導入までの顔写真の席。
// 髪型・髪色・眼鏡・髭・襟色の組み合わせで 俺/谷口/審査員7人 を描き分ける。数値は全て【仮】。

import SwiftUI

// MARK: 顔のパーツ定義

enum HairStyle {
    case short      // 短髪（上半分ドーム）
    case long       // ロング（ドーム＋両サイド垂れ）
    case bun        // シニヨン（ドーム＋頭頂のお団子）
    case allback    // オールバック（薄い上弧）
    case bowl       // マッシュ（深いドーム＝谷口）
}

struct FaceSpec {
    var skin = Color(hex: 0xFFDFC2)
    var hair: HairStyle = .short
    var hairColor = Color(hex: 0x3A3350)
    var glasses = false
    var beard = false
    var collar = Color(hex: 0x8E86A0)   // 襟＝服の色（審査員は重視軸の色）
}

// MARK: 顔グラ本体

/// 丸顔＋髪＋目（点2つ）＋任意の眼鏡/髭＋襟。size 一辺の正方形に収まる。
struct CharacterFace: View {
    let spec: FaceSpec
    var size: CGFloat = 56

    var body: some View {
        let faceR = size * 0.78
        ZStack {
            // 襟（顔の下の服・台形っぽく）
            UnevenRoundedRectangle(topLeadingRadius: size * 0.20, bottomLeadingRadius: size * 0.06,
                                   bottomTrailingRadius: size * 0.06, topTrailingRadius: size * 0.20)
                .fill(spec.collar)
                .frame(width: size * 0.72, height: size * 0.30)
                .offset(y: size * 0.38)
            // 顔
            Circle().fill(spec.skin)
                .frame(width: faceR, height: faceR)
                .offset(y: -size * 0.04)
                .overlay {
                    // 目（左右の点。顔グラの生命線＝これで「人」になる）
                    HStack(spacing: faceR * 0.30) {
                        Circle().fill(Color(hex: 0x2C2740)).frame(width: faceR * 0.085, height: faceR * 0.085)
                        Circle().fill(Color(hex: 0x2C2740)).frame(width: faceR * 0.085, height: faceR * 0.085)
                    }
                    .offset(y: faceR * 0.04)
                }
                .overlay { hairView(faceR: faceR).offset(y: -size * 0.04) }
                .overlay {
                    if spec.glasses {
                        HStack(spacing: faceR * 0.10) {
                            Circle().stroke(Color(hex: 0x2C2740), lineWidth: 1.6)
                                .frame(width: faceR * 0.30, height: faceR * 0.30)
                            Circle().stroke(Color(hex: 0x2C2740), lineWidth: 1.6)
                                .frame(width: faceR * 0.30, height: faceR * 0.30)
                        }
                        .overlay(Rectangle().fill(Color(hex: 0x2C2740)).frame(width: faceR * 0.12, height: 1.6))
                        .offset(y: faceR * 0.02)
                    }
                    if spec.beard {
                        // 顎髭（下弧）
                        Circle().trim(from: 0.08, to: 0.42)
                            .stroke(spec.hairColor, style: StrokeStyle(lineWidth: faceR * 0.14, lineCap: .round))
                            .frame(width: faceR * 0.86, height: faceR * 0.86)
                            .offset(y: -size * 0.02)
                    }
                }
        }
        .frame(width: size, height: size)
        .background(Circle().fill(.white).frame(width: size * 1.0, height: size * 1.0))
        .clipShape(Circle())
    }

    @ViewBuilder private func hairView(faceR: CGFloat) -> some View {
        switch spec.hair {
        case .short:
            Circle().fill(spec.hairColor)
                .mask(alignment: .top) { Rectangle().frame(height: faceR * 0.42) }
        case .bowl:
            Circle().fill(spec.hairColor)
                .mask(alignment: .top) { Rectangle().frame(height: faceR * 0.52) }
        case .long:
            ZStack {
                Circle().fill(spec.hairColor)
                    .mask(alignment: .top) { Rectangle().frame(height: faceR * 0.45) }
                HStack {
                    Capsule().fill(spec.hairColor).frame(width: faceR * 0.16, height: faceR * 0.72)
                    Spacer()
                    Capsule().fill(spec.hairColor).frame(width: faceR * 0.16, height: faceR * 0.72)
                }
                .frame(width: faceR * 1.02)
                .offset(y: faceR * 0.08)
            }
        case .bun:
            ZStack(alignment: .top) {
                Circle().fill(spec.hairColor)
                    .mask(alignment: .top) { Rectangle().frame(height: faceR * 0.40) }
                Circle().fill(spec.hairColor)
                    .frame(width: faceR * 0.30, height: faceR * 0.30)
                    .offset(y: -faceR * 0.12)
            }
        case .allback:
            Circle().fill(spec.hairColor)
                .mask(alignment: .top) { Rectangle().frame(height: faceR * 0.26) }
        }
    }
}

// MARK: プリセット（俺・谷口・審査員7人）

enum FaceCatalog {
    /// 俺（ツッコミ・青）
    static let ore = FaceSpec(hair: .short, hairColor: Color(hex: 0x40394F), collar: Color(hex: 0x4A7BE8))
    /// 谷口（ボケ・朱・マッシュ）
    static let taniguchi = FaceSpec(hair: .bowl, hairColor: Color(hex: 0x2E2838), collar: Color(hex: 0xF0533E))

    /// 審査員（judge_design の7人・重視軸の色を襟に）
    static func judge(_ name: String) -> FaceSpec {
        switch name {
        case "音羽 ルリ":     return FaceSpec(hair: .long, hairColor: Color(hex: 0x6E4358), collar: Theme.cChara)
        case "白波 剛":       return FaceSpec(hair: .short, hairColor: Color(hex: 0x23202E), collar: Theme.cExpr)
        case "卯月 走太":     return FaceSpec(hair: .short, hairColor: Color(hex: 0x7A5638), collar: Theme.cIdea)
        case "花園 千代":     return FaceSpec(hair: .bun, hairColor: Color(hex: 0xD8D4DC), collar: Theme.verm)
        case "目白 慧":       return FaceSpec(hair: .short, hairColor: Color(hex: 0x2C2740), glasses: true, collar: Theme.cIdea)
        case "神楽坂 とんぼ": return FaceSpec(hair: .long, hairColor: Color(hex: 0xC8A44E), collar: Theme.cMental)
        case "天堂寺 銀郎":   return FaceSpec(hair: .allback, hairColor: Color(hex: 0xC8C4CE), beard: true, collar: Theme.cSense)
        default:              return FaceSpec()
        }
    }

    /// 会話の話者名→顔（俺/谷口以外は汎用）
    static func speaker(_ name: String?) -> FaceSpec {
        switch name {
        case "谷口": return taniguchi
        case nil, "俺": return ore
        default: return FaceSpec()
        }
    }
}
