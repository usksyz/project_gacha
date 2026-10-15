class_name PersonalityData
## Personnalité v2 : les DONNÉES seulement (aucune fonction). Le moteur qui les lit est
## PersonalityEngine (personality_engine.gd).
##
## Source : cahier des charges, onglets « Personnalité : document de référence », « 1. Paliers »,
## « 2. Axes » et « 5. Facettes ». Tous les chiffres sont provisoires.
##
## Ce fichier ne fait pas partie de la pile de GameData : c'est une classe à part (class_name), que
## n'importe quel script peut lire en écrivant PersonalityData.AXES, par exemple.
##
## Rappel : un héros a 18 axes. Chaque axe stocke un PALIER entier de -10 à +10 (affiché -100 à +100 en
## mode dev). Le côté + est le premier pôle nommé (Audace), le côté - le second (Prudence).
## Aucune mécanique ne lit ces valeurs directement : elles passent par PersonalityEngine.


# ---------------------------------------------------------------------------
# Les 18 axes (onglet « 2. Axes », section 2)
# ---------------------------------------------------------------------------

## Les 4 familles, dans l'ordre d'affichage, et la vitesse d'évolution de leurs axes (document de
## référence, section 6 : tempérament x0,1 ; caractère x1 ; humeur x2 ; corps x1, mais seulement par
## l'entraînement et les blessures). Le retour de l'humeur vers sa valeur de fond viendra en P4.
const FAMILIES := {
	"temperament": {"name": "Tempérament", "speed": 0.1},
	"caractere": {"name": "Caractère", "speed": 1.0},
	"humeur": {"name": "Humeur", "speed": 2.0},
	"corps": {"name": "Corps", "speed": 1.0},
}

## Chaque axe : famille, nom des deux pôles (« plus » = palier positif), ce qu'il change, et la
## compétence exclusive de chaque pôle (accès au palier 50 : voir POLE_ACCESS).
## Les identifiants sont les abréviations de l'onglet « 5. Facettes ».
const AXES := {
	# Tempérament (inné, ne bouge presque pas)
	"AUD": {"family": "temperament", "name": "Audace", "plus": "Audace", "minus": "Prudence"},
	"CUR": {"family": "temperament", "name": "Curiosité", "plus": "Curiosité", "minus": "Routine"},
	"SEN": {"family": "temperament", "name": "Sensibilité affective", "plus": "Sensibilité affective", "minus": "Détachement"},
	"COL": {"family": "temperament", "name": "Colère", "plus": "Colère", "minus": "Placidité"},
	# Caractère (se forge avec les épreuves)
	"PER": {"family": "caractere", "name": "Persévérance", "plus": "Persévérance", "minus": "Abandon"},
	"MAI": {"family": "caractere", "name": "Maîtrise de soi", "plus": "Maîtrise de soi", "minus": "Impulsivité"},
	"EMP": {"family": "caractere", "name": "Empathie", "plus": "Empathie", "minus": "Égocentrisme"},
	"HON": {"family": "caractere", "name": "Honnêteté", "plus": "Honnêteté", "minus": "Ruse"},
	"AMB": {"family": "caractere", "name": "Ambition", "plus": "Ambition", "minus": "Effacement"},
	"LOY": {"family": "caractere", "name": "Loyauté", "plus": "Loyauté", "minus": "Méfiance"},
	"FOI": {"family": "caractere", "name": "Foi", "plus": "Foi", "minus": "Lucidité"},
	# Humeur (varie)
	"STA": {"family": "humeur", "name": "Stabilité", "plus": "Stabilité", "minus": "Vulnérabilité"},
	"OPT": {"family": "humeur", "name": "Optimisme", "plus": "Optimisme", "minus": "Pessimisme"},
	"VIT": {"family": "humeur", "name": "Vitalité", "plus": "Vitalité", "minus": "Retenue"},
	# Corps (change avec l'entraînement et les blessures)
	"CON": {"family": "corps", "name": "Constitution", "plus": "Constitution", "minus": "Fragilité"},
	"DOU": {"family": "corps", "name": "Seuil de douleur", "plus": "Seuil de douleur haut", "minus": "Seuil de douleur bas"},
	"ACU": {"family": "corps", "name": "Acuité des sens", "plus": "Acuité aiguë", "minus": "Acuité émoussée"},
	# Rythme : + oiseau de nuit, - lève-tôt (onglet « Axes », section 4, et onglet « Facettes »).
	"RYT": {"family": "corps", "name": "Rythme", "plus": "Nocturne", "minus": "Lève-tôt"},
}

## L'ordre fixe des 18 axes (tableaux de poids, affichage, comparaisons entre héros).
const AXIS_ORDER := ["AUD", "CUR", "SEN", "COL", "PER", "MAI", "EMP", "HON", "AMB", "LOY", "FOI",
	"STA", "OPT", "VIT", "CON", "DOU", "ACU", "RYT"]

## Plus haut palier (en valeur absolue) : 10, affiché 100.
const TIER_MAX := 10


# ---------------------------------------------------------------------------
# Génération (onglet « 1. Paliers », section 3)
# ---------------------------------------------------------------------------

## Répartition de base d'un axe (1 à 3 étoiles), en valeur absolue du palier (0 à 10) ; le signe est
## tiré à part (moitié-moitié). La somme fait 99,95 % : le moteur la ramène à 100 %.
const TIER_DISTRIBUTION := [0.02, 0.08, 0.20, 0.26, 0.24, 0.10, 0.05, 0.03, 0.013, 0.005, 0.0015]

## Queue de la rareté : plus d'étoiles, plus d'extrêmes. Ce facteur multiplie les chances des paliers 50
## et 60, et ce facteur à la puissance RARITY_TAIL_POWERS sur les paliers 70 à 100 ; puis tout est ramené
## à 100 % (les paliers bas perdent un peu).
## Écart signalé : le cahier donne 1,0 aux 3 étoiles, mais avec 1,0 le calcul exact donne 1 héros sur 9 à
## ±90 au lieu de 1 sur 8 (tableau de la section 1) ; 1,03 retombe sur le tableau.
const RARITY_TAIL := {1: 0.8, 2: 0.9, 3: 1.03, 4: 1.2, 5: 1.45}
const RARITY_TAIL_POWERS := {5: 1.0, 6: 1.0, 7: 1.5, 8: 2.0, 9: 2.5, 10: 3.0}
## Héros secrets : le cahier veut des profils écrits à la main. En attendant (P1a), ils sont tirés avec
## cette queue, qui reproduit la ligne « Secret (si généré) » du tableau de la section 1 (ajout du
## projet, provisoire : à remplacer par leurs profils).
const SECRET_TAIL := 1.9

## Corrélations légères entre axes (tirage corrélé, puis converti en paliers : la répartition de chaque
## axe ne change pas). [axe, axe, corrélation de -1 à 1]. Choix provisoires, d'après les exemples du
## cahier (Empathie et Loyauté, Stabilité et Optimisme, Colère contre Maîtrise...).
## Pour chaque axe, la somme des valeurs absolues de ses corrélations doit rester sous 1 (chaque paire
## partage un tirage commun, qui prend cette part du hasard de l'axe).
const CORRELATIONS := [
	["EMP", "LOY", 0.30],
	["STA", "OPT", 0.35],
	["COL", "MAI", -0.30],
	["EMP", "HON", 0.25],
	["VIT", "OPT", 0.20],
	["PER", "MAI", 0.20],
	["AUD", "DOU", 0.20],
	["CON", "DOU", 0.25],
	["SEN", "EMP", 0.20],
	["AMB", "AUD", 0.15],
	["CUR", "ACU", 0.15],
]

## 3 étoiles et plus : plus stables et audacieux (document de référence, section 3, « Tirage du
## profil »). Décalage du tirage, en écarts-types, par axe. Gardé petit : un décalage plus fort donne
## trop d'axes à 100 par rapport au tableau de l'onglet « Paliers », qui fait foi sur les chiffres.
const RARITY_BIAS := {
	3: {"STA": 0.05, "AUD": 0.05},
	4: {"STA": 0.08, "AUD": 0.08},
	5: {"STA": 0.1, "AUD": 0.1},
}

## Garantie de relief : chaque héros a au moins RELIEF_MARK_COUNT axe à ±RELIEF_MARK_TIER (sa marque) et
## au moins RELIEF_TRAIT_COUNT axes à ±RELIEF_TRAIT_TIER. Sinon, les axes déjà les plus forts sont poussés.
const RELIEF_MARK_TIER := 6
const RELIEF_MARK_COUNT := 1
const RELIEF_TRAIT_TIER := 5
const RELIEF_TRAIT_COUNT := 3
## Plafond à la création (hors héros secrets) : au plus ABSOLUTE_MAX_COUNT axes à ±ABSOLUTE_TIER.
const ABSOLUTE_TIER := 9
const ABSOLUTE_MAX_COUNT := 2
## Tirage diversifiant : on tire ce nombre de candidats et on garde celui qui ressemble le moins au lobby.
const DIVERSITY_CANDIDATES := 8
## Petits poids personnels : chaque héros pèse chaque axe un peu à sa façon (x0,85 à x1,15) dans ses scores.
const PERSONAL_WEIGHT_SPREAD := 0.15
## Tics (palier 30 : « un tic lié à ce pôle ») : de TICS_MIN à TICS_MAX par héros.
const TICS_MIN := 3
const TICS_MAX := 6
const TIC_TIER := 3

## Passé : le métier ou l'origine décale le tirage d'un axe vers un pôle, sans rien imposer
## (en écarts-types : 0,5 = un net penchant, avant BACKGROUND_BIAS_SCALE). Clé : identifiant de METIERS.
## BACKGROUND_BIAS_SCALE réduit tous ces décalages : plus forts, ils donnent trop d'axes à 100 chez les
## 3 et 5 étoiles par rapport au tableau de l'onglet « Paliers » (vérifié par tools/test_personality.gd).
const BACKGROUND_BIAS_SCALE := 0.6
const BACKGROUND_BIAS := {
	"paysan": {"PER": 0.4, "CUR": -0.3, "RYT": -0.4},
	"berger": {"SEN": 0.3, "ACU": 0.3, "RYT": -0.3},
	"porteur": {"CON": 0.5, "PER": 0.3, "AMB": -0.3},
	"mendiant": {"HON": -0.4, "OPT": -0.4, "LOY": -0.3},
	"balayeur": {"AMB": -0.5, "PER": 0.2},
	"marmiton": {"VIT": 0.3, "AMB": -0.2},
	"lavandiere": {"PER": 0.3, "VIT": 0.2},
	"pecheur": {"MAI": 0.3, "RYT": -0.4, "VIT": -0.2},
	"palefrenier": {"SEN": 0.3, "CON": 0.2},
	"cordonnier": {"MAI": 0.3, "CUR": -0.3},
	"vagabond": {"CUR": 0.4, "LOY": -0.4, "HON": -0.2},
	"saltimbanque": {"VIT": 0.5, "AUD": 0.3, "HON": -0.2},
	"scribe": {"MAI": 0.4, "CUR": 0.3, "CON": -0.3},
	"bucheron": {"CON": 0.5, "DOU": 0.3},
	"mineur": {"CON": 0.4, "DOU": 0.3, "ACU": -0.2},
	"boucher": {"SEN": -0.4, "DOU": 0.3},
	"chasseur": {"ACU": 0.5, "MAI": 0.3, "RYT": -0.3},
	"forgeron": {"CON": 0.4, "PER": 0.4},
	"guerisseur": {"EMP": 0.5, "SEN": 0.3},
	"marchand": {"HON": -0.3, "AMB": 0.3, "CUR": 0.2},
	"voleur": {"HON": -0.6, "ACU": 0.3, "LOY": -0.3},
	"bandit": {"HON": -0.5, "COL": 0.3, "AUD": 0.3},
	"pretre": {"FOI": 0.6, "EMP": 0.2},
	"milicien": {"LOY": 0.4, "MAI": 0.2},
	"soldat": {"MAI": 0.5, "LOY": 0.5},
	"mercenaire": {"LOY": -0.4, "AMB": 0.3, "AUD": 0.3},
	"garde": {"LOY": 0.5, "MAI": 0.4, "ACU": 0.2},
	"chevalier_errant": {"HON": 0.4, "AUD": 0.4, "FOI": 0.3},
	"chasseur_primes": {"ACU": 0.4, "EMP": -0.3, "AMB": 0.3},
	"erudit": {"CUR": 0.5, "FOI": -0.4, "MAI": 0.3},
	"maitre_armes": {"MAI": 0.5, "PER": 0.5},
	"artisan_expert": {"PER": 0.5, "MAI": 0.4, "CUR": 0.2},
	"veteran": {"STA": 0.4, "DOU": 0.4, "OPT": -0.2},
}


# ---------------------------------------------------------------------------
# Métiers (Sommaire, « Décisions tranchées » ; document de référence, section 2)
# ---------------------------------------------------------------------------
# Le métier remplace « Novice » : pour les 1-2 étoiles, c'est ce qu'ils faisaient avant d'être invoqués
# (leur classe reste Novice dans les règles, voir GameData.class_label). Pour les 3 étoiles et plus,
# c'est leur passé. 1 étoile : métiers pauvres, souvent sans lien avec le combat ; plus d'étoiles, plus
# le lien avec le combat est fort ; les artisans experts sont rares.
# « name » : affiché à la place de « Novice » sur les cartes : 17 lettres au plus (comme « Apprenti guerrier »).
# « combat » : lien avec le combat, de 0 (aucun) à 3 (métier des armes).
# « weights » : poids du tirage par rareté (absent = jamais à cette rareté).
# « aptitudes » : décalage de départ des aptitudes (talent, voir APTITUDE_DOMAINS), en crans.
# Les effets des métiers (connaissances de départ, savoir écrire...) viendront plus tard.
const METIERS := {
	# Métiers pauvres, sans lien avec le combat
	"paysan": {"name": "Paysan", "combat": 0, "weights": {1: 14, 2: 6}, "aptitudes": {"metiers": 1}},
	"berger": {"name": "Berger", "combat": 0, "weights": {1: 8, 2: 4}, "aptitudes": {"metiers": 1}},
	"porteur": {"name": "Porteur d'eau", "combat": 0, "weights": {1: 8, 2: 3}, "aptitudes": {}},
	"mendiant": {"name": "Mendiant", "combat": 0, "weights": {1: 8, 2: 2}, "aptitudes": {}},
	"balayeur": {"name": "Balayeur", "combat": 0, "weights": {1: 7, 2: 2}, "aptitudes": {}},
	"marmiton": {"name": "Marmiton", "combat": 0, "weights": {1: 7, 2: 3}, "aptitudes": {"metiers": 1}},
	"lavandiere": {"name": "Lavandier", "combat": 0, "weights": {1: 6, 2: 2}, "aptitudes": {}},
	"pecheur": {"name": "Pêcheur", "combat": 0, "weights": {1: 7, 2: 4}, "aptitudes": {"metiers": 1}},
	"palefrenier": {"name": "Palefrenier", "combat": 0, "weights": {1: 6, 2: 3}, "aptitudes": {}},
	"cordonnier": {"name": "Cordonnier", "combat": 0, "weights": {1: 5, 2: 3}, "aptitudes": {"metiers": 1}},
	"vagabond": {"name": "Vagabond", "combat": 0, "weights": {1: 6, 2: 3}, "aptitudes": {}},
	"saltimbanque": {"name": "Saltimbanque", "combat": 0, "weights": {1: 4, 2: 3}, "aptitudes": {"dague": 1}},
	"scribe": {"name": "Scribe", "combat": 0, "weights": {1: 3, 2: 3}, "aptitudes": {"magie": 1}},
	# Métiers durs, un peu de lien avec le combat
	"bucheron": {"name": "Bûcheron", "combat": 1, "weights": {1: 5, 2: 5}, "aptitudes": {"epee": 1}},
	"mineur": {"name": "Mineur", "combat": 1, "weights": {1: 5, 2: 5}, "aptitudes": {"lance": 1}},
	"boucher": {"name": "Boucher", "combat": 1, "weights": {1: 3, 2: 4}, "aptitudes": {"dague": 1}},
	"chasseur": {"name": "Chasseur", "combat": 2, "weights": {1: 2, 2: 5, 3: 4}, "aptitudes": {"arc": 2}},
	"guerisseur": {"name": "Guérisseur", "combat": 0, "weights": {1: 1, 2: 3, 3: 3}, "aptitudes": {"soin": 2}},
	"marchand": {"name": "Marchand", "combat": 0, "weights": {2: 3, 3: 2}, "aptitudes": {"metiers": 1}},
	"voleur": {"name": "Voleur", "combat": 1, "weights": {1: 2, 2: 4, 3: 4}, "aptitudes": {"dague": 2}},
	"milicien": {"name": "Milicien", "combat": 2, "weights": {1: 1, 2: 5, 3: 4}, "aptitudes": {"lance": 1, "bouclier": 1}},
	# Artisans experts : rares
	"forgeron": {"name": "Forgeron", "combat": 1, "weights": {1: 0.5, 2: 1.5, 3: 1}, "aptitudes": {"metiers": 2, "epee": 1}},
	"artisan_expert": {"name": "Maître artisan", "combat": 0, "weights": {2: 0.5, 3: 1, 4: 1, 5: 0.5}, "aptitudes": {"metiers": 3}},
	# Passés liés au combat (3 étoiles et plus surtout)
	"pretre": {"name": "Prêtre", "combat": 1, "weights": {2: 1, 3: 4, 4: 4, 5: 3}, "aptitudes": {"soin": 2, "magie": 1}},
	"bandit": {"name": "Bandit", "combat": 2, "weights": {2: 2, 3: 5, 4: 3}, "aptitudes": {"epee": 1, "dague": 1}},
	"soldat": {"name": "Soldat", "combat": 3, "weights": {2: 2, 3: 10, 4: 8, 5: 4}, "aptitudes": {"epee": 1, "lance": 1, "bouclier": 1}},
	"mercenaire": {"name": "Mercenaire", "combat": 3, "weights": {3: 8, 4: 8, 5: 5}, "aptitudes": {"epee": 2}},
	"garde": {"name": "Garde de la cité", "combat": 3, "weights": {3: 7, 4: 6, 5: 4}, "aptitudes": {"lance": 1, "bouclier": 2}},
	"chevalier_errant": {"name": "Chevalier errant", "combat": 3, "weights": {3: 3, 4: 6, 5: 7}, "aptitudes": {"epee": 2, "bouclier": 1}},
	"chasseur_primes": {"name": "Chasseur de primes", "combat": 3, "weights": {3: 4, 4: 5, 5: 4}, "aptitudes": {"arc": 1, "dague": 1}},
	"erudit": {"name": "Érudit", "combat": 1, "weights": {3: 3, 4: 4, 5: 5}, "aptitudes": {"magie": 2}},
	"veteran": {"name": "Vétéran", "combat": 3, "weights": {3: 3, 4: 6, 5: 8}, "aptitudes": {"epee": 1, "bouclier": 1}},
	"maitre_armes": {"name": "Maître d'armes", "combat": 3, "weights": {4: 2, 5: 5}, "aptitudes": {"epee": 2, "lance": 1}},
}
## Savoir écrire dépend du métier (document de référence, section 3 bis, « La bibliothèque ») : un scribe
## ou un érudit, même 1★, sera précieux comme bibliothécaire ; un illettré raconte, quelqu'un d'autre écrit.
## (Les héros secrets savent écrire.)
const LITERATE_METIERS := ["scribe", "erudit", "pretre", "marchand", "artisan_expert", "guerisseur", "chevalier_errant"]

## Métier des héros secrets : aucun pour l'instant (ils ont leur propre histoire, qui viendra avec leurs
## profils écrits à la main) ; leur classe s'affiche comme avant.
const SECRET_METIER := ""


# ---------------------------------------------------------------------------
# L'échelle des paliers (onglet « 1. Paliers », section 4)
# ---------------------------------------------------------------------------
## Pour chaque palier (en valeur absolue) : son nom, ses effets, l'accès qu'il ouvre, ce que voit le Maître.
const TIER_LADDER := {
	0: {"name": "Neutre", "effects": "Aucun", "access": "", "seen": "Rien"},
	1: {"name": "Nuance", "effects": "Effets continus faibles", "access": "", "seen": "Rien"},
	2: {"name": "Tendance", "effects": "Pèse dans les choix autonomes", "access": "", "seen": "Rien"},
	3: {"name": "Penchant", "effects": "Préférences d'activités, d'armes, de partenaires", "access": "tic", "seen": "Le geste"},
	4: {"name": "Inclination", "effects": "Affinité de domaine (arme, apprentissage)", "access": "synergies", "seen": "Des habitudes"},
	5: {"name": "Trait", "effects": "Effets nets", "access": "exclusive", "seen": "Le nom du trait, après 3 observations"},
	6: {"name": "Aptitude", "effects": "Apprentissage du domaine x1,2", "access": "epreuves", "seen": "Le trait, plus vite"},
	7: {"name": "Trait majeur", "effects": "Effets forts", "access": "majeur", "seen": "Dès sa première expression"},
	8: {"name": "Aura", "effects": "Effets sur les autres", "access": "aura", "seen": "Les autres changent autour de lui"},
	9: {"name": "Absolu", "effects": "Effets maximaux", "access": "signature", "seen": "Évident"},
	10: {"name": "Légende", "effects": "—", "access": "eveil", "seen": "Une scène d'éveil"},
}

## Paliers (en valeur absolue) qui ouvrent un accès propre au pôle (POLE_ACCESS).
const ACCESS_TIERS := [5, 7, 9, 10]


# ---------------------------------------------------------------------------
# Accès par pôle (« 2. Axes », section 2 ; « 1. Paliers », sections 4 et 6)
# ---------------------------------------------------------------------------
# Clé : pôle = axe + signe (« AUD+ » Audace, « AUD- » Prudence).
# 5 (palier 50) : compétence(s) exclusive(s), par identifiant seulement (noms dans l'onglet « Axes »).
# 7 (palier 70) : trait majeur et sa faiblesse (situationnelle et domptable).
# 9 (palier 90) : signature (pouvoir unique) et compulsion (peut refuser un ordre du Maître).
# 10 (palier 100) : éveil légendaire possible (un événement en accord avec ce pôle).
# Seuls le texte et l'identifiant sont là : les effets viendront en P2.
const POLE_ACCESS := {
	# --- Tempérament ---
	"AUD+": {
		5: ["fer_de_lance"],
		7: {"id": "premier_sur_la_breche", "name": "Premier sur la brèche", "text": "Engage d'office, +15 % à la première frappe", "weakness": "Ignore 20 % des ordres de retraite"},
		9: {"id": "sans_peur", "name": "Sans peur", "text": "Immunisé à la peur hors cicatrice", "compulsion": "Ne fuit jamais, même perdu"},
		10: {"id": "eveil_audace", "text": "Éveil légendaire de l'Audace"},
	},
	"AUD-": {
		5: ["instinct_de_survie"],
		7: {"id": "oeil_du_repli", "name": "Œil du repli", "text": "Sent la défaite venir, l'équipe recule en ordre, -50 % de pertes en retraite", "weakness": "Engage 2 s en retard"},
		9: {"id": "inviolable", "name": "Inviolable", "text": "Évite le premier coup mortel de chaque combat", "compulsion": "Refuse toute mission jugée trop risquée"},
		10: {"id": "eveil_prudence", "text": "Éveil légendaire de la Prudence"},
	},
	"CUR+": {
		5: ["polyvalence"],
		7: {"id": "fouineur", "name": "Fouineur", "text": "Trouve salles et objets cachés, connaissance x1,5 en observant", "weakness": "Touche les reliques et pièges inconnus"},
		9: {"id": "esprit_encyclopedique", "name": "Esprit encyclopédique", "text": "Copie au niveau 1 une compétence vue chez un allié", "compulsion": "Doit examiner tout inconnu, même en combat"},
		10: {"id": "eveil_curiosite", "text": "Éveil légendaire de la Curiosité"},
	},
	"CUR-": {
		5: ["specialiste"],
		7: {"id": "gestes_surs", "name": "Gestes sûrs", "text": "Avec son arme et en lieu connu, +15 % de précision, jamais de raté critique", "weakness": "-15 % en lieu nouveau"},
		9: {"id": "maitre_du_rituel", "name": "Maître du rituel", "text": "Sa routine double les gains sur une même compétence", "compulsion": "Refuse de changer d'arme ou de poste"},
		10: {"id": "eveil_routine", "text": "Éveil légendaire de la Routine"},
	},
	"SEN+": {
		5: ["lien_indefectible"],
		7: {"id": "coeur_ouvert", "name": "Cœur ouvert", "text": "Console (-stress d'un allié), ses gestes trahissent au Maître le mal-être caché des autres", "weakness": "Absorbe la moitié du stress de ses proches"},
		9: {"id": "lien_d_ame", "name": "Lien d'âme", "text": "Peut rappeler un intime à l'agonie", "compulsion": "Ne quitte jamais un intime blessé"},
		10: {"id": "eveil_sensibilite", "text": "Éveil légendaire de la Sensibilité"},
	},
	"SEN-": {
		5: ["coeur_de_pierre"],
		7: {"id": "sang_froid", "name": "Sang-froid", "text": "Aucun stress dû à la mort d'alliés en combat", "weakness": "Opinion des autres en baisse, ne console jamais"},
		9: {"id": "insondable", "name": "Insondable", "text": "Immunisé à la contagion émotionnelle et aux cicatrices de deuil", "compulsion": "Plus aucun lien intime (opinion plafonnée)"},
		10: {"id": "eveil_detachement", "text": "Éveil légendaire du Détachement"},
	},
	"COL+": {
		5: ["sauvagerie"],
		7: {"id": "furie", "name": "Furie", "text": "Blessé ou ami blessé, +25 % de dégâts 10 s", "weakness": "Ignore les ordres pendant"},
		9: {"id": "rage_incarnee", "name": "Rage incarnée", "text": "Chaque coup reçu augmente ses dégâts, terrifie les ennemis faibles", "compulsion": "Répond à toute provocation, même du Maître"},
		10: {"id": "eveil_colere", "text": "Éveil légendaire de la Colère"},
	},
	"COL-": {
		5: ["patience"],
		7: {"id": "calme_contagieux", "name": "Calme contagieux", "text": "Apaise les alliés proches", "weakness": "Réagit 1 s plus tard aux urgences"},
		9: {"id": "oeil_du_cyclone", "name": "Œil du cyclone", "text": "Jamais de rage ni de panique, dissipe une fois par combat la panique de l'équipe", "compulsion": "Refuse toute vengeance"},
		10: {"id": "eveil_placidite", "text": "Éveil légendaire de la Placidité"},
	},
	# --- Caractère ---
	"PER+": {
		5: ["volonte_de_fer", "perseverance"],
		7: {"id": "second_souffle", "name": "Second souffle", "text": "Une fois par combat, récupère 30 % d'endurance ; épreuves volontaires x1,25", "weakness": "Risque de surentraînement"},
		9: {"id": "indomptable_volonte", "name": "Indomptable", "text": "Plafond de maîtrise d'arme +1 rang de plus par l'effort", "compulsion": "N'abandonne jamais, refuse les retraites"},
		10: {"id": "eveil_perseverance", "text": "Éveil légendaire de la Persévérance"},
	},
	"PER-": {
		5: ["menager_ses_forces"],
		7: {"id": "sens_de_la_limite", "name": "Sens de la limite", "text": "Jamais de surentraînement ni d'épuisement total", "weakness": "Lâche les épreuves dures"},
		9: {"id": "lacher_prise", "name": "Lâcher-prise", "text": "Aucun stress d'échec, cicatrices guéries deux fois plus vite", "compulsion": "Abandonne toute tâche ratée deux fois"},
		10: {"id": "eveil_abandon", "text": "Éveil légendaire de l'Abandon"},
	},
	"MAI+": {
		5: ["coup_parfait"],
		7: {"id": "discipline_de_fer", "name": "Discipline de fer", "text": "Formations et rotations sans erreur", "weakness": "S'adapte mal à l'imprévu"},
		9: {"id": "esprit_d_acier", "name": "Esprit d'acier", "text": "Impossible à manipuler, pas de rupture tant que sa Stabilité est positive", "compulsion": "Cache toujours sa douleur et ses blessures"},
		10: {"id": "eveil_maitrise", "text": "Éveil légendaire de la Maîtrise de soi"},
	},
	"MAI-": {
		5: ["premier_sang"],
		7: {"id": "instinct", "name": "Instinct", "text": "Agit avant tout le monde, 20 % de contre-attaque réflexe", "weakness": "Erreurs de formation"},
		9: {"id": "eclair", "name": "Éclair", "text": "Une action instantanée par combat, qui interrompt l'ennemi", "compulsion": "Ne peut pas attendre un ordre plus de 2 s"},
		10: {"id": "eveil_impulsivite", "text": "Éveil légendaire de l'Impulsivité"},
	},
	"EMP+": {
		5: ["premiers_soins"],
		7: {"id": "rempart_vivant", "name": "Rempart vivant", "text": "Intercepte 30 % des coups visant un allié faible proche", "weakness": "Prend plus de dégâts"},
		9: {"id": "lumiere", "name": "Lumière", "text": "Baisse le stress de tout le lobby, peut sortir un Brisé de son arc", "compulsion": "Ne peut achever un ennemi qui se rend ni abandonner un blessé"},
		10: {"id": "eveil_empathie", "text": "Éveil légendaire de l'Empathie"},
	},
	"EMP-": {
		5: ["survivant"],
		7: {"id": "survie_d_abord", "name": "Survie d'abord", "text": "Se met hors de portée quand il est en danger, se soigne en premier, +butin", "weakness": "Opinion des autres en baisse"},
		9: {"id": "intouchable", "name": "Intouchable", "text": "Renvoie 20 % de ses dégâts sur un allié proche", "compulsion": "Ne partage jamais et ne se sacrifie jamais"},
		10: {"id": "eveil_egocentrisme", "text": "Éveil légendaire de l'Égocentrisme"},
	},
	"HON+": {
		5: ["parole_d_honneur"],
		7: {"id": "parole_d_or", "name": "Parole d'or", "text": "Ses rapports sont toujours vrais (fiches vérifiées d'office)", "weakness": "Ne peut ni bluffer ni négocier"},
		9: {"id": "verite_nue", "name": "Vérité nue", "text": "Ses réactions révèlent au Maître les menteurs", "compulsion": "Avoue tout, même les secrets des autres"},
		10: {"id": "eveil_honnetete", "text": "Éveil légendaire de l'Honnêteté"},
	},
	"HON-": {
		5: ["coup_bas"],
		7: {"id": "masque", "name": "Masque", "text": "Montre un faux trait au Maître, ment et vole sans être vu", "weakness": "Rapports peu fiables"},
		9: {"id": "marionnettiste", "name": "Marionnettiste", "text": "Répand des rumeurs ciblées, feintes qui font perdre sa cible à l'ennemi", "compulsion": "Ment même sans raison"},
		10: {"id": "eveil_ruse", "text": "Éveil légendaire de la Ruse"},
	},
	"AMB+": {
		5: ["commandement"],
		7: {"id": "soif_de_gloire", "name": "Soif de gloire", "text": "+XP sur les chefs et élites, volontaire partout", "weakness": "Vole les cibles, jalousie"},
		9: {"id": "destine", "name": "Destiné", "text": "Promotions plus rapides, peut réclamer une classe supérieure", "compulsion": "Ne supporte pas d'être second, défie le Meneur"},
		10: {"id": "eveil_ambition", "text": "Éveil légendaire de l'Ambition"},
	},
	"AMB-": {
		5: ["fidele_second"],
		7: {"id": "ombre_utile", "name": "Ombre utile", "text": "-30 % d'attention des ennemis, soutien efficace", "weakness": "Ne prend jamais l'initiative"},
		9: {"id": "invisible", "name": "Invisible", "text": "Jamais ciblé tant qu'il n'attaque pas", "compulsion": "Refuse tout rôle de Meneur et toute récompense"},
		10: {"id": "eveil_effacement", "text": "Éveil légendaire de l'Effacement"},
	},
	"LOY+": {
		5: ["serment_fidele"],
		7: {"id": "bouclier_des_siens", "name": "Bouclier des siens", "text": "+défense près d'un membre de son cercle, obéissance haute", "weakness": "Suit le Maître même dans l'erreur"},
		9: {"id": "serment", "name": "Serment", "text": "Un serment au Maître ou à un intime le rend incapable de trahir, tient 5 s à 0 PV pour protéger", "compulsion": "Venge toute trahison"},
		10: {"id": "eveil_loyaute", "text": "Éveil légendaire de la Loyauté"},
	},
	"LOY-": {
		5: ["vigilance"],
		7: {"id": "rien_ne_m_echappe", "name": "Rien ne m'échappe", "text": "Repère trahisons et embuscades, insensible à la manipulation", "weakness": "Confiance au Maître plafonnée"},
		9: {"id": "loup_solitaire", "name": "Loup solitaire", "text": "+25 % quand il est seul", "compulsion": "Refuse les duos, dort à l'écart"},
		10: {"id": "eveil_mefiance", "text": "Éveil légendaire de la Méfiance"},
	},
	"FOI+": {
		5: ["ferveur"],
		7: {"id": "ferveur_rites", "name": "Ferveur", "text": "Ses rites baissent le stress du groupe", "weakness": "Superstitions : refuse certains jours ou lieux"},
		9: {"id": "elu", "name": "Élu", "text": "Reçoit des « signes » (une information sur l'étage à venir)", "compulsion": "Obéit aux signes avant le Maître"},
		10: {"id": "eveil_foi", "text": "Éveil légendaire de la Foi"},
	},
	"FOI-": {
		5: ["lucidite"],
		7: {"id": "calcul", "name": "Calcul", "text": "Estimation fiable des chances d'un combat sur la fiche", "weakness": "Rites sans effet sur lui"},
		9: {"id": "oracle_froid", "name": "Oracle froid", "text": "Prédit l'issue d'un combat, optimise les formations", "compulsion": "Refuse les missions au calcul défavorable"},
		10: {"id": "eveil_lucidite", "text": "Éveil légendaire de la Lucidité"},
	},
	# --- Humeur ---
	"STA+": {
		5: ["calme_exclusif"],
		7: {"id": "roc", "name": "Roc", "text": "Stress reçu divisé par deux, pilier de l'équipe", "weakness": "Paraît indifférent"},
		9: {"id": "inebranlable", "name": "Inébranlable", "text": "Jamais de rupture, les cicatrices ne prennent pas", "compulsion": "Jamais d'éveil sous le stress (pas de rage d'éveil)"},
		10: {"id": "eveil_stabilite", "text": "Éveil légendaire de la Stabilité"},
	},
	"STA-": {
		5: ["instinct_de_crise"],
		7: {"id": "a_fleur_de_peau", "name": "À fleur de peau", "text": "Sous stress, chance d'éveil et de vertu doublée", "weakness": "Ruptures fréquentes"},
		9: {"id": "brise_forge", "name": "Brisé-forgé", "text": "Chaque rupture surmontée laisse un gain permanent", "compulsion": "Crise à chaque mort d'allié"},
		10: {"id": "eveil_vulnerabilite", "text": "Éveil légendaire de la Vulnérabilité"},
	},
	"OPT+": {
		5: ["espoir"],
		7: {"id": "phare", "name": "Phare", "text": "Remonte le moral après un revers", "weakness": "Sous-estime le danger"},
		9: {"id": "espoir_incarne", "name": "Espoir incarné", "text": "Une fois par combat, annule la panique de l'équipe et donne +10 % pendant 15 s", "compulsion": "Refuse les retraites"},
		10: {"id": "eveil_optimisme", "text": "Éveil légendaire de l'Optimisme"},
	},
	"OPT-": {
		5: ["prevoyance"],
		7: {"id": "prevoyant", "name": "Prévoyant", "text": "Prépare toujours un plan B (potion de plus, retraite préparée)", "weakness": "Baisse le moral"},
		9: {"id": "cassandre", "name": "Cassandre", "text": "Ses alertes de danger sont fiables (fiche d'étage « danger »)", "compulsion": "Mine l'enthousiasme de l'équipe"},
		10: {"id": "eveil_pessimisme", "text": "Éveil légendaire du Pessimisme"},
	},
	"VIT+": {
		5: ["boute_en_train"],
		7: {"id": "infatigable", "name": "Infatigable", "text": "Endurance +30 %, deux activités au lobby", "weakness": "Dort mal, agite les autres"},
		9: {"id": "moteur", "name": "Moteur", "text": "Augmente l'endurance de l'équipe", "compulsion": "Ne peut pas se reposer"},
		10: {"id": "eveil_vitalite", "text": "Éveil légendaire de la Vitalité"},
	},
	"VIT-": {
		5: ["solitaire_efficace"],
		7: {"id": "econome", "name": "Économe", "text": "-25 % d'endurance dépensée, tient en survie", "weakness": "Démarre lentement"},
		9: {"id": "souffle_infini", "name": "Souffle infini", "text": "Ne s'épuise jamais en défense", "compulsion": "Refuse les assauts prolongés"},
		10: {"id": "eveil_retenue", "text": "Éveil légendaire de la Retenue"},
	},
	# --- Corps ---
	"CON+": {
		5: ["corps_forge"],
		7: {"id": "dur_a_cuire", "name": "Dur à cuire", "text": "Guérison x1,5, résiste aux poisons et maladies", "weakness": "Se surestime"},
		9: {"id": "colosse", "name": "Colosse", "text": "Une fois par combat, reste à 1 PV au lieu de tomber", "compulsion": "Refuse les soins tant qu'il tient debout"},
		10: {"id": "eveil_constitution", "text": "Éveil légendaire de la Constitution"},
	},
	"CON-": {
		5: ["leger"],
		7: {"id": "corps_leger", "name": "Corps léger", "text": "+15 % d'esquive et de vitesse", "weakness": "Moins de PV"},
		9: {"id": "ombre_fragile", "name": "Ombre fragile", "text": "+30 % d'esquive, mais chaque coup subi compte double", "compulsion": "Évite le corps à corps"},
		10: {"id": "eveil_fragilite", "text": "Éveil légendaire de la Fragilité"},
	},
	"DOU+": {
		5: ["esprit_combatif_exclusif"],
		7: {"id": "insensible", "name": "Insensible", "text": "Aucune pénalité de blessure, épreuves de douleur facilitées", "weakness": "Ne signale pas ses saignements"},
		9: {"id": "sans_douleur", "name": "Sans douleur", "text": "Continue à agir 5 s à 0 PV", "compulsion": "Refuse les soins en combat"},
		10: {"id": "eveil_seuil_haut", "text": "Éveil légendaire du Seuil de douleur"},
	},
	"DOU-": {
		5: ["alerte"],
		7: {"id": "alarme_du_corps", "name": "Alarme du corps", "text": "Sent poisons et maladies tôt, l'alerte se voit, soins sur lui x1,3", "weakness": "Moins efficace blessé"},
		9: {"id": "corps_sentinelle", "name": "Corps-sentinelle", "text": "Une fois par combat, évite un coup critique par réflexe", "compulsion": "Panique à la vue de son sang"},
		10: {"id": "eveil_seuil_bas", "text": "Éveil légendaire de la sensibilité à la douleur"},
	},
	"ACU+": {
		5: ["oeil_de_faucon_exclusif", "sixieme_sens"],
		7: {"id": "oeil_de_faucon_majeur", "name": "Œil de faucon", "text": "+précision à distance, repère les embuscades, connaissance x1,5 en observant", "weakness": "Dort mal au bruit"},
		9: {"id": "vision_totale", "name": "Vision totale", "text": "Connaît les points faibles d'un ennemi dès le premier contact", "compulsion": "Stress dans le vacarme (hordes)"},
		10: {"id": "eveil_acuite", "text": "Éveil légendaire de l'Acuité"},
	},
	"ACU-": {
		5: ["concentration"],
		7: {"id": "tunnel", "name": "Tunnel", "text": "Insensible aux feintes et illusions", "weakness": "Surpris par les embuscades"},
		9: {"id": "aveugle_a_l_horreur", "name": "Aveugle à l'horreur", "text": "Aucune peur due à l'apparence des monstres", "compulsion": "N'entend pas les ordres lointains"},
		10: {"id": "eveil_acuite_emoussee", "text": "Éveil légendaire de l'Acuité émoussée"},
	},
	# Rythme : + nocturne (exclusive Veilleur), - lève-tôt (exclusive Aube). Écart signalé : le tableau de
	# l'onglet « Axes » met Aube au pôle haut, mais sa règle et l'onglet « Facettes » disent + = nuit.
	"RYT+": {
		5: ["veilleur"],
		7: {"id": "enfant_de_la_nuit", "name": "Enfant de la nuit", "text": "+15 % la nuit, garde de nuit au lobby", "weakness": "-15 % le matin"},
		9: {"id": "chasseur_nocturne", "name": "Chasseur nocturne", "text": "Voit dans le noir, attaques de nuit dévastatrices", "compulsion": "Indisponible le matin"},
		10: {"id": "eveil_nuit", "text": "Éveil légendaire de la Nuit"},
	},
	"RYT-": {
		5: ["aube"],
		7: {"id": "aube_majeur", "name": "Aube", "text": "+15 % le matin, bonus d'entraînement matinal", "weakness": "-15 % la nuit"},
		9: {"id": "premier_leve", "name": "Premier levé", "text": "Entraîne les autres à l'aube (bonus d'équipe)", "compulsion": "Indisponible pour les missions de nuit"},
		10: {"id": "eveil_aube", "text": "Éveil légendaire de l'Aube"},
	},
}


# ---------------------------------------------------------------------------
# Accès croisés (« 1. Paliers », section 7)
# ---------------------------------------------------------------------------
## Conditions : {axe: palier minimal dans le sens du pôle cité} (négatif = pôle bas : AUD -5 = Prudence 50).
## « extra » : une condition qui n'est pas un axe (vérifiée plus tard par la mécanique qui s'en sert).
const SYNERGIES := {
	"epreuve_du_couteau": {"name": "Épreuve du couteau", "needs": {"PER": 6, "DOU": 5}, "text": "Peut apprendre Résistance à la douleur par épreuve volontaire"},
	"epreuve_du_brasero": {"name": "Épreuve du brasero", "needs": {"PER": 6, "AUD": 4, "DOU": 4}, "text": "Résistance au feu par épreuve volontaire"},
	"duo_de_parade": {"name": "Duo de parade", "needs": {"MAI": 5, "ACU": 5}, "text": "Défense contre les projectiles par entraînement en duo"},
	"meneur": {"name": "Meneur", "needs": {"AMB": 4, "EMP": 3, "STA": 3}, "text": "Peut devenir Meneur"},
	"rage_maitrisee": {"name": "Rage maîtrisée", "needs": {"COL": 6, "MAI": 6}, "text": "Berserk sans la perte d'Intelligence"},
	"increvable": {"name": "Increvable", "needs": {"PER": 7, "CON": 5, "DOU": 5}, "text": "Chance d'éveil du Berserk doublée"},
	"justicier": {"name": "Justicier", "needs": {"COL": 5, "EMP": 5}, "text": "+dégâts contre qui a blessé un faible"},
	"assassin_ne": {"name": "Assassin né", "needs": {"HON": -6, "MAI": 5, "ACU": 5}, "text": "Attaque surprise x2"},
	"predateur": {"name": "Prédateur", "needs": {"HON": -7, "EMP": -7, "LOY": -5}, "text": "Trahison possible, y compris du sauveur"},
	"mentor": {"name": "Mentor", "needs": {"EMP": 5, "MAI": 4}, "extra": "arme_rang_avance", "text": "Peut enseigner son arme"},
	"guerisseur_ne": {"name": "Guérisseur né", "needs": {"EMP": 6, "SEN": 4, "ACU": 4}, "text": "Soins +25 %"},
	"eclaireur": {"name": "Éclaireur", "needs": {"CUR": 5, "ACU": 5, "AMB": -3}, "text": "Missions d'exploration, repérage d'étage"},
	"martyr": {"name": "Martyr", "needs": {"EMP": 7, "FOI": 5}, "text": "Sacrifice volontaire pour un allié"},
	"tacticien": {"name": "Tacticien", "needs": {"AUD": -5, "MAI": 5, "FOI": -5}, "text": "+10 % à l'équipe quand il mène une formation"},
	"vengeur": {"name": "Vengeur", "needs": {"COL": 6, "LOY": 6}, "text": "État de vengeance après la mort d'un intime"},
	"survivant_ne": {"name": "Survivant", "needs": {"AUD": -5, "EMP": -4, "STA": 5}, "text": "Fuite réussie presque toujours"},
	"pilier_du_lobby": {"name": "Pilier du lobby", "needs": {"STA": 6, "OPT": 5, "EMP": 3}, "text": "-stress de tout le lobby"},
	"bourreau": {"name": "Bourreau", "needs": {"COL": 5, "EMP": -6, "SEN": -5}, "text": "Intimide les ennemis faibles, cruauté envers les vaincus"},
}

## Tensions : pas d'accès, mais du drame (hésitation plus longue, stress, choix moins prévisible).
const TENSIONS := {
	"rage_contenue": {"name": "Rage contenue", "needs": {"COL": 7, "MAI": 7}, "text": "Explosion rare et violente"},
	"dechire": {"name": "Déchiré", "needs": {"EMP": 6, "AMB": 6}, "text": "Entre les autres et sa propre gloire"},
	"fonce_puis_craque": {"name": "Fonce puis craque", "needs": {"AUD": 6, "STA": -6}, "text": "Se jette en avant puis s'effondre"},
	"ment_pour_les_siens": {"name": "Ment pour les siens", "needs": {"LOY": 6, "HON": -6}, "text": "Loyal, mais prêt à mentir pour son cercle"},
}


# ---------------------------------------------------------------------------
# Composites (« 1. Paliers », section 5) : lectures rapides, sur les paliers, arrondies au palier
# ---------------------------------------------------------------------------
## {axe: coefficient} ; le résultat est la somme divisée par « div », arrondie au palier entier.
const COMPOSITES := {
	"courage": {"name": "Courage", "axes": {"AUD": 2, "STA": 1, "DOU": 1, "OPT": 1}, "div": 5, "read_by": "Peur, engagement, fuite"},
	"discipline": {"name": "Discipline", "axes": {"MAI": 2, "PER": 1, "LOY": 1}, "div": 4, "read_by": "Obéissance, formations, rotations"},
	"coeur": {"name": "Cœur", "axes": {"EMP": 2, "HON": 1, "SEN": 1}, "div": 4, "read_by": "Choix moraux, pitié, sacrifice"},
	"resilience": {"name": "Résilience", "axes": {"STA": 2, "PER": 1, "OPT": 1, "CON": 1}, "div": 5, "read_by": "Stress, récupération, cicatrices"},
	# (2 Acuité + Curiosité - Loyauté) / 4 : la Méfiance (Loyauté négative) compte en plus.
	"vigilance": {"name": "Vigilance", "axes": {"ACU": 2, "CUR": 1, "LOY": -1}, "div": 4, "read_by": "Embuscades, pièges, mensonges"},
	"ascendant": {"name": "Ascendant", "axes": {"AMB": 2, "AUD": 1, "MAI": 1, "OPT": 1}, "div": 5, "read_by": "Hiérarchie, Meneur, intimidation"},
}


# ---------------------------------------------------------------------------
# Modificateurs (document de référence, section 4 ; « 1. Paliers », section 5) — P2
# ---------------------------------------------------------------------------
# Chaque effet nommé dit ce qu'il lit (un composite ou un axe, en palier -10 à +10), comment il compte et
# ses bornes. Ajouter une mécanique = ajouter une entrée ici (PersonalityEngine.modified l'applique).
# « op » :
#   "add" : chances, seuils, délais. Résultat = base + k x palier ; l'écart (k x palier) est borné par
#           « low » / « high ».
#   "mul" : vitesses et quantités. Résultat = base x (1 + m)^palier ; le facteur est borné par « low » / « high ».
#   "none" : rien n'est lu (seuls les accès de ACCESS_MODIFIERS le changent).
# « min » / « max » : bornes du résultat final (une chance reste entre 0 et 0,95 ; un refus jamais au-dessus de
# 0,5 : garde-fou de « 4. Interactions », section 6). « with_base » : l'effet ne s'applique que si la base
# n'est pas nulle (la personnalité aggrave ou adoucit un risque, elle ne le crée pas).
# « source » : « cahier » si le coefficient est écrit dans le cahier, « projet » s'il est choisi par le projet
# (provisoire, à régler en jouant). Tous les chiffres sont provisoires.
const MODIFIERS := {
	# Peur (cahier : « Chance de peur : -3 points par palier d'Audace, de -30 à +30 points »). Le cahier dit
	# aussi que les mécaniques lisent d'abord les composites (Courage : « peur, engagement, fuite ») : on lit
	# donc le composite Courage, qui compte l'Audace deux fois.
	"fear_chance": {"name": "Chance d'avoir peur", "op": "add", "composite": "courage", "k": -0.03,
		"low": -0.30, "high": 0.30, "min": 0.0, "max": 0.95, "with_base": true, "source": "cahier"},
	"fear_flee": {"name": "Fuite quand il a peur", "op": "add", "composite": "courage", "k": -0.03,
		"low": -0.30, "high": 0.30, "min": 0.0, "max": 0.95, "source": "projet"},
	"fear_return": {"name": "Retour de la peur après une blessure grave", "op": "add", "composite": "courage",
		"k": -0.03, "low": -0.30, "high": 0.30, "min": 0.0, "max": 0.95, "source": "projet"},
	# Désobéissance (Loyauté, confiance, Maîtrise de soi, santé mentale) : composite Discipline (« obéissance »).
	# Seulement sous le seuil de santé mentale ; la dissonance d'un ordre contre sa nature viendra en P3.
	"disobey_chance": {"name": "Refus d'un ordre (santé mentale basse)", "op": "add", "composite": "discipline",
		"k": -0.03, "low": -0.30, "high": 0.30, "min": 0.0, "max": 0.5, "with_base": true, "source": "projet"},
	# Rupture (document de référence : « Stabilité - : éveil plus probable » ; « Prudence : fuite »).
	"rupture_awaken": {"name": "Éveil plutôt qu'effondrement (rupture)", "op": "add", "axis": "STA", "k": -0.02,
		"low": -0.20, "high": 0.20, "min": 0.02, "max": 0.5, "source": "projet"},
	"panic_flee": {"name": "Fuite plutôt que frénésie (rupture)", "op": "add", "axis": "AUD", "k": -0.03,
		"low": -0.30, "high": 0.30, "min": 0.05, "max": 0.95, "source": "projet"},
	# Récupération de la santé mentale à la cité (Résilience : « stress, récupération, cicatrices »).
	"mental_regen": {"name": "Remontée de la santé mentale", "op": "mul", "composite": "resilience", "m": 0.04,
		"low": 0.68, "high": 1.48, "source": "projet"},
	# Endurance (Constitution : réserve ; Vitalité : récupération). Garde-fou des stats de combat : ±30 %.
	"stamina_max": {"name": "Endurance maximale", "op": "mul", "axis": "CON", "m": 0.03, "low": 0.7, "high": 1.3,
		"source": "projet"},
	"stamina_regen": {"name": "Récupération d'endurance", "op": "mul", "axis": "VIT", "m": 0.03, "low": 0.7,
		"high": 1.3, "source": "projet"},
	"stamina_cost": {"name": "Endurance dépensée", "op": "none", "source": "projet"},
	# Planchers (seuls certains accès les relèvent) : santé mentale qui ne tombe jamais à 0 (pas de rupture),
	# endurance qui ne tombe jamais à 0 (jamais épuisé).
	"mental_floor": {"name": "Plancher de santé mentale", "op": "none", "source": "cahier"},
	"stamina_floor": {"name": "Plancher d'endurance", "op": "none", "source": "cahier"},
}

## Les accès (traits majeurs à 70, signatures à 90) dont l'effet écrit dans le cahier est un simple
## modificateur d'une mécanique qui existe déjà. Appliqués après MODIFIERS. {accès: {effet: règle}} ;
## règle : {"set": valeur} (remplace) ou {"mul": facteur} ; « if » : conditions de palier en plus
## (comme les synergies : {axe: palier minimal dans le sens du pôle}). Les autres accès attendent leur
## mécanique (P3 : choix ; P4 : événements ; C3 : perception...).
const ACCESS_MODIFIERS := {
	"sans_peur": {"fear_chance": {"set": 0.0}, "fear_flee": {"set": 0.0}, "fear_return": {"set": 0.0},
		"panic_flee": {"set": 0.0}},                                       # Audace 90 : immunisé à la peur, ne fuit jamais
	"bouclier_des_siens": {"disobey_chance": {"mul": 0.5}},               # Loyauté 70 : obéissance haute
	"infatigable": {"stamina_max": {"mul": 1.3}},                         # Vitalité 70 : endurance +30 %
	"econome": {"stamina_cost": {"mul": 0.75}},                           # Retenue 70 : -25 % d'endurance dépensée
	"sens_de_la_limite": {"stamina_floor": {"set": 1.0}},                 # Abandon 70 : jamais d'épuisement total
	"inebranlable": {"mental_floor": {"set": 1.0}},                       # Stabilité 90 : jamais de rupture
	"esprit_d_acier": {"mental_floor": {"set": 1.0, "if": {"STA": 1}}},   # Maîtrise 90 : pas de rupture si Stabilité positive
}


# ---------------------------------------------------------------------------
# Stress revu (document de référence, « Sensibilité au stress » ; feuille de route v2, prompt 5.1 point 4) — P2
# ---------------------------------------------------------------------------
# Perte de santé mentale = perte de base x Stabilité x sensibilité au type d'événement x accoutumance
# (PersonalityEngine.stress), puis Calme (compétence, comme avant).
# Stabilité (cahier, « 1. Paliers », section 5) : stress reçu / (1 + 0,06 x palier) pour une Stabilité
# positive (au mieux /1,6) ; un Vulnérable (palier négatif) le reçoit x (1 + 0,06 x palier) (ajout du projet :
# le cahier ne donne que le côté positif). Roc (Stabilité 70, cahier) : encore divisé par deux.
const STRESS_STABILITY_STEP := 0.06
const STRESS_ROC_FACTOR := 0.5
## Le facteur total (Stabilité, type, accoutumance, accès) reste entre ces bornes.
const STRESS_FACTOR_MIN := 0.05
const STRESS_FACTOR_MAX := 3.0
## Sensibilité par type d'événement : {axe ou « courage » (composite) : m}, facteur (1 + m)^palier par
## entrée, le produit borné à STRESS_TYPE_MIN..MAX. « subject » : le sujet dont l'appréhension règle
## l'accoutumance (« boss » : le sujet du boss, donné par l'appelant). Coefficients : projet (provisoires) ;
## les axes viennent du document de référence (Témoins d'une synthèse : Empathie, Sensibilité ; Deuil :
## Sensibilité ; peur des boss : Courage...).
const STRESS_TYPE_MIN := 0.5
const STRESS_TYPE_MAX := 2.0
const STRESS_TYPES := {
	"wounds": {"name": "Blessures", "axes": {"DOU": -0.05}},
	"bleeding": {"name": "Voir son sang couler", "axes": {"DOU": -0.05}, "subject": "sight:blood"},
	"boss": {"name": "Arrivée d'un boss", "axes": {"courage": -0.07}, "subject": "boss"},
	"warnings": {"name": "Triple avertissement", "axes": {"OPT": -0.05}, "subject": "mission:defense"},
	"ally_death": {"name": "Un allié tombe", "axes": {"SEN": 0.06, "EMP": 0.04}, "subject": "sight:death"},
	"panic_spread": {"name": "Panique d'un allié", "axes": {"SEN": 0.05}},
	"fear": {"name": "Prendre peur", "axes": {}},
	"berserk": {"name": "Rage (Berserk)", "axes": {}},
	"hostile": {"name": "Un hostile dans l'équipe", "axes": {"COL": 0.05}},
	"defeat": {"name": "Défaite", "axes": {"OPT": -0.05, "AMB": 0.03}},
	"synthesis": {"name": "Voir une synthèse", "axes": {"EMP": 0.05, "SEN": 0.05}, "subject": "synthesis"},
	"left_out": {"name": "Laissé à la cité", "axes": {"AMB": 0.05}},
	"duel_lost": {"name": "Duel perdu", "axes": {"AMB": 0.05}},
	"challenge_refused": {"name": "Défi refusé", "axes": {"COL": 0.05}},
}
## Accoutumance (feuille de route v2 : « baisse à chaque exposition surmontée, sauf deuil d'un ami et peurs
## personnelles ») : facteur = appréhension du sujet / son danger de départ (SUBJECTS), entre STRESS_HABIT_MIN
## (Han et la synthèse : il ne réagit presque pas) et STRESS_HABIT_MAX (un berger face aux loups). Le deuil
## d'un ami (ou frère d'armes) n'y est pas soumis (contexte « friend »).
const STRESS_HABIT_MIN := 0.1
const STRESS_HABIT_MAX := 2.0
## Après une exposition surmontée (le héros ne s'est pas effondré), le danger vécu qu'on compare à son
## attente (after_encounter, mode « watched ») : plus bas que l'appréhension de départ, donc la peur baisse.
const HABIT_SURVIVED_DANGER := 30.0
## Accès qui changent le stress d'un type (ou de tous : « all ») : facteur.
const STRESS_ACCESS := {
	"roc": {"all": STRESS_ROC_FACTOR},          # Stabilité 70 (cahier)
	"sang_froid": {"ally_death": 0.0},          # Détachement 70 : aucun stress dû à la mort d'alliés (cahier)
}


# ---------------------------------------------------------------------------
# Qui peut apprendre quoi (catalogue des compétences, colonne « Qui » ; feuille de route v2, « Affinités de
# compétences ») — P2, PersonalityEngine.can_learn
# ---------------------------------------------------------------------------
# Une compétence hors des affinités du héros ne s'apprend pas (ni éveil, ni entraînement, ni usage) : il
# « stagne ». La synthèse et la promotion passent outre (comme Han qui reçoit Calme par synthèse).
# Le catalogue écrit les seuils sur l'ancienne échelle 0 à 100 (« Stabilité 75+ ») : ils sont réécrits ici
# sur l'échelle des paliers (-100 à +100), adaptés au sens de chaque compétence (choix du porteur du projet :
# « recréer et adapter » ; repère : ancien 50 = 0, 60 = +20, 75 = +50).
# Conditions : [lecture, opération, palier] ; lecture = un axe ou un composite ; « all » : toutes ; « any » :
# au moins une ; « none » : aucune (un craintif n'éveille pas Berserk). Les compétences absentes : tout le monde.
const SKILL_CONDITIONS := {
	# Catalogue : « Stabilité 75+ (sauf synthèse) » ; c'est l'exclusive du pôle Stabilité (palier 50).
	"Calme": {"all": [["STA", ">=", 5]], "text": "Stabilité +50"},
	# Catalogue : « Colère ou ambition haute » ; feuille de route : « courage ou ambition haute » ; onglet Axes :
	# Sauvagerie (Colère +50) donne accès à Berserk ; « un craintif n'éveille pas Berserk ».
	"Berserk": {"any": [["COL", ">=", 5], ["AMB", ">=", 5], ["courage", ">=", 4]], "none": [["courage", "<=", -4]],
		"text": "Colère +50, Ambition +50 ou Courage +40 ; jamais un craintif (Courage -40)"},
	# Catalogue : « Constitution basse ou curiosité haute ».
	"Mouvement souple": {"any": [["CON", "<=", -3], ["CUR", ">=", 3]], "text": "Constitution -30 ou Curiosité +30"},
	# Catalogue : « Audace ou persévérance 50+ » (ancienne échelle : au-dessus du milieu).
	"Résistance à la douleur": {"any": [["AUD", ">=", 0], ["PER", ">=", 0]], "text": "pas à la fois prudent et sans persévérance"},
	# Catalogue : « Seuil de douleur haut » (évolution de Résistance à la douleur).
	"Esprit combatif": {"all": [["DOU", ">=", 2]], "text": "Seuil de douleur +20"},
	# Catalogue : « Déterminés » (feuille de route : courage ou discipline haute).
	"Résistance aux flammes": {"any": [["courage", ">=", 2], ["discipline", ">=", 2]], "text": "Courage +20 ou Discipline +20"},
}


# ---------------------------------------------------------------------------
# Évolution (« 1. Paliers », section 8)
# ---------------------------------------------------------------------------
## Coût en points d'évolution pour atteindre un palier (en valeur absolue) en s'éloignant de zéro.
const EVOLUTION_COST := {1: 10, 2: 10, 3: 10, 4: 10, 5: 10, 6: 15, 7: 25, 8: 40, 9: 60, 10: 100}
## Revenir d'un palier vers zéro coûte toujours ceci : on s'adoucit plus facilement qu'on ne se durcit.
const EVOLUTION_COST_SOFTEN := 10
## L'acharné : les gains d'évolution des axes travaillés sont multipliés par ceci par palier de
## Persévérance (x1,05 par palier ; à Persévérance -50, x0,78).
const ACHARNEMENT_PER_TIER := 1.05


# ---------------------------------------------------------------------------
# Comportements (« 5. Facettes », section 2) : 18 poids, jamais nuls
# ---------------------------------------------------------------------------
## Score = somme (axe / 100 x poids), divisée par la somme des poids en valeur absolue, x 100.
## Poids dans l'ordre de AXIS_ORDER (AUD, CUR, SEN, COL, PER, MAI, EMP, HON, AMB, LOY, FOI, STA, OPT,
## VIT, CON, DOU, ACU, RYT).
const BEHAVIOURS := {
	"life_debt": {"name": "Dette de vie",
		"weights": [0.05, 0.05, 0.40, -0.10, 0.10, 0.10, 0.60, 0.40, -0.20, 0.70, 0.20, 0.05, 0.10, 0.05, 0.05, 0.05, 0.05, 0.05]},
	"betray_wish": {"name": "Envie de trahir",
		"weights": [0.10, 0.10, -0.30, 0.20, 0.10, 0.05, -0.70, -0.60, 0.60, -0.60, -0.10, 0.05, 0.10, 0.05, 0.05, 0.05, 0.10, 0.05]},
	"betray_skill": {"name": "Capacité à trahir sans être vu",
		"weights": [-0.30, 0.10, -0.10, -0.30, 0.30, 0.60, -0.10, -0.50, 0.20, 0.05, -0.05, 0.30, 0.05, -0.10, 0.05, 0.10, 0.40, 0.10]},
	"cruelty": {"name": "Cruauté envers les faibles",
		"weights": [0.10, 0.05, -0.40, 0.50, 0.05, -0.10, -0.80, -0.20, 0.30, -0.10, 0.10, 0.05, -0.10, 0.10, 0.10, 0.10, 0.05, 0.05]},
	"obey_strong": {"name": "Obéissance au plus fort",
		"weights": [-0.15, -0.10, 0.10, -0.25, 0.10, 0.30, 0.05, 0.10, 0.30, 0.50, 0.30, 0.05, 0.05, -0.05, -0.05, -0.05, 0.05, -0.05]},
	"sacrifice": {"name": "Sacrifice",
		"weights": [0.30, 0.05, 0.30, 0.10, 0.20, 0.10, 0.80, 0.20, -0.10, 0.50, 0.30, 0.10, 0.20, 0.10, 0.15, 0.20, 0.10, 0.05]},
	"fear_flee": {"name": "Peur, fuite",
		"weights": [-0.60, -0.10, 0.20, -0.20, -0.30, -0.30, 0.10, 0.05, -0.10, -0.10, 0.10, -0.50, -0.30, -0.05, -0.15, -0.25, 0.10, 0.05]},
}


# ---------------------------------------------------------------------------
# Tics (palier 30 : « un tic lié à ce pôle », ce que voit le Maître : le geste)
# ---------------------------------------------------------------------------
## Deux tics par pôle. Ils n'ont pas encore d'effet ni d'affichage hors du mode dev (P3 : notify).
const TICS := {
	"AUD+": ["Se place toujours devant les autres", "Fait tourner son arme en attendant"],
	"AUD-": ["Regarde toujours où est la sortie", "Recule d'un pas quand on l'approche"],
	"CUR+": ["Ramasse et examine tout ce qu'il trouve", "Pose des questions à tout le monde"],
	"CUR-": ["Mange toujours à la même place", "Range ses affaires dans le même ordre"],
	"SEN+": ["Garde un souvenir d'un proche sur lui", "Se retourne quand quelqu'un soupire"],
	"SEN-": ["Ne regarde jamais les tombes", "Ne retient pas les prénoms"],
	"COL+": ["Serre les poings quand on le contredit", "Frappe les murs quand il perd"],
	"COL-": ["Laisse passer les insultes sans un mot", "Respire lentement avant de répondre"],
	"PER+": ["S'entraîne encore quand les autres sont partis", "Recommence le même geste jusqu'à le réussir"],
	"PER-": ["Pose son arme dès qu'il est fatigué", "Remet à demain ce qui est difficile"],
	"MAI+": ["Ne montre jamais sa douleur", "Parle toujours d'une voix égale"],
	"MAI-": ["Coupe la parole aux autres", "Part au quart de tour"],
	"EMP+": ["Partage sa ration avec le plus faible", "S'arrête près des blessés"],
	"EMP-": ["Se sert toujours en premier", "Garde la meilleure place près du feu"],
	"HON+": ["Rend toujours ce qu'il emprunte", "Dit tout haut ce qu'il pense"],
	"HON-": ["Change sa version des faits", "A toujours un objet qui n'est pas à lui"],
	"AMB+": ["Regarde le tableau des exploits", "Se porte volontaire avant qu'on demande"],
	"AMB-": ["Laisse la parole aux autres", "Se tient en retrait sur les portraits"],
	"LOY+": ["Reste près de son chef", "Défend les absents"],
	"LOY-": ["Dort dos au mur", "Vérifie deux fois ce qu'on lui dit"],
	"FOI+": ["Prie avant chaque combat", "Porte un talisman"],
	"FOI-": ["Se moque des présages", "Compte les chances à voix basse"],
	"STA+": ["Dort bien même la veille d'un étage", "Garde le même visage en toute circonstance"],
	"STA-": ["Se ronge les ongles", "Sursaute au moindre bruit"],
	"OPT+": ["Siffle en marchant", "Dit toujours « la prochaine fois »"],
	"OPT-": ["Prépare toujours une potion de trop", "Dit toujours « ça va mal finir »"],
	"VIT+": ["Ne tient pas en place", "Rit fort et souvent"],
	"VIT-": ["Parle peu", "Se repose dès qu'il peut"],
	"CON+": ["Porte les charges des autres", "Ne tombe jamais malade"],
	"CON-": ["S'essouffle dans les escaliers", "Se couvre même quand il fait chaud"],
	"DOU+": ["Ne remarque pas ses égratignures", "Rit de ses blessures"],
	"DOU-": ["Grimace au moindre choc", "Panse la plus petite coupure"],
	"ACU+": ["Tourne la tête avant tout le monde", "Remarque les détails que personne ne voit"],
	"ACU-": ["Se fait souvent surprendre", "Plisse les yeux pour lire"],
	"RYT+": ["Veille tard près du feu", "Bâille toute la matinée"],
	"RYT-": ["Est debout avant l'aube", "S'endort dès la nuit tombée"],
}


# ---------------------------------------------------------------------------
# Couches de profondeur (« 2. Axes », section 3)
# ---------------------------------------------------------------------------
## Chaque couche : ses options, et pour chacune les axes qui la rendent plus probable (le tirage note
## chaque option selon ces axes, plus du hasard). Valeur et attachement bougent rarement ; le besoin peut
## changer avec la vie au lobby (plus tard). Aucun effet pour l'instant (P2 et suivantes).
const LAYERS := {
	"value": {"name": "Valeur principale", "options": {
		"pouvoir": {"name": "Pouvoir", "axes": {"AMB": 1.0, "HON": -0.5}},
		"reussite": {"name": "Réussite", "axes": {"AMB": 0.8, "PER": 0.6}},
		"plaisir": {"name": "Plaisir", "axes": {"VIT": 0.8, "PER": -0.5}},
		"aventure": {"name": "Aventure", "axes": {"CUR": 0.8, "AUD": 0.6}},
		"liberte": {"name": "Liberté", "axes": {"LOY": -0.7, "MAI": -0.4}},
		"justice": {"name": "Justice", "axes": {"COL": 0.5, "EMP": 0.5, "HON": 0.4}},
		"bienveillance": {"name": "Bienveillance", "axes": {"EMP": 0.8, "SEN": 0.5}},
		"tradition": {"name": "Tradition", "axes": {"CUR": -0.7, "FOI": 0.6}},
		"obeissance": {"name": "Obéissance", "axes": {"LOY": 0.8, "MAI": 0.4}},
		"securite": {"name": "Sécurité", "axes": {"AUD": -0.8, "OPT": -0.4}},
	}},
	"need": {"name": "Besoin", "options": {
		"securite": {"name": "Sécurité", "axes": {"STA": -0.6, "AUD": -0.5}},
		"appartenance": {"name": "Appartenance", "axes": {"SEN": 0.7, "LOY": 0.4}},
		"competence": {"name": "Compétence", "axes": {"PER": 0.6, "AMB": 0.4}},
		"autonomie": {"name": "Autonomie", "axes": {"LOY": -0.6, "CUR": 0.4}},
		"reconnaissance": {"name": "Reconnaissance", "axes": {"AMB": 0.8, "STA": -0.3}},
	}},
	"fear": {"name": "Peur profonde", "options": {
		"mourir": {"name": "Mourir", "axes": {"AUD": -0.8, "DOU": -0.3}},
		"abandon": {"name": "Être abandonné", "axes": {"SEN": 0.7, "STA": -0.4}},
		"inutile": {"name": "Être inutile", "axes": {"AMB": 0.6, "OPT": -0.5}},
		"perdre_proche": {"name": "Perdre un proche", "axes": {"EMP": 0.6, "SEN": 0.5}},
		"deshonneur": {"name": "Le déshonneur", "axes": {"HON": 0.6, "LOY": 0.5}},
	}},
	"attachment": {"name": "Attachement", "options": {
		"secure": {"name": "Sécure", "axes": {"STA": 0.7, "OPT": 0.4, "LOY": 0.3}},
		"anxieux": {"name": "Anxieux", "axes": {"SEN": 0.6, "STA": -0.6}},
		"evitant": {"name": "Évitant", "axes": {"SEN": -0.7, "LOY": -0.4}},
		"desorganise": {"name": "Désorganisé", "axes": {"STA": -0.8, "MAI": -0.4}},
	}},
}
## Hasard dans le tirage d'une couche (en points de score, à côté des axes notés de -1 à 1).
const LAYER_NOISE := 0.8


# ---------------------------------------------------------------------------
# Talent : croissance et aptitudes par domaine (document de référence, section 2)
# ---------------------------------------------------------------------------
# La croissance est la valeur hero["growth"] qui existait déjà (heroes.gd). Les aptitudes vont de 1
# (faible) à 5 (exceptionnelle), fixes sauf événement exceptionnel. Aucun effet pour l'instant (P2 :
# armes de prédilection, plafonds de maîtrise).
const APTITUDE_DOMAINS := {
	"epee": "Épée", "lance": "Lance", "dague": "Dague", "fouet": "Fouet", "arc": "Arc",
	"bouclier": "Bouclier", "magie": "Magie", "soin": "Soin", "metiers": "Métiers",
}
const APTITUDE_MIN := 1
const APTITUDE_MAX := 5
## Aptitude moyenne de départ selon les étoiles (avant le hasard ±1 et le métier).
const APTITUDE_BASE := {1: 1.5, 2: 2.0, 3: 2.5, 4: 3.0, 5: 3.5}


# ---------------------------------------------------------------------------
# Effort (acharnement)
# ---------------------------------------------------------------------------
# Points cumulés en vivant des choses dures ; ne fait que monter. Départ à 0. Les gains viendront avec
# les événements (P4) ; l'acharnement (ACHARNEMENT_PER_TIER) multiplie déjà les gains d'évolution des
# axes travaillés.
const EFFORT_START := 0.0


# ---------------------------------------------------------------------------
# Les anciens traits deviennent des lectures de paliers (« 1. Paliers », section 12)
# ---------------------------------------------------------------------------
## Les neuf traits déjà codés (Courageux... Meneur, voir GamePersonality.TRAITS) gardent leurs effets, mais ne
## sont plus tirés à part : un héros les a quand ses paliers le disent.
## « composite » : {composite: palier minimal (négatif = au plus ce palier)} ; « needs » : {axe: palier minimal
## dans le sens du pôle (négatif = pôle bas)}, comme SYNERGIES ; « at_most » : {axe: palier maximal} ;
## « synergy » : l'accès croisé qu'il faut avoir.
const OLD_TRAITS := {
	# Courageux / Lâche : seuil ±40 (choix du porteur du projet, étape 0 avant P1b ; le cahier disait ±50).
	"Courageux": {"composite": {"courage": 4}},           # Courage >= +40
	"Lâche": {"composite": {"courage": -4}},              # Courage <= -40
	"Loyal": {"needs": {"LOY": 5}},                       # Loyauté >= +50
	"Paresseux": {"needs": {"PER": -5}},                  # Persévérance <= -50 (Abandon)
	"Querelleur": {"needs": {"COL": 5}, "at_most": {"EMP": 2}},  # Colère >= +50 et Empathie <= +20
	"Protecteur": {"needs": {"EMP": 5, "AUD": 3}},        # Empathie >= +50 et Audace >= +30
	"Ambitieux": {"needs": {"AMB": 5}},                   # Ambition >= +50
	"Mauvais": {"needs": {"EMP": -5, "HON": -3}},         # Égocentrisme >= 50 et Ruse >= 30
	"Meneur": {"synergy": "meneur"},                      # Ambition 40, Empathie 30, Stabilité 30
}


# ---------------------------------------------------------------------------
# Profils des héros secrets (« 1. Paliers », section 11)
# ---------------------------------------------------------------------------
# Écrits à la main (convertis de l'ancienne table et complétés d'après l'œuvre) : ils ne suivent ni la
# répartition, ni la garantie de relief, ni le plafond des absolus. Pas de métier.
# « tiers » : paliers (valeur / 10). « layers » : la couche la plus proche parmi LAYERS, et « layer_notes » :
# le texte du cahier (quand aucune option ne le dit exactement, ou quand le cahier ne la donne pas : marqué
# « interprété »). « talent » : aptitudes (TALENT_LEVELS, et « aptitudes » pour un domaine précis) ; la
# croissance reste celle de SECRET_HEROES (heroes.gd), inchangée. « effort » : EFFORT_LEVELS.
# « notes » : ce qui viendra avec d'autres mécaniques (accoutumance, arcs, liens de départ).

## Mots du cahier pour le talent et l'effort → valeurs (provisoires).
const TALENT_LEVELS := {"très faible": 1, "faible": 2, "moyen": 3, "élevé": 4, "très élevé": 5}
const EFFORT_LEVELS := {"faible": 10.0, "moyen": 30.0, "élevé": 60.0, "très élevé": 90.0, "maximal": 120.0}

const SECRET_PROFILES := {
	"Han": {
		"tiers": {"AUD": 4, "CUR": 4, "SEN": -2, "COL": -4, "PER": 9, "MAI": 8, "EMP": -3, "HON": -2, "AMB": 8,
			"LOY": -4, "FOI": -7, "STA": 8, "OPT": 2, "VIT": 2, "CON": -2, "DOU": 3, "ACU": 5, "RYT": 0},
		"layers": {"value": "reussite", "need": "competence", "fear": "deshonneur", "attachment": "evitant"},
		"layer_notes": {"value": "Ne jamais perdre, survivre", "need": "interprété", "fear": "Perdre le contrôle, la défaite",
			"attachment": "Évitant (s'ouvre lentement)"},
		"talent": "élevé", "effort": "très élevé",
		"notes": ["Accoutumance maximale à la synthèse dès le départ"],
		# Sujets connus dès le départ, [connaissance, appréhension] (comme BACKGROUND_SUBJECTS).
		"subjects": {"synthesis": [4, 0]},
	},
	"Jenna": {
		"tiers": {"AUD": 4, "CUR": 6, "SEN": 6, "COL": -1, "PER": 4, "MAI": 2, "EMP": 4, "HON": 6, "AMB": -3,
			"LOY": 7, "FOI": 0, "STA": 8, "OPT": 8, "VIT": 6, "CON": 0, "DOU": 0, "ACU": 7, "RYT": -2},
		"layers": {"value": "obeissance", "need": "appartenance", "fear": "inutile", "attachment": "secure"},
		"layer_notes": {"value": "Appartenir, suivre la bonne personne", "need": "interprété", "fear": "Devenir inutile"},
		"talent": "faible", "aptitudes": {"arc": 5, "dague": 5}, "effort": "moyen",
		"notes": ["Croissance faible (celle de SECRET_HEROES), aptitudes très hautes à l'arc et à la dague"],
	},
	"Aaron": {
		"tiers": {"AUD": -4, "CUR": -2, "SEN": 5, "COL": -2, "PER": 9, "MAI": 5, "EMP": 5, "HON": 8, "AMB": -6,
			"LOY": 8, "FOI": 2, "STA": -2, "OPT": -1, "VIT": 0, "CON": -2, "DOU": 1, "ACU": 2, "RYT": -3},
		"layers": {"value": "bienveillance", "need": "appartenance", "fear": "mourir", "attachment": "anxieux"},
		"layer_notes": {"value": "La famille (rentrer pour sa petite sœur)", "need": "interprété",
			"fear": "Mourir sans revoir sa sœur"},
		"talent": "très faible", "effort": "maximal",
		"notes": ["L'acharné", "Commence Déboussolé (arcs, à venir)"],
	},
	"Hansen": {
		"tiers": {"AUD": 1, "CUR": 1, "SEN": 5, "COL": 0, "PER": 1, "MAI": -2, "EMP": 5, "HON": 3, "AMB": -1,
			"LOY": 8, "FOI": 0, "STA": -1, "OPT": 6, "VIT": 5, "CON": 2, "DOU": 0, "ACU": 0, "RYT": 0},
		"layers": {"value": "bienveillance", "need": "appartenance", "fear": "perdre_proche", "attachment": "secure"},
		"layer_notes": {"value": "La camaraderie", "need": "interprété", "fear": "Perdre ses amis"},
		"talent": "faible", "effort": "moyen",
		"notes": ["Ami de Zid dès le départ (lien de départ pas encore fait)"],
	},
	"Zid": {
		"tiers": {"AUD": -1, "CUR": 1, "SEN": 5, "COL": 0, "PER": 1, "MAI": -4, "EMP": 5, "HON": 3, "AMB": -1,
			"LOY": 8, "FOI": 0, "STA": -3, "OPT": 6, "VIT": 5, "CON": 2, "DOU": -4, "ACU": 0, "RYT": 0},
		"layers": {"value": "bienveillance", "need": "appartenance", "fear": "perdre_proche", "attachment": "anxieux"},
		"layer_notes": {"value": "La camaraderie", "need": "interprété", "fear": "Perdre ses amis"},
		"talent": "faible", "effort": "moyen",
		"notes": ["Ami de Hansen dès le départ (lien de départ pas encore fait)", "Panique quand il est blessé"],
	},
	"Shei": {
		"tiers": {"AUD": 8, "CUR": 0, "SEN": -1, "COL": -4, "PER": 7, "MAI": 8, "EMP": 4, "HON": 8, "AMB": 1,
			"LOY": 6, "FOI": 3, "STA": 9, "OPT": 2, "VIT": 2, "CON": 5, "DOU": 4, "ACU": 3, "RYT": -2},
		"layers": {"value": "obeissance", "need": "competence", "fear": "deshonneur", "attachment": "secure"},
		"layer_notes": {"value": "Le devoir", "need": "interprété", "fear": "Le déshonneur",
			"attachment": "Sécure (accepte son sort avec calme)"},
		"talent": "élevé", "effort": "élevé",
		"notes": [],
	},
	"Yvolka": {
		"tiers": {"AUD": 3, "CUR": 5, "SEN": 2, "COL": 4, "PER": -5, "MAI": -6, "EMP": -2, "HON": 1, "AMB": 8,
			"LOY": 0, "FOI": 0, "STA": -3, "OPT": 4, "VIT": 3, "CON": -2, "DOU": -3, "ACU": 1, "RYT": 2},
		"layers": {"value": "reussite", "need": "reconnaissance", "fear": "inutile", "attachment": "anxieux"},
		"layer_notes": {"value": "La reconnaissance", "fear": "Être remplacée", "attachment": "Anxieux sous l'orgueil"},
		"talent": "très élevé", "effort": "faible",
		"notes": ["La Suffisante"],
	},
	"Edith": {
		"tiers": {"AUD": 5, "CUR": 3, "SEN": -2, "COL": -2, "PER": 6, "MAI": 7, "EMP": 6, "HON": 1, "AMB": 4,
			"LOY": 3, "FOI": -2, "STA": 3, "OPT": -2, "VIT": 1, "CON": 0, "DOU": 2, "ACU": 6, "RYT": 3},
		"layers": {"value": "bienveillance", "need": "appartenance", "fear": "perdre_proche", "attachment": "evitant"},
		"layer_notes": {"value": "Protéger son équipe", "need": "interprété", "fear": "Perdre ceux qu'elle mène",
			"attachment": "Évitant mais chaleureux"},
		"talent": "élevé", "effort": "élevé",
		"notes": ["Meneuse (synergie Meneur)"],
	},
}


# ---------------------------------------------------------------------------
# Les 8 briques du moteur commun (onglet « 4. Interactions », section 2) — P1b : structures seulement
# ---------------------------------------------------------------------------
# Rangées dans hero["persona"]["mind"], vides ou neutres, sans aucun effet en jeu (elles se rempliront
# en P4 et P5). Les liens existants (GameData.bonds) restent la source des relations actuelles ; les
# opinions s'y ajoutent sans les remplacer.

## Besoins (0 à 100, ils baisseront avec le temps) : un besoin satisfait vaut NEED_START.
## « axes » : ce qui pèsera sur son poids (need_weight), comme les couches : axe → coefficient.
const NEEDS := {
	"securite": {"name": "Sécurité", "axes": {"AUD": -0.5, "STA": -0.4}},
	"repos": {"name": "Repos", "axes": {"VIT": -0.4, "CON": -0.3}},
	"appartenance": {"name": "Appartenance", "axes": {"SEN": 0.6, "LOY": 0.3}},
	"reconnaissance": {"name": "Reconnaissance", "axes": {"AMB": 0.8}},
	"autonomie": {"name": "Autonomie", "axes": {"LOY": -0.5, "CUR": 0.3}},
	"progres": {"name": "Progrès", "axes": {"PER": 0.5, "AMB": 0.4}},
	"sens": {"name": "Sens", "axes": {"FOI": 0.7}},
}
const NEED_START := 100.0
## Le besoin de la couche « besoin » pèse plus lourd (layers["need"] a les mêmes identifiants, sauf
## « competence », rattaché au Progrès).
const NEED_LAYER_BONUS := 0.5
const NEED_FROM_LAYER := {"securite": "securite", "appartenance": "appartenance", "competence": "progres",
	"autonomie": "autonomie", "reconnaissance": "reconnaissance"}

## Attentes : ce que le héros trouve normal. Départ : 0, sauf le rang, qui suit les étoiles (un 5★ se
## vexera d'être traité comme un 1★).
const EXPECTATIONS := {
	"confort": {"name": "Confort", "start": 0.0},
	"rang": {"name": "Rang", "start_per_star": 20.0},
	"butin": {"name": "Part du butin", "start": 0.0},
	"reconnaissance": {"name": "Reconnaissance", "start": 0.0},
}

## Stratégies d'adaptation au stress (choisies selon la personnalité en P4) : saines ou coûteuses.
## Une stratégie répétée devient une habitude (mind["coping"]["habits"] : stratégie → nombre de fois).
const COPING_STRATEGIES := {
	"s_entrainer": {"name": "S'entraîner", "healthy": true},
	"parler_ami": {"name": "Parler à un ami", "healthy": true},
	"prier": {"name": "Prier", "healthy": true},
	"dormir": {"name": "Dormir", "healthy": true},
	"s_isoler": {"name": "S'isoler", "healthy": true},
	"se_battre": {"name": "Se battre", "healthy": false},
	"voler": {"name": "Voler", "healthy": false},
	"mentir": {"name": "Mentir", "healthy": false},
	"exiger": {"name": "Exiger", "healthy": false},
	"refuser_mission": {"name": "Refuser une mission", "healthy": false},
}

## Désirs (1 à 3 par héros, nés des couches, en P5) : le catalogue.
const DESIRES := {
	"plus_fort": "Devenir le plus fort",
	"proteger": "Protéger quelqu'un",
	"maitriser_arme": "Maîtriser une arme",
	"reconnu_maitre": "Être reconnu par le Maître",
	"venger": "Venger un ami",
	"comprendre_tour": "Comprendre la Tour",
}

## Bornes des opinions (entre héros, et envers le Maître : la confiance).
const OPINION_MIN := -100.0
const OPINION_MAX := 100.0
## Pensées, souvenirs et décisions gardées au plus (les plus anciennes partent).
const THOUGHTS_MAX := 20
const MEMORIES_MAX := 30


# ---------------------------------------------------------------------------
# Les cercles (onglet « 4. Interactions », section 2 bis) — P1b : données et lecture, aucun effet en jeu
# ---------------------------------------------------------------------------
# On n'est pas le même avec tout le monde : la valeur d'un axe utilisée envers une cible est le palier de
# base + le décalage du cercle de la cible (CIRCLE_SHIFTS, plus celui du rapport à la hiérarchie). Un
# héros peut appartenir à plusieurs cercles : on prend le plus proche, dans l'ordre de CIRCLES.
const CIRCLES := {
	"intime": "Intimes (ami proche, sauveur, mentor)",
	"rival": "Rivaux et ennemis",
	"groupe": "Groupe (sa clique, son équipe)",
	"nouveau": "Nouveaux",
	"plus_fort": "Plus forts",
	"plus_faible": "Plus faibles",
	"lobby": "Lobby",
	"maitre": "Le Maître",
}
## Décalages communs à tous (en paliers), avant ceux du rapport à la hiérarchie.
const CIRCLE_SHIFTS := {
	"intime": {"EMP": 3, "LOY": 3, "HON": 2},
	"rival": {"EMP": -3, "COL": 3, "LOY": -3},
	"groupe": {"EMP": 1, "LOY": 1},
}
## Seuils : opinion d'un intime ou d'un rival ; un « nouveau » a fait moins de NEW_FIGHTS combats ;
## écart de rang perçu pour être « plus fort » ou « plus faible ».
const OPINION_INTIMATE := 60.0
const OPINION_RIVAL := -60.0
const NEW_FIGHTS := 3
const RANK_GAP := 15.0
## Ce qui fait le rang perçu d'un héros (points) : étoiles, niveau, combats faits, Meneur, favori du Maître.
## (Force vue en combat, victimes, humiliations : avec les événements, en P4.)
const RANK_FACTORS := {"rarity": 10.0, "level": 1.0, "fights": 0.5, "leader": 5.0, "favorite": 5.0}

## Le rapport à la hiérarchie, tiré à la création selon les axes (comme les couches) ; il pourra changer
## avec un arc. « axes » : axe → coefficient du tirage ; « shifts » : cercle → {axe: décalage en paliers}.
## Envers le Maître (le plus fort de tous), on prend les décalages « plus_fort ».
## Exemple du cahier, pour un Courtisan : envers les plus forts, Empathie +40, Maîtrise de soi +30,
## Honnêteté -20 ; envers les plus faibles et les nouveaux, Empathie -50, Colère +30, Ambition +20.
const HIERARCHY_STANCES := {
	"egalitaire": {"name": "Égalitaire", "axes": {"HON": 0.6, "EMP": 0.4, "AMB": -0.4}, "shifts": {}},
	"deferent": {"name": "Déférent", "axes": {"LOY": 0.7, "MAI": 0.4, "AMB": -0.4},
		"shifts": {"plus_fort": {"LOY": 3, "MAI": 2, "COL": -2}}},
	"courtisan": {"name": "Courtisan", "axes": {"AMB": 0.6, "HON": -0.6, "EMP": -0.4},
		"shifts": {"plus_fort": {"EMP": 4, "MAI": 3, "HON": -2}, "plus_faible": {"EMP": -5, "COL": 3, "AMB": 2},
			"nouveau": {"EMP": -5, "COL": 3, "AMB": 2}}},
	"dominateur": {"name": "Dominateur", "axes": {"AMB": 0.7, "COL": 0.5, "LOY": -0.3},
		"shifts": {"plus_fort": {"COL": 2, "LOY": -3}, "plus_faible": {"AMB": 2, "EMP": 1}, "nouveau": {"AMB": 2}}},
	"rebelle": {"name": "Rebelle", "axes": {"LOY": -0.6, "COL": 0.5, "EMP": 0.4},
		"shifts": {"plus_fort": {"LOY": -4, "COL": 3}, "plus_faible": {"EMP": 3}, "nouveau": {"EMP": 2}}},
	"protecteur": {"name": "Protecteur", "axes": {"EMP": 0.7, "LOY": 0.4, "COL": -0.3},
		"shifts": {"plus_fort": {"LOY": 1}, "plus_faible": {"EMP": 3, "MAI": 1}, "nouveau": {"EMP": 3, "MAI": 1}}},
}
## Hasard dans le tirage du rapport à la hiérarchie (comme LAYER_NOISE).
const STANCE_NOISE := 0.6


# ---------------------------------------------------------------------------
# Sujets : appréhension et connaissance (document de référence, section 3 bis) — P1b : sans effet en combat
# ---------------------------------------------------------------------------
# Un sujet : une espèce ou une famille de monstres, la synthèse, le lobby, un lieu, un type de mission, la
# vue du sang... Deux valeurs par sujet : l'appréhension (0 à 100, le danger attendu, qui réglera la peur
# et le stress en P2) et la connaissance (niveaux 0 à 4, ce qu'il sait, qui réglera ce qu'il fait de mieux).
# « danger » : appréhension de départ d'un héros qui n'en sait rien ; « enemy » : nom de base de l'ennemi
# (tower.gd) ; « family » : sa famille (un sujet elle aussi).
const SUBJECTS := {
	"monster:gobelin": {"name": "Gobelins", "type": "monstre", "danger": 35, "enemy": "Gobelin", "family": "family:gobelins"},
	"monster:loup_noir": {"name": "Loups noirs", "type": "monstre", "danger": 45, "enemy": "Loup noir", "family": "family:betes"},
	"monster:squelette_archer": {"name": "Squelettes archers", "type": "monstre", "danger": 45, "enemy": "Squelette archer", "family": "family:morts_vivants"},
	"monster:golem": {"name": "Golems de pierre", "type": "monstre", "danger": 55, "enemy": "Golem de pierre", "family": "family:creatures"},
	"monster:chaman": {"name": "Chamans", "type": "monstre", "danger": 40, "enemy": "Chaman", "family": "family:gobelins"},
	"monster:sorcier_gobelin": {"name": "Sorciers gobelins", "type": "monstre", "danger": 55, "enemy": "Sorcier gobelin", "family": "family:gobelins"},
	"monster:chef_gobelin": {"name": "Chef gobelin", "type": "boss", "danger": 75, "enemy": "Chef gobelin", "family": "family:gobelins"},
	"monster:minotaure": {"name": "Minotaure", "type": "boss", "danger": 85, "enemy": "Minotaure", "family": "family:betes"},
	"monster:liche": {"name": "Liche", "type": "boss", "danger": 90, "enemy": "Liche", "family": "family:morts_vivants"},
	"monster:hydre": {"name": "Hydre", "type": "boss", "danger": 90, "enemy": "Hydre", "family": "family:betes"},
	"family:gobelins": {"name": "Famille des gobelins", "type": "famille", "danger": 35},
	"family:betes": {"name": "Bêtes", "type": "famille", "danger": 40},
	"family:morts_vivants": {"name": "Morts-vivants", "type": "famille", "danger": 50},
	"family:creatures": {"name": "Créatures souterraines", "type": "famille", "danger": 50},
	"family:humanoides": {"name": "Humanoïdes", "type": "famille", "danger": 40},
	"synthesis": {"name": "La synthèse", "type": "synthese", "danger": 80},
	"lobby": {"name": "Le lobby", "type": "lieu", "danger": 20},
	"place:tour": {"name": "La Tour", "type": "lieu", "danger": 50},
	"place:mine": {"name": "Mine d'Isralta", "type": "lieu", "danger": 40},
	"place:foret": {"name": "Forêt Kenout", "type": "lieu", "danger": 40},
	"place:plateau": {"name": "Plateau Sinmiel", "type": "lieu", "danger": 40},
	"place:obscurite": {"name": "L'obscurité", "type": "lieu", "danger": 45},
	"mission:survie": {"name": "Survie (horde)", "type": "mission", "danger": 65},
	"mission:defense": {"name": "Défense de la cité", "type": "mission", "danger": 70},
	"sight:blood": {"name": "La vue du sang", "type": "vue", "danger": 40},
	"sight:death": {"name": "La mort", "type": "vue", "danger": 55},
	"sight:wounded": {"name": "Les blessés", "type": "vue", "danger": 35},
}

## Niveaux de connaissance (0 = rien) : ce que le héros sait, et ce qu'on le verra faire en combat (P2).
## « cost » : points de progression pour atteindre ce niveau depuis le précédent.
const KNOWLEDGE_LEVELS := {
	1: {"name": "Reconnaît", "knows": "Le nom, la famille", "seen": "Il ne gèle plus à l'apparition", "cost": 10.0},
	2: {"name": "Lit les attaques", "knows": "Les gestes qui annoncent un coup", "seen": "Il recule ou lève le bouclier avant le coup", "cost": 30.0},
	3: {"name": "Points faibles", "knows": "Où frapper, quel élément", "seen": "Il vise la gorge, change d'arme tout seul", "cost": 60.0},
	4: {"name": "Comportement", "knows": "Fuite, embuscade, appât, chef de meute", "seen": "Il coupe la fuite, frappe le chef en premier", "cost": 100.0},
}
const KNOWLEDGE_MAX := 4
## Niveau le plus haut qu'on atteint selon la façon d'apprendre : en combattant (le niveau 4 ne s'apprend
## que sur le terrain), en regardant, par un récit au lobby, à la bibliothèque (3 avec un bibliothécaire).
const KNOWLEDGE_CAP := {"fought": 4, "watched": 3, "heard": 1, "lobby": 2, "study": 2, "study_librarian": 3}

## Le passé (métier ou origine) : sujets connus avant l'invocation, [connaissance, appréhension].
## (Chasseur : bêtes niveau 2-3 ; mineur : créatures souterraines, obscurité ; soldat : humanoïdes, sang ;
## boucher : sang ; guérisseur : blessés, mort ; scribe : rien ; berger : connaît les loups et les craint.)
const BACKGROUND_SUBJECTS := {
	"chasseur": {"family:betes": [2, 25], "monster:loup_noir": [3, 30]},
	"berger": {"monster:loup_noir": [2, 70]},
	"mineur": {"family:creatures": [2, 35], "place:obscurite": [2, 15]},
	"soldat": {"family:humanoides": [2, 30], "sight:blood": [2, 15], "sight:death": [1, 40]},
	"milicien": {"family:humanoides": [1, 35], "sight:blood": [1, 25]},
	"garde": {"family:humanoides": [2, 30], "sight:blood": [1, 25]},
	"mercenaire": {"family:humanoides": [2, 25], "sight:blood": [2, 10], "sight:death": [2, 30]},
	"veteran": {"family:humanoides": [3, 25], "sight:blood": [2, 10], "sight:death": [2, 25]},
	"bandit": {"family:humanoides": [2, 30], "sight:blood": [2, 15]},
	"chevalier_errant": {"family:humanoides": [2, 25], "family:betes": [1, 35]},
	"chasseur_primes": {"family:humanoides": [2, 25], "family:betes": [1, 30]},
	"maitre_armes": {"family:humanoides": [3, 20], "sight:blood": [2, 10]},
	"boucher": {"sight:blood": [3, 0]},
	"guerisseur": {"sight:wounded": [3, 10], "sight:death": [2, 30]},
	"pretre": {"sight:death": [2, 25], "family:morts_vivants": [1, 50]},
	"bucheron": {"place:foret": [2, 15], "family:betes": [1, 40]},
	"scribe": {},
}

## Ce que la personnalité règle dans l'apprentissage (section 3 bis, « La personnalité règle tout ») :
## constantes des fonctions apprehension(), after_encounter(), share_knowledge() (chiffres provisoires).
const APPREHENSION_PER_TIER := {"AUD": -3.0, "OPT": -2.0}  # départ : Prudence et Pessimisme l'augmentent
const LEARN_SHARE := {"fought": 1.0, "watched": 0.4, "heard": 0.1}  # part apprise d'une rencontre
const FEAR_DROP_RATE := 0.3    # part de l'écart apprise quand le danger vécu est plus faible qu'attendu
const FEAR_RISE_RATE := 0.5    # ... plus fort qu'attendu (la peur monte plus vite qu'elle ne baisse)
const FEAR_STABILITY_STEP := 0.06  # Stabilité : la peur baisse plus vite (x1,06 par palier), monte moins
const SCAR_CHANCE := 0.3       # événement grave chez un Vulnérable (Stabilité <= -50) : cicatrice
const HATE_TIER := 5           # ... chez un Colérique ou un Persévérant (>= 50) : haine de ce sujet
const ABSENCE_DAYS := 7        # absence longue : une partie de la peur perdue revient
const SPONTANEOUS_RETURN := 0.3
const RENEWAL_FEAR := 10.0     # lieu nouveau ou nuit : la peur remonte jusqu'à la première rencontre réussie
const RENEWAL_ROUTINE_STEP := 0.1  # Routine (Curiosité négative) : +10 % par palier ; Curiosité : -10 %
const KNOWLEDGE_BASE_POINTS := 5.0  # par rencontre, plus 1 par coup touché, 2 par esquive
const CURIOSITY_LEARN_STEP := 0.05  # Curiosité : apprend plus vite (x1,05 par palier)
const ACUITY_WATCH_STEP := 0.08     # Acuité des sens : apprend mieux en regardant (x1,08 par palier)
const DETACHMENT_STEP := 0.06       # Détachement : s'endurcit vite à la mort (types « vue »)
const SHARE_POINTS := 8.0           # transmission au lobby, par sujet
const SHARE_TEACH_STEP := 0.06      # Empathie de celui qui explique
const SHARE_LISTEN_STEP := 0.04     # Loyauté de celui qui écoute ; Méfiance (<= -50) : il n'écoute pas
const SHARE_FEAR_PULL := 0.1        # un récit rapproche un peu l'appréhension de celle du conteur
## Après un combat de la Tour (P2, GameData.learn_from_battle) : le danger qu'un survivant a vécu, de 0 à 100,
## comparé à son appréhension de chaque sorte de monstre affrontée : part de la vie perdue x « hp_lost »,
## + « agony » s'il a été à l'agonie, + « ally_fallen » par allié tombé, + « defeat » en cas de défaite.
## « Grave » (cicatrice ou haine possibles) : agonie, ou un ami tombé. Chiffres provisoires (projet).
const ENCOUNTER_DANGER := {"hp_lost": 60.0, "agony": 30.0, "ally_fallen": 15.0, "defeat": 20.0}


## Version du profil de personnalité (hero["persona"]["version"]) : à augmenter si on change ce qui est
## enregistré, avec la migration au chargement (PersonalityEngine.migrate).
## 2 : anciens traits lus sur les paliers (« legacy_traits »), profils des héros secrets (« secret_profile »).
## 3 : P1b, les 8 briques (« mind »), cercles (« hierarchy_stance », « debts »), sujets (« subjects »,
##     « pending_report »), raisons des décisions (« decisions »).
const PROFILE_VERSION := 3
