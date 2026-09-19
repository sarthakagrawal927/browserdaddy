import SwiftUI
import BrowserCore

struct DashboardView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            if let r = model.report, r.totalVisits > 0 {
                VStack(spacing: 16) {
                    verdict(r)
                    timeline(r)
                    trends(r)
                    sites(r)
                    heatmap(r)
                    profiles(r)
                    days(r)
                    depth(r)
                    shared(r)
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

    // MARK: - timeline

    private func timeline(_ r: ReportEngine.Report) -> some View {
        BrowserBand(label: "TIMELINE",
                    subtitle: "Visits per day, stacked by browser") {
            DailyStackedBars(series: r.dailySeries)
        }
    }

    // MARK: - trends

    private func trends(_ r: ReportEngine.Report) -> some View {
        BrowserBand(label: "TRENDS",
                    subtitle: "Focus per day · archive growth · top-site momentum") {
            HStack(alignment: .top, spacing: 20) {
                TrendLine(
                    title: "Focused time / day",
                    points: r.focusDaily.map(\.activeSeconds),
                    labels: (r.focusDaily.first?.date ?? "",
                             r.focusDaily.last?.date ?? ""))
                TrendLine(
                    title: "Unique domains (cumulative)",
                    points: r.cumulativeDomains.map { Double($0.value) },
                    labels: (r.cumulativeDomains.first?.label ?? "",
                             r.cumulativeDomains.last?.label ?? ""),
                    color: BrowserTheme.cyan, kind: .count)
                TrendLine(
                    title: "New domains / month",
                    points: r.newDomainsPerWeek.map { Double($0.value) },
                    labels: (r.newDomainsPerWeek.first?.label ?? "",
                             r.newDomainsPerWeek.last?.label ?? ""),
                    color: BrowserTheme.amber, kind: .count)
            }
            if !r.domainTrends.isEmpty {
                Divider().overlay(BrowserTheme.divider)
                ForEach(Array(r.domainTrends.enumerated()), id: \.offset) { _, t in
                    HStack(spacing: 14) {
                        Text(t.domain).font(.callout)
                            .foregroundStyle(BrowserTheme.ink)
                            .frame(width: 160, alignment: .leading)
                        Sparkline(values: t.monthly.map { Double($0.value) },
                                  color: BrowserTheme.mintInk)
                            .frame(height: 26)
                        Text(t.monthly.last.map { "\($0.value.formatted())" } ?? "—")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(BrowserTheme.secondaryInk)
                            .frame(width: 60, alignment: .trailing)
                    }
                }
            }
        }
    }

    // MARK: - heatmap

    private func heatmap(_ r: ReportEngine.Report) -> some View {
        BrowserBand(label: "HEATMAP",
                    subtitle: "Visit density — weekday × hour (local time)") {
            ActivityHeatmap(cells: r.heatmap)
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

    // MARK: - profiles

    private func profiles(_ r: ReportEngine.Report) -> some View {
        BrowserBand(label: "PROFILES",
                    subtitle: "Each browser/profile has a job — and a rhythm") {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(r.personalities, id: \.label) { p in
                    HStack(alignment: .center, spacing: 14) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.label).font(.callout.weight(.medium))
                                .foregroundStyle(BrowserTheme.ink)
                            Text(p.extra).font(.caption2)
                                .foregroundStyle(.secondary).lineLimit(1)
                        }
                        .frame(width: 200, alignment: .leading)
                        if let ph = r.profileHours.first(
                            where: { $0.source == p.label }) {
                            let mx = max(1, ph.hours.max() ?? 1)
                            Sparkline(values: ph.hours.map {
                                Double($0) / Double(mx) },
                                      color: BrowserTheme.cyan)
                                .frame(height: 26)
                        }
                        Text(p.value.formatted())
                            .font(.callout.monospacedDigit().bold())
                            .foregroundStyle(BrowserTheme.mintInk)
                            .frame(width: 70, alignment: .trailing)
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

    // MARK: - days

    private func days(_ r: ReportEngine.Report) -> some View {
        BrowserBand(label: "DAYS",
                    subtitle: "Day-of-week by source · busiest days · streaks") {
            VStack(alignment: .leading, spacing: 16) {
                // dow × source matrix
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 0) {
                        Text("").frame(width: 140, alignment: .leading)
                        ForEach(["Sun","Mon","Tue","Wed","Thu","Fri","Sat"],
                                id: \.self) { d in
                            Text(d).font(.caption2.weight(.semibold))
                                .foregroundStyle(BrowserTheme.secondaryInk)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    ForEach(Array(r.dowBySource.enumerated()), id: \.offset) { _, s in
                        let mx = max(1, s.days.max() ?? 1)
                        HStack(spacing: 0) {
                            Text(s.source).font(.caption)
                                .foregroundStyle(BrowserTheme.ink)
                                .frame(width: 140, alignment: .leading)
                            ForEach(0..<7, id: \.self) { d in
                                let v = Double(s.days[d]) / Double(mx)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(BrowserTheme.mintInk
                                        .opacity(v < 0.02 ? 0.08
                                                 : 0.15 + v * 0.85))
                                    .frame(height: 14)
                                    .frame(maxWidth: .infinity)
                                    .help("\(s.source) \(d): \(s.days[d])")
                            }
                        }
                    }
                }
                Divider().overlay(BrowserTheme.divider)
                HStack(alignment: .top, spacing: 28) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("BUSIEST DAYS").font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(Array(r.busiestDays.prefix(8).enumerated()),
                                id: \.offset) { _, d in
                            RankRow(value: d.value.formatted(), label: d.label)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CONSISTENCY").font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        RankRow(value: "\(r.longestStreak)d",
                                label: "longest daily streak")
                        RankRow(value: r.medianVisitsPerDay.formatted(),
                                label: "median visits/day")
                        RankRow(value: "\(r.longestGapDays)d",
                                label: "longest gap (no visits)")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - depth

    private func depth(_ r: ReportEngine.Report) -> some View {
        BrowserBand(label: "DEPTH",
                    subtitle: "Concentration — how much of browsing is a few sites") {
            VStack(alignment: .leading, spacing: 13) {
                HStack(spacing: 28) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(format: "%.0f%%", r.top10Share))
                            .font(.title2.bold())
                            .foregroundStyle(BrowserTheme.mintInk)
                        Text("of visits go to your top 10 domains")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(format: "%.0f%%", r.top100Share))
                            .font(.title2.bold())
                            .foregroundStyle(BrowserTheme.cyan)
                        Text("in top 100 — the long tail is huge")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(r.oneHitDomains.formatted())
                            .font(.title2.bold())
                            .foregroundStyle(BrowserTheme.amber)
                        Text("domains visited exactly once")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Divider().overlay(BrowserTheme.divider)
                Text("REVISIT DEPTH").font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(r.habit, id: \.label) { h in
                    RankRow(value: h.value.formatted(), label: h.label)
                }
            }
        }
    }

    // MARK: - shared

    private func shared(_ r: ReportEngine.Report) -> some View {
        BrowserBand(label: "SHARED",
                    subtitle: "Domains alive in more than one browser/profile") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(r.sharedDomains.enumerated()), id: \.offset) { _, s in
                    RankRow(value: s.visits.formatted(), label: s.domain,
                            note: s.sources)
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
