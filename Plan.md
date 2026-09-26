# Polar — spec V1

*L'étale, c'est le moment où la mer ne monte plus et ne descend pas encore.*

Compagnon iPhone pour noter en quelques secondes le triangle **émotion → pensée → comportement**, avec un bilan du soir inspiré d'eMoods pour suivre l'humeur dans la durée.

Version 0.1 · septembre 2026

---

## 0. En bref

| | |
|---|---|
| Plateforme | iPhone, app native SwiftUI |
| Cible | iOS 26 minimum ; fonctions iOS 27 activées quand elles sont disponibles |
| Données | SwiftData sur l'iPhone, synchro iCloud en option |
| Santé | HealthKit : écriture des émotions (State of Mind), lecture du sommeil |
| IA | Foundation Models sur l'appareil, en option : l'app fonctionne entièrement sans |
| Saisie express | App Intents : bouton Action, Centre de contrôle, écran verrouillé, widget, Siri |
| Design | fond blanc, couleur réservée aux données |

---

## État de l'app

Aperçu de ce qui existe dans Polar 0.1, après les changements d'interface. Les sections 5 et 7 décrivent le même comportement. Les blocs de code plus bas restent le point de départ technique.

Trois onglets : **Aujourd'hui**, **Calendrier**, **Tendances**. On passe d'un écran à l'autre par une page plein écran et le bouton Retour. Le bilan, le moment, les réglages, Mon plan, un traitement et « Ça ne va pas » ne sont plus des feuilles. Le partage d'un PDF et l'import d'une sauvegarde restent les feuilles du système.

**Aujourd'hui.** La date et l'engrenage des réglages sont en haut. Dessous, la cohérence cardiaque démarre seule : un cercle qui suit six cycles par minute (cinq secondes pour monter, cinq pour descendre), les mots Inspire et Expire, le compte des secondes, et une courbe. Un toucher met en pause. Le bas de l'écran est un bloc jusqu'en bas de la page.

Dans ce bloc :

- **Bilan du jour.** S'il n'est pas fait : « Sommeil, humeur, irritabilité et anxiété. » S'il est fait : « Sommeil » suivi de la durée, puis quatre colonnes (humeur basse, humeur haute, irritabilité, anxiété). Chaque colonne montre le mot Aucun, Léger, Modéré ou Sévère, et un point sur le niveau.
- **Moments.** « Un mot suffit. » Une émotion notée d'un toucher, sans quitter la page. **Écrire** ouvre la page du moment. **Dicter** lance la voix. Ensuite, les moments du jour, du plus récent au plus ancien. Glisser pour supprimer ou compléter.

Il n'y a pas de phrase du type « Bonsoir. Comment ça va ? » sur cet écran, ni de carte « Ça ne va pas ». Le bouton + n'est pas sur Aujourd'hui. Il reste sur Calendrier et Tendances : un toucher ouvre la page du moment, un appui long dicte.

**Moment.** Une seule page : émotion, pensée et comportement ensemble. Un champ peut rester vide. Terminé revient en arrière. Si la dictée contient un mot de détresse, la page « Ça ne va pas » s'ouvre.

**Bilan.** La page complète : jauges, sommeil, traitements, note. On l'ouvre depuis la carte, depuis un jour du calendrier, ou depuis le rappel du soir.

**Réglages.** Traitements, points suivis, rappel du soir, heure de bascule de la journée, Mon plan, Face ID, flou, iCloud, Santé, phrases du compagnon, IA, apparence, puces de comportement, import JSON.

**Mon plan et Ça ne va pas.** Depuis Réglages, ou par Siri et l'intent dédié. La page d'aide reprend ce qui t'aide, la personne de confiance, le 3114 et le 15.

**Calendrier.** Le mois, lundi en premier. Pincer pour l'année. Un jour ouvre son bilan.

**Tendances.** Life chart, sommeil, constats, émotions, comparaison, recherche, résumé, PDF.

**Verrou.** Face ID une seule fois à l'ouverture, avec le code de l'iPhone en repli. L'écran se floute dès que l'app n'est plus active, si le réglage est allumé.

**Ailleurs, déjà en place.** Widget d'émotions, Siri, bouton Action, Centre de contrôle, rappels du soir et de traitement, Apple Watch en deux touches, écriture Santé en option, modèle local en option.

---

## 1. Principes

1. **Noter en moins de 5 secondes.** L'émotion seule suffit, le reste se complète plus tard.
2. **Rien n'est obligatoire.** Chaque champ peut rester vide.
3. **Pas de bouton « Enregistrer ».** Tout se sauvegarde pendant la saisie ; chaque action s'annule depuis un toast.
4. **Pas de séries ni de score.** Un jour sans note n'est jamais un échec.
5. **Le compagnon constate, il n'interprète pas.** Aucun diagnostic, aucun conseil médical.
6. **Tes données restent sur ton iPhone.** Rien ne part sans une action explicite de ta part.
7. **L'app ne prévient jamais personne d'elle-même.** C'est toi qui contactes tes proches ou ta psy, jamais elle.

---

## 2. Ce qu'on reprend d'eMoods

eMoods est une app de suivi pensée pour la bipolarité : hauts et bas du jour, sommeil, traitements, rapport mensuel pour le médecin, stockage hors ligne. On garde sa logique clinique et on refait l'expérience.

| eMoods | Dans Polar |
|---|---|
| Humeur basse, humeur haute, irritabilité notées chaque jour | Repris, plus l'anxiété, sur 4 niveaux : aucun · léger · modéré · sévère (**bilan du jour**) |
| Heures de sommeil | Pré-remplies depuis Santé, modifiables |
| Traitements : prises, oublis, changements de dose, rappels | Repris ; la prise se coche depuis la notification |
| Symptômes psychotiques, poids | En option, désactivés par défaut |
| Points de suivi activables un par un | Repris dans Réglages |
| Calendrier pour voir les cycles | Repris, avec des barres miroir haut / bas |
| Graphiques configurables | Life chart et comparaison de deux mesures en V2 |
| Rapport PDF mensuel pour le médecin ou le thérapeute | Repris, avec le choix d'inclure ou non tes pensées |
| Hors ligne, rien ne quitte l'appareil | Repris ; iCloud en option |
| Plusieurs notes horodatées par jour (version Pro) | C'est le rôle des **moments** |
| Météo, lumière du jour, phases de lune (eMoods Insights) | Lumière du jour en V3 |

Ce que Polar ajoute : le triangle émotion → pensée → comportement, la saisie sans ouvrir l'app, l'intégration à Santé et le compagnon.

---

## 3. Navigation

```text
Polar
├── Aujourd'hui
│   ├── cohérence cardiaque (démarre seule, pause au toucher)
│   ├── Bilan du jour          page
│   ├── Moments                une émotion note tout de suite
│   │   ├── Écrire             page du moment
│   │   └── Dicter             page du moment, voix
│   └── Réglages               page
│       ├── Mon plan           page
│       │   └── Ça ne va pas   page
│       └── Traitement         page
├── Calendrier
│   ├── ( + )                  page du moment ; appui long : dictée
│   └── un jour                page du bilan
└── Tendances
    ├── ( + )                  page du moment ; appui long : dictée
    └── Partager le PDF        feuille du système
```

- Barre d'onglets système en verre, qui se réduit au défilement (`tabBarMinimizeBehavior(.onScrollDown)`).
- Sur **Aujourd'hui**, pas de bouton +. On note depuis les puces d'émotion, ou avec Écrire et Dicter.
- Sur **Calendrier** et **Tendances**, bouton **+** flottant, style `.glassProminent` : toucher pour la page du moment, appui long pour dicter.
- Bilan, moment, réglages, plan, traitement et aide sont des **pages** dans une seule pile, avec le bouton Retour. On ne les ferme pas en feuille.

---

## 4. Design system

### 4.1 Couleurs

Blanc partout. La couleur ne sert qu'aux données. Tokens à créer dans l'Asset Catalog (Color Sets avec variante sombre pour le mode nuit).

| Token | Clair | Nuit | Usage |
|---|---|---|---|
| `Background` | `#FFFFFF` | `#141416` | fond de tous les écrans |
| `Surface` | `#F5F5F7` | `#1F1F22` | cartes, champs, puces non sélectionnées |
| `Hairline` | `#E8E8ED` | `#2C2C30` | filets, contours des points 0–3 |
| `Ink` | `#111113` | `#F2F2F4` | texte principal, bouton +, sélection |
| `InkMuted` | `#6E6E73` | `#9A9AA0` | texte secondaire (contraste 5:1 sur blanc) |
| `InkFaint` | `#AEAEB2` | `#5A5A60` | placeholders, éléments décoratifs |
| `Elevated` | `#CC7A00` | `#F0A640` | humeur haute (ambre) |
| `Depressed` | `#5B8DEF` | `#7FA6F5` | humeur basse (bleu) |
| `Irritability` | `#E25C4B` | `#F07F70` | irritabilité (corail) |
| `Anxiety` | `#8570E8` | `#A898F7` | anxiété (lavande) |

Règles :

- Les couleurs de données atteignent au moins 3:1 sur blanc (seuil WCAG des éléments graphiques).
- Aucune information ne repose sur la couleur seule : l'humeur haute monte, l'humeur basse descend.
- Une seule couleur forte à l'écran à la fois. Les puces d'émotion restent monochromes.
- Pas d'ombres portées : la profondeur vient de `Surface` et des filets.

### 4.2 Typographie

Police système (SF Pro) et styles Dynamic Type uniquement : les ajustements typographiques d'iOS 27 s'appliquent sans rien faire.

| Rôle | Style | Détail |
|---|---|---|
| Titre d'écran | `.largeTitle` | `.semibold` |
| Titre de carte | `.headline` | |
| Texte | `.body` | |
| Secondaire | `.subheadline` | couleur `InkMuted` |
| Valeurs (intensité, heures) | `.title` | `.fontDesign(.rounded)`, `.monospacedDigit()` |
| Légendes | `.caption` | |

### 4.3 Espacements et formes

- Grille de 4 pt : 4 · 8 · 12 · 16 · 24 · 32 · 48. Marges d'écran : 20 pt.
- Cartes : `.rect(cornerRadius: 24, style: .continuous)`, fond `Surface`.
- Puces et boutons en capsule. Bouton principal : 56 pt de haut.
- Cibles tactiles : 44 × 44 pt minimum.
- Verre (Liquid Glass) uniquement sur les éléments flottants, barres et bouton +. Le contenu reste plat et blanc.

### 4.4 Mouvement et haptique

| Action | Animation | Haptique |
|---|---|---|
| Choisir une puce | `.snappy` | `.selection` |
| Chaque cran d'un curseur (0–10 ou 0–3) | — | `.selection` |
| Moment enregistré | pulsation du compagnon | `.success` |
| Supprimer | fondu | `.impact(weight: .light)` |
| Ouvrir ou fermer une feuille | animation système | — |

- Tout passe par `.sensoryFeedback(_:trigger:)`. Jamais deux retours haptiques d'affilée.
- Durées ≤ 350 ms. Avec **Réduire les animations**, les mouvements deviennent des fondus et le compagnon s'immobilise.

### 4.5 Mode nuit

Le blanc reste l'identité de l'app. Réglage **Apparence** : *Toujours clair* (par défaut), *Suivre le système*, *Nuit automatique* à partir d'une heure choisie. En mode nuit, palette sombre et chaude, compagnon endormi. Pour un outil qui suit le sommeil, la nuit automatique vaut le coup : un écran blanc à 1 h du matin n'aide pas à s'endormir.

### 4.6 Ton et microcopie

Tutoiement, phrases courtes, pas de point d'exclamation, pas de jugement.

| Situation | Texte |
|---|---|
| Moment enregistré | « C'est noté. » |
| Moment incomplet | « À compléter quand tu veux. » |
| Rappel du soir | « Deux minutes pour ta journée ? » |
| Journée sans note | « Rien de noté aujourd'hui. » |
| Retour après plusieurs jours | « Content de te revoir. » |
| Saisie tard la nuit | « Il est tard. Je garde ça pour toi. » |

---

## 5. Écrans

### 5.1 Aujourd'hui

```text
┌────────────────────────────────────────┐
│ samedi 26 septembre                 ⚙  │
│                                        │
│              ( cercle )                │
│               Inspire                  │
│                  4                     │
│            ~~~~~~~~●~~~~~~             │
│                                        │
│  ┌──────────────────────────────────┐  │
│  │ Bilan du jour                 ›  │  │
│  │ Sommeil, humeur, irritabilité    │  │
│  │ et anxiété.                      │  │
│  │                                  │  │
│  │ Une fois fait :                  │  │
│  │ Bilan du jour    Sommeil 7 h 00 ›│  │
│  │ Basse   Haute   Irrit.  Anx.     │  │
│  │ Léger   Aucun   Modéré  Aucun    │  │
│  │  ●      ○       ●       ○        │  │
│  │                                  │  │
│  │ Moments                          │  │
│  │ Un mot suffit.                   │  │
│  │ (Anxiété) (Calme) (Tristesse) ›  │  │
│  │ Écrire    Dicter                 │  │
│  │                                  │  │
│  │ 14:20  Anxiété                6  │  │
│  │        Tout le monde va…        │  │
│  └──────────────────────────────────┘  │
│   [Aujourd'hui]  Calendrier  Tendances │
└────────────────────────────────────────┘
```

- **En haut** : la date sur une ligne, réglages par l'engrenage.
- **Cohérence cardiaque** au centre. Elle démarre seule à six cycles par minute. Inspire et Expire, le chiffre des secondes, le cercle et la courbe suivent le même rythme. Un toucher pause, un autre reprend. Pas de phrase d'accueil sur cet écran.
- **Le bloc du bas** va jusqu'en bas de l'écran. Il contient le bilan puis les moments.
- **Carte « Bilan du jour »** : tant qu'elle est vide, elle nomme ce qu'on y met. Une fois remplie, le sommeil est écrit « Sommeil » plus la durée, et chaque jauge montre son mot (Aucun, Léger, Modéré, Sévère) avec un point sur le niveau. Après l'heure du rappel, le contour de la carte se marque si le bilan n'est pas fait.
- **Moments** du jour, du plus récent au plus ancien. Toucher une émotion l'enregistre tout de suite, toast « À compléter quand tu veux. » Écrire ou Dicter ouvrent la page du moment. Chaque ligne : heure, émotion, intensité, début de la pensée.
  - Glisser vers la gauche : supprimer (annulable). Glisser vers la droite : compléter.
  - Un moment sans émotion affiche « À compléter ».
- **« Ça ne va pas »** n'est pas sur cet écran. On l'ouvre depuis Mon plan, Siri, ou si une dictée contient un mot de détresse.

### 5.2 Saisie d'un moment

Une page, pas une feuille. Émotion, pensée et comportement sont sur le même écran. Chaque champ peut rester vide. Ce qui est saisi est déjà enregistré. **Terminé** revient à l'écran d'avant.

```text
┌────────────────────────────────────────┐
│                  ────                  │
│  Émotion  ·  Pensée  ·  Comportement   │
│  ━━━━━━━                               │
│                                        │
│  Qu'est-ce que tu ressens ?            │
│                                        │
│  [Anxiété]  (Calme)  (Tristesse)       │
│  (Stress)  (Joie)  (Épuisement)        │
│  (Irritation)  (Soulagement)           │
│  (Plus…)  (Autre)                      │
│                                        │
│  Intensité                          6  │
│  ━━━━━━━━━━━━━━━━━━━━━●──────────────  │
│  0                                 10  │
│                                        │
│  C'est lié à…   (Travail)  (Famille)   │
│                                        │
│                            Suivant  →  │
└────────────────────────────────────────┘
  [ ] sélectionné   ( ) à toucher
```

**Étape Émotion**

- Puces : les 8 émotions les plus récentes d'abord, « Plus… » pour le catalogue complet (voir 8.3), « Autre » pour un mot à toi.
- Toucher une puce fait apparaître le curseur d'intensité 0–10 juste en dessous : un cran haptique par valeur, le chiffre en grand à droite.
- Ligne optionnelle « C'est lié à… » : travail, famille, couple, amis, santé, argent… (associations de Santé).

**Étape Pensée**

- Grand champ texte, placeholder « Qu'est-ce qui te passe par la tête ? ».
- Bouton micro : maintenir pour dicter, transcription sur l'iPhone.
- Amorces optionnelles en puces : « Je me dis que… », « J'ai peur que… ».

**Étape Comportement**

- Champ « Qu'est-ce que tu as fait, ou envie de faire ? ».
- Puces personnalisables : S'isoler, Appeler quelqu'un, Rester au lit, Sortir marcher, Dépenser, Écrans, Travailler tard…
- **Terminé** revient en arrière. Le compagnon pulse. Toast « C'est noté. » si émotion, pensée et comportement sont là, sinon « À compléter quand tu veux. » On peut annuler.

**Mode vocal** (appui long sur +)

1. Tu parles librement, jusqu'à une minute.
2. Transcription sur l'iPhone (SpeechAnalyzer).
3. Avec Apple Intelligence, le modèle local range le texte dans les champs du triangle (voir 7.3). Les cartes arrivent pré-remplies : tu corriges d'un toucher si besoin, puis tu valides.
4. Sans Apple Intelligence, la transcription va dans « Pensée » et tu choisis l'émotion.

### 5.3 Bilan du jour (inspiré d'eMoods)

Une fois par jour, plutôt le soir. Moins d'une minute.

```text
┌────────────────────────────────────────┐
│                  ────                  │
│  Bilan du jour                         │
│  Le niveau le plus fort de la journée  │
│                                        │
│                      0    1    2    3  │
│  Humeur basse        ●    ○    ○    ○  │
│  Humeur haute        ○    ●    ○    ○  │
│  Irritabilité        ●    ○    ○    ○  │
│  Anxiété             ○    ○    ●    ○  │
│                                        │
│  Sommeil               6 h 40 · Santé  │
│  Traitement du soir            ✓ Pris  │
│  Note du jour               Ajouter ›  │
│                                        │
│  Aujourd'hui : 2 moments            ›  │
│                                        │
│        ┌────────────────────────┐      │
│        │        Terminé         │      │
│        └────────────────────────┘      │
└────────────────────────────────────────┘
```

- **Quatre jauges** : humeur basse, humeur haute, irritabilité, anxiété. On note le niveau **le plus fort** de la journée : 0 aucun · 1 léger · 2 modéré · 3 sévère. On touche un point ou on glisse le doigt le long de la ligne, avec un cran haptique par niveau.
- **Sommeil** : heures de la nuit précédente, pré-remplies depuis Santé (mention « Santé ») et modifiables avec une roue au quart d'heure.
- **Traitements** : un interrupteur par prise prévue ; un changement de dose se note en un toucher.
- **Points optionnels** (activables dans Réglages) : symptômes psychotiques (oui / non), poids, séance avec ta psy, points personnalisés.
- **Note du jour** : texte libre.
- Les moments du jour sont rappelés en bas (lecture seule) pour aider à se souvenir.
- **Journée logique** : une note faite avant 4 h du matin compte pour la veille (heure réglable, voir 8.2).
- Le bilan n'est **pas** envoyé dans Santé : humeur haute et humeur basse ne se résument pas à une valence agréable / désagréable.

### 5.4 Calendrier

Vue mois façon eMoods, en plus aéré. Chaque case de jour :

```text
┌─────────┐
│   12    │
│    ▮    │   humeur haute : barre ambre qui monte (hauteur = niveau 0–3)
│  ─────  │   ligne médiane
│    ▮    │   humeur basse : barre bleue qui descend
│    ·    │   traitement oublié
└─────────┘
```

- Irritabilité et anxiété : petit point coloré dans le coin de la case à partir du niveau 2.
- Jour sans bilan : case vide, sans marque d'erreur.
- Toucher un jour : la page du bilan et des moments de ce jour, modifiables.
- V2 : pincer pour passer à la vue année (douze mini-mois, une barre par jour).

### 5.5 Tendances

- **Life chart** (de 30 jours à 1 an) : barres miroir, humeur haute au-dessus de l'axe en ambre, humeur basse en dessous en bleu. Juste en dessous, sur la même échelle de temps, la courbe du sommeil. Marqueurs discrets pour les oublis de traitement et les changements de dose. Swift Charts : deux graphiques alignés sur le même axe X, l'un en `BarMark` (valeurs négatives pour l'humeur basse), l'autre en `LineMark` pour le sommeil.
- **Émotions** : les plus fréquentes sur la période, et les heures où elles reviennent.
- **Constats factuels**, jamais d'interprétation : « 3 nuits courtes cette semaine » (seuil réglable), « Traitement pris 6 jours sur 7 ».
- **Comparer** (comme les graphiques configurables d'eMoods) : choisir deux mesures et les afficher ensemble, par exemple sommeil et humeur haute.
- **Exporter** : rapport PDF du mois (voir 8.5).

### 5.6 Mon plan et « Ça ne va pas »

**Mon plan** (Réglages → Mon plan), à remplir avec ta psy :

- tes signes précurseurs, avec tes mots ;
- ce qui t'aide ;
- ta personne de confiance et ta psy (nom, téléphone) ;
- tes signaux d'alerte, par exemple « sommeil sous X h pendant N nuits » ou « humeur haute à modéré ou plus N jours de suite ». **Aucun seuil par défaut** : ils se fixent avec elle.

Quand un signal s'allume : une carte calme en haut d'Aujourd'hui rappelle tes signes et ce qui t'aide, avec des boutons vers ton plan et ta personne de confiance. Pas de notification par défaut, pas de rouge.

**Écran « Ça ne va pas »**, depuis Mon plan, par Siri et le bouton Action (App Intent dédié), ou si une dictée contient un mot de détresse. Il n'est pas affiché sur Aujourd'hui.

- ce qui t'aide (repris de ton plan) ;
- appeler ou écrire à ta personne de confiance (message pré-rempli modifiable, envoyé par toi seulement) ;
- appeler ta psy ;
- **3114** : numéro national de prévention du suicide, gratuit et joignable 24 h/24 ;
- **15** : urgence médicale.

### 5.7 Réglages

- **Traitements** : nom, dose, moment de prise, rappel. On archive un traitement arrêté au lieu de le supprimer, pour garder l'historique.
- **Points suivis** : afficher ou masquer chaque jauge et chaque point optionnel.
- **Rappels** : heure du bilan du soir, rappels de traitement.
- **Journée** : heure de bascule (4 h par défaut).
- **Mon plan**.
- **Confidentialité** : Face ID, synchro iCloud, flou dans le sélecteur d'apps.
- **Santé** : autorisations, écriture des émotions activée ou non.
- **Compagnon** : phrases activées ou non, IA activée ou non.
- **Apparence** : mode nuit.
- **Données** : export PDF et CSV, sauvegarde et import JSON.

---

## 6. Saisir sans ouvrir l'app

| Point d'entrée | Geste | Résultat | API |
|---|---|---|---|
| Bouton Action (iPhone 15 Pro et plus récents) | un appui | ouvre la page du moment | `OpenCaptureIntent` via Raccourcis |
| Centre de contrôle, écran verrouillé | un toucher | idem | `ControlWidget` (iOS 18+) |
| Widget d'accueil | toucher une émotion | enregistre l'émotion seule, « à compléter » | widget interactif, `Button(intent:)` (iOS 17+) |
| Siri | « Noter une émotion dans Polar » | Siri demande l'émotion puis l'intensité | `AppShortcutsProvider` ; intent schemas d'iOS 27 pour les formulations libres |
| Notification du soir | toucher | ouvre la page du bilan | `UNNotificationCategory` |
| Notification de traitement | bouton « Pris » | coche la prise sans ouvrir l'app | action de notification |
| Bouton +, Calendrier et Tendances | appui long | dictée directe | `SpeechAnalyzer` |

Toutes ces entrées écrivent dans le même stockage partagé (App Group) : le widget et Siri enregistrent sans ouvrir l'app.

---

## 7. Le compagnon

### 7.1 Apparence

Une sphère d'environ 400 particules couleur `Ink`, réparties en spirale de Fibonacci et rendues en `Canvas` + `TimelineView` (code en 11.6). Elle habite le blanc sans le charger.

- Elle guide la cohérence cardiaque dès l'ouverture : cinq secondes d'inspiration, cinq d'expiration, sans geste pour la lancer.
- Un cercle, un point qui fait le tour, et une courbe montrent le même cycle. Inspire ou Expire, et le nombre de secondes qui restent.
- Un toucher met en pause, un autre reprend.
- En mode nuit, les particules ralentissent et s'estompent. Le guide continue.
- Elle ne reflète **jamais** ton humeur : pas de sphère triste un jour sans. Elle est la même quoi que tu notes.
- Variante possible : un personnage en pixel art avec les mêmes états, si tu préfères un compagnon incarné (ton éditeur Lenny fait déjà la conversion photo → pixel art).

### 7.2 Comportements

| Déclencheur | Réaction |
|---|---|
| Ouverture de l'app | la cohérence cardiaque démarre sur Inspire, sans phrase |
| Toucher le cercle | pause, ou reprise |
| Chaque bascule, toutes les 5 s | haptique léger |
| Moment enregistré depuis une puce | la ligne apparaît, toast « À compléter quand tu veux. » |
| Moment complet | pulsation, « C'est noté. » |
| Bilan du soir rempli | on revient à Aujourd'hui |
| Signal d'alerte actif | le cercle ne change pas ; la carte du plan apparaît en haut du bloc |

### 7.3 IA (optionnelle)

- **Modèle local** (Foundation Models, `SystemLanguageModel`) : range une dictée dans les champs du triangle avec `@Generable` (code en 11.5), et prépare un résumé factuel de la semaine avant une séance. Tout reste sur l'iPhone. Nécessite un iPhone compatible Apple Intelligence (15 Pro et plus récents). Sous iOS 27, contexte de 8 192 tokens : largement assez pour une semaine de notes.
- **Private Cloud Compute** (`PrivateCloudComputeLanguageModel`, iOS 27) : pour un résumé trop long pour le modèle local. Serveurs Apple, données non conservées, pas de clé API, contexte de 32 000 tokens. Désactivé par défaut.
- **Modèles tiers** : le protocole `LanguageModel` d'iOS 27 permet de brancher Claude ou Gemini, mais tes notes partiraient chez un tiers. Déconseillé pour ces données.

**Règles du compagnon** (dans les `instructions` de la session, et testées) :

- reprendre tes mots, ne jamais interpréter les causes ;
- aucun diagnostic, aucun avis sur les traitements ;
- si une information manque, laisser le champ vide plutôt qu'inventer ;
- si le modèle refuse (`GenerationError.guardrailViolation`) ou si la note contient des mots de détresse (liste locale), pas de message d'erreur : la carte « Ça ne va pas » s'affiche ;
- une batterie d'une trentaine de notes de test passe dans le framework **Evaluations** (Xcode 27) à chaque changement d'instructions.

---

## 8. Données

### 8.1 Modèle SwiftData

Compatible CloudKit : toutes les propriétés ont une valeur par défaut ou sont optionnelles (relations comprises), et aucune n'utilise `@Attribute(.unique)`. L'unicité du bilan par jour se gère donc dans le code.

```swift
import Foundation
import SwiftData

@Model
final class Moment {
    var createdAt: Date = Date.now
    var emotionKey: String?            // clé du catalogue ou mot libre
    var intensity: Int?                // 0…10
    var thought: String?
    var behavior: String?
    var behaviorTags: [String] = []
    var associations: [String] = []    // "travail", "famille"… → HKStateOfMind.Association
    var source: String = "app"         // app · widget · siri · controle · voix
    var healthSampleID: UUID?          // échantillon State of Mind écrit dans Santé

    init(emotionKey: String? = nil, intensity: Int? = nil, source: String = "app") {
        self.emotionKey = emotionKey
        self.intensity = intensity
        self.source = source
    }

    var isComplete: Bool { emotionKey != nil && thought != nil && behavior != nil }
}

@Model
final class DayLog {
    var day: Date = Date.now           // jour logique (8.2)
    var depressed: Int = 0             // 0 aucun · 1 léger · 2 modéré · 3 sévère
    var elevated: Int = 0
    var irritability: Int = 0
    var anxiety: Int = 0
    var sleepHours: Double?
    var sleepFromHealth: Bool = false
    var psychoticSymptoms: Bool?       // nil = point non suivi
    var weightKg: Double?
    var therapySession: Bool = false
    var note: String?
    @Relationship(deleteRule: .cascade, inverse: \MedIntake.dayLog)
    var intakes: [MedIntake]? = []

    init(day: Date) { self.day = day }
}

@Model
final class Medication {
    var name: String = ""
    var dose: String = ""              // texte libre
    var slot: String = "soir"          // matin · midi · soir · au besoin
    var reminder: Date?                // heure du rappel ; nil = pas de rappel
    var isActive: Bool = true          // on archive, on ne supprime pas
    @Relationship(deleteRule: .nullify, inverse: \MedIntake.medication)
    var intakes: [MedIntake]? = []

    init(name: String, dose: String, slot: String) {
        self.name = name
        self.dose = dose
        self.slot = slot
    }
}

@Model
final class MedIntake {
    var taken: Bool = true
    var at: Date = Date.now
    var doseChange: String?            // renseigné si la dose a changé ce jour-là
    var medication: Medication?
    var dayLog: DayLog?

    init(medication: Medication, dayLog: DayLog, taken: Bool) {
        self.medication = medication
        self.dayLog = dayLog
        self.taken = taken
    }
}

@Model
final class CarePlan {
    var warningSigns: [String] = []    // tes signes précurseurs, avec tes mots
    var whatHelps: [String] = []
    var trustedName: String?
    var trustedPhone: String?
    var therapistName: String?
    var therapistPhone: String?

    init() {}
}
```

### 8.2 Journée logique

```swift
extension Date {
    /// Jour de rattachement d'une note : avant l'heure de bascule, c'est encore la veille.
    func logicalDay(startHour: Int = 4, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: addingTimeInterval(-Double(startHour) * 3600))
    }
}
```

### 8.3 Catalogue d'émotions et Santé

| Clé | Libellé | Valence | Label Santé |
|---|---|---|---|
| `joie` | Joie | + | `.joyful` |
| `calme` | Calme | + | `.calm` |
| `soulagement` | Soulagement | + | `.relieved` |
| `fierte` | Fierté | + | `.proud` |
| `gratitude` | Gratitude | + | `.grateful` |
| `espoir` | Espoir | + | `.hopeful` |
| `enthousiasme` | Enthousiasme | + | `.excited` |
| `exaltation` | Exaltation | + | `.excited` |
| `indifference` | Indifférence | 0 | `.indifferent` |
| `tristesse` | Tristesse | − | `.sad` |
| `anxiete` | Anxiété | − | `.anxious` |
| `inquietude` | Inquiétude | − | `.worried` |
| `stress` | Stress | − | `.stressed` |
| `colere` | Colère | − | `.angry` |
| `irritation` | Irritation | − | `.irritated` |
| `frustration` | Frustration | − | `.frustrated` |
| `honte` | Honte | − | `.ashamed` |
| `culpabilite` | Culpabilité | − | `.guilty` |
| `solitude` | Solitude | − | `.lonely` |
| `epuisement` | Épuisement | − | `.drained` |
| `debordement` | Débordement | − | `.overwhelmed` |
| `decouragement` | Découragement | − | `.discouraged` |
| `desespoir` | Désespoir | − | `.hopeless` |
| `peur` | Peur | − | `.scared` |
| `agitation` | Agitation | − | aucun (valence seule) |

```swift
import HealthKit

struct Emotion: Identifiable, Hashable {
    let id: String                         // clé stable : "anxiete"
    let label: String                      // "Anxiété"
    let sign: Double                       // +1 agréable · -1 désagréable · 0 neutre
    let healthLabel: HKStateOfMind.Label?

    func valence(intensity: Int) -> Double { sign * Double(intensity) / 10 }
}

enum EmotionCatalog {
    static let all: [Emotion] = [
        Emotion(id: "joie", label: "Joie", sign: 1, healthLabel: .joyful),
        Emotion(id: "anxiete", label: "Anxiété", sign: -1, healthLabel: .anxious),
        // … le reste du tableau
    ]
    static let keys = all.map(\.id)
}
```

**Écriture dans Santé** : chaque moment qui a une émotion et une intensité devient un `HKStateOfMind` de type `.momentaryEmotion`, avec valence = signe × intensité / 10. Les échantillons Santé sont immuables : si tu modifies le moment, l'ancien échantillon est supprimé (grâce à `healthSampleID`) et un nouveau est écrit.

**Lecture du sommeil** : somme des échantillons `sleepAnalysis` dont la valeur appartient à `HKCategoryValueSleepAnalysis.allAsleepValues`, entre 18 h la veille et 14 h, en dédoublonnant les sources (Apple Watch prioritaire). HealthKit ne dit jamais si la lecture a été refusée : sans données, on propose la saisie manuelle.

### 8.4 Confidentialité

- **Data Protection « Complete »** : les fichiers sont illisibles tant que l'iPhone est verrouillé. Conséquence voulue : les actions depuis l'écran verrouillé demandent Face ID (`authenticationPolicy = .requiresAuthentication` sur les intents, option `.authenticationRequired` sur les actions de notification).
- **Verrou Face ID** à l'ouverture. Une seule demande, avec le visage d'abord, puis le code de l'iPhone si tu choisis « Code » ou si Face ID est indisponible. L'écran se floute dès que l'app quitte le premier plan, si le réglage est allumé.
- **Flou dans le sélecteur d'apps** : dès que `scenePhase` quitte `.active`, un voile `Surface` recouvre l'écran.
- Pas de compte à créer. Aucun SDK tiers ni outil d'analytics.
- **iCloud** désactivé par défaut. Activé, les données passent par la base privée CloudKit de ton compte.

### 8.5 Export

- **Rapport PDF mensuel** (comme eMoods) : page 1, life chart du mois et constats factuels ; page 2, tableau jour par jour (jauges, sommeil, traitements) ; page 3 facultative, les moments. À chaque export, tu choisis d'inclure ou non le texte de tes pensées. Généré avec `ImageRenderer` dans un contexte PDF, partagé via `ShareLink`.
- **CSV** : données brutes.
- **Sauvegarde JSON** : export et import complets, pour ne jamais dépendre de l'app.

---

## 9. Stack technique

| Besoin | Framework | Disponible depuis |
|---|---|---|
| Interface | SwiftUI, Liquid Glass | iOS 26 |
| Stockage | SwiftData (+ CloudKit en option) | iOS 17 |
| Saisie express, Siri | App Intents, `AppShortcutsProvider` | iOS 16 |
| Widget interactif | WidgetKit | iOS 17 |
| Contrôle (Centre de contrôle, écran verrouillé) | `ControlWidget` | iOS 18 |
| Émotions dans Santé | HealthKit `HKStateOfMind` | iOS 18 |
| Sommeil | HealthKit `sleepAnalysis` | iOS 16 (phases de sommeil) |
| Dictée | Speech `SpeechAnalyzer` | iOS 26 |
| IA locale | Foundation Models | iOS 26, modèle refait dans iOS 27 |
| Tests de l'IA | Evaluations | Xcode 27 |
| Graphiques | Swift Charts | iOS 16 |
| Verrou | LocalAuthentication | — |
| Rappels | UserNotifications | — |
| Export | `ImageRenderer`, `ShareLink` | iOS 16 |

- **Cible** : iOS 26 minimum ; `if #available(iOS 27, *)` pour Private Cloud Compute et les intent schemas.
- **Capacités Xcode** : HealthKit, App Groups (`group.fr.laz.polar`), Data Protection, iCloud/CloudKit (quand la synchro arrive).
- **Info.plist** : `NSHealthShareUsageDescription`, `NSHealthUpdateUsageDescription`, `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`, `NSFaceIDUsageDescription`.
- **Compte développeur** : le compte gratuit suffit pour prototyper sur ton iPhone (réinstallation tous les 7 jours, pas d'iCloud) ; le compte payant (99 €/an) devient utile dès que l'app sert au quotidien.

---

## 10. Structure du projet

```text
Polar/
├── App/              PolarApp, RootView, SharedStore, CaptureRouter
├── DesignSystem/     ScaleRow, EmotionChip, GlassPlusButton, Toast
├── Features/
│   ├── Today/        TodayView, DayLogCard, MomentRow
│   ├── Capture/      CaptureSheet, EmotionStep, ThoughtStep, BehaviorStep, VoiceCapture
│   ├── DayLog/       DayLogSheet
│   ├── Calendar/     MonthView, DayCell, DayDetailSheet
│   ├── Trends/       TrendsView, LifeChart, SleepChart
│   ├── Companion/    CompanionSphere, CompanionVoice, BreathingGuide
│   ├── Plan/         CarePlanView, SupportView
│   └── Settings/
├── Model/            Moment, DayLog, Medication, MedIntake, CarePlan, EmotionCatalog
├── Services/         HealthService, SpeechService, AIService, PDFReport, Reminders, AppLock
├── Intents/          OpenCaptureIntent, QuickMomentIntent, SupportIntent, PolarShortcuts
└── PolarWidgets/     QuickEmotionWidget, CaptureControl        (extension WidgetKit)
```

---

## 11. Code de départ

Esquisses à valider dans Xcode.

### 11.1 Stockage partagé et routeur de saisie

```swift
import SwiftData
import Observation

enum SharedStore {
    static let container: ModelContainer = {
        let schema = Schema([Moment.self, DayLog.self, Medication.self, MedIntake.self, CarePlan.self])
        let config = ModelConfiguration(
            schema: schema,
            groupContainer: .identifier("group.fr.laz.polar"),  // partagé avec le widget
            cloudKitDatabase: .none                            // .private("iCloud.fr.laz.polar") pour la synchro
        )
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Stockage indisponible : \(error)")
        }
    }()
}

/// État global de la feuille de saisie, ouvert par le bouton +, le bouton Action ou un contrôle.
@MainActor @Observable
final class CaptureRouter {
    static let shared = CaptureRouter()
    var isPresented = false
}
```

Dans `RootView` : `@State private var router = CaptureRouter.shared`, puis `.sheet(isPresented: $router.isPresented) { CaptureSheet() }`. Dans `PolarApp` : `.modelContainer(SharedStore.container)`.

### 11.2 Jauge 0–3 du bilan

```swift
import SwiftUI

struct ScaleRow: View {
    let title: String
    let tint: Color
    @Binding var value: Int                          // 0…3
    private let levels = ["aucun", "léger", "modéré", "sévère"]

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            ForEach(0..<4, id: \.self) { level in
                Button {
                    value = level
                } label: {
                    Circle()
                        .fill(level == value ? tint : .clear)
                        .overlay(Circle().strokeBorder(level == value ? tint : Color("Hairline"), lineWidth: 1.5))
                        .frame(width: 24, height: 24)
                        .frame(width: 44, height: 44)        // cible tactile
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .sensoryFeedback(.selection, trigger: value)
        .animation(.snappy, value: value)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(levels[value])
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(value + 1, 3)
            case .decrement: value = max(value - 1, 0)
            @unknown default: break
            }
        }
        // À ajouter : DragGesture pour glisser d'un niveau à l'autre.
    }
}
```

### 11.3 Saisie express (App Intents)

```swift
import AppIntents
import SwiftData

enum EmotionOption: String, AppEnum {
    case calme, joie, soulagement, anxiete, tristesse, colere, irritation, epuisement

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Émotion"
    static let caseDisplayRepresentations: [EmotionOption: DisplayRepresentation] = [
        .calme: "Calme", .joie: "Joie", .soulagement: "Soulagement", .anxiete: "Anxiété",
        .tristesse: "Tristesse", .colere: "Colère", .irritation: "Irritation", .epuisement: "Épuisement"
    ]
}

/// Siri : enregistre un moment sans ouvrir l'app.
struct QuickMomentIntent: AppIntent {
    static let title: LocalizedStringResource = "Noter une émotion"
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "Émotion")
    var emotion: EmotionOption

    @Parameter(title: "Intensité", default: 5, inclusiveRange: (0, 10))
    var intensity: Int

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = SharedStore.container.mainContext
        context.insert(Moment(emotionKey: emotion.rawValue, intensity: intensity, source: "siri"))
        try context.save()
        return .result(dialog: "C'est noté.")
    }
}

/// Bouton Action, contrôle, raccourci : ouvre la feuille de saisie.
struct OpenCaptureIntent: AppIntent {
    static let title: LocalizedStringResource = "Nouveau moment"
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        CaptureRouter.shared.isPresented = true
        return .result()
    }
}

struct PolarShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: QuickMomentIntent(),
            phrases: ["Noter une émotion dans \(.applicationName)"],
            shortTitle: "Noter une émotion",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: OpenCaptureIntent(),
            phrases: ["Nouveau moment dans \(.applicationName)"],
            shortTitle: "Nouveau moment",
            systemImageName: "square.and.pencil"
        )
    }
}
```

Contrôle pour le Centre de contrôle et l'écran verrouillé (extension WidgetKit, `OpenCaptureIntent` membre des deux cibles) :

```swift
import WidgetKit
import SwiftUI

struct CaptureControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "fr.laz.polar.capture") {
            ControlWidgetButton(action: OpenCaptureIntent()) {
                Label("Nouveau moment", systemImage: "plus")
            }
        }
        .displayName("Nouveau moment")
    }
}
```

### 11.4 Écriture dans Santé

```swift
import HealthKit

final class HealthService {
    private let store = HKHealthStore()

    func requestAccess() async throws {
        try await store.requestAuthorization(
            toShare: [HKObjectType.stateOfMindType()],
            read: [HKObjectType.stateOfMindType(), HKCategoryType(.sleepAnalysis)]
        )
    }

    /// Écrit un moment dans Santé ; l'UUID renvoyé va dans `healthSampleID`.
    func write(_ moment: Moment, emotion: Emotion) async throws -> UUID {
        let sample = HKStateOfMind(
            date: moment.createdAt,
            kind: .momentaryEmotion,
            valence: emotion.valence(intensity: moment.intensity ?? 5),   // -1…1
            labels: emotion.healthLabel.map { [$0] } ?? [],
            associations: []                                             // à mapper depuis moment.associations
        )
        try await store.save(sample)
        return sample.uuid
    }
}
```

### 11.5 Ranger une dictée (Foundation Models)

```swift
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

enum DraftResult {
    case draft(MomentDraft)
    case unavailable        // pas d'Apple Intelligence : saisie manuelle
    case support            // refus du modèle : afficher « Ça ne va pas »
}

func makeDraft(from transcript: String) async -> DraftResult {
    guard case .available = SystemLanguageModel.default.availability else { return .unavailable }

    let session = LanguageModelSession(instructions: """
        Tu ranges une note personnelle en trois champs : émotion, pensée, comportement.
        Reprends les mots de la personne. N'interprète pas, ne conseille pas, \
        ne pose aucun diagnostic. Si une information manque, laisse le champ vide.
        """)
    do {
        let response = try await session.respond(to: transcript, generating: MomentDraft.self)
        return .draft(response.content)
    } catch LanguageModelSession.GenerationError.guardrailViolation {
        return .support
    } catch {
        return .unavailable
    }
}
```

### 11.6 Compagnon

```swift
import SwiftUI

struct CompanionSphere: View {
    var asleep = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // ~400 points répartis uniformément sur une sphère (spirale de Fibonacci)
    private static let points: [SIMD3<Double>] = (0..<400).map { i in
        let k = Double(i) + 0.5
        let phi = acos(1 - 2 * k / 400)
        let theta = Double.pi * (1 + 5.0.squareRoot()) * k
        return SIMD3(cos(theta) * sin(phi), cos(phi), sin(theta) * sin(phi))
    }

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let breath = 1 + 0.05 * sin(t * 2 * Double.pi / 10)    // 6 respirations par minute
                let radius = min(size.width, size.height) * 0.4 * breath
                let spin = t * (asleep ? 0.03 : 0.12)
                let ink = Color("Ink")

                for p in Self.points {
                    let x = p.x * cos(spin) + p.z * sin(spin)
                    let z = -p.x * sin(spin) + p.z * cos(spin)
                    let depth = (z + 1) / 2                             // 0 au fond, 1 devant
                    let d = 1.0 + 2.0 * depth
                    let cx = size.width / 2 + x * radius
                    let cy = size.height / 2 + p.y * radius
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: cx - d / 2, y: cy - d / 2, width: d, height: d)),
                        with: .color(ink.opacity((asleep ? 0.06 : 0.12) + 0.7 * depth))
                    )
                }
            }
        }
        .frame(width: 180, height: 180)
        .accessibilityHidden(true)
    }
}
```

---

## 12. Feuille de route

### V1 — utilisable au quotidien

- [x] Modèle SwiftData et stockage partagé (App Group)
- [x] Aujourd'hui : cohérence cardiaque, bilan lisible, moments notés depuis la page
- [x] Saisie d'un moment, sans IA
- [x] Bilan du jour : jauges, sommeil manuel, traitements
- [x] Calendrier mois
- [x] Rappel du soir
- [x] Verrou Face ID (une demande, puis le code si besoin) et flou du sélecteur d'apps
- [x] Mon plan et écran « Ça ne va pas »
- [x] Export PDF mensuel

### V1.1 — saisir de partout

- [x] `OpenCaptureIntent` : bouton Action, contrôle du Centre de contrôle et de l'écran verrouillé
- [x] Siri (`QuickMomentIntent`)
- [x] Widget interactif
- [x] Santé : écriture State of Mind, lecture du sommeil
- [x] Rappels de traitement avec action « Pris »
- [x] Compagnon animé et respiration guidée
- [x] Signaux d'alerte, une fois les seuils fixés avec ta psy

### V2 — comprendre

- [x] Dictée (SpeechAnalyzer) et rangement par le modèle local
- [x] Tests du compagnon avec Evaluations
- [x] Tendances : life chart, sommeil, émotions
- [x] Comparer deux mesures
- [x] Résumé factuel de la semaine avant une séance
- [x] Vue année du calendrier
- [x] Mode nuit
- [x] App Apple Watch : un moment en deux touches

### V3 — plus tard

- [x] Recherche dans tes notes en langage naturel (outil de recherche Spotlight du framework Foundation Models, iOS 27)
- [x] Lumière du jour et durée d'ensoleillement (calcul local, sans service externe)
- [x] Synchro iCloud

---

## 13. À voir avec ta psy

- Les signes précurseurs à suivre en priorité, et avec quels mots.
- Les seuils des signaux d'alerte (sommeil, humeur haute ou basse).
- Ce qu'elle veut voir dans le rapport mensuel, et si elle veut lire les pensées.
- Qui prévenir, et comment, quand un signal s'allume.
- Si les quatre jauges du bilan lui conviennent ou s'il faut les ajuster.

---

## 14. Pour démarrer

Place ce fichier à la racine du projet. La section **État de l'app** est l'aperçu de ce qui est en place. Le reste détaille le modèle, les règles et les jalons.

---

## Références

- eMoods, fonctionnalités : <https://emoodtracker.com/features>
- eMoods sur l'App Store : <https://apps.apple.com/us/app/emoods-bipolar-mood-tracker/id1184456130>
- Nouveautés d'iOS 27 pour les développeurs : <https://developer.apple.com/ios/whats-new/>
- What's new in the Foundation Models framework (WWDC26) : <https://developer.apple.com/videos/play/wwdc2026/241/>
- Documentation Foundation Models : <https://developer.apple.com/documentation/foundationmodels>
- HealthKit, `HKStateOfMind` : <https://developer.apple.com/documentation/healthkit/hkstateofmind>
- 3114, prévention du suicide : <https://3114.fr>