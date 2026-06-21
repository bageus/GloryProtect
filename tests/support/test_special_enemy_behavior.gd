class_name TestSpecialEnemyBehavior
extends EnemyBehaviorComponent

var tick_count: int = 0
var elapsed: float = 0.0


func _on_configured() -> void:
	publish_visual_state(&"configured")


func _tick_behavior(delta: float) -> void:
	tick_count += 1
	elapsed += delta
	publish_visual_state(&"active")
