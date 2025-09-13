import SwiftUI
import Combine

struct GeminiView: View {
    @StateObject var manager = GeminiManager.shared
    @State var isResponding = false
    @State var error: String?
@State var showKey = false
    @AppStorage("GeminiKey") var apiKey: String = ""
    let watchScreen = WKInterfaceDevice.current().screenBounds
@State var showKeyAlert = false
    var body: some View {
        TabView {
            VStack {
                ScrollViewReader { proxy in
                    ScrollView {
                        if manager.messages.isEmpty {
                            ContentUnavailableView("No Messages", systemImage: "bubble", description: Text("Try Sending one"))
                        }
                        ForEach(manager.messages) { msg in
                            MessageBubble(message: msg)
                        }
                        Group {
                            if isResponding {
                                HStack {
                                    ProgressView().controlSize(.small)
                                        .frame(width: 25)
                                    Text("Responding")
                                        .font(.caption)
                                }
                            } else {
                                TextFieldLink {
                                    Label("Message", systemImage: "paperplane")
                                } onSubmit: { msg in
                                    Task {
                                        isResponding = true
                                        do {
                                            try await manager.sendMessage(msg)
                                        } catch {
                                            self.error = error.localizedDescription
                                        }
                                        isResponding = false
                                        withAnimation() {
                                            proxy.scrollTo("Bottom")
                                        }
                                    }
                                }
                                .buttonStyle(.bordered)
                                .tint(.blue)
                                .grayDisabled(apiKey.isEmpty)
                                .simultaneousGesture(
                                    TapGesture()
                                        .onEnded { _ in
                                            if apiKey.isEmpty {
                                                showKeyAlert = true
                                            }
                                        }
                                )
                                .alert("API Key Required", isPresented: $showKeyAlert, actions: {
                                    Button("OK") { showKeyAlert = false }
                                }, message: { Text("Please add one in Settings") })
                            }
                        }
                        .id("Bottom")
                    }
                }
            }
            .navigationTitle("Gemini")
            .navigationBarTitleDisplayMode(.inline)
            .navStacked()
            .alert("An Error occured", isPresented: Binding(get: {
                return error != nil
            }, set: { bool in
                if !bool { error = nil }
            })) {
                Button("OK") { error = nil }
            } message: {
                Text(error ?? "Unknown Error")
            }
            Form {
                Section {
                    if showKey {
                        TextField("API Key", text: $apiKey)
                    } else {
                        SecureField("API Key", text: $apiKey)
                    }
                    Toggle("Show API Key", isOn: $showKey)
                    NavigationLink("Get Key") {
                        List {
                            Section {
                                OpenWebsiteButton(url: "https://github.com/timi2506/wsf-md-guides/blob/1fcab31cea13cb0d7156a50d013e46d4d265404b/README.md".toURL()) {
                                    Label("On Watch", systemImage: "applewatch")
                                }
                                NavigationLink(destination: {
                                    Image("Gemini-API-Key-QR")
                                        .resizable()
                                        .scaledToFit()
                                        .cornerRadius(5)
                                        .frame(width: watchScreen.width - 25, height: watchScreen.height - 25)
                                }) {
                                    Label("On iPhone", systemImage: "iphone")
                                }
                            } footer: {
                                Text("Choose where to open the \"Get API Key\" Site")
                            }
                        }
                    }
                }
                Section {
                    Button("Clear Messages") {
                        confirmClear = true
                    }
                    .disabled(manager.messages.isEmpty)
                    .confirmationDialog("Are you sure you want to Clear All Messages?", isPresented: $confirmClear) {
                        Button("Clear", role: .destructive) { manager.messages = [] }
                        Button("Cancel") { confirmClear = false }
                    } message: {
                        Text("This Action cannot be undone")
                    }
                    Button("Save Messages") { saveMessages = true }
                        .disabled(manager.messages.isEmpty)
                    NavigationLink("Restore Messages") {
                        RestoreMessagesView()
                    }
                }
            }
            .navStacked()
            .sheet(isPresented: $saveMessages) {
                SaveMessagesView()
            }
        }
        .tabViewStyle(.verticalPage(transitionStyle: .identity))
    }
    @State var confirmClear = false
    @State var saveMessages = false
}

struct RestoreMessagesView: View {
    @StateObject var manager = BackupManager.shared
    @StateObject var geminiManager = GeminiManager.shared

    @State var restoreBackup: Backup?
    var body: some View {
        List {
            if manager.backups.isEmpty {
                ContentUnavailableView("No Backups yet", systemImage: "cloud", description: Text("Try creating one"))
            }
            ForEach(manager.backups) { backup in
                VStack(alignment: .leading) {
                    Text(backup.name)
                    Text("\(backup.messages.count) Messages")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .onTapGesture {
                    restoreBackup = backup
                }
            }
            .onDelete { offsets in
                manager.backups.remove(atOffsets: offsets)
            }
            .confirmationDialog("Are you sure you want to Restore this Backup?", isPresented: Binding(get: {
                restoreBackup != nil
            }, set: { bool in
                if !bool { restoreBackup = nil }
            })) {
                Button("Restore", role: .destructive) {
                    geminiManager.messages = restoreBackup!.messages
                }
                Button("Cancel") {
                    restoreBackup = nil
                }
            } message: {
                Text("This will replace the current Messages with the Messages found in this Backup")
            }


        }
    }
}

struct SaveMessagesView: View {
    @StateObject var manager = GeminiManager.shared
    @StateObject var backupsManager = BackupManager.shared

    @Environment(\.dismiss) var dismiss
    @State var chatName = ""
    @State var includeDate = false
    var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }
    var body: some View {
        Form {
            Section {
                TextField("Chat Name", text: $chatName)
            } footer: {
                Text("The Name you want to call the current Chat")
            }
            Section {
                Toggle("Include Date", isOn: $includeDate)
            } footer: {
                Text("Whether or not to include the current Date in the Chat Name\n\nExample: \"Chat - \(Date(), formatter: dateFormatter)\"")
            }
        }
        .navigationTitle("Save Messages")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save", systemImage: "checkmark") {
                    backupsManager.addBackup(.init(name: makeName(), messages: manager.messages))
                    dismiss()
                }
                .grayDisabled(chatName.isEmpty)
            }
        }
        .navStacked()
    }
    func makeName() -> String {
        if includeDate {
            return "\(chatName) - \(dateFormatter.string(from: Date()))"
        } else {
            return chatName
        }
    }
}

import MarkdownUI

struct MessageBubble: View {
    var message: Message
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            Markdown(message.message)
                .padding(7.5)
                .padding(.leading, message.isUser ? 2.5 : 10)
                .padding(.trailing, message.isUser ? 10 : 2.5)
                .background(
                    BubbleShape(rightAligned: message.isUser)
                        .foregroundStyle(message.isUser ? .blue : .gray.opacity(0.25))
                )
            if !message.isUser {
                Spacer()
            }
        }
    }
}

struct Message: Codable, Identifiable {
    var id = UUID()
    var isUser: Bool
    var message: String
    var sentAt: Date = Date()
}

struct GeminiRequestBody: Codable {
    init(messages: [Message]) {
        self.contents = messages
            .sorted(by: { $0.sentAt < $1.sentAt })
            .map({ .init(role: $0.isUser ? "user" : "model", parts: [.init(text: $0.message)]) })
    }
    var contents: [Contents]
    struct Contents: Codable {
        var role: String
        var parts: [Parts]
    }
    struct Parts: Codable {
        var text: String
    }
}

struct GeminiResponseBody: Codable {
    var candidates: [Candidate]
    var usageMetadata: UsageMetadata?
    var modelVersion: String?
    var responseId: String?
    
    struct Candidate: Codable {
        var content: Content
        var finishReason: String?
        var index: Int?
    }
    
    struct Content: Codable {
        var parts: [Part]
        var role: String
    }
    
    struct Part: Codable {
        var text: String?
    }
    
    struct UsageMetadata: Codable {
        var promptTokensDetails: [PromptTokensDetails]?
        var totalTokenCount: Int?
        var promptTokenCount: Int?
        var thoughtsTokenCount: Int?
        var candidatesTokenCount: Int?
    }
    
    struct PromptTokensDetails: Codable {
        var tokenCount: Int?
        var modality: String?
    }
}

struct GeminiAPIError: Codable {
    struct ErrorDetail: Codable {
        var code: Int
        var message: String
        var status: String
    }
    var error: ErrorDetail
}

class GeminiManager: ObservableObject {
    static let shared = GeminiManager()
    init() {
        let decoder = JSONDecoder()
        if let data = UserDefaults.standard.data(forKey: "geminiMessages"), let existing = try? decoder.decode([Message].self, from: data) {
            self.messages = existing
        } else {
            self.messages = []
        }
    }
    @Published var messages: [Message]
    @AppStorage("GeminiKey") var apiKey: String = ""
    func sendMessage(_ message: String) async throws {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(apiKey)") else { throw URLError(.unknown) }
        messages.append(.init(isUser: true, message: message))
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let content = GeminiRequestBody(messages: messages)
        let encoder = JSONEncoder()
        let body = try encoder.encode(content)
        request.httpBody = body
        let (data, _) = try await URLSession.shared.data(for: request)
        if let jsonString = String(data: data, encoding: .utf8) {
            print("Raw response:\n\(jsonString)")
        }
        let decoder = JSONDecoder()
        do {
            let response = try decoder.decode(GeminiResponseBody.self, from: data)
            if let reply = response.candidates.first?.content.parts.first?.text {
                messages.append(.init(isUser: false, message: reply))
            } else {
                throw URLError(.badServerResponse)
            }
        } catch {
            if let apiError = try? decoder.decode(GeminiAPIError.self, from: data) {
                throw NSError(domain: "GeminiAPI", code: apiError.error.code, userInfo: [NSLocalizedDescriptionKey: apiError.error.message])
            }
            throw error
        }

    }
    func save() {
        let encoder = JSONEncoder()
        let data = try? encoder.encode(messages)
        UserDefaults.standard.set(data, forKey: "geminiMessages")
    }
}

#Preview {
    GeminiView()
}

struct Backup: Codable, Identifiable {
    var id = UUID()
    var name: String
    var messages: [Message]
}

class BackupManager: ObservableObject {
    @Published var backups: [Backup] = []
    
    private var directoryURL: URL
    private var cancellables = Set<AnyCancellable>()
    
    static let shared = BackupManager()
    init() {
        self.directoryURL = BackupManager.fallbackBackupsDirectory()
        loadBackups()
        
        // Observe changes to backups array
        $backups
            .sink { [weak self] newBackups in
                self?.syncBackupsWithDisk(newBackups)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func addBackup(_ backup: Backup) {
        do {
            let fileURL = directoryURL.appendingPathComponent("\(backup.id).json")
            let data = try JSONEncoder().encode(backup)
            try data.write(to: fileURL, options: .atomic)
            
            if !backups.contains(where: { $0.id == backup.id }) {
                backups.append(backup)
            }
        } catch {
            print("⚠️ Failed to save backup: \(error)")
        }
    }
    
    func removeBackup(_ backup: Backup) {
        backups.removeAll { $0.id == backup.id }
        let fileURL = directoryURL.appendingPathComponent("\(backup.id).json")
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    // MARK: - Private Methods
    
    private func loadBackups() {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
            let jsonFiles = files.filter { $0.pathExtension == "json" }
            
            var loaded: [Backup] = []
            for file in jsonFiles {
                if let data = try? Data(contentsOf: file),
                   let backup = try? JSONDecoder().decode(Backup.self, from: data) {
                    loaded.append(backup)
                }
            }
            backups = loaded
        } catch {
            print("⚠️ Failed to load backups: \(error)")
        }
    }
    
    private func syncBackupsWithDisk(_ currentBackups: [Backup]) {
        do {
            let existingFiles = try FileManager.default.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
            let backupIDs = Set(currentBackups.map { $0.id })
            
            // Remove files not present in array
            for file in existingFiles where file.pathExtension == "json" {
                if let uuid = UUID(uuidString: file.deletingPathExtension().lastPathComponent),
                   !backupIDs.contains(uuid) {
                    try? FileManager.default.removeItem(at: file)
                }
            }
        } catch {
            print("⚠️ Failed to sync backups: \(error)")
        }
    }
    
    // MARK: - Fallback Directory
    
    private static func fallbackBackupsDirectory() -> URL {
        let fileManager = FileManager.default
        
        // 1. Application Support
        if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let appDir = appSupport.appendingPathComponent(Bundle.main.bundleIdentifier ?? "MyApp", isDirectory: true)
            let backupsDir = appDir.appendingPathComponent("Backups", isDirectory: true)
            do {
                try fileManager.createDirectory(at: backupsDir, withIntermediateDirectories: true)
                return backupsDir
            } catch {
                print("⚠️ Failed to create Application Support directory: \(error)")
            }
        }
        
        // 2. Documents fallback
        if let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let backupsDir = documents.appendingPathComponent("Backups", isDirectory: true)
            try? fileManager.createDirectory(at: backupsDir, withIntermediateDirectories: true)
            return backupsDir
        }
        
        // 3. Temporary fallback
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("Backups", isDirectory: true)
        try? fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }
}
