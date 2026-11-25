import Foundation

// FeedKit is Foundation only, so tools/feedtest and tools/feedcheck can compile it outside
// the app (on macOS or Linux), and so it can move into a package Orbit shares later.

struct ParsedFeed: Sendable, Equatable {
    var title = ""
    var siteURL: URL?
    var summary = ""
    var iconURL: URL?
    var items: [ParsedItem] = []
}

struct ParsedItem: Sendable, Equatable {
    var id = ""
    var title = ""
    var link: URL?
    var author = ""
    var published: Date?
    var updated: Date?
    var summaryHTML = ""
    var contentHTML = ""
    var imageURL: URL?
    var audioURL: URL?
    /// Filled in after parsing, off the main thread.
    var excerpt = ""
    var wordCount = 0

    /// The fullest HTML the feed gave: the content when there is some, else the summary.
    var bodyHTML: String { contentHTML.isEmpty ? summaryHTML : contentHTML }
    var date: Date? { published ?? updated }
}

enum FeedError: LocalizedError, Equatable {
    case notAFeed
    case http(Int)
    case noFeedFound
    case badAddress

    var errorDescription: String? {
        switch self {
        case .notAFeed: "This address isn't a feed."
        case .http(let code): "The site answered with an error (\(code))."
        case .noFeedFound: "Couldn't find a feed on this site."
        case .badAddress: "That doesn't look like a web address."
        }
    }
}

/// Dates in feeds come in many shapes: RFC 822 for RSS, ISO 8601 for Atom and JSON Feed,
/// and plenty of near misses of both.
enum FeedDates {
    private static let lock = NSLock()

    private static let rfc822: [DateFormatter] = [
        "EEE, dd MMM yyyy HH:mm:ss Z",
        "EEE, dd MMM yyyy HH:mm:ss zzz",
        "EEE, d MMM yyyy HH:mm:ss Z",
        "EEE, d MMM yyyy HH:mm:ss zzz",
        "EEE, dd MMM yyyy HH:mm Z",
        "EEE, dd MMM yyyy HH:mm zzz",
        "dd MMM yyyy HH:mm:ss Z",
        "d MMM yyyy HH:mm:ss Z",
        "EEE, dd MMM yyyy",
        "yyyy-MM-dd'T'HH:mm:ssZZZZZ",
        "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ",
        "yyyy-MM-dd'T'HH:mmZZZZZ",
        "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd HH:mm:ss Z",
        "yyyy-MM-dd HH:mm:ss",
        "yyyy-MM-dd",
    ].map {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = $0
        return f
    }

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoPlain = ISO8601DateFormatter()

    static func parse(_ raw: String) -> Date? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        // "+0000 (UTC)" and similar trailing comments.
        if let paren = s.range(of: " (") { s = String(s[..<paren.lowerBound]) }
        // "UT" isn't understood by DateFormatter; "GMT" is.
        if s.hasSuffix(" UT") { s = String(s.dropLast(2)) + "GMT" }
        lock.lock()
        defer { lock.unlock() }
        if let d = iso.date(from: s) ?? isoPlain.date(from: s) { return d }
        for f in rfc822 {
            if let d = f.date(from: s) { return d }
        }
        return nil
    }
}
