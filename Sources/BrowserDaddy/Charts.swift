import SwiftUI
import BrowserCore

/// Stable per-browser colors.
enum BrowserColor {
    static func forBrowser(_ name: String) -> Color {
        switch name.lowercased() {
        case "chrome": BrowserTheme.mintInk
        case "safari": BrowserTheme.cyan
        case "brave": BrowserTheme.amber
        case "edge": BrowserTheme.blue
        case "firefox": BrowserTheme.coral
        default: BrowserTheme.secondaryInk
        }
    }
}

/// Daily visits stacked by browser — the archive-over-time view.
/// The Safari→Chrome migration is visible in the color mix.
struct DailyStackedBars: View {
    let series: [ReportEngine.DayPoint]
    var height: CGFloat = 140

    private var prepped: (days: [String], browsers: [String],
                          byDay: [String: [String: Int64]], max: Int64) {
        let days = Array(Set(series.map(\.date))).sorted()
        let browsers = Array(Set(series.map(\.browser))).sorted()
        var byDay: [String: [String: Int64]] = [:]
        for p in series { byDay[p.date, default: [:]][p.browser] = p.count }
        let mx = max(1, days.map { d in
            byDay[d, default: [:]].values.reduce(0, +) }.max() ?? 1)
        return (days, browsers, byDay, mx)
    }

    var body: some View {
        let (days, browsers, byDay, mx) = prepped
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .bottom, spacing: 1) {
                ForEach(days, id: \.self) { d in
                    let total = byDay[d, default: [:]].values.reduce(0, +)
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        ForEach(browsers, id: \.self) { b in
                            let c = byDay[d, default: [:]][b] ?? 0
                            if c > 0 {
                                Rectangle()
                                    .fill(BrowserColor.forBrowser(b))
                                    .frame(height: max(0.5,
                                        CGFloat(c) / CGFloat(mx) * height))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .help("\(d): \(total.formatted()) visits")
                }
            }
            .frame(height: height)

            // axis: month ticks + browser legend
            HStack {
                ForEach(monthTicks(days), id: \.self) { m in
                    Text(m).font(.system(size: 8))
                        .foregroundStyle(BrowserTheme.secondaryInk)
                    Spacer()
                }
            }
            HStack(spacing: 12) {
                ForEach(browsers, id: \.self) { b in
                    HStack(spacing: 4) {
                        Circle().fill(BrowserColor.forBrowser(b))
                            .frame(width: 6, height: 6)
                        Text(b).font(.caption2)
                            .foregroundStyle(BrowserTheme.secondaryInk)
                    }
                }
            }
        }
    }

    private func monthTicks(_ days: [String]) -> [String] {
        var seen = Set<String>()
        var ticks: [String] = []
        for d in days {
            let m = String(d.prefix(7))
            if !seen.contains(m) { seen.insert(m); ticks.append(m) }
        }
        return ticks
    }
}

/// 7×24 visit-density heatmap — GitHub-style intensity grid.
struct ActivityHeatmap: View {
    let cells: [Int64]  // [dow*24 + hour]

    private let dayNames = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        let mx = max(1, cells.max() ?? 1)
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 2) {
                Text("").frame(width: 14)
                ForEach(0..<24, id: \.self) { h in
                    Text(h % 6 == 0 ? "\(h)" : "")
                        .font(.system(size: 6))
                        .foregroundStyle(BrowserTheme.secondaryInk)
                        .frame(maxWidth: .infinity)
                }
            }
            ForEach(0..<7, id: \.self) { d in
                HStack(spacing: 2) {
                    Text(dayNames[d])
                        .font(.system(size: 7))
                        .foregroundStyle(BrowserTheme.secondaryInk)
                        .frame(width: 14, alignment: .leading)
                    ForEach(0..<24, id: \.self) { h in
                        let v = Double(cells[d * 24 + h]) / Double(mx)
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(BrowserTheme.mintInk
                                .opacity(v < 0.02 ? 0.08 : 0.12 + v * 0.88))
                            .frame(maxWidth: .infinity, minHeight: 14)
                    }
                }
            }
        }
    }
}

/// Labeled sparkline card — used for focus trend and archive growth.
struct TrendLine: View {
    enum Kind { case seconds, count }
    let title: String
    let points: [Double]
    var labels: (first: String, last: String) = ("", "")
    var color: Color = BrowserTheme.mintInk
    var kind: Kind = .seconds

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.caption.weight(.semibold))
                    .foregroundStyle(BrowserTheme.secondaryInk)
                Spacer()
                Text(latest).font(.callout.monospacedDigit().bold())
                    .foregroundStyle(BrowserTheme.ink)
            }
            Sparkline(values: points, color: color).frame(height: 56)
            HStack {
                Text(labels.first).font(.system(size: 8))
                Spacer()
                Text(labels.last).font(.system(size: 8))
            }
            .foregroundStyle(BrowserTheme.secondaryInk.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var latest: String {
        guard let v = points.last else { return "—" }
        switch kind {
        case .seconds:
            return v >= 3600 ? String(format: "%.1fh", v / 3600)
                 : v >= 60 ? String(format: "%.0fm", v / 60)
                 : String(format: "%.0fs", v)
        case .count:
            return Int64(v).formatted()
        }
    }
}
