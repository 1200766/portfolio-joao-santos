import Foundation

enum CategorizationService {
    static func category(for details: String, rules: [CategorizationRule]) -> FinanceCategory? {
        let normalizedDetails = normalize(details)
        return rules
            .sorted { $0.createdAt < $1.createdAt }
            .first { normalizedDetails.contains(normalize($0.keyword)) }?
            .category
    }

    static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}
