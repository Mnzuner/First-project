## UI 工具库：统一色板、字体、圆角卡片与按钮样式，避免各视图各写一套。
class_name UIKit
extends RefCounted

const BG := Color("#f2f4f8")
const CARD := Color("#ffffff")
const TEXT := Color("#1f2430")
const MUTED := Color("#7b8496")
const LINE := Color("#e3e8f1")
const TOMATO := Color("#e5533d")
const GREEN := Color("#3fa76b")
const GOLD := Color("#d99a0b")
const BLUE := Color("#3f7fe0")
const SOFT := Color("#eef1f7")

static var _fonts := {}


## 中文字体：优先系统中文字体，缺字时按顺序回退。
static func ui_font(weight: int = 400) -> SystemFont:
	if _fonts.has(weight):
		return _fonts[weight]
	var f := SystemFont.new()
	f.font_names = PackedStringArray([
		"Microsoft YaHei UI", "Microsoft YaHei", "SimHei",
		"Noto Sans CJK SC", "Source Han Sans SC", "PingFang SC", "Arial",
	])
	f.font_weight = weight
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	_fonts[weight] = f
	return f


static func box(color: Color, radius: int = 12, border: int = 0, border_color: Color = LINE, pad: int = 16) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border)
	sb.border_color = border_color
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	sb.anti_aliasing = true
	return sb


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = ui_font()
	t.default_font_size = 15
	t.set_stylebox("panel", "PanelContainer", box(CARD, 16))
	t.set_stylebox("panel", "Panel", box(CARD, 16))
	t.set_stylebox("panel", "PopupPanel", box(CARD, 14, 1))
	t.set_stylebox("panel", "PopupMenu", box(CARD, 12, 1))
	t.set_stylebox("panel", "TabContainer", box(SOFT, 12))
	t.set_stylebox("panel", "Window", box(CARD, 14, 1))
	t.set_color("font_color", "Label", TEXT)
	_style_windows(t)
	_style_buttons(t)
	_style_fields(t)
	_style_tabs(t)
	_style_toggles(t)
	_style_slider(t)
	_style_scrollbars(t)
	return t


## 普通按钮（未被 style_button 覆盖的，例如对话框按钮、下拉框）。
static func _style_buttons(t: Theme) -> void:
	t.set_stylebox("normal", "Button", field_box(CARD))
	t.set_stylebox("hover", "Button", field_box(SOFT))
	t.set_stylebox("pressed", "Button", field_box(Color("#e4eaf4")))
	t.set_stylebox("disabled", "Button", field_box(Color("#f4f6fa")))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", TEXT)
	t.set_color("font_focus_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", MUTED)
	t.set_color("font_hover_pressed_color", "Button", TEXT)

	# 下拉框：浅底、细边框、自绘箭头
	t.set_stylebox("normal", "OptionButton", field_box(CARD))
	t.set_stylebox("hover", "OptionButton", field_box(SOFT))
	t.set_stylebox("pressed", "OptionButton", field_box(Color("#e4eaf4")))
	t.set_stylebox("disabled", "OptionButton", field_box(Color("#f4f6fa")))
	t.set_stylebox("focus", "OptionButton", field_box(CARD, BLUE))
	t.set_color("font_color", "OptionButton", TEXT)
	t.set_color("font_hover_color", "OptionButton", TEXT)
	t.set_color("font_pressed_color", "OptionButton", TEXT)
	t.set_color("font_focus_color", "OptionButton", TEXT)
	t.set_color("font_disabled_color", "OptionButton", MUTED)
	t.set_icon("arrow", "OptionButton", chevron_texture(16, MUTED))
	t.set_constant("arrow_margin", "OptionButton", 10)


## 弹窗（AcceptDialog / ConfirmationDialog 等内嵌窗口）。
static func _style_windows(t: Theme) -> void:
	var frame := box(CARD, 14, 1, LINE, 14)
	frame.content_margin_top = 34
	t.set_stylebox("embedded_border", "Window", frame)
	t.set_stylebox("embedded_unfocused_border", "Window", frame)
	t.set_color("title_color", "Window", TEXT)
	t.set_font("title_font", "Window", ui_font(700))
	t.set_font_size("title_font_size", "Window", 16)


## 输入框 / 数字框。
static func _style_fields(t: Theme) -> void:
	for type_name in ["LineEdit", "SpinBox"]:
		t.set_stylebox("normal", type_name, field_box(CARD, LINE, 8))
		t.set_stylebox("focus", type_name, field_box(CARD, BLUE, 8))
		t.set_stylebox("read_only", type_name, field_box(Color("#f4f6fa"), LINE, 8))
		t.set_color("font_color", type_name, TEXT)
		t.set_color("font_placeholder_color", type_name, MUTED)
		t.set_color("font_selected_color", type_name, TEXT)
		t.set_color("caret_color", type_name, TEXT)
		t.set_color("selection_color", type_name, Color(BLUE.r, BLUE.g, BLUE.b, 0.22))
		t.set_constant("minimum_character_width", type_name, 4)


## 商店里的 TabContainer 标签。
static func _style_tabs(t: Theme) -> void:
	var sel := box(CARD, 9, 1, LINE, 16)
	sel.content_margin_top = 7
	sel.content_margin_bottom = 7
	var unsel := box(SOFT, 9, 1, SOFT, 16)
	unsel.content_margin_top = 7
	unsel.content_margin_bottom = 7
	t.set_stylebox("tab_selected", "TabContainer", sel)
	t.set_stylebox("tab_unselected", "TabContainer", unsel)
	t.set_stylebox("tab_hovered", "TabContainer", unsel)
	t.set_stylebox("tab_disabled", "TabContainer", unsel)
	t.set_color("font_selected_color", "TabContainer", TEXT)
	t.set_color("font_unselected_color", "TabContainer", MUTED)
	t.set_color("font_hovered_color", "TabContainer", TEXT)
	t.set_color("font_disabled_color", "TabContainer", Color("#b7c0cf"))
	t.set_constant("side_margin", "TabContainer", 6)


## 复选框 / 开关：默认图标是白线，浅色背景上几乎看不见，这里自绘。
static func _style_toggles(t: Theme) -> void:
	var on := check_texture(20, true)
	var off := check_texture(20, false)
	var on_dim := check_texture(20, true, Color("#a8bbc9"))
	var off_dim := check_texture(20, false, Color("#c9d2e2"))
	for type_name in ["CheckBox", "CheckButton"]:
		t.set_icon("checked", type_name, on)
		t.set_icon("unchecked", type_name, off)
		t.set_icon("checked_disabled", type_name, on_dim)
		t.set_icon("unchecked_disabled", type_name, off_dim)
		t.set_stylebox("normal", type_name, StyleBoxEmpty.new())
		t.set_stylebox("hover", type_name, StyleBoxEmpty.new())
		t.set_stylebox("pressed", type_name, StyleBoxEmpty.new())
		t.set_stylebox("disabled", type_name, StyleBoxEmpty.new())
		t.set_stylebox("focus", type_name, StyleBoxEmpty.new())
		t.set_color("font_color", type_name, TEXT)
		t.set_color("font_hover_color", type_name, TEXT)
		t.set_color("font_pressed_color", type_name, TEXT)
		t.set_color("font_disabled_color", type_name, MUTED)
		t.set_constant("h_separation", "CheckButton", 8)


## 音量滑条。
static func _style_slider(t: Theme) -> void:
	t.set_stylebox("slider", "HSlider", flat(Color("#e2e8f2"), 4, 8))
	t.set_stylebox("grabber_area", "HSlider", flat(Color("#c8dcf7"), 4, 8))
	t.set_stylebox("grabber_area_highlight", "HSlider", flat(Color("#b9d2f4"), 4, 8))
	t.set_icon("grabber", "HSlider", circle_texture(18, CARD, BLUE, 3.0))
	t.set_icon("grabber_highlight", "HSlider", circle_texture(20, CARD, BLUE, 3.0))
	t.set_icon("grabber_disabled", "HSlider", circle_texture(18, CARD, Color("#c9d2e2"), 3.0))


static func _style_scrollbars(t: Theme) -> void:
	var v_track := bar_box(Color(0, 0, 0, 0), 10, false)
	var v_grab := bar_box(Color("#cfd7e4"), 8, false)
	var v_hot := bar_box(Color("#b8c3d4"), 8, false)
	var v_down := bar_box(Color("#a6b2c5"), 8, false)
	t.set_stylebox("scroll", "VScrollBar", v_track)
	t.set_stylebox("grabber", "VScrollBar", v_grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", v_hot)
	t.set_stylebox("grabber_pressed", "VScrollBar", v_down)
	var h_track := bar_box(Color(0, 0, 0, 0), 10, true)
	var h_grab := bar_box(Color("#cfd7e4"), 8, true)
	var h_hot := bar_box(Color("#b8c3d4"), 8, true)
	var h_down := bar_box(Color("#a6b2c5"), 8, true)
	t.set_stylebox("scroll", "HScrollBar", h_track)
	t.set_stylebox("grabber", "HScrollBar", h_grab)
	t.set_stylebox("grabber_highlight", "HScrollBar", h_hot)
	t.set_stylebox("grabber_pressed", "HScrollBar", h_down)


static func bar_box(color: Color, thickness: int, horizontal: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(thickness / 2.0))
	sb.set_content_margin_all(0)
	if horizontal:
		sb.content_margin_top = int(thickness / 2.0)
		sb.content_margin_bottom = int(thickness / 2.0)
	else:
		sb.content_margin_left = int(thickness / 2.0)
		sb.content_margin_right = int(thickness / 2.0)
	sb.anti_aliasing = true
	return sb


static func field_box(bg: Color, border_color: Color = LINE, pad: int = 12) -> StyleBoxFlat:
	var sb := box(bg, 10, 1, border_color, pad)
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


static func flat(color: Color, radius: int = 4, height: int = 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(0)
	sb.content_margin_top = int(height / 2.0)
	sb.content_margin_bottom = int(height / 2.0)
	sb.anti_aliasing = true
	return sb


# ---------- 自绘图标（项目不依赖图片资源，缺字/缺图时也不至于看不见） ----------

static func _alpha_image(size: int) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


static func _paint_circle(img: Image, center: Vector2, radius: float, color: Color) -> void:
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(center)
			var cov := clampf(radius - d + 0.5, 0.0, 1.0)
			if cov > 0.0:
				img.set_pixel(x, y, Color(color.r, color.g, color.b, color.a * cov))


static func _paint_segment(img: Image, a: Vector2, b: Vector2, width: float, color: Color) -> void:
	var ab := b - a
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var p := Vector2(x + 0.5, y + 0.5)
			var k := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
			var d := p.distance_to(a + ab * k)
			var cov := clampf(width * 0.5 - d + 0.5, 0.0, 1.0)
			if cov > 0.0:
				img.set_pixel(x, y, Color(color.r, color.g, color.b, color.a * cov))


static func _paint_round_rect(img: Image, rect: Rect2, radius: float, color: Color) -> void:
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var p := Vector2(x + 0.5, y + 0.5)
			var dx := 0.0
			if p.x < rect.position.x + radius:
				dx = rect.position.x + radius - p.x
			elif p.x > rect.end.x - radius:
				dx = p.x - (rect.end.x - radius)
			var dy := 0.0
			if p.y < rect.position.y + radius:
				dy = rect.position.y + radius - p.y
			elif p.y > rect.end.y - radius:
				dy = p.y - (rect.end.y - radius)
			var cov := 0.0
			if dx <= 0.0 and dy <= 0.0:
				cov = 1.0
			else:
				cov = clampf(radius - Vector2(dx, dy).length() + 0.5, 0.0, 1.0)
			if cov > 0.0:
				img.set_pixel(x, y, Color(color.r, color.g, color.b, color.a * cov))


static func circle_texture(size: int, fill: Color, border: Color, border_width: float = 2.0) -> ImageTexture:
	var img := _alpha_image(size)
	var c := Vector2(size * 0.5, size * 0.5)
	var r := size * 0.5 - 1.0
	_paint_circle(img, c, r, border)
	_paint_circle(img, c, r - border_width, fill)
	return ImageTexture.create_from_image(img)


static func check_texture(size: int, checked: bool, accent: Color = GREEN) -> ImageTexture:
	var img := _alpha_image(size)
	var rect := Rect2(1.0, 1.0, size - 2.0, size - 2.0)
	if checked:
		_paint_round_rect(img, rect, 5.0, accent)
		var w := float(size)
		_paint_segment(img, Vector2(w * 0.27, w * 0.52), Vector2(w * 0.44, w * 0.69), 2.0, CARD)
		_paint_segment(img, Vector2(w * 0.44, w * 0.69), Vector2(w * 0.75, w * 0.33), 2.0, CARD)
	else:
		_paint_round_rect(img, rect, 5.0, Color("#c9d2e2"))
		_paint_round_rect(img, Rect2(2.2, 2.2, size - 4.4, size - 4.4), 4.2, CARD)
	return ImageTexture.create_from_image(img)


static func chevron_texture(size: int, color: Color) -> ImageTexture:
	var img := _alpha_image(size)
	var w := float(size)
	_paint_segment(img, Vector2(w * 0.26, w * 0.40), Vector2(w * 0.5, w * 0.64), 2.0, color)
	_paint_segment(img, Vector2(w * 0.5, w * 0.64), Vector2(w * 0.74, w * 0.40), 2.0, color)
	return ImageTexture.create_from_image(img)


static func card(bg: Color = CARD, radius: int = 16, border: int = 0, border_color: Color = LINE, pad: int = 20) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(bg, radius, border, border_color, pad))
	return p


static func label(text: String, size: int = 15, color: Color = TEXT, weight: int = 400) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_override("font", ui_font(weight))
	return l


static func button(text: String, kind: String = "primary", height: float = 42.0) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, height)
	style_button(b, kind)
	return b


static func style_button(b: Button, kind: String) -> void:
	var palette := {
		"primary": TOMATO,
		"success": GREEN,
		"gold": GOLD,
		"blue": BLUE,
		"danger": Color("#c0392b"),
		"ghost": SOFT,
		"dark": Color("#2b3240"),
	}
	var base: Color = palette.get(kind, TOMATO)
	var fg := TEXT if kind == "ghost" else Color.WHITE
	b.add_theme_stylebox_override("normal", box(base, 10, 0, LINE, 10))
	b.add_theme_stylebox_override("hover", box(base.lightened(0.10), 10, 0, LINE, 10))
	b.add_theme_stylebox_override("pressed", box(base.darkened(0.10), 10, 0, LINE, 10))
	b.add_theme_stylebox_override("disabled", box(Color("#dfe3ec"), 10, 0, LINE, 10))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	b.add_theme_color_override("font_disabled_color", Color("#9aa3b5"))
	b.add_theme_font_size_override("font_size", 15)


static func margin(child: Control, left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", left)
	m.add_theme_constant_override("margin_top", top)
	m.add_theme_constant_override("margin_right", right)
	m.add_theme_constant_override("margin_bottom", bottom)
	m.add_child(child)
	return m


static func vbox(sep: int = 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep: int = 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


static func hsep(h: int = 12) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(h, 0)
	return c


static func progress(height: float = 10.0, fill: Color = GREEN, bg: Color = Color("#e8ecf4")) -> ProgressBar:
	var p := ProgressBar.new()
	p.show_percentage = false
	p.custom_minimum_size = Vector2(0, height)
	p.add_theme_stylebox_override("background", box(bg, int(height / 2.0), 0, LINE, 0))
	p.add_theme_stylebox_override("fill", box(fill, int(height / 2.0), 0, LINE, 0))
	return p
