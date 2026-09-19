import Foundation

/// A single visit row unified across browser engines.
public struct HistoryVisit: Sendable, Equatable {
    public var browser: String
    public var profile: String
    public var visitID: Int64
    public var url: String
    public var title: String
    public var visitedAt: Date
    public var visitCount: Int
    public var typedCount: Int
    public var transition: String?
    /// Chromium visit_duration (seconds). Unreliable as attention — kept for
    /// fidelity with the python archive; focus.active_s is the honest signal.
    public var duration: Double?
    public var fromVisit: Int64?

    public init(browser: String, profile: String, visitID: Int64, url: String,
                title: String, visitedAt: Date, visitCount: Int,
                typedCount: Int, transition: String?, duration: Double? = nil,
                fromVisit: Int64?) {
        self.browser = browser
        self.profile = profile
        self.visitID = visitID
        self.url = url
        self.title = title
        self.visitedAt = visitedAt
        self.visitCount = visitCount
        self.typedCount = typedCount
        self.transition = transition
        self.duration = duration
        self.fromVisit = fromVisit
    }
}

/// One continuous focus span recorded by the OS-level watcher.
public struct FocusSegment: Sendable, Equatable {
    public var startedAt: Date
    public var endedAt: Date
    public var app: String
    public var url: String
    public var title: String
    public var activeSeconds: Double

    public init(startedAt: Date, endedAt: Date, app: String, url: String,
                title: String, activeSeconds: Double) {
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.app = app
        self.url = url
        self.title = title
        self.activeSeconds = activeSeconds
    }
}

/// A discovered on-disk history store.
public struct HistorySource: Sendable, Equatable {
    public enum Engine: String, Sendable { case chromium, firefox, safari }
    public var browser: String
    public var profile: String
    public var path: URL
    public var engine: Engine

    public init(browser: String, profile: String, path: URL, engine: Engine) {
        self.browser = browser
        self.profile = profile
        self.path = path
        self.engine = engine
    }
}
