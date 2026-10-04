class_name SystemTips
## Textes des conseils du Système : une fenêtre « Conseil » la première fois que le Maître fait quelque chose,
## comme dans l'œuvre. Qui les demande : GameData.show_tip (game_state.gd) ; qui les affiche : main.gd.
## Les chiffres viennent de GameData, pour rester justes si on les change.


## Titre de la fenêtre.
static func title(tip_id: String) -> String:
	if tip_id == "bienvenue":
		return "Bienvenue, Maître"
	return "Conseil"


## Les lignes de la fenêtre (une ligne = un paragraphe centré).
static func lines(tip_id: String) -> Array:
	match tip_id:
		"bienvenue":
			return [
				"Le Système vous a choisi comme Maître de cette cité suspendue dans le néant.",
				"Votre mission : invoquer des héros, les mener dans la Tour et la gravir, étage par étage.",
				"Attention : un héros qui tombe au combat meurt pour toujours. Rien ne le ramènera.",
				"Pour commencer : l'onglet « Invocation ». L'invocation spéciale se paie en gemmes ; l'invocation normale en or, que vous gagnerez dans la Tour.",
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
