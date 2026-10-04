class_name GameTraining
extends GamePersonality
## Le terrain d'entraînement : il s'ouvre après assez d'armes tirées, et les héros inscrits y
## apprennent des compétences au fil du temps réel, même jeu fermé.
## Fait partie de la pile de GameData (voir game_data.gd).


# ---------------------------------------------------------------------------
# Terrain d'entraînement
# ---------------------------------------------------------------------------
# Un héros affecté au terrain travaille une compétence (hero["training"], vide = au repos).
# Toutes les TRAINING_SESSION_SECONDS secondes de temps réel, il fait une séance, même si le jeu
# est fermé : au retour, on compte les séances écoulées depuis hero["training_since"].
# L'entraînement ne donne ni statistiques ni niveau, seulement des compétences.
# Un héros qui monte dans la Tour quitte le terrain le temps de l'étage (il garde sa place et
# son programme) : le temps passé dans la Tour ne compte pas, et il reprend l'entraînement après.
# Plus tard : le temps du lobby ira 3 fois plus vite que le temps réel, et les héros iront
# d'eux-mêmes au terrain d'entraînement.

## Le terrain d'entraînement vient de se construire tout seul (assez d'armes tirées) : on l'annonce.
func _announce_training_ground() -> void:
	facility_completed.emit("Construction terminée", [
		"Le terrain d'entraînement a été construit avec succès !",
		"Tes héros peuvent y apprendre des compétences, même quand le jeu est fermé.",
	])
	show_tip("batiment")  # premier bâtiment : conseil du Système, après la fenêtre


## Vrai quand le terrain d'entraînement est ouvert (assez d'armes tirées).
func training_unlocked() -> bool:
	return weapon_draws >= TRAINING_UNLOCK_DRAWS


## Les héros vivants inscrits au terrain d'entraînement (y compris ceux partis dans la Tour).
func trainees() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for hero in alive_heroes():
		if hero.get("training", "") != "":
			result.append(hero)
	return result


## Affecte un héros à un programme d'entraînement (« » = le renvoyer au repos).
## Renvoie faux si toutes les places du terrain sont prises, ou si le héros refuse (rupture, Paresseux :
## la raison est alors dans last_refusal, voir personality.gd).
func set_training(hero: Dictionary, skill_name: String) -> bool:
	last_refusal = ""
	var already: bool = hero.get("training", "") != ""
	if skill_name != "" and not already and trainees().size() >= TRAINING_SLOTS:
		return false
	if skill_name != "" and not already and not accepts_work(hero):
		return false
	update_training()  # les séances déjà faites dans l'ancien programme sont comptées
	hero["training"] = skill_name
	if skill_name != "":
		hero["post"] = ""  # un héros ne travaille qu'à un endroit à la fois
	hero["training_since"] = Time.get_unix_time_from_system()
	save_game()
	return true


## Secondes avant la prochaine séance d'un héros à l'entraînement.
func seconds_to_next_session(hero: Dictionary) -> int:
	var elapsed: float = Time.get_unix_time_from_system() - hero.get("training_since", 0.0)
	return maxi(0, ceili(TRAINING_SESSION_SECONDS - elapsed))


## Compte les séances terminées depuis la dernière fois et donne les points de progrès.
## Les nouveautés s'ajoutent à training_news, en attendant d'être annoncées au joueur.
func update_training() -> void:
	var now := Time.get_unix_time_from_system()
	var changed := false
	for hero in trainees():
		if is_away(hero):
			continue  # dans la Tour ou au donjon journalier : pas d'entraînement pendant ce temps
		var since: float = hero.get("training_since", now)
		if since > now:
			since = now  # l'horloge de l'appareil a reculé
		var sessions := int((now - since) / TRAINING_SESSION_SECONDS)
		if sessions <= 0:
			continue
		hero["training_since"] = since + sessions * TRAINING_SESSION_SECONDS
		# Des héros Mauvais à la cité baissent l'efficacité (voir personality.gd) : on le remarque ici.
		var efficiency := lobby_efficiency()
		var points: int = maxi(1, roundi(sessions * (TRAINING_POINTS_BASE + hero["growth"]) * efficiency))
		training_news.append_array(add_skill_progress(hero, hero["training"], points,
			skill_progress_needed(hero["training"])))
		if efficiency < 1.0:
			training_news.append_array(notice_bad_heroes())
		changed = true
	if changed:
		save_game()
		training_updated.emit()
