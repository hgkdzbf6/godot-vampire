class_name TouchInput
extends CanvasLayer
## 触摸输入控制器：虚拟摇杆 + 技能按钮
## 支持手机/平板的触摸操作，桌面端也可用

# 虚拟摇杆参数
const JOYSTICK_RADIUS := 60.0
const JOYSTICK_DEAD_ZONE := 15.0
const JOYSTICK_KNOB_RADIUS := 25.0
const JOYSTICK_BG_COLOR := Color(0.2, 0.2, 0.2, 0.5)
const JOYSTICK_KNOB_COLOR := Color(0.8, 0.8, 0.8, 0.7)
const JOYSTICK_OUTLINE_COLOR := Color(0.4, 0.4, 0.4, 0.6)

# 技能按钮参数
const SKILL_BUTTON_SIZE := 60.0
const SKILL_BUTTON_MARGIN := 10.0
const SKILL_BUTTONS_MARGIN := 16.0
const SKILL_COLORS := {
	"sword": Color(0.8, 0.4, 0.2),
	"laser": Color(0.2, 0.6, 0.9),
	"timestop": Color(0.6, 0.2, 0.8),
}
const SKILL_LABELS := {
	"sword": "Q",
	"laser": "E",
	"timestop": "空格",
}

# 触摸状态
var _joystick_touch_index: int = -1
var _joystick_center: Vector2 = Vector2.ZERO
var _joystick_current: Vector2 = Vector2.ZERO
var _is_joystick_active: bool = false

# 技能按钮
var _skill_buttons: Dictionary = {}
var _skill_unlocked: Dictionary = {"sword": false, "laser": false, "timestop": false}
var _skill_charges: Dictionary = {"sword": 0, "laser": 0, "timestop": 0}
var _skill_cooldowns: Dictionary = {"sword": 0.0, "laser": 0.0, "timestop": 0.0}

# 输出方向
var move_direction: Vector2 = Vector2.ZERO

# 绘制节点
var _draw_node: Control
var _skill_container: Control

# 玩家引用（用于直接调用技能）
var _player: Player = null


func _ready() -> void:
	layer = 100
	# 创建绘制节点（用于摇杆）
	_draw_node = Control.new()
	_draw_node.name = "JoystickDraw"
	_draw_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_node.draw.connect(_on_draw)
	add_child(_draw_node)
	# 创建技能按钮容器
	_skill_container = Control.new()
	_skill_container.name = "SkillContainer"
	_skill_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_skill_container.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_skill_container)
	# 连接技能状态信号
	GameEvents.skill_state_changed.connect(_on_skill_state_changed)
	GameEvents.game_started.connect(_on_game_started)
	GameEvents.game_over.connect(_on_game_over)
	# 创建技能按钮
	_create_skill_buttons()
	# 默认隐藏（游戏开始时显示）
	visible = false
	# 延迟获取玩家引用
	call_deferred("_find_player")


func _on_game_started() -> void:
	visible = true


func _on_game_over() -> void:
	visible = false


func _find_player() -> void:
	_player = get_tree().get_first_node_in_group("player") as Player


func _create_skill_buttons() -> void:
	var skill_ids = ["sword", "laser", "timestop"]
	for i in range(skill_ids.size()):
		var skill_id = skill_ids[i]
		var btn := Button.new()
		btn.name = "SkillBtn_" + skill_id
		btn.text = SKILL_LABELS.get(skill_id, "?")
		btn.custom_minimum_size = Vector2(SKILL_BUTTON_SIZE, SKILL_BUTTON_SIZE)
		# 位置：右下角
		var x_offset = -SKILL_BUTTON_SIZE - SKILL_BUTTON_MARGIN - SKILL_BUTTONS_MARGIN
		var y_offset = -SKILL_BUTTON_SIZE - SKILL_BUTTON_MARGIN - SKILL_BUTTONS_MARGIN - i * (SKILL_BUTTON_SIZE + SKILL_BUTTON_MARGIN)
		btn.position = Vector2(x_offset, y_offset)
		btn.anchor_left = 1.0
		btn.anchor_top = 1.0
		btn.anchor_right = 1.0
		btn.anchor_bottom = 1.0
		btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		btn.grow_vertical = Control.GROW_DIRECTION_BEGIN
		# 样式
		var btn_color = SKILL_COLORS.get(skill_id, Color(0.3, 0.3, 0.3))
		var style := StyleBoxFlat.new()
		style.bg_color = btn_color
		style.set_corner_radius_all(8)
		style.set_border_width_all(2)
		style.border_color = Color(0.1, 0.1, 0.1)
		btn.add_theme_stylebox_override("normal", style)
		var style_pressed = style.duplicate()
		style_pressed.bg_color = btn_color.darkened(0.2)
		btn.add_theme_stylebox_override("pressed", style_pressed)
		var style_disabled = style.duplicate()
		style_disabled.bg_color = Color(0.2, 0.2, 0.2, 0.5)
		btn.add_theme_stylebox_override("disabled", style_disabled)
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_font_size_override("font_size", 16)
		# 连接信号
		var sid = skill_id
		btn.pressed.connect(func(): _on_skill_button_pressed(sid))
		_skill_container.add_child(btn)
		_skill_buttons[skill_id] = btn


func _on_skill_button_pressed(skill_id: String) -> void:
	# 直接调用 ActiveSkills 的释放方法
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
	if _skill_buttons.has(skill_id):
		var btn = _skill_buttons[skill_id]
		btn.disabled = not unlocked or charges <= 0 or cd_remaining > 0
		if unlocked:
			btn.text = "%s\n%d" % [SKILL_LABELS.get(skill_id, "?"), charges]
		else:
			btn.text = SKILL_LABELS.get(skill_id, "?")


func _unhandled_input(event: InputEvent) -> void:
	# 处理触摸事件（仅处理摇杆部分）
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)
	# 处理鼠标点击移动
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_mouse_click(event.position)
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_handle_mouse_drag(event.position)


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		# 检查是否点击了技能按钮区域（右侧 35%）
		var screen_w = get_viewport().get_visible_rect().size.x
		if event.position.x > screen_w * 0.65:
			return  # 让按钮控件自己处理
		# 开始摇杆
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
		if dist > JOYSTICK_DEAD_ZONE:
			move_direction = diff.normalized()
			if dist > JOYSTICK_RADIUS:
				_joystick_current = _joystick_center + diff.normalized() * JOYSTICK_RADIUS
		else:
			move_direction = Vector2.ZERO
		_draw_node.queue_redraw()


func _handle_mouse_click(click_pos: Vector2) -> void:
	if _player == null:
		_find_player()
	if _player == null:
		return
	# 计算从玩家到点击位置的方向
	var player_screen_pos = _player.global_position
	var camera = get_viewport().get_camera_2d()
	if camera:
		# 世界坐标 → 屏幕坐标：用 viewport 的 canvas_transform
		var canvas_xform := get_viewport().get_canvas_transform()
		player_screen_pos = canvas_xform * _player.global_position
	var direction = click_pos - player_screen_pos
	if direction.length() > 10.0:
		move_direction = direction.normalized()
		_mouse_move_active = true
		_is_joystick_active = true
		_joystick_center = player_screen_pos
		_joystick_current = click_pos
		_draw_node.queue_redraw()


func _handle_mouse_drag(drag_pos: Vector2) -> void:
	_handle_mouse_click(drag_pos)


var _mouse_move_active := false

func _process(_delta: float) -> void:
	# 持续发送移动输入（模拟按键按住）
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
	# 鼠标松开时停止移动
	if _mouse_move_active and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_mouse_move_active = false
		_is_joystick_active = false
		move_direction = Vector2.ZERO
		_draw_node.queue_redraw()


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


func _on_draw() -> void:
	if _is_joystick_active:
		# 绘制摇杆背景圆
		_draw_circle_with_outline(_draw_node, _joystick_center, JOYSTICK_RADIUS, JOYSTICK_BG_COLOR, 3.0, JOYSTICK_OUTLINE_COLOR)
		# 绘制摇杆手柄
		var knob_pos = _joystick_current
		var diff = _joystick_current - _joystick_center
		if diff.length() > JOYSTICK_RADIUS:
			knob_pos = _joystick_center + diff.normalized() * JOYSTICK_RADIUS
		_draw_circle_filled(_draw_node, knob_pos, JOYSTICK_KNOB_RADIUS, JOYSTICK_KNOB_COLOR)


func _draw_circle_with_outline(control: Control, center: Vector2, radius: float, color: Color, outline_width: float, outline_color: Color) -> void:
	control.draw_circle(center, radius, color)
	var points = PackedVector2Array()
	for i in range(33):
		var angle = i * TAU / 32.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	control.draw_polyline(points, outline_color, outline_width, true)


func _draw_circle_filled(control: Control, center: Vector2, radius: float, color: Color) -> void:
	control.draw_circle(center, radius, color)
