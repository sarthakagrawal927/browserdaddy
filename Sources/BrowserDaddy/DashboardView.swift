import SwiftUI
import BrowserCore

struct DashboardView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            if let r = model.report, r.totalVisits > 0 {
                VStack(spacing: 16) {
                    verdict(r)
                    attention(r)
                    sites(r)
                    rhythm(r)
                    profiles(r)
                    sessions(r)
                    searches(r)
                }
                .padding(28)
                .frame(maxWidth: 1_080)
                .frame(maxWidth: .infinity)
            } else {
                emptyState
            }
        }
    }

    // MARK: - headline

    private func verdict(_ r: ReportEngine.Report) -> some View {
        HStack(alignment: .top, spacing: 18) {
            DaddyArtwork(topic: 1).frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 7) {
                Text("\(r.totalVisits.formatted()) visits archived")
                    .font(.largeTitle.bold())
                    .foregroundStyle(BrowserTheme.ink)
                    .accessibilityAddTraits(.isHeader)
                Text("\(r.uniqueURLs.formatted()) unique URLs across "
                     + "\(r.uniqueDomains.formatted()) domains")
                    .foregroundStyle(BrowserTheme.secondaryInk)
                Label(rangeText(r), systemImage: "archivebox")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BrowserTheme.secondaryInk)
            }
            Spacer()
        }
        .padding(24)
        .background(BrowserTheme.mint)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func rangeText(_ r: ReportEngine.Report) -> String {
        let f = r.sources.map(\.first).min() ?? "—"
        let l = r.sources.map(\.last).max() ?? "—"
        return "\(f) → \(l) · survives browser pruning"
    }

    // MARK: - attention

    private func attention(_ r: ReportEngine.Report) -> some View {
        BrowserBand(label: "ATTENTION",
                    subtitle: "Real focused time — the signal browsers never record") {
            VStack(alignment: .leading, spacing: 13) {
                if r.attentionApps.isEmpty && r.attentionSites.isEmpty {
                    Text("Focus segments appear here as the watcher runs.")
                        .font(.callout).foregroundStyle(BrowserTheme.secondaryInk)
                } else {
                    let maxA = max(1, r.attentionApps.map(\.value).max() ?? 1)
                    ForEach(Array(r.attentionApps.prefix(8).enumerated()),
                            id: \.offset) { _, a in
                        VStack(alignment: .leading, spacing: 3) {
                            RankRow(value: fmtDur(Double(a.value)),
                                    label: a.label, note: a.extra)
                            ShareBar(fraction: Double(a.value) / Double(maxA))
                                .frame(height: 4)
                        }
                    }
                    if !r.attentionSites.isEmpty {
                        Divider().overlay(BrowserTheme.divider)
                        Text("BY SITE").font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(Array(r.attentionSites.prefix(8).enumerated()),
                                id: \.offset) { _, s in
                            RankRow(value: fmtDur(Double(s.value)),
                                    label: s.label)
                        }
                    }
                }
            }
        }
    }

    // MARK: - sites

    private func sites(_ r: ReportEngine.Report) -> some View {
        BrowserBand(label: "SITES",
                    subtitle: "Where visits concentrate — registrable-domain rollup") {
            VStack(alignment: .leading, spacing: 8) {
                let mx = max(1, r.topSites.map(\.value).max() ?? 1)
                ForEach(Array(r.topSites.prefix(15).enumerated()),
                        id: \.offset) { _, s in
                    VStack(alignment: .leading, spacing: 3) {
                        RankRow(value: s.value.formatted(), label: s.label)
                        ShareBar(fraction: Double(s.value) / Double(mx))
                            .frame(height: 3)
                    }
                }
            }
        }
    }

    // MARK: - rhythm

    private func rhythm(_ r: ReportEngine.Report) -> some View {
        BrowserBand(label: "RHYTHM",
                    subtitle: "When browsing happens — UTC hours") {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .bottom, spacing: 3) {
                    let mx = max(1, r.hourly.map(\.value).max() ?? 1)
                    ForEach(Array(r.hourly.enumerated()), id: \.offset) { _, h in
                        VStack(spacing: 3) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(BrowserTheme.mintInk)
                                .frame(height: max(2, CGFloat(h.value)
                                    / CGFloat(mx) * 64))
                            Text(h.label).font(.system(size: 6))
                                .foregroundStyle(BrowserTheme.secondaryInk)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 80)
                HStack(spacing: 12) {
                    ForEach(r.weekday, id: \.label) { d in
                        VStack(spacing: 4) {
                            Text(d.label).font(.caption)
                                .foregroundStyle(BrowserTheme.secondaryInk)
                            Text(d.value.formatted())
                                .font(.callout.monospacedDigit())
                                .foregroundStyle(BrowserTheme.ink)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    // MARK: - profiles

    private func profiles(_ r: ReportEngine.Report) -> some View {
        BrowserBand(label: "PROFILES",
                    subtitle: "Each browser/profile has a job") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(r.personalities, id: \.label) { p in
                    HStack(alignment: .firstTextBaseline) {
                        Text(p.label).font(.callout.weight(.medium))
                            .foregroundStyle(BrowserTheme.ink)
                            .frame(minWidth: 140, alignment: .leading)
                        Text(p.value.formatted())
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(BrowserTheme.mintInk)
                        Spacer()
                        Text(p.extra).font(.caption)
                            .foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Divider().overlay(BrowserTheme.divider)
                ForEach(r.sources, id: \.name) { s in
                    RankRow(value: s.visits.formatted(), label: s.name,
                            note: "\(s.first) → \(s.last)")
                }
            }
        }
    }

    // MARK: - sessions

    private func sessions(_ r: ReportEngine.Report) -> some View {
        BrowserBand(label: "SESSIONS",
                    subtitle: "30-minute-gap sessions and the deepest rabbit holes") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(r.sessionSummary.enumerated()), id: \.offset) { _, s in
                    RankRow(value: s.value.formatted(), label: s.label,
                            note: s.extra)
                }
                if !r.rabbitHoles.isEmpty {
                    Divider().overlay(BrowserTheme.divider)
                    Text("DEEPEST RABBIT HOLES").font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(Array(r.rabbitHoles.enumerated()), id: \.offset) { _, h in
                        RankRow(value: "\(h.domains) dom",
                                label: h.start.formatted(
                                    date: .abbreviated, time: .shortened),
                                note: "\(h.visits) visits · \(fmtDur(h.spanSeconds))")
                    }
                }
            }
        }
    }

    // MARK: - searches

    private func searches(_ r: ReportEngine.Report) -> some View {
        BrowserBand(label: "SEARCHES",
                    subtitle: "Chromium omnibox queries — browsers differ in what they record") {
            VStack(alignment: .leading, spacing: 8) {
                if r.searches.isEmpty {
                    Text("No search terms captured yet.")
                        .font(.callout).foregroundStyle(BrowserTheme.secondaryInk)
                }
                ForEach(Array(r.searches.enumerated()), id: \.offset) { _, s in
                    RankRow(value: s.value.formatted(), label: s.label)
                }
            }
        }
    }

    // MARK: - empty

    private var emptyState: some View {
        VStack(spacing: 26) {
            Spacer()
            ZStack {
                Circle().fill(BrowserTheme.mint).frame(width: 92, height: 92)
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(BrowserTheme.mintInk)
            }
            VStack(spacing: 10) {
                Text("No history archived yet")
                    .font(.largeTitle.bold()).foregroundStyle(BrowserTheme.ink)
                Text("BrowserDaddy reads browser history into a permanent local archive. "
                     + "Grant Full Disk Access, then sync.")
                    .foregroundStyle(BrowserTheme.secondaryInk)
                    .multilineTextAlignment(.center).frame(maxWidth: 520)
            }
            Button("Sync History", action: model.runExtract)
                .buttonStyle(PrimaryActionButtonStyle())
            Spacer()
        }
        .padding(48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
