import SwiftUI
import AuthenticationServices
import Combine
import FaviconFinder

struct BrowserView: View {
    @State var searchText: String = ""
    @State var addWebsiteSheet = false
    @State var bookmarks = false
    @State var recommendations = false
    @AppStorage("privateMode") var privateMode = false
    @AppStorage("useFavicons") var useFavicons = true
    @StateObject var manager = WebsitesManager.shared
    @Environment(\.dismiss) var dismiss
    @State var bookmarkButtonDialog = false
    @State var addWebsiteItem: String?
    var body: some View {
        TabView {
            VStack {
                Spacer()
                TextField("URL or Bing Search", text: $searchText)
                    .padding(.top)
                Spacer()
                HStack {
                    OpenWebsiteButton(url: searchText.toURL(), label: {
                        Label("Open Website", systemImage: "arrow.up.forward.app")
                    })
                    .labelStyle(.iconOnly)
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: 15))
                    .tint(.blue)
                    .grayDisabled(searchText.isEmpty || searchText.toURL() == nil)
                    Button("Bookmarks", systemImage: "bookmark") {
                        if (searchText.isEmpty || searchText.toURL() == nil) {
                            bookmarks = true
                        } else {
                            bookmarkButtonDialog = true
                        }
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: 15))
                    .tint(.orange)
                    .confirmationDialog("Choose what to do", isPresented: $bookmarkButtonDialog) {
                        Button("Add URL to Bookmarks") {
                            bookmarkButtonDialog = false
                            addWebsiteItem = searchText
                            addWebsiteSheet = true
                        }
                        Button("Open Bookmarks") {
                            bookmarkButtonDialog = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                bookmarks = true
                            }
                        }
                    }
                    Button("Recommendations", systemImage: "star") {
                        recommendations.toggle()
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: 15))
                    .tint(.yellow)
                }
                Toggle("Private", systemImage: privateMode ? "eyeglasses" : "eyeglasses.slash", isOn: $privateMode)
                    .toggleStyle(.button)
                    .buttonBorderShape(.roundedRectangle(radius: 15))
                    .tint(.red)
            }
            .navigationTitle("Browser")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $addWebsiteSheet) {
                AddWebsiteView(url: addWebsiteItem ?? "")
            }
            .fullScreenCover(isPresented: $bookmarks) {
                if manager.websites.isEmpty {
                    VStack {
                        Text("No Saved Websites")
                            .bold()
                        Button("Save Website", systemImage: "plus") { addWebsiteSheet.toggle() }
                    }
                } else {
                    List {
                        ForEach(manager.websites) { website in
                            BookmarkItemView(site: website)
                        }
                        .onDelete { offsets in
                            manager.websites.remove(atOffsets: offsets)
                        }
                    }
                    .listStyle(.carousel)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Save Website", systemImage: "plus") { addWebsiteSheet.toggle() }
                                .labelStyle(.iconOnly)
                        }
                    }
                    .navigationTitle("Saved")
                }
            }
            .fullScreenCover(isPresented: $recommendations) {
                RecommendationsView()
            }
            .navStacked()
            Form {
                Section {
                    Toggle("Use Favicons", isOn: $useFavicons)
                } footer: {
                    Text("Whether or not to download and show Favicons in the Bookmarks Manager")
                }
            }
        }
        .tabViewStyle(.verticalPage(transitionStyle: .identity))
        .tabItem {
            Label("Browser", systemImage: "safari")
        }
    }
}

struct BookmarkItemView: View {
    var site: SavedWebsite
    @State var imageURL: URL?
    var body: some View {
        OpenWebsiteButton(url: site.url) {
            HStack {
                AsyncImage(url: imageURL) { image in
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(width: 25, height: 25)
                } placeholder: {
                    Image(systemName: "safari")
                }
                
                VStack(alignment: .leading) {
                    Text(site.name)
                        .lineLimit(1)
                    Text(site.url.noHTTPSstring)
                        .lineLimit(2)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear {
            Task { imageURL = try? await tryFindingFavicon(site.url) }
        }
    }
    @AppStorage("useFavicons") var useFavicons = true

    func tryFindingFavicon(_ url: URL?) async throws -> URL {
        guard useFavicons else { throw CancellationError() }
        guard let url else { throw URLError(.cancelled) }
        let favicon = try await FaviconFinder(url: url)
            .fetchFaviconURLs()
            .largest()
        
        return favicon.source
    }
}

struct OpenWebsiteButton<Label: View>: View {
    @State var session: ASWebAuthenticationSession?
    @AppStorage("privateMode") var privateMode = false

    var url: URL?
    var label: () -> Label
    var body: some View {
        Button(action: {
            openWebsite(url: url)
        }) {
            label()
        }
    }
    
    func openWebsite(url: URL?, completion: (() -> Void)? = nil) {
        guard let url else { return }
        session = ASWebAuthenticationSession(url: url, callbackURLScheme: "", completionHandler: { _, _ in
            completion?()
        })
        session?.prefersEphemeralWebBrowserSession = privateMode
        session?.start()
    }
}

struct AddWebsiteView: View {
    @StateObject var manager = WebsitesManager.shared
    @Environment(\.dismiss) var dismiss
    @State var name = ""
    @State var url = ""

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)
            } footer: {
                Text("This cannot be empty")
            }
            Section {
                TextField("URL", text: $url)
            } footer: {
                Text(url.toURL()?.absoluteString ?? "NO URL")
            }
        }
        .navigationTitle("Add Website")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Dismiss", systemImage: "xmark") { dismiss() }
                    .labelStyle(.iconOnly)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add", systemImage: "checkmark") { addWebsite() }
                    .labelStyle(.iconOnly)
                    .grayDisabled(name.isEmpty || url.isEmpty || url.toURL() == nil)
            }
        }
        .navStacked()
    }
    func addWebsite() {
        manager.websites.append(
            SavedWebsite(name: name, url: url.toURL()!)
        )
        dismiss()
    }
}

class WebsitesManager: ObservableObject {
    static let shared = WebsitesManager()
    init() {
        let decoder = JSONDecoder()
        if let data = UserDefaults.standard.data(forKey: "websites"), let decoded = try? decoder.decode([SavedWebsite].self, from: data) {
            self.websites = decoded
        } else {
            self.websites = []
        }
    }
    @Published var websites: [SavedWebsite] { didSet { save() } }
    func save() {
        let encoder = JSONEncoder()
        let data = try? encoder.encode(websites)
        UserDefaults.standard.set(data, forKey: "websites")
    }
}

struct SavedWebsite: Codable, Identifiable {
    var id = UUID()
    var name: String
    var symbol: String? = nil
    var url: URL
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

extension URL {
    var noHTTPSstring: String {
        if self.absoluteString.starts(with: "https://") {
            return self.absoluteString.replacingOccurrences(of: "https://", with: "")
        } else if self.absoluteString.starts(with: "http://") {
            return self.absoluteString.replacingOccurrences(of: "http://", with: "")
        } else {
            return self.absoluteString
        }
    }
}

struct RecommendationsView: View {
    var recommendations: [SavedWebsite] = [
        SavedWebsite(name: "Google", symbol: "magnifyingglass", url: "https://google.com/".toURL()!),
        SavedWebsite(name: "YouTube", symbol: "play.rectangle", url: "https://youtube.com/".toURL()!),
        SavedWebsite(name: "Wikipedia", symbol: "book.pages", url: "https://wikipedia.com/".toURL()!),
        SavedWebsite(name: "ChatGPT", symbol: "brain", url: "https://chatgpt.com/".toURL()!),
        SavedWebsite(name: "Instagram", symbol: "camera", url: "https://instagram.com/".toURL()!),
        SavedWebsite(name: "Twitter", symbol: "bird", url: "https://x.com/".toURL()!),
        SavedWebsite(name: "Reddit", symbol: "text.bubble", url: "https://reddit.com/".toURL()!),
        SavedWebsite(name: "TikTok", symbol: "rectangle.stack.badge.play", url: "https://tiktok.com/".toURL()!),
        SavedWebsite(name: "Minecraft", symbol: "cube", url: "https://mcraft.fun/".toURL()!)

    ]
    var body: some View {
        List {
            ForEach(recommendations) { recommendation in
                OpenWebsiteButton(url: recommendation.url) {
                    HStack {
                        Image(systemName: recommendation.symbol ?? "safari")
                        VStack(alignment: .leading) {
                            Text(recommendation.name)
                                .lineLimit(1)
                            Text(recommendation.url.noHTTPSstring)
                                .lineLimit(2)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .listStyle(.carousel)
        .navigationTitle("Recommendations")
        .navStacked()
    }
}
