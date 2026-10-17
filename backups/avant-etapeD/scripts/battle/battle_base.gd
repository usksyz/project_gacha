class_name BattleBase
extends RefCounted
## Combat (voir battle.gd) : les données de base (constantes, état du combat), le champ de bataille (carte, cases, placement) et les petits outils. Bas de la pile de Battle (prompt 5, point 3) : chaque fichier « extends » le précédent ; battle.gd est en haut. Les fonctions définies plus haut dans la pile mais appelées plus bas sont déclarées ici, vides, et remplacées plus haut (comme save_game dans GameData).
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


# ---------------------------------------------------------------------------
# Fonctions définies plus haut dans la pile (appelées plus bas) : déclarées vides ici, remplacées plus haut
# ---------------------------------------------------------------------------
# Comme save_game dans GameData : Battle (le haut de la pile) a la vraie fonction, qui est celle appelée.


## (vraie fonction : battle_mind.gd)
func panicking(unit: Dictionary) -> bool:
	return false


## (vraie fonction : battle_mind.gd)
func afraid(unit: Dictionary) -> bool:
	return false


## (vraie fonction : battle.gd)
func can_swap(hero: Dictionary) -> bool:
	return false


## (vraie fonction : battle_mind.gd)
func _reveal(fighter: Dictionary, trait_name: String) -> bool:
	return false


## (vraie fonction : battle.gd)
func range_band(unit: Dictionary) -> String:
	return ""


## (vraie fonction : battle_berserk.gd)
func _hold_on(unit: Dictionary, amount: int) -> int:
	return 0


## (vraie fonction : battle_care.gd)
func _announce_fall(fighter: Dictionary, cause: String, instant := false, blow := {}) -> void:
	pass


## (vraie fonction : battle_mind.gd)
func _stress_wound(fighter: Dictionary, amount: int) -> void:
	pass


## (vraie fonction : battle_mind.gd)
func _fear(unit: Dictionary) -> float:
	return 0.0


## (vraie fonction : battle_berserk.gd)
func _check_critical_state(fighter: Dictionary) -> void:
	pass


## (vraie fonction : battle_berserk.gd)
func _awaken(fighter: Dictionary, ratio: float) -> void:
	pass


## (vraie fonction : battle.gd)
func _try_attack(attacker: Dictionary, target: Dictionary, foes: Array) -> void:
	pass


## (vraie fonction : battle.gd)
func _duel_yields(unit: Dictionary) -> bool:
	return false
