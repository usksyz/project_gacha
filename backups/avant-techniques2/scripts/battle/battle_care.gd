class_name BattleCare
extends BattleBerserk
## Combat (voir battle.gd) : saignement, agonie, secours, soins et mort.


func _try_heal(healer: Dictionary, target: Dictionary) -> void:
	if healer["cooldown"] > 0 or time < healer["swap_until"]:
		return
	healer["cooldown"] = _attack_time(healer)
	healer["last_attack_t"] = time
	healer["mana"] -= HEAL_MANA_COST
	_spend_stamina(healer, GameData.STAMINA_ATTACK_COST)
	var amount := roundi(healer["atk"] * _mind(healer) * _bond(healer) * 2.0 * randf_range(0.9, 1.1))
	amount = mini(amount, target["max_hp"] - target["hp"])
	target["hp"] += amount
	healer["contribution"] += amount
	healer["engaged"] = true  # soigner, c'est prendre part au combat
	healer["acts"]["int"] += 1  # la magie exerce l'Intelligence
	_effect("heal", healer, target, "+%d" % amount, false)


# ---------------------------------------------------------------------------
# Saignement
# ---------------------------------------------------------------------------

## La cible se met à saigner. Si elle saignait déjà, c'est une hémorragie.
func _start_bleed(attacker: Dictionary, target: Dictionary) -> void:
	if target.get("surpass", false):
		return  # Surpassement : immunité aux altérations d'état
	var bleed: Dictionary = target["bleed"]
	var heavy: bool = bleed["ticks"] > 0
	bleed["heavy"] = heavy
	bleed["ticks"] = HEAVY_BLEED_TICKS if heavy else BLEED_TICKS
	bleed["timer"] = BLEED_INTERVAL
	bleed["amount"] = maxi(1, roundi(target["max_hp"] * (HEAVY_BLEED_DAMAGE if heavy else BLEED_DAMAGE)))
	bleed["cause"] = "%s causé%s par %s (niv. %d)" % [
		"d'une hémorragie" if heavy else "d'un saignement", "e" if heavy else "",
		attacker["name"], attacker["level"]]
	if not target["has_bled"]:
		_stress(target, GameData.MENTAL_LOSS_BLEEDING, "bleeding")  # voir son propre sang couler
	target["has_bled"] = true
	var who := _name_with_stars(target)
	if heavy:
		_log("%s fait une hémorragie ! Sa vie s'écoule à grande vitesse." % who, "bleed")
	else:
		_log("%s saigne et va perdre de la santé à intervalles réguliers." % who, "bleed")


## Un combattant qui saigne perd de la vie à intervalles réguliers.
func _bleed_tick(unit: Dictionary) -> void:
	var bleed: Dictionary = unit["bleed"]
	if bleed["ticks"] <= 0:
		return
	bleed["timer"] -= TICK
	if bleed["timer"] > 0:
		return
	bleed["timer"] = BLEED_INTERVAL
	bleed["ticks"] -= 1
	# Résistance à la douleur (les blessures guérissent plus vite) et Indomptable : 80 % au plus.
	var resist := minf(0.8, GameData.skill_level(unit["skills"], "Résistance à la douleur") * PAIN_RESIST_PER_LEVEL \
		+ GameData.skill_level(unit["skills"], "Indomptable") * GameData.INDOMITABLE_PER_LEVEL)
	var amount := _hold_on(unit, mini(maxi(1, roundi(bleed["amount"] * (1.0 - resist))), unit["hp"]))
	unit["hp"] -= amount
	_effect("bleed", unit, unit, "-%d" % amount, false)
	if _duel_yields(unit):
		return
	if unit["hp"] <= 0:
		_announce_fall(unit, "mort " + bleed["cause"])
		return
	_stress_wound(unit, amount)
	_check_critical_state(unit)
	if bleed["ticks"] == 0:
		bleed["heavy"] = false


# ---------------------------------------------------------------------------
# Chutes, cibles, journal
# ---------------------------------------------------------------------------

## Un combattant tombe à 0 point de vie. Un ennemi est vaincu ; un héros tombe à l'agonie (voir
## GameData, tower.gd, « Agonie ») ; « instant » : il meurt sur le coup (mort de stress).
func _announce_fall(fighter: Dictionary, cause: String, instant := false, blow := {}) -> void:
	if fighter["killer"] != "" or fighter["agony"]:
		return  # déjà tombé
	if not fighter["is_hero"]:
		fighter["killer"] = cause
		_log("%s est vaincu." % fighter["name"])
	elif instant:
		_die(fighter, cause)
	else:
		_start_agony(fighter, cause, blow)


## Le héros tombe à l'agonie : il ne bouge plus, ses alliés ont AGONY_SECONDS pour le sauver (_agony_tick).
## S'il reste une potion de soin à l'équipe, elle le stabilise tout de suite.
func _start_agony(fighter: Dictionary, cause: String, blow := {}) -> void:
	fighter["hp"] = 0
	fighter["agony"] = true
	fighter["agony_until"] = time + GameData.AGONY_SECONDS
	fighter["agony_cause"] = cause
	fighter["rescue"] = 0.0
	fighter["panic"] = ""
	fighter["order"] = {}
	fighter["bleed"]["ticks"] = 0
	if fighter["berserk"]:
		_exit_berserk(fighter)
	var who := _name_with_stars(fighter)
	_journal(fighter, "agony", {"cause": cause})
	_log("%s s'effondre ! Il est dans un état critique." % who, "bleed")
	var lines := ["%s est dans un état critique, sa vie est en danger !" % who]
	# Arme plantée (œuvre, ch. 11) : l'arme reste dans la plaie ; un allié ne peut pas le stabiliser.
	fighter["embedded"] = false
	if not blow.is_empty():
		var attacker: Dictionary = blow["attacker"]
		var chance := GameData.embed_chance(attacker["base_name"], attacker["class"], attacker["weapon"],
			attacker["boss"], blow["kind"])
		if randf() < chance:
			fighter["embedded"] = true
			lines.append("Une arme est plantée dans %s : la retirer le tuerait." % fighter["name"])
			_log("L'arme de %s est restée plantée dans %s." % [attacker["name"], fighter["name"]], "bleed")
	_alert("État critique", lines, true)
	if potions > 0:
		potions -= 1
		potions_used += 1
		_stabilize(fighter, "une potion de soin")


## Peut-il secourir un héros à l'agonie ? Debout, sur le terrain, pas effrayé ni en panique.
func _can_rescue(ally: Dictionary) -> bool:
	return ally["hp"] > 0 and ally["present"] and not afraid(ally) and not panicking(ally)


## Chaque pas, pour un héros à l'agonie : un allié libre à son côté (qui peut secourir, et pas au contact d'un
## ennemi) le stabilise au bout de AGONY_RESCUE_SECONDS (il doit y rester), sauf si une arme est plantée dans
## la plaie ; passé AGONY_SECONDS, il meurt (un immortel du mode dev reste à terre).
func _agony_tick(fighter: Dictionary) -> void:
	var helper: Dictionary = {}
	if not fighter["embedded"]:
		for ally in _alive(heroes):
			if _can_rescue(ally) and not _in_contact(ally) \
					and ally["pos"].distance_to(fighter["pos"]) <= GameData.AGONY_ALLY_RANGE:
				helper = ally
				break
	if helper.is_empty():
		fighter["rescue"] = 0.0
	else:
		fighter["rescue"] += TICK * _first_aid(helper)
		if fighter["rescue"] >= GameData.AGONY_RESCUE_SECONDS:
			helper["exclusive_events"]["rescue"] = true  # (P2g : peut éveiller Premiers soins)
			_stabilize(fighter, helper["name"])
			return
	if time >= fighter["agony_until"]:
		_die(fighter, fighter["agony_cause"])


## Sauvé de l'agonie (« by » : l'allié ou la potion) : il se relève avec AGONY_STABILIZED_HP de sa vie et reprend
## le combat (demande du porteur du projet, étape A : avant, il sortait du combat ; il ne quitte l'étage qu'à la
## fin, avec les autres). Il peut retomber à l'agonie.
func _stabilize(fighter: Dictionary, by: String) -> void:
	fighter["agony"] = false
	fighter["stabilized"] = true
	fighter["hp"] = maxi(1, roundi(fighter["max_hp"] * GameData.AGONY_STABILIZED_HP))
	fighter["order"] = {}
	fighter["path"] = PackedVector2Array()
	var text := "%s est stabilisé grâce à %s." % [_name_with_stars(fighter), by]
	_journal(fighter, "rescued", {"by": by})
	_log(text + " Il se relève et reprend le combat.", "awaken")
	_alert("Stabilisé", [text, "Il se relève, affaibli, et reprend le combat."])
	fighter["mind_news"].append("%s a frôlé la mort : stabilisé grâce à %s." % [fighter["name"], by])


## Fin de l'étage (étape A, demande du porteur du projet) : un héros encore à l'agonie quand l'étage se termine est
## soigné (il ne meurt pas, même sans avoir été stabilisé, arme plantée comprise), s'il reste au moins un héros
## debout pour le ramener. Toute l'équipe à terre (défaite complète) : personne ne le ramène, il meurt.
func _heal_at_end(fighter: Dictionary) -> void:
	fighter["agony"] = false
	fighter["stabilized"] = true
	fighter["hp"] = maxi(1, roundi(fighter["max_hp"] * GameData.AGONY_STABILIZED_HP))
	_journal(fighter, "rescued", {"by": "la fin de l'étage"})
	_log("%s est soigné à la fin de l'étage : il s'en sortira." % _name_with_stars(fighter), "awaken")
	fighter["mind_news"].append("%s a frôlé la mort : soigné à la fin de l'étage." % fighter["name"])


## Qui va secourir qui : pour chaque héros à l'agonie, l'allié libre le plus proche (à moins de
## AGONY_HELP_RANGE cases : debout, ni en panique, ni en fuite, ni sous un ordre du Maître, ni lui-même au
## contact d'un ennemi) court à son côté. Un aidant ne s'occupe que d'un blessé à la fois ; une fois en
## route, il continue même si un ennemi le rattrape (le Maître peut l'envoyer ailleurs par un ordre).
func _assign_helpers() -> void:
	# Ceux qui sont déjà en route continuent (s'ils le peuvent encore).
	var kept := {}
	for helper_id in _helpers:
		var helper: Dictionary = units[helper_id]
		var patient: Dictionary = units[_helpers[helper_id]]
		if _needs_help(patient) and _can_rescue(helper) and helper["order"].is_empty():
			kept[helper_id] = patient["id"]
	_helpers = kept
	# Les héros à l'agonie d'abord, puis ceux qui font une hémorragie (soin d'urgence).
	var patients := heroes.filter(func(h): return h["agony"] and _needs_help(h))
	patients.append_array(heroes.filter(func(h): return not h["agony"] and _needs_help(h)))
	for patient in patients:
		if _helpers.values().has(patient["id"]):
			continue
		var best: Dictionary = {}
		var best_distance := GameData.AGONY_HELP_RANGE if patient["agony"] else GameData.CARE_HELP_RANGE
		for ally in _alive(heroes):
			if ally["id"] == patient["id"] or _helpers.has(ally["id"]) or not _can_rescue(ally) \
					or not ally["order"].is_empty() or _in_contact(ally):
				continue
			var distance: float = ally["pos"].distance_to(patient["pos"])
			if distance < best_distance:
				best_distance = distance
				best = ally
		if not best.is_empty():
			_helpers[best["id"]] = patient["id"]


## A-t-il besoin d'un allié à son côté ? À l'agonie, ou en hémorragie (debout et sur le terrain).
func _needs_help(hero: Dictionary) -> bool:
	if hero["agony"]:
		return not hero["embedded"]  # (arme plantée : un allié ne peut rien pour lui)
	return hero["hp"] > 0 and hero["present"] and hero["bleed"]["ticks"] > 0 and hero["bleed"]["heavy"]


## Soin d'urgence, chaque pas, pour un héros en hémorragie : son aidant (voir _assign_helpers) à son côté
## pendant CARE_SECONDS arrête le saignement ; s'il s'éloigne, tout est à refaire.
func _care_tick(hero: Dictionary) -> void:
	var carer: Dictionary = {}
	for helper_id in _helpers:
		if _helpers[helper_id] == hero["id"] and units[helper_id]["pos"].distance_to(hero["pos"]) <= GameData.AGONY_ALLY_RANGE:
			carer = units[helper_id]
	if carer.is_empty():
		hero["care"] = 0.0
		return
	hero["care"] += TICK * _first_aid(carer)
	if hero["care"] < GameData.CARE_SECONDS:
		return
	hero["care"] = 0.0
	hero["bleed"]["ticks"] = 0
	hero["bleed"]["heavy"] = false
	carer["exclusive_events"]["rescue"] = true  # (P2g : peut éveiller Premiers soins)
	var text := "%s a arrêté le saignement de %s." % [carer["name"], hero["name"]]
	_log(text, "awaken")
	_alert("Soin d'urgence", [text])


## Vitesse des secours d'un aidant : 1, plus vite avec Premiers soins (exclusive, P2g : 30 % de temps en moins).
func _first_aid(helper: Dictionary) -> float:
	return 1.0 / (1.0 - GameData.exclusive_effect(helper["skills"], "Premiers soins"))


## Au contact d'un ennemi (à moins de STAMINA_CONTACT_RANGE cases) ?
func _in_contact(unit: Dictionary) -> bool:
	var foes := _alive(enemies if unit["is_hero"] else heroes)
	return foes.any(func(foe): return unit["pos"].distance_to(foe["pos"]) <= GameData.STAMINA_CONTACT_RANGE)


## Un aidant (voir _assign_helpers) va au côté de son blessé et y reste. Renvoie vrai s'il est occupé à ça.
func _help(unit: Dictionary) -> bool:
	if not _helpers.has(unit["id"]):
		return false
	var patient: Dictionary = units[_helpers[unit["id"]]]
	if unit["pos"].distance_to(patient["pos"]) > GameData.AGONY_ALLY_RANGE * 0.7:
		_move_towards(unit, patient["pos"])
	return true


## La mort d'un héros (agonie sans secours, mort de stress) ; un immortel du mode dev reste à terre.
func _die(fighter: Dictionary, cause: String) -> void:
	fighter["agony"] = false
	fighter["hp"] = 0
	if fighter["immortal"]:
		fighter["killer"] = cause  # noté seulement pour ne pas l'annoncer deux fois
		_log("%s est à terre, mais se relèvera." % fighter["name"])
	else:
		fighter["killer"] = cause
		fighter["panic"] = ""
		_journal(fighter, "death", {"cause": cause})
		_log("%s tombe au combat !" % fighter["name"])
		# Voir un allié tomber ébranle les autres (selon leur Sensibilité et leur Empathie, et l'habitude de
		# la mort ; un ami ou un frère d'armes : bien plus encore, voir BOND_DEATH_FACTOR, et on ne s'habitue
		# pas à perdre un ami).
		for ally in _alive(heroes):
			if GameData.has_trait(ally["source"], "Protecteur"):
				_reveal(ally, "Protecteur")
			var bond: int = ally["bonds"].get(fighter["id"], 0)
			var loss: float = GameData.MENTAL_LOSS_ALLY_DEATH * GameData.BOND_DEATH_FACTOR[bond]
			if bond >= GameData.BOND_FRIEND:
				_log("%s voit tomber son %s %s..." % [ally["name"],
					"frère d'armes" if bond == GameData.BOND_BROTHERS else "ami", fighter["name"]], "bleed")
			_stress(ally, loss, "ally_death", {"friend": bond >= GameData.BOND_FRIEND})
			# Voir mourir quelqu'un tout près peut faire peur (voir _scare).
			if ally["pos"].distance_to(fighter["pos"]) <= GameData.FEAR_SIGHT:
				_scare(ally, GameData.FEAR_ALLY_DEATH_CHANCE, "la mort de %s" % fighter["name"])
