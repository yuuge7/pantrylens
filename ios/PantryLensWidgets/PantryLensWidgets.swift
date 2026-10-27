import WidgetKit
import SwiftUI

struct PantryEntry: TimelineEntry {
    let date: Date
    let home: String
    let useSoon: String
    let shopping: String
    let updated: String
}

struct PantryTimeline: TimelineProvider {
    func placeholder(in context: Context) -> PantryEntry {
        PantryEntry(date: Date(), home: "My home", useSoon: "Open PantryLens to see what to use soon.", shopping: "Open PantryLens to see your shopping list.", updated: "")
    }
    func getSnapshot(in context: Context, completion: @escaping (PantryEntry) -> Void) {
        let data = UserDefaults(suiteName: "group.com.pantrylens.pantrylens")
        completion(PantryEntry(date: Date(), home: data?.string(forKey: "home") ?? "My home", useSoon: data?.string(forKey: "useSoon") ?? "", shopping: data?.string(forKey: "shopping") ?? "", updated: data?.string(forKey: "updated") ?? "Open PantryLens to update"))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<PantryEntry>) -> Void) {
        getSnapshot(in: context) { entry in
            completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(1800))))
        }
    }
}

struct PantryWidgetView: View {
    let entry: PantryEntry
    let shopping: Bool
    var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(shopping ? "Shopping list" : "Use soon", systemImage: shopping ? "basket" : "leaf").font(.headline)
            Text(entry.home).font(.caption).foregroundColor(.secondary)
            let value = shopping ? entry.shopping : entry.useSoon
            Text(value.isEmpty ? (shopping ? "Your list is clear." : "Nothing to use soon.") : value)
                .font(.caption).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            Text(entry.updated).font(.system(size: 9)).foregroundColor(.secondary)
        }.padding().foregroundColor(Color(red: 0.08, green: 0.25, blue: 0.21))
    }
    var body: some View {
        if #available(iOS 17.0, *) {
            content.containerBackground(Color(red: 0.96, green: 0.97, blue: 0.95), for: .widget)
        } else {
            content.background(Color(red: 0.96, green: 0.97, blue: 0.95))
        }
    }
}

struct PantryLensWidget: Widget {
    let kind = "PantryLensWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PantryTimeline()) { PantryWidgetView(entry: $0, shopping: false) }
            .configurationDisplayName("Use soon").description("Batches to use before they expire.")
            .supportedFamilies([.systemMedium, .systemLarge])
    }
}
struct PantryLensShoppingWidget: Widget {
    let kind = "PantryLensShoppingWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PantryTimeline()) { PantryWidgetView(entry: $0, shopping: true) }
            .configurationDisplayName("Shopping list").description("Your household shopping list.")
            .supportedFamilies([.systemMedium, .systemLarge])
    }
}
@main
struct PantryLensWidgets: WidgetBundle {
    var body: some Widget { PantryLensWidget(); PantryLensShoppingWidget() }
}
