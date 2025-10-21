//
//  WatchLauncher_Complications.swift
//  WatchLauncher Complications
//
//  Created by Tim on 21.09.25.
//

import WidgetKit
import SwiftUI

struct TabComplicationProvider: AppIntentTimelineProvider {
    func recommendations() -> [AppIntentRecommendation<SelectTabIntent>] {
        [
            AppIntentRecommendation(
                intent: {
                    let intent = SelectTabIntent()
                    intent.tab = .google
                    return intent
                }(),
                description: "Google"
            ),
            AppIntentRecommendation(
                intent: {
                    let intent = SelectTabIntent()
                    intent.tab = .browser
                    return intent
                }(),
                description: "Browser"
            ),
            AppIntentRecommendation(
                intent: {
                    let intent = SelectTabIntent()
                    intent.tab = .gemini
                    return intent
                }(),
                description: "Gemini"
            )
        ]
    }
    
    typealias Entry = TabComplicationEntry
    typealias Intent = SelectTabIntent
    func placeholder(in context: Context) -> Entry {
        Entry(date: Date(), tab: .google)
    }
    
    func snapshot(for configuration: SelectTabIntent, in context: Context) async -> Entry {
        Entry(date: Date(), tab: configuration.tab ?? .google)
    }
    
    func timeline(for configuration: SelectTabIntent, in context: Context) async -> Timeline<Entry> {
        let entry = Entry(date: Date(), tab: configuration.tab ?? .google)
        return Timeline(entries: [entry], policy: .never)
    }
}

struct TabComplicationEntry: TimelineEntry {
    let date: Date
    let tab: TabSelection
}

struct TabComplicationView: View {
    let entry: TabComplicationProvider.Entry
    @Environment(\.widgetFamily) var widgetFamily
    @Environment(\.showsWidgetContainerBackground) var backgroundShown
    @Environment(\.widgetRenderingMode) var renderingMode

    var body: some View {
        Group {
            switch widgetFamily {
                case .accessoryRectangular: accessoryRectangular()
                case .accessoryCircular, .accessoryCorner, .accessoryInline: accessoryCircleCorner()
                default: accessoryRectangular()
            }
        }
        .widgetURL(URL(string: "watchLauncher-openTab://\(entry.tab.tabID)")!)
    }
    func accessoryCircleCorner() -> some View {
        Group {
            if widgetFamily == .accessoryCorner {
                ZStack {
                    AccessoryWidgetBackground()
                    Image(systemName: entry.tab.symbol)
                        .font(.title)
                        .bold()
                }
            } else {
                Image(systemName: entry.tab.symbol)
                    .font(.title)
                    .padding()
                    .foregroundStyle(renderingMode == .fullColor ? entry.tab.color : .primary)
                    .background {
                        if !backgroundShown && widgetFamily != .accessoryCorner {
                            Circle()
                                .foregroundStyle(renderingMode == .accented ? AnyShapeStyle(.fill.tertiary) : AnyShapeStyle(entry.tab.color.tertiary))
                        }
                    }
            }
        }
        .widgetLabel {
            Text(entry.tab.name)
        }
        .containerBackground(.fill.tertiary, for: .widget)
        .widgetAccentable()
    }
    func accessoryRectangular() -> some View {
        HStack {
            Image(systemName: entry.tab.symbol)
                .font(.system(size: 25))
            VStack(alignment: .leading) {
                Text(entry.tab.name)
                    .bold()
                    .font(.subheadline)
                Text(entry.tab.description)
                    .foregroundStyle(.secondary)
                    .minimumScaleFactor(0.01)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(backgroundShown ? .primary : entry.tab.color)
        .containerBackground(LinearGradient(colors: [entry.tab.color, entry.tab.color.opacity(0.5)], startPoint: .top, endPoint: .bottom), for: .widget)
        .widgetAccentable()
    }
}
#Preview(as: .accessoryRectangular) {
    TabWidget()
} timeline: {
    for item in TabSelection.allCases {
        TabComplicationEntry(date: .now, tab: item)
    }
}

struct TabWidget: Widget {
    let kind = "tabWidget"
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectTabIntent.self, provider: TabComplicationProvider()) { entry in
            TabComplicationView(entry: entry)
        }
        .configurationDisplayName("Tab Widget")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryInline, .accessoryRectangular])
        .description("Opens the Selected Tab")
    }
}

extension Date {
    static var iphoneReleaseDate: Date {
        var components = DateComponents()
        components.year = 2007
        components.month = 6
        components.day = 29
        components.hour = 9
        components.minute = 41
        components.timeZone = TimeZone(secondsFromGMT: 0) // UTC
        
        return Calendar.current.date(from: components)!
    }
}

import AppIntents

enum TabSelection: String, AppEnum {
    case google
    case browser
    case gemini
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Tab"
    }
    
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] {
        [
            .google: DisplayRepresentation(
                title: "Google",
                subtitle: "Search the Web",
                image: .init(systemName: "magnifyingglass")
            ),
            .browser: DisplayRepresentation(
                title: "Browser",
                subtitle: "Browse the Web",
                image: .init(systemName: "safari")
            ),
            .gemini: DisplayRepresentation(
                title: "Gemini",
                subtitle: "Chat with AI",
                image: .init(systemName: "bubble.left.and.text.bubble.right")
            )
        ]
    }

    var symbol: String {
        switch self {
            case .google:
                "magnifyingglass"
            case .browser:
                "safari"
            case .gemini:
                "bubble.left.and.text.bubble.right"
        }
    }
    var name: LocalizedStringResource {
        Self.caseDisplayRepresentations[self]?.title ?? "Unknown"
    }
    var description: LocalizedStringResource {
        Self.caseDisplayRepresentations[self]?.subtitle ?? "Open Tab"
    }
    var color: Color {
        switch self {
            case .google:
                    .red
            case .browser:
                    .blue
            case .gemini:
                    .purple
        }
    }
    var tabID: Int {
        switch self {
            case .google:
                0
            case .browser:
                1
            case .gemini:
                2
        }
    }
}

struct SelectTabIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Tab"
    static var description = IntentDescription("Choose which tab the complication opens")
    
    @Parameter(title: "Tab")
    var tab: TabSelection?
}
