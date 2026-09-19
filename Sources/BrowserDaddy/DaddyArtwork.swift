import AppKit
import SwiftUI

/// BrowserDaddy's own Tab Scout identity; compact mark and full illustration.
struct DaddyArtwork: View {
    var brand = false
    private static let mark = Bundle.module.url(
        forResource: "BrowserDaddyIcon", withExtension: "png")
        .flatMap(NSImage.init(contentsOf:))
    private static let sheet = Bundle.module.url(
        forResource: "BrowserDaddyScout", withExtension: "png")
        .flatMap(NSImage.init(contentsOf:))
    var body: some View {
        GeometryReader { geometry in
            if brand, let image = Self.mark {
                Image(nsImage: image).resizable().scaledToFit()
            } else if let image = Self.sheet {
                Image(nsImage: image).resizable().interpolation(.high).scaledToFit()
            }
        }.clipped().allowsHitTesting(false).accessibilityHidden(true)
    }
}
