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
## (La carte elle-même, ses zones de départ et ses ruelles : voir MapGenerator.)
const GRID_W := MapGenerator.WIDTH
const GRID_H := MapGenerator.LENGTH

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
## Déplacements (cahier, « Combat v2 », section 3 ; étape C1) : coûts ajoutés aux cases pour la recherche de
## chemin (voir _refresh_costs) : une case où quelqu'un se tient immobile (CROWD_STILL_COST) ou passe
## (CROWD_MOVING_COST) ; pour les héros, une case à portée d'un tireur ennemi (DANGER_COST par tireur,
## DANGER_MAX_COST au plus). Champs de flux des monstres (voir _follow_flow) : recalculés au plus toutes les
## FLOW_REFRESH secondes si leur cible a changé de case, et toutes les FLOW_MAX_AGE secondes (la foule bouge) ;
## à moins de FLOW_NEAR du but en marchant (NEAR_MARGIN de plus une fois près, voir _near), le monstre prend son
## propre chemin. Bloqué plus de REPATH_BLOCKED secondes : nouveau chemin qui évite le passage bouché (un monstre quitte alors le flux de la horde pendant
## DETOUR_SECONDS : il essaie une autre ruelle). Chiffres provisoires.
const CROWD_STILL_COST := 3.0
const CROWD_MOVING_COST := 0.5
const DANGER_COST := 1.0
const DANGER_MAX_COST := 2.0
const FLOW_REFRESH := 0.5
const FLOW_MAX_AGE := 2.0
const FLOW_NEAR := 3.0
const NEAR_MARGIN := 2.0
const REPATH_BLOCKED := 1.0
const DETOUR_SECONDS := 3.0
const BLOCKED_PATH_COST := 50.0

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
## Han a cette chance d'apprendre Berserk, avec une forte envie de vivre. (Les autres héros : seulement
## Courageux ou Ambitieux, rarement et une seule fois dans leur vie, voir _berserk_door.)
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

## La carte du combat, en donnée (voir MapGenerator.generate_map) : à donner avant start() ; vide, start()
## en fabrique une. Le champ de bataille « 3D sur grille » qui en est tiré (voir BattleMap) : hauteur et type de
## chaque case.
var map_data: Dictionary = {}
var map := BattleMap.new()

## Remparts de la cité (quête de défense seulement).
var walls := 0

## Terrain de survie : la sortie de chaque ruelle côté héros (de gauche à droite ; vide hors de la survie),
## et si un Meneur a déjà organisé la défense (voir _organize_defense).
var alley_exits: Array[Vector2] = []
var _defense_organized := false

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

## Qui va aider qui (agonie, soin d'urgence) : {numéro de l'aidant: numéro du blessé}, recalculé à chaque pas.
var _helpers := {}
## Moment où chaque place d'ennemi s'est libérée (pour faire venir un renfort après un délai).
var _free_since := {}
## Vrai une fois que les héros ont vu un boss arriver (le stress du boss ne compte qu'une fois).
var _boss_seen := false
## Survie : dernière vague annoncée (voir current_wave).
var _wave_announced := 0
## Formations (voir _update_formations) : l'équipe couvre-t-elle les trois portées ? Le mur de boucliers
## a-t-il déjà été annoncé ?
var ranges_covered := false
var _wall_announced := false
## Déplacements (voir « Déplacements » plus bas) : qui se tient immobile dans chaque case ({indice: numéro}),
## les cases où se tient quelqu'un ({indice: vrai}), les cases d'attaque réservées ({indice: numéro}), les champs
## de flux des monstres ({numéro de la cible: {"cell", "time", "dist"}}), prochain calcul des coûts.
var _still_at := {}
var _taken := {}
var _slots := {}
var _flows := {}
var _costs_due := 0.0
## Perception en bâtonnets (Combat v2, C3 ; voir BattlePerception) : ce que chacun voit, entend et sait. On ne
## cible que ce que l'on connaît ; un coup d'un ennemi qu'on ne voit pas est une attaque surprise (_surprise).
## « perception_on » faux : tout le monde sait tout, comme avant C3 (interrupteur pour comparer, sim_tower).
var perception: BattlePerception
var perception_on := true
## Attaques surprises subies par chaque camp pendant ce combat (mesures).
var surprises := {"heroes": 0, "enemies": 0}
## IA tactique des héros (C3 ; voir BattleTactics) : un héros libre choisit son attitude et sa case selon ce qu'il
## sait. « tactical_ai » faux : l'ancien comportement (tous foncent ; interrupteur pour comparer, sim_tower).
## « tactics_context » : le contexte de ses habitudes (type de quête | famille d'ennemis | gabarit de terrain).
var tactics: BattleTactics
var tactical_ai := true
var tactics_context := ""


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


## Survie (terrain à ruelles), au début du combat : un héros Meneur (ni effrayé ni en panique) forme
## lui-même l'équipe : les porteurs de bouclier côte à côte (un mur de boucliers) au milieu, DEFENSE_LINE_GAP
## rangs sous la sortie des ruelles ; les autres au corps à corps juste derrière eux (un lancier d'abord, il
## frappe par-dessus le mur) ; les tireurs sur les toits les plus proches de la sortie des ruelles, ceux qu'on
## atteint de son côté (Combat v2, C1 ; sans toit : derrière les autres). Un tireur posté en hauteur y reste
## et tire (voir _think). Fenêtre « X organise la défense », trait révélé.
## Moins de deux boucliers : pas de mur, il ne déplace personne.
## Pour le mur et le corps à corps, ce sont des postes de départ, pas une consigne : quand les ennemis arrivent,
## ils se battent comme les autres (étape 0, simulation de l'étage 5 : tenir le poste au sol, ou les tireurs sur
## les anciennes hauteurs d'un niveau, faisait perdre bien plus souvent, les héros restant figés face aux archers
## ennemis ; avec les toits à 2 niveaux de C1, les tireurs postés en haut gagnent au contraire). Un ordre du
## Maître passe avant. Sans Meneur, les héros restent sur leur ligne de départ et attendent les ordres du Maître.
const DEFENSE_LINE_GAP := 2
## Le Meneur envoie aussi les tireurs sur les toits (C1, gardé après simulation : étage 5, équipe préparée,
## 3 x 300 combats, sans Meneur 66 %, Meneur P5 65,8 %, P5 + toits 71,5 %). Interrupteur pour comparer (sim_tower).
var leader_roof_shooters := true


func _organize_defense() -> void:
	var leader: Dictionary = {}
	for hero in _alive(heroes):
		if GameData.has_trait(hero["source"], "Meneur") and not panicking(hero) and not afraid(hero):
			leader = hero
			break
	if leader.is_empty():
		return
	_defense_organized = true
	# (un héros qui a déjà un ordre du Maître le garde ; un héros placé par le Maître avant le combat aussi)
	var free := _alive(heroes).filter(func(h): return h["order"].is_empty() and h["present"] and not h.get("placed", false))
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


## Œil de faucon (C3, compétence active) : ordre du Maître ; le héros voit deux fois plus loin pendant
## HAWK_EYE_SECONDS (voir BattlePerception). Il l'active aussi de lui-même quand il ne voit plus l'ennemi.
func order_hawk_eye(hero: Dictionary) -> void:
	if quest.get("duel", false) or not can_hawk_eye(hero) or not _obeys(hero):
		return
	perception.activate_hawk_eye(hero)


func can_hawk_eye(hero: Dictionary) -> bool:
	return perception_on and perception != null and hero["is_hero"] and perception.can_hawk_eye(hero)


## Vrai si ce combattant possède Berserk (ou Surpassement) et peut s'en servir.
func can_berserk(unit: Dictionary) -> bool:
	return unit["person"] and unit["hp"] > 0 and GameData.skill_level(unit["skills"], "Berserk") > 0


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
	}


# ---------------------------------------------------------------------------
# Champ de bataille
# ---------------------------------------------------------------------------

## Prépare le champ de bataille à partir de la carte (map_data, voir MapGenerator) ; sans carte donnée (duel,
## ancien combat en cours), on en fabrique une avec une graine au hasard.
func _build_map() -> void:
	if map_data.is_empty():
		map_data = MapGenerator.generate_map(quest.get("floor", 0), quest, randi())
	map.from_data(map_data)
	alley_exits.assign(map_data.get("alley_exits", []))


## Vrai si ce combattant se tient en hauteur (au-dessus du sol).
func is_high(unit: Dictionary) -> bool:
	return height_of(unit) > 0


## Le centre de chaque case haute (2 niveaux et plus : toits, clocher, rempart, sommet d'une butte), là où
## l'on peut se tenir (pour un ordre « monte là-haut »).
func height_cells() -> Array:
	var cells := []
	for i in map.heights.size():
		var cell := map.cell_at(i)
		if map.walkable(cell) and map.heights[i] >= 2 and map.kind_at(cell) != BattleMap.Kind.LADDER:
			cells.append(BattleMap.center(cell))
	return cells


## Place les héros en formation en bas (les tireurs derrière), et les premiers ennemis en haut.
func _place_units() -> void:
	_place_heroes()
	# (Survie : seulement la première vague ; les autres attendent leur tour, voir current_wave.)
	var first := enemies.filter(func(e): return e["wave"] == 0)
	for i in mini(ENEMY_SLOTS, first.size()):
		var start = first[i]["source"].get("start")  # (place fixée par l'étage, voir MapGenerator.generate)
		if start != null:
			_spawn_enemy(first[i], start.y, start.x)
		else:
			var enemy_rows: Vector2i = map_data.get("enemy_rows", MapGenerator.ENEMY_ROWS)
			_spawn_enemy(first[i], randi_range(enemy_rows.x, enemy_rows.y))


## Le placement automatique des héros : la première ligne, et les tireurs derrière (lignes « hero_rows »).
func _place_heroes() -> void:
	var front: Array[Dictionary] = []
	var back: Array[Dictionary] = []
	for hero in heroes:
		(back if hero["ranged"] else front).append(hero)
	var rows: Array = map_data.get("hero_rows", [MapGenerator.HERO_FRONT_ROW, MapGenerator.HERO_BACK_ROW])
	_place_row(front, rows[0])
	_place_row(back, rows[1])
	for hero in heroes:
		hero["post"] = hero["pos"]


# --- Placement par le Maître (prompt 3, point 2) ---
# Avant de commencer (le combat est démarré par start() mais aucun pas n'a été joué), le Maître peut déplacer ses
# héros dans la zone de départ. Un héros placé par le Maître tient ce poste (comme arrivé là sur son ordre, voir
# _follow_order) et le Meneur ne le déplace pas (_organize_defense). Rien n'est tiré au hasard : sans placement,
# le combat reste identique.

## Les cases de la zone de départ des héros : les lignes « hero_rows » et celles entre elles.
func start_zone() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var rows: Array = map_data.get("hero_rows", [MapGenerator.HERO_FRONT_ROW, MapGenerator.HERO_BACK_ROW])
	for row in range(mini(rows[0], rows[1]), maxi(rows[0], rows[1]) + 1):
		for x in GRID_W:
			if map.walkable(Vector2i(x, row)):
				cells.append(Vector2i(x, row))
	return cells


## Le Maître pose un héros sur une case de la zone de départ (avant le premier pas). S'il y a déjà un héros, ils
## échangent leur place. Renvoie faux si c'est impossible (hors de la zone, combat commencé).
func place_hero(hero: Dictionary, cell: Vector2i) -> bool:
	if time > 0.0 or not hero["is_hero"] or not cell in start_zone():
		return false
	var other: Dictionary = {}
	for unit in units:
		if unit["present"] and unit["id"] != hero["id"] and _cell_of(unit["pos"]) == cell:
			other = unit
	if not other.is_empty() and not other["is_hero"]:
		return false
	if not other.is_empty():
		_set_start(other, hero["pos"])
	_set_start(hero, BattleMap.center(cell))
	return true


func _set_start(hero: Dictionary, pos: Vector2) -> void:
	hero["pos"] = pos
	hero["prev_pos"] = pos
	hero["post"] = pos
	hero["placed"] = true  # placé par le Maître : il tient ce poste, le Meneur ne le déplace pas
	hero["held"] = tactical_ai
	_settle(hero)


## « Placement automatique » : les héros reprennent leur place de départ habituelle.
func auto_place() -> void:
	if time > 0.0:
		return
	for hero in heroes:
		hero["present"] = false
		hero["placed"] = false
		hero["held"] = false
	_place_heroes()


## Aligne des combattants sur une ligne, centrés, sur des cases libres.
func _place_row(fighters: Array[Dictionary], row: int) -> void:
	for i in fighters.size():
		var x := GRID_W / 2 + (i - fighters.size() / 2) * 2
		fighters[i]["pos"] = _free_cell_near(Vector2i(clampi(x, 0, GRID_W - 1), row))
		fighters[i]["prev_pos"] = fighters[i]["pos"]
		fighters[i]["present"] = true
		_settle(fighters[i])


## Fait entrer un ennemi sur le terrain, sur une case libre de la ligne donnée : à la colonne « column », sinon
## à sa colonne d'entrée fixée par l'étage (« entry », voir MapGenerator.generate), sinon au hasard.
func _spawn_enemy(enemy: Dictionary, row: int, column := -1) -> void:
	if column < 0:
		column = enemy["source"].get("entry", -1)
	if column < 0:
		column = randi_range(1, GRID_W - 2)
	enemy["pos"] = _free_cell_near(Vector2i(column, row))
	enemy["prev_pos"] = enemy["pos"]
	enemy["present"] = true
	_settle(enemy)


## Note la case et la hauteur où se tient un combattant (à son arrivée sur le terrain).
func _settle(unit: Dictionary) -> void:
	unit["cell"] = _cell_of(unit["pos"])
	unit["z"] = map.height_at(unit["cell"])


## La case libre la plus proche d'une case donnée (son centre).
func _free_cell_near(cell: Vector2i) -> Vector2:
	for radius in range(0, 6):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				var c := cell + Vector2i(dx, dy)
				if map.walkable(c) and not _occupied(c):
					return Vector2(c) + Vector2(0.5, 0.5)
	return Vector2(map.nearest_walkable(cell)) + Vector2(0.5, 0.5)


func _occupied(cell: Vector2i) -> bool:
	for unit in units:
		if unit["present"] and Vector2i(unit["pos"]) == cell:
			return true
	return false


func _cell_of(pos: Vector2) -> Vector2i:
	return map.cell_of(pos)


func _is_blocked(pos: Vector2) -> bool:
	return not map.walkable(Vector2i(floori(pos.x), floori(pos.y)))


## Hauteur où se tient un combattant (niveau de sa case).
func height_of(unit: Dictionary) -> int:
	return unit.get("z", 0)


## Peut-il glisser de « from » à « to » (une bousculade, un pas en arrière) ? Dans la même case, ou vers une
## case voisine à la même hauteur, par un escalier, ou (« drop » vrai) en sautant d'un niveau.
func _can_shift(from: Vector2, to: Vector2, drop := false) -> bool:
	var a := _cell_of(from)
	var b := Vector2i(floori(to.x), floori(to.y))
	if a == b:
		return map.walkable(b)
	if not map.in_bounds(b) or absi(a.x - b.x) > 1 or absi(a.y - b.y) > 1:
		return false
	var passage := map.step_link(a, b)
	return passage == BattleMap.Link.WALK or passage == BattleMap.Link.STAIRS or (drop and passage == BattleMap.Link.DROP)


## Vrai si « unit » voit « target » : ligne de vue en 3D, de ses yeux au corps de la cible (voir BattleMap).
func _sees(unit: Dictionary, target: Dictionary) -> bool:
	return map.line_of_sight(unit["pos"], height_of(unit), target["pos"], height_of(target))


## Couvert (cahier, « Combat v2 », section 2) : la cible est-elle derrière un muret, une clôture ou un rocher
## plus haut qu'elle, du côté du tireur ? Un tireur bien plus haut que le couvert (COVER_IGNORE_LEVELS) tire
## par-dessus.
func _covered(target: Dictionary, shooter: Dictionary) -> bool:
	var cell := _cell_of(target["pos"])
	var toward: Vector2 = shooter["pos"] - target["pos"]
	for d in BattleMap.DIRECTIONS:
		var c: Vector2i = cell + d
		var kind := map.kind_at(c)
		if not kind in [BattleMap.Kind.LOW_WALL, BattleMap.Kind.ROCK, BattleMap.Kind.BLOCK] or not map.in_bounds(c):
			continue
		var top := maxi(map.height_at(c), 1)
		if top <= height_of(target) or height_of(shooter) >= top + GameData.COVER_IGNORE_LEVELS:
			continue
		if Vector2(d).normalized().dot(toward.normalized()) > 0.7:
			return true
	return false


# ---------------------------------------------------------------------------
# Un pas de temps
# ---------------------------------------------------------------------------

func _step() -> void:
	_update_crowd()
	if perception_on:
		perception.tick()
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

	# Protecteur : un allié proche en danger passe avant l'ennemi ; il va se placer à son côté.
	if unit["is_hero"] and not quest.get("duel", false) and GameData.has_trait(unit["source"], "Protecteur"):
		var ward := _ward_of(unit)
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


## Perception (C3) : il ne connaît aucun ennemi. Un héros tient son poste (il attend de voir venir) ; un
## monstre avance vers le camp des héros (la horde sait où ils sont, pas qui viser : il ne frappe pas avant de voir).
func _unaware(unit: Dictionary, foes: Array) -> void:
	unit["target_id"] = -1
	if unit["is_hero"]:
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


## Portée d'un combattant, pour les formations (voir GameData, tower.gd, RANGE_COVER_BONUS) :
## "longue" (arc, magie), "moyenne" (lance, fouet) ou "courte" (épée, dague, sans arme).
func range_band(unit: Dictionary) -> String:
	if unit["ranged"] or unit["class"] in ["Mage", "Soigneur"]:
		return "longue"
	if unit["weapon"] in GameData.WEAPON_TYPES:
		return GameData.WEAPON_TYPES[unit["weapon"]]["band"]
	return "courte"


# ---------------------------------------------------------------------------
# Journal de combat (personnalité P1b ; document de référence, section 3 bis)
# ---------------------------------------------------------------------------
# Pour chaque héros, un journal compact : premiers contacts, blessures graves, agonie, secours, mort,
# ennemis achevés, formations utilisées ; et des compteurs (coups portés, reçus, esquives). Il est gardé sur
# le héros pour ses derniers combats (GameData.finish_tower_battle, hero["recent_battles"]) : c'est la
# matière de la bibliothèque et du mémorial. Il n'influence rien (aucun tirage au hasard).

## Formations utilisées pendant le combat (noms), dans l'ordre.
var formations_used: Array = []
## Un héros a déjà porté le premier coup du combat (P2g : il peut éveiller Premier sang).
var _first_blood_given := false
## Événements gardés au plus par héros (les compteurs, eux, comptent tout).
const JOURNAL_MAX := 60


func _journal(unit: Dictionary, kind: String, data := {}) -> void:
	if not unit["is_hero"] or unit["journal"].size() >= JOURNAL_MAX:
		return
	var event := {"t": snappedf(time, 0.1), "kind": kind}
	event.merge(data)
	unit["journal"].append(event)


## Un coup (ou une esquive) : compteurs, premier contact avec cet ennemi, blessure grave.
func _journal_hit(attacker: Dictionary, target: Dictionary, amount: int, critical: bool) -> void:
	for pair in [[attacker, target], [target, attacker]]:
		var hero: Dictionary = pair[0]
		var foe: Dictionary = pair[1]
		if hero["is_hero"] and not foe["is_hero"] and not hero["met"].has(foe["id"]):
			hero["met"][foe["id"]] = true
			_journal(hero, "contact", {"with": foe["base_name"]})
			_foe_count(hero, foe["base_name"], "")
	# Par sorte d'ennemi : coups portés et esquives (ce que le héros en apprend, voir GameData.learn_from_battle).
	if attacker["is_hero"] and not target["is_hero"] and amount >= 0:
		_foe_count(attacker, target["base_name"], "hits")
	if target["is_hero"] and not attacker["is_hero"] and amount < 0:
		_foe_count(target, attacker["base_name"], "dodges")
	if attacker["is_hero"] and amount >= 0:
		attacker["journal_counts"]["hits_given"] += 1
	if target["is_hero"]:
		if amount < 0:
			target["journal_counts"]["dodges"] += 1
		else:
			target["journal_counts"]["hits_taken"] += 1
			if critical or amount >= target["max_hp"] * BLEED_HIT:
				_journal(target, "wound", {"by": attacker["base_name"], "amount": amount})


## Compte un coup porté (« hits ») ou une esquive (« dodges ») d'un héros contre une sorte d'ennemi ; « » : la
## rencontre seulement. fighter["foes"] = {nom de base: {"hits", "dodges"}}.
func _foe_count(hero: Dictionary, base_name: String, what: String) -> void:
	if not hero["foes"].has(base_name):
		hero["foes"][base_name] = {"hits": 0, "dodges": 0}
	if what != "":
		hero["foes"][base_name][what] += 1


## Une formation entre en jeu : notée pour le combat et dans le journal des héros debout.
func _journal_formation(formation: String) -> void:
	if formation in formations_used:
		return
	formations_used.append(formation)
	for hero in _alive(heroes):
		_journal(hero, "formation", {"name": formation})


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


## Assez près (et, pour un tir, sans décor entre les deux) ?
func _in_reach(unit: Dictionary, target: Dictionary, reach: float) -> bool:
	var distance: float = unit["pos"].distance_to(target["pos"])
	var above := height_of(unit) - height_of(target)
	if reach <= MELEE_REACH_MAX:
		# Au corps à corps, on ne frappe pas plus d'un niveau au-dessus ou en dessous (il faut monter, ou descendre).
		if absi(above) > GameData.MELEE_MAX_LEVELS:
			return false
		if unit["weapon"] == "Lance" and _behind_shield(unit, target):
			reach += GameData.SPEAR_WALL_REACH  # par-dessus le mur de boucliers
		return distance <= reach + 0.05
	# Un tireur au-dessus de sa cible voit et tire plus loin (par niveau, HEIGHT_MAX_LEVELS au plus).
	reach += clampi(above, 0, GameData.HEIGHT_MAX_LEVELS) * GameData.HEIGHT_REACH_PER_LEVEL
	if distance > reach + 0.05:
		return false
	return _sees(unit, target)


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
	unit["stamina"] = maxf(minf(unit["stamina_floor"], unit["stamina"]), unit["stamina"] - amount * unit["stamina_cost"])
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
	var rate: float = unit["stamina_regen"]
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


## Avance vers un point en suivant un chemin sur la grille 3D (voir BattleMap.find_path) : il contourne le
## décor, prend les escaliers et les échelles, et va moins vite en montant (voir _passage_speed). Le chemin
## est recalculé toutes les PATH_REFRESH secondes, ou tout de suite si le but change de case.
func _move_towards(unit: Dictionary, goal: Vector2) -> void:
	unit["path_timer"] -= TICK
	var goal_cell := _cell_of(goal)
	if unit["path"].is_empty() or unit["path_timer"] <= 0 or unit["path_goal"] != goal_cell:
		unit["path_timer"] = PATH_REFRESH
		unit["path_goal"] = goal_cell
		var path := map.find_path(_cell_of(unit["pos"]), goal_cell, _side(unit))
		if not map.walkable(goal_cell):
			pass  # (on va au plus près)
		elif path.is_empty():
			if _cell_of(unit["pos"]) == goal_cell:
				path.append(goal)  # déjà dans la bonne case : droit au but
		elif _cell_of(path[path.size() - 1]) == goal_cell:
			path[path.size() - 1] = goal
		unit["path"] = path
	_walk_path(unit)


## Le camp d'un combattant pour la recherche de chemin (voir BattleMap.SIDE_HEROES).
func _side(unit: Dictionary) -> int:
	return BattleMap.SIDE_HEROES if unit["is_hero"] else BattleMap.SIDE_ENEMIES


## Avance le long de unit["path"] pendant ce pas. Chaque passage d'une case à l'autre se fait à la vitesse
## qui va avec (marche, escalier, échelle, escalade). Évitement local (cahier, section 3) : si quelqu'un
## d'immobile occupe la case suivante, il le contourne par une case voisine libre ; s'il ne peut pas, il
## attend, et au bout de REPATH_BLOCKED secondes il cherche un autre chemin (voir _blocked). Un passage
## impossible (il a été bousculé hors de son chemin) : il cherchera un nouveau chemin au prochain pas.
func _walk_path(unit: Dictionary) -> void:
	var budget := _move_speed(unit) * TICK
	var start: Vector2 = unit["pos"]
	var path: PackedVector2Array = unit["path"]
	var detours := 0
	while budget > 0.0001 and not path.is_empty():
		var next: Vector2 = path[0]
		var here := _cell_of(unit["pos"])
		var there := _cell_of(next)
		var factor := 1.0
		if here != there:
			if absi(here.x - there.x) > 1 or absi(here.y - there.y) > 1 or map.step_link(here, there) == BattleMap.Link.NONE:
				path = PackedVector2Array()
				unit["path_timer"] = 0.0
				break
			if _stands_in(there, unit) and there != unit["path_goal"]:
				var around := _sidestep(unit, here, there, path[1] if path.size() > 1 else next)
				if around == Vector2i(-1, -1) or detours > 0:
					unit["path"] = path
					_blocked(unit, there)
					return
				detours += 1
				path.insert(0, BattleMap.center(around))
				continue
			factor = _passage_speed(unit, map.step_link(here, there))
		var reach := budget * factor
		var distance: float = unit["pos"].distance_to(next)
		if distance <= reach:
			unit["pos"] = next
			path.remove_at(0)
			budget -= distance / factor
		else:
			unit["pos"] += (next - unit["pos"]).normalized() * reach
			budget = 0.0
	unit["path"] = path
	unit["blocked"] = 0.0
	_spend_stamina(unit, start.distance_to(unit["pos"]) * GameData.STAMINA_MOVE_COST)


## Quelqu'un d'autre se tient-il immobile dans cette case ?
func _stands_in(cell: Vector2i, unit: Dictionary) -> bool:
	var i := map.index(cell)
	return _still_at.has(i) and _still_at[i] != unit["id"]


## Contourner : une case voisine libre (où personne ne se tient), où l'on passe sans monter (à plat, escalier,
## saut d'un niveau), et qui rapproche de « toward ». Vector2i(-1, -1) s'il n'y en a pas.
func _sidestep(unit: Dictionary, here: Vector2i, blocked: Vector2i, toward: Vector2) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_distance: float = unit["pos"].distance_to(toward) - 0.05
	for d in BattleMap.DIRECTIONS:
		var cell: Vector2i = here + d
		if cell == blocked or not map.in_bounds(cell) or _taken.has(map.index(cell)):
			continue
		var passage := map.step_link(here, cell)
		if not passage in [BattleMap.Link.WALK, BattleMap.Link.STAIRS, BattleMap.Link.DROP]:
			continue
		var distance := BattleMap.center(cell).distance_to(toward)
		if distance < best_distance:
			best = cell
			best_distance = distance
	return best


## Bloqué devant « cell » (quelqu'un d'immobile, et pas de case pour le contourner) : il attend. Au bout de
## REPATH_BLOCKED secondes, il cherche un chemin qui évite ce passage ; un monstre quitte alors le flux de
## la horde pendant DETOUR_SECONDS (cahier : « si une ruelle est bouchée, la horde essaie une autre ruelle »).
func _blocked(unit: Dictionary, cell: Vector2i) -> void:
	unit["blocked"] += TICK
	if unit["blocked"] < REPATH_BLOCKED:
		return
	unit["blocked"] = 0.0
	var goal: Vector2i = unit["path_goal"]
	if goal == Vector2i(-1, -1):
		return
	var side := _side(unit)
	var i := map.index(cell)
	var cost: float = map.costs[side][i]
	map.set_cost(cell, cost + BLOCKED_PATH_COST, side)
	unit["path"] = map.find_path(_cell_of(unit["pos"]), goal, side)
	map.set_cost(cell, cost, side)
	unit["path_timer"] = PATH_REFRESH * 2
	if not unit["is_hero"]:
		unit["detour_until"] = time + DETOUR_SECONDS


## Aller attaquer « target » : au corps à corps, vers une case d'attaque libre autour d'elle (réservée, voir
## _attack_slot), puis droit sur elle ; un monstre loin de son but suit le champ de flux de la horde
## (_follow_flow), sauf s'il fait un détour.
func _approach(unit: Dictionary, target: Dictionary) -> void:
	var goal: Vector2 = target["pos"]
	if not unit["ranged"]:
		var slot := _attack_slot(unit, target)
		if slot >= 0 and _cell_of(unit["pos"]) != map.cell_at(slot):
			goal = BattleMap.center(map.cell_at(slot))
	if not unit["is_hero"] and not quest.get("duel", false) and time >= unit["detour_until"] and not _near(unit, target):
		_follow_flow(unit, target)
	elif unit["detour_until"] > time and not unit["path"].is_empty() and _cell_of(unit["path"][unit["path"].size() - 1]) == _cell_of(goal):
		unit["path_timer"] -= TICK
		_walk_path(unit)  # (détour en cours : il garde le chemin qui évite le passage bouché)
	else:
		_move_towards(unit, goal)


## Réservation des cases (cahier, section 3) : une case de corps à corps autour de la cible est « prise » par
## un seul attaquant ; les suivants en cherchent une autre, ce qui crée de vrais encerclements. On garde sa
## case tant qu'elle convient ; sinon la plus proche des cases libres (au plus un niveau d'écart avec la
## cible, personne d'autre immobile dessus). Renvoie son indice, ou -1 s'il n'y en a plus (il s'approche
## quand même).
func _attack_slot(unit: Dictionary, target: Dictionary) -> int:
	var center := _cell_of(target["pos"])
	var current: int = unit["slot"]
	if current >= 0 and _slot_free(current, unit, target, center):
		_slots[current] = unit["id"]
		unit["slot_seen"] = time
		return current
	if current >= 0 and _slots.get(current, -1) == unit["id"]:
		_slots.erase(current)
	var best := -1
	var best_distance := INF
	for d in BattleMap.DIRECTIONS:
		var cell: Vector2i = center + d
		if not map.in_bounds(cell):
			continue
		var i := map.index(cell)
		if not _slot_free(i, unit, target, center):
			continue
		var distance: float = unit["pos"].distance_to(BattleMap.center(cell)) + (0.3 if d.x != 0 and d.y != 0 else 0.0)
		if distance < best_distance:
			best = i
			best_distance = distance
	unit["slot"] = best
	if best >= 0:
		_slots[best] = unit["id"]
		unit["slot_seen"] = time
	return best


func _slot_free(i: int, unit: Dictionary, target: Dictionary, center: Vector2i) -> bool:
	var cell := map.cell_at(i)
	if absi(cell.x - center.x) > 1 or absi(cell.y - center.y) > 1 or cell == center or not map.walkable(cell):
		return false
	if absi(map.height_at(cell) - height_of(target)) > GameData.MELEE_MAX_LEVELS:
		return false
	if _slots.get(i, unit["id"]) != unit["id"]:
		return false
	return not _still_at.has(i) or _still_at[i] == unit["id"] or _still_at[i] == target["id"]


## Le champ de flux d'une cible (partagé par toute la horde) : recalculé au plus toutes les FLOW_REFRESH
## secondes si la cible a changé de case, et toutes les FLOW_MAX_AGE secondes (la foule bouge).
func _flow_for(target: Dictionary) -> Dictionary:
	var goal := _cell_of(target["pos"])
	var flow: Dictionary = _flows.get(target["id"], {})
	if flow.is_empty() or (time - flow["time"] >= FLOW_REFRESH and flow["cell"] != goal) or time - flow["time"] >= FLOW_MAX_AGE:
		flow = {"cell": goal, "time": time, "dist": map.flow_field([goal], BattleMap.SIDE_ENEMIES)}
		_flows[target["id"]] = flow
	return flow


## Le monstre est-il assez près de sa cible pour prendre son propre chemin (vers sa case d'attaque) ? Près
## en marchant (distance lue dans le champ de flux, pas à vol d'oiseau : sinon, de part et d'autre d'un
## obstacle, il hésiterait sans fin entre le flux, qui contourne d'un côté, et son chemin, qui contourne de
## l'autre) ; une fois près, il le reste jusqu'à NEAR_MARGIN de plus.
func _near(unit: Dictionary, target: Dictionary) -> bool:
	var dist: float = _flow_for(target)["dist"][map.index(map.nearest_walkable(_cell_of(unit["pos"])))]
	unit["near"] = dist <= FLOW_NEAR + (NEAR_MARGIN if unit["near"] else 0.0)
	return unit["near"]


## Champ de flux (cahier, section 3) : au lieu d'un chemin par monstre, une carte des distances vers chaque
## cible, calculée pour toute la horde (BattleMap.flow_field), que chaque monstre descend case par case en
## contournant ceux qui se tiennent immobiles. Recalculée au plus toutes les FLOW_REFRESH secondes si la
## cible a changé de case, et toutes les FLOW_MAX_AGE secondes (la foule bouge).
func _follow_flow(unit: Dictionary, target: Dictionary) -> void:
	unit["path_timer"] -= TICK
	var goal := _cell_of(target["pos"])
	var flow := _flow_for(target)
	var here := _cell_of(unit["pos"])
	var avoid := {}
	for i in _still_at:
		if _still_at[i] != unit["id"] and _still_at[i] != target["id"]:
			avoid[i] = true
	unit["path_goal"] = goal
	var next := map.flow_step(flow["dist"], here, BattleMap.SIDE_ENEMIES, avoid)
	if next == Vector2i(-1, -1):
		var ahead := map.flow_step(flow["dist"], here, BattleMap.SIDE_ENEMIES)
		if ahead == Vector2i(-1, -1):
			_move_towards(unit, target["pos"])  # (le flux ne mène nulle part d'ici : chemin à lui)
		else:
			unit["path"] = PackedVector2Array([BattleMap.center(ahead)])
			_blocked(unit, ahead)
		return
	unit["path"] = PackedVector2Array([BattleMap.center(next)])
	_walk_path(unit)


## Au début de chaque pas : qui se tient où (cases prises, cases où quelqu'un est immobile), et les cases
## d'attaque encore réservées (celles dont l'attaquant s'est servi au pas précédent).
func _update_crowd() -> void:
	_still_at.clear()
	_taken.clear()
	for unit in units:
		if not unit["present"] or unit["hp"] <= 0:
			continue
		var i := map.index(_cell_of(unit["pos"]))
		_taken[i] = true
		if unit["still"]:
			_still_at[i] = unit["id"]
	for i in _slots.keys():
		var holder: Dictionary = units[_slots[i]]
		if holder["hp"] <= 0 or not holder["present"] or holder["slot"] != i or time - holder["slot_seen"] > TICK * 1.5:
			_slots.erase(i)
			if holder["slot"] == i:
				holder["slot"] = -1


## Coûts des cases pour la recherche de chemin, toutes les PATH_REFRESH secondes (cahier, section 3 : « coût
## selon la pente, les échelles, la foule et le danger ») : terrain (BattleMap.TERRAIN_COSTS), foule (quelqu'un
## d'immobile ou qui passe), et, pour les héros, les cases à portée d'un tireur ennemi.
func _refresh_costs() -> void:
	if time < _costs_due:
		return
	_costs_due = time + PATH_REFRESH
	var crowd := PackedFloat32Array()
	crowd.resize(map.heights.size())
	crowd.fill(0.0)
	for unit in units:
		if unit["present"] and unit["hp"] > 0:
			crowd[map.index(_cell_of(unit["pos"]))] += CROWD_STILL_COST if unit["still"] else CROWD_MOVING_COST
	var danger := PackedFloat32Array()
	danger.resize(map.heights.size())
	danger.fill(0.0)
	for shooter in enemies:
		if not shooter["present"] or shooter["hp"] <= 0 or not shooter["ranged"]:
			continue
		var reach: float = shooter["reach"]
		var c := _cell_of(shooter["pos"])
		var r := ceili(reach)
		for x in range(maxi(0, c.x - r), mini(GRID_W, c.x + r + 1)):
			for y in range(maxi(0, c.y - r), mini(GRID_H, c.y + r + 1)):
				if BattleMap.center(Vector2i(x, y)).distance_to(shooter["pos"]) <= reach:
					var i := map.index(Vector2i(x, y))
					danger[i] = minf(DANGER_MAX_COST, danger[i] + DANGER_COST)
	for i in map.heights.size():
		var cell := map.cell_at(i)
		var base: float = map.base_costs[i]
		map.set_cost(cell, base + crowd[i] + danger[i], BattleMap.SIDE_HEROES)
		map.set_cost(cell, base + crowd[i], BattleMap.SIDE_ENEMIES)


## Vitesse d'un passage d'une case à l'autre (part de sa vitesse de marche ; voir GameData, tower.gd,
## « Verticalité ») : escalier, échelle, escalade d'un niveau (plus vite avec de la Dextérité).
func _passage_speed(unit: Dictionary, passage: int) -> float:
	match passage:
		BattleMap.Link.STAIRS:
			return GameData.STAIRS_SPEED
		BattleMap.Link.LADDER:
			return GameData.LADDER_SPEED
		BattleMap.Link.CLIMB:
			var skill: float = 1.0 + (unit["spd"] - 10) * GameData.CLIMB_DEX_BONUS
			if unit["is_hero"]:
				skill *= PersonalityEngine.modifier("climb", unit["source"])  # l'Audace (neutre pour l'instant)
			return GameData.CLIMB_SPEED * clampf(skill, GameData.CLIMB_SKILL_MIN, GameData.CLIMB_SKILL_MAX)
	return 1.0


## Recule d'un pas, à l'opposé d'une menace, si la place est libre (il peut sauter d'un niveau, pas plus).
func _step_away(unit: Dictionary, threat: Vector2) -> void:
	var direction: Vector2 = (unit["pos"] - threat).normalized()
	var next: Vector2 = unit["pos"] + direction * _move_speed(unit) * TICK
	if _can_shift(unit["pos"], next, true):
		_spend_stamina(unit, _move_speed(unit) * TICK * GameData.STAMINA_MOVE_COST)
		unit["pos"] = next
		unit["path"] = PackedVector2Array()


## Les combattants trop proches (à la même hauteur) se poussent un peu, sans entrer dans le décor ni changer
## de niveau (une bousculade ne fait pas tomber d'un toit : seul un coup puissant le fait, voir _push).
func _separate() -> void:
	var present := _alive(units)
	for i in present.size():
		for j in range(i + 1, present.size()):
			var a: Dictionary = present[i]
			var b: Dictionary = present[j]
			if height_of(a) != height_of(b):
				continue
			var offset: Vector2 = b["pos"] - a["pos"]
			var distance := offset.length()
			if distance >= PERSONAL_SPACE:
				continue
			if distance < 0.01:
				offset = Vector2(randf_range(-1, 1), randf_range(-1, 1))
			var push := offset.normalized() * (PERSONAL_SPACE - distance) * 0.5
			if _can_shift(a["pos"], a["pos"] - push):
				a["pos"] -= push
			if _can_shift(b["pos"], b["pos"] + push):
				b["pos"] += push


## Après les déplacements du pas : chacun prend la hauteur de sa case. Qui descend de deux niveaux ou plus
## sans échelle (un saut, une chute) se blesse (voir GameData.fall_damage).
func _land() -> void:
	for unit in units:
		if not unit["present"] or unit["hp"] <= 0:
			continue
		unit["still"] = unit["pos"].distance_to(unit["prev_pos"]) < 0.02  # (immobile : voir _update_crowd)
		var cell := _cell_of(unit["pos"])
		if cell == unit["cell"]:
			continue
		var levels: int = unit["z"] - map.height_at(cell)
		var by_ladder := map.kind_at(cell) == BattleMap.Kind.LADDER or map.kind_at(unit["cell"]) == BattleMap.Kind.LADDER
		unit["cell"] = cell
		unit["z"] = map.height_at(cell)
		if levels >= 2 and not by_ladder:
			_fall(unit, levels)


## Une chute (ou un saut) de « levels » niveaux : dégâts, et peut-être la mise à terre.
func _fall(unit: Dictionary, levels: int) -> void:
	var amount := roundi(unit["max_hp"] * GameData.fall_damage(levels))
	if amount <= 0:
		return
	amount = _hold_on(unit, mini(amount, unit["hp"]))  # rage d'éveil : il refuse de mourir
	unit["hp"] -= amount
	_effect("bleed", unit, unit, "-%d" % amount, levels >= 3)
	_log("%s tombe de %d niveaux (-%d)." % [_name_with_stars(unit), levels, amount], "bleed" if levels >= 3 else "")
	if unit["hp"] <= 0:
		_announce_fall(unit, "tombé de %d niveaux" % levels)
	else:
		_check_critical_state(unit)


## Un coup puissant au contact près d'un bord peut faire tomber la cible (cahier : « pousser ») : la case
## derrière elle, dans le sens du coup, est plus basse. Jamais un boss.
func _push(attacker: Dictionary, target: Dictionary, amount: int, critical: bool) -> void:
	if target["boss"] or target["hp"] <= 0 or not target["present"] or (not critical and amount < target["max_hp"] * GameData.PUSH_MIN_HIT):
		return
	var direction: Vector2 = (target["pos"] - attacker["pos"]).normalized()
	var behind := Vector2i((target["pos"] + direction).floor())
	var cell := _cell_of(target["pos"])
	if behind == cell or not map.walkable(behind) or absi(behind.x - cell.x) > 1 or absi(behind.y - cell.y) > 1 \
			or map.height_at(behind) >= height_of(target):
		return
	if randf() >= GameData.PUSH_CHANCE:
		return
	target["pos"] = BattleMap.center(behind)
	target["path"] = PackedVector2Array()
	_log("%s est poussé dans le vide par %s !" % [_name_with_stars(target), attacker["name"]], "bleed")


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
		unit["weapon_skill"] = ""
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
	var amount := _damage(attacker, target, power, critical, kind, surprise)
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
	var text := "esquive !" if amount == -1 else ("couvert !" if amount < 0 else "-%d" % amount)
	if surprise and amount >= 0:
		text = "surprise ! " + text
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
	# Sort de feu : Résistance aux flammes de la cible (80 % au plus).
	if kind == "spell" and attacker["element"] == "Feu":
		raw *= 1.0 - minf(0.8, GameData.skill_level(target["skills"], "Résistance aux flammes") * GameData.FIRE_RESIST_PER_LEVEL)
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


## Sauvé de l'agonie (« by » : l'allié ou la potion) : il sort du combat avec AGONY_STABILIZED_HP de sa vie.
func _stabilize(fighter: Dictionary, by: String) -> void:
	fighter["agony"] = false
	fighter["stabilized"] = true
	fighter["present"] = false  # mis à l'abri : il ne combat plus
	fighter["hp"] = maxi(1, roundi(fighter["max_hp"] * GameData.AGONY_STABILIZED_HP))
	var text := "%s est stabilisé grâce à %s." % [_name_with_stars(fighter), by]
	_journal(fighter, "rescued", {"by": by})
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
		fighter["flee_to"] = _free_cell_near(Vector2i(_cell_of(fighter["pos"]).x, GRID_H - 2))


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
	var share := _hold_on(guardian, mini(roundi(amount * GameData.PROTECT_SHARE), guardian["hp"]))
	if share <= 0:
		return amount
	guardian["hp"] -= share
	guardian["engaged"] = true
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
