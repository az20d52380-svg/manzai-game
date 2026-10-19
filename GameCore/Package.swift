// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GameCore",
    products: [
        .library(name: "GameCore", targets: ["GameCore"])
    ],
    targets: [
        .target(name: "GameCore", path: "Sources/GameCore"),
        .testTarget(name: "GameCoreTests", dependencies: ["GameCore"], path: "Tests/GameCoreTests",
                    exclude: ["Resources/golden_features.json"])   // #filePath から直接読む＝リソースにしない（未処理ファイルの警告を消す）
    ]
)
