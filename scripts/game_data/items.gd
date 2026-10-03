class_name GameItems
extends GameTraining
## Les objets : armes (tirage, arsenal, équipement des héros) et matériaux de l'entrepôt.
## Fait partie de la pile de GameData (voir game_data.gd).


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
	# Apprentis (premier changement de classe), provisoire : les armes de leur famille (cahier :
	# guerriers « épée, lance… », voleurs « dague, arc… »).
	"Apprenti guerrier": ["Épée", "Lance", "Fouet"],
	"Apprenti voleur": ["Dague", "Arc", "Épée"],
}
const SHIELD_CLASSES := ["Novice", "Guerrier", "Chevalier", "Apprenti guerrier"]


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
	var was_unlocked := training_unlocked()
	weapon_draws += count
	if not was_unlocked and training_unlocked():
		_announce_training_ground()
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
# Entrepôt : matériaux
# ---------------------------------------------------------------------------
# Les matériaux s'accumulent dans l'entrepôt (warehouse : {nom: {grade: nombre}}) : ceux du donjon
# journalier, de la Tour, et les pierres d'attribut qui servent à la promotion.

const PROMOTION_STONE := "Pierre d'attribut"


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
