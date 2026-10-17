class_name TacticsData
extends RefCounted
## Données de l'IA tactique des héros (cahier, onglet « Combat v2 », section « L'IA tactique des héros » ;
## étape C3). Données seulement : les fonctions sont dans BattleTactics (scripts/battle_tactics.gd).
##
## Chaque héros libre (sans ordre du Maître) note les cases autour de lui toutes les PLAN_SECONDS secondes et
## choisit où être, contre les seuls ennemis qu'il connaît (perception, BattlePerception). Une case gagne ou perd
## des points selon des CRITÈRES (hauteur, couvert, passage étroit...), chacun avec son poids ; des SEUILS règlent
## les attitudes (quand engager, quand décrocher...).
##
## Poids et seuils sont rangés PAR HÉROS (hero["tactics"], sauvegardé), PAR CONTEXTE (type de quête, famille
## d'ennemis, gabarit de terrain) : ils partent de BASE_WEIGHTS / BASE_THRESHOLDS, ajustés une fois pour toutes
## à la création par sa personnalité (PERSONALITY, lue par PersonalityEngine). Ils ne changent pas encore : l'étape
## suivante (C3b, « L'apprentissage tactique de chaque héros ») les fera évoluer combat après combat, bornés
## entre LEARN_MIN et LEARN_MAX fois leur valeur de départ.
## Ajout du projet : PERSONALITY est une petite table à part, provisoire, à rapprocher des MODIFIERS de la
## personnalité P2 (branche p2-personnalite) au moment de la fusion. Elle ne passe pas par modifier().
## Tous les chiffres sont provisoires.

## Version des données tactiques d'un héros (hero["tactics"]["version"]).
const VERSION := 1

## Toutes les PLAN_SECONDS secondes, chaque héros libre refait son plan (attitude, case, cible).
const PLAN_SECONDS := 0.5
## Les cases étudiées : à moins de SEARCH_RADIUS cases (à pied, échelles comprises), les plus proches d'abord.
const SEARCH_RADIUS := 5.0

## Les critères, du plus simple au plus fin : un héros n'en voit que les premiers (selon son Intelligence, voir
## criteria_count). Un héros peu intelligent ne voit que la hauteur et la bonne distance (et la cible la plus
## proche) ; un héros brillant pense couvert, passage étroit, dos au mur, bord du vide.
const CRITERIA := ["hauteur", "distance", "allies", "decouvert", "couvert", "encercle", "isole", "bord", "passage", "dos"]

## Ce qu'un critère dit au Maître (mode dev, « ses 3 raisons »).
const CRITERIA_NAMES := {
	"hauteur": "en hauteur", "distance": "à bonne distance de tir", "allies": "près des alliés",
	"decouvert": "à découvert sous les tirs", "couvert": "à couvert des tireurs", "encercle": "trop d'ennemis au contact",
	"isole": "isolé", "bord": "au bord d'une chute", "passage": "passage étroit devant", "dos": "dos au mur",
	"trajet": "trajet", "rester": "garde sa place", "proteger": "entre l'allié et l'ennemi", "loin": "loin des ennemis",
	"avance": "se rapproche du tireur à l'abri",
}

## Poids de départ de chaque critère (points par unité : par niveau de hauteur, par tireur, par allié...).
## Positifs : ce qui est bien ; négatifs : ce qui est mal. « trajet » : par case à parcourir (on ne court pas pour
## un rien) ; « rester » : bonus pour la case déjà choisie (pas d'hésitation entre deux cases presque égales).
const BASE_WEIGHTS := {
	"hauteur": 1.5,     # par niveau ; x HEIGHT_RANGED_FACTOR pour un tireur
	"distance": 2.0,    # tireur à bonne distance (à sa portée, pas au contact)
	"allies": 0.6,      # par allié à moins de ALLY_RANGE cases (ALLY_MAX au plus)
	"decouvert": -1.2,  # par tireur ennemi qui le voit et l'atteint
	"couvert": 1.0,     # par tireur ennemi dont il est caché ou couvert
	"encercle": -1.2,   # par ennemi au contact au-delà du premier (tireur : dès le premier)
	"isole": -1.5,      # aucun allié à moins de ISOLATED_RANGE cases
	"bord": -1.5,       # une case voisine plus basse de 2 niveaux et plus (on peut y être poussé)
	"passage": 1.5,     # l'ennemi n'arrive devant lui que par une case (moitié par deux)
	"dos": 1.0,         # dos au mur (rien derrière : pas d'encerclement)
	"trajet": -0.25,    # par case à parcourir
	"rester": 0.5,
	"proteger": 2.0,    # attitude « protéger » : près du point entre l'allié faible et l'ennemi
	"loin": 0.8,        # attitude « décrocher » (et la peur) : par case d'écart avec l'ennemi le plus proche
	"avance": 0.8,      # attitude « se couvrir » : par case gagnée vers le tireur (on se couvre pour avancer)
}
const HEIGHT_RANGED_FACTOR := 2.0
const ALLY_RANGE := 2.0
const ALLY_MAX := 3
const ISOLATED_RANGE := 3.0
## Au contact : un ennemi à moins de CONTACT_RANGE cases.
const CONTACT_RANGE := 1.8

## Seuils des attitudes (cahier : attendre, engager, garder ses distances, se couvrir, concentrer, protéger,
## décrocher) :
## - engage_hp : une cible sous cette part de sa vie (affaiblie) vaut qu'on aille la chercher ;
## - engage_range : une cible connue à moins de ce nombre de cases de sa case, on y va (l'Impulsif voit plus loin) ;
## - wait_max : attendre plus longtemps que ça une cible qui ne vient pas ne sert à rien : on engage ;
## - help_range : un allié au contact d'un ennemi à moins de ce nombre de cases : on va l'aider (concentrer) ;
## - retreat_hp, retreat_foes : sous cette part de sa vie, avec au moins ce nombre d'ennemis au contact : décrocher ;
## - cover_max : sous le feu, il se couvre au plus ce nombre de secondes, puis il va chercher le tireur (« se
##   couvrir avant d'avancer ») ; sans couvert proche, ou un tireur à sa propre portée : il riposte tout de suite ;
## - shooter_range : un ennemi au corps à corps à moins de ce nombre de cases d'un tireur : il recule ;
## - protect_hp : un allié sous cette part de sa vie, menacé, à moins de PROTECT_RANGE cases : le protéger ;
## - danger_hp : un héros posté par le Maître ne quitte sa place que pour un danger grave (sous cette part de sa
##   vie, au moins retreat_foes ennemis au contact).
const BASE_THRESHOLDS := {
	"engage_hp": 0.4,
	"engage_range": 3.0,
	"wait_max": 6.0,
	"help_range": 5.0,
	"cover_max": 3.0,
	"retreat_hp": 0.35,
	"retreat_foes": 2,
	"shooter_range": 2.5,
	"protect_hp": 0.35,
	"danger_hp": 0.3,
	"engage_crowd": 2,
}
## engage_crowd : autour de la cible, à moins de CROWD_RANGE cases, ce nombre d'autres ennemis (moins les alliés déjà
## là) : un héros qui pense à l'encerclement n'y va pas seul, il les attend.
const CROWD_RANGE := 2.5
const PROTECT_RANGE := 5.0
## Attendre l'ennemi ne vaut que si la meilleure case proche vaut au moins WAIT_ADVANTAGE points de plus que
## l'endroit où il est (sinon il engage).
const WAIT_ADVANTAGE := 1.0
## Colère : un ennemi qui a blessé un allié depuis moins de ANGER_SECONDS secondes ; un Colérique (axe Colère >=
## ANGER_AXIS) le charge, même si c'est une erreur.
const ANGER_SECONDS := 3.0
const ANGER_AXIS := 50

## Bornes de l'apprentissage (C3b) : jamais plus du double ni moins de la moitié de la valeur de départ.
const LEARN_MIN := 0.5
const LEARN_MAX := 2.0

## Intelligence (stat) : nombre de critères vus (CRITERIA, dans l'ordre) et de cases étudiées.
## critères = CRITERIA_BASE + (Intelligence - INT_BASE) / INT_PER_CRITERION, cases = CELLS_BASE + (Intelligence -
## INT_BASE) x CELLS_PER_INT, bornés. Lucidité (Foi négative) et Acuité aiguë : +1 critère et +LUCID_CELLS cases
## par LUCID_TIERS paliers (au-dessus de 0 ; en dessous, en moins).
## Exemples : Intelligence 10 (1 étoile) : 3 critères, 14 cases ; 15 (3 étoiles) : 6 critères, 29 cases ; 21 : 10, 47.
const INT_BASE := 8
const CRITERIA_BASE := 2
const INT_PER_CRITERION := 1.5
const CELLS_BASE := 8
const CELLS_PER_INT := 3.0
const CELLS_MIN := 8
const CELLS_MAX := 50
const LUCID_TIERS := 4
const LUCID_CELLS := 6

## La personnalité règle les poids et les seuils de départ (cahier : « L'intelligence et la personnalité règlent
## la qualité des choix »). Chaque ligne : ce qui est réglé, l'axe ou le composite lu (PersonalityEngine.axis ou
## composite, de -100 à +100), et le changement pour +100 (multiplicateur : x (1 + k x valeur / 100), borné à
## [0,2 ; 3]). Audace / Prudence : l'Audacieux engage tôt, se soucie moins d'être à découvert ; le Prudent attend
## et se couvre. Impulsivité / Maîtrise de soi : l'Impulsif quitte sa position dès qu'il voit une cible (Maîtrise
## négative : portée d'engagement plus grande, attente plus courte). Courage (composite) : le peureux cherche
## d'abord à ne pas être encerclé ni isolé, et décroche plus tôt.
const PERSONALITY := [
	{"what": "engage_range", "axis": "AUD", "k": 0.3},
	{"what": "engage_range", "axis": "MAI", "k": -0.8},
	{"what": "wait_max", "axis": "AUD", "k": -0.5},
	{"what": "wait_max", "axis": "MAI", "k": 0.5},
	{"what": "engage_hp", "axis": "AUD", "k": 0.4},
	{"what": "engage_crowd", "axis": "AUD", "k": 0.6},
	{"what": "engage_crowd", "axis": "MAI", "k": -0.3},
	{"what": "retreat_hp", "axis": "AUD", "k": -0.4},
	{"what": "retreat_hp", "composite": "courage", "k": -0.3},
	{"what": "couvert", "axis": "AUD", "k": -0.4},
	{"what": "decouvert", "axis": "AUD", "k": -0.4},
	{"what": "encercle", "composite": "courage", "k": -0.3},
	{"what": "isole", "composite": "courage", "k": -0.3},
	{"what": "allies", "axis": "EMP", "k": 0.3},
]
const PERSONALITY_MIN := 0.2
const PERSONALITY_MAX := 3.0

## La peur (en combat) : il cherche la position la plus sûre, même mauvaise pour l'équipe (poids changés le temps
## de sa peur).
const FEAR_WEIGHTS := {"loin": 2.0, "encercle": 2.0, "decouvert": 2.0, "allies": 0.3, "isole": 0.5, "passage": 0.0}

## Familles d'ennemis (contexte des habitudes) : le premier mot trouvé dans le nom de base.
const FAMILIES := {"gobelin": "gobelins", "loup": "loups", "squelette": "morts-vivants", "golem": "golems"}
