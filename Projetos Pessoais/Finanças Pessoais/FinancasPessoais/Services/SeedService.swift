import Foundation
import SwiftData

@MainActor
enum SeedService {
    static func seedIfNeeded(in context: ModelContext) throws {
        let existingCategories = try context.fetch(FetchDescriptor<FinanceCategory>())
        let isFirstSeed = existingCategories.isEmpty
        var categoriesByName: [String: FinanceCategory] = [:]
        existingCategories.forEach {
            categoriesByName[CategorizationService.normalize($0.name)] = $0
        }

        // Public example data: these neutral categories are created only on a
        // fresh installation and can be renamed or removed by the user.
        let requiredNames = [
            "Alimentação",
            "Transportes",
            "Habitação",
            "Saúde",
            "Lazer",
            "Outros"
        ]
        for name in requiredNames {
            let normalizedName = CategorizationService.normalize(name)
            guard categoriesByName[normalizedName] == nil else { continue }
            let category = FinanceCategory(name: name)
            context.insert(category)
            categoriesByName[normalizedName] = category
        }

        guard isFirstSeed,
              let groceries = categoriesByName[CategorizationService.normalize("Alimentação")],
              let transport = categoriesByName[CategorizationService.normalize("Transportes")],
              let leisure = categoriesByName[CategorizationService.normalize("Lazer")] else {
            try context.save()
            return
        }

        let definitions: [(String, FinanceCategory)] = [
            ("supermercado", groceries),
            ("mercearia", groceries),
            ("padaria", groceries),
            ("metro", transport),
            ("autocarro", transport),
            ("comboio", transport),
            ("cinema", leisure),
            ("museu", leisure),
            ("livro", leisure)
        ]
        definitions.forEach { keyword, category in
            context.insert(CategorizationRule(keyword: keyword, category: category))
        }
        try context.save()
    }
}
