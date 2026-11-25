import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct FeedResponse: Sendable {
    /// nil when the server said nothing has changed since the last fetch (HTTP 304).
    var feed: ParsedFeed?
    var etag: String?
    var lastModified: String?
}

enum FeedFetcher {
    static let userAgent = "Satellite/1.0 (RSS reader)"

    /// Fetches and parses a feed. Passing the ETag and Last-Modified from the previous fetch lets
    /// the server answer "not modified" with no body, which is most refreshes for most feeds.
    static func fetch(_ url: URL, etag: String? = nil, lastModified: String? = nil,
                      session: URLSession = .shared) async throws -> FeedResponse {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/rss+xml, application/atom+xml, application/feed+json, application/xml;q=0.9, */*;q=0.8",
                         forHTTPHeaderField: "Accept")
        if let etag { request.setValue(etag, forHTTPHeaderField: "If-None-Match") }
        if let lastModified { request.setValue(lastModified, forHTTPHeaderField: "If-Modified-Since") }

        let (data, response) = try await session.data(for: request)
        let http = response as? HTTPURLResponse
        let status = http?.statusCode ?? 200
        if status == 304 {
            return FeedResponse(feed: nil, etag: etag, lastModified: lastModified)
        }
        guard (200..<300).contains(status) else { throw FeedError.http(status) }
        let feed = try FeedParser.parse(data, url: response.url ?? url)
        return FeedResponse(feed: feed,
                            etag: http?.value(forHTTPHeaderField: "ETag"),
                            lastModified: http?.value(forHTTPHeaderField: "Last-Modified"))
    }

    /// Any page, for feed discovery. Returns the body and the address after redirects.
    static func fetchPage(_ url: URL) async throws -> (Data, URL) {
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw FeedError.http(http.statusCode)
        }
        return (data, response.url ?? url)
    }
}
