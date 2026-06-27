class_name StrategicMinimapPolished
extends StrategicMinimap

@export_range(1.0, 3.0, 0.1) var cloud_size_multiplier: float = 1.35
@export_range(0.1, 0.35, 0.01) var cloud_wobble_amount: float = 0.2


func get_cloud_radius(enemy_count: int) -> Vector2:
	var count_scale: float = sqrt(float(maxi(1, enemy_count)))
	return Vector2(
		clampf(7.0 + count_scale * 2.4, 11.0, 21.0),
		clampf(5.0 + count_scale * 1.65, 8.0, 15.0)
	) * cloud_size_multiplier


func _draw_enemy_cloud(
	snapshot: StrategicGroupSnapshot,
	position: Vector2,
	color: Color
) -> void:
	var radius: Vector2 = get_cloud_radius(snapshot.enemy_count)
	var points := PackedVector2Array()
	var point_count: int = 18
	var time: float = _blink_elapsed * cloud_morph_speed
	var breathing: float = 1.0 + sin(time * 0.72 + snapshot.group_id) * 0.07

	for index: int in range(point_count):
		var angle: float = TAU * float(index) / float(point_count)
		var phase: float = (
			time
			+ float(snapshot.group_id) * 1.37
			+ float(index) * 1.73
		)
		var secondary: float = sin(time * 1.63 - float(index) * 0.91) * 0.06
		var wobble: float = (
			1.0
			+ sin(phase) * cloud_wobble_amount
			+ secondary
		)
		points.append(
			position + Vector2(
				cos(angle) * radius.x * wobble * breathing,
				sin(angle) * radius.y * (2.0 - wobble) * breathing
			)
		)

	draw_circle(
		position,
		maxf(radius.x, radius.y) * 1.08,
		Color(color.r, color.g, color.b, 0.12)
	)
	draw_colored_polygon(points, color)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(
		outline,
		Color(0.08, 0.01, 0.02, 1.0),
		2.0,
		true
	)

	var visible_specks: int = mini(snapshot.enemy_count, 8)
	for index: int in range(visible_specks):
		var seed: float = float(snapshot.group_id * 17 + index * 11)
		var orbit: float = time * (0.42 + float(index % 3) * 0.09) + seed
		var offset := Vector2(
			sin(orbit * 1.7) * radius.x * 0.55,
			cos(orbit * 2.3) * radius.y * 0.46
		)
		draw_circle(
			position + offset,
			1.7 + sin(orbit) * 0.35,
			Color(0.18, 0.01, 0.025, 0.95)
		)
