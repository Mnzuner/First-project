## 环形倒计时控件：纯 _draw 绘制，避免依赖贴图资源。
class_name RingTimer
extends Control

var progress: float = 0.0:
	set(v):
		progress = clampf(v, 0.0, 1.0)
		queue_redraw()

var time_text: String = "25:00":
	set(v):
		time_text = v
		queue_redraw()

var phase_text: String = "专注中":
	set(v):
		phase_text = v
		queue_redraw()

var sub_text: String = "":
	set(v):
		sub_text = v
		queue_redraw()

var ring_color: Color = UIKit.TOMATO:
	set(v):
		ring_color = v
		queue_redraw()

var track_color: Color = Color("#eceff6")
var thickness: float = 22.0


func _init() -> void:
	custom_minimum_size = Vector2(320, 320)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var center := size / 2.0
	var radius := minf(size.x, size.y) / 2.0 - thickness
	if radius <= 0.0:
		return
	draw_arc(center, radius, 0.0, TAU, 160, track_color, thickness, true)
	if progress > 0.001:
		draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * progress, 160, ring_color, thickness, true)
		# 进度端点加个小圆点，视觉上更像“走动的秒针”。
		var tip := center + Vector2(cos(-PI * 0.5 + TAU * progress), sin(-PI * 0.5 + TAU * progress)) * radius
		draw_circle(tip, thickness * 0.5, ring_color)

	var font := UIKit.ui_font(700)
	draw_string(font, Vector2(0, center.y - 74), phase_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, UIKit.MUTED)
	draw_string(font, Vector2(0, center.y + 18), time_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 60, UIKit.TEXT)
	if sub_text != "":
		draw_string(UIKit.ui_font(), Vector2(0, center.y + 62), sub_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, UIKit.MUTED)
