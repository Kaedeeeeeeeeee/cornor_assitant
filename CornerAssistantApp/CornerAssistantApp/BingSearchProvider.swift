import Foundation

struct BingSearchProvider: SearchProvider {
    func normalizedURL(from input: String) -> URL? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), url.scheme?.isEmpty == false {
            return url
        }

        guard !trimmed.contains(" ") else { return nil }

        var candidate = trimmed
        if !candidate.lowercased().hasPrefix("http://") && !candidate.lowercased().hasPrefix("https://") {
            candidate = "https://\(candidate)"
        }

        guard let url = URL(string: candidate), url.host != nil else {
            return nil
        }

        return url
    }

    func searchURL(for query: String) -> URL? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var components = URLComponents(string: "https://www.bing.com/search")
        components?.queryItems = [
            URLQueryItem(name: "q", value: trimmed)
        ]
        return components?.url
    }

    func suggestions(for query: String) async throws -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var components = URLComponents(string: "https://api.bing.com/osjson.aspx")
        components?.queryItems = [
            URLQueryItem(name: "query", value: trimmed)
        ]

        guard let url = components?.url else { return [] }

        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        guard let array = json as? [Any], array.count >= 2 else { return [] }
        guard let suggestions = array[1] as? [String] else { return [] }
        return suggestions
    }
}
