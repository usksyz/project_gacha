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
##   C'est la seule qui peut donner un mage, et elle a une garantie (4 et 5 étoiles, voir PITY5_LIMIT).
## « cost » : prix d'une invocation ; « currency » : "gold" ou "gems" ;
## « rates » : probabilité de chaque rareté, de la plus haute à la plus basse (le total fait 1.0,
## soit 100 %). Une rareté absente ne peut pas sortir. Taux provisoires.
## Invocation normale, demande du porteur du projet : des 1 étoile presque toujours, des 2 et 3 étoiles
## très très rares (avant : 3 étoiles 10 %, 2 étoiles 30 % ; puis 0,5 % et 2 %). Aucune garantie. Sa première
## x10 (tutoriel) est à part : voir _first_summon_rarities.
## Prompt 1 (économie, sur le modèle des gachas existants) : 3 étoiles 0,7 %, 2 étoiles 2,3 %, 1 étoile 97 %.
const SUMMON_TYPES := {
	"normal": {"name": "Invocation normale", "cost": 5000, "currency": "gold", "mages": false,
		"rates": {3: 0.007, 2: 0.023, 1: 0.97}},
	# Prompt 1 : prix du cahier (500 gemmes) et taux de base à la Genshin Impact (5★ 0,6 %), avec une garantie
	# progressive (voir « Garantie de l'invocation spéciale » plus bas). Avant : 100 gemmes, 4 % / 21 % / 75 %.
	"special": {"name": "Invocation spéciale", "cost": 500, "currency": "gems", "mages": true,
		"rates": {5: 0.006, 4: 0.051, 3: 0.943}},
}

## Mages : seulement par invocation spéciale, 0,5 % des tirages, tirés à part du rang (un mage peut être 3, 4 ou
## 5 étoiles). La garantie ne force jamais un mage. Provisoire. (Avant : 1 % des 3 étoiles et plus.)
const MAGE_CHANCE := 0.005

## Nombre maximum de héros vivants pour invoquer, choix du porteur du projet (les morts ne comptent pas ;
## les héros secrets comptent, mais s'obtiennent toujours par code, même plein). Chiffre provisoire : plus tard, il grandira
## avec le niveau des résidences (cahier : « la résidence a atteint le niv. 2, sa capacité d'accueil a augmenté »).
const HERO_LIMIT := 50

## Garantie de l'invocation spéciale (prompt 1, comme Genshin Impact ; remplace l'ancien pity de 50) :
## - 5 étoiles : à partir du tirage PITY5_SOFT_START sans 5 étoiles (74e), la chance monte de PITY5_SOFT_STEP
##   (6 points) par tirage ; au PITY5_LIMIT-ième (90e), il est sûr. Taux réel moyen : environ 1,6 % (un 5 étoiles
##   tous les 62 tirages environ) ;
## - 4 étoiles ou mieux : sûr au PITY4_LIMIT-ième tirage (10e) sans 4 ou 5 étoiles.
## Compteurs : pity_counter (tirages sans 5 étoiles) et pity4_counter (sans 4 étoiles ou mieux), sauvegardés,
## ils continuent d'une session à l'autre et d'une x1 à une x10. Chiffres provisoires.
const PITY5_LIMIT := 90
const PITY5_SOFT_START := 74
const PITY5_SOFT_STEP := 0.06
const PITY4_LIMIT := 10

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
## Les mages sont tirés à part (MAGE_CHANCE, invocation spéciale seulement) : ils ne sont plus dans ce tableau,
## dont les lignes sont remises à 100 % au tirage (class_rates). Chiffres provisoires, à régler.
const CLASS_RATES := {
	1: {"Novice": 1.0},
	2: {"Novice": 1.0},
	3: {"Guerrier": 0.30, "Chevalier": 0.20, "Archer": 0.20, "Assassin": 0.15, "Soigneur": 0.14},
	4: {"Guerrier": 0.27, "Chevalier": 0.22, "Archer": 0.20, "Assassin": 0.15, "Soigneur": 0.15},
	5: {"Guerrier": 0.25, "Chevalier": 0.22, "Archer": 0.20, "Assassin": 0.16, "Soigneur": 0.16},
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


## Première invocation du tutoriel (normale x10) : chance d'y trouver aussi un 2 étoiles.
const FIRST_SUMMON_TWO_STAR_CHANCE := 0.5


## Vrai si le tutoriel permet cette invocation : pendant son étape « invocation », seule la normale x10 ;
## pendant les étapes suivantes, aucune (l'onglet est fermé de toute façon).
func summon_allowed(summon_type: String, count: int) -> bool:
	if tutorial_step == "":
		return true
	return tutorial_step == "invocation" and summon_type == "normal" and count == TUTORIAL_SUMMON_COUNT


## Raretés de la première invocation (tutoriel), demande du porteur du projet : un 3 étoiles garanti,
## peut-être un 2 étoiles (FIRST_SUMMON_TWO_STAR_CHANCE), et que des 1 étoile pour le reste, mélangés.
func _first_summon_rarities(count: int) -> Array:
	var rarities := [3]
	if randf() < FIRST_SUMMON_TWO_STAR_CHANCE:
		rarities.append(2)
	while rarities.size() < count:
		rarities.append(1)
	rarities.shuffle()
	return rarities


## Invoque « count » héros (invocation « normal » ou « special ») et renvoie la liste des héros
## obtenus (liste vide si on n'a pas de quoi payer, ou si le tutoriel ne le permet pas).
func summon(summon_type: String, count: int) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if not can_afford(summon_type, count) or count > free_hero_slots() or not summon_allowed(summon_type, count):
		return results
	var forced: Array = _first_summon_rarities(count) if tutorial_step == "invocation" else []

	var info: Dictionary = SUMMON_TYPES[summon_type]
	if info["currency"] == "gold":
		gold -= info["cost"] * count
		gold_changed.emit(gold)
	else:
		gems -= info["cost"] * count
		gems_changed.emit(gems)
	for i in count:
		var rarity: int = forced[i] if not forced.is_empty() else _roll_rarity(summon_type)
		var hero := _create_hero(rarity, info["mages"])
		roster.append(hero)
		results.append(hero)
	roll_linked_group(results)  # certains se connaissent peut-être déjà (voir personality.gd)
	save_game()
	advance_tutorial("invocation")  # (tutoriel) étape suivante : composer une équipe
	complete_daily_mission("invocation")
	return results


## Invocation gratuite quotidienne (prompt 1, économie) : une invocation normale x1 offerte par jour réel (jour
## de l'appareil, comme le donjon journalier). Pas pendant le tutoriel ; elle respecte la limite de héros.
## free_summon_day : date (« 2026-10-17 ») de la dernière prise, sauvegardée.
func today_date() -> String:
	return Time.get_date_string_from_system()


func free_summon_available() -> bool:
	return tutorial_step == "" and free_summon_day != today_date()


## Fait l'invocation gratuite du jour. Renvoie le héros obtenu (une liste d'un héros), ou une liste vide si elle
## est déjà prise ou s'il n'y a plus de place dans les résidences.
func free_summon() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if not free_summon_available() or free_hero_slots() < 1:
		return results
	free_summon_day = today_date()
	var hero := _create_hero(_roll_rarity("normal"), SUMMON_TYPES["normal"]["mages"])
	roster.append(hero)
	results.append(hero)
	roll_linked_group(results)  # (un seul héros : jamais de groupe, mais l'annonce précédente est effacée)
	save_game()
	complete_daily_mission("invocation")
	return results


## Combien de tirages spéciaux il reste avant le 5 étoiles sûr (1 = le prochain).
func summons_before_pity() -> int:
	return PITY5_LIMIT - pity_counter


## Combien de tirages spéciaux il reste avant le 4 étoiles (ou mieux) sûr.
func summons_before_pity4() -> int:
	return PITY4_LIMIT - pity4_counter


## Chance d'un 5 étoiles au prochain tirage spécial, quand « done » tirages sans 5 étoiles sont déjà faits :
## le taux de base, puis +6 points par tirage à partir du 74e, et 100 % au 90e.
func five_star_chance(done: int) -> float:
	var pull := done + 1  # numéro du prochain tirage dans la série
	var base: float = SUMMON_TYPES["special"]["rates"][5]
	if pull >= PITY5_LIMIT:
		return 1.0
	if pull >= PITY5_SOFT_START:
		return minf(1.0, base + PITY5_SOFT_STEP * (pull - PITY5_SOFT_START + 1))
	return base


## Taux réel du 5 étoiles avec la garantie (calculé, environ 1,6 %) : 1 / nombre moyen de tirages par 5 étoiles.
func five_star_real_rate() -> float:
	var expected := 0.0     # nombre moyen de tirages pour un 5 étoiles
	var still_none := 1.0   # chance de ne pas l'avoir encore eu
	for done in PITY5_LIMIT:
		var chance := five_star_chance(done)
		expected += (done + 1) * still_none * chance
		still_none *= 1.0 - chance
	return 1.0 / expected


## Tire une rareté au hasard selon les taux de cette sorte d'invocation.
## Seule l'invocation spéciale a une garantie (voir PITY5_LIMIT, PITY4_LIMIT).
func _roll_rarity(summon_type: String) -> int:
	if summon_type == "special":
		return _roll_special_rarity()
	var rates: Dictionary = SUMMON_TYPES[summon_type]["rates"]
	var roll := randf()
	var cumulative := 0.0
	for rarity in rates:
		cumulative += rates[rarity]
		if roll < cumulative:
			return rarity
	return rates.keys().back()  # (arrondi des taux) la plus basse rareté de cette invocation


## Invocation spéciale : 5 étoiles (chance qui monte avec pity_counter), sinon 4 étoiles (taux de base, ou sûr
## au 10e tirage sans 4 étoiles ou mieux), sinon 3 étoiles. Met les deux compteurs à jour.
func _roll_special_rarity() -> int:
	var roll := randf()
	var rarity := 3
	if roll < five_star_chance(pity_counter):
		rarity = 5
	elif pity4_counter + 1 >= PITY4_LIMIT or roll < five_star_chance(pity_counter) + SUMMON_TYPES["special"]["rates"][4]:
		rarity = 4
	pity_counter = 0 if rarity == 5 else pity_counter + 1
	pity4_counter = 0 if rarity >= 4 else pity4_counter + 1  # un 5 étoiles compte comme « 4 étoiles ou mieux »
	return rarity


## Chances de chaque classe pour une rareté (voir CLASS_RATES), remises à 100 %. Les mages sont à part
## (MAGE_CHANCE) : « allow_mage » ne sert qu'à l'affichage du détail des taux (mages en plus).
func class_rates(rarity: int, allow_mage := false) -> Dictionary:
	var rates: Dictionary = CLASS_RATES[rarity].duplicate()
	var total := 0.0
	for hero_class in rates:
		total += rates[hero_class]
	var share := 1.0 - (MAGE_CHANCE if allow_mage else 0.0)
	for hero_class in rates:
		rates[hero_class] = rates[hero_class] / total * share
	if allow_mage:
		rates["Mage"] = MAGE_CHANCE
	return rates


## Tire la classe d'un héros selon sa rareté. « allow_mage » (invocation spéciale) : d'abord MAGE_CHANCE d'être
## un mage, quel que soit le rang ; sinon la classe selon CLASS_RATES.
func _roll_class(rarity: int, allow_mage: bool) -> String:
	if allow_mage and randf() < MAGE_CHANCE:
		return "Mage"
	var rates := class_rates(rarity)
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
		template["skills"].duplicate(true), true)
	# Stats et élément du manhwa, quand on les connaît (sinon : tirés comme pour les autres héros).
	if template.has("stats"):
		hero["stats"] = template["stats"].duplicate()
	if template.has("element"):
		hero["element"] = template["element"]
	elif template["class"] == "Mage":
		hero["element"] = MAGIC_ELEMENTS.pick_random()
	hero["secret"] = true  # (mortel comme les autres : l'immortalité n'existe qu'en mode dev, voir is_immortal)
	return hero


## « secret » : héros secret (sa personnalité est son profil écrit à la main, voir PersonalityData.SECRET_PROFILES).
func _new_hero(hero_name: String, rarity: int, hero_class: String, growth: int, skills: Array, secret := false) -> Dictionary:
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
		"immortal": false,     # case « Immortel » du mode dev (voir is_immortal)
		"secret": false,
		"favorite": false,     # mis en favori par le Maître (voir FAVORITES_MAX)
		"mental": MENTAL_MAX,  # santé mentale (voir personality.gd)
		# Personnalité v2 (18 axes, couches, talent, effort, métier : voir PersonalityEngine). Tirée en la
		# comparant aux héros déjà là, pour que le nouveau ne leur ressemble pas ; un héros secret prend son
		# profil écrit à la main. Ses traits (Courageux, Loyal...) se lisent sur ses paliers (has_trait).
		"persona": PersonalityEngine.new_persona(hero_name, rarity, roster, secret),
		"revealed_traits": [],  # traits que le Maître a découverts (cachés au début)
	}
	next_hero_id += 1
	start_arrival(hero, secret)  # (octobre 2026) motivation cachée, arrivée déboussolée (personality.gd)
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


## Vrai si ce héros secret est déjà venu dans la cité, vivant ou tombé (la mort est définitive :
## un héros secret tombé ne revient pas par son code).
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
