//
//  ContentView.swift
//  WatchLauncher iOS
//
//  Created by Tim on 13.09.25.
//

import SwiftUI
import Drops

struct ContentView: View {
    @StateObject var manager = DropManager.shared
    @State var message = ""
    @State var received: String?
    @State var geminiKey = ""
    @State var googleKey = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Custom") {
                    TextField("Message", text: $message, axis: .vertical)
                        .autocorrectionDisabled()
                        .autocapitalization(.none)
                    Button("Send Drop") {
                        manager.send(message)
                    }
                        .disabled(message.isEmpty)
                }
                Section("API Keys") {
                    TextField("Gemini API Key", text: $geminiKey)
                        .autocorrectionDisabled()
                        .autocapitalization(.none)
                    Button("Send") {
                        dropAction(.geminiAPI, content: geminiKey)
                    }
                    .disabled(geminiKey.isEmpty)
                    TextField("Google API Key", text: $googleKey)
                        .autocorrectionDisabled()
                        .autocapitalization(.none)
                    Button("Send") {
                        dropAction(.googleAPI, content: googleKey)
                    }
                    .disabled(googleKey.isEmpty)
                }
            }
            .onAppear {
                manager.onMessageReceive = { msg in
                    if msg == "watchLauncher-dropAction/messageReceived://" {
                        let drop = Drop(
                            title: "Watch Received",
                            icon: UIImage(systemName: "checkmark")
                        )
                        Drops.show(drop)
                    } else {
                        received = msg
                    }
                }
            }
            .alert("Drop Received", isPresented: Binding(get: {
                received != nil
            }, set: { bool in
                if !bool { received = nil }
            })) {
                Button("Open in Browser") {
                    if let text = received, let url = text.toURL() {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel") {
                    received = nil
                }
            } message: {
                Text(received ?? "UNKNOWN DROP CONTENT")
            }
            .navigationTitle("WatchLauncher Drop")
        }
    }
    func dropAction(_ id: DropActionID, content: String) {
        let dropContent = "watchLauncher-dropAction/\(id.rawValue)://\(content)"
        manager.send(dropContent)
    }
}

enum DropActionID: String, CaseIterable {
    case googleAPI = "googleKey"
    case geminiAPI = "geminiKey"
}

#Preview {
    ContentView()
}

extension String {
    func toURL() -> URL? {
        guard !self.isEmpty else { return nil }
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }
        
        if trimmed.contains(".") {
            let withScheme = "https://\(trimmed)"
            return URL(string: withScheme)
        }
        
        let query = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let searchURL = "https://bing.com/search?q=\(query)"
        return URL(string: searchURL)
    }
}
