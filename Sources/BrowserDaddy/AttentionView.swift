import SwiftUI
import BrowserCore

/// The live attention surface — everything the focus watcher sees.
struct AttentionView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                now
                timeline
                appsAndSites
                pattern
            }
            .padding(28)
            .frame(maxWidth: 1_080)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - now

    private var now: some View {
        HStack(alignment: .top, spacing: 18) {
            ZStack {
                Circle().fill(model.watcher.isRunning
                              ? BrowserTheme.mint : BrowserTheme.coralWash)
                    .frame(width: 52, height: 52)
                Image(systemName: model.watcher.isRunning ? "eye" : "eye.slash")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(model.watcher.isRunning
                                     ? BrowserTheme.mintInk : BrowserTheme.coral)
            }
            VStack(alignment: .leading, spacing: 7) {
                Text(model.nowApp.isEmpty ? "Watching…" : model.nowApp)
                    .font(.largeTitle.bold())
                    .foregroundStyle(BrowserTheme.ink)
                    .accessibilityAddTraits(.isHeader)
                if !model.nowURL.isEmpty {
                    Text(model.nowURL)
                        .font(.callout.monospaced())
                        .foregroundStyle(BrowserTheme.mintInk)
                        .lineLimit(1).truncationMode(.middle)
                } else {
                    Text(model.nowApp.isEmpty
                         ? "Waiting for the first poll"
                         : "Not a browser — or no window open")
                        .font(.callout)
                        .foregroundStyle(BrowserTheme.secondaryInk)
                }
                Label("2s polls · active = input within 60s · second-monitor "
                      + "tabs don't count", systemImage: "info.circle")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(24)
        .background(BrowserTheme.mint)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - day timeline

    private var timeline: some View {
        BrowserBand(label: "TIMELINE",
                    subtitle: "Focus segments across the day — gaps are unfocused") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Menu {
                        ForEach(model.focusDaysList, id: \.self) { d in
                            Button(d) { model.focusDay = d }
                        }
                    } label: {
                        Label(model.focusDay.isEmpty ? "pick a day" : model.focusDay,
                              systemImage: "calendar")
                            .padding(.horizontal, 10).padding(.vertical, 6)
                    }
                    .menuStyle(.borderlessButton).fixedSize()
                    .overlay(RoundedRectangle(cornerRadius: 6)
                        .stroke(BrowserTheme.mintInk.opacity(0.4), lineWidth: 1))
                    Spacer()
                    if !model.daySegments.isEmpty {
                        let act = model.daySegments.reduce(0.0) {
                            $0 + $1.activeSeconds }
                        Text("\(fmtDur(act)) focused · "
                             + "\(model.daySegments.count) spans")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(BrowserTheme.secondaryInk)
                    }
                }

                if model.daySegments.isEmpty {
                    Text("No focus data for this day.")
                        .font(.callout).foregroundStyle(BrowserTheme.secondaryInk)
                } else {
                    DayStrip(segments: model.daySegments)
                    HStack(spacing: 12) {
                        ForEach(topApps, id: \.0) { app, _ in
                            HStack(spacing: 4) {
                                Circle().fill(appColor(app))
                                    .frame(width: 6, height: 6)
                                Text(app).font(.caption2)
                                    .foregroundStyle(BrowserTheme.secondaryInk)
                            }
                        }
                    }
                }
            }
        }
    }

    private struct SegBar: View {
        let seg: ReportEngine.FocusSegRow
        let width: CGFloat

        var body: some View {
            if let st = seg.start, let en = seg.end {
                let (sod, dur) = Self.position(start: st, end: en)
                Rectangle()
                    .fill(appColor(seg.app)
                        .opacity(seg.activeSeconds > 0 ? 0.9 : 0.35))
                    .frame(width: max(2, width * dur / 86400))
                    .offset(x: width * sod / 86400)
                    .help("\(seg.app) · \(seg.url.isEmpty ? "—" : seg.url) · "
                          + "\(fmtDur(seg.activeSeconds)) active")
            }
        }

        private static func position(start: Date, end: Date)
            -> (Double, Double) {
            let cal = Calendar.current
            let sod = Double(
                cal.component(.hour, from: start) * 3600
                + cal.component(.minute, from: start) * 60
                + cal.component(.second, from: start))
            return (sod, max(2, end.timeIntervalSince(start)))
        }
    }

    /// Segments mapped to a 24h strip; colored by app.
    private struct DayStrip: View {
        let segments: [ReportEngine.FocusSegRow]

        var body: some View {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(BrowserTheme.secondaryInk.opacity(0.07))
                    ForEach(segments) { SegBar(seg: $0, width: geo.size.width) }
                }
            }
            .frame(height: 44)
            HStack {
                ForEach([0, 6, 12, 18, 24], id: \.self) { h in
                    if h > 0 { Spacer() }
                    Text("\(h):00").font(.system(size: 8))
                        .foregroundStyle(BrowserTheme.secondaryInk.opacity(0.7))
                }
            }
        }
    }

    private var topApps: [(String, Double)] {
        var t: [String: Double] = [:]
        for s in model.daySegments { t[s.app, default: 0] += s.activeSeconds }
        return t.sorted { $0.value > $1.value }.prefix(6).map { ($0.key, $0.value) }
    }

    // MARK: - apps & sites

    private var appsAndSites: some View {
        BrowserBand(label: "WHERE IT GOES",
                    subtitle: "Active time per app and per site — open time shown too") {
            VStack(alignment: .leading, spacing: 13) {
                let maxA = max(1, model.attentionAppsDetail.map(\.value).max() ?? 1)
                ForEach(Array(model.attentionAppsDetail.prefix(10).enumerated()),
                        id: \.offset) { _, a in
                    VStack(alignment: .leading, spacing: 3) {
                        RankRow(value: fmtDur(Double(a.value)), label: a.label,
                                note: a.extra)
                        ShareBar(fraction: Double(a.value) / Double(maxA))
                            .frame(height: 4)
                    }
                }
                if !model.attentionSitesDetail.isEmpty {
                    Divider().overlay(BrowserTheme.divider)
                    Text("BY SITE").font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(Array(model.attentionSitesDetail.prefix(12).enumerated()),
                            id: \.offset) { _, s in
                        RankRow(value: fmtDur(Double(s.value)), label: s.label,
                                note: s.extra)
                    }
                }
            }
        }
    }

    // MARK: - pattern

    private var pattern: some View {
        BrowserBand(label: "PATTERN",
                    subtitle: "When real attention happens (local time)") {
            HStack(alignment: .bottom, spacing: 3) {
                let hourly = model.attentionHourly
                let mx = max(1, hourly.max() ?? 1)
                ForEach(0..<min(24, hourly.count), id: \.self) { h in
                    VStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(BrowserTheme.mintInk)
                            .frame(height: max(2, CGFloat(hourly[h])
                                / CGFloat(mx) * 60))
                        Text(h % 6 == 0 ? "\(h)" : "")
                            .font(.system(size: 7))
                            .foregroundStyle(BrowserTheme.secondaryInk)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 80)
        }
    }
}

private func appColor(_ name: String) -> Color {
    switch name {
    case "Google Chrome", "Safari", "Brave Browser", "Microsoft Edge",
         "Arc", "Vivaldi", "Opera", "Chromium":
        return BrowserTheme.mintInk
    case "Warp", "Xcode": return BrowserTheme.cyan
    default:
        var h: UInt64 = 5381
        for b in name.utf8 { h = h &* 33 &+ UInt64(b) }
        let palette: [Color] = [BrowserTheme.amber, BrowserTheme.blue,
                                BrowserTheme.coral, BrowserTheme.secondaryInk]
        return palette[Int(h % UInt64(palette.count))]
    }
}
