import Foundation

struct GoogleSearchProvider: SearchProvider {
    private let suggestionEndpoint = "https://suggestqueries.google.com/complete/search"

    func searchURL(for query: String) -> URL? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var components = URLComponents(string: "https://www.google.com/search")
        components?.queryItems = [
            URLQueryItem(name: "q", value: trimmed)
        ]
        return components?.url
    }

    func suggestions(for query: String) async throws -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var components = URLComponents(string: suggestionEndpoint)
        components?.queryItems = [
            URLQueryItem(name: "client", value: "firefox"),
            URLQueryItem(name: "q", value: trimmed)
        ]

        guard let url = components?.url else { return [] }

        let (data, _) = try await URLSession.shared.data(from: url)
        return try parseSuggestions(from: data)
    }

    private func parseSuggestions(from data: Data) throws -> [String] {
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        guard let array = json as? [Any], array.count >= 2 else { return [] }
        guard let suggestions = array[1] as? [String] else { return [] }
        return suggestions
    }
}
