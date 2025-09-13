//
//  WatchLauncherApp.swift
//  WatchLauncher Watch App
//
//  Created by Tim on 07.09.25.
//

import SwiftUI

@main
struct WatchLauncher_Watch_AppApp: App {
    @State var dropItem: DropItem?
    @StateObject var dropManager: DropManager = DropManager.shared
    @AppStorage("GeminiKey") var geminiKey: String = ""
    @State var errorItem: Error?
    @State var errorAlert = false
    @State var addBookmarkItem: DropItem?
    @State var selectedTab = 0
    var body: some Scene {
        WindowGroup {
            ContentView(selectedTab: $selectedTab)
                .onAppear {
                    dropManager.onMessageReceive = { msg in
                        do {
                            if try !tryHandleDrop(msg) {
                                dropItem = .init(message: msg)
                                playNotificationSound()
                            }
                        } catch {
                            errorItem = error
                            errorAlert = true
                        }
                        dropManager.send("watchLauncher-dropAction/messageReceived://")
                    }
                }
                .alert("Error", isPresented: $errorAlert, presenting: errorItem) { _ in
                    Button("OK", role: .cancel) {}
                } message: { error in
                    let base = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    if let nsError = error as NSError? {
                        let reason = nsError.userInfo[NSLocalizedFailureReasonErrorKey] as? String
                        let suggestion = nsError.userInfo[NSLocalizedRecoverySuggestionErrorKey] as? String
                        let combined = [
                            base,
                            reason.flatMap { "\n\n\($0)" },
                            suggestion.flatMap { "\n\n\($0)" }
                        ].compactMap { $0 }.joined()
                        Text(combined)
                    } else {
                        Text(base)
                    }
                }
                .sheet(item: $dropItem) { item in
                    Form {
                        Section("Message: \(item.message)") {
                            OpenWebsiteButton(url: item.message.toURL()) {
                                HStack {
                                    Image(systemName: "safari")
                                        .frame(width: 25)
                                    Text("Open in Browser")
                                }
                            }
                            Button(action: {
                                let savedItem = item
                                dropItem = nil
                                addBookmarkItem = savedItem
                            }) {
                                HStack {
                                    Image(systemName: "bookmark")
                                        .frame(width: 25)
                                    Text("Add to Bookmarks")
                                }
                            }
                            Button(action: {
                                let theItem = item
                                dropItem = nil
                                selectedTab = 2
                                Task {
                                    try await GeminiManager.shared.sendMessage(theItem.message)
                                }
                            }) {
                                HStack {
                                    Image(systemName: "brain")
                                        .frame(width: 25)
                                    Text("Ask Gemini")
                                }
                            }
                        }
                        Section("Advanced Options") {
                            Button(action: {
                                geminiKey = item.message
                                dropItem = nil
                            }) {
                                HStack {
                                    Image(systemName: "bubble")
                                        .frame(width: 25)
                                    Text("Use as Gemini API Key")
                                }
                            }
                            Button(action: {
                                SearchManager.shared.apiKey = item.message
                                dropItem = nil
                            }) {
                                HStack {
                                    Image(systemName: "magnifyingglass")
                                        .frame(width: 25)
                                    Text("Use as Google API Key")
                                }
                            }
                        }
                    }
                    .navigationTitle("Drop Received")
                    .navigationBarTitleDisplayMode(.inline)
                        .navStacked()
                }
                .sheet(item: $addBookmarkItem) { item in
                    AddWebsiteView(url: item.message)
                }
        }
    }
    func tryHandleDrop(_ message: String) throws -> Bool {
        let errorHandlingInternalDropError = NSError(
            domain: "com.timi2506.WatchLauncher",
            code: 1001,
            userInfo: [
                NSLocalizedDescriptionKey: "Error Handling Drop.",
                NSLocalizedFailureReasonErrorKey: "Invalid Drop Content",
                NSLocalizedRecoverySuggestionErrorKey: "Please check your Drop and make sure its not empty"
            ]
        )
        
        if message.hasPrefix("watchLauncher-dropAction/googleKey://") {
            let apiKey = String(message.trimmingPrefix("watchLauncher-dropAction/googleKey://"))
            guard !apiKey.isEmpty else { throw errorHandlingInternalDropError }
            SearchManager.shared.apiKey = apiKey
            playNotificationSound()
        } else if message.hasPrefix("watchLauncher-dropAction/geminiKey://") {
            let apiKey = String(message.trimmingPrefix("watchLauncher-dropAction/geminiKey://"))
            guard !apiKey.isEmpty else { throw errorHandlingInternalDropError }
            geminiKey = apiKey
            playNotificationSound()
        } else if message.hasPrefix("watchLauncher-dropAction/playDropSound://") {
            let bool = String(message.trimmingPrefix("watchLauncher-dropAction/playDropSound://")).contains("true")
            UserDefaults.standard.set(bool, forKey: "playDropSound")
        } else if message == "watchLauncher-dropAction/requestAppInfo://" {
            dropManager.send("watchLauncher-dropAction/appInfoResponse://\(String.appVersionString)")
        } else {
            return false
        }
        return true
    }
}

struct DropItem: Identifiable {
    var id = UUID()
    var message: String
}

extension String {
    static var appVersionString: String {
        let buildVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        return "\(buildVersion ?? "Unknown")\(buildNumber == nil ? "" : " (\(buildNumber!))")"
    }
}
