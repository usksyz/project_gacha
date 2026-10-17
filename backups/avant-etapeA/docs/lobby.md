# Lobby : la cité et ses bâtiments

Les renvois « voir … » peuvent désigner une autre partie de `docs/` ou `CLAUDE.md` (le fichier d'origine a été découpé au prompt 5, sans rien réécrire).

- Hub 3D (demande du porteur du projet, d'après le plan de la cité du manhwa) : `scripts/hub_city_3d.gd`
  (`HubCity3D`, une `SubViewport` 3D faite de formes simples), affiché avec les nouveaux visuels ; les
  anciens gardent le plan 2D `HubMap`. Disposition d'après le plan du manhwa (`PLACES`, rues `CROSSINGS` /
  `STREETS`) : rempart à 12 pans, résidences à l'ouest, combat au nord, place en roue au nord-est face à
  la faille (arche dans le rempart). Demandes du porteur du projet : la cité vole dans le néant (ciel
  étoilé en shader, rocher sous la cité, rochers et cristaux en suspension, courants cyan), style
  médiéval sombre et détaillé (modèles et textures dessinées par le code dans `scripts/city_models.gd`,
  `CityModels` : briques, pavés, tuiles, colombages, fenêtres éclairées). Arbres, créneaux, lanternes en
  `MultiMesh` (téléphone). Un bâtiment pas construit n'apparaît pas dans la cité : on le voit en
  hologramme qui tourne dans le menu Construction (`scripts/holo_preview.gd`). Une fois construit (payé,
  ou condition remplie : terrain d'entraînement, annoncé par `GameData.facility_completed` et une fenêtre
  de `main.gd`), la caméra va vers lui et il monte du sol en hologramme cyan, des pixels scintillent
  (l'hologramme n'est que l'animation de construction). L'animation attend qu'aucune fenêtre ne couvre
  la cité (`HubCity3D.paused`, `hold`).
  Les héros y vivent en suivant les rues (`AStar3D`) : terrain d'entraînement s'ils s'entraînent, devant
  leur bâtiment s'ils sont assistants, sinon promenade (place, rues des résidences) ; départ en mission
  par la faille, retour par la zone de débarquement,
  nouveaux héros par la salle d'invocation. Un doigt : déplacer ; deux doigts / molette : zoom ;
  toucher un lieu (même fonctionnement que `HubMap`) ou un héros (ce qu'il fait). Noms en texte 2D
  par-dessus la 3D. Reste : vrais modèles, temps du lobby x3, héros qui choisissent d'eux-mêmes.
- `scripts/training_screen.gd` : terrain d'entraînement (ouvert depuis le hub, bouton « Retour à la cité ») ;
  `main.gd` range les écrans du hub sans onglet dans `HUB_SCREENS`. Un héros y travaille une compétence
  (`hero["training"]`) ; une séance toutes les `TRAINING_SESSION_SECONDS` de temps réel, même jeu fermé
  (`GameData.update_training()`, appelée au lancement puis toutes les 5 s). Choix du porteur du projet :
  un héros qui monte dans la Tour quitte le terrain le temps de l'étage (il garde sa place et son
  programme, le temps dans la Tour ne compte pas) et reprend l'entraînement après.
  À terme (pas encore fait) : le temps du lobby ira 3 fois plus vite que le temps réel, et les héros se
  baladeront et feront des choses d'eux-mêmes, comme aller au terrain d'entraînement.
- Affectations (bouton du hub, `scripts/assignment_panel.gd`) : `POSTS_PER_BUILDING` = 2 postes
  d'assistant par bâtiment construit (`hero["post"]`) ; un poste et l'entraînement s'excluent.
  Un héros parti (Tour ou donjon journalier, `GameData.is_away`) ne s'entraîne pas et ne compte pas à son poste.
- Donjon journalier (carte de l'écran Donjons, `lobby.gd`) : calendrier selon le jour réel de l'appareil
  (`DAILY_DUNGEONS`, `open_daily_dungeons()`) : lundi-mardi Mine d'Isralta, mercredi-jeudi Forêt Kenout,
  vendredi-samedi Plateau Sinmiel, dimanche tous (on choisit le donjon). Chacun a ses trois matériaux
  (provisoires : la mine garde fer, charbon, cristal ; forêt bois, peau de bête, herbe médicinale ;
  plateau pierre de taille, plume, lin — pas encore utilisés par la forge). Quatre cartes de calendrier à cadre
  argenté, celle du jour dorée. Choix du porteur du projet : autant d'expéditions qu'on veut, plusieurs groupes
  à la fois (`GameData.expeditions`, liste ; plus de limite par jour ; les anciennes sauvegardes à une seule
  expédition sont reprises). Une équipe composée part récolter `EXPEDITION_SECONDS` en temps réel (même jeu
  fermé), avec ses héros libres ; fenêtre système à l'entrée (« Le groupe X est entré dans le donjon journalier,
  [nom] ([difficulté]). Ils reviendront après avoir acquis des matériaux ! ») ; ramassages tirés au départ et
  annoncés au fil du temps (`expedition["log"]`), matériaux gradés, déchets, plans de forge rares ; retour dans
  l'entrepôt (`GameData.warehouse`, rapports dans `expedition_reports`). Monstres rares : un par donjon
  (Reine de la forêt du cahier ; Taupe de cristal et Aigle d'argent inventés), `RARE_MONSTER_CHANCE` (10 %)
  par expédition, `RARE_MONSTER_STONES` (2) pierres d'attribut pour la promotion. Mode dev : terminer les
  expéditions, monstre rare garanti, jour simulé (« jour suivant »). Reste : héros qui y vont d'eux-mêmes
  (avec les héros autonomes du lobby), fermeture du donjon du jour (les « 10 heures » du cahier), chasse.
- Forge (annexe de l'armurerie, `scripts/forge_screen.gd`, construite 500 gemmes) : recettes
  `FORGE_RECIPES`, rang de base = grade du minerai (+1 avec un plan), malus infrastructures / artisan / plan,
  chance affichée (Certaine... Infime) avec Oui / Non, production automatique ou puzzle
  (`scripts/forge_puzzle.gd`, 5 difficultés du cahier, 3 minutes, succès / grand / phénoménal).
  Les assistants de la forge deviennent artisans (compétence « Forge ») en travaillant.
- Chambre de synthèse (`scripts/synthesis_screen.gd`, ouverte depuis le hub, construite 500 gemmes sans
  attendre le terrain d'entraînement) : on choisit le héros à renforcer, puis 1 à `SYNTHESIS_MAX_SACRIFICES`
  (5) héros à sacrifier, de n'importe quel rang (recherche `HeroFilter`) ; fenêtre rouge de confirmation.
  Les sacrifiés meurent pour toujours (cause gardée, armes perdues). Le héros renforcé gagne l'expérience de
  chaque sacrifié et toujours au moins un niveau (cahier : « monte de niveau ») ; pour chaque sacrifié,
  `SYNTHESIS_SKILL_CHANCE` (80 %, feuille de route v2 ; avant 20 %) d'apprendre une de ses compétences qu'il
  n'a pas encore, au niveau 1 (pas une fusion ; incompatibilités respectées). Fenêtre « Synthèse terminée » :
  « X monte en niveau ! La compétence Y a été apprise ! », puis l'expérience et d'où vient chaque compétence ; Œil de faucon (30 %, archers, mages, soigneurs : portée et précision des
  tirs) ; Analyse froide (1 %). Règles et chiffres provisoires dans `game_data/synthesis.gd`.
  Les héros secrets peuvent être sacrifiés (seuls les favoris sont protégés). Chaque synthèse fait baisser la santé mentale des héros
  vivants (voir « Personnalité »). Reste :
  glisser-déposer du cahier (on touche les cartes pour l'instant), salle de promotion dans la chambre.

## Avancement : phases 4 à 6
- Phases 4 à 6 (lobby, artisanat, fin de jeu) : construction, affectations, donjon journalier, entrepôt
  et forge : premières versions faites ; donjon journalier complet (calendrier, trois donjons, monstres rares,
  fenêtre d'entrée). Reste : niveaux de bâtiment, recettes avec les nouveaux matériaux (bois, peau de bête...),
  fonctions des bâtiments de magie, cafétéria, etc. Sauvegarde de la partie : faite
  (reste l'équilibrage de la phase 6).
