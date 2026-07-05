class_name XPGem
extends Area2D
## 经验宝石。被玩家磁吸后自动收集，纯代码自绘（无外部素材）。

@export var value: int = 1
@export var magnet_range: float = 110.0
@export var collect_range: float = 26.0
@export var attract_speed := 380.0
@export var max_speed := 620.0

var _vel := Vector2.ZERO
var _attracted := false
var _player: Node2D = null
var _scale := 1.0
var _color := Color("8fffae")

@onready var _shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	monitoring = true
	monitorable = true
	body_entered.connect(_on_body_entered)
	_player = get_tree().get_first_node_in_group("player")


func setup(p_value: int) -> void:
	value = p_value
	_scale = clampf(0.7 + float(value) * 0.18, 0.7, 2.0)
	if value >= GameData.XP_GEM_VALUE_BIG:
		_color = Color("7be0ff")
	if _shape:
		(_shape.shape as CircleShape2D).radius = GameData.XP_GEM_RADIUS * _scale


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		if not _player:
			return
	var to_p := _player.global_position - global_position
	var dist := to_p.length()
	var pickup: float = GameData.PLAYER_PICKUP_RANGE
	if "pickup_range" in _player:
		pickup = _player.pickup_range
	if not _attracted and dist < (magnet_range + pickup):
		_attracted = true
	if _attracted:
		var dir := to_p.normalized()
		var speed := minf(max_speed, attract_speed + (1.0 - clampf(dist / 200.0, 0.0, 1.0)) * attract_speed)
		_vel = _vel.lerp(dir * speed, 0.25)
		global_position += _vel * delta
		if dist < collect_range:
			_collect()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_collect()


func _collect() -> void:
	GameEvents.xp_collected.emit(value)
	queue_free()


func _draw() -> void:
	var r := GameData.XP_GEM_RADIUS * _scale
	# 外发光
	draw_circle(Vector2.ZERO, r * 1.8, Color(_color.r, _color.g, _color.b, 0.25))
	# 主体（菱形）
	var pts := PackedVector2Array([
		Vector2(0, -r),
		Vector2(r * 0.75, 0),
		Vector2(0, r),
		Vector2(-r * 0.75, 0),
	])
	draw_colored_polygon(pts, _color)
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color.WHITE * 0.9, 1.2)
