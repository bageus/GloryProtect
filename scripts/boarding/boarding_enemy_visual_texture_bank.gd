class_name BoardingEnemyVisualTextureBank
extends RefCounted


static func get_frame_count(archetype_id: StringName, state_id: StringName) -> int:
	return BoardingEnemyVisualAssetCatalog.get_frame_count(archetype_id, state_id)


static func get_frames(archetype_id: StringName, state_id: StringName) -> Array[Texture2D]:
	return BoardingEnemyVisualAssetCatalog.get_frames(archetype_id, state_id)
