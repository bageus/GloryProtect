class_name ShieldCriticalAlertPresenter
extends Control

@export_node_path("ShieldCriticalAlertController") var alert_controller_path: NodePath
@export_range(0.1, 5.0, 0.1) var message_duration: float = 1.6

var _message_remaining: float = 0.0

@onready var _alerts: ShieldCriticalAlertController = get_node(alert_controller_path)
@onready var _message_label: Label = %MessageLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_alerts.critical_alert_raised.connect(_on_critical_alert_raised)


func _process(delta: float) -> void:
	if _message_remaining <= 0.0:
		return
	_message_remaining = maxf(0.0, _message_remaining - delta)
	visible = _message_remaining > 0.0


func _on_critical_alert_raised(section_ids: Array[int]) -> void:
	var labels := PackedStringArray()
	for section_id: int in section_ids:
		labels.append("S%d" % (section_id + 1))
	_message_label.text = "КРИТИЧЕСКИЙ ЩИТ: %s" % ", ".join(labels)
	_message_remaining = message_duration
	visible = true
