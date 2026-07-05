class_name TouchInput
extends CanvasLayer
## 触摸输入控制器：虚拟摇杆 + 技能按钮 + 暂停按钮。
## 全平台显示（桌面端鼠标按住也可移动）。所有尺寸走 UIScale 动态缩放。

# 基础常量（未缩放，实际使用时乘 UIScale.scale）
const JOYSTICK_RADIUS_BASE := 60.0
const JOYSTICK_DEAD_ZONE_BASE := 15.0
const JOYSTICK_KNOB_RADIUS_BASE := 25.0
const JOYSTICK_BG_COLOR := Color(0.2, 0.2, 0.2, 0.5)
const JOYSTICK_KNOB_COLOR := Color(0.85, 0.85, 0.85, 0.75)
const JOYSTICK_OUTLINE_COLOR := Color(0.45, 0.45, 0.45, 0.6)

const SKILL_BUTTON_SIZE_BASE := 64.0
const SKILL_BUTTON_MARGIN_BASE := 12.0
const SKILL_BUTTONS_MARGIN_BASE := 18.0
const PAUSE_BUTTON_SIZE_BASE := 56.0

const SKILL_COLORS := {
	"sword": Color(0.95, 0.55, 0.2),
	"laser": Color(0.2, 0.7, 0.95),
	"timestop": Color(0.7, 0.3, 0.9),
}
const SKILL_LABELS := {
	"sword": "巨剑",
	"laser": "激光",
	"timestop": "时停",
}

# 触摸状态
var _joystick_touch_index: int = -1
var _joystick_center: Vector2 = Vector2.ZERO
var _joystick_current: Vector2 = Vector2.ZERO
var _is_joystick_active: bool = false
var _mouse_move_active := false

# 技能按钮
var _skill_buttons: Dictionary = {}
var _pause_button: Button = null
var _skill_unlocked: Dictionary = {"sword": false, "laser": false, "timestop": false}
var _skill_charges: Dictionary = {"sword": 0, "laser": 0, "timestop": 0}
var _skill_cooldowns: Dictionary = {"sword": 0.0, "laser": 0.0, "timestop": 0.0}
var _skill_cd_totals: Dictionary = {"sword": 6.0, "laser": 5.0, "timestop": 8.0}

# 输出方向
var move_direction: Vector2 = Vector2.ZERO

# 绘制节点
var _draw_node: Control
var _skill_container: Control

# 玩家引用
var _player: Player = null

# 缓存缩放后的尺寸
var _joy_r: float = 60.0
var _joy_dead: float = 15.0
var _joy_knob: float = 25.0
var _btn_size: float = 64.0


func _ready() -> void:
	layer = 100
	# 暂停时本层仍可交互（暂停按钮需响应）
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 绘制节点（摇杆）
	_draw_node = Control.new()
	_draw_node.name = "JoystickDraw"
	_draw_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_node.draw.connect(_on_draw)
	add_child(_draw_node)
	# 技能/按钮容器
	_skill_container = Control.new()
	_skill_container.name = "SkillContainer"
	_skill_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_skill_container.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_skill_container)
	# 信号
	GameEvents.skill_state_changed.connect(_on_skill_state_changed)
	GameEvents.game_started.connect(_on_game_started)
	GameEvents.game_over.connect(_on_game_over)
	UIScale.scale_changed.connect(_on_scale_changed)
	# 应用缩放并创建按钮
	_apply_scale()
	_create_pause_button()
	_create_skill_buttons()
	visible = false
	call_deferred("_find_player")


func _apply_scale() -> void:
	_joy_r = UIScale.s(JOYSTICK_RADIUS_BASE)
	_joy_dead = UIScale.s(JOYSTICK_DEAD_ZONE_BASE)
	_joy_knob = UIScale.s(JOYSTICK_KNOB_RADIUS_BASE)
	_btn_size = UIScale.s(SKILL_BUTTON_SIZE_BASE)


func _on_scale_changed(_new_scale: float) -> void:
	_apply_scale()
	# 重建按钮（尺寸变了）
	for c in _skill_container.get_children():
		c.queue_free()
	_skill_buttons.clear()
	_create_pause_button()
	_create_skill_buttons()


func _on_game_started() -> void:
	visible = true


func _on_game_over() -> void:
	visible = false


func _find_player() -> void:
	_player = get_tree().get_first_node_in_group("player") as Player


# ============================================================
#  暂停按钮（右上角）
# ============================================================
func _create_pause_button() -> void:
	var sz := UIScale.s(PAUSE_BUTTON_SIZE_BASE)
	var btn := Button.new()
	btn.name = "PauseBtn"
	btn.text = "⏸"
	btn.custom_minimum_size = Vector2(sz, sz)
	btn.anchor_left = 1.0
	btn.anchor_top = 0.0
	btn.anchor_right = 1.0
	btn.anchor_bottom = 0.0
	btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	btn.offset_left = -sz - UIScale.s(SKILL_BUTTONS_MARGIN_BASE)
	btn.offset_top = UIScale.s(SKILL_BUTTONS_MARGIN_BASE)
	btn.offset_right = -UIScale.s(SKILL_BUTTONS_MARGIN_BASE)
	btn.offset_bottom = UIScale.s(SKILL_BUTTONS_MARGIN_BASE) + sz
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.18, 0.25, 0.85)
	style.set_corner_radius_all(UIScale.s(8))
	style.set_border_width_all(UIScale.s(2))
	style.border_color = Color(0.4, 0.45, 0.55, 0.8)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_color_override("font_color", Color(0.9, 0.92, 0.95))
	btn.add_theme_font_size_override("font_size", UIScale.font(24))
	btn.pressed.connect(_on_pause_button_pressed)
	_skill_container.add_child(btn)
	_pause_button = btn


func _on_pause_button_pressed() -> void:
	# 模拟按 ESC（pause 动作），复用 Main 的暂停逻辑
	var ev := InputEventAction.new()
	ev.action = "pause"
	ev.pressed = true
	get_viewport().push_input(ev)


# ============================================================
#  技能按钮（右下角竖排）
# ============================================================
func _create_skill_buttons() -> void:
	var skill_ids = ["sword", "laser", "timestop"]
	var margin := UIScale.s(SKILL_BUTTON_MARGIN_BASE)
	var buttons_margin := UIScale.s(SKILL_BUTTONS_MARGIN_BASE)
	for i in range(skill_ids.size()):
		var skill_id = skill_ids[i]
		var btn := Button.new()
		btn.name = "SkillBtn_" + skill_id
		btn.text = SKILL_LABELS.get(skill_id, "?")
		btn.custom_minimum_size = Vector2(_btn_size, _btn_size)
		# 右下角，竖排
		btn.anchor_left = 1.0
		btn.anchor_top = 1.0
		btn.anchor_right = 1.0
		btn.anchor_bottom = 1.0
		btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		btn.grow_vertical = Control.GROW_DIRECTION_BEGIN
		btn.offset_left = -_btn_size - margin - buttons_margin
		btn.offset_top = -_btn_size - margin - buttons_margin - i * (_btn_size + margin)
		btn.offset_right = -margin - buttons_margin
		btn.offset_bottom = -margin - buttons_margin - i * (_btn_size + margin) + _btn_size
		# 样式
		var btn_color = SKILL_COLORS.get(skill_id, Color(0.3, 0.3, 0.3))
		var style := StyleBoxFlat.new()
		style.bg_color = btn_color
		style.set_corner_radius_all(UIScale.s(10))
		style.set_border_width_all(UIScale.s(2))
		style.border_color = Color(0.1, 0.1, 0.1)
		btn.add_theme_stylebox_override("normal", style)
		var sp := style.duplicate()
		sp.bg_color = btn_color.darkened(0.25)
		btn.add_theme_stylebox_override("pressed", sp)
		var sd := style.duplicate()
		sd.bg_color = Color(0.2, 0.2, 0.2, 0.5)
		btn.add_theme_stylebox_override("disabled", sd)
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_font_size_override("font_size", UIScale.font(15))
		var sid = skill_id
		btn.pressed.connect(func(): _on_skill_button_pressed(sid))
		_skill_container.add_child(btn)
		_skill_buttons[skill_id] = btn


func _on_skill_button_pressed(skill_id: String) -> void:
	if _player == null:
		_find_player()
	if _player == null:
		return
	var active_skills = _player.get_node_or_null("ActiveSkills") as ActiveSkills
	if active_skills and active_skills.has_method("cast_skill"):
		active_skills.cast_skill(skill_id)


func _on_skill_state_changed(skill_id: String, unlocked: bool, charges: int, cd_remaining: float, cd_total: float) -> void:
	_skill_unlocked[skill_id] = unlocked
	_skill_charges[skill_id] = charges
	_skill_cooldowns[skill_id] = cd_remaining
	if cd_total > 0:
		_skill_cd_totals[skill_id] = cd_total
	if _skill_buttons.has(skill_id):
		var btn = _skill_buttons[skill_id]
		btn.disabled = not unlocked or charges <= 0 or cd_remaining > 0
		if unlocked:
			btn.text = "%s\n×%d" % [SKILL_LABELS.get(skill_id, "?"), charges]
		else:
			btn.text = SKILL_LABELS.get(skill_id, "?")


# ============================================================
#  输入处理
# ============================================================
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_mouse_click(event.position)
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_handle_mouse_drag(event.position)


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		# 右侧 35% 区域留给按钮（技能/暂停）
		var screen_w = get_viewport().get_visible_rect().size.x
		if event.position.x > screen_w * 0.65:
			return
		if _joystick_touch_index == -1:
			_joystick_touch_index = event.index
			_joystick_center = event.position
			_joystick_current = event.position
			_is_joystick_active = true
			_draw_node.queue_redraw()
	else:
		if event.index == _joystick_touch_index:
			_joystick_touch_index = -1
			_is_joystick_active = false
			_joystick_current = _joystick_center
			move_direction = Vector2.ZERO
			_draw_node.queue_redraw()


func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index == _joystick_touch_index:
		_joystick_current = event.position
		var diff = _joystick_current - _joystick_center
		var dist = diff.length()
		if dist > _joy_dead:
			move_direction = diff.normalized()
			if dist > _joy_r:
				_joystick_current = _joystick_center + diff.normalized() * _joy_r
		else:
			move_direction = Vector2.ZERO
		_draw_node.queue_redraw()


func _handle_mouse_click(click_pos: Vector2) -> void:
	# 鼠标模式：按住左键朝点击方向移动（不画伪摇杆，避免视觉干扰）
	if _player == null:
		_find_player()
	if _player == null:
		return
	var player_screen_pos = _player.global_position
	var canvas_xform := get_viewport().get_canvas_transform()
	player_screen_pos = canvas_xform * _player.global_position
	var direction = click_pos - player_screen_pos
	if direction.length() > 10.0:
		move_direction = direction.normalized()
		_mouse_move_active = true
		# 鼠标模式不画摇杆（_is_joystick_active 保持 false）
	else:
		_mouse_move_active = false
		move_direction = Vector2.ZERO


func _handle_mouse_drag(drag_pos: Vector2) -> void:
	_handle_mouse_click(drag_pos)


func _process(_delta: float) -> void:
	if (_is_joystick_active or _mouse_move_active) and move_direction.length() > 0.1:
		_release_move_input()
		if move_direction.x < -0.1:
			_press_action("move_left")
		if move_direction.x > 0.1:
			_press_action("move_right")
		if move_direction.y < -0.1:
			_press_action("move_up")
		if move_direction.y > 0.1:
			_press_action("move_down")
	elif not _is_joystick_active and not _mouse_move_active:
		_release_move_input()
	if _mouse_move_active and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_mouse_move_active = false
		move_direction = Vector2.ZERO


func _press_action(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	event.strength = 1.0
	get_viewport().push_input(event)


func _release_action(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = false
	event.strength = 0.0
	get_viewport().push_input(event)


func _release_move_input() -> void:
	_release_action("move_left")
	_release_action("move_right")
	_release_action("move_up")
	_release_action("move_down")


# ============================================================
#  绘制（摇杆 + 技能冷却遮罩）
# ============================================================
func _on_draw() -> void:
	# 摇杆（仅触屏拖动时显示，鼠标模式不显示）
	if _is_joystick_active:
		_draw_circle_with_outline(_draw_node, _joystick_center, _joy_r, JOYSTICK_BG_COLOR, UIScale.s(3.0), JOYSTICK_OUTLINE_COLOR)
		var knob_pos = _joystick_current
		var diff = _joystick_current - _joystick_center
		if diff.length() > _joy_r:
			knob_pos = _joystick_center + diff.normalized() * _joy_r
		_draw_circle_filled(_draw_node, knob_pos, _joy_knob, JOYSTICK_KNOB_COLOR)
	# 技能按钮冷却遮罩（覆盖在按钮上方）
	for skill_id in _skill_buttons:
		var btn: Button = _skill_buttons[skill_id]
		var cd: float = _skill_cooldowns.get(skill_id, 0.0)
		if cd > 0:
			var total: float = _skill_cd_totals.get(skill_id, 1.0)
			var ratio: float = clampf(cd / total, 0.0, 1.0)
			var g := btn.get_global_rect()
			# 在 draw_node（全屏）坐标系里画遮罩
			var mask_h: float = g.size.y * ratio
			_draw_node.draw_rect(Rect2(g.position.x, g.position.y, g.size.x, mask_h), Color(0, 0, 0, 0.6))
			# 倒计时数字
			var cd_str := "%.0f" % cd
			var font := ThemeDB.get_default_theme().default_font
			var fs := UIScale.font(18)
			var tw: float = font.get_string_size(cd_str, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
			_draw_node.draw_string(font, g.get_center() + Vector2(-tw * 0.5, fs * 0.35), cd_str, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, Color(1, 0.9, 0.5))
		# 锁图标（未解锁）
		if not _skill_unlocked.get(skill_id, false):
			var g2 := btn.get_global_rect()
			var c := g2.get_center()
			var r := minf(g2.size.x, g2.size.y) * 0.18
			_draw_node.draw_rect(Rect2(c.x - r, c.y - r * 0.2, r * 2, r * 1.4), Color(0.1, 0.1, 0.12, 0.85))
			_draw_node.draw_arc(c + Vector2(0, -r * 0.4), r * 0.7, PI, TAU, 12, Color(0.1, 0.1, 0.12, 0.85), UIScale.s(2.0), false)


func _draw_circle_with_outline(control: Control, center: Vector2, radius: float, color: Color, outline_width: float, outline_color: Color) -> void:
	control.draw_circle(center, radius, color)
	var points = PackedVector2Array()
	for i in range(33):
		var angle = i * TAU / 32.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	control.draw_polyline(points, outline_color, outline_width, true)


func _draw_circle_filled(control: Control, center: Vector2, radius: float, color: Color) -> void:
	control.draw_circle(center, radius, color)
