class_name GameSummon
extends GameItems
## L'invocation de héros (taux, pity, création d'un héros) et les codes secrets (héros secrets).
## Fait partie de la pile de GameData (voir game_data.gd).


# ---------------------------------------------------------------------------
# Invocation
# ---------------------------------------------------------------------------

## Deux sortes d'invocation, comme dans l'œuvre (choix du porteur du projet, aligné sur l'œuvre :
## « invocation gratuite : 1 à 3 étoiles ; invocation payante : 3 à 5 étoiles ») :
## - « normal » : héros de base, payée en or, la monnaie gagnée en jouant. C'est l'invocation
##   « gratuite » du cahier (sans argent réel) : de 1 à 3 étoiles ;
## - « special » : héros spéciaux, payée en gemmes : de 3 à 5 étoiles.
##   C'est la seule qui peut donner un mage, et elle a un pity (5 étoiles garanti).
## « cost » : prix d'une invocation ; « currency » : "gold" ou "gems" ;
## « rates » : probabilité de chaque rareté, de la plus haute à la plus basse (le total fait 1.0,
## soit 100 %). Une rareté absente ne peut pas sortir. Taux provisoires.
const SUMMON_TYPES := {
	"normal": {"name": "Invocation normale", "cost": 5000, "currency": "gold", "mages": false,
		"rates": {3: 0.10, 2: 0.30, 1: 0.60}},
	"special": {"name": "Invocation spéciale", "cost": 100, "currency": "gems", "mages": true,
		"rates": {5: 0.04, 4: 0.21, 3: 0.75}},
}

## Nombre maximum de héros vivants pour invoquer, choix du porteur du projet (les morts ne comptent pas ;
## les héros secrets comptent, mais s'obtiennent toujours par code, même plein). Chiffre provisoire : plus tard, il grandira
## avec le niveau des résidences (cahier : « la résidence a atteint le niv. 2, sa capacité d'accueil a augmenté »).
const HERO_LIMIT := 50

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
## 1 % des 3 étoiles et plus. Comme toutes les invocations spéciales donnent un 3 étoiles ou plus,
## 1 % des invocations spéciales donnent un mage (à peu près 1 toutes les 100).
## Dans l'invocation normale (ses 3 étoiles), la part des mages est simplement retirée du tirage.
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


## Vrai si on peut payer « count » invocations de cette sorte (« normal » ou « special »).
func can_afford(summon_type: String, count: int) -> bool:
	var info: Dictionary = SUMMON_TYPES[summon_type]
	var money := gold if info["currency"] == "gold" else gems
	return money >= info["cost"] * count


## Places libres dans les résidences : combien de héros on peut encore invoquer (voir HERO_LIMIT).
func free_hero_slots() -> int:
	return maxi(0, HERO_LIMIT - alive_heroes().size())


## Invoque « count » héros (invocation « normal » ou « special ») et renvoie la liste des héros
## obtenus (liste vide si on n'a pas de quoi payer).
func summon(summon_type: String, count: int) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if not can_afford(summon_type, count) or count > free_hero_slots():
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
	return rates.keys().back()  # (arrondi des taux) la plus basse rareté de cette invocation


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
	# Stats et élément du manhwa, quand on les connaît (sinon : tirés comme pour les autres héros).
	if template.has("stats"):
		hero["stats"] = template["stats"].duplicate()
	if template.has("element"):
		hero["element"] = template["element"]
	elif template["class"] == "Mage":
		hero["element"] = MAGIC_ELEMENTS.pick_random()
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
		"mental": MENTAL_MAX,  # santé mentale (voir personality.gd)
		"traits": roll_traits(),  # traits de caractère, cachés au début
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
			if owns_secret_hero(hero_name):
				return {}
			used_codes.append(code)
			var hero := _create_secret_hero(hero_name)
			roster.append(hero)
			save_game()
			return hero
	return {}


## Code du menu des héros secrets : il ouvre une fenêtre où l'on choisit, fiches à l'appui,
## le ou les héros secrets à faire venir (ceux qu'on n'a pas encore). Il peut servir plusieurs fois.
const SECRET_MENU_CODE := "SECRET_HERO"


## Vrai si ce héros secret est déjà dans la cité (vivant ou non : il est immortel).
func owns_secret_hero(hero_name: String) -> bool:
	return roster.any(func(hero): return hero.get("secret", false) and hero["name"] == hero_name)


## Fiches des héros secrets pour le menu : un héros « prêt à venir » par nom (sans numéro, pas encore
## dans la cité). C'est exactement lui qui viendra si on le choisit (mêmes stats).
func secret_hero_previews() -> Array[Dictionary]:
	var previews: Array[Dictionary] = []
	for hero_name in SECRET_HEROES:
		var id_before := next_hero_id
		var hero := _create_secret_hero(hero_name)
		next_hero_id = id_before  # une fiche à montrer, pas encore un vrai héros
		hero["id"] = 0
		previews.append(hero)
	return previews


## Fait venir un héros secret montré dans le menu. Renvoie le héros, ou {} s'il est déjà là.
func recruit_secret_hero(preview: Dictionary) -> Dictionary:
	if owns_secret_hero(preview["name"]):
		return {}
	var hero := preview.duplicate(true)
	hero["id"] = next_hero_id
	next_hero_id += 1
	roster.append(hero)
	# Son propre code ne servira plus (il est déjà là).
	var code: String = SECRET_HEROES[hero["name"]]["code"]
	if code != "" and not code in used_codes:
		used_codes.append(code)
	save_game()
	return hero
