extends Node
## Données et règles du jeu.
## Ce script est chargé automatiquement au lancement (« autoload ») :
## n'importe quel autre script peut y accéder en écrivant GameData.
##
## Les règles suivent le cahier des charges (document « Feuille de route »).

signal gems_changed(new_amount: int)
signal gold_changed(new_amount: int)
## Une ou plusieurs séances d'entraînement viennent de se terminer.
signal training_updated
## Quelque chose a changé dans la cité sans que le joueur y touche (retour du donjon journalier...).
signal lobby_updated

# ---------------------------------------------------------------------------
# Invocation
# ---------------------------------------------------------------------------

## Deux sortes d'invocation (cahier des charges) :
## - « normal » : héros de base, payée en or, la monnaie gagnée en jouant. C'est l'invocation
##   « gratuite » du cahier (sans argent réel) : 1 % de chances d'un 4 étoiles, et pas de 5 étoiles ;
## - « special » : héros spéciaux, payée en gemmes, avec de meilleures chances de hauts rangs.
##   C'est la seule qui peut donner un mage, et elle a un pity (5 étoiles garanti).
## « cost » : prix d'une invocation ; « currency » : "gold" ou "gems" ;
## « rates » : probabilité de chaque rareté (le total fait 1.0, soit 100 %). Chiffres provisoires.
const SUMMON_TYPES := {
	"normal": {"name": "Invocation normale", "cost": 5000, "currency": "gold", "mages": false,
		"rates": {5: 0.0, 4: 0.01, 3: 0.08, 2: 0.31, 1: 0.60}},
	"special": {"name": "Invocation spéciale", "cost": 100, "currency": "gems", "mages": true,
		"rates": {5: 0.02, 4: 0.08, 3: 0.20, 2: 0.30, 1: 0.40}},
}

## Pity de l'invocation spéciale : un héros 5 étoiles est garanti au bout de ce nombre
## d'invocations spéciales sans 5 étoiles.
const PITY_LIMIT := 50

## Couleur associée à chaque rareté.
const RARITY_COLORS := {
	5: Color("f5b82e"),
	4: Color("a35ce0"),
	3: Color("3d8fe0"),
	2: Color("4caf6a"),
	1: Color("8a8f98"),
}

## Rareté des classes, à l'intérieur de chaque rareté d'étoiles : une fois les étoiles tirées,
## on tire la classe selon ce tableau (le total de chaque ligne fait 1.0, soit 100 %).
## Les 1 et 2 étoiles sont des gens ordinaires : tous « Novice ».
## Les mages ne s'obtiennent que par invocation spéciale, avec une très très faible chance :
## 1 % des 3 étoiles et plus. Comme 30 % des invocations spéciales donnent un 3 étoiles ou plus,
## environ 0,3 % des invocations spéciales donnent un mage (à peu près 1 toutes les 330).
## Dans l'invocation normale, la part des mages est simplement retirée du tirage.
## Chiffres provisoires, à régler.
const CLASS_RATES := {
	1: {"Novice": 1.0},
	2: {"Novice": 1.0},
	3: {"Guerrier": 0.30, "Chevalier": 0.20, "Archer": 0.20, "Assassin": 0.15, "Soigneur": 0.14, "Mage": 0.01},
	4: {"Guerrier": 0.27, "Chevalier": 0.22, "Archer": 0.20, "Assassin": 0.15, "Soigneur": 0.15, "Mage": 0.01},
	5: {"Guerrier": 0.25, "Chevalier": 0.22, "Archer": 0.20, "Assassin": 0.16, "Soigneur": 0.16, "Mage": 0.01},
}

## Prénoms des héros ordinaires, tirés au hasard.
const HERO_NAMES := [
	"Aldric", "Séléné", "Kaelen", "Brunhild", "Oriane", "Vesper", "Garrick", "Lysa",
	"Tobias", "Mira", "Doran", "Pip", "Hugo", "Léna", "Bram", "Elrik", "Maëlle",
	"Corentin", "Ysolde", "Thibault", "Nora", "Fenwick", "Isaure", "Gaspard", "Liora",
	"Merrin", "Solène", "Tristan", "Anouk", "Oswin", "Clarisse", "Roderic", "Élise",
	"Bastien", "Myra", "Quentin", "Talia", "Ulric", "Zora", "Émeric",
]

# ---------------------------------------------------------------------------
# Fiche d'un héros
# ---------------------------------------------------------------------------

## Les quatre statistiques d'un héros, avec leur nom affiché.
const STAT_NAMES := {
	"str": "Force",
	"int": "Intelligence",
	"vit": "Santé",
	"dex": "Dextérité",
}

## Statistique favorisée par chaque classe (à la création et à chaque niveau).
const CLASS_MAIN_STAT := {
	"Novice": "",
	"Guerrier": "str",
	"Chevalier": "vit",
	"Archer": "dex",
	"Assassin": "dex",
	"Mage": "int",
	"Soigneur": "int",
}

## Mages : leurs statistiques autres que l'Intelligence partent plus bas (voir _roll_stats).
const MAGE_STAT_MALUS := 7

## Valeur de départ de chaque statistique, selon la rareté.
## Un 1 étoile est une personne ordinaire : environ 10 à 12 partout.
const BASE_STAT := {1: 11, 2: 13, 3: 15, 4: 18, 5: 21}

## Niveau maximum selon la rareté. Arrivé là, il faudra une promotion (plus tard).
const MAX_LEVEL := {1: 10, 2: 20, 3: 30, 4: 40, 5: 50}

## Valeur de croissance normale selon la rareté : le nombre de points de statistiques
## gagnés à chaque niveau. Elle est cachée au joueur.
const GROWTH := {1: 2, 2: 3, 3: 5, 4: 6, 5: 8}

## Chance qu'un 1 étoile ait un talent caché : une croissance bien plus forte que la normale.
const HIDDEN_TALENT_CHANCE := 0.15

## Héros secrets (clins d'œil au manhwa). Ils ne suivent pas les règles : ils sont immortels.
## « code » : le code secret à taper (Paramètres > Codes secrets, ou la Place publique) pour l'obtenir.
## Tous s'obtiennent par code, Han compris (choix du porteur du projet : avant, Han était donné
## dès le début de la partie). Un héros secret qu'on a déjà ne peut pas être obtenu une deuxième fois.
## Les étoiles et classes marquées « à confirmer » sont à ajuster selon le manhwa.
const SECRET_HEROES := {
	# Han : 1 étoile en apparence, mais une croissance de 3 étoiles.
	# Il peut réunir Calme et Berserk, normalement incompatibles.
	"Han": {"rarity": 1, "class": "Novice", "growth": 5, "code": "HAN", "skills": []},
	"Hansen": {"rarity": 1, "class": "Novice", "growth": 2, "code": "HANSEN", "skills": []},
	"Zid": {"rarity": 1, "class": "Novice", "growth": 2, "code": "ZID", "skills": []},  # à confirmer
	"Shei": {"rarity": 4, "class": "Novice", "growth": 6, "code": "SHEI", "skills": []},  # classe à confirmer
	"Jenna": {"rarity": 1, "class": "Archer", "growth": 2, "code": "JENNA",  # étoiles à confirmer
		"skills": [{"name": "Maîtrise de l'arc", "rank": "Débutant", "level": 1}]},
	"Aaron": {"rarity": 1, "class": "Novice", "growth": 2, "code": "AARON", "skills": []},  # à confirmer
}

# ---------------------------------------------------------------------------
# Compétences
# ---------------------------------------------------------------------------
# Une compétence, sur la fiche d'un héros : {"name": ..., "rank": "Débutant", "level": 1}.
# Les héros les gagnent en combat (voir battle.gd) : par l'éveil en situation critique,
# ou en survivant à un saignement. Les chiffres sont des propositions, à ajuster.

## Ce que fait chaque compétence (affiché sur la fiche du héros).
const SKILLS := {
	"Résistance à la douleur": "Les blessures guérissent plus vite : saignements réduits de 10 % par niveau.",
	"Mouvement souple": "Esquive : 3 % de chances par niveau d'éviter complètement un coup.",
	"Calme": "Garde son sang-froid : sous la moitié de sa vie, subit 4 % de dégâts en moins par niveau.",
	"Berserk": "Aux portes de la mort (moins de 30 % de vie), entre en rage : Force, Santé et Dextérité +5, Intelligence -10 (+1 aux bonus par niveau suivant).",
	"Maîtrise de l'arc": "Avec un arc : +3 % de dégâts par niveau. Progresse à chaque tir en combat.",
	"Maîtrise de l'épée": "Avec une épée : +3 % de dégâts par niveau. S'apprend au terrain d'entraînement.",
	"Utilisation du bouclier": "Avec un bouclier : 3 % de dégâts subis en moins par niveau. S'apprend au terrain d'entraînement.",
	"Résistance aux flammes": "Dégâts de feu reçus : 5 % en moins par niveau. S'apprend en subissant du feu, ou en combattant aux côtés d'un mage de feu.",
	"Indomptable": "Saignements et hémorragies : 10 % plus faibles par niveau. S'éveille chez un héros qui saigne en situation critique.",
	"Tueur de gobelins": "Contre les gobelins : +10 % de dégâts par niveau. Exploit : coup fatal au boss de l'étage 5, ou 50 gobelins tués.",
	"Esprit combatif": "Évolution de Résistance à la douleur (au niveau 10) : garde ses effets, et +5 % de dégâts par niveau sous la moitié de sa vie.",
	"Analyse froide": "Observation logique : +10 % de précision (la cible esquive moins) et +10 % de coups critiques par niveau. Rare : 1 % de chances après une synthèse.",
	"Œil de faucon": "Vision et précision à distance : pour les tirs (flèches et sorts), +0,3 case de portée et +5 % de précision par niveau. S'obtient en synthèse, pour ceux qui se battent de loin.",
	"Volonté de fer": "Compétence de promotion : +10 % de vie maximum par niveau.",
	"Second souffle": "Compétence de promotion : une fois par combat, sous 25 % de sa vie, reprend 15 % de sa vie (+5 % par niveau au-delà du premier).",
	"Coup précis": "Compétence de promotion : +5 % de coups critiques par niveau.",
	"Peau de pierre": "Compétence de promotion : 4 % de dégâts subis en moins par niveau.",
	"Vivacité": "Compétence de promotion : coups 5 % plus rapides par niveau.",
	"Surpassement": "Fusion de Calme et Berserk (unique). Garde leurs effets ; quand Berserk se déclenche, ses bonus sont doublés et le héros ne saigne plus, mais il perd 2 % de sa vie chaque seconde, jusqu'à la mort.",
	"Épée et bouclier": "Fusion de Maîtrise de l'épée et Utilisation du bouclier. Garde leurs effets, et +2 % de dégâts à l'épée par niveau.",
	"Forge": "Artisan : à la forge, une pièce du puzzle est placée d'office, et plus de malus « Pas d'artisan ». S'apprend en travaillant comme assistant de la forge.",
}

## Niveau maximum d'une compétence (les rangs au-delà de Débutant viendront plus tard).
const SKILL_MAX_LEVEL := 10

## Effets des compétences d'arme, par niveau (utilisés par battle.gd). Elles ne comptent
## qu'avec l'arme qui va avec (Maîtrise de l'épée avec une épée, Utilisation du bouclier avec un bouclier...).
const WEAPON_SKILL_BONUS_PER_LEVEL := 0.03  # Maîtrise d'une arme : +3 % de dégâts avec cette arme
const SHIELD_GUARD_PER_LEVEL := 0.03        # Utilisation du bouclier : -3 % de dégâts subis

# --- Progrès des compétences (entraînement et usage) ---
# Un héros accumule des « points de progrès » dans une compétence (hero["skill_progress"]).
# Arrivé au seuil, il l'apprend (niveau 1) ou passe au niveau suivant, et le compteur repart de zéro.

## Maîtrise de l'arc : un point de progrès par flèche tirée en combat, niveau suivant tous les 50 tirs.
const BOW_SHOTS_PER_LEVEL := 50

## Terrain d'entraînement : les programmes proposés (une compétence travaillée par programme).
const TRAINING_SKILLS := ["Maîtrise de l'épée", "Utilisation du bouclier"]
## Nombre de héros qui peuvent s'entraîner en même temps (terrain de niveau 1).
const TRAINING_SLOTS := 3
## Le terrain d'entraînement s'ouvre après ce nombre d'armes tirées (cahier des charges).
const TRAINING_UNLOCK_DRAWS := 10
## Durée d'une séance, en secondes de temps réel. L'entraînement continue même jeu fermé.
const TRAINING_SESSION_SECONDS := 300
## Points de progrès gagnés par séance : cette base + la valeur de croissance (cachée) du héros.
const TRAINING_POINTS_BASE := 10
## Points de progrès nécessaires pour apprendre la compétence ou gagner un niveau.
const TRAINING_POINTS_PER_LEVEL := 100

## Compétences qui ne peuvent pas être réunies sur un même héros (sauf Han, voir can_learn_skill).
const INCOMPATIBLE_SKILLS := [["Calme", "Berserk"]]

# --- Fusion de compétences ---
# Deux compétences arrivées toutes les deux au niveau FUSION_LEVEL fusionnent en une seule quand
# un déclencheur se produit en combat. La compétence fusionnée remplace les deux autres et garde
# leurs effets (comme si elles restaient au niveau FUSION_LEVEL), avec un effet en plus.
# (Le cahier proposait le niveau 5 ; le porteur du projet a choisi le niveau 10.)

## Niveau que doivent atteindre les deux compétences pour pouvoir fusionner.
const FUSION_LEVEL := 10

## « parts » : les deux compétences qui fusionnent ; « trigger » : ce qui déclenche la fusion
## (voir battle.gd) ; « rank » : le rang affiché de la compétence fusionnée.
const SKILL_FUSIONS := {
	"Surpassement": {"parts": ["Calme", "Berserk"], "trigger": "berserk", "rank": "B+, unique",
		"when": "Berserk se déclenche en combat"},
	"Épée et bouclier": {"parts": ["Maîtrise de l'épée", "Utilisation du bouclier"], "trigger": "sword_shield",
		"rank": "Intermédiaire", "when": "finir un combat de la Tour debout, épée et bouclier en main"},
}

## Évolutions : une compétence arrivée au niveau FUSION_LEVEL se transforme en une compétence supérieure
## (à la fin d'un combat). Comme une fusion, la nouvelle compétence garde les effets de l'ancienne.
const SKILL_EVOLUTIONS := {
	"Esprit combatif": {"from": "Résistance à la douleur", "rank": "Intermédiaire"},
}

# --- Compétences du lot de test (onglet « Compétences » du cahier), chiffres provisoires ---
## Résistance aux flammes : dégâts de feu en moins par niveau ; chance de l'apprendre (ou de la monter)
## après un combat où l'on a subi du feu ; ou 1 point par combat fini aux côtés d'un mage de feu.
const FIRE_RESIST_PER_LEVEL := 0.05
const FIRE_RESIST_CHANCE := 0.5
const FIRE_MAGE_FIGHTS_PER_LEVEL := 3
## Indomptable : saignements plus faibles par niveau (avec Résistance à la douleur, 80 % au plus).
const INDOMITABLE_PER_LEVEL := 0.1
## Tueur de gobelins : dégâts en plus contre les gobelins par niveau ; gobelins à tuer par niveau.
const GOBLIN_SLAYER_PER_LEVEL := 0.1
const GOBLIN_KILLS_PER_LEVEL := 50
## Esprit combatif : dégâts en plus par niveau, sous la moitié de sa vie.
const FIGHTING_SPIRIT_PER_LEVEL := 0.05
## Éléments de la magie : chaque mage en maîtrise un (le feu pour les ennemis sorciers).
const MAGIC_ELEMENTS := ["Feu", "Vent", "Froid"]

## Surpassement : quand Berserk se déclenche, ses bonus sont multipliés par ceci, le héros ne peut
## plus saigner, mais il perd cette part de sa vie maximum chaque seconde (jusqu'à la mort).
const SURPASS_BONUS_MULTIPLIER := 2
const SURPASS_DRAIN_PER_SECOND := 0.02
## Épée et bouclier : dégâts en plus à l'épée, par niveau de la compétence fusionnée.
const SWORD_SHIELD_BONUS_PER_LEVEL := 0.02


## Ce que change le mode Berserk sur les valeurs de combat d'un héros (pour sa fiche) :
## [[nom, valeur de base, valeur en Berserk], ...], ou [] s'il n'a pas Berserk.
## Mêmes calculs que battle.gd (_enter_berserk) : bonus de 4 + niveau, doublé avec Surpassement.
func berserk_preview(hero: Dictionary) -> Array:
	var level := skill_level(hero["skills"], "Berserk")
	if level == 0:
		return []
	var bonus := 4 + level
	if skill_level(hero["skills"], "Surpassement") > 0:
		bonus *= SURPASS_BONUS_MULTIPLIER
	var base := combat_stats(hero)
	var gear := gear_stats(hero)
	var atk: int = base["atk"] + gear.get("atk", 0)
	var def: int = base["def"] + gear.get("def", 0)
	var crit: float = base["crit"] + gear.get("crit", 0.0)
	var magic: bool = hero["class"] in ["Mage", "Soigneur"]
	return [
		["Attaque", atk, maxi(1, atk - 10) if magic else atk + bonus],
		["Défense", def, def + roundi(bonus / 2.0)],
		["Vitesse", base["spd"], base["spd"] + bonus],
		["Critiques (%)", roundi(crit * 100), roundi((crit + bonus / 200.0) * 100)],
	]


## Vrai si les deux compétences d'une fusion sont au niveau voulu sur ce héros.
func fusion_ready(skills: Array, fusion_name: String) -> bool:
	for part in SKILL_FUSIONS[fusion_name]["parts"]:
		if _own_skill_level(skills, part) < FUSION_LEVEL:
			return false
	return true


## Fusionne deux compétences : elles disparaissent, la compétence fusionnée arrive au niveau 1.
## Renvoie le texte à annoncer.
func fuse_skills(skills: Array, fusion_name: String) -> String:
	var parts: Array = SKILL_FUSIONS[fusion_name]["parts"]
	for i in range(skills.size() - 1, -1, -1):
		if skills[i]["name"] in parts:
			skills.remove_at(i)
	skills.append({"name": fusion_name, "rank": SKILL_FUSIONS[fusion_name]["rank"], "level": 1})
	return "Fusion de compétences ! %s + %s → %s" % [parts[0], parts[1], fusion_name]


## Le niveau d'une compétence que le héros possède vraiment (sans compter les fusions).
func _own_skill_level(skills: Array, skill_name: String) -> int:
	for skill in skills:
		if skill["name"] == skill_name:
			return skill["level"]
	return 0


## Vrai pour Han, le héros secret de départ (il a des règles à lui).
func is_han(hero: Dictionary) -> bool:
	return hero.get("secret", false) and hero["name"] == "Han"

## Compétences qu'un héros peut apprendre lors d'un éveil en situation critique.
const AWAKENING_SKILLS := ["Calme", "Mouvement souple", "Berserk"]


## Niveau d'une compétence dans une liste de compétences (0 si le héros ne l'a pas).
## Une compétence fusionnée compte pour ses deux parties au niveau FUSION_LEVEL
## (un héros qui a Surpassement garde les effets de Calme et de Berserk).
func skill_level(skills: Array, skill_name: String) -> int:
	var level := _own_skill_level(skills, skill_name)
	if level > 0:
		return level
	for fusion_name in SKILL_FUSIONS:
		if skill_name in SKILL_FUSIONS[fusion_name]["parts"] and _own_skill_level(skills, fusion_name) > 0:
			return FUSION_LEVEL
	for evolved in SKILL_EVOLUTIONS:
		if SKILL_EVOLUTIONS[evolved]["from"] == skill_name and _own_skill_level(skills, evolved) > 0:
			return FUSION_LEVEL
	return 0


## Évolutions : les compétences arrivées au niveau voulu se transforment. Renvoie les annonces.
func check_evolutions(hero: Dictionary) -> Array[String]:
	var news: Array[String] = []
	var skills: Array = hero["skills"]
	for evolved in SKILL_EVOLUTIONS:
		var from: String = SKILL_EVOLUTIONS[evolved]["from"]
		if _own_skill_level(skills, from) >= FUSION_LEVEL:
			for i in range(skills.size() - 1, -1, -1):
				if skills[i]["name"] == from:
					skills.remove_at(i)
			skills.append({"name": evolved, "rank": SKILL_EVOLUTIONS[evolved]["rank"], "level": 1})
			news.append("%s — Évolution ! %s devient %s" % [hero["name"], from, evolved])
	return news


## Vrai si le héros peut apprendre cette compétence : il ne l'a pas encore,
## et elle n'est pas incompatible avec une des siennes. Han fait exception :
## il peut réunir Calme et Berserk (un « bug » du système, dans le manhwa).
func can_learn_skill(hero: Dictionary, skills: Array, skill_name: String) -> bool:
	if skill_level(skills, skill_name) > 0:
		return false
	if is_han(hero):
		return true
	for pair in INCOMPATIBLE_SKILLS:
		if skill_name in pair:
			for other in pair:
				if other != skill_name and skill_level(skills, other) > 0:
					return false
	return true


func new_skill(skill_name: String) -> Dictionary:
	return {"name": skill_name, "rank": "Débutant", "level": 1}


## Points de progrès d'un héros dans une compétence (0 s'il n'en a pas encore).
func skill_progress(hero: Dictionary, skill_name: String) -> int:
	return hero.get("skill_progress", {}).get(skill_name, 0)


## Points de progrès nécessaires pour le prochain niveau d'une compétence.
func skill_progress_needed(skill_name: String) -> int:
	match skill_name:
		"Maîtrise de l'arc":
			return BOW_SHOTS_PER_LEVEL
		"Tueur de gobelins":
			return GOBLIN_KILLS_PER_LEVEL
		"Résistance aux flammes":
			return FIRE_MAGE_FIGHTS_PER_LEVEL
	return TRAINING_POINTS_PER_LEVEL


## Donne des points de progrès à un héros dans une compétence. À chaque fois que le total
## atteint « per_level », il apprend la compétence (niveau 1) ou gagne un niveau.
## Renvoie les nouveautés à annoncer (« Han — nouvelle compétence : Maîtrise de l'épée »).
## Ne sauvegarde pas : c'est à la fonction qui l'appelle de le faire.
func add_skill_progress(hero: Dictionary, skill_name: String, points: int, per_level: int) -> Array[String]:
	var news: Array[String] = []
	if not hero.has("skill_progress"):
		hero["skill_progress"] = {}  # anciennes sauvegardes
	var total: int = hero["skill_progress"].get(skill_name, 0) + points
	while total >= per_level:
		var level := skill_level(hero["skills"], skill_name)
		if level >= SKILL_MAX_LEVEL:
			break
		total -= per_level
		if level == 0:
			if not can_learn_skill(hero, hero["skills"], skill_name):
				break
			hero["skills"].append(new_skill(skill_name))
			news.append("%s — nouvelle compétence : %s" % [hero["name"], skill_name])
		else:
			for skill in hero["skills"]:
				if skill["name"] == skill_name:
					skill["level"] += 1
			news.append("%s — %s passe au niveau %d" % [hero["name"], skill_name, level + 1])
	# Au niveau maximum, on n'accumule plus rien.
	if skill_level(hero["skills"], skill_name) >= SKILL_MAX_LEVEL:
		total = 0
	hero["skill_progress"][skill_name] = total
	return news


# ---------------------------------------------------------------------------
# Armes : tirage, arsenal, équipement
# ---------------------------------------------------------------------------
# Une arme : {"id": ..., "type": "Épée", "grade": "D+", "owner": id du héros qui la porte (0 = rangée
# dans l'arsenal)}. Un héros a deux emplacements : son arme, et un bouclier (sauf avec un arc,
# qui se tient à deux mains). Sans arme, il se bat avec une arme de départ [F] (voir STARTER_WEAPONS).
# Les mages et les soigneurs se battent avec la magie : ils ne portent pas d'arme.
# Les héros prennent eux-mêmes les meilleures armes de l'arsenal en partant en mission (gear_up)
# et les reposent au retour (tidy_arsenal), sauf ceux dont le Maître a choisi l'équipement
# (hero["manual_gear"]) : eux gardent leurs armes en permanence.

## Prix du tirage d'armes, en or (x10 = 10 fois le prix, 50 000 or comme dans le manhwa).
const WEAPON_DRAW_COST := 5000

## Grades des armes, du plus faible au plus fort, avec leur chance au tirage (total 1.0).
## « et au-delà » (B, A, S...) viendra plus tard : il suffira d'ajouter des lignes.
const WEAPON_GRADES := {
	"F": 0.30, "E-": 0.20, "E": 0.15, "E+": 0.12, "D-": 0.08,
	"D": 0.06, "D+": 0.04, "C-": 0.025, "C": 0.015, "C+": 0.01,
}

## Chaque cran de grade au-dessus de F ajoute ceci à l'attaque (arme) ou à la défense (bouclier).
## Une arme [F] n'ajoute rien : c'est le niveau de départ de tout le monde.
const WEAPON_ATK_PER_GRADE := 1
const SHIELD_DEF_PER_GRADE := 1

## Les types d'armes et leur façon de combattre (chiffres provisoires) :
## « reach » : portée en cases (1 = contact, 5.5 = tir) ; « power » : dégâts de chaque coup ;
## « speed » : durée entre deux coups (0.7 = 30 % plus rapide) ; « crit » : chance de critique en plus.
## « skill » : la compétence d'arme qui renforce cette arme.
const WEAPON_TYPES := {
	"Épée": {"reach": 1.0, "power": 1.0, "speed": 1.0, "crit": 0.0, "skill": "Maîtrise de l'épée",
		"info": "Équilibrée."},
	"Lance": {"reach": 1.8, "power": 1.0, "speed": 1.15, "crit": 0.0, "skill": "Maîtrise de la lance",
		"info": "Frappe de plus loin, un peu plus lente."},
	"Dague": {"reach": 1.0, "power": 0.75, "speed": 0.7, "crit": 0.1, "skill": "Maîtrise de la dague",
		"info": "Coups rapides et plus souvent critiques, mais moins forts."},
	"Fouet": {"reach": 2.2, "power": 0.8, "speed": 1.0, "crit": 0.0, "skill": "Maîtrise du fouet",
		"info": "Longue portée, coups plus faibles."},
	"Arc": {"reach": 5.5, "power": 1.0, "speed": 1.0, "crit": 0.0, "skill": "Maîtrise de l'arc",
		"info": "Tire de loin (il faut voir la cible). Se tient à deux mains : pas de bouclier."},
	"Bouclier": {"reach": 0.0, "power": 0.0, "speed": 1.0, "crit": 0.0, "skill": "Utilisation du bouclier",
		"info": "Se porte en plus de l'arme : ajoute de la défense."},
}

## Armes de départ, quand un héros n'a rien reçu de l'arsenal.
## Le cahier prévoit une vieille épée de fer ; les archers partent avec un vieil arc (choix provisoire).
const STARTER_WEAPONS := {"Épée": "Vieille épée de fer", "Arc": "Vieil arc de chasse"}

## Armes que chaque classe prend d'elle-même dans l'arsenal, par ordre de préférence,
## et classes qui prennent aussi un bouclier.
const CLASS_WEAPONS := {
	"Novice": ["Épée", "Lance", "Dague", "Fouet"],
	"Guerrier": ["Épée", "Lance", "Fouet"],
	"Chevalier": ["Épée", "Lance"],
	"Assassin": ["Dague", "Épée", "Fouet"],
	"Archer": ["Arc"],
}
const SHIELD_CLASSES := ["Novice", "Guerrier", "Chevalier"]


## Numéro du grade (F = 0, E- = 1...) : sert à comparer et à calculer les bonus.
func grade_rank(grade: String) -> int:
	return WEAPON_GRADES.keys().find(grade)


func weapon_name(weapon: Dictionary) -> String:
	return "%s [%s]" % [weapon["type"], weapon["grade"]]


## Vrai si la classe se bat avec la magie (pas d'arme).
func uses_magic(hero: Dictionary) -> bool:
	return hero["class"] in ["Mage", "Soigneur"]


## Tire « count » armes au hasard, les range dans l'arsenal, et renvoie la liste
## (vide si on n'a pas assez d'or). Les héros les prendront en partant en mission.
## Chaque arme tirée compte pour l'ouverture du terrain d'entraînement.
func draw_weapons(count: int) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if gold < WEAPON_DRAW_COST * count:
		return results
	gold -= WEAPON_DRAW_COST * count
	weapon_draws += count
	for i in count:
		var weapon := {"id": next_weapon_id, "type": WEAPON_TYPES.keys().pick_random(),
			"grade": _roll_grade(), "owner": 0}
		next_weapon_id += 1
		arsenal.append(weapon)
		results.append(weapon)
	gold_changed.emit(gold)
	save_game()
	return results


func _roll_grade() -> String:
	var roll := randf()
	var cumulative := 0.0
	for grade in WEAPON_GRADES:
		cumulative += WEAPON_GRADES[grade]
		if roll < cumulative:
			return grade
	return "F"


## L'arme portée par un héros dans un emplacement (« weapon » ou « shield »), ou {} s'il n'en a pas.
func equipped(hero: Dictionary, slot: String) -> Dictionary:
	for weapon in arsenal:
		if weapon["owner"] == hero["id"] and (weapon["type"] == "Bouclier") == (slot == "shield"):
			return weapon
	return {}


## Ce avec quoi un héros se bat vraiment : son arme, ou son arme de départ [F].
## Renvoie {"type", "grade", "name"}. Pour un mage ou un soigneur : {} (la magie).
func fighting_weapon(hero: Dictionary) -> Dictionary:
	if uses_magic(hero):
		return {}
	var weapon := equipped(hero, "weapon")
	if not weapon.is_empty():
		return {"type": weapon["type"], "grade": weapon["grade"], "name": weapon_name(weapon)}
	var type := "Arc" if hero["class"] == "Archer" else "Épée"
	return {"type": type, "grade": "F", "name": "%s [F]" % STARTER_WEAPONS[type]}


## Les armes rangées dans l'arsenal (portées par personne), les meilleures d'abord.
func free_weapons() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for weapon in arsenal:
		if weapon["owner"] == 0:
			result.append(weapon)
	result.sort_custom(func(a, b): return grade_rank(a["grade"]) > grade_rank(b["grade"]))
	return result


## Le Maître équipe un héros d'une arme (ou d'un bouclier) de l'arsenal.
## L'ancienne arme de cet emplacement retourne dans l'arsenal. Un arc retire le bouclier.
## Renvoie faux si c'est impossible (mage, bouclier avec un arc...).
func equip(hero: Dictionary, weapon: Dictionary) -> bool:
	if uses_magic(hero) or not hero["alive"]:
		return false
	var slot := "shield" if weapon["type"] == "Bouclier" else "weapon"
	if slot == "shield" and fighting_weapon(hero)["type"] == "Arc":
		return false
	_take_off(hero, slot)
	weapon["owner"] = hero["id"]
	if weapon["type"] == "Arc":
		_take_off(hero, "shield")
	hero["manual_gear"] = true  # le Maître a choisi : le héros garde cette arme, même à la cité
	tidy_arsenal()
	return true


## Le Maître retire l'arme (ou le bouclier) d'un héros : elle retourne dans l'arsenal.
func unequip(hero: Dictionary, slot: String) -> void:
	_take_off(hero, slot)
	hero["manual_gear"] = true
	save_game()


## Rend l'équipement automatique à un héros : il repose ses armes (s'il est à la cité)
## et prendra lui-même les meilleures au prochain départ en mission.
func set_auto_gear(hero: Dictionary) -> void:
	hero["manual_gear"] = false
	tidy_arsenal()


func _take_off(hero: Dictionary, slot: String) -> void:
	var weapon := equipped(hero, slot)
	if not weapon.is_empty():
		weapon["owner"] = 0


## Rangement de l'arsenal, appelé après chaque changement :
## - les armes d'un héros mort sont perdues avec lui ;
## - un héros qui s'équipe tout seul (pas choisi par le Maître) et qui est à la cité repose ses armes
##   dans l'arsenal : il n'en prend qu'en partant en mission (voir gear_up), et les repose au retour.
## Sauvegarde aussi la partie.
func tidy_arsenal() -> void:
	arsenal = arsenal.filter(func(weapon): return weapon["owner"] == 0 or _hero_alive(weapon["owner"]))
	for hero in alive_heroes():
		if not hero.get("manual_gear", false) and not is_away(hero):
			_take_off(hero, "weapon")
			_take_off(hero, "shield")
	save_game()


## Vrai si le héros est à la cité les mains vides et prendra ses armes au prochain départ en mission.
func gears_up_on_mission(hero: Dictionary) -> bool:
	return not hero.get("manual_gear", false) and not uses_magic(hero) and not is_away(hero)


## Départ en mission (Tour ou donjon journalier) : chaque héros de l'équipe qui s'équipe tout seul
## prend la meilleure arme libre qu'il sait utiliser, puis un bouclier si sa classe en porte.
## Les héros les plus rares se servent en premier. Ceux équipés par le Maître gardent leurs armes.
func gear_up(team: Array) -> void:
	var heroes := team.duplicate()
	heroes.sort_custom(func(a, b): return a["rarity"] > b["rarity"])
	for hero in heroes:
		if hero.get("manual_gear", false) or uses_magic(hero):
			continue
		var current := equipped(hero, "weapon")
		var current_rank := -1 if current.is_empty() else grade_rank(current["grade"])
		for weapon in free_weapons():  # les meilleures d'abord
			if weapon["type"] in CLASS_WEAPONS.get(hero["class"], []) and grade_rank(weapon["grade"]) > current_rank:
				_take_off(hero, "weapon")
				weapon["owner"] = hero["id"]
				break
		if hero["class"] in SHIELD_CLASSES and fighting_weapon(hero)["type"] != "Arc":
			var shield := equipped(hero, "shield")
			var shield_rank := -1 if shield.is_empty() else grade_rank(shield["grade"])
			for weapon in free_weapons():
				if weapon["type"] == "Bouclier" and grade_rank(weapon["grade"]) > shield_rank:
					_take_off(hero, "shield")
					weapon["owner"] = hero["id"]
					break
	save_game()


func _hero_alive(hero_id: int) -> bool:
	for hero in roster:
		if hero["id"] == hero_id:
			return hero["alive"]
	return false


## Valeurs de combat données par l'équipement (utilisées par battle.gd) :
## {"type", "reach", "power", "speed", "crit", "atk" (bonus d'attaque), "def" (bonus du bouclier), "shield": bool}.
func gear_stats(hero: Dictionary) -> Dictionary:
	var weapon := fighting_weapon(hero)
	if weapon.is_empty():
		return {}
	var result: Dictionary = WEAPON_TYPES[weapon["type"]].duplicate()
	result["type"] = weapon["type"]
	result["atk"] = grade_rank(weapon["grade"]) * WEAPON_ATK_PER_GRADE
	var shield := equipped(hero, "shield")
	result["shield"] = not shield.is_empty()
	result["def"] = 0 if shield.is_empty() else 2 + grade_rank(shield["grade"]) * SHIELD_DEF_PER_GRADE
	return result


# ---------------------------------------------------------------------------
# Construction et affectation aux bâtiments
# ---------------------------------------------------------------------------
# Les bâtiments se construisent en gemmes (cahier des charges), une fois le terrain d'entraînement
# ouvert (10 armes tirées) :
# - la forge, annexe de l'armurerie (500 gemmes, comme dans le cahier) ;
# - les bâtiments de magie, annexes du terrain d'entraînement, seulement avec un mage vivant
#   parmi ses héros. Une fois construits tous les trois, ils fusionnent en Hall de magie.
#   Leurs fonctions (Recherche, synthèse d'objets, savoir des mages) viendront plus tard.
# Chaque bâtiment construit a POSTS_PER_BUILDING postes d'assistant (hero["post"]) : un héros affecté
# y travaille au lieu de s'entraîner. À la forge, un assistant devient peu à peu artisan (compétence « Forge »).

## « cost » : prix en gemmes ; « mage » : il faut un mage pour le construire ;
## « info » : ce que fait le bâtiment ; « built » : l'annonce une fois construit.
const BUILDINGS := {
	"synthese": {"name": "Chambre de synthèse", "cost": 500, "mage": false, "needs_training": false,
		"info": "On y sacrifie un héros pour en renforcer un autre (synthèse).",
		"built": "La chambre de synthèse a été construite avec succès !"},
	"forge": {"name": "Forge", "cost": 500, "mage": false,
		"info": "Annexe de l'armurerie : fabrique des armes avec les matériaux du donjon journalier.",
		"built": "La forge a été construite avec succès !"},
	"atelier_magie": {"name": "Atelier de magie", "cost": 500, "mage": true,
		"info": "Débloque la fonction « Recherche ».",
		"built": "L'atelier de magie a été construit avec succès !"},
	"laboratoire": {"name": "Laboratoire d'alchimie", "cost": 500, "mage": true,
		"info": "Débloque plusieurs types de synthèse d'objets.",
		"built": "Le laboratoire d'alchimie a été construit avec succès !"},
	"bibliotheque": {"name": "Bibliothèque", "cost": 500, "mage": true,
		"info": "Les mages y apprennent et gagnent en connaissances.",
		"built": "La bibliothèque a été construite avec succès !"},
}
const MAGIC_BUILDINGS := ["atelier_magie", "laboratoire", "bibliotheque"]
const MAGIC_HALL_NAME := "Hall de magie"

## Postes d'assistant par bâtiment (cahier : « deux postes d'assistant par métier »).
const POSTS_PER_BUILDING := 2


## Les héros vivants affectés à un bâtiment.
func posted_heroes(building_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for hero in alive_heroes():
		if hero.get("post", "") == building_id:
			result.append(hero)
	return result


## Affecte un héros à un bâtiment construit (« » = le retirer de son poste).
## Il quitte alors le terrain d'entraînement : un héros ne travaille qu'à un endroit à la fois.
## Renvoie faux si le bâtiment n'est pas construit ou si ses postes sont pris.
func set_post(hero: Dictionary, building_id: String) -> bool:
	if building_id != "":
		if not building_id in buildings or hero.get("post", "") == building_id:
			return false
		if posted_heroes(building_id).size() >= POSTS_PER_BUILDING:
			return false
		if hero.get("training", "") != "":
			update_training()
			hero["training"] = ""
	hero["post"] = building_id
	save_game()
	return true


## Où est un héros en ce moment (texte court), pour l'affichage.
func activity_text(hero: Dictionary) -> String:
	if in_tower(hero):
		return "Dans la Tour"
	if on_expedition(hero):
		return "Au donjon journalier"
	if hero.get("post", "") != "":
		return "Assistant : %s" % BUILDINGS[hero["post"]]["name"]
	if hero.get("training", "") != "":
		return "Terrain d'entraînement"
	return "Au repos"


## Vrai si au moins un mage vivant fait partie des héros.
func has_mage() -> bool:
	for hero in alive_heroes():
		if hero["class"] == "Mage":
			return true
	return false


## Vrai quand les trois bâtiments de magie sont construits (ils forment alors le Hall de magie).
func has_magic_hall() -> bool:
	for building_id in MAGIC_BUILDINGS:
		if not building_id in buildings:
			return false
	return true


## Pourquoi on ne peut pas construire ce bâtiment (texte), ou "" si c'est possible.
func build_problem(building_id: String) -> String:
	if building_id in buildings:
		return "Déjà construit."
	if BUILDINGS[building_id].get("needs_training", true) and not training_unlocked():
		return "Il faut d'abord le terrain d'entraînement."
	if BUILDINGS[building_id]["mage"] and not has_mage():
		return "Il faut un mage parmi tes héros."
	if gems < BUILDINGS[building_id]["cost"]:
		return "Pas assez de gemmes."
	return ""


## Construit un bâtiment. Renvoie les messages à afficher, ou [] si c'est impossible.
func build(building_id: String) -> Array[String]:
	var messages: Array[String] = []
	if build_problem(building_id) != "":
		return messages
	gems -= BUILDINGS[building_id]["cost"]
	gems_changed.emit(gems)
	buildings.append(building_id)
	messages.append(BUILDINGS[building_id]["built"])
	if building_id in MAGIC_BUILDINGS and has_magic_hall():
		messages.append("Les trois bâtiments fusionnent : le %s est né !" % MAGIC_HALL_NAME)
	save_game()
	return messages


# ---------------------------------------------------------------------------
# Terrain d'entraînement
# ---------------------------------------------------------------------------
# Un héros affecté au terrain travaille une compétence (hero["training"], vide = au repos).
# Toutes les TRAINING_SESSION_SECONDS secondes de temps réel, il fait une séance, même si le jeu
# est fermé : au retour, on compte les séances écoulées depuis hero["training_since"].
# L'entraînement ne donne ni statistiques ni niveau, seulement des compétences.
# Un héros qui monte dans la Tour quitte le terrain le temps de l'étage (il garde sa place et
# son programme) : le temps passé dans la Tour ne compte pas, et il reprend l'entraînement après.
# Plus tard : le temps du lobby ira 3 fois plus vite que le temps réel, et les héros iront
# d'eux-mêmes au terrain d'entraînement.

## Vrai quand le terrain d'entraînement est ouvert (assez d'armes tirées).
func training_unlocked() -> bool:
	return weapon_draws >= TRAINING_UNLOCK_DRAWS


## Vrai si le héros est en train de combattre dans la Tour.
func in_tower(hero: Dictionary) -> bool:
	return not pending_battle.is_empty() and hero["id"] in pending_battle["team"]


## Vrai si le héros est parti de la cité (Tour ou donjon journalier) : il n'est ni au terrain
## d'entraînement ni à son poste, et ne peut pas partir ailleurs.
func is_away(hero: Dictionary) -> bool:
	return in_tower(hero) or on_expedition(hero)


## Les héros vivants inscrits au terrain d'entraînement (y compris ceux partis dans la Tour).
func trainees() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for hero in alive_heroes():
		if hero.get("training", "") != "":
			result.append(hero)
	return result


## Affecte un héros à un programme d'entraînement (« » = le renvoyer au repos).
## Renvoie faux si toutes les places du terrain sont prises.
func set_training(hero: Dictionary, skill_name: String) -> bool:
	var already: bool = hero.get("training", "") != ""
	if skill_name != "" and not already and trainees().size() >= TRAINING_SLOTS:
		return false
	update_training()  # les séances déjà faites dans l'ancien programme sont comptées
	hero["training"] = skill_name
	if skill_name != "":
		hero["post"] = ""  # un héros ne travaille qu'à un endroit à la fois
	hero["training_since"] = Time.get_unix_time_from_system()
	save_game()
	return true


## Secondes avant la prochaine séance d'un héros à l'entraînement.
func seconds_to_next_session(hero: Dictionary) -> int:
	var elapsed: float = Time.get_unix_time_from_system() - hero.get("training_since", 0.0)
	return maxi(0, ceili(TRAINING_SESSION_SECONDS - elapsed))


## Compte les séances terminées depuis la dernière fois et donne les points de progrès.
## Les nouveautés s'ajoutent à training_news, en attendant d'être annoncées au joueur.
func update_training() -> void:
	var now := Time.get_unix_time_from_system()
	var changed := false
	for hero in trainees():
		if is_away(hero):
			continue  # dans la Tour ou au donjon journalier : pas d'entraînement pendant ce temps
		var since: float = hero.get("training_since", now)
		if since > now:
			since = now  # l'horloge de l'appareil a reculé
		var sessions := int((now - since) / TRAINING_SESSION_SECONDS)
		if sessions <= 0:
			continue
		hero["training_since"] = since + sessions * TRAINING_SESSION_SECONDS
		var points: int = sessions * (TRAINING_POINTS_BASE + hero["growth"])
		training_news.append_array(add_skill_progress(hero, hero["training"], points,
			skill_progress_needed(hero["training"])))
		changed = true
	if changed:
		save_game()
		training_updated.emit()


# ---------------------------------------------------------------------------
# Entrepôt et donjon journalier
# ---------------------------------------------------------------------------
# Les matériaux s'accumulent dans l'entrepôt (warehouse : {nom: {grade: nombre}}).
# Le donjon journalier (débloqué après l'étage DAILY_UNLOCK_FLOOR) n'est pas un combat : une équipe
# y part récolter pendant EXPEDITION_SECONDS de temps réel (même jeu fermé), puis elle est rappelée
# automatiquement et les matériaux vont dans l'entrepôt. Une expédition par jour.
# Les ramassages sont tirés au départ (expedition["log"]) et annoncés au fil du temps.
# Pour l'instant, un seul donjon journalier (le cahier en prévoit trois, un par jour de la semaine).

const DAILY_DUNGEON := {
	"name": "Mine de Brumefer",
	"difficulty": "super facile",
	"materials": ["Minerai de fer", "Charbon", "Cristal brut"],
}
## Ce qu'on peut aussi ramasser de temps en temps : un déchet inutile, ou (rarement) un plan de forge.
const JUNK_NAME := "Poubelle"
const JUNK_CHANCE := 0.12
const PLAN_CHANCE := 0.02

## Durée d'une expédition (secondes de temps réel) et temps entre deux ramassages d'un héros.
const EXPEDITION_SECONDS := 1800
const PICKUP_SECONDS := 120

## Grades des matériaux ramassés et leur chance (total 1.0).
const MATERIAL_GRADE_RATES := {
	"F": 0.45, "E-": 0.20, "E": 0.13, "E+": 0.09, "D-": 0.06, "D": 0.04, "D+": 0.02, "C-": 0.01,
}

## Matériaux dans l'entrepôt : {"Minerai de fer": {"F": 12, "E": 3}, ...}.
var warehouse: Dictionary = {}
## Plans de forge possédés (types d'armes), trouvés au donjon journalier.
var plans: Array = []
## Expédition en cours (vide s'il n'y en a pas) : {"team": [id], "start": t, "end": t, "log": [...]}.
var expedition: Dictionary = {}
## Jour (AAAA-MM-JJ) de la dernière expédition : une seule par jour.
var last_expedition_day := ""
## Résultat d'une expédition revenue, pas encore montré au joueur : {"lines": [...], "items": [...]}.
var expedition_report: Dictionary = {}


func daily_unlocked() -> bool:
	return tower_floor > DAILY_UNLOCK_FLOOR


func _today() -> String:
	return Time.get_date_string_from_system()


## Vrai si le héros est parti récolter au donjon journalier.
func on_expedition(hero: Dictionary) -> bool:
	return not expedition.is_empty() and hero["id"] in expedition["team"]


## Pourquoi on ne peut pas partir au donjon journalier (texte), ou "" si c'est possible.
func expedition_problem() -> String:
	if not daily_unlocked():
		return "Verrouillé : franchis l'étage %d." % DAILY_UNLOCK_FLOOR
	if not expedition.is_empty():
		return "Une équipe est déjà dans le donjon."
	if last_expedition_day == _today():
		return "Déjà visité aujourd'hui : reviens demain."
	return ""


## Les héros d'une équipe composée à l'avance qui peuvent partir (vivants, pas dans la Tour).
func expedition_members(team_index: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for hero in team_members(team_index):
		if not is_away(hero):
			result.append(hero)
	return result


## Envoie une équipe au donjon journalier. Tous les ramassages sont tirés maintenant,
## avec le moment où ils arrivent. Renvoie faux si c'est impossible.
func start_expedition(team_index: int) -> bool:
	var team := expedition_members(team_index)
	if expedition_problem() != "" or team.is_empty():
		return false
	update_training()  # les séances terminées avant le départ sont comptées
	var now := Time.get_unix_time_from_system()
	var pickups := []
	for hero in team:
		var t := randf_range(20.0, PICKUP_SECONDS)
		while t < EXPEDITION_SECONDS:
			pickups.append(_roll_pickup(hero, t))
			t += PICKUP_SECONDS * randf_range(0.7, 1.3)
	pickups.sort_custom(func(a, b): return a["t"] < b["t"])
	expedition = {"team": team.map(func(hero): return hero["id"]), "team_index": team_index,
		"start": now, "end": now + EXPEDITION_SECONDS, "log": pickups}
	last_expedition_day = _today()
	gear_up(team)  # les héros prennent leurs armes dans l'arsenal (et la partie est sauvegardée)
	return true


## Un ramassage : un matériau gradé, un déchet, ou (rarement) un plan de forge.
func _roll_pickup(hero: Dictionary, t: float) -> Dictionary:
	var who := "%s (%s)" % [hero["name"], "★".repeat(hero["rarity"])]
	var roll := randf()
	if roll < PLAN_CHANCE:
		var type: String = WEAPON_TYPES.keys().pick_random()
		return {"t": t, "kind": "plan", "name": type,
			"text": "%s a trouvé un plan de forge : « %s » !" % [who, type]}
	if roll < PLAN_CHANCE + STONE_PICKUP_CHANCE:
		return {"t": t, "kind": "material", "name": PROMOTION_STONE, "grade": "F",
			"text": "%s a trouvé une « %s » ! Elle sert à la promotion." % [who, PROMOTION_STONE]}
	if roll < PLAN_CHANCE + STONE_PICKUP_CHANCE + JUNK_CHANCE:
		return {"t": t, "kind": "junk", "name": JUNK_NAME, "grade": "F",
			"text": "%s a collecté « %s (F) ». Astuce : la poubelle est inutile, jetez-la." % [who, JUNK_NAME]}
	var material: String = DAILY_DUNGEON["materials"].pick_random()
	var grade := _roll_from(MATERIAL_GRADE_RATES)
	return {"t": t, "kind": "material", "name": material, "grade": grade,
		"text": "%s a collecté « %s (%s) »." % [who, material, grade]}


## Tire une clé au hasard dans un tableau {clé: chance}.
func _roll_from(rates: Dictionary) -> String:
	var roll := randf()
	var cumulative := 0.0
	for key in rates:
		cumulative += rates[key]
		if roll < cumulative:
			return key
	return rates.keys()[0]


## Secondes écoulées depuis le départ de l'expédition, et secondes restantes.
func expedition_elapsed() -> float:
	return Time.get_unix_time_from_system() - expedition.get("start", 0.0)


func expedition_remaining() -> int:
	return maxi(0, ceili(expedition.get("end", 0.0) - Time.get_unix_time_from_system()))


## Les ramassages déjà faits (ceux dont le moment est passé).
func expedition_log_so_far() -> Array:
	var elapsed := expedition_elapsed()
	return expedition.get("log", []).filter(func(entry): return entry["t"] <= elapsed)


## À la fin du temps, le groupe est rappelé : les matériaux vont dans l'entrepôt,
## les plans sont gardés, les déchets jetés. Appelée régulièrement (et au lancement).
func update_expedition() -> void:
	if expedition.is_empty() or expedition_remaining() > 0:
		return
	var totals := {}
	for entry in expedition["log"]:
		match entry["kind"]:
			"material":
				add_material(entry["name"], entry["grade"], 1)
				var key := "%s (%s)" % [entry["name"], entry["grade"]]
				totals[key] = totals.get(key, 0) + 1
			"plan":
				if not entry["name"] in plans:
					plans.append(entry["name"])
				totals["Plan : %s" % entry["name"]] = 1
	var lines := ["L'équipe %d est revenue du donjon journalier (%s)." % [expedition["team_index"] + 1, DAILY_DUNGEON["name"]]]
	if totals.is_empty():
		lines.append("Elle n'a rien rapporté d'utile.")
	var keys := totals.keys()
	keys.sort()  # rangé par matériau
	for key in keys:
		lines.append("%s x%d" % [key, totals[key]])
	# Les héros retrouvent la cité : l'entraînement reprend avec une séance neuve.
	for hero in alive_heroes():
		if hero["id"] in expedition["team"]:
			hero["training_since"] = Time.get_unix_time_from_system()
	expedition_report = {"lines": lines}
	expedition = {}
	tidy_arsenal()  # les héros reposent leurs armes dans l'arsenal (et la partie est sauvegardée)
	lobby_updated.emit()


func add_material(material: String, grade: String, count: int) -> void:
	if not warehouse.has(material):
		warehouse[material] = {}
	warehouse[material][grade] = warehouse[material].get(grade, 0) + count


## Nombre d'un matériau dans l'entrepôt (d'un grade précis, ou de tous les grades si grade = "").
func material_count(material: String, grade := "") -> int:
	var by_grade: Dictionary = warehouse.get(material, {})
	if grade != "":
		return by_grade.get(grade, 0)
	var total := 0
	for g in by_grade:
		total += by_grade[g]
	return total


## Retire des matériaux : du grade demandé, ou (grade = "") en commençant par les plus faibles.
func _take_material(material: String, count: int, grade := "") -> void:
	var by_grade: Dictionary = warehouse.get(material, {})
	var order: Array = [grade] if grade != "" else WEAPON_GRADES.keys()
	for g in order:
		var used := mini(count, by_grade.get(g, 0))
		if used > 0:
			by_grade[g] -= used
			if by_grade[g] == 0:
				by_grade.erase(g)
			count -= used
	warehouse[material] = by_grade


# ---------------------------------------------------------------------------
# Forge
# ---------------------------------------------------------------------------
# La forge (annexe de l'armurerie) fabrique des armes avec les matériaux de l'entrepôt.
# Le rang de base de l'arme est le grade du matériau principal choisi (+1 cran avec un plan).
# Malus (cahier des charges) : infrastructures insuffisantes (forge de niveau 1, strict minimum),
# pas d'artisan (aucun assistant de la forge n'a la compétence « Forge »), pas de plan.
# Deux façons de produire :
# - automatique : un simple tirage selon la probabilité de succès ; l'arme reste à son rang de base ;
# - à la main : le puzzle de forge (voir forge_puzzle.gd), qui peut faire monter le rang de plusieurs crans.
# En cas d'échec, les matériaux sont perdus.

## Recettes : matériau principal (qui donne le rang) et sa quantité, plus les matériaux en appoint.
## Pour l'instant tout vient de la mine (le bois, le cuir... viendront avec les autres donjons).
const FORGE_RECIPES := {
	"Épée": {"main": "Minerai de fer", "qty": 5, "extra": {"Charbon": 2}},
	"Lance": {"main": "Minerai de fer", "qty": 4, "extra": {"Charbon": 2}},
	"Dague": {"main": "Minerai de fer", "qty": 3, "extra": {"Charbon": 1}},
	"Fouet": {"main": "Minerai de fer", "qty": 3, "extra": {"Charbon": 1}},
	"Arc": {"main": "Minerai de fer", "qty": 3, "extra": {"Charbon": 1}},
	"Bouclier": {"main": "Minerai de fer", "qty": 6, "extra": {"Charbon": 2}},
}

## Difficultés du puzzle (cahier des charges) : taille de la grille, nombre de pièces (et leur taille),
## cases d'impureté, pièces révélées une par une, rotation permise, silhouette qui s'efface (secondes),
## crans de bonus au maximum, et chance de succès affichée avant de confirmer.
const FORGE_DIFFICULTIES := {
	"Facile": {"grid": 5, "pieces": 4, "sizes": [2, 3], "impurities": 0, "reveal": false,
		"rotation": true, "fade": 0.0, "bonus": 1, "chance": 0.95},
	"Normal": {"grid": 6, "pieces": 6, "sizes": [2, 4], "impurities": 0, "reveal": false,
		"rotation": true, "fade": 0.0, "bonus": 2, "chance": 0.8},
	"Difficile": {"grid": 7, "pieces": 8, "sizes": [3, 4], "impurities": 3, "reveal": false,
		"rotation": true, "fade": 0.0, "bonus": 3, "chance": 0.6},
	"Infernal": {"grid": 8, "pieces": 10, "sizes": [3, 4], "impurities": 4, "reveal": true,
		"rotation": true, "fade": 0.0, "bonus": 4, "chance": 0.4},
	"Démoniaque": {"grid": 9, "pieces": 12, "sizes": [3, 5], "impurities": 5, "reveal": true,
		"rotation": false, "fade": 10.0, "bonus": 5, "chance": 0.2},
}

## Temps du puzzle (secondes), et effets des malus dans le puzzle.
const FORGE_TIME := 180
const INFRA_TIME_MALUS := 30          # infrastructures insuffisantes : 30 secondes en moins
const NO_ARTISAN_IMPURITIES := 2      # pas d'artisan : 2 cases d'impureté en plus
## Production automatique : chance de succès sans malus, et ce que retire chaque malus.
const FORGE_AUTO_CHANCE := 0.9
const FORGE_MALUS_CHANCE := 0.15
## Niveau de la forge (les niveaux de bâtiment viendront plus tard) : au niveau 1, les
## infrastructures sont insuffisantes ; au niveau 2, elles donneraient 30 secondes en plus.
const FORGE_LEVEL := 1
## Points de compétence « Forge » gagnés par chaque assistant présent à chaque fabrication
## (100 points par niveau, comme à l'entraînement) : au bout de 4 fabrications, il devient artisan.
const ARTISAN_POINTS_PER_WORK := 25


func forge_built() -> bool:
	return "forge" in buildings


## Les assistants de la forge présents (pas partis dans la Tour ou au donjon).
func forge_assistants() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for hero in posted_heroes("forge"):
		if not is_away(hero):
			result.append(hero)
	return result


## Vrai si un assistant présent est artisan (compétence « Forge »).
func has_artisan() -> bool:
	for hero in forge_assistants():
		if skill_level(hero["skills"], "Forge") > 0:
			return true
	return false


## Les malus qui s'appliquent pour forger ce type d'arme : liste de clés "infra", "artisan", "plan".
func forge_maluses(weapon_type: String) -> Array:
	var result := []
	if FORGE_LEVEL < 2:
		result.append("infra")
	if not has_artisan():
		result.append("artisan")
	if not weapon_type in plans:
		result.append("plan")
	return result


const MALUS_NAMES := {"infra": "Infrastructures insuffisantes (30 s en moins)",
	"artisan": "Pas d'artisan (2 cases d'impureté en plus)",
	"plan": "Pas de plan (silhouette en pointillés, pas de cran en plus)"}


## Chance de succès (0 à 1) : « difficulty » = une difficulté du puzzle, ou "auto".
func forge_chance(weapon_type: String, difficulty: String) -> float:
	var malus_count := forge_maluses(weapon_type).size()
	if difficulty == "auto":
		return clampf(FORGE_AUTO_CHANCE - malus_count * FORGE_MALUS_CHANCE, 0.05, 1.0)
	return clampf(FORGE_DIFFICULTIES[difficulty]["chance"] - malus_count * 0.1, 0.02, 1.0)


## La chance en mots, comme dans le cahier : Certaine, Élevée, Moyenne, Faible, Infime.
func chance_word(chance: float) -> String:
	if chance >= 0.95:
		return "Certaine"
	if chance >= 0.7:
		return "Élevée"
	if chance >= 0.45:
		return "Moyenne"
	if chance >= 0.2:
		return "Faible"
	return "Infime"


## Grades du matériau principal dont on a assez pour cette recette (les meilleurs d'abord),
## en vérifiant aussi les matériaux d'appoint.
func forge_grades(weapon_type: String) -> Array:
	var recipe: Dictionary = FORGE_RECIPES[weapon_type]
	for material in recipe["extra"]:
		if material_count(material) < recipe["extra"][material]:
			return []
	var result := []
	for grade in WEAPON_GRADES.keys():
		if material_count(recipe["main"], grade) >= recipe["qty"]:
			result.push_front(grade)
	return result


## Rang de base : le grade du matériau principal, +1 cran avec un plan.
func forge_base_grade(weapon_type: String, material_grade: String) -> String:
	var rank := grade_rank(material_grade)
	if weapon_type in plans:
		rank += 1
	return _grade_at(rank)


func _grade_at(rank: int) -> String:
	var grades := WEAPON_GRADES.keys()
	return grades[clampi(rank, 0, grades.size() - 1)]


## Prend les matériaux d'une fabrication dans l'entrepôt. Renvoie faux s'il en manque.
func _consume_recipe(weapon_type: String, material_grade: String) -> bool:
	if not material_grade in forge_grades(weapon_type):
		return false
	var recipe: Dictionary = FORGE_RECIPES[weapon_type]
	_take_material(recipe["main"], recipe["qty"], material_grade)
	for material in recipe["extra"]:
		_take_material(material, recipe["extra"][material])
	return true


## Production automatique : un tirage selon la probabilité. Renvoie
## {"ok": false} s'il manque des matériaux, sinon {"ok": true, "success": bool, "weapon": ..., "news": [...]}.
func forge_auto(weapon_type: String, material_grade: String) -> Dictionary:
	var chance := forge_chance(weapon_type, "auto")
	if not _consume_recipe(weapon_type, material_grade):
		return {"ok": false}
	var result := {"ok": true, "success": randf() < chance, "weapon": {}}
	if result["success"]:
		result["weapon"] = _add_forged(weapon_type, forge_base_grade(weapon_type, material_grade))
	result["news"] = _forge_work_done()
	save_game()
	return result


## Début d'une fabrication à la main : les matériaux sont pris tout de suite (perdus en cas d'échec).
func forge_manual_begin(weapon_type: String, material_grade: String) -> bool:
	if not _consume_recipe(weapon_type, material_grade):
		return false
	save_game()
	return true


## Fin du puzzle. « bonus » : crans gagnés (0 pour un succès simple). Renvoie l'arme et les nouveautés.
func forge_manual_end(weapon_type: String, material_grade: String, success: bool, bonus: int) -> Dictionary:
	var result := {"success": success, "weapon": {}}
	if success:
		var rank := grade_rank(forge_base_grade(weapon_type, material_grade)) + bonus
		result["weapon"] = _add_forged(weapon_type, _grade_at(rank))
	result["news"] = _forge_work_done()
	save_game()
	return result


func _add_forged(weapon_type: String, grade: String) -> Dictionary:
	var weapon := {"id": next_weapon_id, "type": weapon_type, "grade": grade, "owner": 0, "forged": true}
	next_weapon_id += 1
	arsenal.append(weapon)
	save_game()
	return weapon


## Chaque fabrication fait progresser les assistants présents vers la compétence « Forge ».
func _forge_work_done() -> Array[String]:
	var news: Array[String] = []
	for hero in forge_assistants():
		news.append_array(add_skill_progress(hero, "Forge", ARTISAN_POINTS_PER_WORK, TRAINING_POINTS_PER_LEVEL))
	return news


# ---------------------------------------------------------------------------
# La Tour
# ---------------------------------------------------------------------------

## Nombre maximum de héros dans une équipe de combat.
const TEAM_SIZE := 5

## Nombre d'équipes que le joueur peut composer à l'avance.
const TEAM_COUNT := 3

## Un boss garde tous les étages multiples de ce nombre (5, 10, 15...).
const BOSS_EVERY := 5

## Un étage déjà conquis peut être rejoué (pour entraîner une nouvelle équipe ou l'équipe principale) :
## les récompenses sont réduites (0.5 = moitié) et il n'y a pas de gemmes.
const REPLAY_XP_RATE := 0.5
const REPLAY_GOLD_RATE := 0.2

## Étage à franchir pour débloquer le donjon journalier.
const DAILY_UNLOCK_FLOOR := 5

## Types de quêtes d'étage : nom affiché et objectif.
## Extermination, subjugation, annihilation : tuer tous les ennemis (l'annihilation ajoute des renforts).
## Survie et défense : tenir jusqu'à la fin du compte à rebours, face à une horde.
const QUEST_TYPES := {
	"extermination": {"name": "Extermination", "objective": "Éliminer tous les ennemis."},
	"subjugation": {"name": "Subjugation", "objective": "Éliminer tous les ennemis."},
	"annihilation": {"name": "Annihilation", "objective": "Éliminer tous les ennemis, renforts compris."},
	"survival": {"name": "Survie", "objective": "Survivre à la horde jusqu'à la fin du compte à rebours."},
	"defense": {"name": "Défense", "objective": "Empêcher la cité de tomber jusqu'à la fin du compte à rebours."},
}

## Limite de temps, en secondes de combat : pour tuer tous les ennemis, ou à tenir (survie, défense).
const KILL_QUEST_SECONDS := 90
const SURVIVAL_SECONDS := 60

## Solidité des remparts d'une quête de défense : chaque coup d'un ennemi arrivé
## au pied des remparts leur retire 1 point. À 0, la cité tombe.
const DEFENSE_WALLS := 75

## Palier : tous les BOSS_EVERY étages, la difficulté monte d'un cran.
## Les ennemis de l'étage de boss et de tous les étages suivants gagnent ce nombre de niveaux en plus.
const TIER_BONUS_LEVELS := 2

## Les ennemis prennent des forces à chaque niveau (0.08 = +8 % par niveau).
const ENEMY_BONUS_PER_LEVEL := 0.08

## Monstres ordinaires de la Tour, dans l'ordre où ils apparaissent (statistiques au niveau 1).
## Leur « classe » décide de leur façon de combattre, exactement comme pour les héros.
const ENEMY_TYPES := [
	{"name": "Gobelin", "class": "Assassin", "str": 9, "int": 3, "vit": 7, "dex": 12},
	{"name": "Loup noir", "class": "Guerrier", "str": 10, "int": 2, "vit": 8, "dex": 11},
	{"name": "Squelette archer", "class": "Archer", "str": 10, "int": 3, "vit": 6, "dex": 10},
	{"name": "Golem de pierre", "class": "Chevalier", "str": 7, "int": 1, "vit": 14, "dex": 5},
	{"name": "Chaman", "class": "Soigneur", "str": 3, "int": 8, "vit": 7, "dex": 9},
	{"name": "Sorcier gobelin", "class": "Mage", "str": 3, "int": 11, "vit": 5, "dex": 8, "element": "Feu"},
]

## Boss qui gardent les étages multiples de BOSS_EVERY.
const BOSS_TYPES := [
	{"name": "Chef gobelin", "class": "Guerrier", "str": 16, "int": 4, "vit": 26, "dex": 10},
	{"name": "Minotaure", "class": "Guerrier", "str": 18, "int": 4, "vit": 30, "dex": 9},
	{"name": "Liche", "class": "Mage", "str": 4, "int": 18, "vit": 24, "dex": 10, "element": "Froid"},
	{"name": "Hydre", "class": "Chevalier", "str": 14, "int": 4, "vit": 40, "dex": 6},
]

# ---------------------------------------------------------------------------
# État de la partie
# ---------------------------------------------------------------------------

## Vraies réserves de gemmes et d'or : celles de la sauvegarde.
var real_gems := 3000
var real_gold := 0
## Montant affiché et utilisable en mode dev (Settings.dev_mode) : « infini ».
const DEV_MONEY := 999999999
## Gemmes et or utilisables : à utiliser partout dans le jeu. En mode dev, ils sont infinis
## (on peut tout payer) et les vraies réserves ne bougent pas : on les retrouve en quittant le mode dev.
var gems: int:
	get:
		return DEV_MONEY if Settings.dev_mode else real_gems
	set(value):
		if not Settings.dev_mode:
			real_gems = value
var gold: int:
	get:
		return DEV_MONEY if Settings.dev_mode else real_gold
	set(value):
		if not Settings.dev_mode:
			real_gold = value
var pity_counter := 0

## Prochain étage de la Tour à conquérir.
var tower_floor := 1

## Tous les héros possédés. Chaque héros est unique :
## deux « Aldric » sont deux individus différents, avec leurs propres statistiques.
var roster: Array[Dictionary] = []

## Numéro donné au prochain héros (chaque héros a un numéro unique).
var next_hero_id := 1

## Codes secrets déjà utilisés.
var used_codes: Array[String] = []

## Équipes composées à l'avance : TEAM_COUNT listes de numéros (id) de héros, dans l'ordre choisi.
var teams: Array = []

## Combat de la Tour en cours (vide s'il n'y en a pas) : {"floor", "team": [id des héros],
## "enemies": [...], "quest": {...}}. Il est sauvegardé dès le début du combat : si le jeu est fermé
## en plein combat, les héros se débrouillent seuls et le combat est terminé au lancement suivant.
var pending_battle: Dictionary = {}

## Résultat d'un combat terminé pendant l'absence du joueur, à lui annoncer
## (vide sinon) : {"floor": ..., "report": rapport de finish_tower_battle}.
var absence_report: Dictionary = {}

## Compétences apprises ou améliorées au terrain d'entraînement, pas encore annoncées au joueur (textes).
var training_news: Array = []

## Toutes les armes possédées, portées ou rangées (voir la section « Armes »).
var arsenal: Array = []
## Numéro donné à la prochaine arme tirée.
var next_weapon_id := 1
## Nombre d'armes tirées depuis le début de la partie (le terrain d'entraînement s'ouvre à 10).
var weapon_draws := 0
## Bâtiments construits (identifiants de BUILDINGS).
var buildings: Array = []


func _ready() -> void:
	# On reprend la partie enregistrée ; s'il n'y en a pas (premier lancement), on en commence une.
	if not load_game():
		_new_game()
	if not pending_battle.is_empty():
		_resolve_pending_battle()
	# L'entraînement et le donjon journalier ont continué pendant que le jeu était fermé,
	# puis on les fait avancer toutes les 5 secondes.
	update_expedition()
	update_training()
	tidy_arsenal()  # (anciennes sauvegardes) les héros à la cité reposent leurs armes
	var timer := Timer.new()
	timer.wait_time = 5.0
	timer.timeout.connect(func():
		update_expedition()
		update_training())
	add_child(timer)
	timer.start()


## « Recommencer la partie » (depuis les paramètres) : efface la sauvegarde et repart de zéro.
func reset_game() -> void:
	delete_save()
	_new_game()


## Prépare une partie neuve.
func _new_game() -> void:
	real_gems = 3000
	real_gold = 0
	pity_counter = 0
	tower_floor = 1
	roster.clear()
	next_hero_id = 1
	used_codes.clear()
	teams = _empty_teams()
	pending_battle = {}
	absence_report = {}
	training_news = []
	arsenal = []
	next_weapon_id = 1
	weapon_draws = 0
	buildings = []
	warehouse = {}
	plans = []
	expedition = {}
	last_expedition_day = ""
	expedition_report = {}
	# On commence sans héros : les héros secrets (Han compris) s'obtiennent par code.


# ---------------------------------------------------------------------------
# Sauvegarde
# ---------------------------------------------------------------------------
# La partie est enregistrée sur l'appareil, dans le dossier « user:// » de Godot
# (sur le web : le stockage du navigateur). Elle est réécrite après chaque changement
# (invocation, combat, code secret, gemmes ou or gagnés) et relue au lancement.
# ConfigFile garde les types (un nombre entier reste un entier), contrairement au JSON.

const SAVE_PATH := "user://sauvegarde.cfg"

## Numéro du format de sauvegarde : à augmenter si on change ce qui est enregistré,
## pour pouvoir adapter les anciennes sauvegardes.
const SAVE_VERSION := 1


## Enregistre toute la partie : monnaies, étage, héros (morts compris), codes utilisés.
func save_game() -> void:
	var file := ConfigFile.new()
	file.set_value("partie", "version", SAVE_VERSION)
	file.set_value("partie", "gemmes", real_gems)
	file.set_value("partie", "or", real_gold)
	file.set_value("partie", "pity", pity_counter)
	file.set_value("partie", "etage", tower_floor)
	file.set_value("partie", "prochain_id", next_hero_id)
	file.set_value("partie", "codes_utilises", used_codes)
	file.set_value("partie", "heros", roster)
	file.set_value("partie", "equipes", teams)
	file.set_value("partie", "combat_en_cours", pending_battle)
	file.set_value("partie", "nouvelles_entrainement", training_news)
	file.set_value("partie", "arsenal", arsenal)
	file.set_value("partie", "prochaine_arme", next_weapon_id)
	file.set_value("partie", "armes_tirees", weapon_draws)
	file.set_value("partie", "batiments", buildings)
	file.set_value("partie", "entrepot", warehouse)
	file.set_value("partie", "plans", plans)
	file.set_value("partie", "expedition", expedition)
	file.set_value("partie", "derniere_expedition", last_expedition_day)
	file.set_value("partie", "retour_expedition", expedition_report)
	file.save(SAVE_PATH)


## Relit la partie enregistrée. Renvoie false s'il n'y a pas de sauvegarde lisible.
func load_game() -> bool:
	var file := ConfigFile.new()
	if file.load(SAVE_PATH) != OK:
		return false
	real_gems = file.get_value("partie", "gemmes", 3000)
	real_gold = file.get_value("partie", "or", 0)
	pity_counter = file.get_value("partie", "pity", 0)
	tower_floor = file.get_value("partie", "etage", 1)
	next_hero_id = file.get_value("partie", "prochain_id", 1)
	# « assign » recopie la liste lue dans nos listes typées (Array[String], Array[Dictionary]).
	used_codes.assign(file.get_value("partie", "codes_utilises", []))
	roster.assign(file.get_value("partie", "heros", []))
	teams = file.get_value("partie", "equipes", _empty_teams())
	while teams.size() < TEAM_COUNT:
		teams.append([])
	pending_battle = file.get_value("partie", "combat_en_cours", {})
	training_news = file.get_value("partie", "nouvelles_entrainement", [])
	arsenal = file.get_value("partie", "arsenal", [])
	next_weapon_id = file.get_value("partie", "prochaine_arme", 1)
	weapon_draws = file.get_value("partie", "armes_tirees", 0)
	buildings = file.get_value("partie", "batiments", [])
	warehouse = file.get_value("partie", "entrepot", {})
	plans = file.get_value("partie", "plans", [])
	expedition = file.get_value("partie", "expedition", {})
	last_expedition_day = file.get_value("partie", "derniere_expedition", "")
	expedition_report = file.get_value("partie", "retour_expedition", {})
	return not roster.is_empty()


## Efface la sauvegarde (utilisé par « Recommencer la partie »).
func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


# ---------------------------------------------------------------------------
# Équipes composées à l'avance
# ---------------------------------------------------------------------------

func _empty_teams() -> Array:
	var result := []
	for i in TEAM_COUNT:
		result.append([])
	return result


## Les héros encore en vie d'une équipe (numéro 0 pour l'Équipe 1), dans l'ordre choisi.
func team_members(index: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for hero_id in teams[index]:
		for hero in roster:
			if hero["id"] == hero_id and hero["alive"]:
				result.append(hero)
	return result


## Ajoute un héros à une équipe, ou l'en retire s'il y est déjà.
## Renvoie faux si l'équipe est déjà complète.
func toggle_team_member(index: int, hero_id: int) -> bool:
	var members: Array = teams[index]
	if hero_id in members:
		members.erase(hero_id)
	elif team_members(index).size() >= TEAM_SIZE:
		return false
	else:
		members.append(hero_id)
	save_game()
	return true


## Un héros mort quitte toutes les équipes.
func _remove_from_teams(hero_id: int) -> void:
	for members in teams:
		members.erase(hero_id)


# ---------------------------------------------------------------------------
# Favoris
# ---------------------------------------------------------------------------
# Le Maître peut mettre des héros en favoris (cahier : « favori » sur la fiche), FAVORITES_MAX au plus
# (choix du porteur du projet). Un favori est protégé : il ne peut pas être sacrifié en synthèse.
# Seuls les héros vivants comptent : un favori mort libère sa place.

const FAVORITES_MAX := 20


func is_favorite(hero: Dictionary) -> bool:
	return hero.get("favorite", false)


## Nombre de favoris (vivants).
func favorites_count() -> int:
	return alive_heroes().filter(is_favorite).size()


## Met un héros en favori, ou le retire des favoris. Renvoie faux si les FAVORITES_MAX places sont prises.
func toggle_favorite(hero: Dictionary) -> bool:
	if not is_favorite(hero) and favorites_count() >= FAVORITES_MAX:
		return false
	hero["favorite"] = not is_favorite(hero)
	save_game()
	return true


# ---------------------------------------------------------------------------
# Monnaies
# ---------------------------------------------------------------------------

func add_gems(amount: int) -> void:
	gems += amount
	gems_changed.emit(gems)
	save_game()


func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)
	save_game()


# ---------------------------------------------------------------------------
# Invocation
# ---------------------------------------------------------------------------

## Vrai si on peut payer « count » invocations de cette sorte (« normal » ou « special »).
func can_afford(summon_type: String, count: int) -> bool:
	var info: Dictionary = SUMMON_TYPES[summon_type]
	var money := gold if info["currency"] == "gold" else gems
	return money >= info["cost"] * count


## Invoque « count » héros (invocation « normal » ou « special ») et renvoie la liste des héros
## obtenus (liste vide si on n'a pas de quoi payer).
func summon(summon_type: String, count: int) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if not can_afford(summon_type, count):
		return results

	var info: Dictionary = SUMMON_TYPES[summon_type]
	if info["currency"] == "gold":
		gold -= info["cost"] * count
		gold_changed.emit(gold)
	else:
		gems -= info["cost"] * count
		gems_changed.emit(gems)
	for i in count:
		var hero := _create_hero(_roll_rarity(summon_type), info["mages"])
		roster.append(hero)
		results.append(hero)
	save_game()
	return results


func summons_before_pity() -> int:
	return PITY_LIMIT - pity_counter


## Tire une rareté au hasard selon les taux de cette sorte d'invocation.
## Seule l'invocation spéciale compte pour le pity.
func _roll_rarity(summon_type: String) -> int:
	var special := summon_type == "special"
	if special:
		pity_counter += 1
		if pity_counter >= PITY_LIMIT:
			pity_counter = 0
			return 5

	var rates: Dictionary = SUMMON_TYPES[summon_type]["rates"]
	var roll := randf()
	var cumulative := 0.0
	for rarity in rates:
		cumulative += rates[rarity]
		if roll < cumulative:
			if rarity == 5 and special:
				pity_counter = 0
			return rarity
	return 1


## Chances de chaque classe pour une rareté (voir CLASS_RATES). Sans les mages (invocation
## normale), leur part est retirée et les autres classes se partagent les 100 %.
func class_rates(rarity: int, allow_mage: bool) -> Dictionary:
	var rates: Dictionary = CLASS_RATES[rarity].duplicate()
	if not allow_mage:
		rates.erase("Mage")
	var total := 0.0
	for hero_class in rates:
		total += rates[hero_class]
	for hero_class in rates:
		rates[hero_class] /= total
	return rates


## Tire la classe d'un héros selon sa rareté.
func _roll_class(rarity: int, allow_mage: bool) -> String:
	var rates := class_rates(rarity, allow_mage)
	var roll := randf()
	var cumulative := 0.0
	for hero_class in rates:
		cumulative += rates[hero_class]
		if roll < cumulative:
			return hero_class
	return rates.keys()[0]


## Crée un nouveau héros ordinaire de la rareté donnée.
## « allow_mage » : seule l'invocation spéciale peut donner un mage.
func _create_hero(rarity: int, allow_mage := false) -> Dictionary:
	var hero_class := _roll_class(rarity, allow_mage)

	var growth: int = GROWTH[rarity]
	if rarity == 1 and randf() < HIDDEN_TALENT_CHANCE:
		growth += 3  # talent caché : croissance digne d'un 3 étoiles

	var hero := _new_hero(HERO_NAMES.pick_random(), rarity, hero_class, growth, [])
	if hero_class == "Mage":
		hero["element"] = MAGIC_ELEMENTS.pick_random()  # magie de feu, de vent ou de froid
	return hero


## Crée un héros secret à partir de SECRET_HEROES.
func _create_secret_hero(hero_name: String) -> Dictionary:
	var template: Dictionary = SECRET_HEROES[hero_name]
	var hero := _new_hero(hero_name, template["rarity"], template["class"], template["growth"],
		template["skills"].duplicate(true))
	hero["immortal"] = true
	hero["secret"] = true
	return hero


func _new_hero(hero_name: String, rarity: int, hero_class: String, growth: int, skills: Array) -> Dictionary:
	var hero := {
		"id": next_hero_id,
		"name": hero_name,
		"rarity": rarity,
		"class": hero_class,
		"level": 1,
		"xp": 0,
		"growth": growth,
		"stats": _roll_stats(rarity, hero_class),
		"skills": skills,
		"skill_progress": {},  # points de progrès par compétence (entraînement, tirs...)
		"training": "",        # compétence travaillée au terrain d'entraînement (vide = au repos)
		"training_since": 0.0, # moment (temps réel) où la séance en cours a commencé
		"alive": true,
		"immortal": false,
		"secret": false,
		"favorite": false,     # mis en favori par le Maître (voir FAVORITES_MAX)
	}
	next_hero_id += 1
	return hero


## Statistiques de départ : la base de la rareté, un peu de hasard (±1),
## et +3 dans la statistique favorisée par la classe.
func _roll_stats(rarity: int, hero_class: String) -> Dictionary:
	var stats := {}
	for stat in STAT_NAMES:
		stats[stat] = BASE_STAT[rarity] + randi_range(-1, 1)
	if hero_class == "Mage":
		# Les mages sont puissants mais fragiles, comme la magicienne 3 étoiles du manhwa :
		# Intelligence très haute (31) et tout le reste très bas (7-8).
		for stat in STAT_NAMES:
			stats[stat] = maxi(5, stats[stat] - MAGE_STAT_MALUS)
		stats["int"] = BASE_STAT[rarity] * 2 + 1 + randi_range(-1, 1)
		return stats
	var main_stat: String = CLASS_MAIN_STAT[hero_class]
	if main_stat != "":
		stats[main_stat] += 3
	return stats


# ---------------------------------------------------------------------------
# Codes secrets
# ---------------------------------------------------------------------------

## Essaie un code secret. Renvoie le héros obtenu, ou {} si le code est faux ou déjà utilisé.
func redeem_code(code: String) -> Dictionary:
	code = code.strip_edges().to_upper()
	if code == "" or code in used_codes:
		return {}
	for hero_name in SECRET_HEROES:
		if SECRET_HEROES[hero_name]["code"] == code:
			# Déjà dans la cité (par exemple Han, donné au début dans les anciennes parties) : pas de double.
			if roster.any(func(hero): return hero.get("secret", false) and hero["name"] == hero_name):
				return {}
			used_codes.append(code)
			var hero := _create_secret_hero(hero_name)
			roster.append(hero)
			save_game()
			return hero
	return {}


# ---------------------------------------------------------------------------
# Promotion (passage à l'étoile suivante)
# ---------------------------------------------------------------------------
# Un héros arrivé au niveau maximum de sa rareté peut passer à l'étoile suivante : il paie de l'or
# et des pierres d'attribut (matériau de l'entrepôt), gagne une étoile (donc un niveau maximum plus
# haut et de meilleures statistiques) et une compétence spéciale.
# Les pierres d'attribut se trouvent (rarement) au donjon journalier, et sur les étages de boss de la Tour.
# (Le cahier demande aussi un certain niveau de compétence ; on le fixera quand l'œuvre en parlera.)

const PROMOTION_STONE := "Pierre d'attribut"

## Coût de la promotion, selon les étoiles actuelles du héros (1 = passer de 1 à 2 étoiles).
## Provisoire, en attente de l'œuvre.
const PROMOTION_COSTS := {
	1: {"gold": 20000, "stones": 1},
	2: {"gold": 50000, "stones": 3},
	3: {"gold": 100000, "stones": 6},
	4: {"gold": 200000, "stones": 10},
}
## Étoiles maximum par promotion pour l'instant (6 et 7 étoiles viendront plus tard, cahier : phase 6).
const MAX_PROMOTION_RARITY := 5

## Compétences spéciales de promotion : une au hasard, parmi celles que le héros n'a pas encore.
## Provisoire, en attente de l'œuvre (effets dans battle.gd, chiffres ci-dessous).
const PROMOTION_SKILLS := ["Volonté de fer", "Second souffle", "Coup précis", "Peau de pierre", "Vivacité"]
const IRON_WILL_HP_PER_LEVEL := 0.1       # Volonté de fer : +10 % de vie maximum par niveau
const SECOND_WIND_HEAL := 0.15            # Second souffle : soigne 15 % (+5 % par niveau) une fois par combat
const SECOND_WIND_HEAL_PER_LEVEL := 0.05
const PRECISE_STRIKE_CRIT_PER_LEVEL := 0.05  # Coup précis : +5 % de coups critiques par niveau
const STONE_SKIN_PER_LEVEL := 0.04        # Peau de pierre : 4 % de dégâts subis en moins par niveau
const QUICKNESS_PER_LEVEL := 0.05         # Vivacité : coups 5 % plus rapides par niveau

## Pierres d'attribut : chance d'en ramasser une au donjon journalier, et nombre donné
## par un étage de boss de la Tour conquis pour la première fois.
const STONE_PICKUP_CHANCE := 0.03
const BOSS_STONES := 1


## Le coût de la promotion d'un héros ({"gold", "stones"}), ou {} s'il ne peut plus monter.
func promotion_cost(hero: Dictionary) -> Dictionary:
	return PROMOTION_COSTS.get(hero["rarity"], {})


## Pourquoi ce héros ne peut pas être promu (texte), ou "" si c'est possible.
func promotion_problem(hero: Dictionary) -> String:
	if not hero["alive"]:
		return "Il n'est plus de ce monde."
	if hero["rarity"] >= MAX_PROMOTION_RARITY or promotion_cost(hero).is_empty():
		return "Déjà au maximum (%d étoiles)." % MAX_PROMOTION_RARITY
	if not is_max_level(hero):
		return "Il doit d'abord atteindre le niveau %d." % MAX_LEVEL[hero["rarity"]]
	if is_away(hero):
		return "Il est parti (%s)." % activity_text(hero)
	var cost := promotion_cost(hero)
	if gold < cost["gold"]:
		return "Pas assez d'or."
	if material_count(PROMOTION_STONE) < cost["stones"]:
		return "Pas assez de pierres d'attribut."
	return ""


## Promeut un héros. Renvoie les lignes à annoncer, ou [] si c'est impossible.
func promote(hero: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	if promotion_problem(hero) != "":
		return lines
	var cost := promotion_cost(hero)
	gold -= cost["gold"]
	gold_changed.emit(gold)
	_take_material(PROMOTION_STONE, cost["stones"])
	lines.append_array(_apply_promotion(hero))
	save_game()
	return lines


## Le passage à l'étoile suivante lui-même (sans payer ni vérifier) : stats, niveau maximum,
## compétence spéciale. Renvoie les lignes à annoncer.
func _apply_promotion(hero: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var old_rarity: int = hero["rarity"]
	hero["rarity"] += 1
	hero["xp"] = 0
	# Les statistiques montent de l'écart entre les deux raretés (ex. 1 → 2 étoiles : +2 partout).
	var gap: int = BASE_STAT[hero["rarity"]] - BASE_STAT[old_rarity]
	for stat in STAT_NAMES:
		hero["stats"][stat] += gap
	lines.append("%s passe à %s ! Niveau maximum : %d." % [hero["name"], "★".repeat(hero["rarity"]), MAX_LEVEL[hero["rarity"]]])
	lines.append("Toutes ses statistiques : +%d." % gap)
	var choices := PROMOTION_SKILLS.filter(func(name): return skill_level(hero["skills"], name) == 0)
	if not choices.is_empty():
		var skill_name: String = choices.pick_random()
		hero["skills"].append({"name": skill_name, "rank": "Spéciale", "level": 1})
		lines.append("Compétence spéciale : %s." % skill_name)
	return lines


# ---------------------------------------------------------------------------
# Synthèse de héros (chambre de synthèse)
# ---------------------------------------------------------------------------
# On sacrifie un ou plusieurs héros (de n'importe quel rang) pour en renforcer un autre (cahier :
# « on fusionne 2 héros ou plus : un seul survit »). Les sacrifiés disparaissent pour toujours (comme
# une mort, leurs armes sont perdues avec eux). Le héros renforcé :
# - gagne de l'expérience, et au moins un niveau (cahier : « le héros renforcé monte de niveau »),
#   sauf s'il est déjà au niveau maximum ;
# - pour chaque sacrifié, a des chances de récupérer une de ses compétences, au niveau 1 (compétence héritée) ;
# - s'il se bat de loin, a des chances de gagner Œil de faucon (cahier : Jenna l'obtient en synthèse) ;
# - très rarement, gagne Analyse froide.
# (Le cahier parle aussi d'une perte de moral : elle viendra avec le moral, en phase 5.)
# Chiffres provisoires.

## Nombre de héros qu'on peut sacrifier d'un coup.
const SYNTHESIS_MAX_SACRIFICES := 5
## Expérience gagnée par sacrifié : une base, plus (niveau x étoiles du sacrifié) x ce nombre.
const SYNTHESIS_XP_BASE := 20
const SYNTHESIS_XP_PER_LEVEL_STAR := 10
## Chance de récupérer une compétence de chaque sacrifié (au niveau 1), et chance d'Analyse froide.
const INHERIT_CHANCE := 0.2
const COLD_ANALYSIS_CHANCE := 0.01
## Analyse froide : précision et coups critiques en plus, par niveau (0.1 = 10 %).
## La précision réduit les chances d'esquive de la cible.
const COLD_ANALYSIS_PER_LEVEL := 0.1
## Œil de faucon : chance à chaque synthèse (apprise, ou un niveau de plus) pour les classes qui
## se battent de loin ; puis, pour les tirs (flèches et sorts), portée en plus (en cases) et
## précision en plus, par niveau.
const HAWK_EYE_CHANCE := 0.3
const HAWK_EYE_CLASSES := ["Archer", "Mage", "Soigneur"]
const HAWK_EYE_REACH_PER_LEVEL := 0.3
const HAWK_EYE_PRECISION_PER_LEVEL := 0.05


## Expérience que le héros renforcé gagne en sacrifiant « sacrifice ».
func synthesis_xp(sacrifice: Dictionary) -> int:
	return SYNTHESIS_XP_BASE + sacrifice["level"] * sacrifice["rarity"] * SYNTHESIS_XP_PER_LEVEL_STAR


## Expérience totale d'une synthèse : celle de chaque sacrifié, et au moins de quoi monter
## d'un niveau. 0 si le héros est déjà au niveau maximum.
func synthesis_total_xp(target: Dictionary, sacrifices: Array) -> int:
	if is_max_level(target):
		return 0
	var xp := 0
	for sacrifice in sacrifices:
		xp += synthesis_xp(sacrifice)
	return maxi(xp, xp_to_next(target["level"]) - target["xp"])


## Pourquoi ce héros ne peut pas être sacrifié pour renforcer « target » (texte), ou "" si c'est possible.
func synthesis_problem(target: Dictionary, sacrifice: Dictionary) -> String:
	if not "synthese" in buildings:
		return "La chambre de synthèse n'est pas construite."
	if target["id"] == sacrifice["id"]:
		return "Un héros ne peut pas se sacrifier pour lui-même."
	if not target["alive"] or not sacrifice["alive"]:
		return "Les deux héros doivent être en vie."
	if sacrifice.get("secret", false):
		return "Un héros légendaire ne peut pas être sacrifié."
	if is_favorite(sacrifice):
		return "Un héros favori ne peut pas être sacrifié (retire-le d'abord des favoris)."
	if is_away(target) or is_away(sacrifice):
		return "Les deux héros doivent être à la cité."
	return ""


## Vrai si ce héros peut gagner Œil de faucon en synthèse (sa classe se bat de loin).
func can_get_hawk_eye(hero: Dictionary) -> bool:
	return hero["class"] in HAWK_EYE_CLASSES and _own_skill_level(hero["skills"], "Œil de faucon") < SKILL_MAX_LEVEL


## La synthèse : « sacrifices » disparaissent pour renforcer « target ».
## Renvoie les lignes à annoncer, ou [] si c'est impossible.
func synthesize(target: Dictionary, sacrifices: Array) -> Array[String]:
	var lines: Array[String] = []
	if sacrifices.is_empty() or sacrifices.size() > SYNTHESIS_MAX_SACRIFICES:
		return lines
	for sacrifice in sacrifices:
		if synthesis_problem(target, sacrifice) != "":
			return lines

	var xp := synthesis_total_xp(target, sacrifices)
	# Les sacrifiés disparaissent pour toujours.
	for sacrifice in sacrifices:
		sacrifice["alive"] = false
		sacrifice["death_cause"] = "sacrifié en synthèse pour renforcer %s" % target["name"]
		_remove_from_teams(sacrifice["id"])
		lines.append("%s (%s) a disparu pour toujours." % [sacrifice["name"], "★".repeat(sacrifice["rarity"])])

	if xp == 0:
		lines.append("%s est déjà au niveau maximum : l'expérience est perdue (pense à la promotion)." % target["name"])
	else:
		var levels := gain_xp(target, xp)
		lines.append("%s gagne %d d'expérience%s." % [target["name"], xp,
			" et passe au niveau %d" % target["level"] if levels > 0 else ""])

	# Compétence héritée : pour chaque sacrifié, une chance de récupérer une de ses compétences.
	for sacrifice in sacrifices:
		if randf() >= INHERIT_CHANCE:
			continue
		var candidates := []
		for skill in sacrifice["skills"]:
			if can_learn_skill(target, target["skills"], skill["name"]) and not skill["name"] in SKILL_FUSIONS:
				candidates.append(skill["name"])
		if not candidates.is_empty():
			var inherited: String = candidates.pick_random()
			target["skills"].append(new_skill(inherited))
			lines.append("Compétence héritée de %s : %s (niveau 1) !" % [sacrifice["name"], inherited])
	# Œil de faucon : pour ceux qui se battent de loin ; un niveau de plus s'ils l'ont déjà.
	if can_get_hawk_eye(target) and randf() < HAWK_EYE_CHANCE:
		var level := _own_skill_level(target["skills"], "Œil de faucon")
		if level == 0:
			target["skills"].append(new_skill("Œil de faucon"))
			lines.append("Nouvelle compétence : Œil de faucon !")
		else:
			for skill in target["skills"]:
				if skill["name"] == "Œil de faucon":
					skill["level"] += 1
			lines.append("Œil de faucon passe au niveau %d !" % (level + 1))
	# Analyse froide : très rare, juste après une synthèse.
	if randf() < COLD_ANALYSIS_CHANCE and can_learn_skill(target, target["skills"], "Analyse froide"):
		target["skills"].append(new_skill("Analyse froide"))
		lines.append("Compétence rare : Analyse froide !")
	tidy_arsenal()  # les armes des sacrifiés sont perdues (et la partie est sauvegardée)
	return lines


# ---------------------------------------------------------------------------
# Expérience et niveaux
# ---------------------------------------------------------------------------

## Expérience nécessaire pour passer du niveau « level » au suivant.
## 10 au niveau 1, 20 au niveau 2... 50 au niveau 5, puis la courbe s'accélère : 70, 90, 110...
func xp_to_next(level: int) -> int:
	if level <= 5:
		return 10 * level
	return 50 + 20 * (level - 5)


func is_max_level(hero: Dictionary) -> bool:
	return hero["level"] >= MAX_LEVEL[hero["rarity"]]


## Donne de l'expérience à un héros. Renvoie le nombre de niveaux gagnés.
func gain_xp(hero: Dictionary, amount: int) -> int:
	var levels := 0
	if is_max_level(hero):
		return 0
	hero["xp"] += amount
	while hero["xp"] >= xp_to_next(hero["level"]):
		hero["xp"] -= xp_to_next(hero["level"])
		_level_up(hero)
		levels += 1
		if is_max_level(hero):
			hero["xp"] = 0
			break
	return levels


## Montée de niveau : le héros gagne autant de points que sa valeur de croissance,
## répartis au hasard (la statistique de sa classe a plus de chances d'en recevoir).
## Les stats bougent de façon inégale : parfois l'une baisse pendant qu'une autre monte.
func _level_up(hero: Dictionary) -> void:
	hero["level"] += 1
	var stats: Dictionary = hero["stats"]
	var choices: Array = STAT_NAMES.keys()
	var main_stat: String = CLASS_MAIN_STAT[hero["class"]]
	if main_stat != "":
		choices.append(main_stat)  # deux fois dans la liste = deux fois plus de chances
	if hero["class"] == "Mage":
		choices.append_array(["int", "int"])  # un mage met presque tout dans l'Intelligence
	for i in hero["growth"]:
		stats[choices.pick_random()] += 1
	if randf() < 0.25:
		var down: String = STAT_NAMES.keys().pick_random()
		if stats[down] > 1:
			stats[down] -= 1
			stats[choices.pick_random()] += 1


# ---------------------------------------------------------------------------
# Combat
# ---------------------------------------------------------------------------

## Réserve de mana des mages et des soigneurs, par point d'Intelligence (la recharge et le coût
## des sorts sont dans battle.gd).
const MANA_PER_INT := 4


## Transforme les 4 statistiques (d'un héros ou d'un ennemi) en valeurs de combat :
## points de vie, attaque, défense, vitesse, chance de coup critique, mana.
func combat_stats(unit: Dictionary) -> Dictionary:
	var stats: Dictionary = unit["stats"]
	var magic: bool = unit["class"] in ["Mage", "Soigneur"]
	return {
		"hp": stats["vit"] * 8,
		"atk": stats["int"] if magic else stats["str"],
		"def": roundi(stats["vit"] / 2.0),
		"spd": stats["dex"],
		"crit": stats["dex"] / 200.0,
		# Mana : seulement pour les classes qui lancent des sorts (réserve = Intelligence x MANA_PER_INT).
		"mana": stats["int"] * MANA_PER_INT if magic else 0,
	}


## Héros encore en vie (ceux qui peuvent combattre).
func alive_heroes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for hero in roster:
		if hero["alive"]:
			result.append(hero)
	return result


func is_boss_floor(floor_number: int) -> bool:
	return floor_number % BOSS_EVERY == 0


## Niveau des monstres d'un étage (étage 1 : gobelins de niveau 3).
## À chaque palier (étage 5, 10...), les monstres gagnent TIER_BONUS_LEVELS niveaux de plus :
## l'étage de boss est un mur à franchir, et les étages suivants restent à ce nouveau cran.
func floor_enemy_level(floor_number: int) -> int:
	return floor_number + 2 + floor_tier(floor_number) * TIER_BONUS_LEVELS


## Numéro du palier d'un étage : 0 pour les étages 1 à 4, 1 pour 5 à 9, 2 pour 10 à 14...
func floor_tier(floor_number: int) -> int:
	return floor_number / BOSS_EVERY


## Récompenses d'un étage : de l'or (5 000 à l'étage 1, 10 000 à l'étage 4...),
## quelques gemmes, et de l'expérience pour chaque héros survivant.
## Un étage de boss rapporte trois fois plus.
func tower_rewards(floor_number: int) -> Dictionary:
	var bonus := 3 if is_boss_floor(floor_number) else 1
	return {
		"gold": roundi(5000 * (1 + (floor_number - 1) / 3.0)) * bonus,
		"gems": (30 + 5 * floor_number) * bonus,
		"xp": (10 + 5 * floor_number) * bonus,
	}


## Quête d'un étage : son type, son objectif et ses règles.
## Étage 1 : extermination ; étage 2 : subjugation ; ensuite annihilation ;
## tous les 5 étages : survie face à une horde (niveau des ennemis caché) ;
## tous les 10 étages : défense de la cité, annoncée par trois avertissements.
func floor_quest(floor_number: int) -> Dictionary:
	var type := "annihilation"
	if floor_number % 10 == 0:
		type = "defense"
	elif floor_number % 5 == 0:
		type = "survival"
	elif floor_number == 1:
		type = "extermination"
	elif floor_number == 2:
		type = "subjugation"
	var quest: Dictionary = QUEST_TYPES[type].duplicate()
	quest["type"] = type
	quest["lasting"] = type in ["survival", "defense"]  # il faut tenir, pas tout tuer
	quest["seconds"] = SURVIVAL_SECONDS if quest["lasting"] else KILL_QUEST_SECONDS
	quest["warnings"] = 3 if type == "defense" else 0
	quest["hidden_level"] = type == "survival"
	quest["walls"] = DEFENSE_WALLS if type == "defense" else 0
	return quest


## Crée les ennemis d'un étage : de plus en plus nombreux, de plus en plus forts,
## et de nouveaux monstres apparaissent en montant. Sur un étage de boss,
## le boss prend la place de 2 monstres (il en reste toujours au moins 2 pour l'escorter).
## Au combat, 6 ennemis au plus se battent en même temps : les autres arrivent en renfort
## (annihilation : quelques-uns ; survie et défense : toute une horde).
func tower_enemies(floor_number: int) -> Array[Dictionary]:
	var quest := floor_quest(floor_number)
	var level := floor_enemy_level(floor_number)
	var enemies: Array[Dictionary] = []
	var monster_count := mini(2 + floor_number / 2, 6)
	if is_boss_floor(floor_number):
		var boss_index := mini(floor_number / BOSS_EVERY - 1, BOSS_TYPES.size() - 1)
		enemies.append(_create_enemy(BOSS_TYPES[boss_index], level + 2))
		enemies[0]["boss"] = true
		monster_count = maxi(2, monster_count - 2)
	match quest["type"]:
		"annihilation":
			monster_count += floor_number / 3
		"survival":
			monster_count += 4 + floor_number / 2
		"defense":
			monster_count += 4 + floor_number / 2
	var known_types := ENEMY_TYPES.slice(0, mini(1 + floor_number / 2, ENEMY_TYPES.size()))
	for i in monster_count:
		enemies.append(_create_enemy(known_types.pick_random(), level))
	_number_duplicates(enemies)
	return enemies


## Crée un ennemi à partir d'un modèle, renforcé selon son niveau.
func _create_enemy(template: Dictionary, level: int) -> Dictionary:
	var multiplier := 1.0 + (level - 1) * ENEMY_BONUS_PER_LEVEL
	var stats := {}
	for stat in STAT_NAMES:
		var value: float = template[stat]
		if stat != "dex":  # la vitesse change peu, pour que l'ordre d'action reste lisible
			value *= multiplier
		stats[stat] = maxi(1, roundi(value * randf_range(0.9, 1.1)))
	# « base_name » garde le nom sans lettre (Gobelin), pour regrouper les ennemis à l'affichage.
	return {"name": template["name"], "base_name": template["name"], "class": template["class"],
		"level": level, "stats": stats, "element": template.get("element", "")}


## Ajoute une lettre aux ennemis qui portent le même nom (Gobelin A, Gobelin B...),
## pour s'y retrouver dans le journal de combat.
func _number_duplicates(enemies: Array[Dictionary]) -> void:
	var counts := {}
	for enemy in enemies:
		counts[enemy["name"]] = counts.get(enemy["name"], 0) + 1
	var seen := {}
	for enemy in enemies:
		var base_name: String = enemy["name"]
		if counts[base_name] > 1:
			var index: int = seen.get(base_name, 0)
			seen[base_name] = index + 1
			enemy["name"] = "%s %s" % [base_name, char(65 + index)]


## Début d'un combat de la Tour : on le note dans la sauvegarde (voir pending_battle).
## « floor_number » : l'étage joué (un étage déjà conquis peut être rejoué, voir REPLAY_GOLD_RATE).
## Les héros prennent leurs armes dans l'arsenal au départ (gear_up) : à appeler avant Battle.new.
func start_tower_battle(team: Array, enemies: Array, quest: Dictionary, floor_number: int) -> void:
	update_training()  # les séances terminées avant le départ sont comptées
	pending_battle = {
		"floor": floor_number,
		"team": team.map(func(hero): return hero["id"]),
		"enemies": enemies.duplicate(true),
		"quest": quest,
	}
	gear_up(team)  # sauvegarde aussi la partie


## Le jeu a été fermé en plein combat : les héros se sont débrouillés seuls.
## On rejoue tout le combat sans ordres, on applique le résultat, et on le garde pour l'annoncer.
func _resolve_pending_battle() -> void:
	var team: Array[Dictionary] = []
	for hero in alive_heroes():
		if hero["id"] in pending_battle["team"]:
			team.append(hero)
	var floor_number: int = pending_battle["floor"]
	if team.is_empty():
		pending_battle = {}
		save_game()
		return
	var battle := Battle.new(team, pending_battle["enemies"], pending_battle["quest"])
	battle.run()
	absence_report = {"floor": floor_number, "report": finish_tower_battle(battle)}


## Compétences gagnées par les exploits d'un survivant pendant le combat (textes à annoncer) :
## - Tueur de gobelins : coup fatal au boss de l'étage 5 (le Chef gobelin), ou 1 point par gobelin tué ;
## - Résistance aux flammes : 1 point par combat fini dans la même équipe qu'un mage de feu.
func _combat_feats(hero: Dictionary, fighter: Dictionary, battle: Battle) -> Array[String]:
	var news: Array[String] = []
	var goblins := 0
	var boss_goblin := false
	for kill in fighter["kills"]:
		if kill["name"].to_lower().contains("gobelin"):
			goblins += 1
			if kill["boss"]:
				boss_goblin = true
	if boss_goblin and skill_level(hero["skills"], "Tueur de gobelins") == 0:
		hero["skills"].append(new_skill("Tueur de gobelins"))
		news.append("%s — exploit ! Nouvelle compétence : Tueur de gobelins" % hero["name"])
	elif goblins > 0:
		news.append_array(add_skill_progress(hero, "Tueur de gobelins", goblins, GOBLIN_KILLS_PER_LEVEL))
	for ally in battle.heroes:
		if ally["id"] != fighter["id"] and ally["class"] == "Mage" and ally["element"] == "Feu":
			news.append_array(add_skill_progress(hero, "Résistance aux flammes", 1, FIRE_MAGE_FIGHTS_PER_LEVEL))
			break
	return news


## Applique le résultat d'un combat de la Tour et renvoie un rapport pour l'écran de fin :
## - les héros tombés meurent pour toujours (sauf les immortels) ;
## - en cas de victoire : or, gemmes, expérience pour les survivants, étage suivant ;
## - en cas de défaite : les survivants gagnent quand même la moitié de l'expérience
##   (sinon une équipe bloquée ne pourrait plus jamais progresser) ;
## - un étage déjà conquis (rejoué pour entraîner une équipe) donne moins d'expérience et d'or,
##   pas de gemmes, et ne fait pas monter dans la Tour.
func finish_tower_battle(battle: Battle) -> Dictionary:
	var floor_number: int = pending_battle.get("floor", tower_floor)
	var replay := floor_number < tower_floor
	pending_battle = {}  # le combat est terminé (la sauvegarde est réécrite plus bas)
	# Les héros inscrits au terrain d'entraînement le retrouvent : la séance repart de zéro.
	for fighter in battle.heroes:
		fighter["source"]["training_since"] = Time.get_unix_time_from_system()
	var report := {
		"victory": battle.victory,
		"gold": 0,
		"gems": 0,
		"xp": 0,
		"dead": [],       # [{"hero": ..., "cause": ...}]
		"level_ups": [],  # [{"hero": ..., "levels": ...}]
		"skills": [],     # compétences apprises ou améliorées pendant le combat (textes)
		"notices": [],    # annonces spéciales (déblocages...)
		"mvp": battle.mvp(),
		"floor": floor_number,
		"replay": replay,  # étage déjà conquis, rejoué pour s'entraîner
	}
	if battle.victory and not replay and floor_number == DAILY_UNLOCK_FLOOR:
		report["notices"].append("Félicitations, Maître ! Vous avez franchi le %de étage. Le donjon journalier est débloqué." % DAILY_UNLOCK_FLOOR)
		report["notices"].append("Conseil : rassemblez des matériaux et renforcez vos héros avant de monter plus haut.")
	for fighter in battle.heroes:
		if fighter["hp"] <= 0 and not fighter["immortal"]:
			fighter["source"]["alive"] = false
			_remove_from_teams(fighter["source"]["id"])
			# La cause est gardée sur la fiche du héros (et donc dans la sauvegarde).
			fighter["source"]["death_cause"] = fighter["killer"]
			report["dead"].append({"hero": fighter["source"], "cause": fighter["killer"]})

	var rewards := tower_rewards(floor_number)
	if replay:
		rewards["gold"] = roundi(rewards["gold"] * REPLAY_GOLD_RATE)
		rewards["gems"] = 0
		rewards["xp"] = roundi(rewards["xp"] * REPLAY_XP_RATE)
	if battle.victory:
		report.merge(rewards, true)
		if not replay:
			tower_floor += 1
			# Objet de promotion : un étage de boss conquis donne des pierres d'attribut.
			if is_boss_floor(floor_number):
				add_material(PROMOTION_STONE, "F", BOSS_STONES)
				report["stones"] = BOSS_STONES
		add_gold(rewards["gold"])
		add_gems(rewards["gems"])
	else:
		report["xp"] = rewards["xp"] / 2

	for fighter in battle.heroes:
		var hero: Dictionary = fighter["source"]
		if hero["alive"]:
			# Les compétences gagnées pendant le combat sont gardées par les survivants.
			hero["skills"] = fighter["skills"]
			report["skills"].append_array(fighter["skill_news"])
			# Maîtrise de l'arc : chaque flèche tirée fait progresser la compétence.
			if fighter["shots"] > 0:
				report["skills"].append_array(add_skill_progress(hero, "Maîtrise de l'arc",
					fighter["shots"], skill_progress_needed("Maîtrise de l'arc")))
			report["skills"].append_array(_combat_feats(hero, fighter, battle))
			report["skills"].append_array(check_evolutions(hero))
			var levels := gain_xp(hero, report["xp"])
			if levels > 0:
				report["level_ups"].append({"hero": hero, "levels": levels})
	tidy_arsenal()  # armes des morts perdues, les autres reposent les leurs (et la partie est sauvegardée)
	return report


# ---------------------------------------------------------------------------
# Mode dev (outils de test)
# ---------------------------------------------------------------------------
# Actif quand Settings.dev_mode est vrai (code secret Settings.DEV_CODE) : or et gemmes infinis
# (voir « gems » et « gold »), et ces outils, utilisés par dev_panel.gd et la fiche du héros.
# Ils passent outre les règles du jeu : à ne jamais appeler en dehors du mode dev.

## Crée un héros de la rareté voulue ; « hero_class » vide = classe tirée au hasard (mages possibles).
func dev_create_hero(rarity: int, hero_class := "") -> Dictionary:
	if hero_class == "":
		hero_class = _roll_class(rarity, true)
	var hero := _new_hero(HERO_NAMES.pick_random(), rarity, hero_class, GROWTH[rarity], [])
	if hero_class == "Mage":
		hero["element"] = MAGIC_ELEMENTS.pick_random()
	roster.append(hero)
	save_game()
	return hero


## Fait gagner « count » niveaux à un héros (sans dépasser son niveau maximum).
func dev_add_levels(hero: Dictionary, count: int) -> void:
	for i in count:
		if is_max_level(hero):
			break
		gain_xp(hero, xp_to_next(hero["level"]) - hero["xp"])
	save_game()


func dev_add_xp(hero: Dictionary, amount: int) -> void:
	gain_xp(hero, amount)
	save_game()


## Passe à l'étoile suivante gratuitement, sans attendre le niveau maximum.
func dev_promote(hero: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	if hero["rarity"] >= MAX_PROMOTION_RARITY:
		return lines
	lines = _apply_promotion(hero)
	hero["level"] = mini(hero["level"], MAX_LEVEL[hero["rarity"]])
	save_game()
	return lines


func dev_add_stats(hero: Dictionary, amount: int) -> void:
	for stat in STAT_NAMES:
		hero["stats"][stat] = maxi(1, hero["stats"][stat] + amount)
	save_game()


## Donne une compétence au niveau 1 (sans vérifier les incompatibilités), ou la monte d'un niveau.
func dev_give_skill(hero: Dictionary, skill_name: String) -> void:
	for skill in hero["skills"]:
		if skill["name"] == skill_name:
			skill["level"] = mini(skill["level"] + 1, SKILL_MAX_LEVEL)
			save_game()
			return
	var skill := new_skill(skill_name)
	if skill_name in SKILL_FUSIONS:
		skill["rank"] = SKILL_FUSIONS[skill_name]["rank"]
	elif skill_name in SKILL_EVOLUTIONS:
		skill["rank"] = SKILL_EVOLUTIONS[skill_name]["rank"]
	hero["skills"].append(skill)
	save_game()


func dev_set_skill_level(hero: Dictionary, skill_name: String, level: int) -> void:
	for skill in hero["skills"]:
		if skill["name"] == skill_name:
			skill["level"] = clampi(level, 1, SKILL_MAX_LEVEL)
	save_game()


func dev_remove_skill(hero: Dictionary, skill_name: String) -> void:
	hero["skills"] = hero["skills"].filter(func(skill): return skill["name"] != skill_name)
	save_game()


## Ramène un héros mort (sans ses armes, perdues avec lui).
func dev_revive(hero: Dictionary) -> void:
	hero["alive"] = true
	hero["death_cause"] = ""
	save_game()


## Change le prochain étage de la Tour à conquérir (1 au minimum).
func dev_set_floor(floor_number: int) -> void:
	tower_floor = maxi(1, floor_number)
	save_game()


func dev_unlock_training() -> void:
	weapon_draws = maxi(weapon_draws, TRAINING_UNLOCK_DRAWS)
	save_game()


## Les héros à l'entraînement (et à la cité) font une séance tout de suite.
func dev_training_session() -> void:
	update_training()
	for hero in trainees():
		if not is_away(hero):
			hero["training_since"] = Time.get_unix_time_from_system() - TRAINING_SESSION_SECONDS
	update_training()
	save_game()


## Le donjon journalier peut être refait aujourd'hui.
func dev_reset_daily() -> void:
	last_expedition_day = ""
	save_game()


## L'expédition en cours se termine tout de suite (tous ses ramassages compris).
func dev_finish_expedition() -> void:
	if expedition.is_empty():
		return
	var shift := float(expedition_remaining())
	expedition["start"] -= shift
	expedition["end"] -= shift
	update_expedition()


## Construit tous les bâtiments, gratuitement et sans conditions.
func dev_build_all() -> void:
	for building_id in BUILDINGS:
		if not building_id in buildings:
			buildings.append(building_id)
	save_game()


## Ajoute « count » de chaque matériau du donjon journalier (au grade voulu) et des pierres d'attribut.
func dev_add_materials(grade: String, count: int) -> void:
	for material in DAILY_DUNGEON["materials"]:
		add_material(material, grade, count)
	add_material(PROMOTION_STONE, "F", count)
	save_game()


## Donne tous les plans de forge.
func dev_all_plans() -> void:
	for weapon_type in WEAPON_TYPES:
		if not weapon_type in plans:
			plans.append(weapon_type)
	save_game()
