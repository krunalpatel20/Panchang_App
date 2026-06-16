import Foundation
import OSLog

private let log = Logger(subsystem: "com.panchang", category: "ContentStore")

/// Loads and vends `ContentEntry` values decoded from `content.json` in the app bundle.
/// Missing or malformed files produce an empty store with a logged warning — no crash.
struct ContentStore: Sendable {
    let allEntries: [ContentEntry]

    static let shared: ContentStore = {
        guard let url = Bundle.main.url(forResource: "content", withExtension: "json", subdirectory: "Content")
                     ?? Bundle.main.url(forResource: "content", withExtension: "json") else {
            log.warning("content.json not found in bundle — ContentStore is empty")
            return ContentStore(entries: [])
        }
        do {
            let data = try Data(contentsOf: url)
            let payload = try JSONDecoder().decode(ContentPayload.self, from: data)
            var entries = payload.entries

            // Merge regional content (optional — missing file is not an error)
            let regionalURL = Bundle.main.url(forResource: "content-regional", withExtension: "json", subdirectory: "Content")
                           ?? Bundle.main.url(forResource: "content-regional", withExtension: "json")
            if let regionalURL,
               let regionalData = try? Data(contentsOf: regionalURL),
               let regionalPayload = try? JSONDecoder().decode(ContentPayload.self, from: regionalData) {
                entries += regionalPayload.entries
            }

            return ContentStore(entries: entries)
        } catch {
            log.warning("content.json failed to decode: \(error) — ContentStore is empty")
            return ContentStore(entries: [])
        }
    }()

    private init(entries: [ContentEntry]) {
        self.allEntries = entries
    }

    func entry(for id: String) -> ContentEntry? {
        allEntries.first { $0.id == id }
    }

    /// Returns true if any authored ContentEntry covers the given festival rule ID,
    /// using the same prefix/suffix matching as the festival detail lookup.
    func hasContent(forFestivalId id: String) -> Bool {
        allEntries.contains {
            $0.id == id ||
            id.hasPrefix($0.id + "_") ||
            id.hasSuffix("_" + $0.id)
        }
    }
}

// MARK: - JSON wrapper

private struct ContentPayload: Codable {
    let entries: [ContentEntry]
}
