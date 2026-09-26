import Foundation
#if os(iOS)
import FoundationModels

@Generable
struct MomentDraft {
    @Guide(description: "Émotion principale", .anyOf(EmotionCatalog.keys))
    var emotion: String

    @Guide(description: "Intensité ressentie", .range(0...10))
    var intensity: Int

    @Guide(description: "La pensée, avec les mots de la personne, à la première personne. Vide si rien n'est dit.")
    var thought: String

    @Guide(description: "Ce que la personne a fait ou a envie de faire. Vide si rien n'est dit.")
    var behavior: String
}

enum DraftResult: Sendable {
    case draft(emotion: String, intensity: Int, thought: String, behavior: String)
    case unavailable
    case support
}

@MainActor
enum AIService {
    static let instructions = """
        Tu ranges une note personnelle en trois champs : émotion, pensée, comportement.
        Reprends les mots de la personne. N'interprète pas, ne conseille pas, \
        ne pose aucun diagnostic. Si une information manque, laisse le champ vide.
        """

    static func makeDraft(from transcript: String) async -> DraftResult {
        if Distress.containsSignal(transcript) { return .support }
        guard case .available = SystemLanguageModel.default.availability else { return .unavailable }
        let session = LanguageModelSession(instructions: instructions)
        do {
            let response = try await session.respond(to: transcript, generating: MomentDraft.self)
            let draft = response.content
            return .draft(
                emotion: draft.emotion,
                intensity: min(max(draft.intensity, 0), 10),
                thought: draft.thought,
                behavior: draft.behavior
            )
        } catch LanguageModelSession.GenerationError.guardrailViolation {
            return .support
        } catch {
            return .unavailable
        }
    }

    static func factualSummary(of facts: [String]) async -> String {
        let joined = facts.joined(separator: "\n")
        guard !facts.isEmpty else { return "Rien à résumer." }
        guard Preferences.shared.aiEnabled, case .available = SystemLanguageModel.default.availability else {
            return facts.joined(separator: "\n")
        }
        let session = LanguageModelSession(instructions: """
            Tu reformules ces constats en quelques phrases courtes.
            Tu n'ajoutes aucun fait, aucun conseil, aucun diagnostic.
            """)
        do {
            let response = try await session.respond(to: joined)
            return response.content
        } catch {
            return facts.joined(separator: "\n")
        }
    }

}
#endif
