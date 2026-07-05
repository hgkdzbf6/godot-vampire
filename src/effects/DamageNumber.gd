class_name DamageNumber
extends Node2D
## 漂浮的伤害数字，纯代码绘制。

var _text := "0"
var _color: Color = Color.WHITE
var _life := 0.7
var _age := 0.0
var _vel := Vector2(0, -60)
var _crit := false
var _font: Font = null
var _font_size := 18

@onready var _label: Label = $Label


func setup(text: String, color: Color, crit: bool = false) -> void:
	_text = text
	_color = color
	_crit = crit


func _ready() -> void:
	_label.text = _text
	_label.add_theme_color_override("font_color", _color)
	_label.add_theme_font_size_override("font_size", 24 if _crit else _font_size)
	if _crit:
		_label.add_theme_font_size_override("font_size", 28)
		_label.modulate = Color(1.6, 1.6, 1.6)
	_label.z_index = 100
	_label.pivot_offset = _label.size * 0.5


func _process(delta: float) -> void:
	_age += delta
	position += _vel * delta
	_vel.y += 140 * delta  # 向上抛出后下落感
	# 透明度淡出
	var a := clampf(1.0 - _age / _life, 0.0, 1.0)
	_label.modulate.a = a
	if _age >= _life:
		queue_free()
