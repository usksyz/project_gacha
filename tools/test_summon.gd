extends SceneTree
## Banc de test des taux d'invocation (prompt 1, économie).
## GameData démarre même avec -s (il relit et réécrit la sauvegarde) : le lancer dans une COPIE du projet
## (worktree git + override.cfg, voir CLAUDE.md, P1a-bis), jamais dans le dépôt :
##   Godot --headless --path <copie> -s res://tools/test_summon.gd [-- tirages=1000000]
## Pour chaque sorte d'invocation : taux réels par rang. Invocation spéciale : nombre moyen de tirages par
## 5 étoiles (attendu : environ 62), part des mages (0,5 %), et vérifie qu'aucune série ne dépasse 90 tirages
## sans 5 étoiles ni 10 sans 4 étoiles ou mieux. Les tirages se font sur GameData sans sauvegarder.

var failures := 0
var started := false


func _process(_delta: float) -> bool:
	# Les autoloads (GameData) sont prêts à la première image, pas dans _initialize.
	if started:
		return true
	started = true
	var game_data: Node = root.get_node("GameData")
	var pulls := 1000000
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("tirages="):
			pulls = int(arg.get_slice("=", 1))
	_check_normal(game_data, pulls)
	_check_special(game_data, pulls)
	print("")
	print("RÉSULTAT : %s" % ("tout est bon" if failures == 0 else "%d problème(s)" % failures))
	quit(1 if failures > 0 else 0)
	return true


func _check_normal(game_data: Node, pulls: int) -> void:
	print("Invocation normale (%d tirages)" % pulls)
	var counts := {1: 0, 2: 0, 3: 0}
	for i in pulls:
		counts[game_data._roll_rarity("normal")] += 1
	var rates: Dictionary = game_data.SUMMON_TYPES["normal"]["rates"]
	for rarity in [3, 2, 1]:
		var real: float = counts[rarity] / float(pulls)
		var expected: float = rates[rarity]
		print("  %d★ : %.3f %% (attendu %.3f %%)" % [rarity, real * 100.0, expected * 100.0])
		# Écart toléré : 5 écarts-types du tirage (loi binomiale).
		var sigma := sqrt(expected * (1.0 - expected) / pulls)
		_check(absf(real - expected) < 5.0 * sigma + 1e-6, "taux du %d★ conforme" % rarity)


func _check_special(game_data: Node, pulls: int) -> void:
	print("Invocation spéciale (%d tirages)" % pulls)
	game_data.pity_counter = 0
	game_data.pity4_counter = 0
	var counts := {3: 0, 4: 0, 5: 0}
	var mages := 0
	var since_five := 0
	var since_four := 0
	var longest_five := 0
	var longest_four := 0
	var fives := 0
	var five_series_total := 0  # somme des longueurs de série (5★ compris) jusqu'à chaque 5★
	for i in pulls:
		var rarity: int = game_data._roll_rarity("special")
		if game_data._roll_class(rarity, true) == "Mage":
			mages += 1
		counts[rarity] += 1
		since_five += 1
		since_four += 1
		if rarity == 5:
			fives += 1
			five_series_total += since_five
			longest_five = maxi(longest_five, since_five)
			since_five = 0
		if rarity >= 4:
			longest_four = maxi(longest_four, since_four)
			since_four = 0
	for rarity in [5, 4, 3]:
		print("  %d★ : %.3f %%" % [rarity, counts[rarity] * 100.0 / pulls])
	var mean := five_series_total / float(maxi(1, fives))
	print("  tirages par 5★ : %.2f en moyenne (taux réel %.3f %%, calculé %.3f %%)" % [mean, 100.0 / mean,
		game_data.five_star_real_rate() * 100.0])
	print("  plus longue série : %d tirages pour un 5★, %d pour un 4★ ou mieux" % [longest_five, longest_four])
	print("  mages : %.3f %% (attendu %.3f %%)" % [mages * 100.0 / pulls, game_data.MAGE_CHANCE * 100.0])
	_check(absf(mean - 62.0) < 1.5, "environ 62 tirages par 5★")
	_check(longest_five <= game_data.PITY5_LIMIT, "jamais plus de 90 tirages sans 5★")
	_check(longest_four <= game_data.PITY4_LIMIT, "jamais plus de 10 tirages sans 4★ ou mieux")
	_check(absf(mages / float(pulls) - game_data.MAGE_CHANCE) < 0.0006, "part des mages : 0,5 %")
	# Les compteurs continuent d'une x1 à une x10 : une série coupée en morceaux donne la même garantie.
	game_data.pity_counter = game_data.PITY5_LIMIT - 1
	_check(game_data._roll_rarity("special") == 5 and game_data.pity_counter == 0, "le 90e tirage donne un 5★")
	game_data.pity4_counter = game_data.PITY4_LIMIT - 1
	game_data.pity_counter = 0
	_check(game_data._roll_rarity("special") >= 4 and game_data.pity4_counter == 0, "le 10e tirage donne un 4★ ou mieux")


func _check(ok: bool, text: String) -> void:
	print("  [%s] %s" % ["ok" if ok else "ÉCHEC", text])
	if not ok:
		failures += 1
