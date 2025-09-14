//
//  WatchLauncher_iOSApp.swift
//  WatchLauncher iOS
//
//  Created by Tim on 13.09.25.
//

import SwiftUI

@main
struct WatchLauncher_iOSApp: App {
    init() {
        _ = GlobalKeyboardAccessory.shared
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
