import SwiftUI
import BrowserCore

struct HistoryView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                DaddyArtwork(topic: 4).frame(width: 34, height: 34)
                TextField("Search URLs and titles…", text: $model.searchTerm)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 9).frame(height: 30)
                    .background(Color.black)
                    .overlay(RoundedRectangle(cornerRadius: 6)
                        .stroke(BrowserTheme.mintInk.opacity(0.45), lineWidth: 1))
                Menu {
                    Button("all") { model.browserFilter = "all" }
                    ForEach(model.browsers, id: \.self) { b in
                        Button(b) { model.browserFilter = b }
                    }
                } label: {
                    Label(model.browserFilter, systemImage: "line.3.horizontal.decrease")
                        .padding(.horizontal, 10).padding(.vertical, 6)
                }
                .menuStyle(.borderlessButton).fixedSize()
                .background(Color.black)
                .overlay(RoundedRectangle(cornerRadius: 6)
                    .stroke(BrowserTheme.mintInk.opacity(0.4), lineWidth: 1))
            }
            .padding(.horizontal, 24).padding(.top, 18).padding(.bottom, 12)

            Divider().overlay(BrowserTheme.mintInk.opacity(0.18))

            if model.historyRows.isEmpty {
                emptyState
            } else {
                List(model.historyRows) { r in
                    HStack(spacing: 12) {
                        Text(r.time?.formatted(date: .abbreviated,
                                               time: .shortened) ?? "—")
                            .font(.caption.monospaced())
                            .foregroundStyle(BrowserTheme.secondaryInk)
                            .frame(width: 150, alignment: .leading)
                        Text(r.browser)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(BrowserTheme.cyan)
                            .frame(width: 58, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(r.title.isEmpty ? r.url : r.title)
                                .foregroundStyle(BrowserTheme.ink)
                                .lineLimit(1).truncationMode(.tail)
                            Text(r.url)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1).truncationMode(.middle)
                        }
                    }
                    .padding(.vertical, 4).contentShape(Rectangle())
                    .listRowBackground(Color.black)
                    .contextMenu {
                        Button("Copy URL") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(r.url, forType: .string)
                        }
                        Button("Open URL") {
                            if let u = URL(string: r.url) {
                                NSWorkspace.shared.open(u)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.black)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Spacer()
            DaddyArtwork(topic: 7).frame(width: 72, height: 72)
            Text(model.report == nil || model.report?.totalVisits == 0
                 ? "Nothing archived yet" : "No matches")
                .font(.title2.bold()).foregroundStyle(BrowserTheme.ink)
            Text(model.report == nil || model.report?.totalVisits == 0
                 ? "Grant Full Disk Access and sync history first."
                 : "Try a different search or browser filter.")
                .font(.callout).foregroundStyle(BrowserTheme.secondaryInk)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
