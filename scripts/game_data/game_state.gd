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
## De nouvelles annonces de relations attendent dans relation_news (hostilité née à la cité) :
## main.gd les montre dans une fenêtre système.
signal relations_changed
## Un conseil du Système est demandé (voir show_tip) : main.gd l'affiche dans une fenêtre « Conseil ».
signal tip_requested(tip_id: String)
## Le tutoriel a changé d'étape (ou s'est terminé) : main.gd met à jour le bandeau et les onglets permis.
signal tutorial_changed


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
## Expéditions en cours (autant qu'on veut, plusieurs groupes à la fois) :
## [{"team": [id], "team_index": n, "start": t, "end": t, "log": [...]}, ...].
var expeditions: Array = []
## Retours d'expédition pas encore montrés au joueur : [{"lines": [...]}, ...].
var expedition_reports: Array = []

## Moment (temps réel) où la santé mentale des héros à la cité a été mise à jour pour la dernière fois
## (voir update_mental, personality.gd). 0 = pas encore.
var mental_updated_at := 0.0
## Liens entre héros (voir personality.gd, section « Liens ») : points de lien de chaque paire,
## { "3-7": 12.0 } (les deux numéros de héros, le plus petit d'abord). Une paire absente = inconnus.
var bonds := {}
## Moment (temps réel) de la dernière heure comptée pour les querelles à la cité (voir update_quarrels,
## personality.gd). 0 = pas encore.
var quarrels_checked_at := 0.0
## Annonces de relations en attente d'être montrées au joueur (« X fait preuve d'hostilité envers Y ! »).
var relation_news: Array = []
## Défis lancés par les héros, en attente de la réponse du Maître : [{"challenger": numéro, "rival": numéro}].
var pending_challenges: Array = []
## Conseils du Système déjà montrés (identifiants de TIP_IDS) : chacun ne s'affiche qu'une fois.
var seen_tips: Array = []
## Étape du tutoriel obligatoire d'une partie neuve (voir TUTORIAL_STEPS) ; "" = terminé (ou ancienne partie).
var tutorial_step := ""


## Enregistre la partie. La vraie fonction est plus haut dans la pile (save.gd) et remplace
## celle-ci : elle est déclarée ici pour que tous les fichiers puissent demander une sauvegarde.
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


# ---------------------------------------------------------------------------
# Conseils du Système (accueil d'un nouveau joueur)
# ---------------------------------------------------------------------------
# Comme dans l'œuvre, le Système glisse un conseil au Maître la première fois qu'il fait quelque chose
# (première invocation, premier étage...). Les textes sont dans SystemTips (scripts/system_tips.gd),
# l'affichage dans main.gd. Un conseil vu est noté dans la sauvegarde (seen_tips) ; le réglage
# Settings.tips les coupe tous, et Paramètres > « Réafficher les conseils » vide seen_tips.

## Tous les conseils, dans l'ordre où un joueur les rencontre d'habitude. Ceux qui commencent par « tuto_ »
## sont les fenêtres du tutoriel (une par étape, puis la fin) : obligatoires comme la bienvenue, le réglage
## ne les coupe pas.
const TIP_IDS := ["bienvenue", "tuto_invocation", "invocation", "tuto_equipe", "equipe", "tuto_etage", "etage",
	"blessure", "mort", "tuto_synthese", "tuto_fin", "batiment"]


## Demande d'afficher un conseil, s'il n'a pas déjà été vu et si les conseils sont activés.
## On peut l'appeler à chaque fois que l'événement arrive : seule la première fois compte.
func show_tip(tip_id: String) -> void:
	if (Settings.tips or is_tutorial_tip(tip_id)) and not tip_id in seen_tips:
		tip_requested.emit(tip_id)


## Vrai pour une fenêtre du tutoriel, bienvenue comprise (obligatoire, même conseils coupés).
func is_tutorial_tip(tip_id: String) -> bool:
	return tip_id == "bienvenue" or tip_id.begins_with("tuto_")


## Le joueur a fermé la fenêtre du conseil : il ne la reverra plus.
func mark_tip_seen(tip_id: String) -> void:
	if not tip_id in seen_tips:
		seen_tips.append(tip_id)
		save_game()


## « Réafficher les conseils » (Paramètres) : chaque conseil reviendra à la prochaine occasion.
func reset_tips() -> void:
	# Les fenêtres d'un tutoriel déjà fini ne reviennent pas (il ne se rejoue pas).
	seen_tips = seen_tips.filter(func(tip_id): return is_tutorial_tip(tip_id) and tutorial_step == "")
	save_game()


# ---------------------------------------------------------------------------
# Tutoriel obligatoire (partie neuve)
# ---------------------------------------------------------------------------
# Cahier, « Tutoriel et interface » : premier combat, puis la synthèse, dont la porte s'ouvre à ce moment.
# Demande du porteur du projet : on commence avec de quoi payer une invocation normale x10, et le tutoriel
# force, dans l'ordre : l'invocation x10 (un 3 étoiles garanti, voir summon.gd), une équipe à composer,
# l'étage 1 (à gagner), une synthèse. Pendant ce temps, seul l'onglet de l'étape est permis (main.gd),
# avec un bandeau qui dit quoi faire. Les fenêtres de chaque étape sont des conseils « tuto_... ».
# Une partie d'avant le tutoriel n'en a pas (tutorial_step vide).

const TUTORIAL_STEPS := ["invocation", "equipe", "etage", "synthese"]
## Nombre de héros de l'invocation forcée du tutoriel.
const TUTORIAL_SUMMON_COUNT := 10


## Passe à l'étape suivante du tutoriel, si on en est bien à « from_step » (sinon rien).
func advance_tutorial(from_step: String) -> void:
	if tutorial_step != from_step:
		return
	var index := TUTORIAL_STEPS.find(from_step)
	tutorial_step = TUTORIAL_STEPS[index + 1] if index + 1 < TUTORIAL_STEPS.size() else ""
	save_game()
	tutorial_changed.emit()


## Termine le tutoriel tout de suite (plus assez de héros pour la suite, ou mode dev).
func end_tutorial() -> void:
	if tutorial_step == "":
		return
	tutorial_step = ""
	save_game()
	tutorial_changed.emit()


## Demande la fenêtre de l'étape en cours du tutoriel (ou celle de la fin), si elle n'a pas été vue.
func show_tutorial_tip() -> void:
	show_tip("tuto_" + (tutorial_step if tutorial_step != "" else "fin"))
