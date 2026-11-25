import Foundation
import SwiftUI

enum Typeface: String, CaseIterable, Identifiable {
    case system, serif

    static let storageKey = "readerTypeface"
    var id: String { rawValue }
    var name: String { self == .system ? "San Francisco" : "New York" }
    var cssFamily: String { self == .system ? "-apple-system, system-ui, sans-serif" : "ui-serif, 'New York', Georgia, serif" }
    var design: Font.Design { self == .system ? .default : .serif }
}

/// How articles look. Changes redraw the visible pages.
struct ReaderStyle: Equatable {
    static let scaleKey = "readerTextScale"
    static let scales: [Double] = [0.85, 0.92, 1.0, 1.08, 1.16, 1.25, 1.35, 1.5]

    var typeface: Typeface = .system
    /// Multiplies the Dynamic Type body size.
    var textScale: Double = 1.0
    var theme: AccentTheme = .standard
}

/// Turns an article into the page the reader shows: title, byline, then the article
/// in a clean single column. Page scripts never run (see ArticlePageController).
@MainActor
enum ArticleRenderer {
    /// Links with this scheme are buttons inside the page, handled by the app.
    static let actionScheme = "satellite-action"

    static func html(for article: Article, style: ReaderStyle) -> String {
        let body = clean(article.bodyHTML)
        var meta: [String] = []
        if !article.author.isEmpty { meta.append(article.author.escapedHTML) }
        meta.append(article.date.articleDate.escapedHTML)
        if article.wordCount > 120 || article.showsFullText { meta.append("\(article.readingMinutes) min read") }

        var hero = ""
        if let image = article.imageURL, !body.contains(image.lastPathComponent) {
            hero = "<figure class=\"hero\"><img src=\"\(image.absoluteString.escapedHTML)\" alt=\"\"></figure>"
        }

        var notes = ""
        if article.showsFullText {
            notes = "<p class=\"note\">Full article from the website · <a href=\"\(actionScheme):fulltext\">Show the feed's version</a></p>"
        }

        var footer = ""
        if article.isTeaser && !article.showsFullText {
            footer += "<a class=\"button primary\" href=\"\(actionScheme):fulltext\">Load the Full Article</a>"
        }
        if let audio = article.audioURL {
            footer += "<a class=\"button\" href=\"\(audio.absoluteString.escapedHTML)\">Play the Audio</a>"
        }
        if let link = article.link {
            footer += "<a class=\"button\" href=\"\(link.absoluteString.escapedHTML)\">Open \((link.host() ?? "Website").replacingOccurrences(of: "www.", with: "").escapedHTML)</a>"
        }

        let titleHTML: String
        if let link = article.link {
            titleHTML = "<a href=\"\(link.absoluteString.escapedHTML)\">\(article.title.escapedHTML)</a>"
        } else {
            titleHTML = article.title.escapedHTML
        }

        return """
        <!doctype html>
        <html><head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
        <meta http-equiv="Content-Security-Policy" content="script-src 'none'; object-src 'none'">
        <style>\(css(style))</style>
        </head><body>
        <header>
          <h1>\(titleHTML)</h1>
          <div class="meta">\(meta.joined(separator: " · "))</div>
        </header>
        \(notes)
        \(hero)
        <article>\(body)</article>
        <footer>\(footer)</footer>
        </body></html>
        """
    }

    /// Strips what never belongs in a reading view.
    private static func clean(_ html: String) -> String {
        var s = html
        for pattern in ["<script\\b[\\s\\S]*?</script>", "<style\\b[\\s\\S]*?</style>", "<link\\b[^>]*>", "<meta\\b[^>]*>",
                        "<form\\b[\\s\\S]*?</form>", "\\son[a-z]+\\s*=\\s*(\"[^\"]*\"|'[^']*')"] {
            s = s.replacingOccurrences(of: pattern, with: "", options: [.regularExpression, .caseInsensitive])
        }
        // Lazy-loading images keep the real address in data-src.
        s = s.replacingOccurrences(of: "<img([^>]*?)\\sdata-src=", with: "<img$1 src=",
                                   options: [.regularExpression, .caseInsensitive])
        return s
    }

    private static func hex(_ value: UInt32) -> String { String(format: "#%06X", value) }

    private static func css(_ style: ReaderStyle) -> String {
        // The same light and dark accent shades as the rest of the app (AccentTheme.color).
        let accent = style.theme.hexValues.base
        let lightAccent = hex(style.theme.lightHex)
        let percent = Int((style.textScale * 100).rounded())
        return """
        :root { color-scheme: light dark; --accent: \(lightAccent); --text: #1C1C1E; --secondary: #6C6C70;
                --rule: rgba(60,60,67,0.18); --code: rgba(118,118,128,0.12); }
        @media (prefers-color-scheme: dark) {
          :root { --accent: \(hex(accent)); --text: #E8E8ED; --secondary: #98989F; --rule: rgba(84,84,88,0.6); --code: rgba(118,118,128,0.24); }
        }
        html { font: -apple-system-body; -webkit-text-size-adjust: none; }
        body { font-family: \(style.typeface.cssFamily); font-size: \(percent)%; line-height: 1.6; color: var(--text);
               background: transparent; margin: 0 auto; max-width: 42em;
               padding: 20px max(22px, env(safe-area-inset-right)) 48px max(22px, env(safe-area-inset-left));
               overflow-wrap: break-word; word-wrap: break-word; -webkit-hyphens: auto; hyphens: auto; }
        header { margin-bottom: 1.4em; }
        h1 { font-size: 1.6em; line-height: 1.2; margin: 0 0 0.4em; font-weight: 700; -webkit-hyphens: manual; hyphens: manual; }
        h1 a { color: inherit; text-decoration: none; }
        .meta, .note { font: -apple-system-subheadline; font-family: -apple-system, system-ui; color: var(--secondary); }
        .note { margin: -0.6em 0 1.4em; }
        a { color: var(--accent); text-decoration-thickness: 1px; text-underline-offset: 2px; }
        article { font-size: 1em; }
        article > :first-child { margin-top: 0; }
        h2, h3, h4 { line-height: 1.3; margin: 1.6em 0 0.5em; }
        h2 { font-size: 1.25em; } h3 { font-size: 1.1em; } h4 { font-size: 1em; }
        p, ul, ol, figure, blockquote, pre, table { margin: 0 0 1em; }
        img, video, iframe, svg, picture { max-width: 100% !important; height: auto !important; border-radius: 8px; }
        img[width="1"], img[height="1"] { display: none; }
        figure { margin-left: 0; margin-right: 0; }
        figure.hero { margin: 0 0 1.4em; }
        figure.hero img { width: 100%; }
        figcaption { font: -apple-system-footnote; color: var(--secondary); margin-top: 0.4em; }
        blockquote { margin-left: 0; padding-left: 1em; border-left: 3px solid var(--accent); color: var(--secondary); }
        pre, code { font-family: ui-monospace, Menlo, monospace; font-size: 0.85em; background: var(--code); border-radius: 6px; }
        code { padding: 0.1em 0.3em; }
        pre { padding: 0.8em 1em; white-space: pre-wrap; }
        pre code { background: none; padding: 0; font-size: 1em; }
        table { display: block; overflow-x: auto; border-collapse: collapse; font-size: 0.9em; }
        td, th { border: 1px solid var(--rule); padding: 0.3em 0.6em; }
        hr { border: none; border-top: 1px solid var(--rule); margin: 2em 0; }
        footer { margin-top: 2.4em; padding-top: 1.4em; border-top: 1px solid var(--rule); display: flex; flex-direction: column; gap: 10px; }
        footer:empty { display: none; }
        .button { display: block; text-align: center; font: -apple-system-headline; font-family: -apple-system, system-ui;
                  padding: 13px; border-radius: 12px; text-decoration: none; background: var(--code); color: var(--accent); }
        .button.primary { background: var(--accent); color: white; }
        @media (prefers-color-scheme: dark) { .button.primary { color: black; } }
        """
    }
}
