extends SceneTree
## Banc de test de la personnalité v2 (cahier, onglet « 1. Paliers », section 9, et « 5. Facettes », section 7).
## Lancer (sans ouvrir le jeu, la sauvegarde n'est pas touchée) :
##   Godot --headless --path . -s res://tools/test_personality.gd
## Vérifie : le tableau de la section 1 (40 000 héros par rareté, à ±10 %), aucun héros plat, au plus deux
## absolus, 3 à 6 tics, les scores et effets dans leurs bornes, les exemples Varek / Sorn / Ilda, le coût de
## l'évolution de 60 à 100, le tirage diversifiant.

const D := preload("res://scripts/game_data/personality_data.gd")
const E := preload("res://scripts/game_data/personality_engine.gd")

var failures := 0


func _initialize() -> void:
	# « -- p1b » : seulement les structures de P1b (rapide).
	if "p1b" in OS.get_cmdline_user_args():
		_check_structures()
		print("")
		print("RÉSULTAT : %s" % ("tout est bon" if failures == 0 else "%d problème(s)" % failures))
		quit(1 if failures > 0 else 0)
		return
	_check_structures()
	_check_distribution()
	_check_facettes_examples()
	_check_evolution()
	_check_effects()
	_check_diversity()
	_check_old_traits()
	_check_migration()
	_check_secret_profiles()
	print("")
	print("RÉSULTAT : %s" % ("tout est bon" if failures == 0 else "%d problème(s)" % failures))
	quit(1 if failures > 0 else 0)


## P1b : les structures de données (8 briques...), à la génération et à la migration.
func _check_structures() -> void:
	print("Structures P1b")
	var fresh := {"id": 1, "name": "Test", "rarity": 3, "persona": E.generate(3, "", [], 42)}
	var mind: Dictionary = fresh["persona"]["mind"]
	_check(mind.keys().size() == 9 and mind["needs"].size() == D.NEEDS.size(), "8 briques à la génération (besoins, pensées, attentes, dissonance, souvenirs, opinions + confiance, adaptation, désirs)")
	_check(mind["expectations"]["rang"] == 60.0, "rang attendu selon les étoiles (3★ : 60)")
	_check(E.need(fresh, "repos") == D.NEED_START and E.opinion(fresh, {"id": 7}) == 0.0, "besoins satisfaits, opinions neutres")
	# Un héros de la version 2 du profil (sans briques) : migrate les ajoute sans rien perdre.
	var old := {"id": 2, "name": "Ancien", "rarity": 5, "persona": E.generate(5, "", [], 43)}
	old["persona"].erase("mind")
	old["persona"]["version"] = 2
	var tiers_before: Dictionary = old["persona"]["tiers"].duplicate()
	E.migrate(old, [old])
	_check(old["persona"].has("mind") and old["persona"]["mind"]["expectations"]["rang"] == 100.0, "migration : briques ajoutées (5★ : rang 100)")
	_check(old["persona"]["tiers"] == tiers_before and old["persona"]["version"] == D.PROFILE_VERSION, "migration : paliers gardés, version du profil à jour")
	E.add_opinion(fresh, old, 150.0)
	_check(E.opinion(fresh, old) == D.OPINION_MAX, "opinion bornée à +100")
	_check_circles()


func _check_circles() -> void:
	print("Cercles")
	# Répartition des rapports à la hiérarchie sur 20 000 héros 3★.
	var counts := {}
	for i in 20000:
		var stance: String = E.generate(3, "", [], 900000 + i)["hierarchy_stance"]
		counts[stance] = counts.get(stance, 0) + 1
	var parts := []
	for stance_id in D.HIERARCHY_STANCES:
		parts.append("%s %.1f %%" % [D.HIERARCHY_STANCES[stance_id]["name"], 100.0 * counts.get(stance_id, 0) / 20000.0])
	print("  rapports à la hiérarchie (3★) : " + ", ".join(parts))
	_check(D.HIERARCHY_STANCES.keys().all(func(s): return counts.get(s, 0) > 400), "chaque rapport à la hiérarchie existe (plus de 2 %)")
	# Un Courtisan : soumis aux forts, dur avec les faibles et les nouveaux.
	var courtier := {"id": 10, "name": "Courtisan", "rarity": 3, "level": 10, "fights": 10, "persona": E.generate(3, "", [], 77)}
	courtier["persona"]["hierarchy_stance"] = "courtisan"
	E.set_tier(courtier, "EMP", 0)
	var strong := {"id": 11, "rarity": 5, "level": 20, "fights": 20}
	var weak := {"id": 12, "rarity": 1, "level": 1, "fights": 10}
	var newcomer := {"id": 13, "rarity": 3, "level": 10, "fights": 0}
	_check(E.circle(courtier, strong) == "plus_fort" and E.circle(courtier, weak) == "plus_faible" and E.circle(courtier, newcomer) == "nouveau",
		"cercles selon le rang perçu et l'ancienneté")
	_check(E.axis(courtier, "EMP", strong) == 40 and E.axis(courtier, "EMP", weak) == -50 and E.axis(courtier, "EMP") == 0,
		"Courtisan : Empathie +40 envers un plus fort, -50 envers un faible, 0 sans cible (exemple du cahier)")
	_check(E.circle(courtier, "maitre") == "maitre" and E.axis(courtier, "EMP", "maitre") == 40, "envers le Maître : comme un plus fort")
	E.add_debt(courtier, weak)
	_check(E.circle(courtier, weak) == "intime", "un sauveur entre dans le cercle Intimes (dette de vie)")
	E.add_opinion(courtier, strong, -80.0)
	_check(E.circle(courtier, strong) == "rival", "opinion très basse : rival")
	_check(E.score(courtier, "obey_strong", strong) != E.score(courtier, "obey_strong"), "score() applique le décalage du cercle")
	_check(not E.is_watched(), "is_watched() : faux tant que les écrans ne le branchent pas (P3)")
	_check_subjects()


## Un héros de test au profil neutre (tous les paliers à 0), avec quelques paliers choisis.
func _plain_hero(id: int, metier := "scribe", tiers := {}) -> Dictionary:
	var hero := {"id": id, "name": "H%d" % id, "rarity": 1, "persona": E.generate(1, metier, [], 5000 + id)}
	for axis_id in D.AXIS_ORDER:
		E.set_tier(hero, axis_id, int(tiers.get(axis_id, 0)))
	return hero


func _check_subjects() -> void:
	print("Sujets et accoutumance")
	var hunter := {"id": 20, "rarity": 2, "persona": E.generate(2, "chasseur", [], 31)}
	_check(E.knowledge(hunter, "monster:loup_noir") == 3 and E.subjects(hunter)["monster:loup_noir"]["prior"], "chasseur : loups connus avant l'invocation (niveau 3)")
	var shepherd := {"id": 21, "rarity": 1, "persona": E.generate(1, "berger", [], 32)}
	_check(E.apprehension(shepherd, "monster:loup_noir") >= 70.0, "berger : connaît les loups et les craint")
	var han := {"id": 22, "name": "Han", "rarity": 1, "secret": true, "persona": E.new_persona("Han", 1, [], true)}
	_check(E.knowledge(han, "synthesis") == 4 and E.apprehension(han, "synthesis") == 0.0, "Han : accoutumance maximale à la synthèse dès le départ")
	var bold := _plain_hero(23, "scribe", {"AUD": 8})
	var careful := _plain_hero(24, "scribe", {"AUD": -8, "OPT": -5})
	_check(E.apprehension(careful, "monster:gobelin") > E.apprehension(bold, "monster:gobelin"), "Prudence et Pessimisme : plus d'appréhension de départ")
	# Un combat facile fait baisser la peur ; un combat dur la fait monter, plus vite.
	var a := _plain_hero(25)
	var start := E.apprehension(a, "monster:gobelin")
	var easy := E.after_encounter(a, "monster:gobelin", {"danger": 0.0, "mode": "fought", "day": 100})
	var b := _plain_hero(26)
	var hard := E.after_encounter(b, "monster:gobelin", {"danger": 100.0, "mode": "fought", "day": 100})
	var drop: float = start - easy["apprehension"]
	var rise: float = hard["apprehension"] - start
	print("  gobelins, départ %.0f : combat facile → %.1f, combat dur → %.1f" % [start, easy["apprehension"], hard["apprehension"]])
	_check(drop > 0.0 and rise > 0.0 and rise / (100.0 - start) > drop / start, "la peur monte plus vite qu'elle ne baisse")
	var steady := _plain_hero(27, "scribe", {"STA": 8})
	var fragile := _plain_hero(28, "scribe", {"STA": -8})
	var s1 := E.after_encounter(steady, "monster:gobelin", {"danger": 0.0, "mode": "fought", "day": 100})
	var s2 := E.after_encounter(fragile, "monster:gobelin", {"danger": 0.0, "mode": "fought", "day": 100})
	_check(s1["apprehension"] < s2["apprehension"], "Stabilité : la peur baisse plus vite")
	var watcher := _plain_hero(29)
	E.after_encounter(watcher, "monster:gobelin", {"danger": 0.0, "mode": "watched", "day": 100})
	_check(E.apprehension(watcher, "monster:gobelin") > easy["apprehension"], "regarder apprend moins que combattre (40 %)")
	# Retour spontané et renouvellement.
	_check(E.apprehension(a, "monster:gobelin", {"day": 110}) > E.apprehension(a, "monster:gobelin", {"day": 101}), "absence de 7 jours : une partie de la peur revient")
	_check(E.apprehension(a, "monster:gobelin", {"day": 101, "setting": "nuit"}) > E.apprehension(a, "monster:gobelin", {"day": 101}), "la nuit (cadre nouveau) : la peur remonte")
	# Connaissance : plafonds selon la façon d'apprendre.
	var fighter := _plain_hero(30)
	var spectator := _plain_hero(31)
	for i in 60:
		E.after_encounter(fighter, "monster:loup_noir", {"danger": 30.0, "mode": "fought", "hits": 3, "dodges": 2, "day": 100})
		E.after_encounter(spectator, "monster:loup_noir", {"danger": 30.0, "mode": "watched", "day": 100})
	_check(E.knowledge(fighter, "monster:loup_noir") == 4 and E.knowledge(spectator, "monster:loup_noir") == 3, "niveau 4 seulement sur le terrain ; en regardant : 3 au plus")
	_check(not E.pending_report(fighter).is_empty(), "ce qu'il a appris attend d'être écrit (pending_report)")
	# Événement grave : cicatrice chez un Vulnérable, haine chez un Colérique.
	var scars := 0
	for i in 200:
		var v := _plain_hero(100 + i, "scribe", {"STA": -7})
		if E.after_encounter(v, "monster:chef_gobelin", {"danger": 100.0, "mode": "fought", "grave": true, "day": 100})["scar"]:
			scars += 1
	var angry := _plain_hero(32, "scribe", {"COL": 7})
	_check(scars > 30 and scars < 90, "Vulnérable : cicatrice possible après un événement grave (%d / 200)" % scars)
	_check(E.after_encounter(angry, "monster:chef_gobelin", {"danger": 100.0, "mode": "fought", "grave": true, "day": 100})["hate"], "Colérique : haine de ce sujet")
	# Transmission au lobby.
	var kind_teacher := _plain_hero(33, "scribe", {"EMP": 8})
	var cold_teacher := _plain_hero(34, "scribe", {"EMP": -8})
	for teacher in [kind_teacher, cold_teacher]:
		E.learn_subject(teacher, "monster:golem", 1000.0, 4)
	var l1 := _plain_hero(35)
	var l2 := _plain_hero(36)
	var distrustful := _plain_hero(37, "scribe", {"LOY": -7})
	E.share_knowledge(kind_teacher, l1)
	E.share_knowledge(cold_teacher, l2)
	var learned := func(h): return E.knowledge(h, "monster:golem") * 1000.0 + E.subjects(h)["monster:golem"]["progress"]
	_check(learned.call(l1) > learned.call(l2), "l'Empathique explique mieux")
	_check(E.share_knowledge(kind_teacher, distrustful).is_empty() and E.knowledge(distrustful, "monster:golem") == 0, "le Méfiant n'écoute pas")
	for i in 20:
		E.share_knowledge(kind_teacher, l1)
	_check(E.knowledge(l1, "monster:golem") == D.KNOWLEDGE_CAP["lobby"], "au lobby : niveau 2 au plus")
	_check_library()


func _check_library() -> void:
	print("Bibliothèque")
	var L = load("res://scripts/game_data/library.gd")
	var library: Dictionary = L.new_library()
	var scout := _plain_hero(40, "scribe")
	var gloomy := _plain_hero(41, "paysan", {"OPT": -8})
	for h in [scout, gloomy]:
		E.learn_subject(h, "monster:liche", 1000.0, 4, 30.0)
		E.after_encounter(h, "monster:liche", {"danger": 90.0, "mode": "fought", "day": 100})
	var written: Array = L.deposit(library, scout)
	var card: Dictionary = library["bestiary"]["monster:liche"]
	_check(not written.is_empty() and E.pending_report(scout).is_empty(), "le rapport est consigné, puis vidé")
	_check(not card["verified"] and card["knowledge"] == 4 and not card["told"], "un seul auteur : non vérifiée ; un scribe l'écrit lui-même")
	var danger_one: float = card["danger"]
	L.deposit(library, gloomy)
	_check(card["verified"] and card["told"], "un second héros la confirme : vérifiée ; un paysan illettré la raconte")
	_check(card["danger"] > danger_one, "le Pessimiste surestime le danger")
	var reader := _plain_hero(42)
	for i in 30:
		L.study(library, reader, "monster:liche")
	var reader2 := _plain_hero(43)
	for i in 30:
		L.study(library, reader2, "monster:liche", true)
	_check(E.knowledge(reader, "monster:liche") == 2 and E.knowledge(reader2, "monster:liche") == 3, "étude : niveau 2 au plus, 3 avec un bibliothécaire")
	var calm := _plain_hero(44)
	var fragile := _plain_hero(45, "scribe", {"STA": -7})
	var before_calm := E.apprehension(calm, "monster:liche")
	var before_fragile := E.apprehension(fragile, "monster:liche")
	L.study(library, calm, "monster:liche")
	L.study(library, fragile, "monster:liche")
	_check(E.apprehension(calm, "monster:liche") < before_calm and E.apprehension(fragile, "monster:liche") > before_fragile,
		"la lecture rassure, mais un récit d'horreur inquiète un Vulnérable")
	L.set_skill_state(library, "Résistance au feu", "rumeur", {"id": 40, "name": "H40"})
	L.set_skill_state(library, "Résistance au feu", "piste", {"id": 41, "name": "H41"}, {"activite": "s'exposer au feu"})
	var skill: Dictionary = L.skill_entry(library, "Résistance au feu")
	_check(skill["state"] == "piste" and not skill["verified"] and skill["authors"].size() == 2, "registre des compétences : rumeur puis piste, non vérifiée")
	L.set_skill_state(library, "Résistance au feu", "verifiee")
	_check(L.skill_entry(library, "Résistance au feu")["verified"], "méthode vérifiée")


func _check(ok: bool, text: String) -> void:
	print(("  ok   " if ok else "  ÉCHEC ") + text)
	if not ok:
		failures += 1


## Section 1 : axes à ±50, ±70, part des héros à ±90 et à ±100, héros plats.
func _check_distribution() -> void:
	print("Répartition (40 000 héros par rareté)")
	# [rareté, secret, axes >= 50, axes >= 70, 1 héros sur N a un axe >= 90, 1 sur N a un axe à 100]
	var targets := [[1, false, 3.6, 0.7, 14.0, 67.0], [3, false, 4.0, 1.0, 8.0, 36.0], [5, false, 5.2, 1.6, 4.0, 14.0],
		[0, true, 6.5, 2.3, 2.0, 7.0]]
	var n := 40000  # (le cahier dit 20 000 ; à 20 000, la colonne « 100 » des 1★ varie de ±6 % par simple hasard)
	for target in targets:
		var rarity: int = target[0] if target[0] > 0 else 5
		var at50 := 0
		var at70 := 0
		var with90 := 0
		var with100 := 0
		var flat := 0
		var over_cap := 0
		var bad_tics := 0
		var near_zero := 0
		var bad_scores := 0
		for i in n:
			var persona := E.generate(rarity, "", [], i + 1 + rarity * 1000003, target[1])
			var hero := {"persona": persona}
			var c50 := 0
			var c60 := 0
			var c90 := 0
			var has100 := false
			for axis_id in D.AXIS_ORDER:
				var t: int = absi(persona["tiers"][axis_id])
				if t >= 5: c50 += 1
				if t >= 6: c60 += 1
				if t >= 7: at70 += 1
				if t >= 9: c90 += 1
				if t == 10: has100 = true
				if t <= 1: near_zero += 1
			at50 += c50
			if c90 > 0: with90 += 1
			if has100: with100 += 1
			if c50 < 3 or c60 < 1: flat += 1
			if c90 > 2 and not target[1]: over_cap += 1
			if persona["tics"].size() < 3 or persona["tics"].size() > 6: bad_tics += 1
			if i < 500:
				for behaviour in D.BEHAVIOURS:
					var s := E.score(hero, behaviour)
					if s < -100.0 or s > 100.0: bad_scores += 1
		var label := "secret" if target[1] else "%d★" % rarity
		var a50 := float(at50) / n
		var a70 := float(at70) / n
		var one_in_90 := float(n) / maxf(1.0, with90)
		var one_in_100 := float(n) / maxf(1.0, with100)
		print("  %s : >=50 %.2f (cible %.1f), >=70 %.2f (cible %.1f), >=90 1 sur %.1f (cible %d), 100 1 sur %.1f (cible %d), entre -10 et +10 : %.0f %%" \
			% [label, a50, target[2], a70, target[3], one_in_90, target[4], one_in_100, target[5], 100.0 * near_zero / (n * 18.0)])
		_check(absf(a50 / target[2] - 1.0) <= 0.10, "%s : axes à ±50 à 10 %% près" % label)
		_check(absf(a70 / target[3] - 1.0) <= 0.10, "%s : axes à ±70 à 10 %% près" % label)
		# Ligne « Secret (si généré) » : information seulement (ses deux dernières colonnes ne peuvent pas être
		# atteintes ensemble avec ce modèle, et les héros secrets auront des profils écrits à la main).
		if not target[1]:
			_check(absf(one_in_90 / target[4] - 1.0) <= 0.10, "%s : héros à ±90 à 10 %% près" % label)
			_check(absf(one_in_100 / target[5] - 1.0) <= 0.10, "%s : héros à ±100 à 10 %% près" % label)
		_check(flat == 0, "%s : aucun héros plat (%d)" % [label, flat])
		_check(over_cap == 0, "%s : au plus deux axes à ±90 (%d)" % [label, over_cap])
		_check(bad_tics == 0, "%s : 3 à 6 tics" % label)
		_check(bad_scores == 0, "%s : scores entre -100 et +100" % label)


## Facettes, section 3 : Varek, Sorn et Ilda (poids personnels neutres).
func _check_facettes_examples() -> void:
	print("Exemples de l'onglet Facettes")
	var heroes := {
		"Varek": [-35, 20, -70, -20, 55, 80, -85, -90, 65, -40, -30, 45, 10, -15, 20, 30, 60, 40],
		"Sorn": [60, 10, 30, 50, -20, -70, -85, -90, 65, -40, 20, -60, 20, 50, 30, -20, -30, -20],
		"Ilda": [-35, 20, 20, -20, 55, 80, -85, -90, 65, 80, -30, 45, 10, -15, 20, 30, 60, 40],
	}
	# [envie de trahir, capacité, dette] annoncés par le cahier
	var expected := {"Varek": [56, 55, -42], "Sorn": [45, -15, -37], "Ilda": [30, 54, -5]}
	for hero_name in heroes:
		# Les valeurs du cahier (onglet écrit avant les paliers) sont arrondies au palier : petit écart permis.
		var hero := {"persona": {"tiers": {}, "weights": {}}}
		for i in D.AXIS_ORDER.size():
			hero["persona"]["tiers"][D.AXIS_ORDER[i]] = roundi(heroes[hero_name][i] / 10.0)
		var got := [E.score(hero, "betray_wish"), E.score(hero, "betray_skill"), E.score(hero, "life_debt")]
		print("  %s : envie %.0f (cahier %d), capacité %.0f (%d), dette %.0f (%d)" \
			% [hero_name, got[0], expected[hero_name][0], got[1], expected[hero_name][1], got[2], expected[hero_name][2]])
		for k in 3:
			_check(absf(got[k] - expected[hero_name][k]) <= 6.0, "%s : score %d proche du cahier" % [hero_name, k + 1])


## Section 8 : 60 → 100 coûte 225 points (25 + 40 + 60 + 100) ; revenir vers zéro coûte 10.
func _check_evolution() -> void:
	print("Évolution")
	var hero := {"persona": E.generate(3, "", [], 42)}
	E.set_tier(hero, "PER", 0)
	E.set_tier(hero, "STA", 6)
	var crossings := E.gain_evolution(hero, "STA", 224.0 / 2.0)  # humeur : x2
	_check(E.tier(hero, "STA") == 9, "Stabilité 60 + 224 points : palier 90 (%d)" % E.tier(hero, "STA"))
	crossings = E.gain_evolution(hero, "STA", 1.0 / 2.0)
	_check(E.tier(hero, "STA") == 10, "un point de plus : 100 (%d)" % E.tier(hero, "STA"))
	_check(not crossings.is_empty() and "eveil_stabilite" in crossings[0]["opened"], "l'éveil de la Stabilité s'ouvre")
	E.gain_evolution(hero, "STA", -10.0 / 2.0)
	_check(E.tier(hero, "STA") == 9, "revenir vers zéro coûte 10 (%d)" % E.tier(hero, "STA"))
	_check(not "eveil_stabilite" in E.accesses(hero), "l'éveil se referme")
	# Acharnement : à Persévérance 60, x1,05^6.
	E.set_tier(hero, "PER", 6)
	_check(absf(E.acharnement(hero) - pow(1.05, 6)) < 0.0001, "acharnement x1,05 par palier de Persévérance")
	E.set_tier(hero, "AUD", 0)
	E.gain_evolution(hero, "AUD", 50.0)  # tempérament : x0,1 → 5 points
	_check(E.tier(hero, "AUD") == 0, "le tempérament bouge à peine (%d)" % E.tier(hero, "AUD"))


## Section 5 : les fonctions d'effet et leurs bornes.
func _check_effects() -> void:
	print("Fonctions d'effet")
	_check(is_equal_approx(E.effect_add(20.0, -3.0, 10), -10.0), "additionner : 20 - 3 x 10 = -10")
	_check(is_equal_approx(E.effect_add(20.0, -3.0, 10, 0.0, 100.0), 0.0), "additionner borné à 0")
	_check(absf(E.effect_mul(1.0, 0.04, 10) - 1.4802) < 0.001, "multiplier : x1,04^10 = 1,48")
	_check(absf(E.effect_mul(1.0, 0.04, -10) - 0.6756) < 0.001, "multiplier : x1,04^-10 = 0,68")
	_check(is_equal_approx(E.effect_div(1.0, 0.06, 10), 1.0 / 1.6), "diviser : /1,6 à 100")
	_check(is_equal_approx(E.effect_div(1.0, 0.06, -10), 1.0 / 1.6), "diviser : la valeur absolue compte")
	_check(is_equal_approx(E.effect_cross(6, 7), 42.0), "croiser : 6 x 7")
	_check(is_equal_approx(E.effect_ratio(6, 7), 0.75), "rapporter : 6 / (1 + 7)")
	_check(is_equal_approx(E.effect_ratio(6, -3), 6.0), "rapporter : une force négative compte pour 0")
	var hero := {"persona": E.generate(2, "", [], 7)}
	_check(E.modifier("fear_chance", hero) == 1.0, "modifier() neutre")
	_check(E.decide(hero, ["a", "b"]) == "a", "decide() : la première option")
	_check(E.decide(hero, ["a", "b"], {"default": "b"}) == "b", "decide() : l'option par défaut")
	for composite_id in D.COMPOSITES:
		var value := E.composite(hero, composite_id)
		_check(value >= -100 and value <= 100 and value % 10 == 0, "composite %s : %d" % [composite_id, value])


## L'ancien tirage des traits (avant la sauvegarde version 4), recopié ici pour comparer : 1 trait au hasard,
## et 40 % de chances d'un deuxième, jamais Courageux avec Lâche.
func _old_roll_traits() -> Array:
	var names: Array = D.OLD_TRAITS.keys()
	var first: String = names.pick_random()
	var traits := [first]
	if randf() < 0.4:
		var others := names.filter(func(n): return n != first and not (n in ["Courageux", "Lâche"] and first in ["Courageux", "Lâche"]))
		traits.append(others.pick_random())
	return traits


## Section 12 : fréquence de chaque ancien trait, avant (tiré à part) et après (lu sur les paliers).
func _check_old_traits() -> void:
	print("Anciens traits : part des héros qui l'ont, avant → après (40 000 héros par rareté)")
	var n := 40000
	var before := {}
	for i in n:
		for trait_name in _old_roll_traits():
			before[trait_name] = before.get(trait_name, 0) + 1
	for rarity in [1, 2, 3, 4, 5]:
		var after := {}
		var none := 0
		var count_total := 0
		for i in n:
			var hero := {"persona": E.generate(rarity, "", [], 900000 + i + rarity * 1000003)}
			var traits := E.old_traits(hero)
			count_total += traits.size()
			if traits.is_empty():
				none += 1
			for trait_name in traits:
				after[trait_name] = after.get(trait_name, 0) + 1
		var parts := []
		for trait_name in D.OLD_TRAITS:
			parts.append("%s %.1f → %.1f %%" % [trait_name, 100.0 * before.get(trait_name, 0) / n, 100.0 * after.get(trait_name, 0) / n])
		print("  %d★ : %s" % [rarity, ", ".join(parts)])
		print("       traits par héros : 1,4 → %.2f ; sans aucun trait : 0 → %.1f %%" % [float(count_total) / n, 100.0 * none / n])
	# Les incompatibilités tiennent d'elles-mêmes : Courage ne peut pas être à la fois >= 50 et <= -50.
	var both := 0
	for i in 5000:
		var hero := {"persona": E.generate(3, "", [], 70000 + i)}
		if E.has_old_trait(hero, "Courageux") and E.has_old_trait(hero, "Lâche"):
			both += 1
	_check(both == 0, "jamais Courageux et Lâche à la fois")


## Migration (sauvegarde version 4) : chaque ancien trait est gardé, paliers poussés juste au seuil.
func _check_migration() -> void:
	print("Migration des anciens traits")
	var kept := 0
	var legacy := 0
	var heroes := 0
	var moved_axes := 0
	var moved_tiers := 0
	for i in 20000:
		var old := _old_roll_traits()
		var hero := {"name": "T", "rarity": 1 + i % 5, "persona": E.generate(1 + i % 5, "", [], 400000 + i),
			"traits": old.map(func(n): return {"name": n, "known": i % 3 == 0})}
		var before: Dictionary = hero["persona"]["tiers"].duplicate()
		E.migrate(hero, [])
		heroes += 1
		var all_kept := true
		for trait_name in old:
			if not E.has_old_trait(hero, trait_name):
				all_kept = false
		if all_kept:
			kept += 1
		legacy += hero["persona"]["legacy_traits"].size()
		for axis_id in D.AXIS_ORDER:
			var gap := absi(int(hero["persona"]["tiers"][axis_id]) - int(before[axis_id]))
			if gap > 0:
				moved_axes += 1
				moved_tiers += gap
		if i % 3 == 0 and hero["revealed_traits"].size() != old.size():
			all_kept = false
		if hero.has("traits"):
			all_kept = false
	_check(kept == heroes, "chaque héros garde tous ses anciens traits (%d / %d)" % [kept, heroes])
	print("  axes poussés par héros : %.2f (de %.1f paliers en moyenne) ; traits gardés hors profil : %.2f %% des héros" \
		% [float(moved_axes) / heroes, float(moved_tiers) / maxf(1, moved_axes), 100.0 * legacy / heroes])
	# Protecteur et Querelleur : l'Empathie ne peut pas être >= 50 et <= 20 ; l'un des deux est gardé à part.
	var hero := {"name": "T", "rarity": 1, "persona": E.generate(1, "", [], 5),
		"traits": [{"name": "Protecteur", "known": true}, {"name": "Querelleur", "known": false}]}
	E.migrate(hero, [])
	_check(E.has_old_trait(hero, "Protecteur") and E.has_old_trait(hero, "Querelleur"), "Protecteur + Querelleur : les deux gardés (%s hors profil)" % [hero["persona"]["legacy_traits"]])
	_check(hero["revealed_traits"] == ["Protecteur"], "drapeau « révélé » gardé par nom")


## Section 11 : les profils des héros secrets.
func _check_secret_profiles() -> void:
	print("Héros secrets")
	for hero_name in D.SECRET_PROFILES:
		var hero := {"name": hero_name, "secret": true, "rarity": 1, "persona": E.new_persona(hero_name, 1, [], true)}
		var same := true
		for axis_id in D.AXIS_ORDER:
			if E.tier(hero, axis_id) != int(D.SECRET_PROFILES[hero_name]["tiers"].get(axis_id, 0)):
				same = false
		_check(same and E.metier(hero) == "", "%s : paliers du cahier, pas de métier" % hero_name)
		print("    traits %s ; effort %.0f ; accès %d" % [E.old_traits(hero), hero["persona"]["effort"], E.accesses(hero).size()])
	# Un héros secret déjà possédé (profil tiré, anciens traits) prend son profil à la migration.
	var han := {"name": "Han", "secret": true, "rarity": 1, "persona": E.generate(1, "", [], 3, true),
		"traits": [{"name": "Querelleur", "known": true}]}
	E.migrate(han, [])
	_check(E.tier(han, "PER") == 9 and han["persona"].get("secret_profile", false), "Han déjà possédé : profil écrit à la main")
	_check(not E.has_old_trait(han, "Querelleur") and han["revealed_traits"] == ["Querelleur"], "Han : ses anciens traits tirés au hasard ne comptent plus (drapeau gardé)")


## Tirage diversifiant : un lobby de clones ; le nouveau héros doit s'en éloigner plus qu'un tirage simple.
func _check_diversity() -> void:
	print("Tirage diversifiant")
	var lobby := []
	for i in 30:
		lobby.append({"alive": true, "persona": E.generate(1, "", [], 1000 + i)})
	var with_lobby := 0.0
	var without := 0.0
	for i in 300:
		with_lobby += E._lobby_distance(E.generate(1, "", lobby, 5000 + i)["tiers"], lobby.map(func(h): return h["persona"]["tiers"]))
		without += E._lobby_distance(E.generate(1, "", [], 5000 + i)["tiers"], lobby.map(func(h): return h["persona"]["tiers"]))
	print("  distance moyenne au plus proche : %.0f avec le tirage diversifiant, %.0f sans" % [with_lobby / 300.0, without / 300.0])
	_check(with_lobby > without, "le tirage diversifiant éloigne le nouveau héros du lobby")
	var metiers := {}
	for i in 2000:
		var m: String = E.roll_metier(1)
		metiers[m] = metiers.get(m, 0) + 1
	var combat := 0
	for m in metiers:
		if D.METIERS[m]["combat"] >= 2:
			combat += metiers[m]
	print("  1★ : %.0f %% de métiers liés au combat" % (100.0 * combat / 2000.0))
	combat = 0
	for i in 2000:
		if D.METIERS[E.roll_metier(5)]["combat"] >= 2:
			combat += 1
	print("  5★ : %.0f %% de passés liés au combat" % (100.0 * combat / 2000.0))
