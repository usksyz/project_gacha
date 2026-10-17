# Tutoriel et conseils du Système

Les renvois « voir … » peuvent désigner une autre partie de `docs/` ou `CLAUDE.md` (le fichier d'origine a été découpé au prompt 5, sans rien réécrire).

- Conseils du Système (accueil d'un nouveau joueur, demande du porteur du projet ; aucune nouvelle mécanique) :
  fenêtre « Conseil » la première fois que le Maître fait quelque chose. Ids dans `GameData.TIP_IDS`
  (`game_state.gd`) : bienvenue (partie neuve, appelée par `main.gd` au lancement), invocation (`summon_screen.gd`,
  cartes retournées), equipe (« Composer les équipes » ou « Former l'équipe »), etage (annonce de l'étage),
  blessure et mort (`report["tips"]` de `finish_tower_battle`, montrés après « Continuer » ou le rapport
  d'absence ; mort aussi après une synthèse), batiment (`build`, `check_auto_buildings`, terrain d'entraînement).
  `GameData.show_tip(id)` émet `tip_requested` si le conseil n'est pas vu et `Settings.tips` actif ; `main.gd`
  les met en file et en montre un à la fois, après ses autres fenêtres (`WINDOW_NAMES`) ; vu = noté à la
  fermeture (`seen_tips`, sauvegardé « conseils_vus » ; une ancienne sauvegarde les compte tous comme vus).
  Textes dans `scripts/system_tips.gd` (`SystemTips`). Paramètres : « Conseils du Système » (activé / désactivé,
  `parametres.cfg`) et « Réafficher les conseils » (`reset_tips`). Nouveau conseil : un id dans `TIP_IDS`, son
  texte dans `SystemTips`, un `show_tip` là où ça arrive. Les ids « tuto_... » et « bienvenue » sont ceux du
  tutoriel (`is_tutorial_tip`) : obligatoires, le réglage ne les coupe pas, « Réafficher » ne les rejoue pas.
- Tutoriel obligatoire d'une partie neuve (demande du porteur du projet ; cahier, « Tutoriel et interface » :
  premier combat puis la synthèse, « dont la porte s'ouvre à ce moment ») : `GameData.tutorial_step`
  (`game_state.gd`, sauvegardé « tutoriel » ; absent d'une ancienne sauvegarde = pas de tutoriel), étapes
  `TUTORIAL_STEPS` : invocation, armes, equipe, etage, synthese, puis "" (fini). On commence avec exactement l'or
  d'une invocation normale x`TUTORIAL_SUMMON_COUNT` (50 000 or ; gemmes : `START_GEMS`, 500 depuis le prompt 1). 1. Seule la normale x10
  est permise (`summon_allowed`) ; elle donne un 3 étoiles garanti, un 2 étoiles une fois sur deux
  (`FIRST_SUMMON_TWO_STAR_CHANCE`), le reste en 1 étoile (`_first_summon_rarities`). 2. Armes (étape T1, demande
  du porteur du projet) : fenêtre « tuto_armes » (les héros partent avec les armes de l'arsenal, il faut en
  invoquer) ; en la fermant, le hub, où une flèche « Touche ici » montre l'armurerie (`HubCity3D.TUTORIAL_POINTS`,
  `HubScreen.TUTORIAL_PLACES` : seul ce lieu s'ouvre) ; à l'armurerie, seul le tirage x10 est permis
  (`weapon_draw_allowed`), et il est offert (`weapon_draw_cost` = 0 ; choisi plutôt que 50 000 or de plus au
  départ : rien en trop, et une partie déjà en cours n'a pas besoin d'or). Il donne au moins une épée, un bouclier
  et un arc (`TUTORIAL_WEAPON_TYPES`, `items.gd`), compte pour le terrain d'entraînement (10 armes : fenêtre
  « Construction terminée », pas d'étape en plus ; son animation dans la cité passe avant celle de la chambre de
  synthèse, à l'étape 5). Puis fenêtre « tuto_arsenal » (les héros prennent eux-mêmes une arme en partant,
  bouton « Auto ») et celle de l'étape suivante. Forge fermée pendant le tutoriel. 3. Composer une équipe
  (« Terminé » avec au moins un héros ; « Entrer dans la Tour » fermé avant). 4. Gagner l'étage 1 (défaite :
  on recommence). La chambre de synthèse est alors construite gratuitement (`finish_tower_battle`). 5. Retour à
  la cité (« Continuer » : `DungeonsScreen.navigate`) : la chambre se construit sous les yeux du Maître
  (demande du porteur du projet : `HubCity3D` la laisse hors de la cité tant que « tuto_synthese » n'est pas vu,
  puis joue l'animation ; signal `construction_finished` → fenêtre de l'étape, `hub_screen.gd`), une flèche
  « Touche ici » la montre (`_place_tutorial_pointer`) et il faut la toucher (les autres lieux, les boutons du
  hub et les héros ne répondent pas). Ancien plan 2D : la fenêtre tout de suite. Puis une synthèse ; moins de
  2 héros vivants : le tutoriel s'arrête (`end_tutorial`).
  Passage d'étape : `advance_tutorial(étape)` (signal `tutorial_changed`). `main.gd` : bandeau en haut
  (`SystemTips.tutorial_goal`), seul l'onglet de l'étape est permis (`TUTORIAL_SCREENS` ; armes et synthèse : le
  hub), reprise à l'écran de l'étape au lancement, fenêtre de chaque étape (`show_tutorial_tip`), hub en fermant
  « tuto_armes » et « tuto_fin ». Mode dev : « Passer le tutoriel » (`dev_skip_tutorial` : rien n'est donné, ni
  le tirage offert). Sauvegarde version 7 : une partie arrêtée à l'étape « equipe » sans équipe composée revient
  à l'étape « armes » ; une équipe composée, ou une étape plus loin : l'étape est sautée (`load_game`).
  Vérification : `tools/test_tutoriel.tscn` (avec une fenêtre ; voir son en-tête) joue une partie neuve en mode
  normal à travers les écrans (invocation, flèche et armurerie touchées dans la cité 3D, tirage, équipe, étage 1
  jusqu'à la victoire avec les héros armés, synthèse), la reprise au lancement et les anciennes sauvegardes, avec
  des captures ; il recommence la partie (voir « Tests et sauvegarde locale »).
