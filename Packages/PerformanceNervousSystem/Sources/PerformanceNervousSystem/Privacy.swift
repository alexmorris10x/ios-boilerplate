import Foundation

public enum PerformancePrivacy {
    public static let defaultAllowedMetadataKeys: Set<String> = [
        "actor", "cache", "cachehit", "cached", "category", "contentkind", "count",
        "environment", "errorcode", "frames", "from", "itemcount", "kind", "mode",
        "operation", "phase", "qascenario", "reason", "result", "rolecount", "screen",
        "sort", "sourcekind", "status", "store", "to", "trigger", "visiblecount",
    ]

    public static func normalizedKey(_ value: String) -> String {
        value.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    public static func sanitizedLabel(_ value: String, fallback: String = "redacted") -> String {
        let candidate = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty, candidate.count <= 64, candidate == candidate.lowercased() else {
            return fallback
        }
        guard candidate.allSatisfy({ $0.isLetter || $0.isNumber || "-_.".contains($0) }) else {
            return fallback
        }
        return candidate
    }

    public static func sanitizedMetadata(
        _ metadata: [String: String],
        allowedKeys: Set<String> = defaultAllowedMetadataKeys
    ) -> [String: String] {
        metadata.reduce(into: [:]) { result, entry in
            let key = normalizedKey(entry.key)
            guard allowedKeys.contains(key), let value = sanitizedValue(entry.value) else { return }
            result[key] = value
        }
    }

    public static func sanitizedValue(_ value: String) -> String? {
        let candidate = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty, candidate.count <= 64 else { return nil }
        if Double(candidate) != nil { return candidate }
        let lowered = candidate.lowercased()
        guard lowered == candidate,
              lowered.allSatisfy({ $0.isLetter || $0.isNumber || "-_.".contains($0) })
        else { return nil }
        return lowered
    }
}
