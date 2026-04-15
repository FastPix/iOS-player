// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FastPixPlayerSDKTest",
    
    platforms: [
        .iOS(.v13)
    ],
    
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "FastPixPlayerSDKTest",
            targets: ["FastPixPlayerSDKTest"]),
    ],
    
    dependencies: [
        // Add the Git URL package dependency here
        .package(url: "https://github.com/FastPix/iOS-data-avplayer-sdk", from: "1.0.6")
    ],
    
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "FastPixPlayerSDKTest",
            dependencies: [
                .product(name: "FastpixVideoDataAVPlayer", package: "iOS-data-avplayer-sdk")  // Link the Git package to your local package
            ]
        ),
        .testTarget(
            name: "FastPixPlayerSDKTestTests",
            dependencies: ["FastPixPlayerSDKTest"]),
    ]
)
