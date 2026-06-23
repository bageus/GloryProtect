from __future__ import annotations

from pathlib import Path

PANEL_PATH = Path("scripts/ui/crew_command_panel.gd")
VIEW_PATH = Path("scripts/ui/crew_command_panel_view.gd")


def replace_once(source: str, old: str, new: str) -> str:
    count = source.count(old)
    if count != 1:
        raise RuntimeError(f"Expected exactly one occurrence, found {count}: {old[:80]!r}")
    return source.replace(old, new, 1)


def replace_between(source: str, start: str, end: str, replacement: str) -> str:
    start_index = source.find(start)
    end_index = source.find(end, start_index)
    if start_index < 0 or end_index < 0:
        raise RuntimeError(f"Unable to locate block: {start!r} -> {end!r}")
    return source[:start_index] + replacement + source[end_index:]


panel = PANEL_PATH.read_text(encoding="utf-8")

panel = replace_once(
    panel,
    """var _slot_specs: Array[Dictionary] = []
var _slot_buttons: Array[Button] = []
var _free_cell_by_defender: Dictionary = {}
var _pending_free_moves: Dictionary = {}
var _selected_slot := -1
var _context_panel: PanelContainer
var _context_box: VBoxContainer
var _feedback_label: Label
""",
    """var _slot_specs: Array[Dictionary] = []
var _free_cell_by_defender: Dictionary = {}
var _pending_free_moves: Dictionary = {}
var _selected_slot := -1
var _view := CrewCommandPanelView.new()
""",
)

panel = replace_once(
    panel,
    "\t_build_interface()\n",
    "\t_view.build(self, 6, 12, _on_slot_pressed)\n",
)

panel = replace_between(
    panel,
    "func _build_interface() -> void:\n",
    "func _connect_signals() -> void:\n",
    "",
)

panel = replace_between(
    panel,
    "func _update_slots() -> void:\n",
    "func _describe_slot(spec: Dictionary) -> Dictionary:\n",
    """func _update_slots() -> void:
\tfor slot_index: int in range(_slot_specs.size()):
\t\tvar spec: Dictionary = _slot_specs[slot_index]
\t\t_view.update_slot(slot_index, spec, _describe_slot(spec))


""",
)

panel = replace_between(
    panel,
    "func _on_slot_pressed(slot_index: int) -> void:\n",
    "func _on_release_pressed(slot_index: int) -> void:\n",
    """func _on_slot_pressed(slot_index: int) -> void:
\t_selected_slot = slot_index
\t_rebuild_context_menu()


func _rebuild_context_menu() -> void:
\tif _selected_slot < 0 or _selected_slot >= _slot_specs.size():
\t\t_close_context()
\t\treturn
\tvar description: Dictionary = _describe_slot(_slot_specs[_selected_slot])
\tvar owner_id: int = int(description["owner"])
\tvar free_ids: Array[int] = _get_available_free_defenders(owner_id)
\t_view.rebuild_context(
\t\tdescription,
\t\tfree_ids,
\t\t_selected_slot,
\t\t_on_release_pressed,
\t\t_on_assign_pressed,
\t\t_close_context
\t)


""",
)

panel = replace_between(
    panel,
    "func _set_feedback(message: String, is_error: bool) -> void:\n",
    "func _on_buildable_unlocked(type_id: int, _count: int) -> void:\n",
    """func _set_feedback(message: String, is_error: bool) -> void:
\t_view.set_feedback(message, is_error)


func _close_context() -> void:
\t_view.close_context()
\t_selected_slot = -1


""",
)

panel = panel.replace("_context_panel.visible", "_view.is_context_visible()")

for forbidden in (
    "_slot_buttons",
    "_context_panel",
    "_context_box",
    "_feedback_label",
    "_build_interface",
    "_build_side_panel",
    "_build_context_panel",
    "_make_panel_style",
    "_make_context_style",
    "_add_close_button",
    "_clear_children",
):
    if forbidden in panel:
        raise RuntimeError(f"Presentation identifier remained in panel: {forbidden}")

view = '''class_name CrewCommandPanelView
extends RefCounted

var _host: Control
var _slot_buttons: Array[Button] = []
var _context_panel: PanelContainer
var _context_box: VBoxContainer
var _feedback_label: Label


func build(
\thost: Control,
\tleft_slot_count: int,
\ttotal_slot_count: int,
\tslot_pressed: Callable
) -> void:
\t_host = host
\t_host.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
\t_host.offset_top = -142.0
\t_build_side_panel(true, 0, left_slot_count, slot_pressed)
\t_build_side_panel(false, left_slot_count, total_slot_count, slot_pressed)
\t_build_context_panel()
\t_build_feedback_label()


func update_slot(
\tslot_index: int,
\tspec: Dictionary,
\tdescription: Dictionary
) -> void:
\tvar button: Button = _slot_buttons[slot_index]
\tbutton.text = "%s\\n%s" % [
\t\tdescription["title"],
\t\tdescription["occupant"],
\t]
\tbutton.disabled = not bool(description["available"])
\tbutton.tooltip_text = "Ячейка платформы %d" % (int(spec["cell"]) + 1)


func rebuild_context(
\tdescription: Dictionary,
\tfree_ids: Array[int],
\tslot_index: int,
\trelease_pressed: Callable,
\tassign_pressed: Callable,
\tclose_pressed: Callable
) -> void:
\t_clear_children(_context_box)
\t_context_panel.visible = true
\t_add_context_title(String(description["title"]))
\tif not bool(description["available"]):
\t\t_add_centered_label("Пост появится после получения улучшения")
\t\t_add_close_button(close_pressed)
\t\treturn
\n\tvar owner_id: int = int(description["owner"])
\tif owner_id >= 0:
\t\tvar release := Button.new()
\t\trelease.text = "Освободить пост — защитник %d" % (owner_id + 1)
\t\trelease.pressed.connect(release_pressed.bind(slot_index))
\t\t_context_box.add_child(release)
\n\tif free_ids.is_empty():
\t\t_add_centered_label("Свободных защитников нет")
\telse:
\t\t_add_assignment_buttons(free_ids, slot_index, assign_pressed)
\t_add_close_button(close_pressed)


func set_feedback(message: String, is_error: bool) -> void:
\t_feedback_label.text = message
\t_feedback_label.add_theme_color_override(
\t\t"font_color",
\t\tColor(1.0, 0.48, 0.4) if is_error else Color(0.62, 0.92, 0.72)
\t)


func close_context() -> void:
\t_context_panel.visible = false


func is_context_visible() -> bool:
\treturn _context_panel.visible


func _build_side_panel(
\tis_left: bool,
\tbegin: int,
\tend: int,
\tslot_pressed: Callable
) -> void:
\tvar panel := PanelContainer.new()
\tpanel.anchor_top = 1.0
\tpanel.anchor_bottom = 1.0
\tpanel.offset_top = -116.0
\tpanel.offset_bottom = -8.0
\tif is_left:
\t\tpanel.anchor_left = 0.0
\t\tpanel.anchor_right = 0.5
\t\tpanel.offset_left = 8.0
\t\tpanel.offset_right = -96.0
\telse:
\t\tpanel.anchor_left = 0.5
\t\tpanel.anchor_right = 1.0
\t\tpanel.offset_left = 96.0
\t\tpanel.offset_right = -8.0
\tpanel.add_theme_stylebox_override("panel", _make_panel_style())
\tpanel.mouse_filter = Control.MOUSE_FILTER_STOP
\t_host.add_child(panel)

\tvar margin := MarginContainer.new()
\tmargin.add_theme_constant_override("margin_left", 6)
\tmargin.add_theme_constant_override("margin_top", 6)
\tmargin.add_theme_constant_override("margin_right", 6)
\tmargin.add_theme_constant_override("margin_bottom", 6)
\tpanel.add_child(margin)

\tvar row := HBoxContainer.new()
\trow.add_theme_constant_override("separation", 4)
\tmargin.add_child(row)
\tfor slot_index: int in range(begin, end):
\t\tvar button := Button.new()
\t\tbutton.custom_minimum_size = Vector2(68.0, 92.0)
\t\tbutton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
\t\tbutton.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
\t\tbutton.pressed.connect(slot_pressed.bind(slot_index))
\t\trow.add_child(button)
\t\t_slot_buttons.append(button)


func _build_context_panel() -> void:
\t_context_panel = PanelContainer.new()
\t_context_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
\t_context_panel.offset_left = -210.0
\t_context_panel.offset_top = -330.0
\t_context_panel.offset_right = 210.0
\t_context_panel.offset_bottom = -148.0
\t_context_panel.add_theme_stylebox_override("panel", _make_context_style())
\t_context_panel.mouse_filter = Control.MOUSE_FILTER_STOP
\t_context_panel.visible = false
\t_host.add_child(_context_panel)

\tvar margin := MarginContainer.new()
\tmargin.add_theme_constant_override("margin_left", 12)
\tmargin.add_theme_constant_override("margin_top", 10)
\tmargin.add_theme_constant_override("margin_right", 12)
\tmargin.add_theme_constant_override("margin_bottom", 10)
\t_context_panel.add_child(margin)
\t_context_box = VBoxContainer.new()
\t_context_box.add_theme_constant_override("separation", 5)
\tmargin.add_child(_context_box)


func _build_feedback_label() -> void:
\t_feedback_label = Label.new()
\t_feedback_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
\t_feedback_label.offset_left = 210.0
\t_feedback_label.offset_top = -141.0
\t_feedback_label.offset_right = -210.0
\t_feedback_label.offset_bottom = -118.0
\t_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
\t_feedback_label.add_theme_font_size_override("font_size", 13)
\t_feedback_label.add_theme_color_override(
\t\t"font_color",
\t\tColor(0.72, 0.82, 0.92)
\t)
\t_feedback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
\t_host.add_child(_feedback_label)


func _add_context_title(text: String) -> void:
\tvar title := Label.new()
\ttitle.text = text
\ttitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
\ttitle.add_theme_font_size_override("font_size", 17)
\t_context_box.add_child(title)


func _add_centered_label(text: String) -> void:
\tvar label := Label.new()
\tlabel.text = text
\tlabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
\t_context_box.add_child(label)


func _add_assignment_buttons(
\tfree_ids: Array[int],
\tslot_index: int,
\tassign_pressed: Callable
) -> void:
\tvar hint := Label.new()
\thint.text = "Назначить свободного защитника:"
\t_context_box.add_child(hint)
\tvar row := HBoxContainer.new()
\trow.alignment = BoxContainer.ALIGNMENT_CENTER
\trow.add_theme_constant_override("separation", 5)
\t_context_box.add_child(row)
\tfor defender_id: int in free_ids:
\t\tvar button := Button.new()
\t\tbutton.text = "Защитник %d" % (defender_id + 1)
\t\tbutton.pressed.connect(assign_pressed.bind(slot_index, defender_id))
\t\trow.add_child(button)


func _add_close_button(close_pressed: Callable) -> void:
\tvar close := Button.new()
\tclose.text = "Закрыть"
\tclose.pressed.connect(close_pressed)
\t_context_box.add_child(close)


func _clear_children(container: Container) -> void:
\tfor child: Node in container.get_children():
\t\tcontainer.remove_child(child)
\t\tchild.queue_free()


func _make_panel_style() -> StyleBoxFlat:
\tvar style := StyleBoxFlat.new()
\tstyle.bg_color = Color(0.025, 0.035, 0.055, 0.94)
\tstyle.border_color = Color(0.2, 0.34, 0.48, 0.95)
\tstyle.set_border_width_all(2)
\tstyle.corner_radius_top_left = 8
\tstyle.corner_radius_top_right = 8
\tstyle.corner_radius_bottom_left = 4
\tstyle.corner_radius_bottom_right = 4
\treturn style


func _make_context_style() -> StyleBoxFlat:
\tvar style := StyleBoxFlat.new()
\tstyle.bg_color = Color(0.018, 0.026, 0.043, 0.98)
\tstyle.border_color = Color(0.34, 0.56, 0.76, 1.0)
\tstyle.set_border_width_all(2)
\tstyle.corner_radius_top_left = 8
\tstyle.corner_radius_top_right = 8
\tstyle.corner_radius_bottom_left = 8
\tstyle.corner_radius_bottom_right = 8
\treturn style
'''

panel_lines = panel.count("\n") + 1
view_lines = view.count("\n") + 1
if panel_lines > 600 or view_lines > 600:
    raise RuntimeError(
        f"Generated files exceed limit: panel={panel_lines}, view={view_lines}"
    )

PANEL_PATH.write_text(panel, encoding="utf-8")
VIEW_PATH.write_text(view, encoding="utf-8")
print(f"Generated {PANEL_PATH} ({panel_lines} lines)")
print(f"Generated {VIEW_PATH} ({view_lines} lines)")
