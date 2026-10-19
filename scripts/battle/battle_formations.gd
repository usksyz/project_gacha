class_name BattleFormations
extends BattleJournal
## Combat (voir battle.gd) : formations (trois portées, mur de boucliers, lancier), Protecteur, liens, rotation et Meneur.


## La rotation : « tired » part à ROTATION_REAR_DISTANCE cases derrière lui et s'y repose ; l'allié le plus
## frais (au moins ROTATION_FRESH_STAMINA d'endurance, de préférence au corps à corps) prend sa place.
## Pendant ROTATION_VULNERABLE_SECONDS, les deux ne frappent pas et encaissent plus (voir _damage).
## Renvoie l'allié qui prend le poste ({} si personne n'est assez frais : il part quand même).
func _rotate(tired: Dictionary) -> Dictionary:
	var spot: Vector2 = tired["pos"]
	var relief := _find_relief(tired)
	var rear := _free_cell_near(_cell_of(Vector2(spot.x, minf(GRID_H - 2.5, spot.y + GameData.ROTATION_REAR_DISTANCE))))
	if map_data.has("enemy_anchor"):  # (scène : l'arrière, c'est à l'opposé du camp ennemi)
		var away: Vector2 = (spot - BattleMap.center(map_data["enemy_anchor"])).normalized()
		rear = _free_cell_near(_cell_of(spot + away * GameData.ROTATION_REAR_DISTANCE))
	tired["order"] = {"kind": "move", "pos": rear}
	tired["path"] = PackedVector2Array()
	tired["resting"] = true
	tired["swap_until"] = time + GameData.ROTATION_VULNERABLE_SECONDS
	if relief.is_empty():
		_log("%s se replie pour reprendre son souffle, mais personne n'est assez frais pour le relever." % tired["name"])
		return relief
	relief["order"] = {"kind": "move", "pos": spot}
	relief["path"] = PackedVector2Array()
	relief["swap_until"] = time + GameData.ROTATION_VULNERABLE_SECONDS
	_log("%s se replie pour reprendre son souffle ; %s prend son poste." % [tired["name"], relief["name"]])
	return relief


## L'allié le plus apte à relever « tired » (assez frais, ni au repos, ni effrayé, ni en panique), ou {}.
func _find_relief(tired: Dictionary) -> Dictionary:
	var relief: Dictionary = {}
	var best := -INF
	for ally in _alive(heroes):
		if ally["id"] == tired["id"] or ally["resting"] or panicking(ally) or afraid(ally) \
				or ally["stamina"] < ally["max_stamina"] * GameData.ROTATION_FRESH_STAMINA:
			continue
		# Le plus frais et le plus proche ; un combattant au corps à corps passe avant un tireur.
		var score: float = ally["stamina"] - ally["pos"].distance_to(tired["pos"]) * 3.0 - (50.0 if ally["ranged"] else 0.0)
		if score > best:
			best = score
			relief = ally
	return relief


## Meneur : un allié au contact d'un ennemi et à bout de souffle (sous LEADER_TIRED_STAMINA de son endurance) ?
## Le Meneur fait tourner la première ligne lui-même (fenêtre au Maître), au plus toutes les LEADER_COOLDOWN s.
func _lead(leader: Dictionary) -> void:
	if time < leader["lead_ready"] or panicking(leader) or afraid(leader):
		return
	for ally in _alive(heroes):
		if not can_swap(ally) or not ally["order"].is_empty() \
				or ally["stamina"] > ally["max_stamina"] * GameData.LEADER_TIRED_STAMINA:
			continue
		if not _alive(enemies).any(func(foe): return ally["pos"].distance_to(foe["pos"]) <= GameData.STAMINA_CONTACT_RANGE):
			continue
		if _find_relief(ally).is_empty():
			continue  # personne d'assez frais pour le relever
		_rotate(ally)
		leader["lead_ready"] = time + GameData.LEADER_COOLDOWN
		_reveal(leader, "Meneur")
		_alert("Rotation", ["%s fait tourner la première ligne." % _name_with_stars(leader)])
		return


func _organize_defense() -> void:
	var leader: Dictionary = {}
	for hero in _alive(heroes):
		if GameData.has_trait(hero["source"], "Meneur") and not panicking(hero) and not afraid(hero):
			leader = hero
			break
	if leader.is_empty():
		return
	_defense_organized = true
	# (un héros qui a déjà un ordre du Maître le garde)
	var free := _alive(heroes).filter(func(h): return h["order"].is_empty() and h["present"])
	var shields := free.filter(func(h): return h["shield"] and not h["ranged"])
	var others := free.filter(func(h): return not h["shield"] and not h["ranged"])
	var shooters := free.filter(func(h): return h["ranged"])
	if shields.size() < 2:
		return  # pas de mur possible : la ligne de départ vaut mieux qu'un groupe serré (simulation, équipe sans armes)
	var row: int = map_data["alley_exit_row"] + DEFENSE_LINE_GAP
	var center := GRID_W / 2
	# Le mur : du milieu vers les côtés (x, x - 1, x + 1, x - 2...).
	var wall: Array = []
	for i in shields.size():
		var dx := (i + 1) / 2 * (1 if i % 2 == 1 else -1)
		var cell := Vector2(clampi(center + dx, 0, GRID_W - 1) + 0.5, row + 0.5)
		wall.append(cell)
		_send_to_post(shields[i], cell)
	# Juste derrière le mur : les autres au corps à corps, un lancier d'abord.
	others.sort_custom(func(a, b): return a["weapon"] == "Lance" and b["weapon"] != "Lance")
	for i in others.size():
		var front: Vector2 = wall[i % wall.size()] if not wall.is_empty() else Vector2(center + 0.5, row + 0.5)
		_send_to_post(others[i], _free_cell_near(_cell_of(front + Vector2(0, 1))))
	# Les tireurs : derrière (P5), ou sur les toits les plus proches de la sortie des ruelles (essai C1).
	var roofs: Array = []
	if leader_roof_shooters:
		# (seulement les toits qu'on atteint de son côté de la carte, sans passer chez les ennemis)
		var ours := map.reachable(heroes.map(func(h): return _cell_of(h["pos"])), MapGenerator.ALLEY_ROW)
		roofs = height_cells().filter(func(p): return ours.has(_cell_of(p)))
	var spot_of := BattleMap.center(Vector2i(center, map_data["alley_exit_row"] - 1))
	roofs.sort_custom(func(a, b): return a.distance_to(spot_of) < b.distance_to(spot_of))
	for hero in shooters:
		if not roofs.is_empty():
			_send_to_post(hero, roofs.pop_front())
		else:
			_send_to_post(hero, _free_cell_near(Vector2i(center, row + 2)))
	_reveal(leader, "Meneur")
	var who := _name_with_stars(leader)
	_log("%s organise la défense : un mur de boucliers, les autres derrière." % who, "awaken")
	_alert("Défense", ["%s organise la défense." % who])
	_journal_formation("défense du Meneur (%s)" % leader["name"])


## Le Meneur place un héros : il y va, et ce sera son poste (voir _follow_order). Avec l'IA tactique (C3), il garde
## ce placement de départ jusqu'à l'arrivée de l'ennemi, puis chacun applique l'IA ; un tireur posté sur un toit
## y reste (il tient le poste en hauteur, comme avant).
func _send_to_post(hero: Dictionary, spot: Vector2) -> void:
	hero["order"] = {"kind": "move", "pos": spot, "by": "meneur"}
	hero["path"] = PackedVector2Array()


## Chaque pas : l'équipe couvre-t-elle les trois portées (héros debout sur le terrain) ? Annonce aussi, une
## fois, le premier mur de boucliers. (Rien en duel.)
func _update_formations() -> void:
	if quest.get("duel", false):
		return
	var bands := {}
	for hero in _alive(heroes):
		bands[range_band(hero)] = true
	var covered := bands.size() >= 3
	if covered != ranges_covered:
		ranges_covered = covered
		if covered:
			_log("L'équipe couvre les trois portées (courte, moyenne, longue) : +%d %% en attaque et en défense." \
				% roundi(GameData.RANGE_COVER_BONUS * 100), "awaken")
			_journal_formation("trois portées")
		else:
			_log("L'équipe ne couvre plus les trois portées.", "disobey")
	if not _wall_announced:
		for hero in _alive(heroes):
			var wall := _wall_allies(hero)
			if not wall.is_empty():
				_wall_announced = true
				var names := [hero["name"]] + wall.map(func(ally): return ally["name"])
				_log("Mur de boucliers : %s serrent les rangs." % " et ".join(names), "awaken")
				_alert("Mur de boucliers", ["%s serrent les rangs : leur défense monte." % " et ".join(names)])
				_journal_formation("mur de boucliers")
				break


## Mur de boucliers : les porteurs de bouclier côte à côte avec celui-ci (même ligne, à moins de
## SHIELD_WALL_RANGE cases), SHIELD_WALL_MAX_ALLIES au plus. Vide s'il n'a pas de bouclier.
func _wall_allies(unit: Dictionary) -> Array:
	if not unit["shield"] or not unit["is_hero"] or quest.get("duel", false):
		return []
	var wall := []
	for ally in _alive(heroes):
		if ally["id"] == unit["id"] or not ally["shield"]:
			continue
		var offset: Vector2 = ally["pos"] - unit["pos"]
		if offset.length() <= GameData.SHIELD_WALL_RANGE and absf(offset.y) <= 0.8:
			wall.append(ally)
			if wall.size() >= GameData.SHIELD_WALL_MAX_ALLIES:
				break
	return wall


## Un lancier est-il juste derrière un porteur de bouclier, face à « target » (le bouclier plus près d'elle) ?
func _behind_shield(unit: Dictionary, target: Dictionary) -> bool:
	if not unit["is_hero"]:
		return false
	var distance: float = unit["pos"].distance_to(target["pos"])
	for ally in _alive(heroes):
		if ally["id"] != unit["id"] and ally["shield"] \
				and ally["pos"].distance_to(unit["pos"]) <= GameData.SPEAR_WALL_RANGE \
				and ally["pos"].distance_to(target["pos"]) < distance - 0.4:
			return true
	return false


## Formations : ce que l'attaque d'un héros gagne (trois portées couvertes).
func _formation_attack(unit: Dictionary) -> float:
	return 1.0 + GameData.RANGE_COVER_BONUS if unit["is_hero"] and ranges_covered else 1.0


## Formations : ce que la défense d'un héros gagne (trois portées couvertes, mur de boucliers).
func _formation_defense(unit: Dictionary) -> float:
	var factor := _formation_attack(unit)
	return factor * (1.0 + _wall_allies(unit).size() * GameData.SHIELD_WALL_DEFENSE_PER_ALLY)


## Bonus d'un héros qui se bat à moins de BOND_RANGE cases d'un ami ou d'un frère d'armes
## (le meilleur lien compte) : 1.05 ou 1.10 ; 1.0 sinon (et pour les ennemis).
func _bond(unit: Dictionary) -> float:
	var best := 0.0
	for ally_id in unit["bonds"]:
		var ally: Dictionary = units[ally_id]
		if ally["hp"] > 0 and ally["present"] and unit["pos"].distance_to(ally["pos"]) <= GameData.BOND_RANGE:
			best = maxf(best, GameData.BOND_FIGHT_BONUS[unit["bonds"][ally_id]])
	return 1.0 + best


## Protecteur : l'allié en danger le plus proche (sous PROTECT_HP de sa vie, à moins de PROTECT_RANGE
## cases) qu'il doit couvrir, ou {}.
func _ward_of(guardian: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var best := GameData.PROTECT_RANGE
	for ally in _alive(heroes):
		if ally["id"] == guardian["id"] or float(ally["hp"]) / ally["max_hp"] >= GameData.PROTECT_HP:
			continue
		var distance: float = guardian["pos"].distance_to(ally["pos"])
		if distance < best:
			best = distance
			result = ally
	return result


## Le Protecteur qui couvre cette cible (un héros sous PROTECT_HP de sa vie), s'il est assez près, debout
## et pas en panique ; {} sinon.
func _guardian_for(target: Dictionary) -> Dictionary:
	if not target["is_hero"] or quest.get("duel", false) or float(target["hp"]) / target["max_hp"] >= GameData.PROTECT_HP:
		return {}
	for ally in _alive(heroes):
		if ally["id"] != target["id"] and not panicking(ally) and GameData.has_trait(ally["source"], "Protecteur") \
				and ally["pos"].distance_to(target["pos"]) <= GameData.PROTECT_GUARD_RANGE:
			return ally
	# (étape E, point 4) sans le trait : un ami ou un frère d'armes tout près (voir BattleTies.guards)
	if ties != null:
		for ally in _alive(heroes):
			if ties.guards(ally, target):
				return ally
	return {}


## Le Protecteur encaisse PROTECT_SHARE du coup destiné à « ward » (il peut tomber à sa place).
## Renvoie ce qui reste pour la cible.
func _cover(guardian: Dictionary, ward: Dictionary, amount: int) -> int:
	var part: float = ties.share_of(guardian) if ties != null else GameData.PROTECT_SHARE  # (un Martyr : plus)
	var share := _hold_on(guardian, mini(roundi(amount * part), guardian["hp"]))
	if share <= 0:
		return amount
	guardian["hp"] -= share
	guardian["engaged"] = true
	guardian["acts"]["vit"] += 1  # encaisser exerce la Santé
	_effect("hit", guardian, guardian, "-%d" % share, false)
	if ties != null:
		ties.covered(guardian, ward)  # (étape E, point 4) noté pour les liens après le combat
	if not guardian.get("covered", {}).has(ward["id"]) and GameData.has_trait(guardian["source"], "Protecteur"):
		guardian["covered"] = guardian.get("covered", {})
		guardian["covered"][ward["id"]] = true
		_log("%s se jette devant %s pour le protéger !" % [guardian["name"], ward["name"]], "awaken")
		_reveal(guardian, "Protecteur")
	if guardian["hp"] <= 0:
		_announce_fall(guardian, "tombé en protégeant %s" % ward["name"])
	else:
		_stress_wound(guardian, share)
	return amount - share
