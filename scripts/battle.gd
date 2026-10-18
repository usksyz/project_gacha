class_name Battle
extends BattleCare


func _init(team: Array, foes: Array, floor_quest: Dictionary = DEFAULT_QUEST) -> void:
	quest = floor_quest
	walls = quest["walls"]
	if not quest.get("duel", false):
		potions = GameData.mission_potions()
	if quest.get("wait_contact", false):
		clock_start = -1.0
	for hero in team:
		heroes.append(_make_fighter(hero, true))
	for enemy in foes:
		if quest.get("duel", false):
			# Duel (voir GameData.duel_quest) : l'adversaire est un héros, avec ses armes, dans le camp d'en face.
			var rival := _make_fighter(enemy, true)
			rival["is_hero"] = false
			enemies.append(rival)
		else:
			enemies.append(_make_fighter(enemy, false))
	units.append_array(heroes)
	units.append_array(enemies)
	for i in units.size():
		units[i]["id"] = i
	# Liens entre les héros de l'équipe (voir GameData, personality.gd) : {numéro du pion allié: palier}.
	for hero in heroes:
		for ally in heroes:
			var level := GameData.bond_level(hero["source"], ally["source"])
			if level > 0:
				hero["bonds"][ally["id"]] = level


## Prépare le champ de bataille et place tout le monde. À appeler une fois, avant step().
func start() -> void:
	_build_map()
	map.build_graph()
	_place_units()
	perception = BattlePerception.new(self)
	tactics = BattleTactics.new(self)
	# Étape E : la disposition des ennemis selon la mission, et l'exploration des héros. Hors horde, le compte à
	# rebours attend le premier contact (ou l'alarme).
	alert = BattleAlert.new(self)
	alert.setup()
	explore = BattleExplore.new(self)
	explore.setup()
	ties = BattleTies.new(self)
	ties.setup()
	if not alert.alarm:
		clock_start = -1.0
	# Les habitudes tactiques de chaque héros pour ce contexte (créées au premier combat, gardées sur le héros).
	tactics_context = BattleTactics.context_of(quest, enemies.map(func(e): return e["source"]), map_data)
	if not quest.get("duel", false):
		for hero in heroes:
			var habits := BattleTactics.profile(hero["source"], tactics_context)
			hero["tw"] = habits["weights"].duplicate()
			hero["tt"] = habits["thresholds"].duplicate()
			hero["t_criteria"] = BattleTactics.criteria_count(hero["source"])
			hero["t_cells"] = BattleTactics.cells_count(hero["source"])
	if quest.get("duel", false) and heroes.size() > 0 and enemies.size() > 0:
		# Duel : les deux duellistes se font face.
		heroes[0]["facing"] = (enemies[0]["pos"] - heroes[0]["pos"]).normalized()
		enemies[0]["facing"] = -heroes[0]["facing"]
	# Défense de la cité : le triple avertissement pèse sur les esprits dès le début.
	if quest.get("warnings", 0) > 0:
		for hero in heroes:
			_stress(hero, GameData.MENTAL_LOSS_WARNINGS, "warnings")
	# Deux hostiles dans la même équipe : l'ambiance est tendue, chacun en perd de la santé mentale.
	for i in heroes.size():
		for j in range(i + 1, heroes.size()):
			if GameData.bond_level(heroes[i]["source"], heroes[j]["source"]) == GameData.BOND_HOSTILE:
				_log("%s et %s se regardent de travers : l'ambiance est tendue." % [heroes[i]["name"], heroes[j]["name"]], "disobey")
				_stress(heroes[i], GameData.MENTAL_LOSS_HOSTILE, "hostile")
				_stress(heroes[j], GameData.MENTAL_LOSS_HOSTILE, "hostile")


## Fait avancer le combat d'un pas (TICK secondes).
func step() -> void:
	if finished:
		return
	for unit in units:
		unit["prev_pos"] = unit["pos"]  # pour que l'écran glisse en douceur d'un pas à l'autre
	_step()
	time += TICK
	# Sécurité : si personne ne s'est encore touché après CONTACT_WAIT_MAX, le décompte démarre quand même.
	# (Hors horde, c'est l'alarme qui s'en charge, voir BattleAlert.tick.)
	if clock_start < 0 and alert.disposition == "horde" and time >= CONTACT_WAIT_MAX:
		_start_clock()
	if not finished and clock_time() >= quest["seconds"]:
		if quest.get("duel", false):
			# Duel au temps écoulé : celui qui garde la plus grande part de sa vie l'emporte.
			var hero: Dictionary = heroes[0]
			var rival: Dictionary = enemies[0]
			victory = float(hero["hp"]) / hero["max_hp"] >= float(rival["hp"]) / rival["max_hp"]
			_log("Le temps est écoulé : %s l'emporte aux points !" % (hero if victory else rival)["name"])
		elif quest["lasting"]:
			victory = true
			_log("Le compte à rebours est terminé : ton équipe a tenu bon ! Victoire !")
		else:
			_log("Le temps est écoulé : ton équipe bat en retraite.")
		_finish()


## Joue tout le combat d'un coup, sans ordres du joueur.
func run() -> void:
	start()
	while not finished:
		step()


## Temps écoulé sur le compte à rebours (0 tant qu'il n'a pas démarré).
func clock_time() -> float:
	return 0.0 if clock_start < 0 else time - clock_start


## Démarre le compte à rebours (survie : au premier contact avec les ennemis).
func _start_clock() -> void:
	if clock_start >= 0:
		return
	clock_start = time
	if alert != null and alert.disposition != "horde":
		_log("Premier contact avec l'ennemi : le compte à rebours commence !")
	else:
		_log("Premier contact avec la horde : le compte à rebours commence !")


func _finish() -> void:
	finished = true
	duration = time
	_after_fight()


# ---------------------------------------------------------------------------
# Ordres du joueur
# ---------------------------------------------------------------------------

## Envoie un héros à un endroit (en cases) : il y va sans s'arrêter, puis en fait son nouveau poste.
func order_move(hero: Dictionary, pos: Vector2) -> void:
	if quest.get("duel", false) or not _obeys(hero):  # pas d'ordres pendant un duel
		return
	if _is_blocked(pos):
		pos = _free_cell_near(_cell_of(pos))
	hero["resting"] = false  # (un ordre du Maître met fin au repos de la rotation)
	# (« by » : un ordre du Maître ; arrivé, le héros tient ce poste, voir _follow_order et BattleTactics.hold)
	hero["order"] = {"kind": "move", "pos": pos, "by": "maitre"}
	hero["held"] = false
	hero["path"] = PackedVector2Array()


## Demande à un héros d'attaquer un ennemi précis, jusqu'à ce qu'il tombe.
func order_attack(hero: Dictionary, enemy: Dictionary) -> void:
	if quest.get("duel", false) or not _obeys(hero):  # pas d'ordres pendant un duel
		return
	hero["resting"] = false
	hero["held"] = false
	hero["order"] = {"kind": "attack", "target": enemy["id"]}
	hero["path"] = PackedVector2Array()


## Ordre « échanger de place » : le héros part se reposer à l'arrière, un allié frais prend son poste
## (voir _rotate). Comme tout ordre, il peut être refusé (_obeys).
func order_swap(hero: Dictionary) -> void:
	if quest.get("duel", false) or not can_swap(hero) or not _obeys(hero):
		return
	_rotate(hero)


## Vrai si ce héros peut recevoir l'ordre « échanger de place » (debout, pas déjà au repos ni en échange).
func can_swap(hero: Dictionary) -> bool:
	return hero["is_hero"] and hero["hp"] > 0 and hero["present"] and not hero["resting"] and time >= hero["swap_until"]


## Œil de faucon (C3, compétence active) : ordre du Maître ; le héros voit deux fois plus loin pendant
## HAWK_EYE_SECONDS (voir BattlePerception). Il l'active aussi de lui-même quand il ne voit plus l'ennemi.
func order_hawk_eye(hero: Dictionary) -> void:
	if quest.get("duel", false) or not can_hawk_eye(hero) or not _obeys(hero):
		return
	perception.activate_hawk_eye(hero)


func can_hawk_eye(hero: Dictionary) -> bool:
	return perception_on and perception != null and hero["is_hero"] and perception.can_hawk_eye(hero)


## Suit l'ordre du joueur, s'il y en a un. Renvoie faux quand il n'y a (plus) d'ordre à suivre.
func _follow_order(unit: Dictionary, foes: Array) -> bool:
	var order: Dictionary = unit.get("order", {})
	if order.is_empty():
		return false
	if order["kind"] == "move":
		if unit["pos"].distance_to(order["pos"]) > 0.15:
			_move_towards(unit, order["pos"])
			return true
		unit["post"] = order["pos"]  # arrivé : c'est son nouveau poste
		unit["order"] = {}
		# IA tactique (C3) : posté par le Maître, il tient sa position jusqu'à un nouvel ordre ou un danger grave ;
		# posté en hauteur par le Meneur (tireur sur un toit), aussi.
		if tactical_ai and (order.get("by", "") == "maitre" or (order.get("by", "") == "meneur" and is_high(unit))):
			unit["held"] = true
		elif tactical_ai and order.get("by", "") == "meneur":
			unit["leader_post"] = true  # il garde le placement du Meneur jusqu'à l'arrivée de l'ennemi
		return false
	var target: Dictionary = units[order["target"]]
	if target["hp"] <= 0:
		unit["order"] = {}  # la cible est tombée : ordre accompli
		return false
	unit["target_id"] = target["id"]
	if _in_reach(unit, target, unit["reach"]):
		_try_attack(unit, target, foes)
	else:
		_approach(unit, target)
	return true


## Le héros qui a le plus contribué (dégâts + soins), ou "" s'il n'y a aucun héros.
func mvp() -> String:
	var best: Dictionary = {}
	for fighter in heroes:
		if best.is_empty() or fighter["contribution"] > best["contribution"]:
			best = fighter
	return "" if best.is_empty() else best["name"]


## Un « combattant » : ses valeurs de combat, sa position et ses points de vie actuels.
## « source » garde le héros (ou l'ennemi) d'origine, pour le marquer mort après le combat.
## Les compétences sont une copie : elles ne sont recopiées sur le héros qu'à la fin
## (GameData.finish_tower_battle), et seulement s'il a survécu.
func _make_fighter(source: Dictionary, is_hero: bool) -> Dictionary:
	var stats := GameData.combat_stats(source)
	var fighter_class: String = source["class"]
	# L'arme d'un héros décide de sa portée et de sa façon de frapper (voir GameData.WEAPON_TYPES).
	# Les ennemis, les mages et les soigneurs n'ont pas d'arme : leur classe décide.
	var gear: Dictionary = GameData.gear_stats(source) if is_hero else {}
	# Compétences de promotion qui changent les valeurs de départ : Volonté de fer (vie), Coup précis (critiques).
	var skills: Array = source.get("skills", [])
	var max_hp := roundi(stats["hp"] * (1.0 + GameData.skill_level(skills, "Volonté de fer") * GameData.IRON_WILL_HP_PER_LEVEL))
	var crit_bonus := GameData.skill_level(skills, "Coup précis") * GameData.PRECISE_STRIKE_CRIT_PER_LEVEL \
		+ GameData.skill_level(skills, "Analyse froide") * GameData.COLD_ANALYSIS_PER_LEVEL
	var reach := RANGED_RANGE if fighter_class in ["Archer", "Mage", "Soigneur"] else MELEE_RANGE
	if not gear.is_empty():
		reach = gear["reach"]
	# Œil de faucon (synthèse) : les tireurs voient et tirent plus loin.
	if reach > MELEE_REACH_MAX:
		reach += GameData.skill_level(skills, "Œil de faucon") * GameData.HAWK_EYE_REACH_PER_LEVEL
	return {
		"name": source["name"],
		"class": fighter_class,
		"level": source["level"],
		"rarity": source.get("rarity", 1),
		"stars": "★".repeat(source.get("rarity", 1)),
		"is_hero": is_hero,
		"boss": source.get("boss", false),
		"hidden_level": not is_hero and quest["hidden_level"],  # niveau affiché « ? »
		"immortal": is_hero and GameData.is_immortal(source),  # mode dev seulement
		"source": source,
		"skills": source.get("skills", []).duplicate(true),
		"hp": max_hp,
		"max_hp": max_hp,
		# Attaque et défense sans la santé mentale : elle compte à chaque coup (voir _mind).
		"atk": stats["atk"] + gear.get("atk", 0),
		"def": stats["def"] + gear.get("def", 0),
		"spd": stats["spd"],
		"crit": stats["crit"] + gear.get("crit", 0.0) + crit_bonus,
		"second_wind_used": false,  # Second souffle : une seule fois par combat
		"mana": stats["mana"],                       # mages et soigneurs seulement (0 pour les autres)
		"max_mana": stats["mana"],
		"mana_regen": source["stats"]["int"] * MANA_REGEN_PER_INT if stats["mana"] > 0 else 0.0,
		"weapon": gear.get("type", ""),              # type d'arme ("" = pas d'arme)
		"weapon_skill": gear.get("skill", ""),       # compétence qui renforce cette arme
		"weapon_power": gear.get("power", 1.0),      # force de chaque coup
		"weapon_speed": gear.get("speed", 1.0),      # durée entre deux coups (0.7 = plus rapide)
		"shield": gear.get("shield", false),         # porte un bouclier
		"reach": reach,                              # portée d'attaque, en cases
		"ranged": reach > MELEE_REACH_MAX,           # tireur : reste derrière et recule au contact
		"present": false,          # sur le terrain (les renforts arrivent plus tard)
		"pos": Vector2.ZERO,       # position, en cases (0.5 = milieu de la première case)
		"cell": Vector2i.ZERO,     # sa case, et la hauteur où il se tient (niveaux, voir BattleMap et _land)
		"z": 0,
		"prev_pos": Vector2.ZERO,  # position au pas précédent (pour que l'écran glisse en douceur)
		"order": {},               # ordre du joueur en cours (voir order_move, order_attack)
		"post": Vector2.ZERO,      # poste que le héros tient
		"path": PackedVector2Array(),
		"path_timer": 0.0,
		"path_goal": Vector2i(-1, -1),  # case visée par son chemin (un nouveau but : nouveau chemin)
		"still": false,           # immobile pendant le dernier pas
		"blocked": 0.0,           # temps passé bloqué (quelqu'un d'immobile sur son chemin)
		"detour_until": 0.0,      # monstre : suit son propre chemin (autre ruelle) jusqu'à ce moment
		"near": false,            # monstre : assez près de sa cible pour prendre son propre chemin (voir _near)
		"slot": -1,               # case d'attaque réservée autour de sa cible (indice ; -1 : aucune)
		"slot_seen": -1.0,        # dernier moment où il s'en est servi
		"cooldown": randf_range(0.2, 0.8),  # temps avant la prochaine attaque
		"contribution": 0,  # dégâts infligés + soins donnés, pour désigner le MVP
		"killer": "",       # cause de la mort, s'il tombe
		# Saignement en cours : fois restantes, temps avant la prochaine, vie perdue, hémorragie ou non, cause.
		"bleed": {"ticks": 0, "timer": 0.0, "amount": 0, "heavy": false, "cause": ""},
		"has_bled": false,         # a saigné pendant ce combat (pour Résistance à la douleur)
		"awakening_tried": false,  # l'éveil n'est tenté qu'une fois par combat
		"death_door_tried": false, # la chance « aux portes de la mort » aussi
		"berserk": false,          # en rage (compétence Berserk, active à bascule : voir _berserk_think)
		"berserk_since": 0.0,      # moment où la rage a commencé
		"berserk_ordered": false,  # rage ordonnée par le Maître : il la garde jusqu'à l'ordre de la couper
		"berserk_hold_until": 0.0, # le Maître l'a fait couper : pas de reprise d'elle-même avant ce moment
		"berserk_changes": {},     # ce que la rage a ajouté (atk, def, spd, crit), retiré à la sortie
		"awakening_rage": false,   # rage d'éveil en cours (Berserk vient de s'éveiller : voir _awakening_rage)
		"refuse_death_until": 0.0, # rage d'éveil : ne peut pas tomber sous 1 point de vie avant ce moment
		# Migraine (après la rage) : jusqu'à ce moment du combat ; elle continue après (GameData.migraine_left).
		"migraine_until": GameData.migraine_left(source) if is_hero else 0.0,
		"person": is_hero,         # un héros (l'adversaire d'un duel aussi) : sa migraine est gardée à la fin
		# Endurance (voir GameData, tower.gd) : seuls les héros s'épuisent.
		# Personnalité (P2) : Constitution (réserve), Vitalité (récupération), Retenue 70 (dépense), Abandon 70
		# (jamais à 0). Un ennemi sans profil reste neutre.
		"stamina": PersonalityEngine.modified("stamina_max", source, GameData.STAMINA_MAX),
		"max_stamina": PersonalityEngine.modified("stamina_max", source, GameData.STAMINA_MAX),
		"stamina_cost": PersonalityEngine.modified("stamina_cost", source,
			GameData.STAMINA_NOVICE_FACTOR if is_hero and GameData.is_combat_novice(source) else 1.0),
		"stamina_regen": PersonalityEngine.modified("stamina_regen", source, GameData.STAMINA_REGEN_PER_SECOND),
		"stamina_floor": PersonalityEngine.modified("stamina_floor", source, 0.0),
		# Berserk selon le caractère (P2) : Colère (déclenche), Prudence (coupe tôt), Maîtrise de soi (bon moment).
		"berserk_trigger_hp": PersonalityEngine.modified("berserk_trigger_hp", source, GameData.BERSERK_DANGER_HP),
		"berserk_stop_hp": PersonalityEngine.modified("berserk_stop_hp", source, GameData.BERSERK_STOP_HP),
		"berserk_stop_mental": PersonalityEngine.modified("berserk_stop_mental", source, GameData.BERSERK_STOP_MENTAL),
		"exposed": {},             # sujets de stress vécus (sang, mort, boss...) : accoutumance en fin de combat
		"foes": {},                # sortes d'ennemis affrontées (coups, esquives) : ce qu'il en apprend (P2)
		"exhausted": false,        # endurance tombée à 0, pas encore remontée à STAMINA_RECOVERED
		# Rotation (voir order_swap) : se repose à l'arrière ; vulnérable pendant l'échange jusqu'à « swap_until ».
		"resting": false,
		"swap_until": 0.0,
		"lead_ready": 0.0,         # Meneur : prochain moment où il peut faire tourner la première ligne
		# Agonie (voir _announce_fall) : à 0 point de vie, un héros agonise jusqu'à « agony_until ».
		"agony": false,
		"agony_until": 0.0,
		"agony_cause": "",         # ce qui l'a mis à terre (cause de la mort s'il n'est pas sauvé)
		"rescue": 0.0,             # temps passé avec un allié à son côté (stabilisé à AGONY_RESCUE_SECONDS)
		"stabilized": false,       # sauvé de l'agonie : hors du combat, avec un peu de vie
		"embedded": false,         # arme plantée dans la plaie (agonie) : seule une potion peut le sauver
		"care": 0.0,               # soin d'urgence : temps passé avec un aidant à son côté pendant une hémorragie
		# Compétences exclusives (P2g) : événements vécus qui peuvent les éveiller en fin de combat ; Premier sang.
		"exclusive_events": {},
		"first_blood_used": false,
		"skill_news": [],          # compétences apprises ou améliorées, pour l'écran de fin
		"shots": 0,                # flèches tirées (font progresser Maîtrise de l'arc)
		# Usure de l'arme (voir GameData, tower.gd, WEAR_PER_HIT) : coups portés au contact pendant ce combat.
		"wear_hits": 0,
		"wear_noticed": false,
		# Carquois (héros à l'arc ; -1 : pas de carquois) : flèches restantes, tirées, ramassées.
		"arrows": GameData.QUIVER_SIZE if is_hero and gear.get("type", "") == "Arc" else -1,
		"arrows_spent": 0,
		"arrows_picked": 0,
		"arrow_progress": 0.0,     # flèche en train d'être ramassée (une entière à 1)
		"bow": {},                 # à court de flèches : la portée et la force de son arc, rendues quand il en retrouve
		# Ce qu'il a fait (croissance de ses stats au prochain niveau, voir GameData.add_activity) :
		# coups portés (Force), esquives et tirs (Dextérité), coups encaissés (Santé), sorts et soins (Intelligence).
		"acts": {"str": 0, "dex": 0, "vit": 0, "int": 0},
		# Expérience méritée (phase 1.2) : a-t-il porté, reçu (ou esquivé) un coup, ou soigné ? Sinon, pas d'XP.
		"engaged": false,
		"base_name": source.get("base_name", source["name"]),  # nom sans lettre (Gobelin, pas Gobelin A)
		"wave": source.get("wave", 0),  # survie : sa vague (voir current_wave) ; 0 = sur le terrain dès le début
		# Élément de la magie d'un mage (un mage sans élément noté fait du feu).
		"element": source.get("element", "Feu" if fighter_class == "Mage" else ""),
		"kills": [],               # ennemis achevés : [{"name", "boss"}] (pour Tueur de gobelins)
		# Journal compact du combat (héros seulement, voir _journal) : matière de la bibliothèque et du mémorial.
		"journal": [],
		"journal_counts": {"hits_given": 0, "hits_taken": 0, "dodges": 0, "kills": 0},
		"met": {},                 # ennemis déjà rencontrés (premier contact noté une fois)
		"took_fire": false,        # a subi des dégâts de feu (pour Résistance aux flammes)
		# Étape D : éléments subis (feu, vent, froid : chance d'en apprendre la résistance), ce que le héros a vécu
		# (« pris au contact », « tirs subis »...) qui décide de ce qu'il voudra travailler (GameData.merge_practice),
		# et ses coups portés avec la dague de secours (Maîtrise de la dague).
		"took_elements": {},
		"practice": {},
		"dagger_hits": 0,
		# Santé mentale, suivie en direct (voir _stress) ; recopiée sur le héros à la fin du combat.
		"mental": GameData.mental(source) if is_hero else GameData.MENTAL_MAX,
		"sulk_until": 0.0,         # a refusé un ordre : ignore les ordres jusqu'à ce moment
		"ruptured": false,         # rupture déjà arrivée dans ce combat (une seule fois)
		"was_broken": is_hero and GameData.is_broken(source),  # parti « En rupture » : risque la mort de stress
		"panic": "",               # effondrement en cours : "flee" (fuit) ou "frenzy" (frappe au hasard)
		"panic_until": 0.0,        # fin de la panique
		"panic_target": -1,        # frénésie : la cible du moment (n'importe qui)
		"panic_retarget": 0.0,     # frénésie : moment où il change de cible
		"flee_to": Vector2.ZERO,   # fuite : là où il court
		# Peur (voir _scare et GameData, personality.gd) : tout héros peut prendre peur face à une menace.
		"fearful": is_hero and not quest.get("duel", false),
		"scared": false,           # a déjà pris peur dans ce combat (ensuite, seule une blessure grave la ramène)
		"fear_until": 0.0,         # a peur jusqu'à ce moment (qu'il fuie ou qu'il se batte contre sa peur)
		"fear_flee": false,        # sa fuite en cours vient de la peur (pas d'un effondrement)
		"fear_comfort": 0.0,       # temps passé à côté d'un allié qui le rassure (la peur se lève à FEAR_LIFT_SECONDS)
		"saw_enemy": false,        # a déjà vu un ennemi à portée (la vue de l'ennemi peut faire peur)
		"was_hit": false,          # a déjà été blessé dans ce combat (la première blessure fait peur)
		"mind_news": [],           # traits révélés, ruptures : pour la fenêtre « Personnalité » de fin
		"bonds": {},               # liens avec les autres héros de l'équipe : {numéro du pion: palier}
		# Perception (C3, voir BattlePerception) : où il regarde (les héros partent du bas et regardent vers le
		# haut), le bout de ses bâtonnets, qui il voit et entend, ce qu'il sait de chaque ennemi.
		"facing": Vector2(0, -1) if is_hero else Vector2(0, 1),
		"rays": PackedVector2Array(),
		"sees": {},
		"hears": {},
		"knows": {},
		"glance_at": 0.0,          # prochain regard en arrière (Prudence, Méfiance)
		"hawk_until": 0.0,         # Œil de faucon actif jusqu'à ce moment
		"hawk_ready": 0.0,         # Œil de faucon de nouveau possible à ce moment
		# IA tactique (C3, voir BattleTactics) : son plan (attitude, case, cible, raisons), le prochain plan, posté
		# par le Maître (il tient sa place), ses poids et seuils pour ce combat (copiés de ses habitudes), combien
		# de critères il voit et de cases il étudie, depuis quand il attend.
		"tactic": {},
		"tactic_due": 0.0,
		"held": false,
		"tw": TacticsData.BASE_WEIGHTS.duplicate(),
		"tt": TacticsData.BASE_THRESHOLDS.duplicate(),
		"t_criteria": TacticsData.CRITERIA.size(),
		"t_cells": TacticsData.CELLS_MAX,
		"cover_since": -1.0,       # sous le feu depuis ce moment (se couvrir, puis aller chercher le tireur)
		"cover_from": -1,          # le tireur qui le prend pour cible (numéro ; -1 : aucun)
		"t_last_dist": -1.0,       # distance de sa cible au dernier plan (vient-elle vers lui ?)
		"engaged_t": -1.0,         # moment où il a connu son premier ennemi
		"last_attack_t": -100.0,   # moment de son dernier coup (ou tir, sort, soin)
		"hurt_hero_at": -100.0,    # dernier moment où il a blessé un héros (colère, cible « qui fait mal »)
		"hurt_hero_id": -1,        # le héros blessé
		# Étape E (voir BattleAlert, BattleExplore) : son pas (1 : normal ; ronde, exploration prudente : moins), son
		# état de vigilance (monstres : sommeil, repos, guet, ronde, poste, embusque, fouille, alerte), sa place et son
		# état de départ, sa ronde, le moment où il a repéré quelqu'un, le bruit qu'il va voir, son dernier cri.
		"pace": 1.0,
		"state": "alerte",
		"home_state": "alerte",
		"home_pos": Vector2.ZERO,
		"home_facing": Vector2(0, 1),
		"route": [],
		"route_i": 0,
		"spot_t": -1.0,
		"search": Vector2.ZERO,
		"search_until": -1.0,
		"alert_t": -100.0,
		# Étape E, point 3 : sa discrétion (1 : normal ; les monstres le remarquent à cette part de leur vue et de leur
		# ouïe, voir BattleExplore.stealth_of), et pris dans un piège jusqu'à ce moment.
		"stealth": 1.0,
		"trapped_until": 0.0,
		# Étape E, point 4 (voir BattleTies) : en repli après avoir abandonné un allié, jusqu'à ce moment ; l'a déjà fait.
		"abandon_until": 0.0,
		"abandoned": false,
	}


# ---------------------------------------------------------------------------
# Un pas de temps
# ---------------------------------------------------------------------------

func _step() -> void:
	_update_crowd()
	if perception_on:
		perception.tick()
	alert.tick()
	_refresh_costs()
	_update_formations()
	if not _defense_organized and not alley_exits.is_empty():
		_organize_defense()
	_call_reinforcements()
	_check_boss_arrival()
	for hero in heroes:
		if hero["agony"]:
			_agony_tick(hero)
	_assign_helpers()
	for hero in heroes:
		if _needs_help(hero) and not hero["agony"]:
			_care_tick(hero)
	var order := _alive(units)
	order.shuffle()
	for unit in order:
		if unit["hp"] <= 0:
			continue  # tombé plus tôt pendant ce pas
		_bleed_tick(unit)
		unit["mana"] = minf(unit["max_mana"], unit["mana"] + unit["mana_regen"] * TICK)
		if unit["berserk"] and unit["hp"] > 0:
			_berserk_tick(unit)
		if unit["is_hero"] and unit["fearful"] and unit["hp"] > 0:
			_fear_tick(unit)
		if unit["person"] and unit["hp"] > 0:
			_stamina_tick(unit)
		if unit["arrows"] >= 0 and unit["hp"] > 0:
			_arrow_tick(unit)
		if unit["is_hero"] and unit["hp"] > 0 and GameData.has_trait(unit["source"], "Meneur"):
			_lead(unit)
		if unit["person"] and unit["hp"] > 0:
			_berserk_think(unit)
			if perception_on:
				perception.hawk_eye_think(unit)
		if unit["hp"] > 0:
			unit["cooldown"] -= TICK
			_think(unit)
		if _check_end():
			return
	_check_traps()
	_separate()
	_land()


## Survie par vagues (voir GameData, tower.gd, SURVIVAL_WAVES) : la vague en cours (0 = la première).
## Une nouvelle vague arrive toutes les quest["wave_seconds"] du compte à rebours (pas avant le premier
## contact). Sans vagues (autres quêtes) : toujours 0.
func current_wave() -> int:
	if quest.get("wave_seconds", 0.0) <= 0.0 or clock_start < 0:
		return 0
	return mini(quest["waves"] - 1, int(clock_time() / quest["wave_seconds"]))


## Au besoin, un ennemi en réserve entre par le haut de la carte à la place d'un ennemi tombé.
## En survie, seulement ceux des vagues déjà arrivées ; chaque nouvelle vague est annoncée.
func _call_reinforcements() -> void:
	var wave := current_wave()
	if wave > _wave_announced:
		_wave_announced = wave
		var text := "Vague %d sur %d : la horde revient !" % [wave + 1, quest["waves"]]
		if wave == quest["waves"] - 1 and enemies.any(func(e): return e["boss"]):
			text += " Le chef est avec elle."
		_log(text, "reinforce")
		_alert("Vague %d" % (wave + 1), [text], wave == quest["waves"] - 1)
	var on_field := 0
	for enemy in enemies:
		if enemy["present"] and enemy["hp"] > 0:
			on_field += 1
	var waiting := _reserve().filter(func(e): return e["wave"] <= wave)
	if waiting.is_empty() or on_field >= ENEMY_SLOTS:
		_free_since.clear()
		return
	var free_places := ENEMY_SLOTS - on_field
	for place in free_places:
		if not _free_since.has(place):
			_free_since[place] = time
	var arrivals := []
	for place in _free_since.keys():
		if time - _free_since[place] >= REINFORCE_DELAY and not waiting.is_empty():
			var enemy: Dictionary = waiting.pop_front()
			_spawn_enemy(enemy, map_data.get("entry_row", MapGenerator.ENTRY_ROW))
			alert.on_spawn(enemy)  # (étape E : sans alarme, il sort du camp, ou fait sa ronde)
			arrivals.append(enemy["name"])
			_free_since.erase(place)
	if not arrivals.is_empty():
		var text := "Des renforts arrivent : %s." % ", ".join(arrivals)
		if not waiting.is_empty():
			text += " (%d encore en approche)" % waiting.size()
		_log(text, "reinforce")


## Les ennemis qui ne sont pas encore entrés sur le terrain.
func _reserve() -> Array:
	return enemies.filter(func(e): return not e["present"])


## Fin du combat ? (victoire, défaite, cité tombée)
func _check_end() -> bool:
	if finished:
		return true
	if _alive(enemies).is_empty() and _reserve().is_empty():
		victory = true
		_log("Victoire ! Il ne reste plus un seul ennemi.")
	elif _alive(heroes).is_empty():
		_log("Défaite... toute l'équipe est tombée.")
	elif quest["walls"] > 0 and walls <= 0:
		_log("Les remparts cèdent : la cité est tombée !")
	else:
		return false
	_finish()
	return true


## Ce que fait un combattant pendant ce pas : choisir sa cible, s'en approcher, frapper, reculer...
func _think(unit: Dictionary) -> void:
	var foes := _alive(enemies if unit["is_hero"] else heroes)
	var allies := _alive(heroes if unit["is_hero"] else enemies)
	# Perception (C3) : on ne vise que les ennemis que l'on connaît (vus, entendus, appris d'un allié, ou encore
	# en mémoire). Les ordres du Maître, eux, peuvent viser n'importe quel ennemi (le Maître voit tout l'écran).
	var known := foes if not perception_on else foes.filter(func(foe): return perception.knows(unit, foe))
	unit["pace"] = 1.0
	unit["stealth"] = 1.0

	# Étape E : un monstre qui ne chasse pas encore (au repos, endormi, de garde, en ronde, embusqué...) : voir
	# BattleAlert. Une fois en alerte, il se bat comme avant.
	if not unit["is_hero"] and alert.think(unit, known):
		return

	# Un héros en pleine panique (rupture) n'écoute plus rien.
	if unit["is_hero"] and unit["panic"] != "":
		if panicking(unit):
			_panic_think(unit, foes)
			return
		unit["panic"] = ""
		unit["fear_flee"] = false
		if not afraid(unit) and unit["ruptured"]:  # (la fin d'une fuite de peur n'est pas annoncée)
			_log("%s reprend ses esprits." % _name_with_stars(unit), "disobey")

	# Un ordre du joueur passe avant tout.
	if unit["is_hero"] and _follow_order(unit, foes):
		return

	# (étape E, point 4) Un égoïste lâche en danger abandonne un allié et se replie (voir BattleTies.abandon).
	if unit["is_hero"] and ties.abandon(unit, foes):
		return

	# Un allié à l'agonie (ou en hémorragie) à secourir : il y va (voir _assign_helpers).
	if unit["is_hero"] and _help(unit):
		return

	# Au repos à l'arrière (rotation) : il ne combat que si un ennemi vient au contact.
	if unit["resting"] and not foes.any(func(foe): return unit["pos"].distance_to(foe["pos"]) <= GameData.STAMINA_CONTACT_RANGE):
		return

	# Soigneur : un allié blessé passe avant tout (s'il lui reste assez de mana pour soigner).
	if unit["class"] == "Soigneur" and unit["mana"] >= HEAL_MANA_COST:
		var wounded := _most_wounded(allies)
		if not wounded.is_empty():
			if _in_reach(unit, wounded, RANGED_RANGE):
				_try_heal(unit, wounded)
			else:
				_move_towards(unit, wounded["pos"])
			return

	# Défense : un ennemi va au pied du rempart et le frappe, sauf si un héros lui barre la route (un héros
	# qu'il peut atteindre : pas un tireur sur le chemin de ronde, deux niveaux plus haut).
	if not unit["is_hero"] and quest["walls"] > 0:
		var reachable := known.filter(func(foe): return absi(height_of(foe) - height_of(unit)) <= GameData.MELEE_MAX_LEVELS)
		var nearest := _nearest(unit, reachable)
		if nearest.is_empty() or unit["pos"].distance_to(nearest["pos"]) > 2.5:
			var wall_row: int = map_data.get("wall_row", -1)
			if wall_row < 0:
				wall_row = GRID_H  # (ancienne carte sans rempart : le bas de la carte)
			if unit["pos"].y >= wall_row - 1.25:
				if unit["cooldown"] <= 0:
					unit["cooldown"] = _attack_time(unit)
					walls = maxi(0, walls - 1)
			else:
				_move_towards(unit, Vector2(unit["pos"].x, wall_row - 0.5))
			return
		if not unit["ranged"]:
			# Un héros lui barre la route : c'est lui qu'il attaque (pas un autre, plus loin : il hésiterait sans
			# fin entre le rempart et sa cible).
			unit["target_id"] = nearest["id"]
			if _in_reach(unit, nearest, unit["reach"]):
				_try_attack(unit, nearest, foes)
			else:
				_approach(unit, nearest)
			return

	# Protecteur : un allié proche en danger passe avant l'ennemi ; il va se placer à son côté. (Étape E, point 4 : sans
	# le trait, un héros fait de même pour un ami ou un frère d'armes, voir BattleTies.ward_of.)
	if unit["is_hero"] and not quest.get("duel", false):
		var ward := ties.ward_of(unit)
		if not ward.is_empty() and unit["pos"].distance_to(ward["pos"]) > GameData.PROTECT_GUARD_RANGE * 0.8:
			_move_towards(unit, ward["pos"])
			return

	if foes.is_empty():
		return
	# IA tactique (C3) : posté par le Maître, il tient sa place ; libre, il choisit son attitude et sa case selon ce
	# qu'il sait (voir BattleTactics). Sans elle (tactical_ai faux) : l'ancien comportement, plus bas.
	if unit["is_hero"] and tactical_ai and not quest.get("duel", false):
		if unit["held"] and tactics.hold(unit, known, foes):
			return
		# (étape E) des monstres qui ne l'ont pas vu : l'équipe se rassemble avant d'attaquer (BattleExplore.stalk)
		if explore.stalk(unit, known):
			return
		# (étape E, point 4) un opportuniste se sert d'un allié comme appât (voir BattleTies.flank)
		if ties.flank(unit, known, foes):
			return
		if tactics.think(unit, known, foes, allies):
			return
	if known.is_empty():
		_unaware(unit, foes)
		return
	var target := _choose_target(unit, known, allies)
	unit["target_id"] = target["id"]

	# Posté sur une hauteur (le Maître l'y a envoyé) : il tient la position, sans courir après les ennemis ;
	# il frappe ou tire sur ceux qui sont à sa portée (la cible choisie d'abord).
	if unit["is_hero"] and is_high(unit) and map.walkable(_cell_of(unit["post"])) and map.height_at(_cell_of(unit["post"])) > 0:
		if not _in_reach(unit, target, unit["reach"]):
			var near := known.filter(func(foe): return _in_reach(unit, foe, unit["reach"]))
			target = _nearest(unit, near) if not near.is_empty() else {}
		if not target.is_empty():
			unit["target_id"] = target["id"]
			_try_attack(unit, target, foes)
		return

	# Un héros tient son poste tant que les ennemis sont loin.
	var target_pos: Vector2 = target["pos"] if not perception_on else perception.known_pos(unit, target)
	if unit["is_hero"] and unit["pos"].distance_to(target_pos) > ENGAGE_DISTANCE:
		if unit["pos"].distance_to(unit["post"]) > 0.3:
			_move_towards(unit, unit["post"])
		return

	# Une cible qu'il ne connaît plus que de mémoire : il va voir à sa dernière place connue ; elle n'y est plus ?
	# Il l'oublie.
	if perception_on and not perception.knows_now(unit, target):
		if unit["pos"].distance_to(target_pos) <= 1.0:
			unit["knows"].erase(target["id"])
		else:
			_move_towards(unit, target_pos)
		return

	if unit["ranged"]:
		# Un tireur recule quand un ennemi arrive au contact.
		var closest := _nearest(unit, known)
		if unit["pos"].distance_to(closest["pos"]) < 1.6:
			_step_away(unit, closest["pos"])
		if _in_reach(unit, target, unit["reach"]):
			_try_attack(unit, target, foes)
		else:
			_approach(unit, target)
	else:
		if _in_reach(unit, target, unit["reach"]):
			_try_attack(unit, target, foes)
		else:
			_approach(unit, target)


## Le choix de la cible, selon la classe. Sinon : l'adversaire le plus proche,
## en évitant ceux que plusieurs alliés attaquent déjà (pour ne pas tous s'agglutiner).
func _choose_target(unit: Dictionary, foes: Array, allies: Array) -> Dictionary:
	if unit["class"] == "Assassin":
		return _weakest(foes)
	# Un chevalier proche attire les coups.
	for foe in foes:
		if foe["class"] == "Chevalier" and unit["pos"].distance_to(foe["pos"]) <= TAUNT_DISTANCE:
			return foe
	var result: Dictionary = {}
	var best := INF
	for foe in foes:
		var crowd := 0
		for ally in allies:
			if ally["id"] != unit["id"] and ally.get("target_id", -1) == foe["id"]:
				crowd += 1
		var score: float = unit["pos"].distance_to(foe["pos"]) + crowd * CROWD_PENALTY
		# Un monstre se jette sur un héros qui fuit (une proie qui tourne le dos).
		if not unit["is_hero"] and _fleeing(foe):
			score -= PREY_BONUS
		if score < best:
			best = score
			result = foe
	return result


## Perception (C3) : il ne connaît aucun ennemi. Un héros explore le terrain (étape E, voir BattleExplore ; en horde,
## ou posté par le Maître : il tient son poste, il attend de voir venir) ; un monstre en alerte avance vers le camp
## des héros (la horde sait où ils sont, pas qui viser : il ne frappe pas avant de voir).
func _unaware(unit: Dictionary, foes: Array) -> void:
	unit["target_id"] = -1
	if unit["is_hero"]:
		if explore.think(unit):
			return
		if unit["pos"].distance_to(unit["post"]) > 0.3:
			_move_towards(unit, unit["post"])
		return
	var nearest := _nearest(unit, foes)
	if not nearest.is_empty():
		_approach(unit, nearest)


## Attaque surprise (C3) : la cible ne voit pas l'attaquant de ses propres yeux (il n'est dans aucun de ses
## bâtonnets ; l'entendre ne suffit pas). Pas en duel (les deux se font face et se surveillent).
func _surprise(attacker: Dictionary, target: Dictionary) -> bool:
	return perception_on and not quest.get("duel", false) and target["present"] and not perception.sees(target, attacker)


## Étape E, point 3 : assassinat. Un héros frappe un monstre qui ne se doute de rien (pas en alerte, l'alarme n'est pas
## donnée) et qui ne voit pas venir le coup : la force du coup est multipliée (voir GameData, tower.gd). Renvoie le
## multiplicateur (1 : pas d'assassinat). Pas les sorts (ils touchent toute une zone).
func _assassination(attacker: Dictionary, target: Dictionary, kind: String, surprise: bool) -> float:
	if not surprise or not attacker["is_hero"] or target["is_hero"] or alert.alarm or target["state"] == "alerte":
		return 1.0
	if kind == "arrow":
		return GameData.ASSASSINATE_RANGED_POWER
	if kind != "hit":
		return 1.0
	if attacker["weapon"] == "Dague" or attacker["class"] == "Assassin":
		return GameData.ASSASSINATE_BLADE_POWER
	return GameData.ASSASSINATE_POWER


## Étape E, point 3 : un héros pose un piège sur une case (voir BattleExplore._work_trap).
func place_trap(hero: Dictionary, cell: Vector2i) -> void:
	traps.append({"cell": cell, "by": hero["name"], "atk": hero["atk"], "id": hero["id"]})
	traps_placed += 1
	_log("%s pose un piège." % hero["name"])


## Un monstre qui marche sur un piège le déclenche : dégâts, immobilisé un moment (pas un chef), et ça s'entend.
func _check_traps() -> void:
	for trap in traps.duplicate():
		for monster in _alive(enemies):
			if _cell_of(monster["pos"]) == trap["cell"]:
				_trigger_trap(trap, monster)
				break


func _trigger_trap(trap: Dictionary, monster: Dictionary) -> void:
	traps.erase(trap)
	traps_sprung += 1
	var factor := 0.5 if monster["boss"] else 1.0
	var amount := mini(maxi(1, roundi((trap["atk"] * GameData.TRAP_POWER - monster["def"] * 0.5) * factor)), monster["hp"])
	monster["hp"] -= amount
	if not monster["boss"]:
		monster["trapped_until"] = time + GameData.TRAP_HOLD
	_start_clock()
	_effect("bleed", monster, monster, "piège ! -%d" % amount, true)
	_log("%s tombe dans le piège de %s !" % [monster["name"], trap["by"]], "reinforce")
	var trapper: Dictionary = units[trap["id"]]
	if monster["hp"] <= 0:
		_announce_fall(monster, "pris au piège de %s" % trap["by"])
		trapper["kills"].append({"name": monster["base_name"], "boss": monster["boss"]})
		trapper["journal_counts"]["kills"] += 1
	else:
		alert.raise(monster, {})
	alert.noise(monster["pos"], GameData.NOISE_FIGHT)


## Portée d'un combattant, pour les formations (voir GameData, tower.gd, RANGE_COVER_BONUS) :
## "longue" (arc, magie), "moyenne" (lance, fouet) ou "courte" (épée, dague, sans arme).
func range_band(unit: Dictionary) -> String:
	if unit["ranged"] or unit["class"] in ["Mage", "Soigneur"]:
		return "longue"
	if unit["weapon"] in GameData.WEAPON_TYPES:
		return GameData.WEAPON_TYPES[unit["weapon"]]["band"]
	return "courte"


# ---------------------------------------------------------------------------
# Attaques et soins
# ---------------------------------------------------------------------------

func _try_attack(attacker: Dictionary, target: Dictionary, foes: Array) -> void:
	if attacker["cooldown"] > 0 or time < attacker["swap_until"]:
		return  # (pendant un échange de place, il ne frappe pas)
	attacker["cooldown"] = _attack_time(attacker)
	attacker["last_attack_t"] = time
	_spend_stamina(attacker, GameData.STAMINA_ATTACK_COST)
	match attacker["class"]:
		"Mage":
			if attacker["mana"] >= SPELL_MANA_COST:
				# Le sort touche la cible et tous les ennemis autour d'elle.
				attacker["mana"] -= SPELL_MANA_COST
				for foe in foes:
					if foe["pos"].distance_to(target["pos"]) <= SPELL_RADIUS:
						_hit(attacker, foe, 0.7, false, "spell")
				# Étape D : le sort d'un mage héros éclabousse aussi ses alliés trop près de la cible (_splash).
				if attacker["is_hero"]:
					for ally in _alive(heroes):
						if ally["id"] != attacker["id"] and ally["pos"].distance_to(target["pos"]) <= SPELL_RADIUS:
							_splash(attacker, ally)
			else:
				# À court de mana : un petit trait de magie, sur la cible seulement.
				_hit(attacker, target, MANA_BOLT_POWER, false, "bolt")
		"Soigneur":
			_hit(attacker, target, 1.0, false, "spell")
		_:
			# Attaque surprise (C3) : plus de chances de critique (voir aussi _damage : ni esquive ni parade).
			var surprise_crit := GameData.SURPRISE_CRIT_BONUS if _surprise(attacker, target) else 0.0
			if attacker["ranged"]:
				# Un tir (arc). Les archers visent mieux : +25 % de critiques, et leurs critiques font x2.
				var archer: bool = attacker["class"] == "Archer"
				var critical: bool = randf() < attacker["crit"] * _fear(attacker) + (0.25 if archer else 0.0) + surprise_crit
				var power := (2.0 if archer else 1.5) if critical else 1.0
				_hit(attacker, target, power * attacker["weapon_power"], critical, "arrow")
				if attacker["is_hero"]:
					attacker["shots"] += 1
				_use_arrows(attacker, 1)
			else:
				# Un coup au contact (épée, lance, dague, fouet...).
				var power := 1.0
				var critical := false
				match attacker["class"]:
					"Guerrier":
						power = 1.2  # frappe fort
					"Assassin":
						pass
					_:
						critical = randf() < attacker["crit"] * _fear(attacker) + surprise_crit
						power = 1.5 if critical else 1.0
				# (Guerrier, Assassin : pas de critique d'ordinaire ; par surprise, oui.)
				if surprise_crit > 0.0 and attacker["class"] in ["Guerrier", "Assassin"] and randf() < surprise_crit:
					critical = true
					power *= 1.5
				_hit(attacker, target, power * attacker["weapon_power"] * _wear(attacker), critical, "hit")


## Usure (voir GameData, tower.gd, WEAR_PER_HIT) : un coup de plus avec son arme au contact ; renvoie la force
## qui lui reste (1 = neuve, jamais sous WEAR_MIN_FACTOR). L'arc ne s'émousse pas, la dague de secours non plus.
func _wear(unit: Dictionary) -> float:
	if not unit["is_hero"] or unit["weapon"] in ["", "Arc"]:
		return 1.0
	unit["wear_hits"] += 1
	var factor := wear_factor(unit)
	if factor <= GameData.WEAR_NOTICE and not unit["wear_noticed"]:
		unit["wear_noticed"] = true
		_log("L'arme de %s s'émousse : ses coups portent moins." % unit["name"], "disobey")
	return factor


## Ce qu'il reste de la force de son arme après les coups de ce combat (1 = neuve).
func wear_factor(unit: Dictionary) -> float:
	return maxf(GameData.WEAR_MIN_FACTOR, 1.0 - unit["wear_hits"] * GameData.WEAR_PER_HIT)


## Carquois : « count » flèches tirées. À court, l'archer tire sa dague de secours et se bat au contact.
func _use_arrows(unit: Dictionary, count: int) -> void:
	if unit["arrows"] < 0:
		return  # pas de carquois (monstre, mage...)
	unit["arrows"] = maxi(0, unit["arrows"] - count)
	unit["arrows_spent"] += count
	if unit["arrows"] == 0 and unit["bow"].is_empty():
		unit["bow"] = {"reach": unit["reach"], "power": unit["weapon_power"], "skill": unit["weapon_skill"]}
		unit["reach"] = MELEE_RANGE
		unit["ranged"] = false
		unit["weapon_power"] = GameData.OUT_OF_ARROWS_POWER
		unit["weapon_skill"] = "Maîtrise de la dague"  # (étape D : sa dague de secours profite de cette maîtrise ; avant, aucune)
		_log("%s n'a plus de flèches : il tire sa dague de secours." % _name_with_stars(unit), "disobey")


## Carquois, chaque pas : loin des ennemis, l'archer ramasse des flèches (une partie de celles qu'il a tirées).
func _arrow_tick(unit: Dictionary) -> void:
	if unit["arrows"] >= GameData.QUIVER_SIZE \
			or unit["arrows_picked"] >= int(unit["arrows_spent"] * GameData.ARROW_RECOVER_SHARE):
		return
	if _alive(enemies).any(func(foe): return unit["pos"].distance_to(foe["pos"]) <= GameData.ARROW_PICKUP_CALM):
		return
	unit["arrow_progress"] += GameData.ARROW_PICKUP_PER_SECOND * TICK
	if unit["arrow_progress"] < 1.0:
		return
	unit["arrow_progress"] -= 1.0
	unit["arrows"] += 1
	unit["arrows_picked"] += 1
	if not unit["bow"].is_empty():
		# Il retrouve son arc.
		unit["reach"] = unit["bow"]["reach"]
		unit["weapon_power"] = unit["bow"]["power"]
		unit["weapon_skill"] = unit["bow"]["skill"]
		unit["ranged"] = true
		unit["bow"] = {}
		_log("%s ramasse des flèches et reprend son arc." % unit["name"])


## Ordre « Tir de barrage » possible ? Un héros à l'arc, debout, avec des flèches et des ennemis à sa portée.
func can_barrage(hero: Dictionary) -> bool:
	return hero["is_hero"] and hero["hp"] > 0 and hero["present"] and hero["arrows"] > 0 \
		and not hero["resting"] and not _barrage_targets(hero).is_empty()


func _barrage_targets(hero: Dictionary) -> Array:
	return _alive(enemies).filter(func(foe): return _in_reach(hero, foe, hero["reach"]))


## Ordre « Tir de barrage » : toutes ses flèches d'un coup, au hasard sur les ennemis à sa portée (chacune à
## BARRAGE_POWER d'un tir). Il se retrouve sans flèches. Comme tout ordre, il peut être refusé (_obeys).
func order_barrage(hero: Dictionary) -> void:
	if quest.get("duel", false) or not can_barrage(hero) or not _obeys(hero):
		return
	var count: int = hero["arrows"]
	var fired := 0
	for i in count:
		var targets := _barrage_targets(hero)
		if targets.is_empty():
			break
		_hit(hero, targets.pick_random(), GameData.BARRAGE_POWER * hero["weapon_power"], false, "arrow")
		fired += 1
	hero["shots"] += fired
	hero["cooldown"] = _attack_time(hero)
	hero["resting"] = false
	_spend_stamina(hero, GameData.BARRAGE_STAMINA_COST)
	_log("%s lâche un tir de barrage : %d flèches !" % [_name_with_stars(hero), fired], "awaken")
	_use_arrows(hero, count)


## Un coup : dégâts, effet à l'écran, saignement, situation critique, chute.
func _hit(attacker: Dictionary, target: Dictionary, power: float, critical: bool, kind: String) -> void:
	var surprise := _surprise(attacker, target)
	# Vigilance (exclusive, P2g) : une chance de voir venir l'attaque surprise (tirée seulement s'il l'a).
	var vigilance := GameData.exclusive_effect(target["skills"], "Vigilance") if surprise else 0.0
	if vigilance > 0.0 and randf() < vigilance:
		surprise = false
	# (étape E, point 3) Un monstre qui ne se doute de rien : assassinat (voir _assassination).
	var assassinate := _assassination(attacker, target, kind, surprise)
	if kind == "hit":
		power *= ties.rear_factor(attacker, target)  # (étape E, point 4) à revers
	if assassinate > 1.0:
		power *= assassinate
		critical = critical or assassinate >= GameData.ASSASSINATE_BLADE_POWER
	var amount := _damage(attacker, target, power, critical, kind, surprise)
	var silent := false
	if assassinate > 1.0 and amount >= 0:
		# Au moins une part de sa vie (voir GameData.ASSASSINATE_HP_SHARE).
		var share: float = GameData.ASSASSINATE_HP_SHARE["tir" if kind == "arrow" else \
			("lame" if assassinate >= GameData.ASSASSINATE_BLADE_POWER else "coup")] * (0.5 if target["boss"] else 1.0)
		var extra := mini(target["hp"], roundi(target["max_hp"] * share) - amount)
		if extra > 0:
			target["hp"] -= extra
			attacker["contribution"] += extra
			amount += extra
		assassinations += 1
		attacker["journal_counts"]["assassinations"] = attacker["journal_counts"].get("assassinations", 0) + 1
		silent = target["hp"] <= 0
		if silent:
			_log(("%s abat %s d'une flèche avant qu'il ne comprenne." if kind == "arrow" else "%s égorge %s sans un bruit.") \
				% [attacker["name"], target["name"]], "awaken")
	# Événements qui peuvent éveiller une exclusive en fin de combat (P2g) : surpris, premier coup du combat.
	if surprise and amount >= 0 and target["is_hero"]:
		target["exclusive_events"]["surprised"] = true
	if attacker["is_hero"] and amount >= 0 and not _first_blood_given:
		_first_blood_given = true
		attacker["exclusive_events"]["first_blood"] = true
	attacker["engaged"] = true  # il a pris part au combat (expérience méritée)
	target["engaged"] = true
	# Activité (croissance) : l'esquive exerce la Dextérité ; le coup porté, la stat de l'attaque ;
	# le coup encaissé, la Santé.
	if amount == -1:
		target["acts"]["dex"] += 1
	elif amount >= 0:
		attacker["acts"][ACT_STAT.get(kind, "str")] += 1
		target["acts"]["vit"] += 1
	_note_practice(attacker, target, amount, kind)  # (étape D) ce que le héros vit, sans tirage
	var text := "esquive !" if amount == -1 else ("paré !" if amount == -3 else ("couvert !" if amount < 0 else "-%d" % amount))
	if surprise and amount >= 0:
		text = ("assassinat ! " if assassinate > 1.0 else "surprise ! ") + text
		surprises["heroes" if target["is_hero"] else "enemies"] += 1
		if target["is_hero"]:
			target["journal_counts"]["surprised"] = target["journal_counts"].get("surprised", 0) + 1
	_effect(kind, attacker, target, text, critical and amount >= 0)
	_journal_hit(attacker, target, maxi(amount, -1), critical)
	if kind == "hit" and amount > 0:
		_push(attacker, target, amount, critical)
	if amount > 0 and target["is_hero"] and not attacker["is_hero"]:
		attacker["hurt_hero_at"] = time  # (IA tactique : la colère, le tireur qui fait mal)
		attacker["hurt_hero_id"] = target["id"]
	if target["hp"] <= 0 and target["killer"] == "":
		_announce_fall(target, "tué par %s (niv. %d)" % [attacker["name"], attacker["level"]], false, {"attacker": attacker, "kind": kind})
		if attacker["is_hero"]:
			attacker["kills"].append({"name": target["base_name"], "boss": target["boss"]})
			attacker["journal_counts"]["kills"] += 1
			_journal(attacker, "kill", {"with": target["base_name"], "boss": target["boss"]})
	if not silent:
		alert.on_hit(attacker, target)  # (étape E) le coup s'entend ; un monstre frappé passe en alerte


## Étape D : un allié éclaboussé par le sort d'un mage de son équipe : FRIENDLY_SPLASH de l'attaque du mage, moins sa
## résistance à l'élément ; jamais mis à terre (il reste au moins 1 point de vie). Aucun tirage au hasard. C'est
## ce qui lui donne envie d'apprendre cette résistance (practice « mage:<élément> »).
func _splash(mage: Dictionary, ally: Dictionary) -> void:
	var element: String = mage["element"] if mage["element"] != "" else "Feu"
	var resist := minf(0.8, GameData.skill_level(ally["skills"], GameData.ELEMENT_RESISTANCES.get(element, "")) \
		* GameData.FIRE_RESIST_PER_LEVEL)
	var amount := mini(roundi(mage["atk"] * GameData.FRIENDLY_SPLASH * (1.0 - resist)), ally["hp"] - 1)
	ally["practice"]["mage:" + element] = ally["practice"].get("mage:" + element, 0) + 1
	ally["took_elements"][element] = true
	if amount <= 0:
		return
	ally["hp"] -= amount
	_effect("spell", mage, ally, "-%d" % amount, false)


## Étape D : ce qu'un héros vit à chaque coup (sans tirage) : pris au contact alors qu'il se bat de loin, touché par
## des tirs alors qu'il se bat au contact, coups encaissés au bouclier, esquives, coups portés avec son arme.
func _note_practice(attacker: Dictionary, target: Dictionary, amount: int, kind: String) -> void:
	if target["is_hero"] and not attacker["is_hero"]:
		var practice: Dictionary = target["practice"]
		var from_afar: bool = target["ranged"] or not target["bow"].is_empty() or target["class"] in ["Mage", "Soigneur"]
		if amount == -1:
			practice["esquives"] = practice.get("esquives", 0) + 1
		elif amount >= 0:
			if kind == "hit" and from_afar:
				practice["pris_au_contact"] = practice.get("pris_au_contact", 0) + 1
			elif kind != "hit" and not from_afar:
				practice["tirs_subis"] = practice.get("tirs_subis", 0) + 1
			if target["shield"]:
				practice["au_bouclier"] = practice.get("au_bouclier", 0) + 1
			practice["coups_subis"] = practice.get("coups_subis", 0) + 1
	if attacker["is_hero"] and not target["is_hero"] and amount >= 0 and attacker["weapon_skill"] != "":
		var key: String = "arme:" + attacker["weapon_skill"]
		attacker["practice"][key] = attacker["practice"].get(key, 0) + 1
		if not attacker["bow"].is_empty():
			attacker["dagger_hits"] += 1  # (dague de secours d'un archer)


## Retire des points de vie à la cible et renvoie les dégâts infligés (-1 si elle esquive).
## « kind » : "hit" (corps à corps), "arrow" (flèche) ou "spell" (sort).
func _damage(attacker: Dictionary, target: Dictionary, power: float, critical := false, kind := "hit", surprise := false) -> int:
	_start_clock()  # premier coup échangé : c'est le contact (rien ne change si le décompte tourne déjà)
	# Mouvement souple : une chance d'éviter complètement le coup (moins face à la précision
	# d'Analyse froide, et à celle d'Œil de faucon pour les flèches et les sorts). Pas face à une attaque surprise.
	var dodge: float = GameData.skill_level(target["skills"], "Mouvement souple") * DODGE_PER_LEVEL \
		- GameData.skill_level(attacker["skills"], "Analyse froide") * GameData.COLD_ANALYSIS_PER_LEVEL
	if kind != "hit":
		dodge -= GameData.skill_level(attacker["skills"], "Œil de faucon") * GameData.HAWK_EYE_PRECISION_PER_LEVEL
	if not surprise and randf() < dodge:
		return -1
	# Parade des projectiles (étape D) : un combattant au contact pare une partie des flèches et des sorts qu'il voit venir
	# (tirage seulement s'il a la compétence).
	if kind != "hit" and not surprise and not target["ranged"]:
		var parry := minf(GameData.PARRY_MAX, GameData.skill_level(target["skills"], "Parade des projectiles") * GameData.PARRY_PER_LEVEL)
		if parry > 0.0 and randf() < parry:
			return -3
	# Couvert : derrière un muret ou un rocher, un tir peut s'y arrêter (voir _covered).
	if kind != "hit" and _covered(target, attacker) and randf() < GameData.COVER_CHANCE:
		return -2
	# Maîtrise de l'arme que tient l'attaquant (épée, arc...) : chaque niveau renforce ses coups.
	if kind != "spell" and attacker["weapon_skill"] != "":
		power *= 1.0 + GameData.skill_level(attacker["skills"], attacker["weapon_skill"]) * GameData.WEAPON_SKILL_BONUS_PER_LEVEL
	# Premier sang (exclusive, P2g) : son premier coup du combat (qui touche) frappe plus fort.
	if not attacker["first_blood_used"] and GameData.skill_level(attacker["skills"], "Premier sang") > 0:
		attacker["first_blood_used"] = true
		power *= 1.0 + GameData.exclusive_effect(attacker["skills"], "Premier sang")
	# Épée et bouclier (fusion) : un bonus en plus à l'épée.
	if kind == "hit" and attacker["weapon"] == "Épée":
		power *= 1.0 + GameData.skill_level(attacker["skills"], "Épée et bouclier") * GameData.SWORD_SHIELD_BONUS_PER_LEVEL
	# Tueur de gobelins : plus de dégâts contre tous les gobelins (Gobelin, Chef gobelin, Sorcier gobelin).
	if target["base_name"].to_lower().contains("gobelin"):
		power *= 1.0 + GameData.skill_level(attacker["skills"], "Tueur de gobelins") * GameData.GOBLIN_SLAYER_PER_LEVEL
	# Esprit combatif : sous la moitié de sa vie, l'attaquant frappe plus fort.
	if attacker["hp"] * 2 < attacker["max_hp"]:
		power *= 1.0 + GameData.skill_level(attacker["skills"], "Esprit combatif") * GameData.FIGHTING_SPIRIT_PER_LEVEL
	# Migraine (après une rage Berserk) : l'attaquant frappe moins fort.
	if has_migraine(attacker):
		power *= GameData.MIGRAINE_DAMAGE_FACTOR
	# Avantage de hauteur : par niveau au-dessus de l'autre (HEIGHT_MAX_LEVELS au plus), on frappe plus fort
	# et on encaisse moins (voir GameData, tower.gd, « Verticalité »).
	var above := clampi(height_of(attacker) - height_of(target), -GameData.HEIGHT_MAX_LEVELS, GameData.HEIGHT_MAX_LEVELS)
	if above > 0:
		power *= 1.0 + above * GameData.HEIGHT_DAMAGE_PER_LEVEL
	# Santé mentale basse : l'attaquant frappe moins fort, la cible se défend moins bien (voir _mind).
	# Un ami ou un frère d'armes tout près : l'inverse (voir _bond).
	# Formations (trois portées, mur de boucliers) : voir _formation_attack et _formation_defense.
	var raw: float = attacker["atk"] * _mind(attacker) * _bond(attacker) * _formation_attack(attacker) * power \
		* randf_range(0.9, 1.1) - target["def"] * _mind(target) * _bond(target) * _formation_defense(target) * 0.5
	# Sort élémentaire : la résistance de la cible à cet élément (80 % au plus). Étape D : feu, vent et froid (avant :
	# le feu seulement).
	if kind == "spell" and GameData.ELEMENT_RESISTANCES.has(attacker["element"]):
		var element: String = attacker["element"]
		raw *= 1.0 - minf(0.8, GameData.skill_level(target["skills"], GameData.ELEMENT_RESISTANCES[element]) * GameData.FIRE_RESIST_PER_LEVEL)
		target["took_elements"][element] = true
		if target["is_hero"]:
			target["practice"]["element:" + element] = target["practice"].get("element:" + element, 0) + 1
		if element == "Feu":
			target["took_fire"] = true
	if above < 0:
		raw *= 1.0 + above * GameData.HEIGHT_DEFENSE_PER_LEVEL
	# Peau de pierre (compétence de promotion) : la cible encaisse mieux.
	raw *= 1.0 - GameData.skill_level(target["skills"], "Peau de pierre") * GameData.STONE_SKIN_PER_LEVEL
	# Utilisation du bouclier : avec un bouclier en main, la cible pare une partie du coup (pas un coup qu'elle
	# n'a pas vu venir).
	if target["shield"] and not surprise:
		raw *= 1.0 - GameData.skill_level(target["skills"], "Utilisation du bouclier") * GameData.SHIELD_GUARD_PER_LEVEL
	# Calme : sous la moitié de sa vie, la cible garde son sang-froid et encaisse mieux.
	if target["hp"] * 2 < target["max_hp"]:
		raw *= 1.0 - GameData.skill_level(target["skills"], "Calme") * CALM_PER_LEVEL
	# Un fuyard (peur, effondrement) tourne le dos : il encaisse plus.
	if _fleeing(target):
		raw *= GameData.FLEEING_DAMAGE_TAKEN
	# En plein échange de place (rotation) : le moment le plus dangereux.
	if time < target["swap_until"]:
		raw *= GameData.ROTATION_DAMAGE_TAKEN
	var amount := mini(maxi(1, roundi(raw)), target["hp"])
	# Un Protecteur tout près d'un allié en danger prend une partie du coup pour lui.
	var guardian := _guardian_for(target)
	if not guardian.is_empty():
		amount = _cover(guardian, target, amount)
	amount = _hold_on(target, amount)  # rage d'éveil : il refuse de mourir
	target["hp"] -= amount
	attacker["contribution"] += amount
	if _duel_yields(target):
		return amount
	if target["hp"] > 0:
		_stress_wound(target, amount)
		var grave: bool = critical or amount >= target["max_hp"] * BLEED_HIT
		if grave:
			_start_bleed(attacker, target)
		_check_critical_state(target)
		# Sa première blessure peut lui faire peur (voir _scare) ; une blessure grave peut ramener une peur passée.
		if target["is_hero"] and not target["was_hit"]:
			target["was_hit"] = true
			_scare(target, GameData.FEAR_FIRST_WOUND_CHANCE, "sa première blessure")
		elif grave and target["fearful"] and target["scared"] and not afraid(target) and not panicking(target) \
				and randf() < GameData.fear_return_chance(target["source"]):
			_frighten(target, "une blessure grave")
	return amount


## Après le combat : un héros qui a saigné et tient encore debout peut apprendre
## (ou améliorer) Résistance à la douleur. Un héros debout, épée et bouclier en main,
## dont les deux maîtrises sont au maximum, les fusionne en « Épée et bouclier ».
func _after_fight() -> void:
	# Encore à l'agonie quand l'étage se termine (étape A, demande du porteur du projet ; avant : sauvé seulement si un
	# allié debout pouvait le rejoindre à temps) : soigné, s'il reste un héros debout ; sinon (toute l'équipe à terre)
	# il meurt. Un duel ne finit jamais à l'agonie.
	var someone_standing := not _alive(heroes).is_empty()
	for hero in heroes:
		if not hero["agony"]:
			continue
		if someone_standing:
			_heal_at_end(hero)
		else:
			_die(hero, hero["agony_cause"])
	# La rage s'arrête avec le combat ; la migraine (en cours ou qui commence) continue après, en temps réel.
	var now := Time.get_unix_time_from_system()
	for unit in units:
		if not unit["person"]:
			continue
		if unit["berserk"] and unit["hp"] > 0:
			_exit_berserk(unit, true)
		if unit["migraine_until"] > time:
			unit["source"]["migraine_until"] = now + unit["migraine_until"] - time
	for fighter in heroes:
		var standing: bool = fighter["hp"] > 0 or fighter["immortal"]
		if standing and fighter["weapon"] == "Épée" and fighter["shield"] \
				and GameData.fusion_ready(fighter["skills"], "Épée et bouclier"):
			_announce_fusion(fighter, GameData.fuse_skills(fighter["skills"], "Épée et bouclier"))
		# Résistance aux flammes : un héros qui a subi du feu et tient debout peut l'apprendre (ou la monter).
		# Étape D : de même pour le vent et le froid (même chance), dans cet ordre.
		for element in GameData.ELEMENT_RESISTANCES:
			if standing and fighter["took_elements"].has(element) and randf() < GameData.FIRE_RESIST_CHANCE:
				_improve_skill(fighter, GameData.ELEMENT_RESISTANCES[element], "a appris %s" % ELEMENT_WORDS[element])
		# Compétences exclusives (P2g) : un événement vécu peut les éveiller (ou les monter), chez un héros qui
		# a l'accès du pôle et tient debout. Pas de tirage pour les autres (combats identiques à graine égale).
		if standing and not quest.get("duel", false):
			for event in fighter["exclusive_events"]:
				for exclusive in PersonalityEngine.exclusives_for_event(fighter["source"], event):
					if randf() < exclusive["chance"]:
						_improve_skill(fighter, exclusive["skill"], exclusive["how"])
	for fighter in heroes:
		if not fighter["has_bled"] or (fighter["hp"] <= 0 and not fighter["immortal"]):
			continue
		if randf() >= PAIN_RESIST_CHANCE:
			continue
		var skill_name := "Résistance à la douleur"
		var level := GameData.skill_level(fighter["skills"], skill_name)
		var line := ""
		if level == 0:
			if not PersonalityEngine.can_learn(fighter["source"], skill_name, fighter["skills"]):
				continue  # hors de ses affinités (P2) : il n'en tire rien
			fighter["skills"].append(GameData.new_skill(skill_name))
			line = "nouvelle compétence : %s" % skill_name
		elif level < GameData.SKILL_MAX_LEVEL:
			for skill in fighter["skills"]:
				if skill["name"] == skill_name:
					skill["level"] += 1
			line = "%s passe au niveau %d" % [skill_name, level + 1]
		if line != "":
			fighter["skill_news"].append("%s — %s" % [fighter["name"], line])
			_log("%s a appris de ses blessures : %s." % [fighter["name"], line], "awaken")


## Duel : à DUEL_STOP_HP de sa vie, un duelliste s'arrête (jamais de mort) et l'autre l'emporte.
## Renvoie vrai si le duel vient de se terminer.
func _duel_yields(unit: Dictionary) -> bool:
	if not quest.get("duel", false) or finished or unit["hp"] > unit["max_hp"] * GameData.DUEL_STOP_HP:
		return false
	unit["hp"] = maxi(unit["hp"], ceili(unit["max_hp"] * GameData.DUEL_STOP_HP))  # le coup est retenu
	unit["bleed"]["ticks"] = 0
	victory = not unit["is_hero"]
	var winner: Dictionary = enemies[0] if unit["is_hero"] else heroes[0]
	_log("%s pose un genou à terre : %s remporte le duel !" % [unit["name"], winner["name"]], "awaken")
	_finish()
	return true
