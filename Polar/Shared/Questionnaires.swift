import Foundation

/// Une question d'un questionnaire, avec ses réponses ordonnées de 0 à n.
struct Question: Identifiable, Hashable {
    let id: Int
    let text: String
    let options: [String]
}

/// Un questionnaire validé : le point de la semaine.
struct Questionnaire: Identifiable, Hashable {
    let id: String            // phq9 · asrm · gad7
    let title: String
    let period: String
    let prompt: String?       // consigne partagée (PHQ-9, GAD-7)
    let questions: [Question]
    let publishedCutoffs: [Cutoff]

    struct Cutoff: Hashable {
        let threshold: Int
        let label: String
    }

    var maxScore: Int { questions.map { $0.options.count - 1 }.reduce(0, +) }

    /// Score brut : somme des réponses.
    func score(_ answers: [Int]) -> Int { answers.reduce(0, +) }

    /// Repère publié correspondant à un score (le plus haut atteint). nil si sous le premier seuil.
    func cutoffLabel(for score: Int) -> String? {
        publishedCutoffs.last { score >= $0.threshold }?.label
    }

    static func byID(_ id: String) -> Questionnaire? {
        all.first { $0.id == id }
    }

    static let all: [Questionnaire] = [phq9, asrm, gad7]

    /// Questionnaires du point de la semaine, selon les réglages (GAD-7 en option).
    static func weekly(includeGAD7: Bool) -> [Questionnaire] {
        includeGAD7 ? [phq9, asrm, gad7] : [phq9, asrm]
    }
}

extension Questionnaire {
    /// Échelle de fréquence partagée PHQ-9 / GAD-7 (traduction française officielle).
    private static let frequency = [
        "Jamais",
        "Plusieurs jours",
        "Plus de la moitié des jours",
        "Presque tous les jours",
    ]

    static let phq9 = Questionnaire(
        id: "phq9",
        title: "PHQ-9",
        period: "les 2 dernières semaines",
        prompt: "Au cours des 2 dernières semaines, à quelle fréquence as-tu été gêné(e) par ce problème ?",
        questions: [
            "Peu d'intérêt ou de plaisir à faire les choses",
            "Se sentir triste, déprimé(e) ou désespéré(e)",
            "Difficultés à s'endormir ou à rester endormi(e), ou dormir trop",
            "Se sentir fatigué(e) ou avoir peu d'énergie",
            "Avoir peu d'appétit ou manger trop",
            "Avoir une mauvaise opinion de soi-même, ou avoir le sentiment d'être nul(le), ou d'avoir déçu sa famille ou de ne pas avoir été à la hauteur",
            "Avoir du mal à se concentrer, par exemple pour lire le journal ou regarder la télévision",
            "Bouger ou parler si lentement que les autres ont pu le remarquer. Ou au contraire, être si agité(e) que tu bougeais beaucoup plus que d'habitude",
            "Penser qu'il vaudrait mieux mourir, ou envisager de te faire du mal d'une manière ou d'une autre",
        ].enumerated().map { Question(id: $0.offset, text: $0.element, options: frequency) },
        publishedCutoffs: [
            .init(threshold: 5, label: "léger"),
            .init(threshold: 10, label: "modéré"),
            .init(threshold: 15, label: "modérément sévère"),
            .init(threshold: 20, label: "sévère"),
        ]
    )

    static let gad7 = Questionnaire(
        id: "gad7",
        title: "GAD-7",
        period: "les 2 dernières semaines",
        prompt: "Au cours des 2 dernières semaines, à quelle fréquence as-tu été gêné(e) par ce problème ?",
        questions: [
            "Se sentir nerveux(se), anxieux(se) ou très tendu(e)",
            "Ne pas pouvoir arrêter de s'inquiéter ou ne pas pouvoir contrôler ses inquiétudes",
            "S'inquiéter trop à propos de différentes choses",
            "Avoir de la difficulté à se détendre",
            "Être si agité(e) qu'il est difficile de rester tranquille",
            "Devenir facilement contrarié(e) ou irritable",
            "Avoir peur que quelque chose d'épouvantable puisse arriver",
        ].enumerated().map { Question(id: $0.offset, text: $0.element, options: frequency) },
        publishedCutoffs: [
            .init(threshold: 5, label: "léger"),
            .init(threshold: 10, label: "modéré"),
            .init(threshold: 15, label: "sévère"),
        ]
    )

    /// ASRM (version APA « DSM-5 Level 2 — Mania — Adult »). Version française à valider avec ta psy.
    static let asrm = Questionnaire(
        id: "asrm",
        title: "ASRM",
        period: "les 7 derniers jours",
        prompt: nil,
        questions: [
            Question(id: 0, text: "Humeur", options: [
                "Je ne me sens pas plus heureux(se) ou gai(e) que d'habitude",
                "Je me sens parfois plus heureux(se) ou gai(e) que d'habitude",
                "Je me sens souvent plus heureux(se) ou gai(e) que d'habitude",
                "Je me sens la plupart du temps plus heureux(se) ou gai(e) que d'habitude",
                "Je me sens tout le temps plus heureux(se) ou gai(e) que d'habitude",
            ]),
            Question(id: 1, text: "Confiance en soi", options: [
                "Je ne me sens pas plus sûr(e) de moi que d'habitude",
                "Je me sens parfois plus sûr(e) de moi que d'habitude",
                "Je me sens souvent plus sûr(e) de moi que d'habitude",
                "Je me sens souvent extrêmement sûr(e) de moi",
                "Je me sens tout le temps extrêmement sûr(e) de moi",
            ]),
            Question(id: 2, text: "Besoin de sommeil", options: [
                "Je n'ai pas moins besoin de sommeil que d'habitude",
                "J'ai parfois besoin de moins de sommeil que d'habitude",
                "J'ai souvent besoin de moins de sommeil que d'habitude",
                "J'ai souvent besoin de beaucoup moins de sommeil que d'habitude",
                "Je peux passer le jour et la nuit sans dormir et ne pas être fatigué(e)",
            ]),
            Question(id: 3, text: "Parler", options: [
                "Je ne parle pas plus que d'habitude",
                "Je parle parfois plus que d'habitude",
                "Je parle souvent plus que d'habitude",
                "Je parle souvent beaucoup plus que d'habitude",
                "Je parle tout le temps et on ne peut pas m'interrompre",
            ]),
            Question(id: 4, text: "Activité", options: [
                "Je n'ai pas été plus actif(ve) que d'habitude",
                "J'ai parfois été plus actif(ve) que d'habitude",
                "J'ai souvent été plus actif(ve) que d'habitude",
                "J'ai souvent été beaucoup plus actif(ve) que d'habitude",
                "J'ai été tout le temps actif(ve) ou en mouvement",
            ]),
        ],
        publishedCutoffs: [
            .init(threshold: 6, label: "probabilité élevée d'un état (hypo)maniaque"),
        ]
    )
}
