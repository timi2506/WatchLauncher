//
//  ContentView.swift
//  WatchLauncher Watch App
//
//  Created by Tim on 07.09.25.
//

import SwiftUI
import AuthenticationServices

struct ContentView: View {
    @State var selectedTab = 0
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

#Preview {
    ContentView()
}

extension View {
    func navStacked() -> some View {
        NavigationStack { self }
    }
}
