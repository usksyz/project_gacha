class_name BattleBerserk
extends BattleMind
## Combat (voir battle.gd) : situation critique, éveil des compétences et Berserk.


## Ordonne à un héros qui possède Berserk d'entrer en rage (« on » vrai) ou d'en sortir.
## En rage sur ordre, il la garde jusqu'à l'ordre contraire ; coupée sur ordre, il ne la relance pas
## de lui-même pendant BERSERK_ORDER_HOLD secondes. Comme tout ordre, il peut être refusé (_obeys).
func order_berserk(hero: Dictionary, on: bool) -> void:
	if quest.get("duel", false) or not can_berserk(hero) or hero["berserk"] == on or not _obeys(hero):
		return
	if on:
		_enter_berserk(hero)
		hero["berserk_ordered"] = true
	else:
		_exit_berserk(hero)
		hero["berserk_hold_until"] = time + GameData.BERSERK_ORDER_HOLD


## Vrai si ce combattant possède Berserk (ou Surpassement) et peut s'en servir.
func can_berserk(unit: Dictionary) -> bool:
	return unit["person"] and unit["hp"] > 0 and GameData.skill_level(unit["skills"], "Berserk") > 0


# ---------------------------------------------------------------------------
# Situation critique : éveil des compétences et Berserk
# ---------------------------------------------------------------------------

## Appelée quand un combattant vient de perdre de la vie sans tomber.
func _check_critical_state(fighter: Dictionary) -> void:
	if not fighter["is_hero"] or quest.get("duel", false):
		return  # (un duel s'arrête bien avant la situation critique)
	var ratio: float = float(fighter["hp"]) / fighter["max_hp"]
	# Second souffle (compétence de promotion) : une fois par combat, le héros reprend de la vie.
	var wind := GameData.skill_level(fighter["skills"], "Second souffle")
	if ratio <= CRITICAL_HP and wind > 0 and not fighter["second_wind_used"]:
		fighter["second_wind_used"] = true
		var heal := roundi(fighter["max_hp"] * (GameData.SECOND_WIND_HEAL + (wind - 1) * GameData.SECOND_WIND_HEAL_PER_LEVEL))
		fighter["hp"] = mini(fighter["max_hp"], fighter["hp"] + heal)
		_effect("heal", fighter, fighter, "+%d" % heal, false)
		_log("%s trouve un second souffle !" % _name_with_stars(fighter), "awaken")
		ratio = float(fighter["hp"]) / fighter["max_hp"]
	if ratio <= CRITICAL_HP and not fighter["awakening_tried"]:
		fighter["awakening_tried"] = true
		# Personnalité (P2) : la Vulnérabilité s'éveille plus souvent, la Stabilité moins.
		var chance := HAN_AWAKENING_CHANCE if GameData.is_han(fighter["source"]) \
			else PersonalityEngine.modified("awakening_chance", fighter["source"], AWAKENING_CHANCE)
		if randf() < chance:
			_awaken(fighter, ratio)
	# Acquisition de Berserk (une seule fois) : aux portes de la mort, avec la rage de vivre.
	# (Son utilisation, ensuite, est à part : voir _berserk_think.)
	if ratio <= BERSERK_LEARN_HP and not fighter["death_door_tried"]:
		fighter["death_door_tried"] = true
		if _berserk_door(fighter) and PersonalityEngine.can_learn(fighter["source"], "Berserk", fighter["skills"]):
			fighter["skills"].append(GameData.new_skill("Berserk"))
			_log("Aux portes de la mort, %s refuse de mourir... Nouvelle compétence : Berserk !" \
				% _name_with_stars(fighter), "awaken")
			fighter["skill_news"].append("%s — nouvelle compétence : Berserk" % fighter["name"])
			_awakening_rage(fighter)


## Aux portes de la mort : Berserk s'éveille-t-il ? (Voir GameData, heroes.gd, BERSERK_AWAKEN_CHANCE.)
## Han : DEATH_DOOR_CHANCE, à chaque combat. Les autres : seulement si leur caractère y donne accès (P2,
## PersonalityData.SKILL_CONDITIONS : Colère, Ambition ou Courage hauts, jamais un craintif ; avant : Courageux
## ou Ambitieux), une seule fois dans leur vie (la chance est tentée, puis plus jamais), BERSERK_AWAKEN_CHANCE.
func _berserk_door(fighter: Dictionary) -> bool:
	var source: Dictionary = fighter["source"]
	if GameData.is_han(source):
		return randf() < DEATH_DOOR_CHANCE
	if GameData.skill_level(fighter["skills"], "Berserk") > 0 or source.get("berserk_door_tried", false):
		return false
	if not PersonalityEngine.has_affinity(source, "Berserk"):
		return false
	source["berserk_door_tried"] = true  # une seule fois dans sa vie (enregistré avec le héros)
	if randf() >= PersonalityEngine.modified("berserk_door", source, GameData.BERSERK_AWAKEN_CHANCE):
		return false  # (Increvable : chance doublée)
	for trait_name in GameData.BERSERK_AWAKEN_TRAITS:
		_reveal(fighter, trait_name)  # c'est sa volonté (courage, ambition) qui l'éveille (sans le trait : rien)
	return true


## Éveil des compétences : chaque compétence gagne 1 à 3 niveaux d'un coup,
## et le héros peut en apprendre une nouvelle (toujours s'il n'en avait aucune à améliorer).
func _awaken(fighter: Dictionary, ratio: float) -> void:
	var news := []
	for skill in fighter["skills"]:
		if skill["level"] < GameData.SKILL_MAX_LEVEL:
			skill["level"] = mini(skill["level"] + randi_range(1, 3), GameData.SKILL_MAX_LEVEL)
			news.append("%s passe au niveau %d" % [skill["name"], skill["level"]])

	var han := GameData.is_han(fighter["source"])
	var candidates := []
	for skill_name in GameData.AWAKENING_SKILLS:
		if skill_name == "Berserk" and not han:
			continue  # hors Han, Berserk ne vient qu'aux portes de la mort, et rarement (_berserk_door)
		# Les éveils suivent les affinités (P2) : un craintif n'éveille pas Berserk, un volatil n'éveille pas Calme.
		if PersonalityEngine.can_learn(fighter["source"], skill_name, fighter["skills"]):
			candidates.append(skill_name)
	# Indomptable : candidate seulement si le héros saigne au moment de la situation critique.
	if fighter["bleed"]["ticks"] > 0 and PersonalityEngine.can_learn(fighter["source"], "Indomptable", fighter["skills"]):
		candidates.append("Indomptable")
	# Han apprend toujours une nouvelle compétence s'il peut, et Berserk en priorité.
	if not candidates.is_empty() and (news.is_empty() or han or randf() < 0.5):
		var learned: String = candidates.pick_random()
		if han and "Berserk" in candidates:
			learned = "Berserk"
		fighter["skills"].append(GameData.new_skill(learned))
		news.append("nouvelle compétence : %s" % learned)

	if news.is_empty():
		return  # toutes ses compétences sont déjà au maximum
	_log("Éveil des compétences ! %s : %s." % [_name_with_stars(fighter), ", ".join(news)], "awaken")
	for line in news:
		fighter["skill_news"].append("%s — %s" % [fighter["name"], line])
	if "nouvelle compétence : Berserk" in news:
		_awakening_rage(fighter)


## Rage d'éveil (voir GameData, heroes.gd, AWAKENING_RAGE_SECONDS) : Berserk vient de s'éveiller, la rage
## monte aussitôt ; pendant AWAKENING_RAGE_SECONDS, il refuse de mourir (jamais sous 1 point de vie) et
## ne coupe pas la rage de lui-même (_berserk_think). Pas en duel (un duel n'éveille rien).
func _awakening_rage(fighter: Dictionary) -> void:
	if quest.get("duel", false) or not can_berserk(fighter) or fighter["berserk"]:
		return
	if PersonalityEngine.modified("awakening_rage", fighter["source"], 1.0) <= 0.0:
		return  # Stabilité 90 (Inébranlable) : jamais de rage d'éveil
	fighter["awakening_rage"] = true
	fighter["refuse_death_until"] = time + GameData.AWAKENING_RAGE_SECONDS
	_enter_berserk(fighter)


## Rage d'éveil : il refuse de mourir. Ce qu'il peut perdre de « amount » sans tomber sous 1 point de vie.
func _hold_on(unit: Dictionary, amount: int) -> int:
	if time < unit["refuse_death_until"]:
		return clampi(amount, 0, unit["hp"] - 1)
	return amount


## Le combat est-il difficile pour ce héros ? (C'est là qu'il entre en rage de lui-même.)
## Un duel, un boss sur le terrain, une horde (survie, défense de la cité), ou un allié en danger
## tout près (lui-même compris) : sous BERSERK_DANGER_HP de sa vie, à moins de BERSERK_ALLY_RANGE cases.
func _in_danger(unit: Dictionary) -> bool:
	if quest.get("duel", false):
		return true
	# (Boss et horde : seulement quand ils arrivent à portée d'engagement, pas de l'autre bout de la carte.)
	var foes := _alive(enemies if unit["is_hero"] else heroes) \
		.filter(func(foe): return unit["pos"].distance_to(foe["pos"]) <= ENGAGE_DISTANCE)
	if foes.any(func(foe): return foe["boss"]):
		return true
	if not foes.is_empty() and (quest["type"] == "survival" or quest["walls"] > 0):
		return true
	if _alive(enemies if unit["is_hero"] else heroes).is_empty():
		return false
	for ally in _alive(heroes if unit["is_hero"] else enemies):
		if float(ally["hp"]) / ally["max_hp"] < unit["berserk_trigger_hp"] \
				and unit["pos"].distance_to(ally["pos"]) <= GameData.BERSERK_ALLY_RANGE:
			return true
	return false


## Berserk, compétence active à bascule : le héros décide lui-même d'entrer en rage ou d'en sortir.
## Il y entre quand le combat est difficile (_in_danger), sauf en pleine peur ou panique, pendant une
## migraine, sous BERSERK_STOP_MENTAL de santé mentale, ou juste après que le Maître la lui a fait couper.
## Il en sort quand le danger est passé (après BERSERK_MIN_SECONDS au moins), sous BERSERK_STOP_MENTAL,
## sous BERSERK_STOP_HP de sa vie (SURPASS_STOP_HP en Surpassement). Une rage ordonnée par le Maître n'est
## coupée que sur ordre. Ces seuils dépendent du caractère (P2, lus au début du combat : fighter
## « berserk_trigger_hp » (Colère), « berserk_stop_hp » (Prudence), « berserk_stop_mental » (Maîtrise de soi)).
func _berserk_think(unit: Dictionary) -> void:
	if not can_berserk(unit) or panicking(unit) or afraid(unit):
		return
	if not unit["berserk"]:
		var surpass_ready := GameData.skill_level(unit["skills"], "Surpassement") > 0 \
			or GameData.fusion_ready(unit["skills"], "Surpassement")
		var min_hp: float = GameData.SURPASS_STOP_HP if surpass_ready else unit["berserk_stop_hp"]
		if time >= unit["berserk_hold_until"] and time >= unit["migraine_until"] \
				and unit["mental"] >= unit["berserk_stop_mental"] \
				and float(unit["hp"]) / unit["max_hp"] >= min_hp and _in_danger(unit):
			_enter_berserk(unit)
		return
	if unit["berserk_ordered"] or time - unit["berserk_since"] < GameData.BERSERK_MIN_SECONDS:
		return
	if unit["awakening_rage"] and time < unit["refuse_death_until"]:
		return  # rage d'éveil : pas de coupure automatique pendant le refus de mourir
	var stop_hp: float = GameData.SURPASS_STOP_HP if unit.get("surpass", false) else unit["berserk_stop_hp"]
	var worn_out: bool = float(unit["hp"]) / unit["max_hp"] < stop_hp
	if worn_out or unit["mental"] < unit["berserk_stop_mental"] or not _in_danger(unit):
		_exit_berserk(unit)


## Entre en rage : Force, Santé, Dextérité +5 et Intelligence -10 (voir GameData.berserk_stat_changes),
## traduits en valeurs de combat comme GameData.combat_stats (Force ou Intelligence : attaque ;
## Santé : défense, la vie maximum ne change pas ; Dextérité : vitesse et critiques).
func _enter_berserk(fighter: Dictionary) -> void:
	# Fusion : Calme et Berserk au niveau maximum fusionnent en Surpassement au moment où la rage monte.
	if GameData.fusion_ready(fighter["skills"], "Surpassement"):
		_announce_fusion(fighter, GameData.fuse_skills(fighter["skills"], "Surpassement"))
	var stats := GameData.berserk_stat_changes(fighter["skills"])
	# Rage maîtrisée (accès croisé Colère 60 et Maîtrise 60) : pas de perte d'Intelligence.
	stats["int"] = roundi(stats["int"] * PersonalityEngine.modified("berserk_int_malus", fighter["source"], 1.0))
	var magic: bool = fighter["class"] in ["Mage", "Soigneur"]  # leur attaque vient de l'Intelligence
	var changes := {
		"atk": maxi(1 - fighter["atk"], stats["int"]) if magic else stats["str"],
		"def": roundi(stats["vit"] / 2.0),
		"spd": stats["dex"],
		"crit": stats["dex"] / 200.0,
	}
	for key in changes:
		fighter[key] += changes[key]
	fighter["berserk_changes"] = changes
	fighter["berserk"] = true
	fighter["berserk_since"] = time
	fighter["berserk_ordered"] = false
	var who := _name_with_stars(fighter)
	var lines := ["%s est entré en mode Berserk !" % who]
	if GameData.skill_level(fighter["skills"], "Surpassement") > 0:
		# Surpassement : le corps passe en surrégime. Bonus doublés, plus de saignement,
		# mais la vie baisse chaque seconde (voir _berserk_tick).
		fighter["surpass"] = true
		fighter["bleed"]["ticks"] = 0
		lines.append("Surpassement : son corps passe en surrégime.")
	if fighter["awakening_rage"]:
		lines.append("Rage d'éveil : il refuse de mourir !")
	_log(" ".join(lines) + " Une pression écrasante envahit le champ de bataille.", "berserk")
	_alert("Berserk", lines, true)


## Sort de la rage : les bonus disparaissent, et la migraine commence (MIGRAINE_SECONDS, plus longue
## après un Surpassement). « end » : le combat est fini (pas de fenêtre, une ligne pour la fin du combat).
func _exit_berserk(fighter: Dictionary, end := false) -> void:
	var changes: Dictionary = fighter["berserk_changes"]
	for key in changes:
		fighter[key] -= changes[key]
	fighter["berserk_changes"] = {}
	fighter["berserk"] = false
	fighter["berserk_ordered"] = false
	var migraine := GameData.MIGRAINE_SECONDS
	if fighter.get("surpass", false):
		migraine *= GameData.SURPASS_MIGRAINE_FACTOR
	if fighter["awakening_rage"]:  # la première rage, celle de l'éveil, laisse une migraine plus longue
		migraine *= GameData.AWAKENING_MIGRAINE_FACTOR
		fighter["awakening_rage"] = false
	fighter["surpass"] = false
	fighter["migraine_until"] = maxf(fighter["migraine_until"], time + migraine)
	var text := "%s est sorti de son état Berserk." % _name_with_stars(fighter)
	_log(text + " Une migraine le prend.", "berserk")
	if end:
		fighter["mind_news"].append("%s est sorti de son état Berserk à la fin du combat : migraine (-%d %% de dégâts, %d min)." \
			% [fighter["name"], roundi((1.0 - GameData.MIGRAINE_DAMAGE_FACTOR) * 100), roundi(migraine / 60.0)])
	else:
		_alert("Berserk", [text, "Migraine : -%d %% de dégâts pendant %d minutes." \
			% [roundi((1.0 - GameData.MIGRAINE_DAMAGE_FACTOR) * 100), roundi(migraine / 60.0)]])


## En migraine en ce moment (après une rage) ?
func has_migraine(unit: Dictionary) -> bool:
	return time < unit["migraine_until"]


## Apprend une compétence au niveau 1, ou la fait monter d'un niveau, et l'annonce.
func _improve_skill(fighter: Dictionary, skill_name: String, how: String) -> void:
	var level := GameData.skill_level(fighter["skills"], skill_name)
	var line := ""
	if level == 0:
		if not PersonalityEngine.can_learn(fighter["source"], skill_name, fighter["skills"]):
			return
		fighter["skills"].append(GameData.new_skill(skill_name))
		line = "nouvelle compétence : %s" % skill_name
	elif level < GameData.SKILL_MAX_LEVEL:
		for skill in fighter["skills"]:
			if skill["name"] == skill_name:
				skill["level"] += 1
		line = "%s passe au niveau %d" % [skill_name, level + 1]
	if line != "":
		fighter["skill_news"].append("%s — %s" % [fighter["name"], line])
		_log("%s %s : %s." % [fighter["name"], how, line], "awaken")


## Annonce une fusion de compétences (journal et écran de fin).
func _announce_fusion(fighter: Dictionary, text: String) -> void:
	_log("%s : %s" % [_name_with_stars(fighter), text], "awaken")
	fighter["skill_news"].append("%s — %s" % [fighter["name"], text])


## En rage, chaque pas : la compétence coûte de la vie (BERSERK_DRAIN_PER_SECOND, SURPASS_DRAIN_PER_SECOND en
## Surpassement), jusqu'à la mort s'il ne s'arrête pas, et de la santé mentale (deux fois plus en Surpassement).
func _berserk_tick(unit: Dictionary) -> void:
	var surpass: bool = unit.get("surpass", false)
	_stress(unit, GameData.MENTAL_BERSERK_PER_SECOND * TICK * (GameData.SURPASS_MENTAL_FACTOR if surpass else 1.0), "berserk")
	if unit["hp"] <= 0:
		return
	var drain := GameData.SURPASS_DRAIN_PER_SECOND if surpass else GameData.BERSERK_DRAIN_PER_SECOND
	unit["drain"] = unit.get("drain", 0.0) + unit["max_hp"] * drain * TICK
	var amount := _hold_on(unit, mini(int(unit["drain"]), unit["hp"]))
	if amount <= 0:
		return
	unit["drain"] -= amount
	unit["hp"] -= amount
	if _duel_yields(unit):
		return  # (un duel s'arrête avant la mort)
	if unit["hp"] <= 0:
		_announce_fall(unit, "épuisé par Surpassement" if surpass else "épuisé par Berserk")
