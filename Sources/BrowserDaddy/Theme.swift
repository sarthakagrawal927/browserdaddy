import SwiftUI

/// Daddy series theme — same palette as StorageDaddy/PerformanceDaddy.
enum BrowserTheme {
    static let fog = Color.black
    static let surface = Color.black
    static let ink = Color.white
    static let secondaryInk = Color(red: 0.78, green: 0.90, blue: 0.86)
    static let coral = Color(red: 0.90, green: 0.46, blue: 0.40)
    static let coralWash = coral.opacity(0.12)
    static let mintInk = Color(red: 0.42, green: 0.79, blue: 0.62)
    static let mint = mintInk.opacity(0.18)
    static let action = mintInk
    static let blue = Color(red: 0.33, green: 0.58, blue: 0.83)
    static let cyan = Color(red: 0.27, green: 0.70, blue: 0.75)
    static let amber = Color(red: 0.87, green: 0.67, blue: 0.28)
    static let divider = secondaryInk.opacity(0.18)
}

/// Shared Daddy-series control pattern.
struct DaddyButtonStyle: ButtonStyle {
    var prominent = false
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 11).padding(.vertical, 7)
            .foregroundStyle(prominent ? Color.black : BrowserTheme.mintInk)
            .background(prominent ? BrowserTheme.mintInk : Color.black,
                        in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7)
                .stroke(BrowserTheme.mintInk.opacity(prominent ? 1 : 0.35),
                        lineWidth: 1))
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
            .contentShape(RoundedRectangle(cornerRadius: 7))
    }
}

struct PrimaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        DaddyButtonStyle(prominent: true).makeBody(configuration: configuration)
    }
}

/// Labeled card section, same rhythm as PerformanceDaddy's TriageBand.
struct BrowserBand<Content: View>: View {
    let label: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 24) {
                bandHeading.frame(width: 124, alignment: .leading)
                Divider()
                content.frame(maxWidth: .infinity, alignment: .leading)
            }
            VStack(alignment: .leading, spacing: 16) {
                bandHeading
                Divider()
                content.frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(24)
        .background(BrowserTheme.surface.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(BrowserTheme.divider, lineWidth: 1)
        }
    }

    private var bandHeading: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(.headline)
                .foregroundStyle(BrowserTheme.secondaryInk)
                .accessibilityAddTraits(.isHeader)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Ranked row: mono value, label, trailing note — the list atom.
struct RankRow: View {
    let value: String
    let label: String
    var note = ""
    var color: Color = BrowserTheme.ink

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(value)
                .font(.callout.monospacedDigit())
                .foregroundStyle(BrowserTheme.mintInk)
                .frame(minWidth: 62, alignment: .trailing)
            Text(label)
                .foregroundStyle(color)
                .lineLimit(1).truncationMode(.middle)
            Spacer()
            Text(note)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

/// Area+stroke sparkline, ported from PerformanceDaddy.
struct Sparkline: View {
    let values: [Double]
    var color: Color = BrowserTheme.mintInk

    var body: some View {
        GeometryReader { geometry in
            let maximum = max(values.max() ?? 1, 1)
            let points = values.enumerated().map { index, value in
                CGPoint(
                    x: values.count <= 1 ? 0
                        : geometry.size.width * CGFloat(index)
                          / CGFloat(values.count - 1),
                    y: geometry.size.height
                        * (1 - CGFloat(value / maximum) * 0.88))
            }
            ZStack {
                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: CGPoint(x: first.x, y: geometry.size.height))
                    path.addLine(to: first)
                    for point in points.dropFirst() { path.addLine(to: point) }
                    if let last = points.last {
                        path.addLine(to: CGPoint(x: last.x,
                                                 y: geometry.size.height))
                    }
                    path.closeSubpath()
                }
                .fill(color.opacity(0.12))
                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    for point in points.dropFirst() { path.addLine(to: point) }
                }
                .stroke(color, style: StrokeStyle(
                    lineWidth: 3, lineCap: .round, lineJoin: .round))
            }
        }
        .accessibilityElement(children: .ignore)
    }
}

/// Shared filter controls — source + range, daddy-styled bordered menus.
struct FilterBar: View {
    @EnvironmentObject var model: AppModel
    /// Focus data has no profile dimension — hide source on Attention.
    var showSource = true

    var body: some View {
        HStack(spacing: 10) {
            if showSource { sourceMenu }
            rangeMenu
            if model.filterSource != "all" || model.filterDays != 0 {
                Button("Clear filters") {
                    model.filterSource = "all"
                    model.filterDays = 0
                }
            }
            Spacer()
        }
    }

    private var sourceMenu: some View {
        Menu {
            Button("all sources") { model.filterSource = "all" }
            ForEach(model.report?.sources ?? [], id: \.name) { s in
                Button(s.name) { model.filterSource = s.name }
            }
        } label: {
            Label(model.filterSource == "all" ? "all sources" : model.filterSource,
                  systemImage: "line.3.horizontal.decrease")
                .padding(.horizontal, 10).padding(.vertical, 6)
        }
        .menuStyle(.borderlessButton).fixedSize()
        .overlay(RoundedRectangle(cornerRadius: 6)
            .stroke(BrowserTheme.mintInk.opacity(0.4), lineWidth: 1))
    }

    private var rangeMenu: some View {
        Menu {
            ForEach([(0, "all time"), (7, "last 7 days"), (30, "last 30 days"),
                     (90, "last 90 days")], id: \.0) { d, label in
                Button(label) { model.filterDays = d }
            }
        } label: {
            Label(rangeLabel, systemImage: "calendar")
                .padding(.horizontal, 10).padding(.vertical, 6)
        }
        .menuStyle(.borderlessButton).fixedSize()
        .overlay(RoundedRectangle(cornerRadius: 6)
            .stroke(BrowserTheme.mintInk.opacity(0.4), lineWidth: 1))
    }

    private var rangeLabel: String {
        model.filterDays == 0 ? "all time" : "last \(model.filterDays) days"
    }
}

/// Proportional bar for ranked lists.
struct ShareBar: View {
    let fraction: Double
    var color: Color = BrowserTheme.mintInk

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(color.opacity(0.12))
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: max(3, geo.size.width
                        * min(1, fraction)))
            }
        }
    }
}
