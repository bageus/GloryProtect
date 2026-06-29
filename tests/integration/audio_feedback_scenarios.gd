extends SceneTree

const GAME_SCENE := preload("res://scenes/game/game_root_with_flyers.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game: Node2D = GAME_SCENE.instantiate() as Node2D
	root.add_child(game)
	await process_frame
	await process_frame

	var flow: GameFlowController = game.get_node("GameFlowController")
	var audio := game.get_node("GameAudioController") as GameAudioController
	var music := game.get_node("GameMusicController") as GameMusicController
	var crew: CrewManager = game.get_node("World/Platform/CrewManager")
	var replacements: CrewReplacementController = game.get_node(
		"CrewReplacementController"
	)
	var enemies: BoardingEnemyRegistry = game.get_node(
		"World/BoardingEnemyRegistry"
	)
	var medical: MedicalStationSystem = game.get_node(
		"World/MedicalStationSystem"
	)
	var turrets: TurretSystem = game.get_node("World/TurretSystem")
	var anchors: AnchorSystem = game.get_node("World/AnchorSystem")
	var platform: PlatformController = game.get_node("World/Platform")
	var contact: OrbContactSystem = game.get_node("World/OrbContactSystem")
	var shield: ShieldSystem = game.get_node("ShieldSystem")
	var shield_core: ShieldCoreSystem = game.get_node("World/ShieldCoreSystem")

	_disable_spawners(game)
	music.refresh_music_state_for_tests()
	assert(music.is_gameplay_music_active())
	assert(not music.is_game_over_music_active())
	flow.state = GameFlowController.RunState.RUNNING
	await process_frame

	assert(audio != null)
	assert(audio.get_loaded_sound_ids().size() == 13)

	var defender: Defender = crew.get_defender(0)
	var target: Defender = crew.get_defender(1)
	defender.melee.attack_started.emit(target.health)
	assert(audio.get_trigger_count(
		GameAudioController.SOUND_DEFENDER_ATTACK
	) == 1)

	defender.ranged.projectile_launched.emit(
		target.health,
		defender.global_position,
		target.global_position
	)
	assert(audio.get_trigger_count(
		GameAudioController.SOUND_SHOOTER_ATTACK
	) == 1)

	crew.defender_died.emit(defender.defender_id)
	assert(audio.get_trigger_count(
		GameAudioController.SOUND_DEFENDER_DIE
	) == 1)

	enemies.enemy_removed.emit(11, &"test")
	assert(audio.get_trigger_count(
		GameAudioController.SOUND_MONSTER_DIE
	) == 1)

	replacements.replacement_completed.emit(defender.defender_id, defender)
	assert(audio.get_trigger_count(GameAudioController.SOUND_PORTAL) == 1)

	turrets.shot_started.emit(3, defender.defender_id, 11)
	assert(audio.get_trigger_count(
		GameAudioController.SOUND_TURRET_ATTACK
	) == 1)

	anchors.anchor_attached.emit(0)
	anchors.anchor_removed.emit(0)
	anchors.anchor_broken.emit(1)
	assert(audio.get_trigger_count(
		GameAudioController.SOUND_WINCH_CONNECT
	) == 1)
	assert(audio.get_trigger_count(
		GameAudioController.SOUND_WINCH_DISCONNECT
	) == 2)

	shield_core.completion_energy_shared.emit(0, 1, 5.0)
	assert(audio.get_trigger_count(
		GameAudioController.SOUND_SHIELD_WAVE
	) == 1)

	medical.healing_started.emit(1, 0)
	audio.refresh_audio_state_for_tests()
	assert(audio.is_loop_active(GameAudioController.SOUND_HEALER_HEAL))
	medical.healing_stopped.emit(1, 0)
	audio.refresh_audio_state_for_tests()
	assert(not audio.is_loop_active(GameAudioController.SOUND_HEALER_HEAL))

	contact.active_orb_id = 0
	audio.refresh_audio_state_for_tests()
	assert(audio.is_loop_active(GameAudioController.SOUND_SHIELD_CHARGE))
	contact.active_orb_id = -1
	audio.refresh_audio_state_for_tests()
	assert(not audio.is_loop_active(GameAudioController.SOUND_SHIELD_CHARGE))

	shield.set_health(0, 1.0)
	audio.refresh_audio_state_for_tests()
	assert(audio.is_loop_active(GameAudioController.SOUND_SHIELD_ALERT))
	shield.set_health(0, shield.get_max_health())
	audio.refresh_audio_state_for_tests()
	assert(not audio.is_loop_active(GameAudioController.SOUND_SHIELD_ALERT))

	platform.horizontal_velocity = 30.0
	audio.refresh_audio_state_for_tests()
	assert(audio.is_loop_active(GameAudioController.SOUND_PLATFORM_MOVE))
	platform.horizontal_velocity = 0.0
	audio.refresh_audio_state_for_tests()
	assert(not audio.is_loop_active(GameAudioController.SOUND_PLATFORM_MOVE))

	medical.healing_started.emit(1, 0)
	platform.horizontal_velocity = 30.0
	contact.active_orb_id = 0
	shield.set_health(0, 1.0)
	audio.refresh_audio_state_for_tests()
	flow.state = GameFlowController.RunState.MANUAL_PAUSE
	audio.refresh_audio_state_for_tests()
	assert(not audio.is_loop_active(GameAudioController.SOUND_HEALER_HEAL))
	assert(not audio.is_loop_active(GameAudioController.SOUND_PLATFORM_MOVE))
	assert(not audio.is_loop_active(GameAudioController.SOUND_SHIELD_CHARGE))
	assert(not audio.is_loop_active(GameAudioController.SOUND_SHIELD_ALERT))

	flow.end_run(&"test")
	await process_frame
	assert(not music.is_gameplay_music_active())
	assert(music.is_game_over_music_active())

	flow.start_run()
	await process_frame
	assert(music.is_gameplay_music_active())
	assert(not music.is_game_over_music_active())

	print("Audio feedback scenarios passed")
	quit()


func _disable_spawners(game: Node) -> void:
	var paths: Array[NodePath] = [
		NodePath("World/BoardingSpawnDirector"),
		NodePath("World/FlyingEnemySpawnDirector"),
		NodePath("World/StrategicWaveDirector"),
		NodePath("World/StrategicGroupMutationController"),
	]
	for path: NodePath in paths:
		if not game.has_node(path):
			continue
		var system: Node = game.get_node(path)
		system.set_process(false)
		system.set_physics_process(false)
