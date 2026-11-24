## 柱状图控件：统计看板的日 / 周视图共用，纯 _draw 绘制。
class_name BarChart
extends Control

var items: Array = []:
	set(v):
		items = v
		queue_redraw()

var bar_color: Color = UIKit.TOMATO:
	set(v):
		bar_color = v
		queue_redraw()

var unit: String = "个"


func _init() -> void:
	custom_minimum_size = Vector2(0, 200)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var font := UIKit.ui_font()
	var bold := UIKit.ui_font(700)
	var pad_bottom := 26.0
	var pad_top := 22.0
	var area_h := maxf(10.0, size.y - pad_bottom - pad_top)
	# 基准线
	draw_line(Vector2(0, size.y - pad_bottom), Vector2(size.x, size.y - pad_bottom), UIKit.LINE, 1.0)
	if items.is_empty():
		draw_string(font, Vector2(0, size.y * 0.5), "暂无数据", HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, UIKit.MUTED)
		return
	var total := 0
	for it in items:
		total += int(it.get("value", 0))
	if total <= 0:
		draw_string(bold, Vector2(0, size.y * 0.46), "还没有完成的番茄", HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, UIKit.MUTED)
		draw_string(font, Vector2(0, size.y * 0.46 + 26), "完成一次专注后，这里就会出现柱状图", HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, Color("#a7b0c0"))
		return
	var max_v := 1
	for it in items:
		max_v = maxi(max_v, int(it.get("value", 0)))
	var n := items.size()
	var slot := size.x / float(n)
	var bar_w := minf(44.0, slot * 0.52)
	for i in range(n):
		var it: Dictionary = items[i]
		var v := int(it.get("value", 0))
		var h := area_h * (float(v) / float(max_v))
		var base_y := size.y - pad_bottom
		var x := slot * (i + 0.5) - bar_w * 0.5
		var rect := Rect2(Vector2(x, base_y - h), Vector2(bar_w, maxf(h, 2.0)))
		var c := bar_color
		if v <= 0:
			c = Color("#e8ecf4")
		var sb := StyleBoxFlat.new()
		sb.bg_color = c
		sb.set_corner_radius_all(int(bar_w * 0.28))
		draw_style_box(sb, rect)
		if v > 0:
			draw_string(bold, Vector2(x - 10, rect.position.y - 6), str(v), HORIZONTAL_ALIGNMENT_CENTER, bar_w + 20, 14, UIKit.TEXT)
		draw_string(font, Vector2(x - 16, base_y + 18), String(it.get("label", "")), HORIZONTAL_ALIGNMENT_CENTER, bar_w + 32, 12, UIKit.MUTED)
