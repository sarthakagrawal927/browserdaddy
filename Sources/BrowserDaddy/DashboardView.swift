import SwiftUI
import BrowserCore

struct DashboardView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            if let r = model.report {
                LazyVStack(alignment: .leading, spacing: 20) {
                    header(r)
                    if !r.attentionApps.isEmpty || !r.attentionSites.isEmpty {
                        attention(r)
                    }
                    topSites(r)
                    sources(r)
                    rhythm(r)
                    sessions(r)
                    misc(r)
                }
                .padding(24)
            } else {
                ContentUnavailableView("No data yet",
                    systemImage: "chart.bar",
                    description: Text(
                        "Run Extract History (⌘E) after granting Full Disk Access."))
            }
        }
    }

    private func header(_ r: ReportEngine.Report) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(r.totalVisits.formatted()) visits")
                .font(.title.monospacedDigit().bold())
            Text("\(r.uniqueURLs.formatted()) unique URLs · "
                 + "\(r.uniqueDomains.formatted()) domains")
                .foregroundStyle(.secondary)
            if model.extracting {
                ProgressView("Extracting…")
            }
        }
    }

    private func section(_ title: String, @ViewBuilder _ c: () -> some View)
        -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            c()
        }
    }

    private func attention(_ r: ReportEngine.Report) -> some View {
        section("Attention — real focused time") {
            ForEach(Array(r.attentionApps.enumerated()), id: \.offset) { _, a in
                row(fmtDur(Double(a.value)), a.label, a.extra)
            }
            if !r.attentionSites.isEmpty {
                Divider().padding(.vertical, 4)
                ForEach(Array(r.attentionSites.enumerated()), id: \.offset) { _, s in
                    row(fmtDur(Double(s.value)), s.label, "")
                }
            }
        }
    }

    private func topSites(_ r: ReportEngine.Report) -> some View {
        section("Top sites (eTLD+1)") {
            ForEach(Array(r.topSites.prefix(15).enumerated()), id: \.offset) { _, s in
                row("\(s.value)", s.label, "")
            }
        }
    }

    private func sources(_ r: ReportEngine.Report) -> some View {
        section("Sources") {
            ForEach(r.sources, id: \.name) { s in
                row("\(s.visits)", s.name, "\(s.first) → \(s.last)")
            }
            ForEach(Array(r.monthlyShare.enumerated()), id: \.offset) { _, m in
                Text(m).font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func rhythm(_ r: ReportEngine.Report) -> some View {
        section("Rhythm") {
            HStack(alignment: .bottom, spacing: 3) {
                let mx = r.hourly.map(\.value).max() ?? 1
                ForEach(Array(r.hourly.enumerated()), id: \.offset) { _, h in
                    VStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 2)
                            .frame(height: max(2, CGFloat(h.value) / CGFloat(mx) * 60))
                        Text(h.label).font(.system(size: 6))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            HStack {
                ForEach(r.weekday, id: \.label) { d in
                    row("\(d.value)", d.label, "")
                }
            }
        }
    }

    private func sessions(_ r: ReportEngine.Report) -> some View {
        section("Sessions & rabbit holes") {
            ForEach(Array(r.sessionSummary.enumerated()), id: \.offset) { _, s in
                row("\(s.value)", s.label, s.extra)
            }
            Divider().padding(.vertical, 4)
            ForEach(Array(r.rabbitHoles.enumerated()), id: \.offset) { _, h in
                row(h.start.formatted(date: .abbreviated, time: .shortened),
                    "\(h.domains) domains",
                    "\(h.visits) visits · \(fmtDur(h.spanSeconds)) · \(h.source)")
            }
        }
    }

    private func misc(_ r: ReportEngine.Report) -> some View {
        section("Searches") {
            ForEach(Array(r.searches.enumerated()), id: \.offset) { _, s in
                row("\(s.value)", s.label, "")
            }
        }
    }

    private func row(_ left: String, _ mid: String, _ right: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(left).font(.body.monospacedDigit())
                .frame(minWidth: 70, alignment: .trailing)
            Text(mid).lineLimit(1).truncationMode(.middle)
            Spacer()
            Text(right).font(.caption).foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}
