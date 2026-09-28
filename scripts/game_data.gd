extends Node
## Données et règles du jeu.
## Ce script est chargé automatiquement au lancement (« autoload ») :
## n'importe quel autre script peut y accéder en écrivant GameData.
##
## Les règles suivent le cahier des charges (document « Feuille de route »).

signal gems_changed(new_amount: int)
signal gold_changed(new_amount: int)

# ---------------------------------------------------------------------------
# Invocation
# ---------------------------------------------------------------------------

## Prix d'une invocation, en gemmes.
const SUMMON_COST := 100

## Pity : un héros 5 étoiles est garanti au bout de ce nombre d'invocations sans 5 étoiles.
const PITY_LIMIT := 50

## Probabilité d'obtenir chaque rareté (le total fait 1.0, soit 100 %).
const RARITY_RATES := {
	5: 0.02,
	4: 0.08,
	3: 0.20,
	2: 0.30,
	1: 0.40,
}

## Couleur associée à chaque rareté.
const RARITY_COLORS := {
	5: Color("f5b82e"),
	4: Color("a35ce0"),
	3: Color("3d8fe0"),
	2: Color("4caf6a"),
	1: Color("8a8f98"),
}

## Chance qu'un héros de 3 étoiles ou plus soit un Mage (0.05 = 5 %).
## Les mages ne s'obtiennent que par invocation, et très rarement.
const MAGE_CHANCE := 0.05

## Classes possibles pour un héros de 3 étoiles ou plus (hors Mage).
## Les 1 et 2 étoiles commencent tous « Novice ».
const HIGH_CLASSES := ["Guerrier", "Chevalier", "Archer", "Assassin", "Soigneur"]

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
## « code » : le code secret à taper sur la Place publique pour l'obtenir
## (vide = le héros est donné dès le début de la partie).
## Les étoiles et classes marquées « à confirmer » sont à ajuster selon le manhwa.
const SECRET_HEROES := {
	# Han : 1 étoile en apparence, mais une croissance de 3 étoiles.
	# Plus tard, il obtiendra à la fois Calme et Berserk, normalement incompatibles.
	"Han": {"rarity": 1, "class": "Novice", "growth": 5, "code": "", "skills": []},
	"Hansen": {"rarity": 1, "class": "Novice", "growth": 2, "code": "HANSEN", "skills": []},
	"Zid": {"rarity": 1, "class": "Novice", "growth": 2, "code": "ZID", "skills": []},  # à confirmer
	"Shei": {"rarity": 4, "class": "Novice", "growth": 6, "code": "SHEI", "skills": []},  # classe à confirmer
	"Jenna": {"rarity": 1, "class": "Archer", "growth": 2, "code": "JENNA",  # étoiles à confirmer
		"skills": [{"name": "Maîtrise de l'arc", "rank": "Débutant", "level": 1}]},
	"Aaron": {"rarity": 1, "class": "Novice", "growth": 2, "code": "AARON", "skills": []},  # à confirmer
}

# ---------------------------------------------------------------------------
# La Tour
# ---------------------------------------------------------------------------

## Nombre maximum de héros dans une équipe de combat.
const TEAM_SIZE := 5

## Un boss garde tous les étages multiples de ce nombre (5, 10, 15...).
const BOSS_EVERY := 5

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
	{"name": "Sorcier gobelin", "class": "Mage", "str": 3, "int": 11, "vit": 5, "dex": 8},
]

## Boss qui gardent les étages multiples de BOSS_EVERY.
const BOSS_TYPES := [
	{"name": "Chef gobelin", "class": "Guerrier", "str": 16, "int": 4, "vit": 26, "dex": 10},
	{"name": "Minotaure", "class": "Guerrier", "str": 18, "int": 4, "vit": 30, "dex": 9},
	{"name": "Liche", "class": "Mage", "str": 4, "int": 18, "vit": 24, "dex": 10},
	{"name": "Hydre", "class": "Chevalier", "str": 14, "int": 4, "vit": 40, "dex": 6},
]

# ---------------------------------------------------------------------------
# État de la partie
# ---------------------------------------------------------------------------

var gems := 3000
var gold := 0
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


func _ready() -> void:
	reset_game()


## Remet la partie à zéro (au lancement, et depuis les paramètres : « Recommencer la partie »).
func reset_game() -> void:
	gems = 3000
	gold = 0
	pity_counter = 0
	tower_floor = 1
	roster.clear()
	next_hero_id = 1
	used_codes.clear()
	# Han est là dès le début de la partie.
	roster.append(_create_secret_hero("Han"))


# ---------------------------------------------------------------------------
# Monnaies
# ---------------------------------------------------------------------------

func add_gems(amount: int) -> void:
	gems += amount
	gems_changed.emit(gems)


func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)


# ---------------------------------------------------------------------------
# Invocation
# ---------------------------------------------------------------------------

func can_afford(count: int) -> bool:
	return gems >= SUMMON_COST * count


## Invoque « count » héros et renvoie la liste des héros obtenus
## (liste vide si on n'a pas assez de gemmes).
func summon(count: int) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if not can_afford(count):
		return results

	gems -= SUMMON_COST * count
	for i in count:
		var hero := _create_hero(_roll_rarity())
		roster.append(hero)
		results.append(hero)
	gems_changed.emit(gems)
	return results


func summons_before_pity() -> int:
	return PITY_LIMIT - pity_counter


## Tire une rareté au hasard selon RARITY_RATES, en tenant compte du pity.
func _roll_rarity() -> int:
	pity_counter += 1
	if pity_counter >= PITY_LIMIT:
		pity_counter = 0
		return 5

	var roll := randf()
	var cumulative := 0.0
	for rarity in RARITY_RATES:
		cumulative += RARITY_RATES[rarity]
		if roll < cumulative:
			if rarity == 5:
				pity_counter = 0
			return rarity
	return 1


## Crée un nouveau héros ordinaire de la rareté donnée.
func _create_hero(rarity: int) -> Dictionary:
	var hero_class := "Novice"
	if rarity >= 3:
		hero_class = "Mage" if randf() < MAGE_CHANCE else HIGH_CLASSES.pick_random()

	var growth: int = GROWTH[rarity]
	if rarity == 1 and randf() < HIDDEN_TALENT_CHANCE:
		growth += 3  # talent caché : croissance digne d'un 3 étoiles

	return _new_hero(HERO_NAMES.pick_random(), rarity, hero_class, growth, [])


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
		"alive": true,
		"immortal": false,
		"secret": false,
	}
	next_hero_id += 1
	return hero


## Statistiques de départ : la base de la rareté, un peu de hasard (±1),
## et +3 dans la statistique favorisée par la classe.
func _roll_stats(rarity: int, hero_class: String) -> Dictionary:
	var stats := {}
	for stat in STAT_NAMES:
		stats[stat] = BASE_STAT[rarity] + randi_range(-1, 1)
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
			used_codes.append(code)
			var hero := _create_secret_hero(hero_name)
			roster.append(hero)
			return hero
	return {}


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

## Transforme les 4 statistiques (d'un héros ou d'un ennemi) en valeurs de combat :
## points de vie, attaque, défense, vitesse, chance de coup critique.
func combat_stats(unit: Dictionary) -> Dictionary:
	var stats: Dictionary = unit["stats"]
	var magic: bool = unit["class"] in ["Mage", "Soigneur"]
	return {
		"hp": stats["vit"] * 8,
		"atk": stats["int"] if magic else stats["str"],
		"def": roundi(stats["vit"] / 2.0),
		"spd": stats["dex"],
		"crit": stats["dex"] / 200.0,
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
func floor_enemy_level(floor_number: int) -> int:
	return floor_number + 2


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


## Crée les ennemis d'un étage : de plus en plus nombreux (6 au maximum), de plus en plus
## forts, et de nouveaux monstres apparaissent en montant. Sur un étage de boss,
## le boss prend la place de 2 monstres (il en reste toujours au moins 2 pour l'escorter).
func tower_enemies(floor_number: int) -> Array[Dictionary]:
	var level := floor_enemy_level(floor_number)
	var enemies: Array[Dictionary] = []
	var monster_count := mini(2 + floor_number / 2, 6)
	if is_boss_floor(floor_number):
		var boss_index := mini(floor_number / BOSS_EVERY - 1, BOSS_TYPES.size() - 1)
		enemies.append(_create_enemy(BOSS_TYPES[boss_index], level + 2))
		monster_count = maxi(2, monster_count - 2)
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
	return {"name": template["name"], "class": template["class"], "level": level, "stats": stats}


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


## Applique le résultat d'un combat de la Tour et renvoie un rapport pour l'écran de fin :
## - les héros tombés meurent pour toujours (sauf les immortels) ;
## - en cas de victoire : or, gemmes, expérience pour les survivants, étage suivant ;
## - en cas de défaite : les survivants gagnent quand même la moitié de l'expérience
##   (sinon une équipe bloquée ne pourrait plus jamais progresser).
func finish_tower_battle(battle: Battle) -> Dictionary:
	var report := {
		"victory": battle.victory,
		"gold": 0,
		"gems": 0,
		"xp": 0,
		"dead": [],       # [{"hero": ..., "cause": ...}]
		"level_ups": [],  # [{"hero": ..., "levels": ...}]
		"mvp": battle.mvp(),
	}
	for fighter in battle.heroes:
		if fighter["hp"] <= 0 and not fighter["immortal"]:
			fighter["source"]["alive"] = false
			report["dead"].append({"hero": fighter["source"], "cause": fighter["killer"]})

	var rewards := tower_rewards(tower_floor)
	if battle.victory:
		report.merge(rewards, true)
		tower_floor += 1
		add_gold(rewards["gold"])
		add_gems(rewards["gems"])
	else:
		report["xp"] = rewards["xp"] / 2

	for fighter in battle.heroes:
		var hero: Dictionary = fighter["source"]
		if hero["alive"]:
			var levels := gain_xp(hero, report["xp"])
			if levels > 0:
				report["level_ups"].append({"hero": hero, "levels": levels})
	return report
