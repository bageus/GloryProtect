class_name UpgradeOverrideRegistry
extends RefCounted

class OverrideEntry:
	var override_id: StringName
	var priority: int
	var callback: Callable

	func _init(id: StringName, order: int, handler: Callable) -> void:
		override_id = id
		priority = order
		callback = handler


var _entries: Dictionary[StringName, Array] = {}


func register_override(
	event_id: StringName,
	override_id: StringName,
	priority: int,
	callback: Callable
) -> bool:
	if event_id == &"" or override_id == &"" or not callback.is_valid():
		return false
	var entries: Array = _entries.get(event_id, [])
	for entry: OverrideEntry in entries:
		if entry.override_id == override_id:
			return false
	entries.append(OverrideEntry.new(override_id, priority, callback))
	entries.sort_custom(func(first: OverrideEntry, second: OverrideEntry) -> bool:
		if first.priority == second.priority:
			return first.override_id < second.override_id
		return first.priority > second.priority
	)
	_entries[event_id] = entries
	return true


func unregister_override(event_id: StringName, override_id: StringName) -> void:
	var entries: Array = _entries.get(event_id, [])
	for index: int in range(entries.size() - 1, -1, -1):
		var entry: OverrideEntry = entries[index]
		if entry.override_id == override_id:
			entries.remove_at(index)
	_entries[event_id] = entries


func resolve(event_id: StringName, context: Dictionary) -> bool:
	var entries: Array = _entries.get(event_id, [])
	for entry: OverrideEntry in entries:
		if bool(entry.callback.call(context)):
			return true
	return false


func clear() -> void:
	_entries.clear()
