class_name GridBackground
extends Node2D
## 跟随相机的网格背景。每帧根据相机位置重绘，制造无限网格效果。

@export var cell_size: float = 64.0
@export var color_major: Color = Color(1, 1, 1, 0.06)
@export var color_minor: Color = Color(1, 1, 1, 0.03)
@export var base_color: Color = Color(0.07, 0.09, 0.13)

var _camera: Camera2D = null


func _ready() -> void:
	z_index = -100
	z_as_relative = false
	_camera = get_viewport().get_camera_2d()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var vp := get_viewport_rect().size
	var cam_pos := Vector2.ZERO
	var zoom := Vector2.ONE
	if _camera and is_instance_valid(_camera):
		cam_pos = _camera.get_screen_center_position()
		zoom = _camera.zoom

	# 视口四角的世界坐标（考虑 zoom）
	var half_ext := vp * 0.5 / zoom
	var top_left := cam_pos - half_ext
	var bot_right := cam_pos + half_ext

	# 背景填充
	draw_rect(Rect2(top_left, bot_right - top_left), base_color)

	# 次级网格
	_draw_grid(top_left, bot_right, cell_size * 0.5, color_minor)
	# 主网格
	_draw_grid(top_left, bot_right, cell_size, color_major)


func _draw_grid(top_left: Vector2, bot_right: Vector2, step: float, col: Color) -> void:
	var start_x := floorf(top_left.x / step) * step
	var end_x := bot_right.x
	var start_y := floorf(top_left.y / step) * step
	var end_y := bot_right.y
	var x := start_x
	while x <= end_x:
		draw_line(Vector2(x, top_left.y), Vector2(x, bot_right.y), col, 1.0)
		x += step
	var y := start_y
	while y <= end_y:
		draw_line(Vector2(top_left.x, y), Vector2(bot_right.x, y), col, 1.0)
		y += step
