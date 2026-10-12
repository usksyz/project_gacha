class_name GameHeroes
extends GameState
## Les héros : fiche (statistiques, rareté, héros secrets), compétences, expérience et niveaux,
## équipes composées à l'avance, favoris, et où se trouve un héros (Tour, donjon journalier).
## Fait partie de la pile de GameData (voir game_data.gd).


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
	# Classes d'apprenti (premier changement de classe, voir « Changement de classe »).
	"Apprenti guerrier": "str",
	"Apprenti voleur": "dex",
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

## Héros secrets (clins d'œil au manhwa). Ils sont mortels comme les autres (feuille de route v2 ;
## avant, ils étaient immortels) : l'immortalité n'existe plus qu'en mode dev (voir is_immortal).
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
	# Yvolka Rivel Strachur, la magicienne 3 étoiles du manhwa (fiche du cahier : 7 / 31 / 8 / 7,
	# « Magie de feu intermédiaire », pas encore une compétence du jeu : ici, la magie de feu).
	"Yvolka": {"rarity": 3, "class": "Mage", "growth": 5, "code": "YVOLKA", "element": "Feu",
		"stats": {"str": 7, "int": 31, "vit": 8, "dex": 7}, "skills": []},
	# Edith Callen, la voleuse 3 étoiles (cahier : Force 13, Vitalité 14, Dextérité 17 ; Intelligence
	# non donnée, à confirmer). Sa « Épée courte » (niv. 3) devient Maîtrise de l'épée, son « Tir à l'arc »
	# Maîtrise de l'arc.
	"Edith": {"rarity": 3, "class": "Assassin", "growth": 5, "code": "EDITH",
		"stats": {"str": 13, "int": 12, "vit": 14, "dex": 17}, "skills": [
			{"name": "Maîtrise de l'épée", "rank": "Débutant", "level": 3},
			{"name": "Maîtrise de l'arc", "rank": "Débutant", "level": 1},
			{"name": "Mouvement souple", "rank": "Débutant", "level": 1}]},
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
	"Berserk": "Active, à bascule (acquise une fois, aux portes de la mort). En combat, il entre en rage de lui-même quand le combat est difficile (boss, horde, duel, allié en danger), ou sur ton ordre : Force, Santé et Dextérité +5, Intelligence -10 (+1 aux bonus par niveau suivant), mais il perd 1 % de sa vie et de la santé mentale chaque seconde. Il en sort quand le danger est passé, sous 15 % de vie, et à la fin du combat. Après : Migraine 3 minutes (-10 % de dégâts).",
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
	"Surpassement": "Fusion de Calme et Berserk (unique). Garde leurs effets ; en Berserk, bonus doublés et plus de saignement, mais il perd 2 % de sa vie et deux fois plus de santé mentale chaque seconde, et la migraine dure deux fois plus longtemps. Il en sort de lui-même sous 25 % de vie.",
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
		"when": "Berserk s'active en combat"},
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

# --- Berserk : compétence active à bascule (feuille de route v2, section 2) ---
# Acquisition (une seule fois) : par éveil, aux portes de la mort (battle.gd, DEATH_DOOR_CHANCE).
# Utilisation : en combat, le héros l'active de lui-même quand le combat est difficile (boss, horde,
# duel, allié en danger), ou sur ordre du Maître (bouton « Berserk » de l'écran de combat) ; il la
# désactive quand le danger est passé, et elle s'arrête à la fin du combat. Ensuite : Migraine.
# Les noms de l'œuvre (Force, Endurance, Agilité) sont ceux du jeu : Force, Santé, Dextérité.

## Éveil de Berserk : il doit rester rare (feuille de route v2 ; dans l'œuvre, seul Han l'éveille, par une volonté
## de vivre exceptionnelle). Hors Han, seul un héros Courageux ou Ambitieux (BERSERK_AWAKEN_TRAITS, trait révélé
## s'il l'éveille) le peut, aux portes de la mort (battle.gd), avec BERSERK_AWAKEN_CHANCE, et une seule fois dans
## sa vie : la chance est tentée une fois, puis plus jamais (hero["berserk_door_tried"], enregistré ; absent
## d'une ancienne sauvegarde = pas encore tentée). Avant : tout héros, 30 % à chaque combat, plus l'éveil. Han
## garde ses chances (battle.gd, DEATH_DOOR_CHANCE et HAN_AWAKENING_CHANCE). Chiffre provisoire.
const BERSERK_AWAKEN_TRAITS := ["Courageux", "Ambitieux"]
const BERSERK_AWAKEN_CHANCE := 0.1

## Bonus en Berserk : Force, Santé et Dextérité +BERSERK_BONUS au niveau 1 (+1 par niveau suivant),
## Intelligence -BERSERK_INT_MALUS.
const BERSERK_BONUS := 5
const BERSERK_INT_MALUS := 10
## Le héros garde la rage au moins ce temps (secondes de combat) avant de la couper de lui-même.
const BERSERK_MIN_SECONDS := 5.0
## Le Maître lui a ordonné de la couper : il ne la relance pas de lui-même pendant ce temps.
const BERSERK_ORDER_HOLD := 15.0
## Dans l'œuvre, la compétence coûte de la vie : cette part de la vie maximum par seconde en rage.
const BERSERK_DRAIN_PER_SECOND := 0.01
## (Ajout du projet) Sous cette santé mentale, ou sous BERSERK_STOP_HP de sa vie, le héros coupe la rage
## de lui-même (sur ordre du Maître, il la garde quand même). Plus tard, ces seuils dépendront du
## caractère (Maîtrise de soi).
const BERSERK_STOP_MENTAL := 25.0
const BERSERK_STOP_HP := 0.15
## « Allié en danger » : un allié (ou lui-même) sous cette part de sa vie, à moins de BERSERK_ALLY_RANGE cases.
const BERSERK_DANGER_HP := 0.3
const BERSERK_ALLY_RANGE := 5.0
## Migraine après la rage : durée en secondes (temps réel, elle continue après le combat), et dégâts
## multipliés par ceci tant qu'elle dure (0,9 = -10 %). Pendant la migraine, le héros ne relance pas la
## rage de lui-même (le Maître peut encore l'ordonner).
const MIGRAINE_SECONDS := 180.0
const MIGRAINE_DAMAGE_FACTOR := 0.9
## Rage d'éveil (interprétation du ch. 12 de l'œuvre, demande du porteur du projet) : quand Berserk s'éveille
## en combat, le héros entre aussitôt en rage. Cette première rage ignore la coupure automatique, et pendant
## AWAKENING_RAGE_SECONDS il ne peut pas tomber sous 1 point de vie (le refus de mourir : coups, saignement,
## coût de la rage). Ensuite, les règles normales de Berserk reprennent, et la migraine qui suit cette rage
## dure AWAKENING_MIGRAINE_FACTOR fois plus longtemps. Chiffres provisoires.
const AWAKENING_RAGE_SECONDS := 8.0
const AWAKENING_MIGRAINE_FACTOR := 2.0

## Surpassement (fusion de Calme et Berserk) : même bascule que Berserk, en plus fort et plus coûteux.
## Bonus multipliés par SURPASS_BONUS_MULTIPLIER, plus de saignement ; mais il perd SURPASS_DRAIN_PER_SECOND
## de sa vie maximum chaque seconde (au lieu de BERSERK_DRAIN_PER_SECOND), SURPASS_MENTAL_FACTOR fois plus de santé mentale, et la migraine dure
## SURPASS_MIGRAINE_FACTOR fois plus longtemps. Il le coupe de lui-même sous SURPASS_STOP_HP de sa vie.
const SURPASS_BONUS_MULTIPLIER := 2
const SURPASS_DRAIN_PER_SECOND := 0.02
const SURPASS_MENTAL_FACTOR := 2.0
const SURPASS_MIGRAINE_FACTOR := 2.0
const SURPASS_STOP_HP := 0.25


## Ce que Berserk change aux statistiques (selon ses compétences) : {"str": +5, "vit": +5, "dex": +5,
## "int": -10}, bonus doublés avec Surpassement ; {} sans Berserk.
func berserk_stat_changes(skills: Array) -> Dictionary:
	var level := skill_level(skills, "Berserk")
	if level == 0:
		return {}
	var bonus := BERSERK_BONUS + level - 1
	if skill_level(skills, "Surpassement") > 0:
		bonus *= SURPASS_BONUS_MULTIPLIER
	return {"str": bonus, "vit": bonus, "dex": bonus, "int": -BERSERK_INT_MALUS}


## Secondes de migraine qu'il reste à ce héros (0 s'il n'en a pas).
func migraine_left(hero: Dictionary) -> float:
	return maxf(0.0, hero.get("migraine_until", 0.0) - Time.get_unix_time_from_system())
## Épée et bouclier : dégâts en plus à l'épée, par niveau de la compétence fusionnée.
const SWORD_SHIELD_BONUS_PER_LEVEL := 0.02


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


## Vrai si ce héros ne peut pas mourir : seulement en mode dev, quand la case « Immortel » de sa fiche
## est cochée (hero["immortal"]). Hors du mode dev, tout le monde est mortel.
func is_immortal(hero: Dictionary) -> bool:
	return Settings.dev_mode and hero.get("immortal", false)


## Un héros d'une étoile reste un « novice du combat » pendant ses NOVICE_FIGHTS premiers combats :
## tout l'écrase (peur, personality.gd) et il bouge trop, s'épuisant deux fois plus vite (endurance, tower.gd).
const NOVICE_FIGHTS := 3


func is_combat_novice(hero: Dictionary) -> bool:
	return hero["rarity"] == 1 and hero.get("fights", 0) < NOVICE_FIGHTS


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
## Ce que les niveaux ont changé aux stats est dans last_growth (voir _level_up).
func gain_xp(hero: Dictionary, amount: int) -> int:
	var levels := 0
	last_growth = {}
	if is_max_level(hero):
		hero["growth_log"] = {}  # plus de niveaux à gagner : ce qu'il a fait ne compte plus
		return 0
	var shares := activity_shares(hero)
	hero["xp"] += amount
	while hero["xp"] >= xp_to_next(hero["level"]):
		hero["xp"] -= xp_to_next(hero["level"])
		_level_up(hero, shares)
		levels += 1
		if is_max_level(hero):
			hero["xp"] = 0
			break
	if levels > 0:
		hero["growth_log"] = {}  # on repart de zéro jusqu'au prochain niveau
	return levels


# --- Croissance selon ce que le héros a fait (feuille de route v2 : « à chaque niveau, un total fixe de
# points, répartis selon ce que fait le héros ; une stat peut baisser ») ---
# Le total de points par niveau reste sa valeur de croissance (cachée). Depuis son dernier niveau, le héros
# accumule de l'activité dans hero["growth_log"] ({"str": 12, "dex": 3, ...}) : coups portés → Force ;
# esquives et tirs → Dextérité ; coups encaissés → Santé ; magie (sorts, soins) ou étude → Intelligence.
# (Combat de la Tour : battle.gd, fighter["acts"] ; terrain d'entraînement : training.gd. L'étude viendra
# avec la bibliothèque.) Sans aucune activité (niveaux du mode dev...), l'ancienne répartition au hasard.
# Chiffres provisoires.

## Une stat qui a reçu moins de cette part de l'activité est « peu utilisée » : elle peut perdre 1 point
## (STAT_DECAY_CHANCE par niveau), donné à la stat la plus utilisée. Une seule par niveau, jamais sous 1.
const STAT_DECAY_SHARE := 0.1
const STAT_DECAY_CHANCE := 0.3

## (Pas enregistré) Ce qu'a changé le dernier gain_xp : {"str": 2, "int": -1, ...}, pour la fenêtre de niveau.
var last_growth := {}


## Ajoute de l'activité à un héros (« counts » : {"str": 3, "vit": 1, ...}). Ne sauvegarde pas.
func add_activity(hero: Dictionary, counts: Dictionary) -> void:
	if not hero.has("growth_log"):
		hero["growth_log"] = {}  # anciennes sauvegardes
	for stat in counts:
		if counts[stat] > 0:
			hero["growth_log"][stat] = hero["growth_log"].get(stat, 0) + counts[stat]


## La part de chaque stat dans l'activité du héros depuis son dernier niveau ({} s'il n'a rien fait).
func activity_shares(hero: Dictionary) -> Dictionary:
	var activity: Dictionary = hero.get("growth_log", {})
	var total := 0
	for stat in STAT_NAMES:
		total += activity.get(stat, 0)
	if total <= 0:
		return {}
	var shares := {}
	for stat in STAT_NAMES:
		shares[stat] = float(activity.get(stat, 0)) / total
	return shares


## « Force +2, Santé +1, Intelligence -1 » (ou "" si rien n'a changé).
func growth_text(changes: Dictionary) -> String:
	var parts := []
	for stat in STAT_NAMES:
		var gap: int = changes.get(stat, 0)
		if gap != 0:
			parts.append("%s %s%d" % [STAT_NAMES[stat], "+" if gap > 0 else "-", absi(gap)])
	return ", ".join(parts)


## Montée de niveau : le héros gagne autant de points que sa valeur de croissance, répartis selon son
## activité (« shares », voir activity_shares : au plus fort reste) ; une stat peu utilisée peut perdre 1 point.
## Sans activité : au hasard (la statistique de sa classe a plus de chances), et parfois l'une baisse
## pendant qu'une autre monte. Les changements s'ajoutent à last_growth.
func _level_up(hero: Dictionary, shares: Dictionary = {}) -> void:
	hero["level"] += 1
	var stats: Dictionary = hero["stats"]
	var before: Dictionary = stats.duplicate()
	if shares.is_empty():
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
	else:
		# Au plus fort reste : chaque stat reçoit sa part entière, les points restants vont aux plus grands restes.
		var points: int = hero["growth"]
		var given := 0
		var rests := []
		for stat in STAT_NAMES:
			var exact: float = shares[stat] * points
			stats[stat] += floori(exact)
			given += floori(exact)
			rests.append([exact - floori(exact), stat])
		rests.sort_custom(func(a, b): return a[0] > b[0])
		for i in points - given:
			stats[rests[i][1]] += 1
		# Une stat peu utilisée peut perdre un point, au profit de la plus utilisée.
		var unused := STAT_NAMES.keys().filter(func(stat): return shares[stat] < STAT_DECAY_SHARE and stats[stat] > 1)
		if not unused.is_empty() and randf() < STAT_DECAY_CHANCE:
			var top: String = STAT_NAMES.keys()[0]
			for stat in STAT_NAMES:
				if shares[stat] > shares[top]:
					top = stat
			stats[unused.pick_random()] -= 1
			stats[top] += 1
	for stat in STAT_NAMES:
		var gap: int = stats[stat] - before[stat]
		if gap != 0:
			last_growth[stat] = last_growth.get(stat, 0) + gap


# ---------------------------------------------------------------------------
# Changement de classe
# ---------------------------------------------------------------------------
# La voie du 1 étoile, « déchet à trésor » (cahier, onglet « Invocations et classes ») : tout le monde
# commence Novice, puis change de classe en plusieurs étapes, selon les compétences d'arme acquises.
# - Premier changement : un Novice au niveau FIRST_CLASS_CHANGE_LEVEL devient apprenti (guerrier ou
#   voleur) s'il a au moins une compétence d'arme de cette voie (CLASS_PATHS). S'il a les deux, le
#   Maître choisit ; s'il n'en a aucune, il reste Novice.
# - Deuxième changement : un apprenti au niveau SECOND_CLASS_CHANGE_LEVEL, avec une compétence d'arme de
#   sa voie au niveau SECOND_CLASS_CHANGE_SKILL_LEVEL, prend une des deux classes de sa voie (CLASS_FINALS),
#   au choix du Maître. Ses compétences de débutant évoluent (rang EVOLVED_SKILL_RANK, mêmes effets)
#   ou disparaissent (CLASS_LOST_SKILLS), comme Han qui perd Mouvement secret en devenant Guerrier.
# Les statistiques ne changent pas : la nouvelle classe change ce qui monte à chaque niveau
# (CLASS_MAIN_STAT) et les armes que le héros prend dans l'arsenal (CLASS_WEAPONS). Chiffres provisoires.

## Niveau du premier changement de classe (Novice → apprenti).
const FIRST_CLASS_CHANGE_LEVEL := 10

## Les voies du premier changement : la classe d'apprenti, et les compétences d'arme qui y mènent.
## L'« épée courte » du cahier n'existe pas dans le jeu (elle est comptée dans Maîtrise de l'épée) ;
## Maîtrise de la dague ne s'apprend pas encore.
const CLASS_PATHS := {
	"Apprenti guerrier": ["Maîtrise de l'épée", "Utilisation du bouclier"],
	"Apprenti voleur": ["Maîtrise de la dague", "Maîtrise de l'arc"],
}

## Deuxième changement : niveau, et niveau à atteindre dans une compétence d'arme de sa voie.
const SECOND_CLASS_CHANGE_LEVEL := 20
const SECOND_CLASS_CHANGE_SKILL_LEVEL := 5
## Les classes proposées à chaque apprenti au deuxième changement.
const CLASS_FINALS := {
	"Apprenti guerrier": ["Guerrier", "Chevalier"],
	"Apprenti voleur": ["Archer", "Assassin"],
}
## Compétences de débutant qui disparaissent en prenant cette classe (provisoire : le Mouvement souple
## d'un voleur ne va pas à un guerrier, comme le Mouvement secret de Han dans l'œuvre).
const CLASS_LOST_SKILLS := {
	"Guerrier": ["Mouvement souple"],
	"Chevalier": ["Mouvement souple"],
}
## Les autres compétences de débutant évoluent : elles passent à ce rang (leurs effets ne changent pas).
const EVOLVED_SKILL_RANK := "Intermédiaire"

## Classes réservées à l'invocation (cahier : « les mages ne s'obtiennent que par invocation ; la magie
## est un savoir ») : aucun changement de classe n'y mène, même si une voie les proposait un jour.
const INVOCATION_ONLY_CLASSES := ["Mage", "Soigneur"]


## Les compétences d'arme d'une voie que le héros possède au moins au niveau « min_level ».
func _path_skills(hero: Dictionary, path: String, min_level: int) -> Array:
	return CLASS_PATHS[path].filter(func(skill_name): return skill_level(hero["skills"], skill_name) >= min_level)


## Les classes que ce héros peut prendre maintenant (son prochain changement de classe), ou [].
func class_change_options(hero: Dictionary) -> Array[String]:
	var options: Array[String] = []
	if not hero["alive"]:
		return options
	if hero["class"] == "Novice" and hero["level"] >= FIRST_CLASS_CHANGE_LEVEL:
		for path in CLASS_PATHS:
			if not _path_skills(hero, path, 1).is_empty():
				options.append(path)
	elif hero["class"] in CLASS_FINALS and hero["level"] >= SECOND_CLASS_CHANGE_LEVEL:
		if not _path_skills(hero, hero["class"], SECOND_CLASS_CHANGE_SKILL_LEVEL).is_empty():
			options.assign(CLASS_FINALS[hero["class"]])
	for reserved in INVOCATION_ONLY_CLASSES:
		options.erase(reserved)
	return options


## Pourquoi ce héros, arrivé au niveau d'un changement de classe, ne peut pas en changer
## (texte pour sa fiche), ou "" (il peut, ou ce n'est pas encore le moment).
func class_change_problem(hero: Dictionary) -> String:
	if not hero["alive"]:
		return ""
	if hero["class"] == "Novice" and hero["level"] >= FIRST_CLASS_CHANGE_LEVEL:
		if class_change_options(hero).is_empty():
			return ("Niveau %d atteint, mais aucune compétence d'arme : reste Novice. Épée ou bouclier " \
				+ "(terrain d'entraînement) pour devenir Apprenti guerrier ; dague ou arc " \
				+ "(tirer à l'arc en combat) pour devenir Apprenti voleur.") % FIRST_CLASS_CHANGE_LEVEL
	if hero["class"] in CLASS_FINALS and hero["level"] >= SECOND_CLASS_CHANGE_LEVEL:
		if class_change_options(hero).is_empty():
			var levels := []
			for skill_name in CLASS_PATHS[hero["class"]]:
				levels.append("%s niv. %d" % [skill_name, skill_level(hero["skills"], skill_name)])
			return "Niveau %d atteint : pour devenir %s, il faut une de ces compétences au niveau %d (%s)." \
				% [SECOND_CLASS_CHANGE_LEVEL, " ou ".join(CLASS_FINALS[hero["class"]]),
				SECOND_CLASS_CHANGE_SKILL_LEVEL, ", ".join(levels)]
	if not class_change_options(hero).is_empty() and is_away(hero):
		return "Changement de classe possible au retour (%s)." % ("Tour" if in_tower(hero) else "donjon journalier")
	return ""


## Change la classe d'un héros (« new_class » doit être une de ses options).
## Renvoie les lignes à annoncer dans la fenêtre système, ou [] si c'est impossible.
func change_class(hero: Dictionary, new_class: String) -> Array[String]:
	var lines: Array[String] = []
	if new_class in INVOCATION_ONLY_CLASSES or not new_class in class_change_options(hero) or is_away(hero):
		return lines
	var old_class: String = hero["class"]
	hero["class"] = new_class
	lines.append("%s change de classe : %s → %s !" % [hero["name"], old_class, new_class])
	if old_class in CLASS_FINALS:
		lines.append_array(_class_change_skills(hero, new_class))
	save_game()
	return lines


## Deuxième changement : les compétences de débutant évoluent ou disparaissent. Renvoie les annonces.
func _class_change_skills(hero: Dictionary, new_class: String) -> Array[String]:
	var lines: Array[String] = []
	var skills: Array = hero["skills"]
	for i in range(skills.size() - 1, -1, -1):
		var skill: Dictionary = skills[i]
		if skill["rank"] != "Débutant":
			continue
		if skill["name"] in CLASS_LOST_SKILLS.get(new_class, []):
			skills.remove_at(i)
			hero.get("skill_progress", {}).erase(skill["name"])
			lines.append("%s disparaît : elle ne convient pas à un %s." % [skill["name"], new_class])
		else:
			skill["rank"] = EVOLVED_SKILL_RANK
			lines.append("%s évolue : rang %s." % [skill["name"], EVOLVED_SKILL_RANK])
	lines.reverse()  # (la liste a été parcourue à l'envers) dans l'ordre de la fiche
	return lines


# ---------------------------------------------------------------------------
# Équipes composées à l'avance
# ---------------------------------------------------------------------------

## Nombre maximum de héros dans une équipe de combat.
const TEAM_SIZE := 5

## Nombre d'équipes que le joueur peut composer à l'avance.
const TEAM_COUNT := 3


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


## Remplace toute une équipe (glisser-déposer de la composition) : « hero_ids » dans l'ordre voulu,
## TEAM_SIZE héros au plus.
func set_team(index: int, hero_ids: Array) -> void:
	teams[index] = hero_ids.slice(0, TEAM_SIZE)
	save_game()


## Le héros qui porte ce numéro (vide s'il n'existe pas).
func hero_by_id(hero_id: int) -> Dictionary:
	for hero in roster:
		if hero["id"] == hero_id:
			return hero
	return {}


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
# Héros vivants, et où ils sont
# ---------------------------------------------------------------------------

## Héros encore en vie (ceux qui peuvent combattre).
func alive_heroes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for hero in roster:
		if hero["alive"]:
			result.append(hero)
	return result


## Vrai si le héros est en train de combattre dans la Tour.
func in_tower(hero: Dictionary) -> bool:
	return not pending_battle.is_empty() and hero["id"] in pending_battle["team"]


## Vrai si le héros est parti de la cité (Tour ou donjon journalier) : il n'est ni au terrain
## d'entraînement ni à son poste, et ne peut pas partir ailleurs.
func is_away(hero: Dictionary) -> bool:
	return in_tower(hero) or on_expedition(hero)


## Vrai si le héros est parti récolter au donjon journalier.
func on_expedition(hero: Dictionary) -> bool:
	for expedition in expeditions:
		if hero["id"] in expedition["team"]:
			return true
	return false
