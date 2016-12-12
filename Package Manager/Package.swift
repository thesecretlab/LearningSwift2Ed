// this file is from the Swift Package Manager example project written by Apple as part of the Swift.org open source project
// Copyright Apple and the Swift project authors, licensed under the Apache License v2.0 with Runtime Library Exception
// https://github.com/apple/example-package-dealer

// BEGIN package_manager_setup
import PackageDescription

let package = Package(
    name: "Dealer",
    dependencies: [
        .Package(url:"https://github.com/apple/example-package-deckofplayingcards.git",
                 majorVersion: 3)]
)
// END package_manager_setup
