class_name BoardingRewardController
extends Node

signal reward_granted(enemy_id: int, amount: int, reason: StringName)
signal strategic_reward_granted(section_id: int, amount: int)

@export_node_path("BoardingEnemyRegistry") var enemy_registry_path: NodePath
@export_node_path("RunEconomy") var run_economy_path: NodePath
@export_node_path("StrategicWaveSystem") var strategic_wave_path: NodePath
@export_range(0.2, 3.0, 0.1) var feedback_duration: float = 1.0
@export var balance: EconomyBalance

@onready var _enemies: BoardingEnemyRegistry = get_node(enemy_registry_path)
@onready var _economy: RunEconomy = get_node(run_economy_path)
var _strategic: StrategicWaveSystem
var _game_flow: GameFlowController
var _counter: Label
var _gain: Label
var _pending_gain: int = 0
var _feedback_remaining: float = 0.0


func _ready() -> void:
	assert(balance != null, "BoardingRewardController requires EconomyBalance")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_enemies.enemy_removed.connect(_on_enemy_removed)
	_strategic = _resolve_strategic_wave_system()
	if _strategic != null:
		_strategic.strategic_enemy_impacted.connect(_on_strategic_enemy_impacted)
	var scene_root: Node = _resolve_scene_root()
	if scene_root != null:
		_game_flow = scene_root.get_node_or_null(
			"GameFlowController"
		) as GameFlowController
		_build_feedback_view(scene_root)


func _process(delta: float) -> void:
	if _counter == null or _gain == null:
		return
	_counter.text = "Монеты: %d" % _economy.get_coins()
	if _feedback_remaining <= 0.0:
		_gain.visible = false
		_pending_gain = 0
		return
	if _game_flow == null or _game_flow.is_world_simulation_active():
		_feedback_remaining = maxf(0.0, _feedback_remaining - maxf(0.0, delta))
	var fade_window: float = maxf(0.1, feedback_duration * 0.35)
	_gain.modulate.a = clampf(_feedback_remaining / fade_window, 0.0, 1.0)


func get_coin_counter_text() -> String:
	return "" if _counter == null else _counter.text


func get_coin_gain_text() -> String:
	return "" if _gain == null else _gain.text


func is_coin_gain_visible() -> bool:
	return _gain != null and _gain.visible


func get_coin_gain_color() -> Color:
	if _gain == null:
		return Color.TRANSPARENT
	return _gain.get_theme_color("font_color")


func _on_enemy_removed(enemy_id: int, reason: StringName) -> void:
	if not balance.is_rewarded_boarding_reason(reason):
		return
	_grant_reward(enemy_id, balance.boarding_enemy_base_reward, reason)


func _on_strategic_enemy_impacted(section_id: int, _damage: float) -> void:
	var amount: int = balance.strategic_enemy_impact_reward
	if amount <= 0:
		return
	_grant_reward(-1, amount, &"strategic_shield_impact")
	strategic_reward_granted.emit(section_id, amount)


func _grant_reward(enemy_id: int, amount: int, reason: StringName) -> void:
	if amount <= 0:
		return
	_economy.add_coins(amount, reason)
	reward_granted.emit(enemy_id, amount, reason)
	if _counter == null or _gain == null:
		return
	_pending_gain = _pending_gain + amount if _feedback_remaining > 0.0 else amount
	_feedback_remaining = feedback_duration
	_gain.text = "+%d" % _pending_gain
	_gain.visible = true
	_gain.modulate.a = 1.0
	_counter.text = "Монеты: %d" % _economy.get_coins()


func _resolve_strategic_wave_system() -> StrategicWaveSystem:
	if not strategic_wave_path.is_empty():
		return get_node_or_null(strategic_wave_path) as StrategicWaveSystem
	return get_node_or_null("../StrategicWaveSystem") as StrategicWaveSystem


func _resolve_scene_root() -> Node:
	var current: Node = get_tree().current_scene
	if current != null and current.is_ancestor_of(self):
		return current
	current = self
	while (
		current.get_parent() != null
		and current.get_parent() != get_tree().root
	):
		current = current.get_parent()
	return current


func _build_feedback_view(scene_root: Node) -> void:
	var canvas: CanvasLayer = scene_root.get_node_or_null(
		"CanvasLayer"
	) as CanvasLayer
	if canvas == null:
		return
	_counter = _make_label(18.0, 58.0, 26)
	_counter.name = "CoinCounter"
	_gain = _make_label(56.0, 90.0, 22)
	_gain.name = "CoinGain"
	_gain.visible = false
	_gain.add_theme_color_override(
		"font_color",
		UpgradeCardFormatter.get_price_color()
	)
	canvas.add_child(_counter)
	canvas.add_child(_gain)
	_counter.text = "Монеты: %d" % _economy.get_coins()


func _make_label(top: float, bottom: float, font_size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.anchor_left = 1.0
	label.anchor_right = 1.0
	label.offset_left = -240.0
	label.offset_top = top
	label.offset_right = -24.0
	label.offset_bottom = bottom
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_size_override("font_size", font_size)
	return label
