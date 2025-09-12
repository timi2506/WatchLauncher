import SwiftUI
import Combine

struct GoogleSearchResponse: Codable {
    let kind: String
    let items: [SearchResultItem]
}

struct SearchResultItem: Codable, Hashable {
    let title: String
    let link: String
    let snippet: String?
}

class SearchManager: ObservableObject {
    init() {
        if let string = UserDefaults(suiteName: "group.timi2506.WatchFari")?.string(forKey: "searchKey") {
            self.apiKey = string
        }
    }
    static let shared = SearchManager()
    @Published var apiKey = "" {
        didSet {
            UserDefaults(suiteName: "group.timi2506.WatchFari")?.set(apiKey, forKey: "searchKey")
        }
    }
    
    func fetchGoogleSearchResults(query: String, completion: @escaping ([SearchResultItem]?) -> Void) {
        let cseId = "b37533880e1d646dc"
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://www.googleapis.com/customsearch/v1?q=\(encodedQuery)&key=\(apiKey)&cx=\(cseId)"
        
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Error fetching search results: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let data = data else {
                print("No data received.")
                completion(nil)
                return
            }
            
            do {
                let searchResponse = try JSONDecoder().decode(GoogleSearchResponse.self, from: data)
                
                completion(searchResponse.items)
            } catch {
                print("Error decoding response: \(error.localizedDescription)")
                completion(nil)
            }
        }
        
        task.resume()
    }
}

struct GoogleSearchView: View {
    @State var results: [SearchResultItem]?
    @StateObject var searchManager = SearchManager.shared
    @State var searchText = ""
    @State var loading = false
    @State var showKey = false
    @State var showKeyAlert = false
    var onOpenSearchresult: (String) -> Void
    let watchScreen = WKInterfaceDevice.current().screenBounds
    var body: some View {
        VStack {
            TextField("Search Text", text: $searchText)
                .textFieldStyle(.plain)
            HStack {
                NavigationLink(destination: {
                    List {
                        Section("Search Results") {
                            if loading {
                                ProgressView()
                            } else if let results {
                                ForEach(results, id: \.self) { result in
                                    Button(action: {
                                        onOpenSearchresult(result.link)
                                    }) {
                                        VStack(alignment: .leading) {
                                            Text(result.title)
                                            Text(result.link)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            } else {
                                ContentUnavailableView.search
                            }
                        }
                    }
                    .onAppear {
                        let prompt = searchText
                        searchText = ""
                        loading = true
                        searchManager.fetchGoogleSearchResults(query: prompt) { items in
                            loading = false
                            results = items
                        }
                    }
                }) {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .disabled(searchText.isEmpty || searchManager.apiKey.isEmpty)
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .labelStyle(.iconOnly)
                .simultaneousGesture(
                    TapGesture()
                        .onEnded { _ in
                            if searchManager.apiKey.isEmpty {
                                showKeyAlert = true
                            }
                        }
                )
                
                NavigationLink(destination: {
                    Form {
                        if showKey {
                            TextField("API Key", text: $searchManager.apiKey)
                        } else {
                            SecureField("API Key", text: $searchManager.apiKey)
                        }
                        Toggle("Show API Key", isOn: $showKey)
                        NavigationLink("Get Key") {
                            List {
                                Section {
                                    Button("On Watch", systemImage: "applewatch") {
                                        onOpenSearchresult("https://developers.google.com/custom-search/v1/overview#api_key")
                                    }
                                    NavigationLink(destination: {
                                        Image("API-Key-QR")
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
                    .navigationTitle("Search Settings")
                }) {
                    Label("Settings", systemImage: "gear")
                }
                .buttonStyle(.bordered)
                .tint(.blue)
                .labelStyle(.iconOnly)
            }
        }
        .alert("API Key Required", isPresented: $showKeyAlert, actions: {
            Button("OK") { showKeyAlert = false }
        }, message: { Text("Please add one in Settings") })
        .navigationTitle("Google")
        .navigationBarTitleDisplayMode(.inline)
        .navStacked()
        .tabItem {
            Label("Hello, world!", systemImage: "globe")
        }
    }
}
