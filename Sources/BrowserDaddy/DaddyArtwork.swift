import AppKit
import SwiftUI

/// BrowserDaddy's own Tab Scout identity; compact mark and full illustration.
struct DaddyArtwork: View {
    var brand = false
    private static let mark = DaddyResources.url(forResource: "BrowserDaddyIcon")
        .flatMap(NSImage.init(contentsOf:))
    private static let sheet = DaddyResources.url(forResource: "BrowserDaddyScout")
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

enum DaddyResources {
    static func url(forResource name: String) -> URL? {
        let packaged = Bundle.main.resourceURL.flatMap {
            Bundle(url: $0.appendingPathComponent("BrowserDaddy_BrowserDaddy.bundle"))
        }
        return packaged?.url(forResource: name, withExtension: "png")
            ?? Bundle.module.url(forResource: name, withExtension: "png")
    }
}
