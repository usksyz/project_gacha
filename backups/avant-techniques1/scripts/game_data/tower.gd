class_name GameTower
extends GameSynthesis
## La Tour : étages, quêtes, ennemis et boss, valeurs de combat, début et fin d'un combat
## (récompenses, morts, expérience, exploits).
## Fait partie de la pile de GameData (voir game_data.gd).


# ---------------------------------------------------------------------------
# La Tour
# ---------------------------------------------------------------------------
# (TEAM_SIZE et TEAM_COUNT sont avec les équipes, dans heroes.gd ; DAILY_UNLOCK_FLOOR avec le
# donjon journalier, dans lobby.gd.)

## Un boss garde tous les étages multiples de ce nombre (5, 10, 15...).
const BOSS_EVERY := 5

## Un étage déjà conquis peut être rejoué (pour entraîner une nouvelle équipe ou l'équipe principale) :
## les récompenses sont réduites (0.5 = moitié) et il n'y a pas de gemmes.
const REPLAY_XP_RATE := 0.5
const REPLAY_GOLD_RATE := 0.2

## Types de quêtes d'étage : nom affiché et objectif.
## Extermination, subjugation, annihilation : tuer tous les ennemis (l'annihilation ajoute des renforts).
## Survie et défense : tenir jusqu'à la fin du compte à rebours, face à une horde.
const QUEST_TYPES := {
	"extermination": {"name": "Extermination", "objective": "Éliminer tous les ennemis."},
	"subjugation": {"name": "Subjugation", "objective": "Éliminer tous les ennemis."},
	"annihilation": {"name": "Annihilation", "objective": "Éliminer tous les ennemis, renforts compris."},
	"survival": {"name": "Survie", "objective": "Survivre à la horde jusqu'à la fin du compte à rebours."},
	"defense": {"name": "Défense", "objective": "Empêcher la cité de tomber jusqu'à la fin du compte à rebours."},
}

## Limite de temps, en secondes de combat : pour tuer tous les ennemis, ou à tenir (survie, défense).
const KILL_QUEST_SECONDS := 90
## Défense de la cité : temps à tenir (avant la phase 1.2, la survie avait le même : 60 s).
const DEFENSE_SECONDS := 60

## Survie par vagues (feuille de route v2, phase 1.2 ; œuvre : la survie de l'étage 5, 30 minutes,
## « broyeur de héros », ch. 10 et 11). La difficulté vient de la durée et de l'usure, pas d'un seul choc :
## SURVIVAL_SECONDS à tenir (le compte à rebours démarre au premier contact), la horde arrive en
## SURVIVAL_WAVES vagues, une toutes les SURVIVAL_WAVE_SECONDS du compte à rebours. Chaque vague compte
## SURVIVAL_WAVE_MONSTERS + étage / 5 monstres ; le boss arrive avec la dernière (étage 5 : 6 vagues de 2,
## soit 12 monstres et le chef gobelin). Entre deux vagues, les héros soufflent (endurance, flèches).
## Avant : une seule horde de 8 monstres (5 après le dernier réglage), 60 s. Chiffres provisoires, réglés par
## simulation pour qu'une équipe préparée gagne l'étage 5 à 30-60 % (voir CLAUDE.md, « Tour ») : avec des
## vagues de 3 ou 4, les monstres s'accumulent plus vite qu'on ne les tue (0 à 15 % de victoires).
const SURVIVAL_SECONDS := 210
const SURVIVAL_WAVES := 6
const SURVIVAL_WAVE_SECONDS := 35.0
const SURVIVAL_WAVE_MONSTERS := 1

## Terrain des quêtes de survie (phase 1.2 ; œuvre, ch. 9 et 11) : une rangée de maisons coupe la carte,
## percée de SURVIVAL_ALLEYS ruelles larges d'une case (peu d'ennemis peuvent attaquer en même temps) ;
## côté héros, près de la sortie des ruelles, HEIGHT_COUNT hauteurs. Le Maître y envoie un héros par un ordre
## (toucher la hauteur). Chiffres provisoires.
const SURVIVAL_ALLEYS := 3
const HEIGHT_COUNT := 2

# --- Verticalité (cahier, « Combat v2 », section 2 ; étape C1) ---
# Chaque case a une hauteur de 0 à 4 niveaux (battle_map.gd). Monter : escalier ou rampe à STAIRS_SPEED de sa
# vitesse, échelle à LADDER_SPEED, escalade d'un niveau sans aide à CLIMB_SPEED (x (1 + (Dextérité - 10) x
# CLIMB_DEX_BONUS), entre CLIMB_SKILL_MIN et CLIMB_SKILL_MAX ; l'Audace passera par PersonalityEngine.modifier,
# neutre pour l'instant) ; deux niveaux sans échelle : impossible. Descendre : sauter d'un niveau sans risque ;
# de deux, FALL_DAMAGE[2] de sa vie maximum ; plus (en tombant), FALL_DAMAGE[3], puis + FALL_DAMAGE_PER_LEVEL
# par niveau en plus. Avantage de hauteur, par niveau au-dessus de l'adversaire (HEIGHT_MAX_LEVELS au plus) :
# +HEIGHT_DAMAGE_PER_LEVEL de dégâts infligés, -HEIGHT_DEFENSE_PER_LEVEL de dégâts subis, et les tireurs
# HEIGHT_REACH_PER_LEVEL case de portée en plus. Au corps à corps, on ne frappe pas plus de MELEE_MAX_LEVELS
# niveau au-dessus ou en dessous. Pousser : un coup au contact puissant (critique, ou au moins PUSH_MIN_HIT de
# la vie maximum) sur une cible au bord d'une case plus basse la fait tomber à PUSH_CHANCE (jamais un boss).
# Couvert : derrière un muret, une clôture ou un rocher plus haut que lui, un tir s'y arrête à COVER_CHANCE,
# sauf si le tireur est COVER_IGNORE_LEVELS niveaux au-dessus du couvert. Avant C1 : hauteurs de 1 niveau
# seulement, +20 % de dégâts, -25 % subis, escalade à 0,35. Chiffres provisoires.
const STAIRS_SPEED := 0.8
const LADDER_SPEED := 0.45
const CLIMB_SPEED := 0.25
const CLIMB_DEX_BONUS := 0.02
const CLIMB_SKILL_MIN := 0.6
const CLIMB_SKILL_MAX := 1.6
const FALL_DAMAGE := {2: 0.05, 3: 0.25}
const FALL_DAMAGE_PER_LEVEL := 0.1
const HEIGHT_DAMAGE_PER_LEVEL := 0.1
const HEIGHT_DEFENSE_PER_LEVEL := 0.1
const HEIGHT_MAX_LEVELS := 3
const HEIGHT_REACH_PER_LEVEL := 1.0
const MELEE_MAX_LEVELS := 1
const PUSH_MIN_HIT := 0.2
const PUSH_CHANCE := 0.35
const COVER_CHANCE := 0.35
const COVER_IGNORE_LEVELS := 2


## Part de la vie maximum perdue en tombant de « levels » niveaux (0 pour un seul niveau).
func fall_damage(levels: int) -> float:
	if levels < 2:
		return 0.0
	if levels == 2:
		return FALL_DAMAGE[2]
	return FALL_DAMAGE[3] + (levels - 3) * FALL_DAMAGE_PER_LEVEL

## Solidité des remparts d'une quête de défense : chaque coup d'un ennemi arrivé
## au pied des remparts leur retire 1 point. À 0, la cité tombe.
const DEFENSE_WALLS := 75

## Palier : tous les BOSS_EVERY étages, la difficulté monte d'un cran.
## Les ennemis de l'étage de boss et de tous les étages suivants gagnent ce nombre de niveaux en plus.
const TIER_BONUS_LEVELS := 2

## Premiers étages plus durs (demandes du porteur du projet : l'étage 1 écrème, « les forts survivent, les
## faibles meurent » ; on doit sentir la tension à chaque étage, et la préparation doit être nécessaire) :
## {étage: [monstres au moins, sortes de monstres au moins]}. Étage 1 : gobelins et loups noirs ; dès
## l'étage 2, les archers squelettes. Avant : 2 gobelins à l'étage 1. À partir de l'étage 5, la formule
## normale (déjà assez dure). Chiffres réglés par simulation (voir CLAUDE.md, « Tour »).
const EARLY_FLOOR_ENEMIES := {1: [5, 2], 2: [6, 3], 3: [6, 3], 4: [6, 3]}

## Les ennemis prennent des forces à chaque niveau (0.08 = +8 % par niveau).
const ENEMY_BONUS_PER_LEVEL := 0.08

## Monstres ordinaires de la Tour, dans l'ordre où ils apparaissent (statistiques au niveau 1).
## Leur « classe » décide de leur façon de combattre, exactement comme pour les héros.
const ENEMY_TYPES := [
	{"name": "Gobelin", "class": "Assassin", "str": 9, "int": 3, "vit": 7, "dex": 12},
	{"name": "Loup noir", "class": "Guerrier", "str": 10, "int": 2, "vit": 8, "dex": 11},
	{"name": "Squelette archer", "class": "Archer", "str": 10, "int": 3, "vit": 6, "dex": 10},
	{"name": "Golem de pierre", "class": "Chevalier", "str": 7, "int": 1, "vit": 14, "dex": 5},
	{"name": "Chaman", "class": "Soigneur", "str": 3, "int": 8, "vit": 7, "dex": 9},
	{"name": "Sorcier gobelin", "class": "Mage", "str": 3, "int": 11, "vit": 5, "dex": 8, "element": "Feu"},
]

## Boss qui gardent les étages multiples de BOSS_EVERY.
const BOSS_TYPES := [
	{"name": "Chef gobelin", "class": "Guerrier", "str": 16, "int": 4, "vit": 26, "dex": 10},
	{"name": "Minotaure", "class": "Guerrier", "str": 18, "int": 4, "vit": 30, "dex": 9},
	{"name": "Liche", "class": "Mage", "str": 4, "int": 18, "vit": 24, "dex": 10, "element": "Froid"},
	{"name": "Hydre", "class": "Chevalier", "str": 14, "int": 4, "vit": 40, "dex": 6},
]


# ---------------------------------------------------------------------------
# Combat
# ---------------------------------------------------------------------------

## Réserve de mana des mages et des soigneurs, par point d'Intelligence (la recharge et le coût
## des sorts sont dans battle.gd).
const MANA_PER_INT := 4

# --- Endurance (feuille de route v2, phase 1 ; cahier, lot A : « les novices s'épuisent parce qu'ils
# bougent trop », ch. 10) ---
# Chaque héros a une réserve d'endurance en combat (battle.gd, fighter["stamina"]). Se déplacer et frapper
# la vident ; elle remonte quand il n'est pas au contact d'un ennemi (à moins de STAMINA_CONTACT_RANGE
# cases). À 0, il est épuisé : attaque et défense x STAMINA_EXHAUSTED_FACTOR, déplacements x
# STAMINA_EXHAUSTED_SPEED, jusqu'à ce qu'elle remonte à STAMINA_RECOVERED. Un novice du combat
# (is_combat_novice) la vide STAMINA_NOVICE_FACTOR fois plus vite. Les monstres ne s'épuisent pas.
# Chiffres provisoires.
const STAMINA_MAX := 100.0
const STAMINA_MOVE_COST := 1.5        # par case parcourue
const STAMINA_ATTACK_COST := 5.0      # par coup (ou tir, sort, soin)
const STAMINA_REGEN_PER_SECOND := 8.0 # hors du contact
const STAMINA_CONTACT_RANGE := 1.8
const STAMINA_NOVICE_FACTOR := 2.0
const STAMINA_EXHAUSTED_FACTOR := 0.6 # attaque et défense -40 %
const STAMINA_EXHAUSTED_SPEED := 0.6  # déplacements ralentis
const STAMINA_RECOVERED := 30.0

# --- Rotation (cahier, lot A : survie de l'étage 5, ch. 10) ---
# L'ordre « échanger de place » (battle.gd, order_swap) envoie un héros à l'arrière (ROTATION_REAR_DISTANCE
# cases derrière lui), où il se repose : il ne combat que si un ennemi vient au contact, et son endurance
# remonte ROTATION_REST_FACTOR fois plus vite ; il revient au combat quand elle est pleine. Un allié frais
# (au moins ROTATION_FRESH_STAMINA de son endurance) prend son poste. Pendant ROTATION_VULNERABLE_SECONDS,
# les deux ne frappent pas et encaissent x ROTATION_DAMAGE_TAKEN : c'est le moment le plus dangereux.
# Trait Meneur (personality.gd) : il ordonne lui-même la rotation d'un allié au contact dont l'endurance
# passe sous LEADER_TIRED_STAMINA, au plus une fois toutes les LEADER_COOLDOWN secondes.
const ROTATION_REAR_DISTANCE := 3.0
const ROTATION_REST_FACTOR := 3.0
const ROTATION_FRESH_STAMINA := 0.5
const ROTATION_VULNERABLE_SECONDS := 1.0
const ROTATION_DAMAGE_TAKEN := 1.5
const LEADER_TIRED_STAMINA := 0.2
const LEADER_COOLDOWN := 8.0

# --- Portées et formations (phase 1.2 ; cahier, lot A ; œuvre : ch. 5, trois portées ; ch. 9, formation des
# novices) ---
# Chaque héros a une portée (Battle.range_band) : courte (épée, dague, bouclier, sans arme), moyenne (lance,
# fouet), longue (arc, magie). Une équipe dont les héros debout couvrent les trois portées gagne
# RANGE_COVER_BONUS en attaque et en défense. Mur de boucliers : un porteur de bouclier qui a un autre porteur
# de bouclier côte à côte (à moins de SHIELD_WALL_RANGE cases, sur la même ligne) gagne
# SHIELD_WALL_DEFENSE_PER_ALLY de défense par voisin (SHIELD_WALL_MAX_ALLIES au plus). Un lancier juste
# derrière un porteur de bouclier (à moins de SPEAR_WALL_RANGE cases de lui, le bouclier plus près de
# l'ennemi) frappe SPEAR_WALL_REACH case plus loin : par-dessus le mur, sans être au contact.
# Chiffres provisoires.
const RANGE_COVER_BONUS := 0.1
const SHIELD_WALL_RANGE := 1.5
const SHIELD_WALL_DEFENSE_PER_ALLY := 0.15
const SHIELD_WALL_MAX_ALLIES := 2
const SPEAR_WALL_RANGE := 1.6
const SPEAR_WALL_REACH := 0.6

# --- Usure des armes et flèches (phase 1.2 ; cahier, lot A ; œuvre : ch. 10) ---
# Usure : chaque coup porté au contact avec une arme l'émousse ; ses dégâts sont multipliés par
# 1 - coups x WEAR_PER_HIT, jamais sous WEAR_MIN_FACTOR. Le journal le dit une fois, sous WEAR_NOTICE.
# Les armes sont réparées automatiquement au retour (l'usure ne dure que le combat).
# Flèches : un héros à l'arc a un carquois de QUIVER_SIZE flèches. À court, il se bat au contact avec sa
# dague de secours (OUT_OF_ARROWS_POWER des dégâts). Quand aucun ennemi n'est à moins de ARROW_PICKUP_CALM
# cases, il ramasse ARROW_PICKUP_PER_SECOND flèches par seconde, jusqu'à ARROW_RECOVER_SHARE de celles
# qu'il a tirées. Ordre « Tir de barrage » : il tire d'un coup toutes ses flèches sur les ennemis à sa
# portée, chacune à BARRAGE_POWER de la force d'un tir, pour BARRAGE_STAMINA_COST d'endurance.
# Les monstres (archers squelettes compris) ne s'usent pas et ne manquent pas de flèches. Chiffres provisoires.
const WEAR_PER_HIT := 0.004
const WEAR_MIN_FACTOR := 0.6
const WEAR_NOTICE := 0.85
const QUIVER_SIZE := 25
const OUT_OF_ARROWS_POWER := 0.5
const ARROW_PICKUP_CALM := 4.0
const ARROW_PICKUP_PER_SECOND := 1.0
const ARROW_RECOVER_SHARE := 0.5
const BARRAGE_POWER := 0.6
const BARRAGE_STAMINA_COST := 10.0

# --- Agonie (cahier, lot A : fin du ch. 10) ---
# À 0 point de vie, un héros ne meurt pas tout de suite : il tombe à l'agonie AGONY_SECONDS secondes
# (fenêtre rouge « X est dans un état critique, sa vie est en danger ! »). L'allié libre le plus proche
# (à moins de AGONY_HELP_RANGE cases, pas au contact d'un ennemi, pas effrayé) court à son côté ; s'il y
# reste AGONY_RESCUE_SECONDS (à moins de
# AGONY_ALLY_RANGE cases), ou si l'équipe a une potion de soin, il est stabilisé : il se relève avec
# AGONY_STABILIZED_HP de sa vie et reprend le combat (étape A ; avant, il en sortait). Sinon, à la fin de ses
# AGONY_SECONDS, il meurt (mort définitive). Quand l'étage se termine, un héros encore à l'agonie est soigné, s'il
# reste un héros debout (étape A ; avant : seulement si un allié pouvait le rejoindre à temps) ; toute l'équipe à
# terre : il meurt. Seul un allié libre (pas au contact d'un ennemi) part le secourir.
# Les potions : l'équipe en
# emporte jusqu'à POTIONS_PER_MISSION de l'entrepôt (POTION, items.gd) et rend celles qu'elle n'a pas bues.
# Un immortel du mode dev passe aussi par l'agonie, mais reste « à terre » au lieu de mourir.
const AGONY_SECONDS := 8.0
const AGONY_HELP_RANGE := 8.0
const AGONY_ALLY_RANGE := 1.5
const AGONY_RESCUE_SECONDS := 3.0
# Arme plantée (œuvre, ch. 11 : Jenna laisse la lame dans la plaie de Zid, qui se viderait de son sang si on
# la retirait). Parfois, l'arme qui met un héros à l'agonie reste dans la plaie : un allié ne peut pas le
# stabiliser (la retirer le tuerait), seule une potion de soin (ou plus tard un soigneur) le sauve.
# Chance selon le coup : lance ou lame lourde (EMBED_HEAVY_CHANCE : lance, monstre Guerrier armé, boss),
# autre lame (EMBED_BLADE_CHANCE), flèche (EMBED_ARROW_CHANCE) ; jamais les bêtes (EMBED_BEASTS), la magie,
# le saignement ni l'épuisement.
const EMBED_HEAVY_CHANCE := 0.45
const EMBED_BLADE_CHANCE := 0.25
const EMBED_ARROW_CHANCE := 0.25
const EMBED_BEASTS := ["Loup noir", "Golem de pierre"]
const AGONY_STABILIZED_HP := 0.1
const POTIONS_PER_MISSION := 3

# --- Soin d'urgence (cahier, lot A : ch. 10) ---
# Un héros fait une hémorragie (battle.gd, saignement aggravé) : l'allié libre le plus proche (à moins de
# CARE_HELP_RANGE cases, pas au contact d'un ennemi) le rejoint et cesse de combattre ; s'il reste à son
# côté (AGONY_ALLY_RANGE) pendant CARE_SECONDS, le saignement s'arrête : « X a arrêté le saignement de Y ».
# (Un héros à l'agonie passe avant.)
const CARE_SECONDS := 3.0
const CARE_HELP_RANGE := 6.0

# --- Perception en bâtonnets (cahier, « Combat v2 », section 4 ; étape C3) ---
# Chaque combattant voit par un éventail de SIGHT_RAYS bâtonnets (rayons) sur SIGHT_ANGLE degrés vers l'avant,
# longs de SIGHT_LENGTH cases au centre et de SIGHT_LENGTH x SIGHT_SIDE_FACTOR sur les côtés (vision
# périphérique). Un bâtonnet s'arrête sur un obstacle ou un relief plus haut que ses yeux (ligne de vue 3D de C1) ;
# un combattant touché par un bâtonnet est vu. Autour de lui, il entend dans un cercle de HEARING_RADIUS cases
# (HEARING_BEAST_RADIUS pour les bêtes, EMBED_BEASTS : l'odorat). Il se souvient de la dernière position vue
# d'un ennemi pendant SIGHT_MEMORY secondes. Mise à jour toutes les PERCEPTION_INTERVAL secondes (5 par seconde).
# Ce qui change les bâtonnets : la hauteur (+SIGHT_HEIGHT_BONUS case par niveau), les herbes hautes (chaque case
# d'herbes traversée depuis le sol coûte SIGHT_GRASS_COST cases), la nuit (quête « night » : x SIGHT_NIGHT_FACTOR,
# sauf un Nocturne, axe Rythme >= NOCTURNE_MIN), la peur, la panique et la rage (cône x SIGHT_TUNNEL_FACTOR :
# vision en tunnel), l'Acuité des sens (lue par PersonalityEngine : un bâtonnet de plus ou de moins tous les
# SIGHT_ACUITY_TIERS_PER_RAY paliers, longueur et ouïe +SIGHT_ACUITY_LENGTH par palier), les monstres (longueur x
# SIGHT_MONSTER_FACTOR : « en plus court »). Mémoire : + SIGHT_MEMORY_PER_MAI s par palier de Maîtrise de soi,
# + SIGHT_MEMORY_PER_INT s par point d'Intelligence au-dessus de 10, entre SIGHT_MEMORY_MIN et SIGHT_MEMORY_MAX.
# Prudence (Audace <= -GLANCE_AXIS) ou Méfiance (Loyauté <= -GLANCE_AXIS) : un regard en arrière toutes les
# GLANCE_SECONDS secondes. Partage : un allié à moins de VOICE_RANGE cases sait ce que voit l'autre ; un Meneur
# debout le partage avec toute l'équipe. Attaque surprise : un coup d'un ennemi qui n'est pas dans ses bâtonnets
# (l'ouïe ne suffit pas : on l'entend, on ne voit pas le coup venir) : ni esquive ni parade (Mouvement souple,
# bouclier), et SURPRISE_CRIT_BONUS de chances de critique en plus. Œil de faucon, actif : bâtonnets
# x HAWK_EYE_LENGTH_FACTOR, cône x HAWK_EYE_ANGLE_FACTOR, pendant HAWK_EYE_SECONDS, puis HAWK_EYE_COOLDOWN avant
# de pouvoir le relancer. Sixième sens : SIXTH_SENSE_RAYS bâtonnets de SIXTH_SENSE_LENGTH cases vers l'arrière
# (sur SIXTH_SENSE_ANGLE degrés). Chiffres provisoires.
const PERCEPTION_INTERVAL := 0.2
const SIGHT_RAYS := 9
const SIGHT_ANGLE := 120.0
const SIGHT_LENGTH := 6.0
const SIGHT_SIDE_FACTOR := 0.6
const SIGHT_MONSTER_FACTOR := 0.8
const SIGHT_HEIGHT_BONUS := 1.0
const SIGHT_GRASS_COST := 2.0
const SIGHT_NIGHT_FACTOR := 0.5
const NOCTURNE_MIN := 50
const SIGHT_TUNNEL_FACTOR := 0.5
const SIGHT_ACUITY_TIERS_PER_RAY := 2
const SIGHT_ACUITY_LENGTH := 0.03
const SIGHT_MIN_RAYS := 3
const HEARING_RADIUS := 2.0
const HEARING_BEAST_RADIUS := 3.5
const SIGHT_MEMORY := 5.0
const SIGHT_MEMORY_PER_MAI := 0.15
const SIGHT_MEMORY_PER_INT := 0.1
const SIGHT_MEMORY_MIN := 3.0
const SIGHT_MEMORY_MAX := 8.0
const GLANCE_AXIS := 30
const GLANCE_SECONDS := 3.0
const VOICE_RANGE := 4.0
const SURPRISE_CRIT_BONUS := 0.15
const HAWK_EYE_SECONDS := 15.0
const HAWK_EYE_LENGTH_FACTOR := 2.0
const HAWK_EYE_ANGLE_FACTOR := 0.8
const HAWK_EYE_COOLDOWN := 30.0
const SIXTH_SENSE_RAYS := 3
const SIXTH_SENSE_LENGTH := 2.5
const SIXTH_SENSE_ANGLE := 60.0

# --- Vigilance des monstres et exploration (étape E, demande du porteur du projet ; ajout du projet) ---
# Les monstres n'attaquent que s'ils voient ou entendent les héros. Selon la mission, ils sont disposés autrement
# (ENEMY_DISPOSITIONS, une par étage, tirée de la graine de l'étage : un étage figé garde la sienne) :
# - "horde" (survie, défense, duel ; avant l'étape E, tous les combats) : ils savent où sont les héros et foncent ;
# - "pillage" (étage 1, le village envahi) : dispersés entre les maisons, ils rôdent au pas ;
# - "camp" : autour d'un feu, au repos (vue x STATE_SIGHT["repos"]), deux guetteurs (GUARDS_PER_CAMP) tournés vers
#   les héros, une patrouille qui fait le tour ; les autres dorment sous les tentes (renforts : ils sortent du camp) ;
# - "endormis" : le camp dort (aucun bâtonnet, ouïe x SLEEP_HEARING_FACTOR) ;
# - "poste" : un poste fortifié sur la hauteur la plus proche du camp ennemi (tireurs en haut, les autres au pied) ;
# - "patrouilles" : des groupes de 2 ou 3 font des rondes au milieu de la carte ;
# - "embuscade" : cachés dans les herbes hautes ou derrière les rochers ; vus seulement à moins de HIDDEN_SIGHT cases
#   (+ HIDDEN_ACUITY par palier d'Acuité) ; ils bondissent quand un héros passe à moins de AMBUSH_TRIGGER cases.
# États d'un monstre (« state ») : sommeil, repos, guet, ronde, poste, embusque, fouille (il va voir un bruit),
# alerte (il chasse les héros). Un monstre qui repère un héros réagit après REACTION_SECONDS (selon son état : le
# temps de se lever, de comprendre), puis crie : les monstres à moins de SHOUT_RANGE cases passent en alerte ; un
# guetteur donne l'alarme générale (tout le camp). Chaque coup s'entend à NOISE_FIGHT cases (un dormeur : moitié) :
# les monstres qui l'entendent viennent voir (fouille, au pas SEARCH_PACE), regardent SEARCH_SECONDS puis reprennent
# leur place. Un monstre frappé passe en alerte. Rondes au pas PATROL_PACE. Sans aucun contact au bout de
# ALARM_SECONDS, les monstres flairent l'équipe : alarme générale, et le compte à rebours démarre (il démarre sinon
# au premier coup échangé, comme la survie). Chiffres provisoires.
const ENEMY_DISPOSITIONS := {
	"extermination": ["pillage"],
	"subjugation": ["embuscade", "patrouilles"],
	"annihilation": ["camp", "endormis", "poste", "patrouilles"],
}
const DISPOSITION_NAMES := {"horde": "Horde", "pillage": "Pillage", "camp": "Camp gardé", "endormis": "Camp endormi",
	"poste": "Poste fortifié", "patrouilles": "Patrouilles", "embuscade": "Embuscade"}
const REACTION_SECONDS := {"sommeil": 2.5, "repos": 1.2, "guet": 0.8, "ronde": 0.6, "poste": 0.6, "fouille": 0.4, "embusque": 0.0}
const STATE_SIGHT := {"sommeil": 0.0, "repos": 0.6, "guet": 1.35, "fouille": 1.1}
const SLEEP_HEARING_FACTOR := 0.5
const SHOUT_RANGE := 7.0
const NOISE_FIGHT := 5.0
const SEARCH_SECONDS := 5.0
const SEARCH_PACE := 0.8
const PATROL_PACE := 0.55
const PATROL_RADIUS := 3.0
const GUARDS_PER_CAMP := 2
const HIDDEN_SIGHT := 2.5
const HIDDEN_ACUITY := 0.25
const AMBUSH_TRIGGER := 2.5
const ALARM_SECONDS := 80.0
# Exploration des héros (étape E) : sans ennemi connu, les héros ne restent plus sur leur ligne de départ (le Maître
# ne les place plus) : ils explorent le terrain (les cases que leurs bâtonnets ont parcourues sont « explorées »).
# L'équipe suit un meneur (un Meneur, sinon le plus audacieux) vers la case inexplorée la plus proche, en préférant
# le côté ennemi (EXPLORE_FORWARD par rangée), au pas EXPLORE_PACE (ils avancent prudemment). Un Curieux
# (Curiosité >= SCOUT_CUR) ou un Assassin part en éclaireur (jamais à plus de SCOUT_AHEAD cases devant le meneur) ;
# un solitaire (Loyauté <= -LONER_LOY, ou Audace >= LONER_AUD et Empathie <= 0) explore de son côté ; un prudent
# (Audace <= -PRUDENT_AUD) ferme la marche. Les autres le suivent à quelques pas. Plan refait toutes les
# EXPLORE_REPLAN secondes. Une case vue n'est explorée que EXPLORE_FORGET secondes (un monstre qui rôde a pu y revenir).
const EXPLORE_REPLAN := 1.5
const EXPLORE_FORGET := 25.0  # une case vue n'est « explorée » que ce temps-là : ensuite on y repasse
const EXPLORE_GOAL_MAX := 10.0  # au plus ce temps sur un même but (un toit qu'on ne voit pas d'en bas...)
const EXPLORE_PACE := 0.8
const EXPLORE_FORWARD := 0.4
const SCOUT_CUR := 40
const SCOUT_AHEAD := 4.0
const LONER_LOY := 40
const LONER_AUD := 60
const PRUDENT_AUD := 30
# Ralliement : un héros qui repère des monstres qui ne l'ont pas vu (aucun en alerte) ne charge pas seul : l'équipe se
# rassemble autour de lui (à moins de GATHER_RADIUS cases), puis attaque ensemble ; au plus GATHER_MAX secondes
# d'attente. Un solitaire n'attend personne.
const GATHER_RADIUS := 3.0
const GATHER_MAX := 10.0
# Étape E, point 3 : infiltration, assassinat, pièges (ajout du projet ; demande du porteur du projet : « une tactique
# pourrait permettre l'assassinat », « préparent des pièges », « l'infiltration et l'assassinat augmenteraient la
# survie »).
# Discrétion : un héros qui avance prudemment (exploration, ralliement) n'est remarqué par les monstres qu'à
# STEALTH_FACTOR de leur vue et de leur ouïe ; un infiltrateur à INFILTRATOR_STEALTH ; Mouvement souple : -STEALTH_PER_DODGE
# par niveau (STEALTH_MIN au plus bas).
const STEALTH_FACTOR := 0.75
const INFILTRATOR_STEALTH := 0.5
const STEALTH_PER_DODGE := 0.03
const STEALTH_MIN := 0.3
# Assassinat : un coup porté par un héros à un monstre qui ne se doute de rien (pas en alerte) et qui ne voit pas venir
# le coup : force x ASSASSINATE_POWER (tir : ASSASSINATE_RANGED_POWER ; dague ou Assassin : ASSASSINATE_BLADE_POWER et
# coup critique). S'il le tue, c'est sans un bruit (ni cri ni bruit de combat).
const ASSASSINATE_POWER := 2.0
const ASSASSINATE_RANGED_POWER := 1.5
const ASSASSINATE_BLADE_POWER := 3.0
# Et au moins cette part de la vie maximum de la cible (un chef : moitié) : une lame dans le dos d'un monstre qui dort
# le tue ; un autre coup en retire la moitié, un tir le tiers.
const ASSASSINATE_HP_SHARE := {"lame": 1.0, "coup": 0.5, "tir": 0.35}
# Infiltrateur (Assassin, dague, accès « Éclaireur », ou rusé et pas craintif : Honnêteté <= -INFILTRATOR_HON et Audace
# >= 0) : pendant le ralliement, il n'attend pas : il se glisse vers un monstre qui ne l'a pas vu (un guetteur d'abord,
# puis le plus isolé) pour l'assassiner. Tant qu'il n'est pas repéré, l'équipe l'attend jusqu'à GATHER_MAX +
# INFILTRATE_EXTRA secondes.
const INFILTRATOR_HON := 30
const INFILTRATE_EXTRA := 12.0
# Pièges : un poseur (accès « Tacticien », ou Vigilance >= TRAPPER_VIGILANCE) pose TRAPS_PER_HERO piège pendant le
# ralliement, TRAP_DISTANCE cases devant le point de ralliement vers l'ennemi (pas en horde : essayé en survie, à la sortie
# des ruelles, la horde arrive en 3 s environ, avant que le piège soit posé). Il lui faut TRAP_SECONDS sur place. Un monstre qui marche dessus : force TRAP_POWER x l'attaque du
# poseur (moins la moitié de sa défense), immobilisé TRAP_HOLD secondes (un chef : moitié des dégâts, pas immobilisé).
const TRAPPER_VIGILANCE := 30
const TRAPS_PER_HERO := 1
const TRAP_DISTANCE := 2.0
const TRAP_SECONDS := 3.0
const TRAP_POWER := 1.6
const TRAP_HOLD := 2.5
# Étape E, point 4 : les liens et le caractère en combat (ajout du projet ; demande du porteur du projet : « joue en
# équipe ou se sépare, utilise les alliés en tant qu'appât ou les protège, les jette pour occuper l'ennemi et se
# replier »). Lu par BattleTies (battle_ties.gd).
# Protéger un ami : sans le trait Protecteur, un héros (Empathie >= FRIEND_GUARD_EMP) va couvrir un ami ou un frère d'armes
# en danger (sous PROTECT_HP, à moins de PROTECT_RANGE) et encaisse PROTECT_SHARE de ses coups ; un Martyr (accès)
# MARTYR_SHARE. Couvert par un allié : leur lien gagne BOND_POINTS_COVERED après le combat.
const FRIEND_GUARD_EMP := 0
const MARTYR_SHARE := 0.6
const BOND_POINTS_COVERED := 8.0
# À revers : frapper un monstre occupé par un autre héros, dans son dos (de l'autre côté : produit scalaire <=
# REAR_ANGLE_DOT), force x REAR_ATTACK_BONUS. Un opportuniste (accès Prédateur, ou Honnêteté <= -OPPORTUNIST_HON et
# Empathie <= -OPPORTUNIST_EMP) le cherche : il se sert de l'allié comme appât et contourne le monstre ; l'allié s'en
# souvient (opinion OPINION_BAIT).
const REAR_ATTACK_BONUS := 1.3
const REAR_ANGLE_DOT := -0.3
const OPPORTUNIST_HON := 30
const OPPORTUNIST_EMP := 20
const OPINION_BAIT := -10.0
# Abandonner un allié : un égoïste lâche (accès Prédateur, ou Empathie <= -ABANDON_EMP et Courage <= -ABANDON_COURAGE),
# sous ABANDON_HP de sa vie, un monstre au contact et un allié tout près, pousse l'allié vers le monstre et se replie
# ABANDON_SECONDS (une fois par combat). L'allié perd ABANDON_MENTAL de santé mentale ; s'ils survivent, ils deviennent
# hostiles.
const ABANDON_EMP := 40
const ABANDON_COURAGE := 20
const ABANDON_HP := 0.3
const ABANDON_SECONDS := 5.0
const ABANDON_MENTAL := 10.0


## Chance que l'arme reste plantée dans un héros mis à l'agonie par ce coup (« kind » : "hit" ou "arrow" ;
## « weapon » : le type d'arme de l'attaquant, "" pour un monstre ; voir EMBED_HEAVY_CHANCE).
func embed_chance(attacker_name: String, attacker_class: String, weapon: String, boss: bool, kind: String) -> float:
	if attacker_name in EMBED_BEASTS:
		return 0.0
	if kind == "arrow":
		return EMBED_ARROW_CHANCE
	if kind != "hit":
		return 0.0
	if weapon == "Lance" or boss or (weapon == "" and attacker_class == "Guerrier"):
		return EMBED_HEAVY_CHANCE
	return EMBED_BLADE_CHANCE


## Potions de soin qu'une équipe emporte dans la Tour (celles de l'entrepôt, POTIONS_PER_MISSION au plus).
func mission_potions() -> int:
	return mini(material_count(POTION), POTIONS_PER_MISSION)


## Transforme les 4 statistiques (d'un héros ou d'un ennemi) en valeurs de combat :
## points de vie, attaque, défense, vitesse, chance de coup critique, mana.
func combat_stats(unit: Dictionary) -> Dictionary:
	var stats: Dictionary = unit["stats"]
	var magic: bool = unit["class"] in ["Mage", "Soigneur"]
	return {
		"hp": stats["vit"] * 8,
		"atk": stats["int"] if magic else stats["str"],
		"def": roundi(stats["vit"] / 2.0),
		"spd": stats["dex"],
		"crit": stats["dex"] / 200.0,
		# Mana : seulement pour les classes qui lancent des sorts (réserve = Intelligence x MANA_PER_INT).
		"mana": stats["int"] * MANA_PER_INT if magic else 0,
	}


func is_boss_floor(floor_number: int) -> bool:
	return floor_number % BOSS_EVERY == 0


## Niveau des monstres d'un étage (étage 1 : gobelins de niveau 3).
## À chaque palier (étage 5, 10...), les monstres gagnent TIER_BONUS_LEVELS niveaux de plus :
## l'étage de boss est un mur à franchir, et les étages suivants restent à ce nouveau cran.
func floor_enemy_level(floor_number: int) -> int:
	return floor_number + 2 + floor_tier(floor_number) * TIER_BONUS_LEVELS


## Numéro du palier d'un étage : 0 pour les étages 1 à 4, 1 pour 5 à 9, 2 pour 10 à 14...
func floor_tier(floor_number: int) -> int:
	return floor_number / BOSS_EVERY


## Gemmes d'un étage conquis pour la première fois (prompt 1, économie) : TOWER_GEMS_BASE + TOWER_GEMS_PER_FLOOR
## x étage (étage 1 : 120, soit un quart d'invocation spéciale), x3 sur un étage de boss ; rien en rejouant.
## Provisoire (avant : 30 + 5 x étage).
const TOWER_GEMS_BASE := 100
const TOWER_GEMS_PER_FLOOR := 20


## Récompenses d'un étage : de l'or (5 000 à l'étage 1, 10 000 à l'étage 4...),
## des gemmes, et de l'expérience pour chaque héros survivant.
## Un étage de boss rapporte trois fois plus.
func tower_rewards(floor_number: int) -> Dictionary:
	var bonus := 3 if is_boss_floor(floor_number) else 1
	return {
		"gold": roundi(5000 * (1 + (floor_number - 1) / 3.0)) * bonus,
		"gems": (TOWER_GEMS_BASE + TOWER_GEMS_PER_FLOOR * floor_number) * bonus,
		"xp": (10 + 5 * floor_number) * bonus,
	}


## Prochain palier (prompt 5, écran Donjons) : ce qu'un étage de boss débloque en plus de ses récompenses (x3,
## pierres d'attribut, palier suivant). Seul le donjon journalier dépend de la Tour pour l'instant.
const MILESTONE_UNLOCKS := {DAILY_UNLOCK_FLOOR: "le donjon journalier"}
## L'avis sur l'équipe compare le niveau moyen des meilleurs héros à celui des monstres de l'étage (en niveaux).
const MILESTONE_READY_MARGIN := 2


## Le prochain étage de boss et l'avis du Système sur les héros, en mots (jamais de chiffres de niveau) :
## {"floor", "quest": nom de la quête, "verdict": phrase, "advice": [conseils], "unlocks": [ce qu'il débloque]}.
## Les héros jugés : les TEAM_SIZE plus forts (niveau x étoiles) parmi les vivants.
func next_milestone() -> Dictionary:
	var floor_number := tower_floor + (BOSS_EVERY - tower_floor % BOSS_EVERY) % BOSS_EVERY
	var quest := floor_quest(floor_number)
	var heroes := alive_heroes()
	heroes.sort_custom(func(a, b): return a["level"] * a["rarity"] > b["level"] * b["rarity"])
	heroes = heroes.slice(0, TEAM_SIZE)
	var verdict := "Tu n'as pas encore de héros pour cet étage."
	var advice: Array[String] = []
	if not heroes.is_empty():
		var average := 0.0
		for hero in heroes:
			average += hero["level"]
		average /= heroes.size()
		var monsters := floor_enemy_level(floor_number)
		if average < monsters - MILESTONE_READY_MARGIN:
			verdict = "Tes héros ne sont pas prêts."
		elif average < monsters:
			verdict = "Tes héros ne sont pas encore prêts : il leur faut de l'expérience."
		elif average < monsters + MILESTONE_READY_MARGIN:
			verdict = "Tes héros peuvent tenter leur chance, mais ce sera dur."
		else:
			verdict = "Tes héros semblent prêts."
		if heroes.size() < TEAM_SIZE:
			advice.append("Ton équipe n'est pas complète.")
		var fighters := heroes.filter(func(hero): return not uses_magic(hero))
		var armed := fighters.filter(func(hero): return not equipped(hero, "weapon").is_empty()).size() \
			+ free_weapons().filter(func(weapon): return weapon["type"] != "Bouclier").size()
		if armed < fighters.size():
			advice.append("Tous n'auront pas d'arme : passe à l'armurerie.")
		if quest.get("lasting", false) and material_count(POTION) == 0:
			advice.append("Le combat sera long : prépare des potions de soin à la forge.")
		if quest.get("warnings", 0) > 0:
			advice.append("Une défense de la cité : le palier le plus dur, réservé aux héros équipés et aguerris.")
	var unlocks: Array[String] = ["des récompenses triplées et des pierres d'attribut",
		"le palier suivant, avec des matériaux de meilleure qualité"]
	if MILESTONE_UNLOCKS.has(floor_number) and floor_number >= tower_floor:
		unlocks.push_front(MILESTONE_UNLOCKS[floor_number])
	return {"floor": floor_number, "quest": quest["name"], "verdict": verdict, "advice": advice, "unlocks": unlocks}


## Grade des matériaux gagnés dans la Tour, selon le palier (étages 1-4, 5-9, 10-14...).
## Chiffres provisoires : le cahier montre du « Fer (C) » dès l'étage 1, mais à la forge le grade du minerai
## donne le rang de l'arme : du C si tôt rendrait le tirage d'armes inutile. À valider avec le porteur du projet.
const TOWER_MATERIAL_GRADES := ["E", "D", "C-", "C", "C+"]


## Matériaux gagnés en conquérant un étage (cahier : « Fer (C) x1, Cuir (C) x3 » à l'étage 1,
## « Fer (C) x2, Cuir (C) x3 » à l'étage 4). Le cuir n'existe pas encore dans le jeu : le charbon le
## remplace. Un étage de boss donne en plus un cristal brut. Renvoie [{"name", "grade", "count"}].
func tower_materials(floor_number: int) -> Array[Dictionary]:
	var grade: String = TOWER_MATERIAL_GRADES[mini(floor_tier(floor_number), TOWER_MATERIAL_GRADES.size() - 1)]
	var items: Array[Dictionary] = [
		{"name": "Minerai de fer", "grade": grade, "count": 1 + floor_number / 4},
		{"name": "Charbon", "grade": grade, "count": 3 + floor_number / 6},
	]
	if is_boss_floor(floor_number):
		items.append({"name": "Cristal brut", "grade": grade, "count": 1})
	return items


## Quête d'un étage : son type, son objectif et ses règles.
## Étage 1 : extermination ; étage 2 : subjugation ; ensuite annihilation ;
## tous les 5 étages : survie face à une horde (niveau des ennemis caché) ;
## tous les 10 étages : défense de la cité, annoncée par trois avertissements.
func floor_quest(floor_number: int) -> Dictionary:
	var type := "annihilation"
	if floor_number % 10 == 0:
		type = "defense"
	elif floor_number % 5 == 0:
		type = "survival"
	elif floor_number == 1:
		type = "extermination"
	elif floor_number == 2:
		type = "subjugation"
	var quest: Dictionary = QUEST_TYPES[type].duplicate()
	quest["type"] = type
	quest["floor"] = floor_number  # (le lieu de la carte en dépend, voir MapGenerator.template_for)
	quest["lasting"] = type in ["survival", "defense"]  # il faut tenir, pas tout tuer
	quest["seconds"] = KILL_QUEST_SECONDS
	if type == "survival":
		quest["seconds"] = SURVIVAL_SECONDS
		quest["waves"] = SURVIVAL_WAVES  # la horde arrive par vagues (voir Battle.current_wave)
		quest["wave_seconds"] = SURVIVAL_WAVE_SECONDS
	elif type == "defense":
		quest["seconds"] = DEFENSE_SECONDS
	quest["warnings"] = 3 if type == "defense" else 0
	quest["hidden_level"] = type == "survival"
	# Survie (cahier) : « le décompte ne démarre qu'au premier contact avec les ennemis ».
	quest["wait_contact"] = type == "survival"
	quest["walls"] = DEFENSE_WALLS if type == "defense" else 0
	return quest


## Crée les ennemis d'un étage : de plus en plus nombreux, de plus en plus forts,
## et de nouveaux monstres apparaissent en montant. Sur un étage de boss,
## le boss prend la place de 2 monstres (il en reste toujours au moins 2 pour l'escorter).
## Au combat, 6 ennemis au plus se battent en même temps : les autres arrivent en renfort
## (annihilation : quelques-uns ; survie et défense : toute une horde).
## « rng » : le tirage à suivre (MapGenerator.generate en donne un, tiré de la graine de l'étage) ; sans, le
## hasard de Godot.
func tower_enemies(floor_number: int, rng: RandomNumberGenerator = null) -> Array[Dictionary]:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.seed = randi()
	var quest := floor_quest(floor_number)
	var level := floor_enemy_level(floor_number)
	var enemies: Array[Dictionary] = []
	var early: Array = EARLY_FLOOR_ENEMIES.get(floor_number, [0, 0])
	var monster_count := mini(maxi(2 + floor_number / 2, early[0]), 6)
	if is_boss_floor(floor_number):
		var boss_index := mini(floor_number / BOSS_EVERY - 1, BOSS_TYPES.size() - 1)
		enemies.append(_create_enemy(BOSS_TYPES[boss_index], level + 2, rng))
		enemies[0]["boss"] = true
		monster_count = maxi(2, monster_count - 2)
	match quest["type"]:
		"annihilation":
			monster_count += floor_number / 3
		"defense":
			monster_count += 4 + floor_number / 2
	var known_types := ENEMY_TYPES.slice(0, mini(maxi(1 + floor_number / 2, early[1]), ENEMY_TYPES.size()))
	if quest["type"] == "survival":
		# Survie par vagues : chaque monstre porte le numéro de sa vague (0 = la première, sur le terrain dès
		# le début) ; le boss arrive avec la dernière.
		var boss: Array[Dictionary] = enemies.duplicate()
		enemies.clear()
		for wave in SURVIVAL_WAVES:
			if wave == SURVIVAL_WAVES - 1:
				for chief in boss:
					chief["wave"] = wave
					enemies.append(chief)
			for i in SURVIVAL_WAVE_MONSTERS + floor_number / 5:
				var monster := _create_enemy(known_types[rng.randi_range(0, known_types.size() - 1)], level, rng)
				monster["wave"] = wave
				enemies.append(monster)
	else:
		for i in monster_count:
			enemies.append(_create_enemy(known_types[rng.randi_range(0, known_types.size() - 1)], level, rng))
	_number_duplicates(enemies)
	return enemies


## Crée un ennemi à partir d'un modèle, renforcé selon son niveau.
func _create_enemy(template: Dictionary, level: int, rng: RandomNumberGenerator = null) -> Dictionary:
	var multiplier := 1.0 + (level - 1) * ENEMY_BONUS_PER_LEVEL
	var stats := {}
	for stat in STAT_NAMES:
		var value: float = template[stat]
		if stat != "dex":  # la vitesse change peu, pour que l'ordre d'action reste lisible
			value *= multiplier
		stats[stat] = maxi(1, roundi(value * (rng.randf_range(0.9, 1.1) if rng != null else randf_range(0.9, 1.1))))
	# « base_name » garde le nom sans lettre (Gobelin), pour regrouper les ennemis à l'affichage.
	return {"name": template["name"], "base_name": template["name"], "class": template["class"],
		"level": level, "stats": stats, "element": template.get("element", "")}


## Ajoute une lettre aux ennemis qui portent le même nom (Gobelin A, Gobelin B...),
## pour s'y retrouver dans le journal de combat.
func _number_duplicates(enemies: Array[Dictionary]) -> void:
	var counts := {}
	for enemy in enemies:
		counts[enemy["name"]] = counts.get(enemy["name"], 0) + 1
	var seen := {}
	for enemy in enemies:
		var base_name: String = enemy["name"]
		if counts[base_name] > 1:
			var index: int = seen.get(base_name, 0)
			seen[base_name] = index + 1
			enemy["name"] = "%s %s" % [base_name, char(65 + index)]


## Un étage de la Tour, figé (cahier, « Combat v2 », section 8 bis, tranché par le porteur du projet) : à la
## première visite, la carte et les ennemis (espèces, nombre, niveaux, élites, chef, vagues, positions de
## départ) sont générés (MapGenerator.generate, avec une graine tirée au hasard) puis enregistrés dans la
## sauvegarde (floors) ; ensuite l'étage n'est plus jamais modifié et se rejoue à l'identique, perdu ou gagné.
## Seul le déroulé du combat change. Une ancienne sauvegarde (sans étages enregistrés) : chaque étage est
## généré et figé à son prochain passage. La quête, elle, suit toujours les règles du jeu (floor_quest).
## Renvoie {"version", "seed", "map", "enemies"} : ne pas le modifier (les ennemis sont à copier pour un combat).
func floor_layout(floor_number: int) -> Dictionary:
	if not floors.has(floor_number):
		floors[floor_number] = MapGenerator.generate(floor_number, floor_quest(floor_number), randi())
		save_game()
	return floors[floor_number]


## Ce que les héros savent d'un étage (prompt 3, point 1 ; Sommaire du cahier : « une défaite doit pouvoir se
## comprendre et se préparer ») : le carnet de l'étage à la bibliothèque, et la mémoire des héros vivants qui y
## ont combattu (hero["recent_battles"], les RECENT_BATTLES_KEPT derniers combats : un souvenir s'efface).
## Renvoie {"visited": vrai si quelqu'un s'en souvient, "seen": {nom de base d'ennemi: vrai} (premiers contacts
## notés dans leur journal), "witnesses": [noms des héros vivants qui y étaient], "library": vrai s'il y a un carnet}.
func floor_knowledge(floor_number: int) -> Dictionary:
	var result := {"visited": false, "seen": {}, "witnesses": [], "library": false}
	if library.get("floors", {}).has("tour:%d" % floor_number):
		result["visited"] = true
		result["library"] = true
	for hero in alive_heroes():
		for memory in hero.get("recent_battles", []):
			if memory.get("floor", 0) != floor_number:
				continue
			result["visited"] = true
			if not hero["name"] in result["witnesses"]:
				result["witnesses"].append(hero["name"])
			for event in memory.get("events", []):
				if event.get("kind", "") == "contact":
					result["seen"][event.get("with", "")] = true
	return result


## Début d'un combat de la Tour : on le note dans la sauvegarde (voir pending_battle).
## « floor_number » : l'étage joué (un étage déjà conquis peut être rejoué, voir REPLAY_GOLD_RATE).
## Les héros prennent leurs armes dans l'arsenal au départ (gear_up) : à appeler avant Battle.new.
## « map » : la carte de l'étage (floor_layout), notée aussi : un combat repris au lancement suivant se joue
## sur la même carte.
func start_tower_battle(team: Array, enemies: Array, quest: Dictionary, floor_number: int, map := {}) -> void:
	update_training()  # les séances terminées avant le départ sont comptées
	pending_battle = {
		"floor": floor_number,
		"team": team.map(func(hero): return hero["id"]),
		"enemies": enemies.duplicate(true),
		"quest": quest,
		"map": map,
	}
	gear_up(team)  # sauvegarde aussi la partie


## Le jeu a été fermé en plein combat : les héros se sont débrouillés seuls.
## On rejoue tout le combat sans ordres, on applique le résultat, et on le garde pour l'annoncer.
func _resolve_pending_battle() -> void:
	var team: Array[Dictionary] = []
	for hero in alive_heroes():
		if hero["id"] in pending_battle["team"]:
			team.append(hero)
	var floor_number: int = pending_battle["floor"]
	if team.is_empty():
		pending_battle = {}
		save_game()
		return
	var battle := Battle.new(team, pending_battle["enemies"], pending_battle["quest"])
	battle.map_data = pending_battle.get("map", {})  # (combat d'avant C1 : une carte neuve)
	battle.start()
	# (Les places choisies par le Maître avant l'étape E, « placement » d'une ancienne sauvegarde, ne servent plus :
	# les héros explorent eux-mêmes.)
	while not battle.finished:
		battle.step()
	absence_report = {"floor": floor_number, "report": finish_tower_battle(battle)}


## Compétences gagnées par les exploits d'un survivant pendant le combat (textes à annoncer) :
## - Tueur de gobelins : coup fatal au boss de l'étage 5 (le Chef gobelin), ou 1 point par gobelin tué ;
## - Résistance aux flammes : 1 point par combat fini dans la même équipe qu'un mage de feu.
func _combat_feats(hero: Dictionary, fighter: Dictionary, battle: Battle) -> Array[String]:
	var news: Array[String] = []
	var goblins := 0
	var boss_goblin := false
	for kill in fighter["kills"]:
		if kill["name"].to_lower().contains("gobelin"):
			goblins += 1
			if kill["boss"]:
				boss_goblin = true
	if boss_goblin and skill_level(hero["skills"], "Tueur de gobelins") == 0:
		hero["skills"].append(new_skill("Tueur de gobelins"))
		news.append("%s — exploit ! Nouvelle compétence : Tueur de gobelins" % hero["name"])
	elif goblins > 0:
		news.append_array(add_skill_progress(hero, "Tueur de gobelins", goblins, GOBLIN_KILLS_PER_LEVEL))
	for ally in battle.heroes:
		if ally["id"] != fighter["id"] and ally["class"] == "Mage" and ally["element"] == "Feu":
			news.append_array(add_skill_progress(hero, "Résistance aux flammes", 1, FIRE_MAGE_FIGHTS_PER_LEVEL))
			break
	return news


## Bilan d'un combat (prompt 3, point 3 ; Sommaire du cahier : « une défaite doit pouvoir se comprendre ») :
## DEBRIEF_MIN à DEBRIEF_MAX moments clés tirés des journaux des héros (Battle, « Journal de combat »), dans
## l'ordre, racontés par un survivant en phrases simples, sans chiffres. Le narrateur : le survivant qui a le
## plus vécu (le plus d'événements dans son journal). Les moments : le premier contact, les blessures graves, les
## formations, l'agonie, les secours, un boss abattu, les morts ; les plus graves d'abord s'il y en a trop.
## Renvoie {"narrator": nom ("" : aucun survivant), "lines": [textes]}.
const DEBRIEF_MIN := 3
const DEBRIEF_MAX := 5
## Importance de chaque sorte de moment (la plus haute est gardée en premier).
const DEBRIEF_WEIGHTS := {"death": 6, "agony": 5, "rescued": 4, "kill": 3, "wound": 2, "formation": 1, "contact": 0}


func battle_debrief(battle: Battle) -> Dictionary:
	var survivors := battle.heroes.filter(func(fighter): return fighter["hp"] > 0 or fighter["immortal"] \
		or fighter.get("stabilized", false))
	if survivors.is_empty():
		return {"narrator": "", "lines": ["Personne n'est revenu pour raconter ce qui s'est passé."]}
	survivors.sort_custom(func(a, b): return a["journal"].size() > b["journal"].size())
	var narrator: Dictionary = survivors[0]
	var moments := []
	var seen := {}
	for fighter in battle.heroes:
		for event in fighter["journal"]:
			var kind: String = event.get("kind", "")
			if not DEBRIEF_WEIGHTS.has(kind) or (kind == "kill" and not event.get("boss", false)):
				continue
			# Une seule fois chaque formation, et seulement le tout premier contact du combat.
			var key: String = kind + ":" + (event.get("name", "") if kind == "formation" else ("" if kind == "contact" else str(fighter["id"])))
			if kind in ["wound", "agony", "death", "rescued"]:
				key += ":%s" % event.get("t", 0.0)
			if seen.has(key):
				continue
			seen[key] = true
			moments.append({"t": event.get("t", 0.0), "weight": DEBRIEF_WEIGHTS[kind], "who": fighter, "event": event})
	# Le premier contact (pour situer le récit), puis les plus importants ; remis dans l'ordre du combat.
	var contact := moments.filter(func(m): return m["event"]["kind"] == "contact")
	moments = moments.filter(func(m): return m["event"]["kind"] != "contact")
	moments.sort_custom(func(a, b): return a["weight"] > b["weight"] or (a["weight"] == b["weight"] and a["t"] < b["t"]))
	moments = moments.slice(0, DEBRIEF_MAX - contact.size()) + contact
	moments.sort_custom(func(a, b): return a["t"] < b["t"])
	var lines := []
	for moment in moments:
		lines.append(_debrief_line(moment["who"], moment["event"], narrator))
	# Trop peu de moments : le début (l'exploration, étape E), puis la fin, puis une phrase pour conclure.
	if lines.size() < DEBRIEF_MIN and battle.alert != null and battle.alert.disposition != "horde":
		lines.push_front("Nous avancions à tâtons, sans savoir où ils se cachaient.")
	if lines.size() < DEBRIEF_MIN:
		lines.append("Nous avons dû battre en retraite." if not battle.victory else "Nous avons tenu, mais à quel prix.")
	if lines.size() < DEBRIEF_MIN:
		lines.append("Je n'en dirai pas plus.")
	return {"narrator": narrator["name"], "lines": lines}


## Étape E, point 4 : ce qui s'est passé entre les héros pendant le combat (BattleTies.events) : couvert par un ami, le
## lien se renforce (BOND_POINTS_COVERED) ; servi d'appât, il s'en souvient (opinion OPINION_BAIT) ; abandonné, ils
## deviennent hostiles. Seulement entre héros encore vivants. Renvoie les annonces (fenêtre « Liens »).
func ties_after_battle(battle: Battle) -> Array[String]:
	var news: Array[String] = []
	if battle.ties == null:
		return news
	for event in battle.ties.events:
		var a: Dictionary = battle.units[event["a"]]["source"]
		var b: Dictionary = battle.units[event["b"]]["source"]
		if not a.get("alive", false) or not b.get("alive", false):
			continue
		match event["kind"]:
			"couvert":
				var line := add_bond_points(a, b, BOND_POINTS_COVERED)
				news.append(line if line != "" else "%s n'oubliera pas que %s l'a couvert." % [b["name"], a["name"]])
			"appat":
				PersonalityEngine.add_opinion(b, a, OPINION_BAIT)
				news.append("%s a compris que %s s'était servi de lui comme appât." % [b["name"], a["name"]])
			"abandon":
				news.append(make_hostile(b, a))
	return news


## Une phrase du bilan, dite par le narrateur (« je » quand c'est lui). Aucun chiffre (niveaux enlevés des causes).
func _debrief_line(who: Dictionary, event: Dictionary, narrator: Dictionary) -> String:
	var me: bool = who["id"] == narrator["id"]
	var name: String = who["name"]
	match event.get("kind", ""):
		"contact":
			return "Le combat a commencé quand nous sommes tombés sur un %s." % _plain(event.get("with", "ennemi"))
		"wound":
			return ("J'ai été gravement blessé par un %s." if me else name + " a été gravement blessé par un %s.") \
				% _plain(event.get("by", "ennemi"))
		"formation":
			var formation: String = event.get("name", "")
			if formation.begins_with("défense du Meneur"):
				return "%s a organisé la défense." % formation.get_slice("(", 1).trim_suffix(")")
			if formation == "mur de boucliers":
				return "Nous avons formé un mur de boucliers."
			return "Nous tenions toutes les portées, de près comme de loin."
		"agony":
			return ("Je suis tombé (%s), je sentais la vie me quitter." if me else name + " est tombé (%s), entre la vie et la mort.") \
				% _plain(event.get("cause", "blessé"))
		"rescued":
			var by := _plain(event.get("by", "quelqu'un"))
			by = by.left(1).to_upper() + by.substr(1)  # (« une potion de soin » → « Une potion de soin »)
			return "%s m'a sauvé de justesse." % by if me else "%s a sauvé %s de justesse." % [by, name]
		"kill":
			return ("J'ai abattu le %s." if me else name + " a abattu le %s.") % _plain(event.get("with", "chef"))
		"death":
			return "Nous avons perdu %s (%s)." % [name, _plain(event.get("cause", "tombé"))]
	return ""


## Un texte du journal sans chiffres : « tué par Gobelin A (niv. 3) » → « tué par Gobelin A ».
func _plain(text: String) -> String:
	var regex := RegEx.create_from_string("\\s*\\([^)]*\\d[^)]*\\)|\\d+")
	return regex.sub(text, "", true).strip_edges()


## Étape D (le porteur du projet : « la répétition d'une action avec un sens permet de débloquer et améliorer des
## compétences ») : ce que le héros a vécu pendant le combat (Battle._note_practice) s'ajoute à ses besoins
## (hero["practice_needs"] : {compétence: poids}), les anciens s'estompant (PRACTICE_DECAY par combat). C'est ce
## qu'il voudra travailler au terrain (training_wish, lobby.gd). Poids : projet, provisoires.
const PRACTICE_DECAY := 0.7
const PRACTICE_WEIGHTS := {"pris_au_contact": 1.0, "tirs_subis": 1.0, "mage": 1.5, "element": 0.7, "au_bouclier": 0.3,
	"esquives": 0.3, "arme": 0.15, "mage_allie": 1.0}


func merge_practice(hero: Dictionary, fighter: Dictionary, battle: Battle) -> void:
	var needs: Dictionary = hero.get("practice_needs", {})
	for skill_name in needs.keys():
		needs[skill_name] *= PRACTICE_DECAY
	var practice: Dictionary = fighter["practice"]
	var shooter: bool = hero["class"] == "Archer" or fighter["weapon"] == "Arc"
	var add := func(skill_name: String, amount: float):
		if amount > 0.0:
			needs[skill_name] = needs.get(skill_name, 0.0) + amount
	add.call("Maîtrise de la dague" if shooter else "Mouvement souple",
		practice.get("pris_au_contact", 0) * PRACTICE_WEIGHTS["pris_au_contact"])
	add.call("Parade des projectiles", practice.get("tirs_subis", 0) * PRACTICE_WEIGHTS["tirs_subis"])
	add.call("Utilisation du bouclier", practice.get("au_bouclier", 0) * PRACTICE_WEIGHTS["au_bouclier"])
	add.call("Mouvement souple", practice.get("esquives", 0) * PRACTICE_WEIGHTS["esquives"])
	for key in practice:
		var parts: PackedStringArray = key.split(":")
		if parts.size() != 2:
			continue
		match parts[0]:
			"arme":
				add.call(parts[1], practice[key] * PRACTICE_WEIGHTS["arme"])
			"mage", "element":
				add.call(ELEMENT_RESISTANCES.get(parts[1], ""), practice[key] * PRACTICE_WEIGHTS[parts[0]])
	# Un mage élémentaire dans l'équipe : on veut pouvoir se battre à côté de lui sans en souffrir.
	for ally in battle.heroes:
		if ally["id"] != fighter["id"] and ally["class"] == "Mage" and ELEMENT_RESISTANCES.has(ally["element"]):
			add.call(ELEMENT_RESISTANCES[ally["element"]], PRACTICE_WEIGHTS["mage_allie"])
	needs.erase("")
	hero["practice_needs"] = needs


## Combats gardés dans hero["recent_battles"] (le mémorial en relit jusqu'à trois).
const RECENT_BATTLES_KEPT := 3


## Journal de combat (personnalité P1b) : chaque héros, mort ou vivant, garde le journal compact de ses
## derniers combats : {"floor", "day", "victory", "survived", "formation": [noms], "counts", "events"}.
## Les survivants ajoutent le carnet de l'étage à ce qu'ils rapportent (PersonalityEngine.pending_report),
## à écrire plus tard à la bibliothèque. Aucun effet en jeu.
func _keep_battle_journals(battle: Battle, floor_number: int, killed_by: Array) -> void:
	var day := PersonalityEngine.today()
	for fighter in battle.heroes:
		var hero: Dictionary = fighter["source"]
		var battles: Array = hero.get("recent_battles", [])
		battles.append({"floor": floor_number, "day": day, "victory": battle.victory, "survived": hero["alive"],
			"formation": battle.formations_used.duplicate(), "counts": fighter["journal_counts"].duplicate(),
			"events": fighter["journal"].duplicate(true)})
		hero["recent_battles"] = battles.slice(-RECENT_BATTLES_KEPT)
		if hero["alive"]:
			PersonalityEngine.add_report_item(hero, {"kind": "floor", "floor": floor_number, "victory": battle.victory,
				"waves": battle.current_wave() + 1 if battle.quest.get("waves", 0) > 0 else 0,
				"killed_by": killed_by.duplicate(), "worked": battle.formations_used.duplicate() if battle.victory else []})


## Effets des sujets (P2 ; document de référence, section 3 bis) : un survivant compare ce qu'il a vécu à ce
## qu'il attendait de chaque sorte de monstre affrontée (PersonalityEngine.after_encounter) : sa peur baisse
## si c'était moins dur qu'attendu, monte sinon ; il apprend à les connaître (coups portés, esquives). Danger
## vécu : PersonalityData.ENCOUNTER_DANGER. La peur en combat en dépend (Battle._dread).
func learn_from_battle(hero: Dictionary, fighter: Dictionary, battle: Battle) -> void:
	var weights: Dictionary = PersonalityData.ENCOUNTER_DANGER
	var agony: bool = fighter["journal"].any(func(event): return event["kind"] == "agony")
	var fallen := battle.heroes.filter(func(other): return other["id"] != fighter["id"] and other["hp"] <= 0)
	var danger: float = (1.0 - float(maxi(0, fighter["hp"])) / fighter["max_hp"]) * weights["hp_lost"] \
		+ (weights["agony"] if agony else 0.0) + fallen.size() * weights["ally_fallen"] \
		+ (0.0 if battle.victory else weights["defeat"])
	var friend_fell := fallen.any(func(other): return fighter["bonds"].get(other["id"], 0) >= BOND_FRIEND)
	for base_name in fighter.get("foes", {}):
		var subject := PersonalityEngine.subject_for_enemy(base_name)
		if subject == "":
			continue
		var counts: Dictionary = fighter["foes"][base_name]
		PersonalityEngine.after_encounter(hero, subject, {"danger": minf(100.0, danger), "mode": "fought",
			"hits": counts["hits"], "dodges": counts["dodges"], "grave": agony or friend_fell})


## Applique le résultat d'un combat de la Tour et renvoie un rapport pour l'écran de fin :
## - les héros tombés meurent pour toujours (sauf un immortel du mode dev) ;
## - en cas de victoire : or, gemmes, expérience pour les survivants, étage suivant ;
## - en cas de défaite : les survivants gagnent quand même la moitié de l'expérience
##   (sinon une équipe bloquée ne pourrait plus jamais progresser) ;
## - un étage déjà conquis (rejoué pour entraîner une équipe) donne moins d'expérience et d'or,
##   pas de gemmes, et ne fait pas monter dans la Tour.
func finish_tower_battle(battle: Battle) -> Dictionary:
	var floor_number: int = pending_battle.get("floor", tower_floor)
	var replay := floor_number < tower_floor
	pending_battle = {}  # le combat est terminé (la sauvegarde est réécrite plus bas)
	# Les héros inscrits au terrain d'entraînement le retrouvent : la séance repart de zéro.
	for fighter in battle.heroes:
		fighter["source"]["training_since"] = Time.get_unix_time_from_system()
	var report := {
		"victory": battle.victory,
		"gold": 0,
		"gems": 0,
		"xp": 0,
		"dead": [],       # [{"hero": ..., "cause": ...}]
		"level_ups": [],  # [{"hero": ..., "levels": ..., "growth": {"str": 2, ...}}]
		"skills": [],     # compétences apprises ou améliorées pendant le combat (textes)
		"notices": [],    # annonces spéciales (déblocages...)
		"items": [],      # objets gagnés, rangés dans l'entrepôt : [{"name", "grade", "count"}]
		"lost_weapons": [],  # armes perdues avec les héros morts (textes)
		"mental": [],     # santé mentale des survivants : « Han : santé mentale 100 → 84 » (textes)
		"mvp": battle.mvp(),
		"floor": floor_number,
		"replay": replay,  # étage déjà conquis, rejoué pour s'entraîner
		"tips": [],       # conseils du Système à montrer après les fenêtres de fin (voir show_tip)
		"idle": [],       # survivants qui n'ont rien fait pendant le combat : pas d'expérience (noms)
	}
	if battle.victory and not replay and floor_number == DAILY_UNLOCK_FLOOR:
		report["notices"].append("Félicitations, Maître ! Vous avez franchi le %de étage. Le donjon journalier est débloqué." % DAILY_UNLOCK_FLOOR)
		report["notices"].append("Conseil : rassemblez des matériaux et renforcez vos héros avant de monter plus haut.")
	for fighter in battle.heroes:
		if fighter["hp"] <= 0 and not fighter["immortal"]:
			fighter["source"]["alive"] = false
			_remove_from_teams(fighter["source"]["id"])
			# La cause est gardée sur la fiche du héros (et donc dans la sauvegarde).
			fighter["source"]["death_cause"] = fighter["killer"]
			# Son dernier combat compte (fiche figée des héros tombés ; les survivants : mental_after_battle).
			fighter["source"]["fights"] = fighter["source"].get("fights", 0) + 1
			report["dead"].append({"hero": fighter["source"], "cause": fighter["killer"]})
			# Ses armes sont perdues avec lui (tidy_arsenal les retire plus bas).
			for weapon in arsenal:
				if weapon["owner"] == fighter["source"]["id"]:
					report["lost_weapons"].append("%s : %s" % [fighter["source"]["name"], weapon_name(weapon)])
	if not report["dead"].is_empty():
		report["tips"].append("mort")  # conseil du Système à la première mort
	# Bilan (prompt 3, point 3) : après une défaite ou une mort, un survivant raconte les moments clés.
	if not battle.victory or not report["dead"].is_empty():
		report["debrief"] = battle_debrief(battle)
	_keep_battle_journals(battle, floor_number, report["dead"].map(func(dead): return dead["cause"]))

	var rewards := tower_rewards(floor_number)
	if replay:
		rewards["gold"] = roundi(rewards["gold"] * REPLAY_GOLD_RATE)
		rewards["gems"] = 0
		rewards["xp"] = roundi(rewards["xp"] * REPLAY_XP_RATE)
	if battle.victory:
		report.merge(rewards, true)
		if not replay:
			tower_floor += 1
			# Matériaux gradés, rangés dans l'entrepôt (pas en rejouant un étage : on ne les gagne qu'une fois).
			report["items"].append_array(tower_materials(floor_number))
			# Objet de promotion : un étage de boss conquis donne des pierres d'attribut.
			if is_boss_floor(floor_number):
				report["items"].append({"name": PROMOTION_STONE, "grade": "F", "count": BOSS_STONES})
			for item in report["items"]:
				add_material(item["name"], item["grade"], item["count"])
		add_gold(rewards["gold"])
		add_gems(rewards["gems"])
	else:
		report["xp"] = rewards["xp"] / 2

	for fighter in battle.heroes:
		var hero: Dictionary = fighter["source"]
		if hero["alive"]:
			# Les compétences gagnées pendant le combat sont gardées par les survivants.
			hero["skills"] = fighter["skills"]
			report["skills"].append_array(fighter["skill_news"])
			# Maîtrise de l'arc : chaque flèche tirée fait progresser la compétence.
			if fighter["shots"] > 0:
				report["skills"].append_array(add_skill_progress(hero, "Maîtrise de l'arc",
					fighter["shots"], skill_progress_needed("Maîtrise de l'arc")))
			# Étape D : la dague de secours d'un archer progresse coup par coup (comme l'arc tir par tir).
			if fighter["dagger_hits"] > 0:
				report["skills"].append_array(add_skill_progress(hero, "Maîtrise de la dague",
					fighter["dagger_hits"], skill_progress_needed("Maîtrise de la dague")))
			report["skills"].append_array(_combat_feats(hero, fighter, battle))
			merge_practice(hero, fighter, battle)  # (étape D) ce qu'il a vécu : ce qu'il voudra travailler
			report["skills"].append_array(check_evolutions(hero))
			# Ce qu'il a fait pendant le combat oriente la croissance de ses stats (voir heroes.gd).
			add_activity(hero, fighter["acts"])
			# Expérience méritée (phase 1.2 ; œuvre, ch. 2 et 4) : sans avoir porté ni reçu un seul coup
			# (ni soigné), il ne gagne pas d'expérience ; le rapport le signale.
			var earned: int = report["xp"] if fighter.get("engaged", true) else 0
			if earned == 0 and report["xp"] > 0:
				report["idle"].append(hero["name"])
			var levels := gain_xp(hero, earned)
			if levels > 0:
				report["level_ups"].append({"hero": hero, "levels": levels, "growth": last_growth.duplicate()})
			# Conseil du Système la première fois qu'un héros revient blessé ou ébranlé.
			if fighter["hp"] < fighter["max_hp"] or fighter["mental"] < mental(hero):
				if not "blessure" in report["tips"]:
					report["tips"].append("blessure")
			# Ce qu'il a appris des monstres affrontés (appréhension, connaissance).
			learn_from_battle(hero, fighter, battle)
			# Santé mentale : ce que le combat lui a coûté (voir personality.gd).
			var mental_line := mental_after_battle(hero, fighter, battle.victory, report["mental"])
			if mental_line != "":
				report["mental"].append(mental_line)
	# Les ambitieux laissés à la cité stressent (voir personality.gd).
	mental_left_out(battle.heroes.map(func(fighter): return fighter["source"]), report["mental"])
	# Liens : les survivants se rapprochent, plus vite après une victoire difficile (voir personality.gd).
	var survivors := battle.heroes.filter(func(fighter): return fighter["source"]["alive"])
	var hp := 0
	var max_hp := 0
	for fighter in survivors:
		hp += maxi(0, fighter["hp"])
		max_hp += fighter["max_hp"]
	var hard: bool = is_boss_floor(floor_number) or not report["dead"].is_empty() \
		or (max_hp > 0 and hp < max_hp * HARD_VICTORY_HP)
	report["bonds"] = bonds_after_battle(survivors.map(func(fighter): return fighter["source"]), battle.victory, hard)
	report["bonds"].append_array(ties_after_battle(battle))  # (étape E, point 4)
	# Tutoriel : l'étage gagné ouvre la chambre de synthèse (cahier : « la synthèse, dont la porte s'ouvre à
	# ce moment »), sans frais. Perdu : on recommence l'étage. Moins de 2 héros vivants : pas de synthèse
	# possible, le tutoriel s'arrête là.
	if tutorial_step == "etage":
		if alive_heroes().size() < 2:
			end_tutorial()
			report["tips"].append("tuto_fin")
		elif battle.victory:
			if not "synthese" in buildings:
				buildings.append("synthese")
			advance_tutorial("etage")  # sa fenêtre vient après l'animation de construction dans la cité (hub_screen.gd)
	# Usure : les armes émoussées pendant le combat sont réparées au retour (l'usure ne dure que le combat).
	var blunted := battle.heroes.filter(func(fighter): return fighter["source"]["alive"] \
		and battle.wear_factor(fighter) <= WEAR_NOTICE)
	if not blunted.is_empty():
		report["repairs"] = "Armes émoussées, réparées au retour : %s." % ", ".join(blunted.map(func(fighter): return fighter["name"]))
	# Les potions de soin bues pendant le combat (agonie) sont retirées de l'entrepôt.
	if battle.potions_used > 0:
		_take_material(POTION, battle.potions_used)
		report["potions"] = "Potions de soin utilisées : %d (il en reste %d dans l'entrepôt)." \
			% [battle.potions_used, material_count(POTION)]
	tidy_arsenal()  # armes des morts perdues, les autres reposent les leurs (et la partie est sauvegardée)
	return report


## Les statistiques d'un héros en Berserk, pour sa fiche : [[nom, valeur en Berserk, valeur de base], ...]
## (« Force 16 / 11 (+5) »), ou [] s'il n'a pas Berserk. Mêmes chiffres que battle.gd (_enter_berserk).
func berserk_preview(hero: Dictionary) -> Array:
	var changes := berserk_stat_changes(hero["skills"])
	if changes.has("int"):  # Rage maîtrisée : pas de perte d'Intelligence (P2)
		changes["int"] = roundi(changes["int"] * PersonalityEngine.modified("berserk_int_malus", hero, 1.0))
	var rows := []
	for stat in changes:
		var base: int = hero["stats"][stat]
		rows.append([STAT_NAMES[stat], maxi(1, base + changes[stat]), base])
	return rows
