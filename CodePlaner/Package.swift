// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CodingPlan",
    defaultLocalization: "en",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.8.0"),
    ],
    targets: [
        .executableTarget(
            name: "CodingPlan",
            dependencies: ["Alamofire"],
            path: "CodingPlan"
        ),
        .testTarget(
            name: "CodingPlanTests",
            dependencies: ["CodingPlan"],
            path: "Tests/CodingPlanTests"
        ),
    ]
)
