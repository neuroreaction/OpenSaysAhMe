import WidgetKit
import SwiftUI

struct OpenSaysMe_Widget: Widget {
    let kind: String = "OpenSaysMe_Widget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            OpenSaysMeWidgetView(entry: entry)
        }
        .configurationDisplayName("My Garage")
        .description("Open your garage door")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date())
    }
    
    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        completion(SimpleEntry(date: Date()))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let timeline = Timeline(entries: [SimpleEntry(date: Date())], policy: .never)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
}

struct OpenSaysMeWidgetView: View {
    var entry: Provider.Entry
    
    var body: some View {
        Link(destination: URL(string: "opensaysme://openmydoor")!) {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "garage.closed")
                    .font(.title2)
            }
        }
    }
}
