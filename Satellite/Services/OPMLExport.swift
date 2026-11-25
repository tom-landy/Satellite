import Foundation
import UniformTypeIdentifiers

extension UTType {
    /// Declared in Satellite-Info.plist so .opml files open in the app.
    static let opml = UTType(importedAs: "org.opml.opml", conformingTo: .xml)
}

extension OPML {
    /// Writes the sources to a temporary file for the share sheet.
    static func exportFile(_ sources: [Source]) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Satellite Sources.opml")
        let text = export(sources.map { ($0.title, $0.feedURL) }, title: "Sites I follow in Satellite")
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }
}
