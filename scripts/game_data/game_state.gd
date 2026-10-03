class_name GameState
extends Node
## L'état de la partie : tout ce qui est enregistré dans la sauvegarde (héros, monnaies, Tour, armes,
## bâtiments, entrepôt...), les monnaies et les signaux envoyés aux écrans.
## C'est le premier fichier de la pile de GameData (voir game_data.gd) : tous les autres l'utilisent.

signal gems_changed(new_amount: int)
signal gold_changed(new_amount: int)
## Une ou plusieurs séances d'entraînement viennent de se terminer.
signal training_updated
## Quelque chose a changé dans la cité sans que le joueur y touche (retour du donjon journalier...).
signal lobby_updated
## Un bâtiment s'est construit tout seul, sa condition remplie (terrain d'entraînement...) :
## main.gd l'annonce dans une fenêtre, et le hub 3D joue l'animation de construction.
signal facility_completed(title: String, lines: Array)


# ---------------------------------------------------------------------------
# État de la partie
# ---------------------------------------------------------------------------

## Vraies réserves de gemmes et d'or : celles de la sauvegarde.
var real_gems := 3000
var real_gold := 0
## Montant affiché et utilisable en mode dev (Settings.dev_mode) : « infini ».
const DEV_MONEY := 999999999
## Gemmes et or utilisables : à utiliser partout dans le jeu. En mode dev, ils sont infinis
## (on peut tout payer) et les vraies réserves ne bougent pas : on les retrouve en quittant le mode dev.
var gems: int:
	get:
		return DEV_MONEY if Settings.dev_mode else real_gems
	set(value):
		if not Settings.dev_mode:
			real_gems = value
var gold: int:
	get:
		return DEV_MONEY if Settings.dev_mode else real_gold
	set(value):
		if not Settings.dev_mode:
			real_gold = value
var pity_counter := 0

## Prochain étage de la Tour à conquérir.
var tower_floor := 1

## Tous les héros possédés. Chaque héros est unique :
## deux « Aldric » sont deux individus différents, avec leurs propres statistiques.
var roster: Array[Dictionary] = []

## Numéro donné au prochain héros (chaque héros a un numéro unique).
var next_hero_id := 1

## Codes secrets déjà utilisés.
var used_codes: Array[String] = []

## Équipes composées à l'avance : TEAM_COUNT listes de numéros (id) de héros, dans l'ordre choisi.
var teams: Array = []

## Combat de la Tour en cours (vide s'il n'y en a pas) : {"floor", "team": [id des héros],
## "enemies": [...], "quest": {...}}. Il est sauvegardé dès le début du combat : si le jeu est fermé
## en plein combat, les héros se débrouillent seuls et le combat est terminé au lancement suivant.
var pending_battle: Dictionary = {}

## Résultat d'un combat terminé pendant l'absence du joueur, à lui annoncer
## (vide sinon) : {"floor": ..., "report": rapport de finish_tower_battle}.
var absence_report: Dictionary = {}

## Compétences apprises ou améliorées au terrain d'entraînement, pas encore annoncées au joueur (textes).
var training_news: Array = []

## Toutes les armes possédées, portées ou rangées (voir la section « Armes »).
var arsenal: Array = []
## Numéro donné à la prochaine arme tirée.
var next_weapon_id := 1
## Nombre d'armes tirées depuis le début de la partie (le terrain d'entraînement s'ouvre à 10).
var weapon_draws := 0
## Bâtiments construits (identifiants de BUILDINGS).
var buildings: Array = []

# Entrepôt et donjon journalier (voir la section du même nom).
## Matériaux dans l'entrepôt : {"Minerai de fer": {"F": 12, "E": 3}, ...}.
var warehouse: Dictionary = {}
## Plans de forge possédés (types d'armes), trouvés au donjon journalier.
var plans: Array = []
## Expédition en cours (vide s'il n'y en a pas) : {"team": [id], "start": t, "end": t, "log": [...]}.
var expedition: Dictionary = {}
## Jour (AAAA-MM-JJ) de la dernière expédition : une seule par jour.
var last_expedition_day := ""
## Résultat d'une expédition revenue, pas encore montré au joueur : {"lines": [...], "items": [...]}.
var expedition_report: Dictionary = {}


## Enregistre la partie. La vraie fonction est plus haut dans la pile (section « Sauvegarde ») et
## remplace celle-ci : elle est déclarée ici pour que tous les fichiers puissent demander une sauvegarde.
func save_game() -> void:
	pass


# ---------------------------------------------------------------------------
# Monnaies
# ---------------------------------------------------------------------------

func add_gems(amount: int) -> void:
	gems += amount
	gems_changed.emit(gems)
	save_game()


func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)
	save_game()
