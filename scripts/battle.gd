class_name Battle
extends RefCounted
## Combat en temps réel, vu du dessus.
##
## Le combat se joue en direct : l'écran de combat (BattleView) appelle step() 10 fois
## par seconde (un pas = TICK secondes), et dessine où en est chacun. Pas d'accélération :
## on vit le combat. Le joueur peut guider ses héros pendant le combat (order_move, order_attack),
## ce qui peut changer le résultat, ou les laisser se débrouiller.
## run() joue tout le combat d'un coup, sans ordres : c'est ce qui arrive quand le joueur
## ferme le jeu en plein combat (les héros se débrouillent seuls, voir GameData).
##
## Le champ de bataille est une grille : chaque case est libre ou bloquée par le décor
## (rochers, murs, maisons). Les combattants se déplacent librement entre les cases libres,
## contournent le décor (recherche de chemin), et les tireurs ont besoin de voir leur cible.
##
## Comportements :
## - les ennemis foncent sur les héros (en défense : sur les remparts, sauf si un héros est tout près) ;
## - les héros tiennent leur position et attaquent les ennemis qui s'approchent ;
##   un ordre du joueur passe avant tout : aller à un endroit (qui devient leur nouveau poste),
##   ou attaquer un ennemi précis ;
## - chaque classe a sa particularité :
##     Novice    : attaque simple au corps à corps
##     Guerrier  : frappe fort (dégâts x1.2)
##     Chevalier : attire les coups (les ennemis proches le visent en priorité)
##     Mage      : sort à distance qui touche aussi les ennemis autour de la cible (dégâts x0.7)
##     Archer    : tire à distance, +25 % de chances de coup critique, et ses critiques font x2
##     Assassin  : vise l'ennemi qui a le moins de points de vie
##     Soigneur  : soigne à distance l'allié le plus blessé (attaque si personne n'est blessé)
##   Les tireurs (Archer, Mage, Soigneur) reculent quand un ennemi arrive au contact.
## - l'arme d'un héros (voir GameData.WEAPON_TYPES) décide de sa portée et de ses coups :
##   un héros avec un arc devient un tireur, quelle que soit sa classe ; lance et fouet frappent
##   d'un peu plus loin ; la dague frappe vite. Le grade de l'arme ajoute de l'attaque,
##   le bouclier de la défense. Les ennemis, mages et soigneurs n'ont pas d'arme.
##
## États et compétences (les chiffres sont des propositions, à ajuster) :
## - saignement : un coup critique, ou un coup qui retire beaucoup de vie d'un coup,
##   fait saigner la cible, qui perd de la vie à intervalles réguliers ;
##   blessée à nouveau pendant qu'elle saigne, elle fait une hémorragie (plus grave) ;
## - éveil des compétences : un héros qui passe sous 25 % de sa vie peut s'éveiller,
##   une fois par combat : ses compétences gagnent plusieurs niveaux d'un coup,
##   et il peut en apprendre une nouvelle ;
## - un héros qui a saigné et termine le combat debout peut apprendre Résistance à la douleur ;
## - les flèches tirées par un héros sont comptées (« shots ») : elles font progresser
##   Maîtrise de l'arc à la fin du combat (voir GameData.finish_tower_battle).
## Les effets des compétences sont décrits dans GameData.SKILLS.
##
## Quête (voir GameData.floor_quest) :
## - quêtes pour tuer tous les ennemis : passé la limite de temps, l'équipe bat en retraite (défaite) ;
## - survie et défense : il faut tenir jusqu'à la fin du compte à rebours ;
##   en défense, les ennemis qui atteignent les remparts les frappent. À 0, la cité tombe.
## ENEMY_SLOTS ennemis au plus sont sur le terrain en même temps : les autres arrivent
## en renfort par le haut de la carte quand un ennemi tombe.

# --- Temps ---

## Durée d'un pas de simulation, en secondes (10 pas par seconde).
const TICK := 0.1

# --- Champ de bataille ---

## Taille de la grille, en cases (largeur, hauteur). Les héros partent du bas, les ennemis du haut.
const GRID_W := 18
const GRID_H := 20

## Nombre d'ennemis sur le terrain en même temps, et délai avant l'arrivée d'un renfort.
const ENEMY_SLOTS := 6
const REINFORCE_DELAY := 2.0

## Quête utilisée quand on n'en donne pas : tuer tous les ennemis en 90 secondes au plus.
const DEFAULT_QUEST := {"type": "extermination", "lasting": false, "seconds": 90, "hidden_level": false, "walls": 0}
## Quête de survie : si aucun coup n'est échangé au bout de ce temps (secondes),
## le compte à rebours démarre quand même (pour qu'un combat ne dure jamais sans fin).
const CONTACT_WAIT_MAX := 60.0

# --- Déplacements et attaques ---

## Portées, en cases : corps à corps, tir (arc, sort, soin), rayon de l'explosion d'un sort.
const MELEE_RANGE := 1.0
const RANGED_RANGE := 5.5
const SPELL_RADIUS := 1.6
## Au-delà de cette portée, on tire (il faut voir la cible) ; en dessous, on frappe
## (épée, dague : 1 case ; lance, fouet : un peu plus, voir GameData.WEAPON_TYPES).
const MELEE_REACH_MAX := 2.5
## Les héros restent à leur poste tant qu'aucun ennemi n'est plus près que ça (en cases).
const ENGAGE_DISTANCE := 7.0
## Un chevalier attire les ennemis qui sont à moins de cette distance de lui.
const TAUNT_DISTANCE := 3.5
## Pour se répartir les cibles : une cible déjà attaquée par un allié compte comme
## si elle était plus loin de ce nombre de cases (par allié).
const CROWD_PENALTY := 1.5
## Un héros qui fuit (peur, effondrement) compte pour un monstre comme s'il était plus près de ce
## nombre de cases : les monstres le poursuivent.
const PREY_BONUS := 3.0
## Vitesse de déplacement (cases par seconde) : de base, plus un bonus par point de dextérité.
const BASE_SPEED := 1.6
const SPEED_PER_DEX := 0.04
## Temps entre deux attaques (secondes) pour 15 de dextérité : plus rapide avec plus de dextérité.
const BASE_ATTACK_TIME := 1.2
## Les chemins sont recalculés à cet intervalle (secondes).
const PATH_REFRESH := 0.5
## Distance minimale entre deux combattants (ils se poussent un peu pour ne pas se chevaucher).
const PERSONAL_SPACE := 0.75

# --- États ---

## Un coup qui retire au moins cette part de la vie maximum fait saigner (0.35 = 35 %).
const BLEED_HIT := 0.35
## Saignement : part de la vie maximum perdue à chaque fois, nombre de fois, intervalle (secondes).
const BLEED_DAMAGE := 0.05
const BLEED_TICKS := 3
const HEAVY_BLEED_DAMAGE := 0.1
const HEAVY_BLEED_TICKS := 4
const BLEED_INTERVAL := 1.5
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
## Aux portes de la mort (la première fois qu'il passe sous BERSERK_LEARN_HP dans un combat),
## un héros a cette chance d'apprendre Berserk, avec une forte envie de vivre.
## (L'éveil, lui, se tente plus tôt, à CRITICAL_HP : il n'aurait presque jamais donné Berserk.)
const DEATH_DOOR_CHANCE := 0.3
## (Berserk, une fois appris, est une compétence active à bascule : voir _berserk_think et
## GameData, heroes.gd, section « Berserk ».)
## Han apprend Berserk plus facilement : ses chances d'éveil sont plus hautes, Berserk lui vient
## dès la situation critique (pas seulement aux portes de la mort), et passe avant les autres compétences.
const HAN_AWAKENING_CHANCE := 0.8

## Mana (mages et soigneurs) : réserve de départ = Intelligence x MANA_PER_INT (voir GameData.combat_stats),
## recharge par seconde = Intelligence x MANA_REGEN_PER_INT. Un sort de zone et un soin coûtent du mana ;
## à sec, le mage lance un petit trait de magie gratuit (MANA_BOLT_POWER) et le soigneur ne soigne plus.
const MANA_REGEN_PER_INT := 0.15
const SPELL_MANA_COST := 20
const HEAL_MANA_COST := 12
const MANA_BOLT_POWER := 0.3

## Quelle stat un coup porté exerce (croissance, voir « acts ») : coup au contact → Force,
## flèche → Dextérité, sort ou trait de magie → Intelligence.
const ACT_STAT := {"hit": "str", "arrow": "dex", "spell": "int", "bolt": "int"}

## Esquive par niveau de Mouvement souple, et réduction des dégâts par niveau de Calme.
const DODGE_PER_LEVEL := 0.03
const CALM_PER_LEVEL := 0.04

# --- Ce que le combat produit ---

var quest: Dictionary

## Tous les combattants : les héros, puis les ennemis (renforts compris, absents au départ).
## Leur position dans cette liste est leur numéro (« id »).
var units: Array[Dictionary] = []
var heroes: Array[Dictionary] = []
var enemies: Array[Dictionary] = []

## Cases bloquées par le décor, et les morceaux de décor à dessiner :
## [{"rect": Rect2i, "kind": "rock" / "wall" / "house" / "rampart"}].
var obstacles: Array[Dictionary] = []

## Remparts de la cité (quête de défense seulement).
var walls := 0

## Journal : {"t": moment (secondes), "text": ..., "style": "" ou "bleed", "awaken", "berserk", "reinforce"}.
var events: Array[Dictionary] = []

## Effets à dessiner : {"t", "kind": "hit" / "arrow" / "spell" / "heal" / "bleed", "from": id, "to": id,
## "text": « -12 », « esquive ! », « +20 »..., "crit": bool}.
var effects: Array[Dictionary] = []

## Fenêtres système à afficher pendant le combat (ruptures) : {"t", "title", "lines": [textes], "danger"}.
var alerts: Array[Dictionary] = []

## Moment où le compte à rebours a démarré (-1 : pas encore). En survie, il attend le premier
## contact avec les ennemis (premier coup donné ou reçu) ; sinon, il démarre tout de suite.
var clock_start := 0.0

var victory := false
## Vrai quand le combat est terminé (victoire, défaite, temps écoulé).
var finished := false
## Moment du combat, en secondes (et sa durée totale une fois terminé).
var time := 0.0
var duration := 0.0

## Potions de soin emportées par l'équipe (GameData.mission_potions) et bues pendant le combat
## (GameData.finish_tower_battle les retire de l'entrepôt). Voir « Agonie ».
var potions := 0
var potions_used := 0

var _grid := AStarGrid2D.new()
## Qui va aider qui (agonie, soin d'urgence) : {numéro de l'aidant: numéro du blessé}, recalculé à chaque pas.
var _helpers := {}
## Moment où chaque place d'ennemi s'est libérée (pour faire venir un renfort après un délai).
var _free_since := {}
## Vrai une fois que les héros ont vu un boss arriver (le stress du boss ne compte qu'une fois).
var _boss_seen := false


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
	_place_units()
	# Défense de la cité : le triple avertissement pèse sur les esprits dès le début.
	if quest.get("warnings", 0) > 0:
		for hero in heroes:
			_stress(hero, GameData.MENTAL_LOSS_WARNINGS)
	# Deux hostiles dans la même équipe : l'ambiance est tendue, chacun en perd de la santé mentale.
	for i in heroes.size():
		for j in range(i + 1, heroes.size()):
			if GameData.bond_level(heroes[i]["source"], heroes[j]["source"]) == GameData.BOND_HOSTILE:
				_log("%s et %s se regardent de travers : l'ambiance est tendue." % [heroes[i]["name"], heroes[j]["name"]], "disobey")
				_stress(heroes[i], GameData.MENTAL_LOSS_HOSTILE)
				_stress(heroes[j], GameData.MENTAL_LOSS_HOSTILE)


## Fait avancer le combat d'un pas (TICK secondes).
func step() -> void:
	if finished:
		return
	for unit in units:
		unit["prev_pos"] = unit["pos"]  # pour que l'écran glisse en douceur d'un pas à l'autre
	_step()
	time += TICK
	# Sécurité : si personne ne s'est encore touché après CONTACT_WAIT_MAX, le décompte démarre quand même.
	if clock_start < 0 and time >= CONTACT_WAIT_MAX:
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
	hero["order"] = {"kind": "move", "pos": pos}
	hero["path"] = PackedVector2Array()


## Demande à un héros d'attaquer un ennemi précis, jusqu'à ce qu'il tombe.
func order_attack(hero: Dictionary, enemy: Dictionary) -> void:
	if quest.get("duel", false) or not _obeys(hero):  # pas d'ordres pendant un duel
		return
	hero["resting"] = false
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


## La rotation : « tired » part à ROTATION_REAR_DISTANCE cases derrière lui et s'y repose ; l'allié le plus
## frais (au moins ROTATION_FRESH_STAMINA d'endurance, de préférence au corps à corps) prend sa place.
## Pendant ROTATION_VULNERABLE_SECONDS, les deux ne frappent pas et encaissent plus (voir _damage).
## Renvoie l'allié qui prend le poste ({} si personne n'est assez frais : il part quand même).
func _rotate(tired: Dictionary) -> Dictionary:
	var spot: Vector2 = tired["pos"]
	var relief := _find_relief(tired)
	var rear := _free_cell_near(_cell_of(Vector2(spot.x, minf(GRID_H - 2.5, spot.y + GameData.ROTATION_REAR_DISTANCE))))
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


## Le héros obéit-il à l'ordre ? Avec une santé mentale basse, il peut l'ignorer
## (GameData.disobey_chance), puis il boude : il ignore tous les ordres pendant DISOBEY_SULK secondes.
## Loyal réduit le risque ; quand c'est sa loyauté qui le fait obéir, le trait se révèle.
func _obeys(hero: Dictionary) -> bool:
	if time < hero["sulk_until"] or panicking(hero):
		_effect("refuse", hero, hero, "Non !", false)
		return false
	var chance := GameData.disobey_chance(hero["mental"])
	if chance <= 0.0:
		return true
	var loyal := GameData.has_trait(hero["source"], "Loyal")
	var roll := randf()
	if roll < chance * (GameData.LOYAL_DISOBEY_FACTOR if loyal else 1.0):
		hero["sulk_until"] = time + GameData.DISOBEY_SULK
		_effect("refuse", hero, hero, "Non !", false)
		_log("%s, à bout de nerfs, ignore ton ordre." % hero["name"], "disobey")
		return false
	if loyal and roll < chance:
		# Sans sa loyauté, il aurait refusé.
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
		return false
	var target: Dictionary = units[order["target"]]
	if target["hp"] <= 0:
		unit["order"] = {}  # la cible est tombée : ordre accompli
		return false
	unit["target_id"] = target["id"]
	if _in_reach(unit, target, unit["reach"]):
		_try_attack(unit, target, foes)
	else:
		_move_towards(unit, target["pos"])
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
		"prev_pos": Vector2.ZERO,  # position au pas précédent (pour que l'écran glisse en douceur)
		"order": {},               # ordre du joueur en cours (voir order_move, order_attack)
		"post": Vector2.ZERO,      # poste que le héros tient
		"path": PackedVector2Array(),
		"path_timer": 0.0,
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
		# Migraine (après la rage) : jusqu'à ce moment du combat ; elle continue après (GameData.migraine_left).
		"migraine_until": GameData.migraine_left(source) if is_hero else 0.0,
		"person": is_hero,         # un héros (l'adversaire d'un duel aussi) : sa migraine est gardée à la fin
		# Endurance (voir GameData, tower.gd) : seuls les héros s'épuisent.
		"stamina": GameData.STAMINA_MAX,
		"max_stamina": GameData.STAMINA_MAX,
		"stamina_cost": GameData.STAMINA_NOVICE_FACTOR if is_hero and GameData.is_combat_novice(source) else 1.0,
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
		"skill_news": [],          # compétences apprises ou améliorées, pour l'écran de fin
		"shots": 0,                # flèches tirées (font progresser Maîtrise de l'arc)
		# Ce qu'il a fait (croissance de ses stats au prochain niveau, voir GameData.add_activity) :
		# coups portés (Force), esquives et tirs (Dextérité), coups encaissés (Santé), sorts et soins (Intelligence).
		"acts": {"str": 0, "dex": 0, "vit": 0, "int": 0},
		"base_name": source.get("base_name", source["name"]),  # nom sans lettre (Gobelin, pas Gobelin A)
		# Élément de la magie d'un mage (un mage sans élément noté fait du feu).
		"element": source.get("element", "Feu" if fighter_class == "Mage" else ""),
		"kills": [],               # ennemis achevés : [{"name", "boss"}] (pour Tueur de gobelins)
		"took_fire": false,        # a subi des dégâts de feu (pour Résistance aux flammes)
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
	}


# ---------------------------------------------------------------------------
# Champ de bataille
# ---------------------------------------------------------------------------

## Crée le décor : des rochers et des murs au milieu de la carte (des maisons alignées
## en ruelles pour les quêtes de survie), et les remparts de la cité en bas pour la défense.
## On vérifie toujours qu'un chemin relie le haut et le bas de la carte.
func _build_map() -> void:
	_grid.region = Rect2i(0, 0, GRID_W, GRID_H)
	_grid.cell_size = Vector2.ONE
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.update()

	if quest["walls"] > 0:
		_add_obstacle(Rect2i(0, GRID_H - 1, GRID_W, 1), "rampart")

	if quest["type"] == "survival":
		# Des pâtés de maisons séparés par des ruelles.
		for row in [6, 10]:
			var x := randi_range(0, 2)
			while x < GRID_W - 2:
				var width := randi_range(2, 4)
				_try_obstacle(Rect2i(x, row + randi_range(0, 1), mini(width, GRID_W - x), 3), "house")
				x += width + randi_range(2, 3)
	var pieces := randi_range(6, 9)
	for i in pieces:
		var horizontal := randf() < 0.5
		var size := Vector2i(randi_range(2, 4), 1) if horizontal else Vector2i(1, randi_range(2, 3))
		if randf() < 0.4:
			size = Vector2i(randi_range(1, 2), randi_range(1, 2))
		var cell := Vector2i(randi_range(0, GRID_W - size.x), randi_range(5, GRID_H - 8))
		_try_obstacle(Rect2i(cell, size), "rock" if size.x == size.y else "wall")


## Ajoute un morceau de décor s'il ne coupe pas la carte en deux ; sinon on l'enlève.
func _try_obstacle(rect: Rect2i, kind: String) -> void:
	_add_obstacle(rect, kind)
	var top := Vector2i(GRID_W / 2, 1)
	var bottom := Vector2i(GRID_W / 2, GRID_H - 4)
	if _grid.get_id_path(top, bottom).is_empty():
		for x in range(rect.position.x, rect.end.x):
			for y in range(rect.position.y, rect.end.y):
				_grid.set_point_solid(Vector2i(x, y), false)
		obstacles.pop_back()


func _add_obstacle(rect: Rect2i, kind: String) -> void:
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			_grid.set_point_solid(Vector2i(x, y), true)
	obstacles.append({"rect": rect, "kind": kind})


## Place les héros en formation en bas (les tireurs derrière), et les premiers ennemis en haut.
func _place_units() -> void:
	var front: Array[Dictionary] = []
	var back: Array[Dictionary] = []
	for hero in heroes:
		(back if hero["ranged"] else front).append(hero)
	var front_row := GRID_H - 5 if quest["walls"] > 0 else GRID_H - 6
	_place_row(front, front_row)
	_place_row(back, front_row + 2)
	for hero in heroes:
		hero["post"] = hero["pos"]

	for i in mini(ENEMY_SLOTS, enemies.size()):
		_spawn_enemy(enemies[i], randi_range(1, 3))


## Aligne des combattants sur une ligne, centrés, sur des cases libres.
func _place_row(fighters: Array[Dictionary], row: int) -> void:
	for i in fighters.size():
		var x := GRID_W / 2 + (i - fighters.size() / 2) * 2
		fighters[i]["pos"] = _free_cell_near(Vector2i(clampi(x, 0, GRID_W - 1), row))
		fighters[i]["prev_pos"] = fighters[i]["pos"]
		fighters[i]["present"] = true


## Fait entrer un ennemi sur le terrain, sur une case libre de la ligne donnée.
func _spawn_enemy(enemy: Dictionary, row: int) -> void:
	enemy["pos"] = _free_cell_near(Vector2i(randi_range(1, GRID_W - 2), row))
	enemy["prev_pos"] = enemy["pos"]
	enemy["present"] = true


## La case libre la plus proche d'une case donnée (son centre).
func _free_cell_near(cell: Vector2i) -> Vector2:
	for radius in range(0, 6):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				var c := cell + Vector2i(dx, dy)
				if _grid.is_in_boundsv(c) and not _grid.is_point_solid(c) and not _occupied(c):
					return Vector2(c) + Vector2(0.5, 0.5)
	return Vector2(cell) + Vector2(0.5, 0.5)


func _occupied(cell: Vector2i) -> bool:
	for unit in units:
		if unit["present"] and Vector2i(unit["pos"]) == cell:
			return true
	return false


func _cell_of(pos: Vector2) -> Vector2i:
	return Vector2i(clampi(int(pos.x), 0, GRID_W - 1), clampi(int(pos.y), 0, GRID_H - 1))


func _is_blocked(pos: Vector2) -> bool:
	var cell := Vector2i(floori(pos.x), floori(pos.y))
	return not _grid.is_in_boundsv(cell) or _grid.is_point_solid(cell)


## Vrai si rien dans le décor ne cache « to » depuis « from » (pour les tirs et les sorts).
func _line_of_sight(from: Vector2, to: Vector2) -> bool:
	var steps := int(from.distance_to(to) / 0.3) + 1
	for i in range(1, steps):
		if _is_blocked(from.lerp(to, float(i) / steps)):
			return false
	return true


# ---------------------------------------------------------------------------
# Un pas de temps
# ---------------------------------------------------------------------------

func _step() -> void:
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
		if unit["is_hero"] and unit["hp"] > 0 and GameData.has_trait(unit["source"], "Meneur"):
			_lead(unit)
		if unit["person"] and unit["hp"] > 0:
			_berserk_think(unit)
		if unit["hp"] > 0:
			unit["cooldown"] -= TICK
			_think(unit)
		if _check_end():
			return
	_separate()


## Au besoin, un ennemi en réserve entre par le haut de la carte à la place d'un ennemi tombé.
func _call_reinforcements() -> void:
	var on_field := 0
	for enemy in enemies:
		if enemy["present"] and enemy["hp"] > 0:
			on_field += 1
	var waiting := _reserve()
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
			_spawn_enemy(enemy, 0)
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

	# Défense : un ennemi va aux remparts, sauf si un héros lui barre la route.
	if not unit["is_hero"] and quest["walls"] > 0:
		var nearest := _nearest(unit, foes)
		if nearest.is_empty() or unit["pos"].distance_to(nearest["pos"]) > 2.5:
			if unit["pos"].y >= GRID_H - 2.2:
				if unit["cooldown"] <= 0:
					unit["cooldown"] = _attack_time(unit)
					walls = maxi(0, walls - 1)
			else:
				_move_towards(unit, Vector2(unit["pos"].x, GRID_H - 1.5))
			return

	# Protecteur : un allié proche en danger passe avant l'ennemi ; il va se placer à son côté.
	if unit["is_hero"] and not quest.get("duel", false) and GameData.has_trait(unit["source"], "Protecteur"):
		var ward := _ward_of(unit)
		if not ward.is_empty() and unit["pos"].distance_to(ward["pos"]) > GameData.PROTECT_GUARD_RANGE * 0.8:
			_move_towards(unit, ward["pos"])
			return

	if foes.is_empty():
		return
	var target := _choose_target(unit, foes, allies)
	unit["target_id"] = target["id"]

	# Un héros tient son poste tant que les ennemis sont loin.
	if unit["is_hero"] and unit["pos"].distance_to(target["pos"]) > ENGAGE_DISTANCE:
		if unit["pos"].distance_to(unit["post"]) > 0.3:
			_move_towards(unit, unit["post"])
		return

	if unit["ranged"]:
		# Un tireur recule quand un ennemi arrive au contact.
		var closest := _nearest(unit, foes)
		if unit["pos"].distance_to(closest["pos"]) < 1.6:
			_step_away(unit, closest["pos"])
		if _in_reach(unit, target, unit["reach"]):
			_try_attack(unit, target, foes)
		else:
			_move_towards(unit, target["pos"])
	else:
		if _in_reach(unit, target, unit["reach"]):
			_try_attack(unit, target, foes)
		else:
			_move_towards(unit, target["pos"])


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


## Assez près (et, pour un tir, sans décor entre les deux) ?
func _in_reach(unit: Dictionary, target: Dictionary, reach: float) -> bool:
	var distance: float = unit["pos"].distance_to(target["pos"])
	if distance > reach + 0.05:
		return false
	return reach <= MELEE_REACH_MAX or _line_of_sight(unit["pos"], target["pos"])


## Temps entre deux attaques : plus court avec de la dextérité, et selon l'arme (dague rapide, lance lente).
func _attack_time(unit: Dictionary) -> float:
	# Vivacité (compétence de promotion) : des coups plus rapides.
	var quick := 1.0 - GameData.skill_level(unit["skills"], "Vivacité") * GameData.QUICKNESS_PER_LEVEL
	return maxf(0.4, BASE_ATTACK_TIME * 15.0 / maxf(5.0, unit["spd"] * _fear(unit)) * unit["weapon_speed"] * quick)


func _move_speed(unit: Dictionary) -> float:
	var speed: float = BASE_SPEED + unit["spd"] * _fear(unit) * SPEED_PER_DEX
	if unit["exhausted"]:
		speed *= GameData.STAMINA_EXHAUSTED_SPEED
	return speed * (0.8 if unit["boss"] else 1.0)


## Endurance : se déplacer et frapper la vident (deux fois plus vite pour un novice). À 0 : épuisé.
func _spend_stamina(unit: Dictionary, amount: float) -> void:
	if not unit["person"] or amount <= 0.0:
		return
	unit["stamina"] = maxf(0.0, unit["stamina"] - amount * unit["stamina_cost"])
	if unit["stamina"] <= 0.0 and not unit["exhausted"]:
		unit["exhausted"] = true
		_log("%s est épuisé." % _name_with_stars(unit), "disobey")


## Endurance : elle remonte quand le héros n'est au contact d'aucun ennemi. Épuisé, il reprend ses
## forces à STAMINA_RECOVERED.
func _stamina_tick(unit: Dictionary) -> void:
	var foes := _alive(enemies if unit["is_hero"] else heroes)
	if foes.any(func(foe): return unit["pos"].distance_to(foe["pos"]) <= GameData.STAMINA_CONTACT_RANGE):
		return
	# Au repos à l'arrière (rotation, arrivé à son poste de repos) : trois fois plus vite.
	var rate := GameData.STAMINA_REGEN_PER_SECOND
	if unit["resting"] and unit["order"].is_empty():
		rate *= GameData.ROTATION_REST_FACTOR
	unit["stamina"] = minf(unit["max_stamina"], unit["stamina"] + rate * TICK)
	if unit["exhausted"] and unit["stamina"] >= GameData.STAMINA_RECOVERED:
		unit["exhausted"] = false
	if unit["resting"] and unit["stamina"] >= unit["max_stamina"]:
		unit["resting"] = false  # reposé : il retourne au combat
		_log("%s a repris son souffle." % unit["name"])


## Épuisé (endurance à 0) : attaque et défense x STAMINA_EXHAUSTED_FACTOR.
func _tired(unit: Dictionary) -> float:
	return GameData.STAMINA_EXHAUSTED_FACTOR if unit["exhausted"] else 1.0


## La peur : toutes ses stats x FEAR_STAT_FACTOR (attaque et défense dans _mind, vitesse, critiques).
func _fear(unit: Dictionary) -> float:
	return GameData.FEAR_STAT_FACTOR if afraid(unit) else 1.0


## Avance vers un point en suivant un chemin qui contourne le décor.
func _move_towards(unit: Dictionary, goal: Vector2) -> void:
	unit["path_timer"] -= TICK
	if unit["path"].is_empty() or unit["path_timer"] <= 0:
		unit["path_timer"] = PATH_REFRESH
		var ids := _grid.get_id_path(_cell_of(unit["pos"]), _cell_of(goal), true)
		var path := PackedVector2Array()
		for i in range(1, ids.size()):
			path.append(Vector2(ids[i]) + Vector2(0.5, 0.5))
		if not path.is_empty():
			path[path.size() - 1] = goal if not _is_blocked(goal) else path[path.size() - 1]
		unit["path"] = path
	var step := _move_speed(unit) * TICK
	var start: Vector2 = unit["pos"]
	var path: PackedVector2Array = unit["path"]
	while step > 0 and not path.is_empty():
		var next: Vector2 = path[0]
		var distance: float = unit["pos"].distance_to(next)
		if distance <= step:
			unit["pos"] = next
			path.remove_at(0)
			step -= distance
		else:
			unit["pos"] += (next - unit["pos"]).normalized() * step
			step = 0
	unit["path"] = path
	_spend_stamina(unit, start.distance_to(unit["pos"]) * GameData.STAMINA_MOVE_COST)


## Recule d'un pas, à l'opposé d'une menace, si la place est libre.
func _step_away(unit: Dictionary, threat: Vector2) -> void:
	var direction: Vector2 = (unit["pos"] - threat).normalized()
	var next: Vector2 = unit["pos"] + direction * _move_speed(unit) * TICK
	if not _is_blocked(next):
		_spend_stamina(unit, _move_speed(unit) * TICK * GameData.STAMINA_MOVE_COST)
		unit["pos"] = next
		unit["path"] = PackedVector2Array()


## Les combattants trop proches se poussent un peu, sans entrer dans le décor.
func _separate() -> void:
	var present := _alive(units)
	for i in present.size():
		for j in range(i + 1, present.size()):
			var a: Dictionary = present[i]
			var b: Dictionary = present[j]
			var offset: Vector2 = b["pos"] - a["pos"]
			var distance := offset.length()
			if distance >= PERSONAL_SPACE:
				continue
			if distance < 0.01:
				offset = Vector2(randf_range(-1, 1), randf_range(-1, 1))
			var push := offset.normalized() * (PERSONAL_SPACE - distance) * 0.5
			if not _is_blocked(a["pos"] - push):
				a["pos"] -= push
			if not _is_blocked(b["pos"] + push):
				b["pos"] += push


# ---------------------------------------------------------------------------
# Attaques et soins
# ---------------------------------------------------------------------------

func _try_attack(attacker: Dictionary, target: Dictionary, foes: Array) -> void:
	if attacker["cooldown"] > 0 or time < attacker["swap_until"]:
		return  # (pendant un échange de place, il ne frappe pas)
	attacker["cooldown"] = _attack_time(attacker)
	_spend_stamina(attacker, GameData.STAMINA_ATTACK_COST)
	match attacker["class"]:
		"Mage":
			if attacker["mana"] >= SPELL_MANA_COST:
				# Le sort touche la cible et tous les ennemis autour d'elle.
				attacker["mana"] -= SPELL_MANA_COST
				for foe in foes:
					if foe["pos"].distance_to(target["pos"]) <= SPELL_RADIUS:
						_hit(attacker, foe, 0.7, false, "spell")
			else:
				# À court de mana : un petit trait de magie, sur la cible seulement.
				_hit(attacker, target, MANA_BOLT_POWER, false, "bolt")
		"Soigneur":
			_hit(attacker, target, 1.0, false, "spell")
		_:
			if attacker["ranged"]:
				# Un tir (arc). Les archers visent mieux : +25 % de critiques, et leurs critiques font x2.
				var archer: bool = attacker["class"] == "Archer"
				var critical: bool = randf() < attacker["crit"] * _fear(attacker) + (0.25 if archer else 0.0)
				var power := (2.0 if archer else 1.5) if critical else 1.0
				_hit(attacker, target, power * attacker["weapon_power"], critical, "arrow")
				if attacker["is_hero"]:
					attacker["shots"] += 1
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
						critical = randf() < attacker["crit"] * _fear(attacker)
						power = 1.5 if critical else 1.0
				_hit(attacker, target, power * attacker["weapon_power"], critical, "hit")


## Un coup : dégâts, effet à l'écran, saignement, situation critique, chute.
func _hit(attacker: Dictionary, target: Dictionary, power: float, critical: bool, kind: String) -> void:
	var amount := _damage(attacker, target, power, critical, kind)
	# Activité (croissance) : l'esquive exerce la Dextérité ; le coup porté, la stat de l'attaque ;
	# le coup encaissé, la Santé.
	if amount < 0:
		target["acts"]["dex"] += 1
	else:
		attacker["acts"][ACT_STAT.get(kind, "str")] += 1
		target["acts"]["vit"] += 1
	var text := "esquive !" if amount < 0 else "-%d" % amount
	_effect(kind, attacker, target, text, critical and amount >= 0)
	if target["hp"] <= 0 and target["killer"] == "":
		_announce_fall(target, "tué par %s (niv. %d)" % [attacker["name"], attacker["level"]], false, {"attacker": attacker, "kind": kind})
		if attacker["is_hero"]:
			attacker["kills"].append({"name": target["base_name"], "boss": target["boss"]})


## Retire des points de vie à la cible et renvoie les dégâts infligés (-1 si elle esquive).
## « kind » : "hit" (corps à corps), "arrow" (flèche) ou "spell" (sort).
func _damage(attacker: Dictionary, target: Dictionary, power: float, critical := false, kind := "hit") -> int:
	_start_clock()  # premier coup échangé : c'est le contact (rien ne change si le décompte tourne déjà)
	# Mouvement souple : une chance d'éviter complètement le coup (moins face à la précision
	# d'Analyse froide, et à celle d'Œil de faucon pour les flèches et les sorts).
	var dodge: float = GameData.skill_level(target["skills"], "Mouvement souple") * DODGE_PER_LEVEL \
		- GameData.skill_level(attacker["skills"], "Analyse froide") * GameData.COLD_ANALYSIS_PER_LEVEL
	if kind != "hit":
		dodge -= GameData.skill_level(attacker["skills"], "Œil de faucon") * GameData.HAWK_EYE_PRECISION_PER_LEVEL
	if randf() < dodge:
		return -1
	# Maîtrise de l'arme que tient l'attaquant (épée, arc...) : chaque niveau renforce ses coups.
	if kind != "spell" and attacker["weapon_skill"] != "":
		power *= 1.0 + GameData.skill_level(attacker["skills"], attacker["weapon_skill"]) * GameData.WEAPON_SKILL_BONUS_PER_LEVEL
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
	# Santé mentale basse : l'attaquant frappe moins fort, la cible se défend moins bien (voir _mind).
	# Un ami ou un frère d'armes tout près : l'inverse (voir _bond).
	var raw: float = attacker["atk"] * _mind(attacker) * _bond(attacker) * power * randf_range(0.9, 1.1) \
		- target["def"] * _mind(target) * _bond(target) * 0.5
	# Sort de feu : Résistance aux flammes de la cible (80 % au plus).
	if kind == "spell" and attacker["element"] == "Feu":
		raw *= 1.0 - minf(0.8, GameData.skill_level(target["skills"], "Résistance aux flammes") * GameData.FIRE_RESIST_PER_LEVEL)
		target["took_fire"] = true
	# Peau de pierre (compétence de promotion) : la cible encaisse mieux.
	raw *= 1.0 - GameData.skill_level(target["skills"], "Peau de pierre") * GameData.STONE_SKIN_PER_LEVEL
	# Utilisation du bouclier : avec un bouclier en main, la cible pare une partie du coup.
	if target["shield"]:
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


func _try_heal(healer: Dictionary, target: Dictionary) -> void:
	if healer["cooldown"] > 0 or time < healer["swap_until"]:
		return
	healer["cooldown"] = _attack_time(healer)
	healer["mana"] -= HEAL_MANA_COST
	_spend_stamina(healer, GameData.STAMINA_ATTACK_COST)
	var amount := roundi(healer["atk"] * _mind(healer) * _bond(healer) * 2.0 * randf_range(0.9, 1.1))
	amount = mini(amount, target["max_hp"] - target["hp"])
	target["hp"] += amount
	healer["contribution"] += amount
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
		_stress(target, GameData.MENTAL_LOSS_BLEEDING)  # voir son propre sang couler
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
	var amount := mini(maxi(1, roundi(bleed["amount"] * (1.0 - resist))), unit["hp"])
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
		var chance := HAN_AWAKENING_CHANCE if GameData.is_han(fighter["source"]) else AWAKENING_CHANCE
		if randf() < chance:
			_awaken(fighter, ratio)
	# Acquisition de Berserk (une seule fois) : aux portes de la mort, avec la rage de vivre.
	# (Son utilisation, ensuite, est à part : voir _berserk_think.)
	if ratio <= BERSERK_LEARN_HP and not fighter["death_door_tried"]:
		fighter["death_door_tried"] = true
		if randf() < DEATH_DOOR_CHANCE and GameData.can_learn_skill(fighter["source"], fighter["skills"], "Berserk"):
			fighter["skills"].append(GameData.new_skill("Berserk"))
			_log("Aux portes de la mort, %s refuse de mourir... Nouvelle compétence : Berserk !" \
				% _name_with_stars(fighter), "awaken")
			fighter["skill_news"].append("%s — nouvelle compétence : Berserk" % fighter["name"])


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
		if skill_name == "Berserk" and ratio > BERSERK_LEARN_HP and not han:
			continue  # Berserk ne vient qu'aux portes de la mort (Han : dès la situation critique)
		if GameData.can_learn_skill(fighter["source"], fighter["skills"], skill_name):
			candidates.append(skill_name)
	# Indomptable : candidate seulement si le héros saigne au moment de la situation critique.
	if fighter["bleed"]["ticks"] > 0 and GameData.can_learn_skill(fighter["source"], fighter["skills"], "Indomptable"):
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
		if float(ally["hp"]) / ally["max_hp"] < GameData.BERSERK_DANGER_HP \
				and unit["pos"].distance_to(ally["pos"]) <= GameData.BERSERK_ALLY_RANGE:
			return true
	return false


## Berserk, compétence active à bascule : le héros décide lui-même d'entrer en rage ou d'en sortir.
## Il y entre quand le combat est difficile (_in_danger), sauf en pleine peur ou panique, pendant une
## migraine, sous BERSERK_STOP_MENTAL de santé mentale, ou juste après que le Maître la lui a fait couper.
## Il en sort quand le danger est passé (après BERSERK_MIN_SECONDS au moins), sous BERSERK_STOP_MENTAL,
## sous BERSERK_STOP_HP de sa vie (SURPASS_STOP_HP en Surpassement). Une rage ordonnée par le Maître n'est
## coupée que sur ordre. (Plus tard, ces coupures dépendront du caractère : Maîtrise de soi.)
func _berserk_think(unit: Dictionary) -> void:
	if not can_berserk(unit) or panicking(unit) or afraid(unit):
		return
	if not unit["berserk"]:
		var surpass_ready := GameData.skill_level(unit["skills"], "Surpassement") > 0 \
			or GameData.fusion_ready(unit["skills"], "Surpassement")
		var min_hp := GameData.SURPASS_STOP_HP if surpass_ready else GameData.BERSERK_STOP_HP
		if time >= unit["berserk_hold_until"] and time >= unit["migraine_until"] \
				and unit["mental"] >= GameData.BERSERK_STOP_MENTAL \
				and float(unit["hp"]) / unit["max_hp"] >= min_hp and _in_danger(unit):
			_enter_berserk(unit)
		return
	if unit["berserk_ordered"] or time - unit["berserk_since"] < GameData.BERSERK_MIN_SECONDS:
		return
	var stop_hp := GameData.SURPASS_STOP_HP if unit.get("surpass", false) else GameData.BERSERK_STOP_HP
	var worn_out: bool = float(unit["hp"]) / unit["max_hp"] < stop_hp
	if worn_out or unit["mental"] < GameData.BERSERK_STOP_MENTAL or not _in_danger(unit):
		_exit_berserk(unit)


## Entre en rage : Force, Santé, Dextérité +5 et Intelligence -10 (voir GameData.berserk_stat_changes),
## traduits en valeurs de combat comme GameData.combat_stats (Force ou Intelligence : attaque ;
## Santé : défense, la vie maximum ne change pas ; Dextérité : vitesse et critiques).
func _enter_berserk(fighter: Dictionary) -> void:
	# Fusion : Calme et Berserk au niveau maximum fusionnent en Surpassement au moment où la rage monte.
	if GameData.fusion_ready(fighter["skills"], "Surpassement"):
		_announce_fusion(fighter, GameData.fuse_skills(fighter["skills"], "Surpassement"))
	var stats := GameData.berserk_stat_changes(fighter["skills"])
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
		if not GameData.can_learn_skill(fighter["source"], fighter["skills"], skill_name):
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
	_stress(unit, GameData.MENTAL_BERSERK_PER_SECOND * TICK * (GameData.SURPASS_MENTAL_FACTOR if surpass else 1.0))
	if unit["hp"] <= 0:
		return
	var drain := GameData.SURPASS_DRAIN_PER_SECOND if surpass else GameData.BERSERK_DRAIN_PER_SECOND
	unit["drain"] = unit.get("drain", 0.0) + unit["max_hp"] * drain * TICK
	var amount := mini(int(unit["drain"]), unit["hp"])
	if amount <= 0:
		return
	unit["drain"] -= amount
	unit["hp"] -= amount
	if _duel_yields(unit):
		return  # (un duel s'arrête avant la mort)
	if unit["hp"] <= 0:
		_announce_fall(unit, "épuisé par Surpassement" if surpass else "épuisé par Berserk")


## Après le combat : un héros qui a saigné et tient encore debout peut apprendre
## (ou améliorer) Résistance à la douleur. Un héros debout, épée et bouclier en main,
## dont les deux maîtrises sont au maximum, les fusionne en « Épée et bouclier ».
func _after_fight() -> void:
	# Encore à l'agonie quand le combat s'arrête : sauvé si un allié debout peut le rejoindre et rester à son
	# côté avant la fin de ses AGONY_SECONDS ; sinon il meurt. Une arme plantée : personne ne peut le sauver.
	for hero in heroes:
		if not hero["agony"]:
			continue
		var left: float = hero["agony_until"] - time - (GameData.AGONY_RESCUE_SECONDS - hero["rescue"])
		var rescuer: Dictionary = {}
		for ally in _alive(heroes):
			if not hero["embedded"] and ally["pos"].distance_to(hero["pos"]) / _move_speed(ally) <= left:
				rescuer = ally
				break
		if rescuer.is_empty():
			_die(hero, hero["agony_cause"])
		else:
			_stabilize(hero, rescuer["name"])
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
		if standing and fighter["took_fire"] and randf() < GameData.FIRE_RESIST_CHANCE:
			_improve_skill(fighter, "Résistance aux flammes", "a appris du feu")
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
		fighter["rescue"] += TICK
		if fighter["rescue"] >= GameData.AGONY_RESCUE_SECONDS:
			_stabilize(fighter, helper["name"])
			return
	if time >= fighter["agony_until"]:
		_die(fighter, fighter["agony_cause"])


## Sauvé de l'agonie (« by » : l'allié ou la potion) : il sort du combat avec AGONY_STABILIZED_HP de sa vie.
func _stabilize(fighter: Dictionary, by: String) -> void:
	fighter["agony"] = false
	fighter["stabilized"] = true
	fighter["present"] = false  # mis à l'abri : il ne combat plus
	fighter["hp"] = maxi(1, roundi(fighter["max_hp"] * GameData.AGONY_STABILIZED_HP))
	var text := "%s est stabilisé grâce à %s." % [_name_with_stars(fighter), by]
	_log(text + " Il est mis à l'abri.", "awaken")
	_alert("Stabilisé", [text, "Il sort du combat, sa vie n'est plus en danger."])
	fighter["mind_news"].append("%s a frôlé la mort : stabilisé grâce à %s." % [fighter["name"], by])


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
	hero["care"] += TICK
	if hero["care"] < GameData.CARE_SECONDS:
		return
	hero["care"] = 0.0
	hero["bleed"]["ticks"] = 0
	hero["bleed"]["heavy"] = false
	var text := "%s a arrêté le saignement de %s." % [carer["name"], hero["name"]]
	_log(text, "awaken")
	_alert("Soin d'urgence", [text])


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
		_log("%s tombe au combat !" % fighter["name"])
		# Voir un allié tomber ébranle les autres (Protecteur : deux fois plus ; un ami ou un frère d'armes :
		# bien plus encore, voir BOND_DEATH_FACTOR).
		for ally in _alive(heroes):
			var loss := GameData.MENTAL_LOSS_ALLY_DEATH
			if GameData.has_trait(ally["source"], "Protecteur"):
				loss *= GameData.PROTECTOR_DEATH_FACTOR
				_reveal(ally, "Protecteur")
			var bond: int = ally["bonds"].get(fighter["id"], 0)
			loss *= GameData.BOND_DEATH_FACTOR[bond]
			if bond >= GameData.BOND_FRIEND:
				_log("%s voit tomber son %s %s..." % [ally["name"],
					"frère d'armes" if bond == GameData.BOND_BROTHERS else "ami", fighter["name"]], "bleed")
			_stress(ally, loss)
			# Voir mourir quelqu'un tout près peut faire peur (voir _scare).
			if ally["pos"].distance_to(fighter["pos"]) <= GameData.FEAR_SIGHT:
				_scare(ally, GameData.FEAR_ALLY_DEATH_CHANCE, "la mort de %s" % fighter["name"])


## Bonus d'un héros qui se bat à moins de BOND_RANGE cases d'un ami ou d'un frère d'armes
## (le meilleur lien compte) : 1.05 ou 1.10 ; 1.0 sinon (et pour les ennemis).
func _bond(unit: Dictionary) -> float:
	var best := 0.0
	for ally_id in unit["bonds"]:
		var ally: Dictionary = units[ally_id]
		if ally["hp"] > 0 and ally["present"] and unit["pos"].distance_to(ally["pos"]) <= GameData.BOND_RANGE:
			best = maxf(best, GameData.BOND_FIGHT_BONUS[unit["bonds"][ally_id]])
	return 1.0 + best


# ---------------------------------------------------------------------------
# Santé mentale en direct, rupture
# ---------------------------------------------------------------------------

## Efficacité selon la santé mentale du moment (1.0 pour les ennemis ; voir GameData.mental_factor).
## Un héros qui a peur (voir _scare) ou épuisé (_tired) frappe et se défend moins bien.
func _mind(unit: Dictionary) -> float:
	if not unit["is_hero"]:
		return _tired(unit)  # (l'adversaire d'un duel s'épuise aussi)
	return GameData.mental_factor(unit["mental"]) * _fear(unit) * _tired(unit)


## Un héros perd de la santé mentale (moins avec Calme). À 0, c'est la rupture (une fois par combat).
func _stress(fighter: Dictionary, amount: float) -> void:
	if not fighter["is_hero"] or fighter["hp"] <= 0 or amount <= 0.0 or quest.get("duel", false):
		return  # (un duel compte à part, voir GameData.finish_duel)
	fighter["mental"] = maxf(0.0, fighter["mental"] - amount * (1.0 - GameData.mental_guard(fighter["skills"])))
	if fighter["mental"] <= 0.0 and not fighter["ruptured"]:
		_rupture(fighter)


## Blessure : perte proportionnelle à la vie perdue (MENTAL_LOSS_WOUNDS pour une vie entière).
func _stress_wound(fighter: Dictionary, amount: int) -> void:
	_stress(fighter, GameData.MENTAL_LOSS_WOUNDS * float(amount) / fighter["max_hp"])


## Un boss arrive sur le terrain : chaque héros debout encaisse le choc (Courageux moitié, Lâche double).
func _check_boss_arrival() -> void:
	if _boss_seen or not enemies.any(func(e): return e["boss"] and e["present"] and e["hp"] > 0):
		return
	_boss_seen = true
	for hero in _alive(heroes):
		var loss := GameData.MENTAL_LOSS_BOSS
		if GameData.has_trait(hero["source"], "Courageux"):
			loss *= GameData.BRAVE_BOSS_FACTOR
			_reveal(hero, "Courageux")
		if GameData.has_trait(hero["source"], "Lâche"):
			loss *= GameData.COWARD_BOSS_FACTOR
			_reveal(hero, "Lâche")
		_stress(hero, loss)
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
		# Éveil : le « craquage positif ». L'esprit se brise... et se reforge.
		if GameData.has_trait(source, "Courageux"):
			_reveal(fighter, "Courageux")
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
	# Il court vers le bas de la carte, loin des ennemis qui arrivent par le haut.
	fighter["flee_to"] = _free_cell_near(Vector2i(_cell_of(fighter["pos"]).x, GRID_H - 2))
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
			_stress(ally, GameData.PANIC_SPREAD_LOSS)


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
	var chance := GameData.fear_chance(fighter["source"], base_chance, _fear_threats(fighter, novice_counts))
	if randf() < chance:
		_frighten(fighter, what)


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
	_stress(fighter, GameData.FEAR_MENTAL_LOSS)
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
		fighter["flee_to"] = _free_cell_near(Vector2i(_cell_of(fighter["pos"]).x, GRID_H - 2))


## Chaque pas, pour un héros qui peut avoir peur : la vue du premier ennemi à portée peut l'effrayer ;
## s'il a peur, un allié tout près (FEAR_LIFT_RANGE) qui est son ami, son frère d'armes, ou Courageux,
## le rassure : au bout de FEAR_LIFT_SECONDS, la peur se lève (fuite comprise).
func _fear_tick(unit: Dictionary) -> void:
	if not unit["saw_enemy"] and _alive(enemies).any(func(foe): return unit["pos"].distance_to(foe["pos"]) <= ENGAGE_DISTANCE):
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
	return {}


## Le Protecteur encaisse PROTECT_SHARE du coup destiné à « ward » (il peut tomber à sa place).
## Renvoie ce qui reste pour la cible.
func _cover(guardian: Dictionary, ward: Dictionary, amount: int) -> int:
	var share := mini(roundi(amount * GameData.PROTECT_SHARE), guardian["hp"])
	if share <= 0:
		return amount
	guardian["hp"] -= share
	guardian["acts"]["vit"] += 1  # encaisser exerce la Santé
	_effect("hit", guardian, guardian, "-%d" % share, false)
	if not guardian.get("covered", {}).has(ward["id"]):
		guardian["covered"] = guardian.get("covered", {})
		guardian["covered"][ward["id"]] = true
		_log("%s se jette devant %s pour le protéger !" % [guardian["name"], ward["name"]], "awaken")
		_reveal(guardian, "Protecteur")
	if guardian["hp"] <= 0:
		_announce_fall(guardian, "tombé en protégeant %s" % ward["name"])
	else:
		_stress_wound(guardian, share)
	return amount - share


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


## Une fenêtre système, affichée par l'écran de combat.
func _alert(title: String, lines: Array, danger := false) -> void:
	alerts.append({"t": time, "title": title, "lines": lines, "danger": danger})


## Nom suivi des étoiles, comme dans les fenêtres système : « Hansen (★) ».
func _name_with_stars(fighter: Dictionary) -> String:
	if not fighter["is_hero"]:
		return fighter["name"]
	return "%s (%s)" % [fighter["name"], fighter["stars"]]


## L'adversaire vivant le plus proche.
func _nearest(unit: Dictionary, foes: Array) -> Dictionary:
	var result: Dictionary = {}
	var best := INF
	for foe in foes:
		var distance: float = unit["pos"].distance_to(foe["pos"])
		if distance < best:
			best = distance
			result = foe
	return result


## L'adversaire vivant qui a le moins de points de vie.
func _weakest(foes: Array) -> Dictionary:
	var result: Dictionary = {}
	for target in foes:
		if result.is_empty() or target["hp"] < result["hp"]:
			result = target
	return result


## L'allié vivant le plus blessé (en proportion, sous 90 % de sa vie), ou {} si personne ne l'est.
func _most_wounded(allies: Array) -> Dictionary:
	var result: Dictionary = {}
	var lowest_ratio := 0.9
	for ally in allies:
		var ratio: float = float(ally["hp"]) / ally["max_hp"]
		if ratio < lowest_ratio:
			lowest_ratio = ratio
			result = ally
	return result


## Les combattants présents sur le terrain et encore debout.
func _alive(fighters: Array) -> Array:
	return fighters.filter(func(f): return f["present"] and f["hp"] > 0)


func _log(text: String, style := "") -> void:
	events.append({"t": time, "text": text, "style": style})


func _effect(kind: String, from: Dictionary, to: Dictionary, text: String, crit: bool) -> void:
	effects.append({"t": time, "kind": kind, "from": from["id"], "to": to["id"], "text": text, "crit": crit})
