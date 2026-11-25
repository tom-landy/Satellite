import Foundation

extension String {
    /// Visible text of an HTML fragment: tags removed, entities decoded, paragraphs kept as line breaks.
    var htmlPlainText: String {
        guard contains("<") || contains("&") else {
            return trimmingCharacters(in: .whitespacesAndNewlines)
        }
        var s = replacingOccurrences(of: "<(script|style)\\b[^>]*>[\\s\\S]*?</\\1>", with: "",
                                     options: [.regularExpression, .caseInsensitive])
        s = s.replacingOccurrences(of: "<!--[\\s\\S]*?-->", with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: "<br\\s*/?>|</(p|div|li|h[1-6]|blockquote|tr|figure)>", with: "\n",
                                   options: [.regularExpression, .caseInsensitive])
        s = s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        s = s.decodingHTMLEntities
        s = s.replacingOccurrences(of: "[ \\t\\u00A0]+", with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: " *\\n *", with: "\n", options: .regularExpression)
        return s.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Plain text squashed onto one line, for titles.
    var htmlInlineText: String {
        htmlPlainText.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    /// Escapes text for use inside HTML, including attribute values.
    var escapedHTML: String {
        var s = replacingOccurrences(of: "&", with: "&amp;")
        s = s.replacingOccurrences(of: "<", with: "&lt;")
        s = s.replacingOccurrences(of: ">", with: "&gt;")
        return s.replacingOccurrences(of: "\"", with: "&quot;")
    }

    var decodingHTMLEntities: String {
        guard contains("&") else { return self }
        let ns = self as NSString
        let matches = HTMLText.entityPattern.matches(in: self, range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return self }
        var out = ""
        var last = 0
        for m in matches {
            out += ns.substring(with: NSRange(location: last, length: m.range.location - last))
            let body = ns.substring(with: m.range(at: 1))
            if let decoded = HTMLText.decodeEntity(body) {
                out += decoded
            } else {
                out += ns.substring(with: m.range)
            }
            last = m.range.location + m.range.length
        }
        out += ns.substring(from: last)
        return out
    }
}

enum HTMLText {
    static let entityPattern = try! NSRegularExpression(pattern: "&(#[0-9]{1,7}|#[xX][0-9a-fA-F]{1,6}|[a-zA-Z][a-zA-Z0-9]{1,31});")
    private static let imagePattern = try! NSRegularExpression(pattern: "<img\\b[^>]*>", options: .caseInsensitive)
    private static let srcPattern = try! NSRegularExpression(pattern: "\\ssrc\\s*=\\s*([\"'])(.*?)\\1", options: .caseInsensitive)

    private static let named: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": "\u{00A0}",
        "ndash": "–", "mdash": "—", "lsquo": "‘", "rsquo": "’", "sbquo": "‚", "ldquo": "“", "rdquo": "”",
        "bdquo": "„", "hellip": "…", "bull": "•", "middot": "·", "copy": "©", "reg": "®", "trade": "™",
        "deg": "°", "plusmn": "±", "times": "×", "divide": "÷", "frac12": "½", "frac14": "¼", "frac34": "¾",
        "euro": "€", "pound": "£", "yen": "¥", "cent": "¢", "sect": "§", "para": "¶", "laquo": "«", "raquo": "»",
        "lsaquo": "‹", "rsaquo": "›", "prime": "′", "Prime": "″", "larr": "←", "rarr": "→", "uarr": "↑", "darr": "↓",
        "thinsp": "\u{2009}", "ensp": "\u{2002}", "emsp": "\u{2003}", "zwnj": "\u{200C}", "zwj": "\u{200D}", "shy": "\u{00AD}",
        "aacute": "á", "eacute": "é", "iacute": "í", "oacute": "ó", "uacute": "ú", "Aacute": "Á", "Eacute": "É",
        "agrave": "à", "egrave": "è", "igrave": "ì", "ograve": "ò", "ugrave": "ù", "acirc": "â", "ecirc": "ê",
        "icirc": "î", "ocirc": "ô", "ucirc": "û", "auml": "ä", "euml": "ë", "iuml": "ï", "ouml": "ö", "uuml": "ü",
        "Auml": "Ä", "Ouml": "Ö", "Uuml": "Ü", "szlig": "ß", "ccedil": "ç", "Ccedil": "Ç", "ntilde": "ñ",
        "Ntilde": "Ñ", "aring": "å", "Aring": "Å", "aelig": "æ", "oslash": "ø", "Oslash": "Ø", "iexcl": "¡", "iquest": "¿",
    ]

    static func decodeEntity(_ body: String) -> String? {
        if body.hasPrefix("#") {
            let digits = body.dropFirst()
            let value: UInt32?
            if digits.first == "x" || digits.first == "X" {
                value = UInt32(digits.dropFirst(), radix: 16)
            } else {
                value = UInt32(digits)
            }
            guard let value, let scalar = Unicode.Scalar(value) else { return nil }
            return String(Character(scalar))
        }
        return named[body]
    }

    /// A short plain-text preview of an article.
    static func excerpt(fromPlainText text: String, limit: Int = 280) -> String {
        let flat = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        guard flat.count > limit else { return flat }
        let cut = flat.prefix(limit)
        if let space = cut.lastIndex(of: " ") {
            return String(cut[..<space]) + "…"
        }
        return String(cut) + "…"
    }

    static func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace }).count
    }

    /// The first real image in some HTML, skipping tracking pixels and inline data.
    static func firstImage(in html: String, base: URL?) -> URL? {
        let ns = html as NSString
        for tag in imagePattern.matches(in: html, range: NSRange(location: 0, length: ns.length)) {
            let element = ns.substring(with: tag.range)
            if element.range(of: "width=[\"']?1[\"'\\s/>]", options: .regularExpression) != nil { continue }
            let el = element as NSString
            guard let src = srcPattern.firstMatch(in: element, range: NSRange(location: 0, length: el.length)) else { continue }
            let value = el.substring(with: src.range(at: 2)).decodingHTMLEntities
                .trimmingCharacters(in: .whitespaces)
            if value.isEmpty || value.hasPrefix("data:") { continue }
            if let url = URL(string: value, relativeTo: base)?.absoluteURL, url.scheme?.hasPrefix("http") == true {
                return url
            }
        }
        return nil
    }
}
