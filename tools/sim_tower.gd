extends Node
## Simulateur de la Tour (mesures d'équilibre de CLAUDE.md), sans ordres du Maître et sans potions.
## Lancer (la scène charge GameData, donc la sauvegarde locale : en faire une copie avant, et la remettre
## après, car GameData peut la réécrire au lancement) :
##   Godot --headless --path . res://tools/sim_tower.tscn -- etages=1,2,3,4 combats=200 equipe=brute graine=1
## « equipe » : brute (équipe du tutoriel, 3★ + 2★ + 3 x 1★, au niveau des monstres de l'étage) ou preparee
## (2 niveaux de plus, épée et bouclier de grade D, arc D pour les archers).
## Affiche, par étage : victoires (%), morts par combat, et les anciens traits présents dans les équipes.

const TRAIT_NAMES := ["Courageux", "Lâche", "Loyal", "Paresseux", "Querelleur", "Protecteur", "Ambitieux", "Mauvais", "Meneur"]


func _ready() -> void:
	var args := {"etages": "1,2,3,4,5", "combats": "200", "equipe": "brute", "graine": "1"}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=")
		if parts.size() == 2:
			args[parts[0]] = parts[1]
	seed(int(args["graine"]))
	Settings.dev_mode = false  # (pas enregistré)
	GameData.warehouse = {}    # pas de potions
	GameData.roster.clear()    # lobby vide : le tirage diversifiant ne compare pas les héros à ceux de la sauvegarde
	var prepared: bool = args["equipe"] == "preparee"
	for floor_text in args["etages"].split(","):
		var floor_number := int(floor_text)
		var count := int(args["combats"])
		var wins := 0
		var deaths := 0
		var trait_counts := {}
		var with_trait := {}  # {trait: [combats où l'équipe l'a, victoires]}
		for i in count:
			GameData.arsenal = []
			var team := _make_team(floor_number, prepared)
			var present := {}
			for hero in team:
				for trait_name in TRAIT_NAMES:
					if GameData.has_trait(hero, trait_name):
						trait_counts[trait_name] = trait_counts.get(trait_name, 0) + 1
						present[trait_name] = true
			var battle := Battle.new(team, GameData.tower_enemies(floor_number), GameData.floor_quest(floor_number))
			battle.run()
			if battle.victory:
				wins += 1
			for trait_name in present:
				var entry: Array = with_trait.get(trait_name, [0, 0])
				entry[0] += 1
				entry[1] += 1 if battle.victory else 0
				with_trait[trait_name] = entry
			deaths += battle.heroes.filter(func(f): return _is_dead(f)).size()
		var trait_parts := []
		for trait_name in TRAIT_NAMES:
			trait_parts.append("%s %.2f" % [trait_name, trait_counts.get(trait_name, 0) / float(count)])
		print("RESULTAT equipe=%s etage=%d combats=%d victoires=%.1f%% morts=%.2f traits_par_equipe: %s" \
			% [args["equipe"], floor_number, count, 100.0 * wins / count, float(deaths) / count, ", ".join(trait_parts)])
		# Victoires selon que l'équipe a le trait ou non (pour trouver ce qui pèse sur l'équilibre).
		var split_parts := []
		for trait_name in TRAIT_NAMES:
			var entry: Array = with_trait.get(trait_name, [0, 0])
			var without: int = count - entry[0]
			split_parts.append("%s avec %.0f%% (%d) sans %.0f%%" % [trait_name, 100.0 * entry[1] / maxf(1, entry[0]), entry[0],
				100.0 * (wins - entry[1]) / maxf(1, without)])
		print("  victoires selon le trait : ", ", ".join(split_parts))
	get_tree().quit()


## Mort pour de bon à la fin du combat (Battle._die note « killer » ; un immortel est seulement à terre).
func _is_dead(fighter: Dictionary) -> bool:
	return fighter.get("killer", "") != "" and not fighter["immortal"]


func _make_team(floor_number: int, prepared: bool) -> Array:
	var team := []
	var level := GameData.floor_enemy_level(floor_number) + (2 if prepared else 0)
	for rarity in [3, 2, 1, 1, 1]:
		var hero: Dictionary = GameData._create_hero(rarity)
		while hero["level"] < level and not GameData.is_max_level(hero):
			GameData.gain_xp(hero, GameData.xp_to_next(hero["level"]) - hero["xp"])
		if prepared and not GameData.uses_magic(hero):
			if hero["class"] == "Archer":
				_give(hero, "Arc")
			else:
				_give(hero, "Épée")
				_give(hero, "Bouclier")
		team.append(hero)
	return team


func _give(hero: Dictionary, type: String) -> void:
	GameData.arsenal.append({"id": GameData.arsenal.size() + 1, "type": type, "grade": "D", "owner": hero["id"]})
