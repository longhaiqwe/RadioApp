import Foundation
import Combine

class SearchHistoryManager: ObservableObject {
    static let shared = SearchHistoryManager()
    
    @Published var history: [String] = []
    private let historyKey = "search_history"
    private let maxHistoryItems = 20
    
    private init() {
        loadHistory()
    }
    
    func addHistory(_ query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return }
        
        // 移除已存在的相同搜索词
        history.removeAll { $0.lowercased() == trimmedQuery.lowercased() }
        
        // 插入到开头
        history.insert(trimmedQuery, at: 0)
        
        // 限制数量
        if history.count > maxHistoryItems {
            history = Array(history.prefix(maxHistoryItems))
        }
        
        saveHistory()
    }
    
    func removeHistory(_ query: String) {
        history.removeAll { $0 == query }
        saveHistory()
    }
    
    func clearHistory() {
        history = []
        saveHistory()
    }
    
    private func saveHistory() {
        UserDefaults.standard.set(history, forKey: historyKey)
    }
    
    private func loadHistory() {
        if let savedHistory = UserDefaults.standard.stringArray(forKey: historyKey) {
            self.history = savedHistory
        }
    }
}
