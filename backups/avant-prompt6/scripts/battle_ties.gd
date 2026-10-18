class_name BattleTies
extends RefCounted
## Les liens et le caractère en combat (étape E, point 4 ; demande du porteur du projet : « joue en équipe ou se
## sépare, utilise les alliés en tant qu'appât ou les protège, les jette pour occuper l'ennemi et se replier » ; ajout du
## projet, chiffres dans GameData, tower.gd, « point 4 »).
##
## - Protéger un ami : sans le trait Protecteur, un héros qui n'est pas sans cœur va couvrir un ami ou un frère d'armes
##   en danger et prend une part de ses coups (un Martyr, plus) ; leur lien se renforce après le combat.
## - L'appât : un opportuniste contourne le monstre qui s'acharne sur un allié et le prend à revers (frapper à revers
##   est plus fort pour tout le monde, voir rear_factor) ; l'allié s'en souvient.
## - Abandonner : un égoïste lâche, en danger, pousse un allié vers le monstre et se replie ; ils deviennent hostiles.
## Ce qui s'est passé est noté dans « events » ; GameData.ties_after_battle (tower.gd) l'applique aux liens et aux
## opinions après le combat. Aucun tirage au hasard. Rien en duel.

var battle  # Battle (pas de type : les deux classes se connaissent)
## Le caractère de chaque héros (lu une fois par combat) : {numéro: {"martyr", "opportunist", "abandoner", "guard"}}.
var traits := {}
## Ce qui s'est passé : [{"kind": "couvert" | "appat" | "abandon", "a": numéro, "b": numéro}] (a : celui qui agit).
var events: Array[Dictionary] = []
## Combien de fois chaque chose est arrivée (mesures) : couvert, appat, abandon, revers.
var counts := {"couvert": 0, "appat": 0, "abandon": 0, "revers": 0}
var _noted := {}  # (une seule ligne de journal par paire et par sorte)


func _init(owner) -> void:
	battle = owner


func setup() -> void:
	for hero in battle.heroes:
		if not hero["person"]:
			continue
		var source: Dictionary = hero["source"]
		var accesses: Array = PersonalityEngine.accesses(source)
		var predator: bool = "predateur" in accesses
		var empathy: int = PersonalityEngine.axis(source, "EMP")
		traits[hero["id"]] = {
			"martyr": "martyr" in accesses,
			"opportunist": predator or (PersonalityEngine.axis(source, "HON") <= -GameData.OPPORTUNIST_HON \
				and empathy <= -GameData.OPPORTUNIST_EMP),
			"abandoner": predator or (empathy <= -GameData.ABANDON_EMP \
				and PersonalityEngine.composite(source, "courage") <= -GameData.ABANDON_COURAGE),
			"guard": empathy >= GameData.FRIEND_GUARD_EMP,
		}


func _has(hero: Dictionary, what: String) -> bool:
	return not battle.quest.get("duel", false) and traits.get(hero["id"], {}).get(what, false)


# ---------------------------------------------------------------------------
# Protéger un ami
# ---------------------------------------------------------------------------

## Le Protecteur (trait) couvre n'importe quel allié en danger ; les autres, seulement un ami ou un frère d'armes (et s'ils
## ne sont pas sans cœur). Renvoie l'allié à couvrir, ou {}.
func ward_of(guardian: Dictionary) -> Dictionary:
	if GameData.has_trait(guardian["source"], "Protecteur"):
		return battle._ward_of(guardian)
	if not _has(guardian, "guard") or battle.afraid(guardian) or battle.panicking(guardian):
		return {}
	var result: Dictionary = {}
	var best: float = GameData.PROTECT_RANGE
	for ally_id in guardian["bonds"]:
		var ally: Dictionary = battle.units[ally_id]
		if guardian["bonds"][ally_id] < GameData.BOND_FRIEND or ally["hp"] <= 0 or not ally["present"]:
			continue
		if float(ally["hp"]) / ally["max_hp"] >= GameData.PROTECT_HP:
			continue
		var distance: float = guardian["pos"].distance_to(ally["pos"])
		if distance < best:
			best = distance
			result = ally
	return result


## Couvre-t-il cette cible (un ami en danger tout près) ? (Le trait Protecteur, lui, est vu par Battle._guardian_for.)
func guards(guardian: Dictionary, target: Dictionary) -> bool:
	return guardian["id"] != target["id"] and _has(guardian, "guard") and not battle.panicking(guardian) \
		and guardian["bonds"].get(target["id"], 0) >= GameData.BOND_FRIEND \
		and guardian["pos"].distance_to(target["pos"]) <= GameData.PROTECT_GUARD_RANGE


## La part des coups qu'il encaisse à la place de l'autre (un Martyr : plus).
func share_of(guardian: Dictionary) -> float:
	return GameData.MARTYR_SHARE if _has(guardian, "martyr") else GameData.PROTECT_SHARE


## Il vient de couvrir « ward » (voir Battle._cover) : noté pour les liens, et une ligne de journal la première fois.
func covered(guardian: Dictionary, ward: Dictionary) -> void:
	if _note("couvert", guardian, ward) and not GameData.has_trait(guardian["source"], "Protecteur"):
		var text := "%s se jette devant %s : il ne laissera pas tomber son ami !" % [guardian["name"], ward["name"]]
		if _has(guardian, "martyr"):
			text = "%s couvre %s de son corps, quoi qu'il lui en coûte !" % [guardian["name"], ward["name"]]
		battle._log(text, "awaken")


# ---------------------------------------------------------------------------
# À revers, l'appât
# ---------------------------------------------------------------------------

## Frapper à revers : un monstre occupé par un autre héros (sa cible), frappé de l'autre côté. Renvoie le multiplicateur.
func rear_factor(attacker: Dictionary, target: Dictionary) -> float:
	if not attacker["is_hero"] or target["is_hero"] or battle.quest.get("duel", false):
		return 1.0
	var victim := _victim_of(target)
	if victim.is_empty() or victim["id"] == attacker["id"]:
		return 1.0
	var from_me: Vector2 = (attacker["pos"] - target["pos"]).normalized()
	var from_victim: Vector2 = (victim["pos"] - target["pos"]).normalized()
	if from_me.dot(from_victim) > GameData.REAR_ANGLE_DOT:
		return 1.0
	counts["revers"] += 1
	if _has(attacker, "opportunist") and _note("appat", attacker, victim):
		battle._log("%s se sert de %s comme appât et prend %s à revers." % [attacker["name"], victim["name"], target["name"]], "disobey")
	return GameData.REAR_ATTACK_BONUS


## L'opportuniste : un monstre connu s'acharne sur un allié au contact ? Il le contourne pour le frapper dans le dos.
## Renvoie vrai s'il s'en occupe (sinon l'IA tactique décide).
func flank(hero: Dictionary, known: Array, foes: Array) -> bool:
	if not _has(hero, "opportunist") or hero["ranged"] or battle.afraid(hero) or not hero["order"].is_empty():
		return false
	# (pris lui-même pour cible au contact : il se bat d'abord pour sa peau)
	for foe in known:
		if foe.get("target_id", -1) == hero["id"] and hero["pos"].distance_to(foe["pos"]) <= GameData.STAMINA_CONTACT_RANGE:
			return false
	var best: Dictionary = {}
	var best_distance := 6.0
	for foe in known:
		var victim := _victim_of(foe)
		if victim.is_empty() or victim["id"] == hero["id"] or victim["pos"].distance_to(foe["pos"]) > 1.6:
			continue
		var distance: float = hero["pos"].distance_to(foe["pos"])
		if distance < best_distance:
			best_distance = distance
			best = foe
	if best.is_empty():
		return false
	var victim := _victim_of(best)
	var behind: Vector2 = best["pos"] + (best["pos"] - victim["pos"]).normalized() * 0.95
	hero["target_id"] = best["id"]
	if rear_factor_preview(hero, best, victim) and battle._in_reach(hero, best, hero["reach"]):
		battle._try_attack(hero, best, foes)
	elif battle.map.walkable(battle.map.cell_of(behind)):
		battle._move_towards(hero, behind)
	else:
		return false
	return true


## Est-il déjà dans le dos du monstre (par rapport à l'allié qui l'occupe) ?
func rear_factor_preview(hero: Dictionary, foe: Dictionary, victim: Dictionary) -> bool:
	return (hero["pos"] - foe["pos"]).normalized().dot((victim["pos"] - foe["pos"]).normalized()) <= GameData.REAR_ANGLE_DOT


## Le héros sur lequel s'acharne ce monstre (sa cible, debout), ou {}.
func _victim_of(monster: Dictionary) -> Dictionary:
	var target_id: int = monster.get("target_id", -1)
	if target_id < 0 or target_id >= battle.units.size():
		return {}
	var victim: Dictionary = battle.units[target_id]
	if not victim["is_hero"] or victim["hp"] <= 0 or not victim["present"]:
		return {}
	return victim


# ---------------------------------------------------------------------------
# Abandonner un allié
# ---------------------------------------------------------------------------

## Un égoïste lâche en danger pousse un allié vers le monstre et se replie (une fois par combat). Pendant le repli, il
## court vers l'arrière. Renvoie vrai tant qu'il se replie.
func abandon(hero: Dictionary, foes: Array) -> bool:
	if hero["abandon_until"] > battle.time:
		var back := Vector2(hero["pos"].x, battle.GRID_H - 1.5)
		battle._move_towards(hero, back)
		return true
	if hero["abandoned"] or not _has(hero, "abandoner") or not hero["order"].is_empty():
		return false
	if float(hero["hp"]) / hero["max_hp"] >= GameData.ABANDON_HP:
		return false
	var monster: Dictionary = {}
	for foe in foes:
		if hero["pos"].distance_to(foe["pos"]) <= GameData.STAMINA_CONTACT_RANGE:
			monster = foe
			break
	if monster.is_empty():
		return false
	var ally: Dictionary = {}
	for other in battle._alive(battle.heroes):
		if other["id"] != hero["id"] and hero["pos"].distance_to(other["pos"]) <= 1.6:
			ally = other
			break
	if ally.is_empty():
		return false
	hero["abandoned"] = true
	hero["abandon_until"] = battle.time + GameData.ABANDON_SECONDS
	# Il le pousse vers le monstre (si la case le permet), et le monstre s'en prend à lui.
	var shove: Vector2 = ally["pos"] + (monster["pos"] - ally["pos"]).normalized() * 0.6
	if battle.map.walkable(battle.map.cell_of(shove)) and absi(battle.map.height_at(battle.map.cell_of(shove)) - battle.height_of(ally)) == 0:
		ally["pos"] = shove
	monster["target_id"] = ally["id"]
	battle._stress(ally, GameData.ABANDON_MENTAL, "hostile")
	events.append({"kind": "abandon", "a": hero["id"], "b": ally["id"]})
	counts["abandon"] += 1
	battle._log("%s pousse %s vers %s et se replie pour sauver sa peau !" % [hero["name"], ally["name"], monster["name"]], "disobey")
	battle._alert("Abandon", ["%s a abandonné %s face à %s." % [hero["name"], ally["name"], monster["name"]]], true)
	return true


## Note une chose arrivée entre deux héros (une fois par paire et par sorte). Renvoie vrai la première fois.
func _note(kind: String, a: Dictionary, b: Dictionary) -> bool:
	var key := "%s:%d:%d" % [kind, a["id"], b["id"]]
	if _noted.has(key):
		return false
	_noted[key] = true
	events.append({"kind": kind, "a": a["id"], "b": b["id"]})
	counts[kind] += 1
	return true
