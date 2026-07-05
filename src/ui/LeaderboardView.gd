class_name LeaderboardView
extends Control
## 排行榜视图。显示 Top 20，支持返回。

signal back_requested()

@onready var _list: VBoxContainer = %List


func _ready() -> void:
	# 应用 UI 缩放（递归缩放所有子控件的字号）
	UIScale.apply_font_scale(self)
	UIScale.scale_changed.connect(func(_s): UIScale.apply_font_scale(self))
	%BackButton.pressed.connect(func(): back_requested.emit())
	%ClearButton.pressed.connect(_on_clear)


## 隐藏自带的返回/清空按钮（用于嵌入到其他界面，如 GameOver 的排行榜视图）。
func hide_native_buttons() -> void:
	%BackButton.visible = false
	%ClearButton.visible = false


## 显示自带的返回/清空按钮（主菜单独立查看时用）。
func show_native_buttons() -> void:
	%BackButton.visible = true
	%ClearButton.visible = true


func refresh(highlight_rank: int = -1) -> void:
	for c in _list.get_children():
		c.queue_free()
	var entries := Leaderboard.get_entries()
	if entries.is_empty():
		var empty := Label.new()
		empty.text = "暂无记录，去打一局吧！"
		empty.add_theme_color_override("font_color", Color(0.6, 0.65, 0.72))
		empty.add_theme_font_size_override("font_size", 20)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_list.add_child(empty)
		return
	for i in entries.size():
		var e: Dictionary = entries[i]
		var row := _make_row(i + 1, e, i + 1 == highlight_rank)
		_list.add_child(row)


func _make_row(rank: int, e: Dictionary, highlight: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	if highlight:
		row.modulate = Color("ffe34a")
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.14, 0.2, 0.85 if rank % 2 == 1 else 0.6)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	row.add_theme_stylebox_override("panel", sb)

	var m := int(e.get("time", 0))
	var time_str := "%02d:%02d" % [m / 60, m % 60]
	var diff_name := Difficulty.preset_name(int(e.get("difficulty", 1)))
	var boss := "👑" if bool(e.get("boss", false)) else ""

	var cells := [
		"#%d" % rank,
		String(e.get("name", "???")),
		"%d" % int(e.get("score", 0)),
		diff_name,
		time_str,
		"杀%d" % int(e.get("kills", 0)),
		"Lv%d" % int(e.get("level", 1)),
		boss,
	]
	var weights := [0.6, 2.0, 1.4, 1.2, 1.0, 1.0, 0.8, 0.5]
	for i in cells.size():
		var lbl := Label.new()
		lbl.text = cells[i]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 18 if i == 1 else 16)
		if i == 2:  # 分数高亮
			lbl.add_theme_color_override("font_color", Color("ffe34a"))
		elif i == 0:
			lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if i != 1 else HORIZONTAL_ALIGNMENT_LEFT
		row.add_child(lbl)
	return row


func _on_clear() -> void:
	# 二次确认
	var dlg := ConfirmationDialog.new()
	dlg.dialog_text = "确定清空排行榜吗？此操作不可撤销。"
	add_child(dlg)
	dlg.confirmed.connect(func():
		Leaderboard.clear()
		refresh()
		dlg.queue_free()
	)
	dlg.canceled.connect(func(): dlg.queue_free())
	dlg.popup_centered(Vector2i(360, 120))
