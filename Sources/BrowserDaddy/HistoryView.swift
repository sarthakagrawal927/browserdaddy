import SwiftUI
import BrowserCore

struct HistoryView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Search URLs and titles…", text: $model.searchTerm)
                    .textFieldStyle(.roundedBorder)
                Picker("Browser", selection: $model.browserFilter) {
                    Text("all").tag("all")
                    ForEach(model.browsers, id: \.self) { Text($0).tag($0) }
                }
                .frame(width: 140)
            }
            .padding()

            Table(model.historyRows) {
                TableColumn("Time") { r in
                    Text(r.time?.formatted(date: .abbreviated,
                                           time: .shortened) ?? "—")
                        .font(.caption.monospaced())
                        .frame(width: 130, alignment: .leading)
                }
                TableColumn("Source") { r in
                    Text(r.browser)
                        .font(.caption)
                        .frame(width: 60, alignment: .leading)
                }
                TableColumn("Title") { r in
                    Text(r.title).lineLimit(1).truncationMode(.tail)
                }
                TableColumn("URL") { r in
                    Text(r.url)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                }
            }
        }
    }
}
