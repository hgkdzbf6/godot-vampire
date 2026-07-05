extends Node
## UI 全局缩放系统（Autoload）。
## 根据屏幕短边相对设计基准（720）计算缩放系数，
## 提供统一的 s()/font()/sv() 辅助，让所有 UI 字号/尺寸在小屏（手机/平板）上成比例放大。
##
## 设计基准：短边 720px → scale = 1.0（桌面 1280×720 不变）
##           短边更小（手机横屏逻辑视口短边可能 ~400-540）→ scale 放大至 ~1.4-1.6
##
## 用法：
##   add_theme_font_size_override("font_size", UIScale.font(22))
##   custom_minimum_size = UIScale.sv(Vector2(280, 16))
##   var r := UIScale.s(60.0)   # 自绘半径

signal scale_changed(new_scale: float)

const DESIGN_SHORT_SIDE := 720.0   # 设计基准短边
const SCALE_MIN := 1.0
const SCALE_MAX := 1.6

var scale: float = 1.0
var is_touchscreen: bool = false


func _ready() -> void:
	is_touchscreen = DisplayServer.is_touchscreen_available()
	_recompute()
	# 监听窗口尺寸变化（窗口缩放/旋转）
	get_tree().root.size_changed.connect(_recompute)


func _recompute() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var size := vp.get_visible_rect().size
	if size.x <= 0 or size.y <= 0:
		return
	var short_side := minf(size.x, size.y)
	var new_scale := clampf(short_side / DESIGN_SHORT_SIDE, SCALE_MIN, SCALE_MAX)
	if !is_equal_approx(new_scale, scale):
		scale = new_scale
		scale_changed.emit(scale)


## 缩放一个数值（字号、半径、尺寸等）。
func s(value: float) -> float:
	return value * scale


## 缩放字号，返回 int（add_theme_font_size_override 需要 int）。
func font(base: int) -> int:
	return int(round(base * scale))


## 缩放 Vector2（custom_minimum_size 等）。
func sv(vec: Vector2) -> Vector2:
	return vec * scale


## 缩放 Rect2。
func sr(rect: Rect2) -> Rect2:
	return Rect2(rect.position * scale, rect.size * scale)


## 递归给节点子树里所有 Label/Button/RichTextLabel/LineEdit 应用字号缩放。
## 首次调用读取控件当前字号存入 meta（_ui_base_font_size），之后按 meta × scale 应用。
func apply_font_scale(node: Node) -> void:
	for child in node.get_children():
		if child is Label or child is Button or child is RichTextLabel or child is LineEdit:
			var base: int
			if child.has_meta("_ui_base_font_size"):
				base = int(child.get_meta("_ui_base_font_size"))
			else:
				# 首次：读取当前生效字号（含 .tscn 里的 theme_override）并存档
				base = int(child.get_theme_font_size("font_size"))
				if base <= 0:
					base = 16
				child.set_meta("_ui_base_font_size", base)
			child.add_theme_font_size_override("font_size", int(round(base * scale)))
		# 递归子节点
		apply_font_scale(child)
