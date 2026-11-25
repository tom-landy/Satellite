// Runs FeedKit against real feeds and real sites. Network-dependent, so CI runs it
// without failing the build:
//   swiftc Satellite/FeedKit/*.swift tools/feedcheck/main.swift -o /tmp/feedcheck
//   /tmp/feedcheck tools/feedcheck/feeds.opml
import Foundation

let args = CommandLine.arguments
guard args.count > 1, let opml = FileManager.default.contents(atPath: args[1]), let feeds = try? OPML.parse(opml) else {
    print("usage: feedcheck feeds.opml"); exit(2)
}

var failures = 0

print("Feeds\n")
for feed in feeds {
    let start = Date()
    do {
        let first = try await FeedFetcher.fetch(feed.url)
        guard let parsed = first.feed else { throw FeedError.notAFeed }
        let ms = Int(Date().timeIntervalSince(start) * 1000)
        let dated = parsed.items.filter { $0.date != nil }.count
        let withBody = parsed.items.filter { $0.wordCount > 0 }.count
        let withLink = parsed.items.filter { $0.link != nil }.count
        // A second fetch with the validators should come back as "not modified" on servers that support it.
        let second = try await FeedFetcher.fetch(feed.url, etag: first.etag, lastModified: first.lastModified)
        let conditional = second.feed == nil ? "304" : (first.etag == nil && first.lastModified == nil ? "no validators" : "200 again")
        print("ok   \(feed.title): \"\(parsed.title)\", \(parsed.items.count) items, \(dated) dated, \(withBody) with text, \(withLink) linked, refetch \(conditional), \(ms) ms")
        if parsed.items.isEmpty || dated < parsed.items.count / 2 || withLink == 0 {
            failures += 1
            print("     ^ suspicious")
        }
        if let item = parsed.items.first {
            print("     newest: \(item.title.prefix(70)) | \(item.date.map { "\($0)" } ?? "no date") | \(item.wordCount) words")
        }
    } catch {
        failures += 1
        print("FAIL \(feed.title): \(error)")
    }
}

print("\nDiscovery\n")
for site in ["daringfireball.net", "https://www.theverge.com", "sixcolors.com", "https://www.swift.org/blog/", "kottke.org"] {
    do {
        let found = try await FeedDiscovery.discover(site)
        print("ok   \(site) -> \(found.map { "\($0.title) <\($0.url.absoluteString)>" }.joined(separator: ", "))")
    } catch {
        failures += 1
        print("FAIL \(site): \(error)")
    }
}

print("\n\(failures) problem(s)")
exit(failures == 0 ? 0 : 1)
