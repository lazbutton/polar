import CoreSpotlight
import Foundation
import UniformTypeIdentifiers
#if os(iOS)
import FoundationModels
import _CoreSpotlight_FoundationModels
#endif

enum SpotlightIndex {
    static func index(_ moment: Moment) {
        let set = CSSearchableItemAttributeSet(contentType: .text)
        set.title = "Moment"
        set.textContent = [moment.emotionLabel, moment.thought, moment.behavior]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        let item = CSSearchableItem(
            uniqueIdentifier: String(describing: moment.persistentModelID),
            domainIdentifier: "fr.laz.polar.moments",
            attributeSet: set
        )
        CSSearchableIndex.default().indexSearchableItems([item])
    }

    static func remove(_ moment: Moment) {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [String(describing: moment.persistentModelID)])
    }
}

enum NoteSearch {
    static func local(query: String, moments: [Moment]) -> [Moment] {
        let terms = query
            .split(separator: " ")
            .map { $0.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: French.locale) }
            .filter { !$0.isEmpty }
        guard !terms.isEmpty else { return [] }
        return moments.filter { moment in
            let haystack = [moment.emotionLabel, moment.thought, moment.behavior]
                .compactMap { $0 }
                .joined(separator: " ")
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: French.locale)
            return terms.allSatisfy { haystack.contains($0) }
        }
    }

    #if os(iOS)
    @available(iOS 27, *)
    @MainActor
    static func answer(query: String) async -> String? {
        guard Preferences.shared.aiEnabled else { return nil }
        guard case .available = SystemLanguageModel.default.availability else { return nil }
        let tool = SpotlightSearchTool(configuration: .init(sources: [.coreSpotlight]))
        let session = LanguageModelSession(
            tools: [tool],
            instructions: """
                Tu cherches dans les notes Polar déjà indexées sur cet iPhone.
                Tu cites ce qui est écrit. Tu n'interprètes pas, tu ne conseilles pas, \
                tu ne poses aucun diagnostic. Si tu ne trouves rien, tu le dis.
                """
        )
        return try? await session.respond(to: query).content
    }
    #endif
}
