import Foundation
import Combine

@MainActor
final class SuggestionStore: ObservableObject {
    @Published var suggestions: [String] = []

    private let provider: GoogleSearchProvider
    private let minimumCharacters = 2
    private let debounceInterval: UInt64 = 220_000_000 // 0.22s
    private var task: Task<Void, Never>?

    init(provider: GoogleSearchProvider) {
        self.provider = provider
    }

    func update(query: String) {
        task?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= minimumCharacters else {
            suggestions = []
            return
        }

        task = Task { [weak self] in
            guard let self else { return }

            do {
                try await Task.sleep(nanoseconds: debounceInterval)
                let suggestions = try await provider.suggestions(for: trimmed)
                guard !Task.isCancelled else { return }
                self.suggestions = suggestions
            } catch is CancellationError {
                // Ignore cancellations
            } catch {
                guard !Task.isCancelled else { return }
                self.suggestions = []
            }
        }
    }

    func clear() {
        task?.cancel()
        suggestions = []
    }
}
