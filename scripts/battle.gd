class_name Battle
extends RefCounted
## Combat automatique entre l'équipe du joueur et des ennemis.
##
## Le combat est calculé en entier, d'un seul coup, par run() : chaque action est notée
## dans « events ». L'écran de combat (BattleView) rejoue ensuite ces événements
## un par un pour que le joueur puisse suivre.
##
## Règles :
## - à chaque tour, tous les combattants vivants agissent, du plus rapide au plus lent ;
## - dégâts = attaque - la moitié de la défense de la cible (au moins 1) ;
## - la dextérité donne une petite chance de coup critique (dégâts x1.5) ;
## - un héros immortel (héros secret) tombé à 0 est seulement « à terre » ;
## - chaque classe a sa particularité :
##     Novice    : attaque simple
##     Guerrier  : frappe fort (dégâts x1.2)
##     Chevalier : attire les coups (les ennemis le visent 3 fois plus souvent)
##     Mage      : frappe tous les ennemis à la fois (dégâts x0.6 sur chacun)
##     Archer    : +25 % de chances de coup critique, et ses critiques font x2
##     Assassin  : vise toujours l'ennemi qui a le moins de points de vie
##     Soigneur  : soigne l'allié le plus blessé (attaque si personne n'est blessé)
##
## États et compétences (les chiffres sont des propositions, à ajuster) :
## - saignement : un coup critique, ou un coup qui retire beaucoup de vie d'un coup,
##   fait saigner la cible, qui perd de la vie au début de ses tours suivants ;
##   blessée à nouveau pendant qu'elle saigne, elle fait une hémorragie (plus grave) ;
## - éveil des compétences : un héros qui passe sous 25 % de sa vie peut s'éveiller,
##   une fois par combat : ses compétences gagnent plusieurs niveaux d'un coup,
##   et il peut en apprendre une nouvelle ;
## - un héros qui a saigné et termine le combat debout peut apprendre Résistance à la douleur.
## Les effets des compétences sont décrits dans GameData.SKILLS.

## Quête (voir GameData.floor_quest) :
## - quêtes pour tuer tous les ennemis : passé la limite de tours, l'équipe abandonne (défaite) ;
## - survie et défense : il faut tenir jusqu'à la fin de la limite de tours ;
##   en défense, chaque ennemi debout à la fin d'un tour abîme les remparts de la cité.
## 6 ennemis au plus se battent en même temps : les autres attendent en renfort
## et prennent la place des ennemis tombés, au début du tour suivant.

## Nombre d'ennemis qui combattent en même temps.
const ENEMY_SLOTS := 6

## Quête utilisée quand on n'en donne pas : tuer tous les ennemis en 30 tours au plus.
const DEFAULT_QUEST := {"type": "extermination", "lasting": false, "rounds": 30, "hidden_level": false, "walls": 0}

## Un coup qui retire au moins cette part de la vie maximum fait saigner (0.35 = 35 %).
const BLEED_HIT := 0.35
## Saignement : part de la vie maximum perdue à chaque tour, et nombre de tours.
const BLEED_DAMAGE := 0.05
const BLEED_TURNS := 3
## Hémorragie : la même chose, en plus grave.
const HEAVY_BLEED_DAMAGE := 0.1
const HEAVY_BLEED_TURNS := 4
## Réduction des saignements par niveau de Résistance à la douleur (au plus 80 %).
const PAIN_RESIST_PER_LEVEL := 0.1
## Chance d'apprendre (ou d'améliorer) Résistance à la douleur après avoir saigné.
const PAIN_RESIST_CHANCE := 0.5

## Sous cette part de sa vie, un héros est en situation critique et peut s'éveiller.
const CRITICAL_HP := 0.25
## Chance d'éveil en situation critique (une seule tentative par héros et par combat).
const AWAKENING_CHANCE := 0.35
## Berserk ne s'apprend qu'aux portes de la mort : sous cette part de sa vie.
const BERSERK_LEARN_HP := 0.15
## Un héros qui possède Berserk entre en rage sous cette part de sa vie.
const BERSERK_HP := 0.3

## Esquive par niveau de Mouvement souple, et réduction des dégâts par niveau de Calme.
const DODGE_PER_LEVEL := 0.03
const CALM_PER_LEVEL := 0.04

var quest: Dictionary
var heroes: Array[Dictionary] = []
## Les ennemis qui combattent (ENEMY_SLOTS au plus). Un renfort remplace un ennemi tombé à sa place.
var enemies: Array[Dictionary] = []
## Les ennemis qui attendent d'entrer en renfort.
var reserve: Array = []
## Remparts de la cité (quête de défense seulement).
var walls := 0

## Chaque événement : {"text": ce qui s'est passé, "hp": points de vie de tout le monde après,
## "style": "" ou un genre d'événement ("bleed", "awaken", "berserk", "reinforce") pour le colorer à l'écran}.
## L'ordre des points de vie est : les héros, puis les ennemis.
## Un événement de renforts a aussi « arrivals » : [{"index", "name", "level", "max_hp"}]
## (index = position dans la liste des points de vie), pour que l'écran change les noms.
var events: Array[Dictionary] = []

var victory := false

## Messages en attente : ce qui arrive pendant un coup (saignement, éveil...) est annoncé
## juste après la ligne qui décrit ce coup.
var _pending: Array = []


func _init(team: Array, foes: Array, floor_quest: Dictionary = DEFAULT_QUEST) -> void:
	quest = floor_quest
	walls = quest["walls"]
	for hero in team:
		heroes.append(_make_fighter(hero, true))
	for enemy in foes:
		if enemies.size() < ENEMY_SLOTS:
			enemies.append(_make_fighter(enemy, false))
		else:
			reserve.append(enemy)


## Joue tout le combat.
func run() -> void:
	_fight()
	_after_fight()


func _fight() -> void:
	var rounds: int = quest["rounds"]
	for round_number in range(1, rounds + 1):
		_call_reinforcements()
		if quest["lasting"]:
			_log("— Tour %d — encore %d à tenir" % [round_number, rounds - round_number + 1])
		else:
			_log("— Tour %d / %d —" % [round_number, rounds])
		for fighter in _turn_order():
			if fighter["hp"] <= 0:
				continue  # mis K.O. plus tôt dans ce tour
			_bleed_tick(fighter)
			if fighter["hp"] > 0:
				_act(fighter)
			if _alive(enemies).is_empty() and reserve.is_empty():
				victory = true
				_log("Victoire ! Il ne reste plus un seul ennemi.")
				return
			if _alive(heroes).is_empty():
				_log("Défaite... toute l'équipe est tombée.")
				return
			if _alive(enemies).is_empty():
				break  # la vague est tombée : les renforts arrivent au tour suivant
		if walls > 0:
			var attackers := _alive(enemies).size()
			walls = maxi(0, walls - attackers)
			if attackers > 0:
				_log("Les ennemis frappent les remparts : -%d (reste %d/%d)." % [attackers, walls, quest["walls"]], "reinforce")
			if walls == 0:
				_log("Les remparts cèdent : la cité est tombée !")
				return
	if quest["lasting"]:
		victory = true
		_log("Le compte à rebours est terminé : ton équipe a tenu bon ! Victoire !")
	else:
		_log("Le temps est écoulé : ton équipe bat en retraite.")


## Au début d'un tour, les ennemis en réserve prennent la place des ennemis tombés.
func _call_reinforcements() -> void:
	var arrivals := []
	for i in enemies.size():
		if enemies[i]["hp"] > 0 or reserve.is_empty():
			continue
		var fighter := _make_fighter(reserve.pop_front(), false)
		enemies[i] = fighter
		arrivals.append({"index": heroes.size() + i, "name": fighter["name"], "level": fighter["level"],
			"max_hp": fighter["max_hp"]})
	if arrivals.is_empty():
		return
	var names := arrivals.map(func(a): return a["name"])
	var text := "Des renforts arrivent : %s." % ", ".join(names)
	if not reserve.is_empty():
		text += " (%d encore en approche)" % reserve.size()
	_add_event(text, "reinforce")
	events[-1]["arrivals"] = arrivals


## Le héros qui a le plus contribué (dégâts + soins), ou "" s'il n'y a aucun héros.
func mvp() -> String:
	var best: Dictionary = {}
	for fighter in heroes:
		if best.is_empty() or fighter["contribution"] > best["contribution"]:
			best = fighter
	return "" if best.is_empty() else best["name"]


## Un « combattant » : ses valeurs de combat et ses points de vie actuels.
## « source » garde le héros (ou l'ennemi) d'origine, pour le marquer mort après le combat.
## Les compétences sont une copie : elles ne sont recopiées sur le héros qu'à la fin
## (GameData.finish_tower_battle), et seulement s'il a survécu.
func _make_fighter(source: Dictionary, is_hero: bool) -> Dictionary:
	var stats := GameData.combat_stats(source)
	return {
		"name": source["name"],
		"class": source["class"],
		"level": source["level"],
		"stars": "★".repeat(source.get("rarity", 1)),
		"is_hero": is_hero,
		"hidden_level": not is_hero and quest["hidden_level"],  # niveau affiché « ? »
		"immortal": source.get("immortal", false),
		"source": source,
		"skills": source.get("skills", []).duplicate(true),
		"hp": stats["hp"],
		"max_hp": stats["hp"],
		"atk": stats["atk"],
		"def": stats["def"],
		"spd": stats["spd"],
		"crit": stats["crit"],
		"contribution": 0,  # dégâts infligés + soins donnés, pour désigner le MVP
		"killer": "",       # cause de la mort, s'il tombe
		# Saignement en cours : tours restants, vie perdue par tour, hémorragie ou non, qui l'a causé.
		"bleed": {"turns": 0, "amount": 0, "heavy": false, "cause": ""},
		"has_bled": false,         # a saigné pendant ce combat (pour Résistance à la douleur)
		"awakening_tried": false,  # l'éveil n'est tenté qu'une fois par combat
		"berserk": false,          # en rage (compétence Berserk)
		"skill_news": [],          # compétences apprises ou améliorées, pour l'écran de fin
	}


## Ordre d'action du tour : du plus rapide au plus lent.
## On ajoute un petit nombre au hasard pour départager les égalités.
func _turn_order() -> Array:
	var order := _alive(heroes) + _alive(enemies)
	for fighter in order:
		fighter["initiative"] = fighter["spd"] + randf()
	order.sort_custom(func(a, b): return a["initiative"] > b["initiative"])
	return order


## Le combattant fait son action, selon sa classe.
func _act(fighter: Dictionary) -> void:
	var allies: Array[Dictionary] = heroes if fighter["is_hero"] else enemies
	var foes: Array[Dictionary] = enemies if fighter["is_hero"] else heroes

	match fighter["class"]:
		"Guerrier":
			_attack(fighter, _random_target(foes), 1.2)
		"Mage":
			var targets := _alive(foes)
			var hits := []
			for target in targets:
				hits.append("%s %s" % [target["name"], _hit_text(_damage(fighter, target, 0.6))])
			_log("%s lance un sort de zone : %s" % [fighter["name"], ", ".join(hits)])
			_check_deaths(targets, fighter)
		"Archer":
			var critical: bool = randf() < fighter["crit"] + 0.25
			_attack(fighter, _random_target(foes), 2.0 if critical else 1.0, critical)
		"Assassin":
			_attack(fighter, _weakest(foes))
		"Soigneur":
			var wounded := _most_wounded(allies)
			if wounded.is_empty():
				_attack(fighter, _random_target(foes))
			else:
				_heal(fighter, wounded)
		_:
			var critical: bool = randf() < fighter["crit"]
			_attack(fighter, _random_target(foes), 1.5 if critical else 1.0, critical)


func _attack(attacker: Dictionary, target: Dictionary, power := 1.0, critical := false) -> void:
	var amount := _damage(attacker, target, power, critical)
	var text := "%s frappe %s : %s" % [attacker["name"], target["name"], _hit_text(amount)]
	if critical and amount >= 0:
		text = "Coup critique ! " + text
	_log(text)
	_check_deaths([target], attacker)


## Texte d'un coup : « -12 », ou « esquive ! » (dégâts de -1).
func _hit_text(amount: int) -> String:
	return "esquive !" if amount < 0 else "-%d" % amount


## Retire des points de vie à la cible et renvoie les dégâts infligés (-1 si elle esquive).
func _damage(attacker: Dictionary, target: Dictionary, power: float, critical := false) -> int:
	# Mouvement souple : une chance d'éviter complètement le coup.
	if randf() < GameData.skill_level(target["skills"], "Mouvement souple") * DODGE_PER_LEVEL:
		return -1
	var raw: float = attacker["atk"] * power * randf_range(0.9, 1.1) - target["def"] * 0.5
	# Calme : sous la moitié de sa vie, la cible garde son sang-froid et encaisse mieux.
	if target["hp"] * 2 < target["max_hp"]:
		raw *= 1.0 - GameData.skill_level(target["skills"], "Calme") * CALM_PER_LEVEL
	var amount := mini(maxi(1, roundi(raw)), target["hp"])
	target["hp"] -= amount
	attacker["contribution"] += amount
	if target["hp"] > 0:
		if critical or amount >= target["max_hp"] * BLEED_HIT:
			_start_bleed(attacker, target)
		_check_critical_state(target)
	return amount


func _heal(healer: Dictionary, target: Dictionary) -> void:
	var amount := roundi(healer["atk"] * 2.0 * randf_range(0.9, 1.1))
	amount = mini(amount, target["max_hp"] - target["hp"])
	target["hp"] += amount
	healer["contribution"] += amount
	_log("%s soigne %s : +%d" % [healer["name"], target["name"], amount])


# ---------------------------------------------------------------------------
# Saignement
# ---------------------------------------------------------------------------

## La cible se met à saigner. Si elle saignait déjà, c'est une hémorragie.
func _start_bleed(attacker: Dictionary, target: Dictionary) -> void:
	var bleed: Dictionary = target["bleed"]
	var heavy: bool = bleed["turns"] > 0
	bleed["heavy"] = heavy
	bleed["turns"] = HEAVY_BLEED_TURNS if heavy else BLEED_TURNS
	bleed["amount"] = maxi(1, roundi(target["max_hp"] * (HEAVY_BLEED_DAMAGE if heavy else BLEED_DAMAGE)))
	bleed["cause"] = "%s causé%s par %s (niv. %d)" % [
		"d'une hémorragie" if heavy else "d'un saignement", "e" if heavy else "",
		attacker["name"], attacker["level"]]
	target["has_bled"] = true
	var who := _name_with_stars(target)
	if heavy:
		_queue("%s fait une hémorragie ! Sa vie s'écoule à grande vitesse." % who, "bleed")
	else:
		_queue("%s saigne et va perdre de la santé à intervalles réguliers." % who, "bleed")


## Au début de son tour, un combattant qui saigne perd de la vie.
func _bleed_tick(fighter: Dictionary) -> void:
	var bleed: Dictionary = fighter["bleed"]
	if bleed["turns"] <= 0:
		return
	bleed["turns"] -= 1
	# Résistance à la douleur : les blessures guérissent plus vite.
	var resist := minf(0.8, GameData.skill_level(fighter["skills"], "Résistance à la douleur") * PAIN_RESIST_PER_LEVEL)
	var amount := mini(maxi(1, roundi(bleed["amount"] * (1.0 - resist))), fighter["hp"])
	fighter["hp"] -= amount
	if fighter["hp"] > 0:
		_check_critical_state(fighter)
	var word := "hémorragie" if bleed["heavy"] else "saignement"
	_log("%s perd %d PV (%s)." % [fighter["name"], amount, word], "bleed")
	if fighter["hp"] <= 0:
		_announce_fall(fighter, "mort " + bleed["cause"])
	elif bleed["turns"] == 0:
		bleed["heavy"] = false
		_log("%s ne saigne plus." % fighter["name"])


# ---------------------------------------------------------------------------
# Situation critique : éveil des compétences et Berserk
# ---------------------------------------------------------------------------

## Appelée quand un combattant vient de perdre de la vie sans tomber.
func _check_critical_state(fighter: Dictionary) -> void:
	if not fighter["is_hero"]:
		return
	var ratio: float = float(fighter["hp"]) / fighter["max_hp"]
	if ratio <= CRITICAL_HP and not fighter["awakening_tried"]:
		fighter["awakening_tried"] = true
		if randf() < AWAKENING_CHANCE:
			_awaken(fighter, ratio)
	if ratio <= BERSERK_HP and not fighter["berserk"] and GameData.skill_level(fighter["skills"], "Berserk") > 0:
		_enter_berserk(fighter)


## Éveil des compétences : chaque compétence gagne 1 à 3 niveaux d'un coup,
## et le héros peut en apprendre une nouvelle (toujours s'il n'en avait aucune à améliorer).
func _awaken(fighter: Dictionary, ratio: float) -> void:
	var news := []
	for skill in fighter["skills"]:
		if skill["level"] < GameData.SKILL_MAX_LEVEL:
			skill["level"] = mini(skill["level"] + randi_range(1, 3), GameData.SKILL_MAX_LEVEL)
			news.append("%s passe au niveau %d" % [skill["name"], skill["level"]])

	var candidates := []
	for skill_name in GameData.AWAKENING_SKILLS:
		if skill_name == "Berserk" and ratio > BERSERK_LEARN_HP:
			continue  # Berserk ne vient qu'aux portes de la mort
		if GameData.can_learn_skill(fighter["source"], fighter["skills"], skill_name):
			candidates.append(skill_name)
	if not candidates.is_empty() and (news.is_empty() or randf() < 0.5):
		var learned: String = candidates.pick_random()
		fighter["skills"].append(GameData.new_skill(learned))
		news.append("nouvelle compétence : %s" % learned)

	if news.is_empty():
		return  # toutes ses compétences sont déjà au maximum
	_queue("Éveil des compétences ! %s : %s." % [_name_with_stars(fighter), ", ".join(news)], "awaken")
	for line in news:
		fighter["skill_news"].append("%s — %s" % [fighter["name"], line])


## Berserk : la rage renforce le héros (Force, Santé, Dextérité) mais lui fait perdre ses moyens (Intelligence).
func _enter_berserk(fighter: Dictionary) -> void:
	fighter["berserk"] = true
	var bonus := 4 + GameData.skill_level(fighter["skills"], "Berserk")  # +5 au niveau 1
	if fighter["class"] in ["Mage", "Soigneur"]:
		fighter["atk"] = maxi(1, fighter["atk"] - 10)  # leur attaque vient de l'Intelligence
	else:
		fighter["atk"] += bonus
	fighter["def"] += roundi(bonus / 2.0)
	fighter["spd"] += bonus
	fighter["crit"] += bonus / 200.0
	_queue("%s est entré en mode Berserk ! Une pression écrasante envahit le champ de bataille." \
		% _name_with_stars(fighter), "berserk")


## Après le combat : un héros qui a saigné et tient encore debout peut apprendre
## (ou améliorer) Résistance à la douleur.
func _after_fight() -> void:
	for fighter in heroes:
		if not fighter["has_bled"] or (fighter["hp"] <= 0 and not fighter["immortal"]):
			continue
		if randf() >= PAIN_RESIST_CHANCE:
			continue
		var skill_name := "Résistance à la douleur"
		var level := GameData.skill_level(fighter["skills"], skill_name)
		var line := ""
		if level == 0:
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


# ---------------------------------------------------------------------------
# Chutes, cibles, journal
# ---------------------------------------------------------------------------

## Annonce les combattants qui viennent de tomber à 0 point de vie,
## et note la cause de la mort des héros.
func _check_deaths(targets: Array, attacker: Dictionary) -> void:
	for target in targets:
		if target["hp"] <= 0 and target["killer"] == "":
			_announce_fall(target, "tué par %s (niv. %d)" % [attacker["name"], attacker["level"]])


func _announce_fall(fighter: Dictionary, cause: String) -> void:
	if not fighter["is_hero"]:
		fighter["killer"] = cause
		_log("%s est vaincu." % fighter["name"])
	elif fighter["immortal"]:
		_log("%s est à terre, mais se relèvera." % fighter["name"])
	else:
		fighter["killer"] = cause
		_log("%s tombe au combat !" % fighter["name"])


## Nom suivi des étoiles, comme dans les fenêtres système : « Hansen (★) ».
func _name_with_stars(fighter: Dictionary) -> String:
	if not fighter["is_hero"]:
		return fighter["name"]
	return "%s (%s)" % [fighter["name"], fighter["stars"]]


## Choisit une cible au hasard. Un Chevalier compte pour 3 : il est visé 3 fois plus souvent.
func _random_target(foes: Array) -> Dictionary:
	var targets := _alive(foes)
	var total := 0
	for target in targets:
		total += _threat(target)
	var roll := randi() % total
	for target in targets:
		roll -= _threat(target)
		if roll < 0:
			return target
	return targets[-1]


func _threat(fighter: Dictionary) -> int:
	return 3 if fighter["class"] == "Chevalier" else 1


## L'adversaire vivant qui a le moins de points de vie.
func _weakest(foes: Array) -> Dictionary:
	var result: Dictionary = {}
	for target in _alive(foes):
		if result.is_empty() or target["hp"] < result["hp"]:
			result = target
	return result


## L'allié vivant le plus blessé (en proportion), ou {} si personne n'est blessé.
func _most_wounded(allies: Array) -> Dictionary:
	var result: Dictionary = {}
	var lowest_ratio := 1.0
	for ally in _alive(allies):
		var ratio: float = float(ally["hp"]) / ally["max_hp"]
		if ratio < lowest_ratio:
			lowest_ratio = ratio
			result = ally
	return result


func _alive(fighters: Array) -> Array:
	return fighters.filter(func(f): return f["hp"] > 0)


## Note un événement, avec les points de vie de tout le monde à ce moment-là,
## puis les messages en attente (saignement, éveil...) causés par ce qui vient d'arriver.
func _log(text: String, style := "") -> void:
	_add_event(text, style)
	var waiting := _pending
	_pending = []
	for message in waiting:
		_add_event(message[0], message[1])


## Met un message en attente : il sera noté juste après le prochain événement.
func _queue(text: String, style: String) -> void:
	_pending.append([text, style])


func _add_event(text: String, style: String) -> void:
	var hp := []
	for fighter in heroes + enemies:
		hp.append(fighter["hp"])
	events.append({"text": text, "hp": hp, "style": style})
