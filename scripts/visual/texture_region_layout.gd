class_name TextureRegionLayout
extends RefCounted


static func get_alpha_bounds(
	texture: Texture2D,
	threshold: float = 0.08
) -> Rect2:
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		return Rect2(Vector2.ZERO, texture.get_size())
	var bounds := _scan_alpha_bounds(
		image,
		Rect2i(Vector2i.ZERO, image.get_size()),
		threshold
	)
	if bounds.size == Vector2.ZERO:
		return Rect2(Vector2.ZERO, texture.get_size())
	return bounds


static func get_auto_atlas_frame_regions(
	texture: Texture2D,
	frame_count: int,
	threshold: float = 0.08
) -> Array[Rect2]:
	var grid: Vector2i = resolve_atlas_grid(texture.get_size(), frame_count)
	return get_atlas_frame_regions(
		texture,
		grid.x,
		grid.y,
		threshold
	)


static func resolve_atlas_grid(
	texture_size: Vector2,
	frame_count: int
) -> Vector2i:
	var safe_frame_count: int = maxi(1, frame_count)
	var best_grid := Vector2i(safe_frame_count, 1)
	var best_score: float = INF
	for rows: int in range(1, safe_frame_count + 1):
		if safe_frame_count % rows != 0:
			continue
		var columns: int = floori(float(safe_frame_count) / float(rows))
		var cell_width: float = texture_size.x / float(columns)
		var cell_height: float = texture_size.y / float(rows)
		if cell_width <= 0.0 or cell_height <= 0.0:
			continue
		var aspect_ratio: float = cell_width / cell_height
		var score: float = absf(log(maxf(aspect_ratio, 0.0001)))
		if score < best_score:
			best_score = score
			best_grid = Vector2i(columns, rows)
	return best_grid


static func get_atlas_frame_regions(
	texture: Texture2D,
	columns: int,
	rows: int,
	threshold: float = 0.08
) -> Array[Rect2]:
	var safe_columns: int = maxi(1, columns)
	var safe_rows: int = maxi(1, rows)
	var frame_count: int = safe_columns * safe_rows
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		return _build_full_frame_regions(
			texture.get_size(),
			safe_columns,
			safe_rows
		)

	var frame_width: int = floori(
		float(image.get_width()) / float(safe_columns)
	)
	var frame_height: int = floori(
		float(image.get_height()) / float(safe_rows)
	)
	if frame_width <= 0 or frame_height <= 0:
		var single_region: Array[Rect2] = [
			Rect2(Vector2.ZERO, texture.get_size())
		]
		return single_region

	var union_min := Vector2i(frame_width, frame_height)
	var union_max := Vector2i(-1, -1)
	for frame_index: int in range(frame_count):
		var cell_position := Vector2i(
			(frame_index % safe_columns) * frame_width,
			floori(float(frame_index) / float(safe_columns)) * frame_height
		)
		var cell := Rect2i(
			cell_position,
			Vector2i(frame_width, frame_height)
		)
		var bounds: Rect2 = _scan_alpha_bounds(image, cell, threshold)
		if bounds.size == Vector2.ZERO:
			continue
		var relative_position := Vector2i(
			roundi(bounds.position.x) - cell_position.x,
			roundi(bounds.position.y) - cell_position.y
		)
		var relative_end := relative_position + Vector2i(
			roundi(bounds.size.x),
			roundi(bounds.size.y)
		) - Vector2i.ONE
		union_min.x = mini(union_min.x, relative_position.x)
		union_min.y = mini(union_min.y, relative_position.y)
		union_max.x = maxi(union_max.x, relative_end.x)
		union_max.y = maxi(union_max.y, relative_end.y)

	if union_max.x < union_min.x or union_max.y < union_min.y:
		return _build_full_frame_regions(
			Vector2(image.get_size()),
			safe_columns,
			safe_rows
		)

	var union_size := Vector2i(
		union_max.x - union_min.x + 1,
		union_max.y - union_min.y + 1
	)
	var regions: Array[Rect2] = []
	for frame_index: int in range(frame_count):
		var cell_position := Vector2i(
			(frame_index % safe_columns) * frame_width,
			floori(float(frame_index) / float(safe_columns)) * frame_height
		)
		regions.append(Rect2(
			Vector2(cell_position + union_min),
			Vector2(union_size)
		))
	return regions


static func fit_inside(source_size: Vector2, maximum_size: Vector2) -> Vector2:
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return maximum_size
	var scale_factor: float = minf(
		maximum_size.x / source_size.x,
		maximum_size.y / source_size.y
	)
	return source_size * maxf(scale_factor, 0.0)


static func fit_height(source_size: Vector2, height: float) -> Vector2:
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return Vector2(height, height)
	return Vector2(source_size.x / source_size.y * height, height)


static func _scan_alpha_bounds(
	image: Image,
	area: Rect2i,
	threshold: float
) -> Rect2:
	var min_x: int = area.end.x
	var min_y: int = area.end.y
	var max_x: int = area.position.x - 1
	var max_y: int = area.position.y - 1
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			if image.get_pixel(x, y).a <= threshold:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		return Rect2(Vector2(area.position), Vector2.ZERO)
	return Rect2(
		Vector2(float(min_x), float(min_y)),
		Vector2(
			float(max_x - min_x + 1),
			float(max_y - min_y + 1)
		)
	)


static func _build_full_frame_regions(
	texture_size: Vector2,
	columns: int,
	rows: int
) -> Array[Rect2]:
	var frame_size := Vector2(
		texture_size.x / float(columns),
		texture_size.y / float(rows)
	)
	var regions: Array[Rect2] = []
	for frame_index: int in range(columns * rows):
		regions.append(Rect2(
			Vector2(
				float(frame_index % columns) * frame_size.x,
				floor(float(frame_index) / float(columns)) * frame_size.y
			),
			frame_size
		))
	return regions
