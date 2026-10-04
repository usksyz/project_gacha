class_name SystemTips
## Textes des conseils du Système : une fenêtre « Conseil » la première fois que le Maître fait quelque chose,
## comme dans l'œuvre. Qui les demande : GameData.show_tip (game_state.gd) ; qui les affiche : main.gd.
## Les chiffres viennent de GameData, pour rester justes si on les change.


## Titre de la fenêtre.
static func title(tip_id: String) -> String:
	if tip_id == "bienvenue":
		return "Bienvenue, Maître"
	if tip_id == "tuto_fin":
		return "Tutoriel terminé"
	if tip_id.begins_with("tuto_"):
		var step := GameData.TUTORIAL_STEPS.find(tip_id.trim_prefix("tuto_")) + 1
		return "Tutoriel — étape %d / %d" % [step, GameData.TUTORIAL_STEPS.size()]
	return "Conseil"


## Le bandeau du tutoriel (en haut de l'écran) : ce qu'il faut faire maintenant.
static func tutorial_goal(step: String) -> String:
	var number := "Tutoriel %d/%d : " % [GameData.TUTORIAL_STEPS.find(step) + 1, GameData.TUTORIAL_STEPS.size()]
	match step:
		"invocation":
			return number + "invoque %d héros (invocation normale x%d)." % [GameData.TUTORIAL_SUMMON_COUNT, GameData.TUTORIAL_SUMMON_COUNT]
		"equipe":
			return number + "Donjons > « Composer les équipes », place des héros, puis « Terminé »."
		"etage":
			return number + "Donjons > « Entrer dans la Tour » et conquiers l'étage 1."
		"synthese":
			return number + "choisis un héros à renforcer, puis au moins un héros à sacrifier."
	return ""


## Les lignes de la fenêtre (une ligne = un paragraphe centré).
static func lines(tip_id: String) -> Array:
	match tip_id:
		"bienvenue":
			return [
				"Le Système vous a choisi comme Maître de cette cité suspendue dans le néant.",
				"Votre mission : invoquer des héros, les mener dans la Tour et la gravir, étage par étage.",
				"Attention : un héros qui tombe au combat meurt pour toujours. Rien ne le ramènera.",
				"Le Système vous guide pour vos premiers pas : suivez le bandeau en haut de l'écran.",
			]
		"tuto_invocation":
			return [
				"Le Système vous offre %s or : de quoi invoquer vos %d premiers héros." % [
					UI.format_number(GameData.SUMMON_TYPES["normal"]["cost"] * GameData.TUTORIAL_SUMMON_COUNT), GameData.TUTORIAL_SUMMON_COUNT],
				"Touchez l'invocation normale x%d." % GameData.TUTORIAL_SUMMON_COUNT,
				"Pour cette première fois, un héros 3 étoiles vous est garanti.",
			]
		"tuto_equipe":
			return [
				"Vos premiers héros sont arrivés. Il faut maintenant former une équipe.",
				"Ouvrez « Donjons », puis « Composer les équipes ». Placez de 1 à %d héros, puis touchez « Terminé »." % GameData.TEAM_SIZE,
			]
		"tuto_etage":
			return [
				"Votre équipe est prête. La Tour vous attend.",
				"Touchez « Entrer dans la Tour », choisissez votre équipe et conquérez l'étage 1.",
				"En cas de défaite, les survivants rentrent à la cité : vous pourrez retenter l'étage.",
			]
		"tuto_synthese":
			return [
				"Étage conquis ! La porte de la chambre de synthèse s'ouvre.",
				"La synthèse sacrifie des héros pour en renforcer un autre : les sacrifiés disparaissent pour toujours, le héros renforcé gagne au moins un niveau.",
				"Conseil : renforcez votre meilleur héros en sacrifiant un héros d'une étoile.",
			]
		"tuto_fin":
			return [
				"Le tutoriel est terminé : toute la cité vous est ouverte.",
				"L'or se gagne dans la Tour. L'invocation normale (or) donne surtout des héros d'une étoile ; l'invocation spéciale (gemmes) donne des héros de 3 à 5 étoiles.",
				"Bonne chance, Maître.",
			]
		"invocation":
			return [
				"Chaque héros est unique : deux héros du même nom sont deux personnes différentes.",
				"Les étoiles (1 à 5) disent sa rareté et son niveau maximum. Un héros d'une étoile peut cacher un talent : ne le jugez pas trop vite.",
				"Son caractère (« ? ») se révèle avec le temps. Touchez sa carte dans « Collection » pour voir sa fiche.",
				"Vous pouvez avoir %d héros vivants au plus." % GameData.HERO_LIMIT,
				"Ensuite : « Donjons », puis « Composer les équipes ».",
			]
		"equipe":
			return [
				"Une équipe compte de 1 à %d héros. Vous pouvez en préparer %d à l'avance." % [GameData.TEAM_SIZE, GameData.TEAM_COUNT],
				"Maintenez une carte puis glissez-la dans une place du groupe, ou touchez-la simplement.",
				"Les héros qui combattent ensemble deviennent amis, puis frères d'armes : ils se battent mieux côte à côte.",
				"Les armes de l'arsenal sont prises au départ en mission, et reposées au retour.",
			]
		"etage":
			return [
				"Le combat se joue en direct. Vos héros se débrouillent seuls, mais vous pouvez les guider.",
				"Touchez un héros, puis un endroit pour l'y envoyer, ou un ennemi pour qu'il l'attaque.",
				"« Pause » arrête le temps pour regarder, mais aucun ordre n'est possible pendant la pause.",
				"Lisez bien la quête : l'objectif n'est pas toujours d'éliminer tous les ennemis.",
			]
		"blessure":
			return [
				"Vos héros ont souffert. Les blessures se referment au retour à la cité.",
				"La santé mentale, elle, ne remonte que lentement : environ %d par heure de repos à la cité, un peu moins s'ils travaillent." % roundi(GameData.MENTAL_REST_PER_HOUR),
				"Sous %d, ils se battent moins bien et peuvent refuser vos ordres. À 0, c'est la rupture." % roundi(GameData.MENTAL_MALUS_START),
				"Surveillez la barre sous leur carte, et laissez-les souffler entre deux étages.",
			]
		"mort":
			return [
				"Un héros est mort. C'est définitif : ses armes sont perdues avec lui.",
				"Ceux qui l'ont vu tomber en sont ébranlés, d'autant plus s'ils étaient ses amis ou ses frères d'armes.",
				"Son souvenir reste dans « Collection », bouton « Tombés ».",
				"Ne montez pas plus haut que ce que vos héros peuvent supporter. Un étage déjà conquis peut être refait pour s'entraîner.",
			]
		"batiment":
			return [
				"La cité grandit. Chaque bâtiment ouvre de nouvelles possibilités.",
				"Chaque bâtiment a %d postes d'assistant : bouton « Affectations » du hub." % GameData.POSTS_PER_BUILDING,
				"Un héros au travail regagne un peu moins vite sa santé mentale qu'au repos.",
				"Le bouton « Construction » du hub montre les bâtiments à venir.",
			]
	return []
