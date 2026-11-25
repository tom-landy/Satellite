// Offline checks for FeedKit against the fixtures in tools/feedtest/fixtures.
// Runs in CI on every push, and on Linux too:
//   swiftc Satellite/FeedKit/*.swift tools/feedtest/main.swift -o /tmp/feedtest
//   /tmp/feedtest tools/feedtest/fixtures
import Foundation

let dir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "tools/feedtest/fixtures")
var failures = 0
var checks = 0

func check(_ condition: @autoclosure () -> Bool, _ message: String, line: Int = #line) {
    checks += 1
    if !condition() {
        failures += 1
        print("FAIL (line \(line)): \(message)")
    }
}

func load(_ name: String, url: String) -> ParsedFeed? {
    do {
        let data = try Data(contentsOf: dir.appendingPathComponent(name))
        return try FeedParser.parse(data, url: URL(string: url))
    } catch {
        failures += 1
        print("FAIL: \(name) did not parse: \(error)")
        return nil
    }
}

func date(_ iso: String) -> Date { ISO8601DateFormatter().date(from: iso)! }

// RSS 2.0
if let feed = load("rss.xml", url: "https://blog.example.com/feed") {
    check(feed.title == "Sample & Co Blog", "rss title: \(feed.title)")
    check(feed.siteURL?.absoluteString == "https://blog.example.com/", "rss site: \(String(describing: feed.siteURL))")
    check(feed.iconURL?.absoluteString == "https://blog.example.com/icon.png", "rss icon")
    check(feed.items.count == 3, "rss item count: \(feed.items.count)")
    if feed.items.count == 3 {
        let a = feed.items[0], b = feed.items[1], c = feed.items[2]
        check(a.id == "post-1", "rss guid: \(a.id)")
        check(a.title == "First post ’s title", "rss numeric entity in title: \(a.title)")
        check(a.link?.absoluteString == "https://blog.example.com/2026/11/first-post", "rss relative link: \(String(describing: a.link))")
        check(a.author == "Jane Writer", "rss dc:creator: \(a.author)")
        check(a.published == date("2026-11-24T09:30:00Z"), "rss pubDate: \(String(describing: a.published))")
        check(a.contentHTML.contains("<b>world</b>"), "rss content:encoded kept as HTML: \(a.contentHTML)")
        check(a.summaryHTML == "A short summary.", "rss description: \(a.summaryHTML)")
        check(a.imageURL?.absoluteString == "https://blog.example.com/images/hero.jpg", "rss image from content: \(String(describing: a.imageURL))")
        check(a.wordCount == 5, "rss word count: \(a.wordCount)")
        check(b.id == "https://blog.example.com/2026/11/second", "rss id falls back to link: \(b.id)")
        check(b.author == "Jane Writer", "rss author email form: \(b.author)")
        check(b.published == date("2026-11-23T18:00:00Z"), "rss GMT date")
        check(b.summaryHTML == "<p>Escaped <em>HTML</em> summary</p>", "rss escaped description: \(b.summaryHTML)")
        check(b.audioURL?.absoluteString == "https://blog.example.com/a.mp3", "rss audio enclosure")
        check(b.imageURL?.absoluteString == "https://blog.example.com/thumb.jpg", "rss media:thumbnail")
        check(b.excerpt == "Escaped HTML summary", "rss excerpt: \(b.excerpt)")
        check(c.summaryHTML.contains("<a href=\"https://x.example/?a=1&amp;b=2\">link</a>"), "rss raw markup rebuilt: \(c.summaryHTML)")
        check(c.summaryHTML.contains("&amp; text"), "rss raw markup text escaped: \(c.summaryHTML)")
        check(c.published == date("2026-11-22T08:00:00Z"), "rss UT date: \(String(describing: c.published))")
    }
}

// Atom
if let feed = load("atom.xml", url: "https://atom.example.org/feed.atom") {
    check(feed.title == "Atom & Friends", "atom html title: \(feed.title)")
    check(feed.siteURL?.absoluteString == "https://atom.example.org/", "atom site: \(String(describing: feed.siteURL))")
    check(feed.iconURL?.absoluteString == "https://atom.example.org/favicon.png", "atom relative icon: \(String(describing: feed.iconURL))")
    check(feed.items.count == 2, "atom entries: \(feed.items.count)")
    if feed.items.count == 2 {
        let a = feed.items[0], b = feed.items[1]
        check(a.id == "tag:atom.example.org,2026:1", "atom id")
        check(a.link?.absoluteString == "https://atom.example.org/posts/xhtml", "atom alternate link: \(String(describing: a.link))")
        check(a.author == "Alex Atom", "atom author: \(a.author)")
        check(abs((a.published ?? .distantPast).timeIntervalSince(date("2026-11-24T07:15:30Z"))) < 1, "atom fractional date: \(String(describing: a.published))")
        check(a.contentHTML.contains("<a href=\"/rel\">relative link</a>"), "atom xhtml rebuilt: \(a.contentHTML)")
        check(a.contentHTML.contains("3 &lt; 4"), "atom xhtml text escaped: \(a.contentHTML)")
        check(a.contentHTML.contains("<br>") && !a.contentHTML.contains("</br>"), "atom void elements: \(a.contentHTML)")
        check(a.imageURL?.absoluteString == "https://atom.example.org/pic.png", "atom image from content")
        check(b.published == nil && b.date == date("2026-11-23T09:00:00Z"), "atom updated as date")
        check(b.summaryHTML == "<p>Summary only</p>" && b.bodyHTML == b.summaryHTML, "atom summary: \(b.summaryHTML)")
    }
}

// RSS 1.0
if let feed = load("rdf.xml", url: "https://rdf.example.net/index.rdf") {
    check(feed.title == "RDF Site", "rdf title")
    check(feed.items.count == 1 && feed.items.first?.id == "https://rdf.example.net/one", "rdf item about")
    check(feed.items.first?.published == date("2026-11-20T12:00:00Z"), "rdf dc:date")
}

// JSON Feed
if let feed = load("feed.json", url: "https://json.example.com/feed.json") {
    check(feed.title == "JSON Feed Blog", "json title")
    check(feed.items.count == 2, "json items")
    if feed.items.count == 2 {
        check(feed.items[0].id == "42", "json numeric id")
        check(feed.items[0].author == "Jo Json", "json feed author")
        check(feed.items[0].published == date("2026-11-24T15:00:00Z"), "json date")
        check(feed.items[1].contentHTML == "<p>Line one</p><p>Line two &amp; more</p>", "json content_text: \(feed.items[1].contentHTML)")
        check(feed.items[1].title == "Line one Line two & more", "json title from text: \(feed.items[1].title)")
    }
}

// A feed with an HTML entity XML doesn't know keeps what came before it.
if let feed = load("broken.xml", url: "https://broken.example/rss") {
    check(feed.items.count >= 1 && feed.items[0].title == "Good item", "broken feed keeps early items: \(feed.items.map(\.title))")
}

// Not a feed
do {
    _ = try FeedParser.parse(try Data(contentsOf: dir.appendingPathComponent("page.html")))
    check(false, "HTML page should not parse as a feed")
} catch {
    check(true, "")
}

// Discovery from a page's <link> tags
if let html = try? String(contentsOf: dir.appendingPathComponent("page.html"), encoding: .utf8) {
    let found = FeedDiscovery.links(inHTML: html, base: URL(string: "https://example.com/blog/")!)
    check(found.map(\.url.absoluteString) == ["https://example.com/feed/", "https://example.com/atom.xml"], "discovery: \(found)")
    check(found.first?.title == "Example » Feed", "discovery title: \(found.first?.title ?? "")")
    check(found.last?.title == "Example & Site", "discovery falls back to page title: \(found.last?.title ?? "")")
}
check(FeedDiscovery.normalise("daringfireball.net")?.absoluteString == "https://daringfireball.net", "normalise bare host")
check(FeedDiscovery.normalise("feed://example.com/rss")?.absoluteString == "https://example.com/rss", "normalise feed://")
check(FeedDiscovery.normalise("not a url") == nil, "normalise rejects junk")

// OPML
if let data = try? Data(contentsOf: dir.appendingPathComponent("subs.opml")), let feeds = try? OPML.parse(data) {
    check(feeds.map(\.url.absoluteString) == ["https://a.example/feed", "https://b.example/rss"], "opml feeds: \(feeds)")
    check(feeds.first?.title == "A Blog", "opml title")
    let round = try? OPML.parse(Data(OPML.export(feeds.map { ($0.title, $0.url) }, title: "Test").utf8))
    check(round == feeds, "opml export round trip")
} else {
    check(false, "opml parse")
}

// Text helpers
check("Tom &amp; Jerry&#x2019;s &unknown; &#169;".decodingHTMLEntities == "Tom & Jerry’s &unknown; ©", "entities")
check("<p>One</p><p>Two<br>Three</p><script>x()</script>".htmlPlainText == "One\nTwo\nThree", "plain text: \("<p>One</p><p>Two<br>Three</p>".htmlPlainText)")
check(HTMLText.excerpt(fromPlainText: "one two three four", limit: 9) == "one two…", "excerpt")
check(HTMLText.firstImage(in: "<img src=\"p.gif\" width=\"1\" height=\"1\"><img alt='x' src='data:abc'><img src=\"/a.jpg\">",
                          base: URL(string: "https://s.example/post/"))?.absoluteString == "https://s.example/a.jpg", "first image skips pixels")
check(FeedDates.parse("Tue, 5 Nov 2024 10:00:00 +0000") == date("2024-11-05T10:00:00Z"), "single digit day")
check(FeedDates.parse("Tue, 05 Nov 2024 10:00:00 EST") == date("2024-11-05T15:00:00Z"), "named zone")
check(FeedDates.parse("2024-11-05") == date("2024-11-05T00:00:00Z"), "date only")

print("\(checks - failures)/\(checks) checks passed")
exit(failures == 0 ? 0 : 1)
