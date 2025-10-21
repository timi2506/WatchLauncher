//
//  ContentView.swift
//  WatchLauncher Watch App
//
//  Created by Tim on 07.09.25.
//

import SwiftUI
import AuthenticationServices

struct ContentView: View {
    @Binding var selectedTab: Int
    var body: some View {
        TabView(selection: $selectedTab) {
            GoogleSearchView { urlString in
                openWebsite(url: urlString.toURL())
            }
                .tag(0)
            BrowserView()
                .tag(1)
            GeminiView()
                .tag(2)
        }
        .tabViewStyle(.page)
        .onOpenURL { url in
            if url.absoluteString.hasPrefix("watchLauncher-openTab://") {
                switch url.absoluteString.trimmingPrefix("watchLauncher-openTab://") {
                    case "0": selectedTab = 0
                    case "1": selectedTab = 1
                    case "2": selectedTab = 2
                    default: break
                }
            }
        }
    }
    @State var session: ASWebAuthenticationSession?
    @AppStorage("privateMode") var privateMode = false

    func openWebsite(url: URL?, completion: (() -> Void)? = nil) {
        guard let url else { return }
        session = ASWebAuthenticationSession(url: url, callbackURLScheme: "", completionHandler: { _, _ in
            completion?()
        })
        session?.prefersEphemeralWebBrowserSession = privateMode
        session?.start()
    }
}

extension View {
    func navStacked() -> some View {
        NavigationStack { self }
    }
}
