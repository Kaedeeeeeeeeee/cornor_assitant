import Foundation
import Combine

struct OCRHistoryItem: Identifiable, Codable, Equatable {
    let id: UUID
    let text: String
    let timestamp: Date
    
    init(id: UUID = UUID(), text: String, timestamp: Date = Date()) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
    }
}

class OCRHistoryManager: ObservableObject {
    static let shared = OCRHistoryManager()
    
    @Published var history: [OCRHistoryItem] = [] {
        didSet {
            save()
        }
    }
    
    private let maxHistoryCount = 20
    private let storageKey = "OCRHistory"
    
    private init() {
        load()
    }
    
    func add(_ text: String) {
        let item = OCRHistoryItem(text: text)
        // Insert at beginning
        history.insert(item, at: 0)
        // Trim
        if history.count > maxHistoryCount {
            history = Array(history.prefix(maxHistoryCount))
        }
    }
    
    func clear() {
        history = []
    }
    
    private func save() {
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let items = try? JSONDecoder().decode([OCRHistoryItem].self, from: data) {
            self.history = items
        }
    }
    
    var recentItems: [OCRHistoryItem] {
        Array(history.prefix(5))
    }
    
    var lastResult: OCRHistoryItem? {
        history.first
    }
}
