## 主界面：顶部导航 + 四个视图切换 + 全局提示 / 结束提醒。
##
## 视图切换只改 visible，计时与农场状态都在 autoload 里，因此切换不会中断后台计时。
extends Control

const VIEWS := [
	{"id": "pomodoro", "title": "番茄钟", "script": preload("res://scripts/ui/pomodoro_view.gd")},
	{"id": "farm", "title": "农场", "script": preload("res://scripts/ui/farm_view.gd")},
	{"id": "stats", "title": "统计看板", "script": preload("res://scripts/ui/stats_view.gd")},
	{"id": "settings", "title": "设置", "script": preload("res://scripts/ui/settings_view.gd")},
]

var nav_buttons := {}
var view_nodes := {}
var status_label: Label
var toast_panel: PanelContainer
var toast_label: Label
var toast_tween: Tween
var alert: AcceptDialog
var sfx: AudioStreamPlayer
var focus_tone: AudioStreamWAV
var break_tone: AudioStreamWAV
var current: String = "pomodoro"


func _ready() -> void:
	theme = UIKit.make_theme()
	_build()
	Pomodoro.tick.connect(_on_tick)
	Pomodoro.focus_finished.connect(_on_focus_finished)
	Pomodoro.break_finished.connect(_on_break_finished)
	Pomodoro.notice.connect(toast)
	Pomodoro.state_changed.connect(func(_a: bool, _b: bool) -> void: _refresh_status())
	Pomodoro.phase_changed.connect(func(_p: String) -> void: _refresh_status())
	_switch("pomodoro")


# ---------------------------------------------------------------- 构建

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = UIKit.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	root.add_child(_build_topbar())

	var content := Control.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(content)
	for entry in VIEWS:
		var view: Control = entry["script"].new()
		view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		view.visible = false
		content.add_child(view)
		view_nodes[String(entry["id"])] = view

	_build_toast()
	_build_alert()
	_build_sfx()


func _build_topbar() -> Control:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UIKit.box(UIKit.CARD, 0, 0, UIKit.LINE, 0))
	bar.custom_minimum_size = Vector2(0, 66)
	var w := UIKit.margin(UIKit.hbox(10), 22, 12, 22, 12)
	bar.add_child(w)
	var row := w.get_child(0)

	var brand := UIKit.label("番茄农场", 20, UIKit.TEXT, 700)
	row.add_child(brand)
	row.add_child(UIKit.hsep(18))

	for entry in VIEWS:
		var b := UIKit.button(String(entry["title"]), "ghost", 38)
		b.custom_minimum_size = Vector2(96, 38)
		var id := String(entry["id"])
		b.pressed.connect(func() -> void: _switch(id))
		row.add_child(b)
		nav_buttons[id] = b

	row.add_child(UIKit.spacer())
	status_label = UIKit.label("", 14, UIKit.MUTED, 700)
	row.add_child(status_label)
	return bar


func _build_toast() -> void:
	var holder := CenterContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	holder.offset_top = -86
	holder.offset_bottom = -22
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	toast_panel = PanelContainer.new()
	toast_panel.add_theme_stylebox_override("panel", UIKit.box(Color("#2b3240"), 12, 0, UIKit.LINE, 14))
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.visible = false
	toast_label = UIKit.label("", 14, Color.WHITE)
	toast_panel.add_child(toast_label)
	holder.add_child(toast_panel)


func _build_alert() -> void:
	alert = AcceptDialog.new()
	alert.title = "番茄提醒"
	alert.ok_button_text = "我知道了"
	alert.add_theme_font_override("font", UIKit.ui_font())
	alert.add_theme_font_size_override("font_size", 16)
	add_child(alert)


func _build_sfx() -> void:
	focus_tone = _make_tone([784.0, 1046.5])
	break_tone = _make_tone([523.25, 392.0])
	sfx = AudioStreamPlayer.new()
	add_child(sfx)


# ---------------------------------------------------------------- 导航

func _switch(id: String) -> void:
	current = id
	for key in view_nodes.keys():
		view_nodes[key].visible = key == id
	for key in nav_buttons.keys():
		UIKit.style_button(nav_buttons[key], "primary" if key == id else "ghost")


func _refresh_status() -> void:
	if Pomodoro.running:
		var tag := "专注" if Pomodoro.phase == Pomodoro.PHASE_FOCUS else "休息"
		if Pomodoro.paused:
			tag = "已暂停"
		status_label.text = "%s · %s" % [tag, _fmt(Pomodoro.remaining)]
	else:
		status_label.text = ""


func _on_tick(_remaining: float, _total: float, _phase: String) -> void:
	_refresh_status()


# ---------------------------------------------------------------- 提醒

func _on_focus_finished() -> void:
	show_alert("本次番茄完成！\n\n获得金币与经验奖励，去看看农场吧。", true)


func _on_break_finished() -> void:
	show_alert("休息结束，继续下一个番茄吧。", true)
	_play(break_tone)


func show_alert(text: String, with_sound: bool) -> void:
	alert.dialog_text = text
	alert.popup_centered()
	if with_sound:
		_play(focus_tone)


func _play(stream: AudioStreamWAV) -> void:
	if not bool(Storage.value("settings", "sound_enabled", true)):
		return
	var vol := clampf(float(Storage.value("settings", "volume", 0.6)), 0.0, 1.0)
	if vol <= 0.001:
		return
	sfx.stream = stream
	sfx.volume_db = linear_to_db(vol * 0.8)
	sfx.play()


# ---------------------------------------------------------------- 提示

func toast(text: String) -> void:
	toast_label.text = text
	toast_panel.visible = true
	toast_panel.modulate.a = 1.0
	if toast_tween != null and toast_tween.is_valid():
		toast_tween.kill()
	toast_tween = create_tween()
	toast_tween.tween_interval(2.2)
	toast_tween.tween_property(toast_panel, "modulate:a", 0.0, 0.5)
	toast_tween.tween_callback(func() -> void: toast_panel.visible = false)


# ---------------------------------------------------------------- 工具

func _fmt(sec: float) -> String:
	var s := int(ceil(maxf(sec, 0.0)))
	return "%02d:%02d" % [int(s / 60), s % 60]


## 用正弦波合成一个双音提示音，避免依赖外部音频资源。
func _make_tone(freqs: Array) -> AudioStreamWAV:
	var rate := 22050
	var note_len := 0.18
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	var per := int(rate * note_len)
	var data := PackedByteArray()
	data.resize(per * freqs.size() * 2)
	var idx := 0
	for f in freqs:
		var hz := float(f)
		for i in per:
			var env := 1.0 - float(i) / float(per)
			var v := int(sin(TAU * hz * float(i) / float(rate)) * env * 0.32 * 32767.0)
			v = clampi(v, -32768, 32767)
			data[idx] = v & 0xFF
			data[idx + 1] = (v >> 8) & 0xFF
			idx += 2
	wav.data = data
	return wav
