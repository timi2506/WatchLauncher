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
            TabView {
                GeometryReader { proxy in
                    ScrollViewReader { scrollProxy in
                        ScrollView {
                            VStack {
                                Spacer()
                                TextField("Message", text: $message, axis: .vertical)
                                    .autocorrectionDisabled()
                                    .autocapitalization(.none)
                                    .font(.title)
                                    .multilineTextAlignment(.center)
                                    .bold()
                                    .fontDesign(.rounded)
                                Spacer()
                                Button(action: {
                                    manager.send(message)
                                }) {
                                    Text("Send Drop")
                                        .bold()
                                        .frame(maxWidth: .infinity)
                                        .padding(15)
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(message.isEmpty)
                                .padding()
                                Button(action: {
                                    withAnimation() { scrollProxy.scrollTo("Advanced") }
                                }) {
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 25))
                                        .bold()
                                }
                                .padding(.bottom, 50)
                            }
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            VStack {
                                Spacer()
                                VStack(spacing: 50) {
                                    TextField("Google API Key", text: $googleKey)
                                        .autocorrectionDisabled()
                                        .autocapitalization(.none)
                                        .multilineTextAlignment(.center)
                                        .font(.title)
                                        .bold()
                                    Button(action: {
                                        dropAction(.googleAPI, content: googleKey)
                                    }) {
                                        Text("Send Google API Key")
                                            .bold()
                                            .padding(15)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(googleKey.isEmpty)
                                }
                                Spacer()
                                Divider()
                                Spacer()
                                VStack(spacing: 50) {
                                    TextField("Gemini API Key", text: $geminiKey)
                                        .autocorrectionDisabled()
                                        .autocapitalization(.none)
                                        .multilineTextAlignment(.center)
                                        .font(.title)
                                        .bold()
                                    Button(action: {
                                        dropAction(.geminiAPI, content: geminiKey)
                                    }) {
                                        Text("Send Gemini API Key")
                                            .bold()
                                            .padding(15)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(geminiKey.isEmpty)
                                }
                                Spacer()
                            }
                            .padding(.horizontal)
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .id("Advanced")
                        }
                        .scrollIndicators(.never)
                    }
                    .scrollTargetBehavior(.paging)
                }
                aboutApp
            }
            .tabViewStyle(.page)
            .onAppear {
                manager.onMessageReceive = { msg in
                    if msg == "watchLauncher-dropAction/messageReceived://" {
                        let drop = Drop(
                            title: "Watch Received",
                            icon: UIImage(systemName: "checkmark")
                        )
                        Drops.show(drop)
                    } else if msg.hasPrefix("watchLauncher-dropAction/appInfoResponse://") {
                        let appVersion = String(msg.trimmingPrefix("watchLauncher-dropAction/appInfoResponse://"))
                        watchVersion = appVersion
                        fetchingInfo = false
                    } else {
                        received = msg
                        playNotificationSound()
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
    @State var fetchingInfo = true
    @State var watchVersion: String?
    @AppStorage("playDropSound") var playDropSound = false
    
    var aboutApp: some View {
        Form {
            Section("About iOS Companion App") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(String.appVersionString)
                        .foregroundStyle(.secondary)
                }
            }
            Section("About watchOS App") {
                if fetchingInfo {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text("Fetching")
                    }
                }
                HStack {
                    Text("Version")
                    Spacer()
                    Text(watchVersion ?? "Unknown")
                        .foregroundStyle(.secondary)
                }
            }
            Section("Universal Settings") {
                Toggle("Play Drop Sound", isOn: $playDropSound)
            }
        }
        .refreshable {
            requestAppInfo()
        }
        .onAppear {
            requestAppInfo()
        }
        .onChange(of: playDropSound) {
            dropAction(.dropSound, content: playDropSound ? "true" : "false")
        }
    }
    func requestAppInfo() {
        dropAction(.requestAppInfo)
    }
    func dropAction(_ id: DropActionID, content: String = "") {
        let dropContent = "watchLauncher-dropAction/\(id.rawValue)://\(content)"
        manager.send(dropContent)
    }
}

enum DropActionID: String, CaseIterable {
    case googleAPI = "googleKey"
    case geminiAPI = "geminiKey"
    case requestAppInfo = "requestAppInfo"
    case dropSound = "playDropSound"
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

extension String {
    static var appVersionString: String {
        let buildVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        return "\(buildVersion ?? "Unknown")\(buildNumber == nil ? "" : " (\(buildNumber!))")"
    }
}
