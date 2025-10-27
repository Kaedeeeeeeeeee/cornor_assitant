import Foundation

protocol SearchProvider {
    func searchURL(for query: String) -> URL?
    func suggestions(for query: String) async throws -> [String]
}

extension SearchProvider {
    func normalizedURL(from input: String) -> URL? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed),
           let scheme = url.scheme, !scheme.isEmpty,
           url.host != nil {
            return url
        }

        if trimmed.rangeOfCharacter(from: .whitespacesAndNewlines) != nil {
            return nil
        }

        let prefixed = "https://\(trimmed)"
        guard let candidate = URL(string: prefixed),
              let host = candidate.host,
              host.contains(".") || host == "localhost" else {
            return nil
        }

        return candidate
    }
}
