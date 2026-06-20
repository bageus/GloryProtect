class_name ShieldCriticalAlertPresenter
extends Control

@export_node_path("ShieldCriticalAlertController") var alert_controller_path: NodePath
@export_range(0.05, 2.0, 0.05) var tone_duration: float = 0.18
@export_range(100.0, 3000.0, 10.0) var tone_frequency: float = 880.0
@export_range(0.1, 5.0, 0.1) var message_duration: float = 1.6
@export_range(0.0, 1.0, 0.05) var tone_amplitude: float = 0.35

var _message_remaining: float = 0.0

@onready var _alerts: ShieldCriticalAlertController = get_node(
	alert_controller_path
)
@onready var _message_label: Label = %MessageLabel
@onready var _audio: AudioStreamPlayer = %AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_audio.stream = _build_tone_stream()
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
	_audio.play()


func _build_tone_stream() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 44100
	stream.stereo = false
	var sample_count: int = maxi(1, roundi(stream.mix_rate * tone_duration))
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for sample_index: int in range(sample_count):
		var phase: float = (
			TAU * tone_frequency * float(sample_index) / float(stream.mix_rate)
		)
		var envelope: float = 1.0 - float(sample_index) / float(sample_count)
		var value: int = roundi(
			sin(phase) * envelope * tone_amplitude * 32767.0
		)
		data.encode_s16(sample_index * 2, clampi(value, -32768, 32767))
	stream.data = data
	return stream
