# Polar 0.2 — avancement

Suivi de la mise en place de la spec 0.2 (voir `Plan.md`) par-dessus l'app 0.1.
Branche : `cursor/implement-polar-0-2-plan-db62` · PR : lazbutton/polar#1.

> **Limite d'environnement.** Polar est un projet **Xcode iOS/watchOS** (SwiftUI, SwiftData,
> HealthKit, WidgetKit, App Intents, Foundation Models). Il ne peut pas être compilé ni lancé
> dans le Cloud Agent (Linux, sans Xcode). Seule la **logique pure** (Foundation) a été compilée
> et exécutée end-to-end avec Swift 6.1 sous Linux : **39 tests passent**. Les couches
> SwiftUI/SwiftData ont été écrites et relues avec soin mais **restent à compiler dans Xcode**.

---

## Fait

### Données et migration
- [x] `DayLog` étendu : énergie (−2…+2), horaires de sommeil (`bedtime`/`wakeTime`), rythme SRM-5
      (`firstContact`/`activityStart`/`dinner`), `signsSeen`, `factors`, cache `daylightMinutes`/`steps`.
- [x] `Moment.forSession` (« À en parler avec ma psy »).
- [x] Nouveaux modèles SwiftData : `SafetyPlan`, `SurveyResponse`, `LabResult`.
- [x] `CarePlan` par pôle/palier : `WarningSign`, `PlanAction`, `Contact` (+ anciens champs gardés pour la migration).
- [x] Schéma CloudKit-compatible (tout optionnel ou par défaut) ; migration légère automatique.
- [x] Migration 0.1 → 0.2 en code (`Migration.swift`) : anciens signes → `WarningSign`,
      « ce qui t'aide » → plan de sécurité, contacts repris ; **sauvegarde JSON automatique** avant migration.
- [x] `Backup` couvre tous les nouveaux champs et modèles (import 0.1 toléré).

### Logique clinique (testée)
- [x] `SleepMetrics` : durée, milieu, décalage du milieu (médiane 28 nuits), variabilité 7 nuits.
- [x] `Instability` : écarts absolus successifs (MASD), axe d'humeur, jours à deux pôles.
- [x] `Questionnaires` : PHQ-9, ASRM, GAD-7 (textes FR, scores, repères publiés, item 9).
- [x] `AlertRule`/`AlertEngine` étendus : nuits courtes, sommeil plus tôt/tard, irrégularité,
      énergie, humeur haute/basse, deux pôles, signes précurseurs, traitement oublié, PHQ-9, ASRM
      (avec `stage`, `isOn`, `notifies`, `pole`).
- [x] Tests unitaires du cœur (`PolarTests/MetricsTests.swift`, `PlanModelTests.swift`).

### Écrans (Lot A/B)
- [x] `SafetyPlanPage` : plan de sécurité en 6 étapes (Stanley-Brown), boutons d'appel (personne, psy, 3114, 15),
      « écrire à » pré-rempli, date de relecture.
- [x] `CarePlanView` par pôle et par palier, avec éditeurs de signes/actions et classement des signes hérités.
- [x] Bilan enrichi : jauge Énergie, horaires de sommeil (Santé + saisie), signes cochés, rythme, facteurs,
      « Tout pris », repère d'hier.
- [x] `WeeklyCheckPage` : point de la semaine (une question par écran, progression, item 9 → plan de sécurité).
- [x] `SessionPage` : préparer ma séance (faits depuis la dernière séance, questionnaires, moments marqués,
      mes questions, mode présentation).
- [x] `LabsView` : analyses saisies telles quelles.
- [x] Carte discrète après un mot de détresse tapé + bascule « À en parler » sur la page Moment.

### Fluidité et système (Lot C)
- [x] Émotion + intensité en un geste (`IntensityChip`).
- [x] Actions rapides de l'icône (Nouveau moment, Bilan, Ça ne va pas) via `AppDelegate`/`SceneDelegate`.
- [x] Notifications actionnables : traitement (Pris / Dans 30 min / Pas aujourd'hui), soir (Ouvrir le bilan,
      note écrite) + textes neutres sur l'écran verrouillé ; aucun rappel en pause.
- [x] Verrou avec délai de grâce (immédiat / 1 / 5 / 15 min) ; `UndoManager` relié au contexte.
- [x] Réglages : points suivis (énergie/rythme/facteurs/analyses), point de la semaine, `SignalsView`,
      mode discret, pause, délai de grâce, ressources.
- [x] Tendances : mode discret, entrée « Préparer ma séance », graphique des scores de questionnaires.

---

## Reste à faire

### À valider dans Xcode (priorité)
- [ ] **Compiler et lancer** l'app dans Xcode ; corriger les éventuelles erreurs SwiftUI/SwiftData
      (impossible à vérifier sous Linux).
- [ ] Rejouer les tests unitaires dans Xcode et écrire les **tests d'interface** des budgets (7.1) + audit
      d'accessibilité (`performAccessibilityAudit`).
- [ ] Vérifier la **migration** sur une vraie base 0.1 (le flag est stocké dans l'App Group).

### Fonctionnel non couvert / partiel
- [ ] **Transitions zoom** et **routeur par onglet** (7.2, 14.2) : on est resté sur `CaptureRouter`
      à pile unique, sans `matchedTransitionSource`/`navigationTransition(.zoom)` ni pile par onglet.
- [ ] **Cadran de sommeil 24 h** à deux poignées (style Horloge) : remplacé par des `DatePicker` + molette d'heures.
- [ ] **Santé — lumière du jour et pas** : lecture ajoutée dans `HealthService.dailyTotals`, mais pas encore
      rafraîchie dans `DayLog` après affichage ni affichée en Tendances.
- [ ] **Tendances** : graphiques sommeil en horaires, rythme du jour, variation jour-à-jour, jours à deux pôles,
      lumière/pas (seul le graphique des questionnaires est ajouté).
- [ ] **Indicateur de régularité SRM-5** et **variation jour-à-jour** : données captées, calcul/affichage à finir.
- [ ] **Rapport PDF façon life chart** (11.7) : le PDF mensuel 0.1 est inchangé ; pages 1–4 et export de
      « Préparer ma séance » à faire.
- [ ] **Notifications de signaux** : l'option « Me prévenir » (`notifies`) est stockée mais aucune notification
      de signal n'est programmée.
- [ ] **Point de la semaine « toutes les deux semaines »** : préférence stockée mais non appliquée
      (seul le jour de la semaine est vérifié).
- [ ] **Calendrier** : aperçu en appui long (jauges/énergie/sommeil/moments) non ajouté.
- [ ] **Secouer pour annuler** : `UndoManager` est branché, mais le geste de secousse n'est pas explicitement testé.

### Écarts d'architecture assumés (à revoir si besoin)
- [ ] `AlertRule` reste une **`struct` Codable** persistée dans `Preferences` (pas un `@Model` comme en 11.1),
      pour éviter une migration de schéma risquée non compilable ici. Étendu avec les nouveaux champs.
- [ ] Migration réalisée **en code au premier lancement** plutôt que via `VersionedSchema`/`SchemaMigrationPlan`
      (la migration reste légère car tous les nouveaux champs sont optionnels ou par défaut).

### Confidentialité / qualité / distribution
- [ ] **Sauvegarde JSON chiffrée** (AES-GCM + PBKDF2, CryptoKit) : non faite (export/import en clair).
- [ ] **App Intents Testing** (iOS 27), **Evaluations** (règles du compagnon), **MetricKit**, journaux `Logger`
      privés, **`PrivacyInfo.xcprivacy`**.
- [ ] **Info.plist / capacités Xcode** : vérifier les clés d'usage (Santé, micro, reconnaissance vocale, Face ID)
      et l'App Group. Les actions rapides sont enregistrées dynamiquement (pas d'`UIApplicationShortcutItems`).
- [ ] **TestFlight**.

### À faire avec ta psy (rappel du plan, hors code)
- [ ] Valider la version française de l'ASRM, fixer les seuils des signaux, remplir Mon plan et le plan de sécurité.
