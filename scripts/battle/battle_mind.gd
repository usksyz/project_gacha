class_name BattleMind
extends BattleMoves
## Combat (voir battle.gd) : peur et santé mentale (stress, rupture, panique, désobéissance, traits révélés).


## Le héros obéit-il à l'ordre ? Avec une santé mentale basse, il peut l'ignorer
## (GameData.disobey_chance, que sa personnalité aggrave ou adoucit), puis il boude : il ignore tous les
## ordres pendant DISOBEY_SULK secondes. Quand c'est sa discipline qui le fait obéir et qu'il est Loyal,
## le trait se révèle.
func _obeys(hero: Dictionary) -> bool:
	if time < hero["sulk_until"] or panicking(hero):
		_effect("refuse", hero, hero, "Non !", false)
		return false
	var base := GameData.disobey_base(hero["mental"])
	if base <= 0.0:
		return true
	var chance := GameData.disobey_chance(hero["source"], hero["mental"])
	var roll := randf()
	if roll < chance:
		hero["sulk_until"] = time + GameData.DISOBEY_SULK
		_effect("refuse", hero, hero, "Non !", false)
		_log("%s, à bout de nerfs, ignore ton ordre." % hero["name"], "disobey")
		return false
	if roll < base and GameData.has_trait(hero["source"], "Loyal"):
		# Sans sa personnalité, il aurait refusé.
		if _reveal(hero, "Loyal"):
			_log("%s obéit malgré la peur : il est loyal." % hero["name"], "disobey")
	return true


## Un trait du héros agit : il se révèle s'il était caché (annonce gardée pour la fin du combat).
## Renvoie vrai s'il vient d'être révélé.
func _reveal(fighter: Dictionary, trait_name: String) -> bool:
	var line := GameData.reveal_trait(fighter["source"], trait_name)
	if line == "":
		return false
	fighter["mind_news"].append(line)
	return true


## La peur : toutes ses stats x FEAR_STAT_FACTOR (attaque et défense dans _mind, vitesse, critiques).
func _fear(unit: Dictionary) -> float:
	return GameData.FEAR_STAT_FACTOR if afraid(unit) else 1.0


# ---------------------------------------------------------------------------
# Santé mentale en direct, rupture
# ---------------------------------------------------------------------------

## Efficacité selon la santé mentale du moment (1.0 pour les ennemis ; voir GameData.mental_factor).
## Un héros qui a peur (voir _scare) ou épuisé (_tired) frappe et se défend moins bien.
func _mind(unit: Dictionary) -> float:
	if not unit["is_hero"]:
		return _tired(unit)  # (l'adversaire d'un duel s'épuise aussi)
	return GameData.mental_factor(unit["mental"]) * _fear(unit) * _tired(unit)


## Un héros perd de la santé mentale : stress revu (P2, PersonalityEngine.stress : Stabilité, sensibilité au
## type d'événement « type », accoutumance ; « context » : sujet du boss, deuil d'un ami), puis moins avec
## Calme. Le sujet est noté (fighter["exposed"]) : s'il finit le combat sans s'effondrer, il s'y habitue un peu
## (GameData.finish_tower_battle). À 0, c'est la rupture (une fois par combat).
func _stress(fighter: Dictionary, amount: float, type := "", context := {}) -> void:
	if not fighter["is_hero"] or fighter["hp"] <= 0 or amount <= 0.0 or quest.get("duel", false):
		return  # (un duel compte à part, voir GameData.finish_duel)
	var loss := PersonalityEngine.stress(fighter["source"], type, amount, context)
	# Plancher : certains héros ne tombent jamais à 0 (Stabilité 90, Maîtrise 90 : pas de rupture).
	var floor_value := PersonalityEngine.modified("mental_floor", fighter["source"], 0.0)
	fighter["mental"] = maxf(minf(floor_value, fighter["mental"]), fighter["mental"] - loss * (1.0 - GameData.mental_guard(fighter["skills"])))
	var subject := PersonalityEngine.stress_subject(type, context)
	if subject != "" and not context.get("friend", false):
		fighter["exposed"][subject] = true
	if fighter["mental"] <= 0.0 and not fighter["ruptured"]:
		_rupture(fighter)


## Blessure : perte proportionnelle à la vie perdue (MENTAL_LOSS_WOUNDS pour une vie entière).
func _stress_wound(fighter: Dictionary, amount: int) -> void:
	_stress(fighter, GameData.MENTAL_LOSS_WOUNDS * float(amount) / fighter["max_hp"], "wounds")


## Un boss arrive sur le terrain : chaque héros debout encaisse le choc, selon son Courage et ce qu'il sait
## déjà de ce boss (accoutumance). Courageux et Lâche s'y montrent.
func _check_boss_arrival() -> void:
	if _boss_seen or not enemies.any(func(e): return e["boss"] and e["present"] and e["hp"] > 0):
		return
	_boss_seen = true
	var boss: Dictionary = enemies.filter(func(e): return e["boss"] and e["present"] and e["hp"] > 0)[0]
	var context := {"subject": PersonalityEngine.subject_for_enemy(boss["base_name"])}
	for hero in _alive(heroes):
		for trait_name in ["Courageux", "Lâche"]:
			if GameData.has_trait(hero["source"], trait_name):
				_reveal(hero, trait_name)
		_stress(hero, GameData.MENTAL_LOSS_BOSS, "boss", context)
		_scare(hero, GameData.FEAR_BOSS_CHANCE, "le boss")


## La santé mentale d'un héros vient de tomber à 0 : éveil (rare) ou effondrement (le plus souvent).
func _rupture(fighter: Dictionary) -> void:
	fighter["ruptured"] = true
	var who := _name_with_stars(fighter)
	var source: Dictionary = fighter["source"]
	# Déjà en rupture avant le combat : son esprit peut ne pas tenir une deuxième fois (mort de stress).
	if fighter["was_broken"] and not fighter["immortal"] and randf() < GameData.STRESS_DEATH_CHANCE:
		fighter["hp"] = 0
		fighter["bleed"]["ticks"] = 0
		_effect("refuse", fighter, fighter, "...", false)
		_announce_fall(fighter, "mort de stress, l'esprit brisé", true)
		_alert("Rupture : mort de stress", [
			"%s était déjà en rupture. Sa santé mentale est retombée à 0." % who,
			"Son esprit n'a pas tenu : il meurt de stress.",
		], true)
		return
	if randf() < GameData.rupture_awaken_chance(source):
		# Éveil : le « craquage positif ». L'esprit se brise... et se reforge (plus souvent chez un Vulnérable).
		fighter["mental"] = GameData.RUPTURE_AWAKEN_MENTAL
		_log("Rupture ! L'esprit de %s se brise... et se reforge. Éveil !" % who, "awaken")
		_awaken(fighter, float(fighter["hp"]) / fighter["max_hp"])
		_alert("Rupture : éveil", [
			"La santé mentale de %s est tombée à 0." % who,
			"Au lieu de s'effondrer, il s'éveille ! Sa santé mentale remonte à %d." % GameData.RUPTURE_AWAKEN_MENTAL,
		])
		fighter["mind_news"].append("%s : rupture en combat, mais il s'est éveillé." % fighter["name"])
		return

	# Effondrement : panique (fuite ou frénésie), et la peur se propage aux alliés proches.
	var flee := randf() < GameData.panic_flee_chance(source)
	if flee and GameData.has_trait(source, "Lâche"):
		_reveal(fighter, "Lâche")
	fighter["panic"] = "flee" if flee else "frenzy"
	fighter["fear_flee"] = false  # (l'effondrement remplace une fuite de peur : un allié ne l'arrête pas)
	fighter["panic_until"] = time + GameData.PANIC_SECONDS
	fighter["panic_target"] = -1
	fighter["order"] = {}
	fighter["path"] = PackedVector2Array()
	# Il court loin des ennemis qu'il connaît (carte de fuite, recensement « Techniques », point 5 ; sans ennemi connu :
	# vers le bas de la carte, loin des ennemis qui arrivent par le haut).
	fighter["flee_to"] = _flee_cell(fighter)
	var what := "Il s'enfuit, terrifié." if flee else "Il frappe au hasard, amis comme ennemis !"
	_log("Rupture ! %s s'effondre. %s" % [who, what], "berserk")
	_effect("refuse", fighter, fighter, "!!!", false)
	_alert("Rupture : effondrement", [
		"La santé mentale de %s est tombée à 0. Il panique pendant %d secondes." % [who, GameData.PANIC_SECONDS],
		what,
		"Ses alliés proches sont ébranlés.",
	], true)
	fighter["mind_news"].append("%s : rupture en combat, il s'est effondré." % fighter["name"])
	for ally in _alive(heroes):
		if ally["id"] != fighter["id"] and ally["pos"].distance_to(fighter["pos"]) <= GameData.PANIC_RADIUS:
			_stress(ally, GameData.PANIC_SPREAD_LOSS, "panic_spread")


## En pleine panique (effondrement) ?
func panicking(unit: Dictionary) -> bool:
	return unit["panic"] != "" and time < unit["panic_until"]


## En train de fuir (peur, ou effondrement en fuite) : il tourne le dos à l'ennemi.
func _fleeing(unit: Dictionary) -> bool:
	return unit["panic"] == "flee" and panicking(unit)


## A peur en ce moment (voir _scare) : « PEUR » sur son portrait.
func afraid(unit: Dictionary) -> bool:
	return time < unit["fear_until"]


## Les menaces qui pèsent sur ce héros (voir GameData, personality.gd, « Peur ») : un ennemi bien plus fort
## ou un boss à portée, une horde, une santé mentale basse ; et « novice » (un 1 étoile dans ses premiers
## combats) si « novice_counts ». Renvoie leur nombre (0 : rien ne peut lui faire peur).
func _fear_threats(fighter: Dictionary, novice_counts: bool) -> int:
	var threats := 0
	var near := _alive(enemies).filter(func(foe): return fighter["pos"].distance_to(foe["pos"]) <= ENGAGE_DISTANCE)
	if near.any(func(foe): return foe["boss"] or foe["level"] >= fighter["level"] + GameData.FEAR_STRONGER_LEVELS):
		threats += 1
	if not near.is_empty() and (quest["type"] == "survival" or quest["walls"] > 0):
		threats += 1  # une horde
	if fighter["mental"] < GameData.FEAR_LOW_MENTAL:
		threats += 1
	if novice_counts and GameData.is_combat_novice(fighter["source"]):
		threats += 1
	return threats


## Peur : un héros peut prendre peur devant « what » (la vue de l'ennemi, sa première blessure, la mort
## d'un allié, un boss), selon les menaces (_fear_threats) et GameData.fear_chance. Une fois par combat ;
## ensuite, seule une blessure grave peut la ramener (voir _damage). « novice_counts » : faux pour la vue
## de l'ennemi (un novice ne s'effraie pas d'avance, seulement face à une vraie menace).
func _scare(fighter: Dictionary, base_chance: float, what: String, novice_counts := true) -> void:
	if not fighter["fearful"] or fighter["scared"] or fighter["hp"] <= 0 or panicking(fighter):
		return
	var chance := GameData.fear_chance(fighter["source"], base_chance * _dread(fighter), _fear_threats(fighter, novice_counts))
	if randf() < chance:
		_frighten(fighter, what)


## Ce que le héros sait des ennemis à portée (P2, effets des sujets) : l'appréhension du plus redouté,
## rapportée à son danger habituel (PersonalityEngine.habit_factor : 1 pour qui n'en sait rien, moins pour
## qui s'y est habitué, plus pour un berger face aux loups). 1 s'il n'y a aucun ennemi connu à portée.
func _dread(fighter: Dictionary) -> float:
	var worst := -1.0
	for foe in _alive(enemies):
		if fighter["pos"].distance_to(foe["pos"]) > ENGAGE_DISTANCE:
			continue
		var subject := PersonalityEngine.subject_for_enemy(foe["base_name"])
		if subject != "":
			worst = maxf(worst, PersonalityEngine.habit_factor(fighter["source"], subject))
	return worst if worst >= 0.0 else 1.0


## Le héros a peur : toutes ses stats baissent (_fear) pendant FEAR_MAX_SECONDS, sauf si un allié la lève
## (_fear_tick). Soit il s'enfuit d'abord vers le bas de la carte (FEAR_SECONDS, sourd aux ordres), soit il
## se bat contre sa peur (il obéit). Rien n'annonce la fuite : le joueur la voit. Le journal dit seulement
## qu'il a peur.
func _frighten(fighter: Dictionary, what: String) -> void:
	var source: Dictionary = fighter["source"]
	fighter["scared"] = true
	fighter["fear_comfort"] = 0.0
	_log("%s a peur." % _name_with_stars(fighter), "disobey")
	fighter["mind_news"].append("%s a eu peur au combat (%s)." % [fighter["name"], what])
	_stress(fighter, GameData.FEAR_MENTAL_LOSS, "fear")
	if fighter["hp"] <= 0 or panicking(fighter):
		return  # (le stress a pu provoquer une rupture)
	fighter["fear_until"] = time + GameData.FEAR_MAX_SECONDS
	if randf() < GameData.fear_flee_chance(source):
		if GameData.has_trait(source, "Lâche"):
			_reveal(fighter, "Lâche")
		fighter["fear_flee"] = true
		fighter["panic"] = "flee"
		fighter["panic_until"] = time + GameData.FEAR_SECONDS
		fighter["order"] = {}
		fighter["path"] = PackedVector2Array()
		fighter["flee_to"] = _flee_cell(fighter)


## Chaque pas, pour un héros qui peut avoir peur : la vue du premier ennemi à portée peut l'effrayer ;
## s'il a peur, un allié tout près (FEAR_LIFT_RANGE) qui est son ami, son frère d'armes, ou Courageux,
## le rassure : au bout de FEAR_LIFT_SECONDS, la peur se lève (fuite comprise).
func _fear_tick(unit: Dictionary) -> void:
	# (Perception, C3 : la « vue » de l'ennemi, c'est le voir ou l'entendre soi-même.)
	if not unit["saw_enemy"] and _alive(enemies).any(func(foe): return unit["pos"].distance_to(foe["pos"]) <= ENGAGE_DISTANCE \
			and (not perception_on or unit["sees"].has(foe["id"]) or unit["hears"].has(foe["id"]))):
		unit["saw_enemy"] = true
		_scare(unit, GameData.FEAR_SIGHT_ENEMY_CHANCE, "la vue de l'ennemi", false)
	if not afraid(unit):
		return
	var comforter: Dictionary = {}
	for ally in _alive(heroes):
		if ally["id"] == unit["id"] or afraid(ally) or panicking(ally) \
				or unit["pos"].distance_to(ally["pos"]) > GameData.FEAR_LIFT_RANGE:
			continue
		if unit["bonds"].get(ally["id"], 0) >= GameData.BOND_FRIEND or GameData.has_trait(ally["source"], "Courageux"):
			comforter = ally
			break
	if comforter.is_empty():
		unit["fear_comfort"] = 0.0
		return
	unit["fear_comfort"] += TICK
	if unit["fear_comfort"] < GameData.FEAR_LIFT_SECONDS:
		return
	unit["fear_until"] = time
	unit["fear_comfort"] = 0.0
	if unit["fear_flee"] and unit["panic"] == "flee":
		unit["panic"] = ""  # il cesse de fuir
	unit["fear_flee"] = false
	var friend: bool = unit["bonds"].get(comforter["id"], 0) >= GameData.BOND_FRIEND
	if not friend:
		_reveal(comforter, "Courageux")
	var text := "%s n'est plus effrayé." % _name_with_stars(unit)
	_log("%s %s %s l'a rassuré." % [text, "Son ami" if friend else "Le courageux", comforter["name"]], "awaken")
	unit["mind_news"].append("%s n'avait plus peur grâce à %s." % [unit["name"], comforter["name"]])
	_alert("Peur", [text])


## Ce que fait un héros en panique : il fuit, ou il frappe n'importe qui à sa portée (même un allié).
func _panic_think(unit: Dictionary, foes: Array) -> void:
	if unit["panic"] == "flee":
		if time >= unit.get("flee_due", 0.0):
			unit["flee_due"] = time + GameData.FLEE_REPLAN
			unit["flee_to"] = _flee_cell(unit)
		_move_towards(unit, unit["flee_to"])
		return
	if unit["panic_target"] < 0 or time >= unit["panic_retarget"] or units[unit["panic_target"]]["hp"] <= 0:
		# Une nouvelle cible au hasard parmi les trois plus proches, amis ou ennemis.
		var others := _alive(units).filter(func(u): return u["id"] != unit["id"])
		if others.is_empty():
			return
		others.sort_custom(func(a, b): return unit["pos"].distance_to(a["pos"]) < unit["pos"].distance_to(b["pos"]))
		unit["panic_target"] = others.slice(0, 3).pick_random()["id"]
		unit["panic_retarget"] = time + 1.5
	var target: Dictionary = units[unit["panic_target"]]
	if _in_reach(unit, target, unit["reach"]):
		_try_attack(unit, target, foes)
	else:
		_move_towards(unit, target["pos"])


## Où court un héros qui s'enfuit : loin des ennemis qu'il connaît (carte de fuite, voir BattleSearch.flee_target).
func _flee_cell(fighter: Dictionary) -> Vector2:
	if search != null:
		return search.flee_target(fighter)
	return retreat_point(fighter["pos"])
