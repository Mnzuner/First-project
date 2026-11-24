## 设置：提醒音效开关、音量、默认时长、数据重置（二次确认）。
extends Control

var sound_check: CheckButton
var volume_slider: HSlider
var volume_label: Label
var focus_spin: SpinBox
var break_spin: SpinBox
var confirm_farm: ConfirmationDialog
var confirm_stats: ConfirmationDialog


func _ready() -> void:
	_build()
	_load_values()


func _build() -> void:
	var root := UIKit.vbox(16)
	var w := UIKit.margin(root, 24, 18, 24, 18)
	w.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(w)

	root.add_child(UIKit.label("设置", 22, UIKit.TEXT, 700))

	var sound_card := UIKit.card()
	var sv := UIKit.vbox(12)
	sv.add_child(UIKit.label("提醒", 15, UIKit.TEXT, 700))
	var sound_row := UIKit.hbox(10)
	var sound_text := UIKit.vbox(2)
	sound_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sound_text.add_child(UIKit.label("番茄结束提醒音效", 14, UIKit.TEXT))
	sound_text.add_child(UIKit.label("专注 / 休息结束时播放提示音，并弹出提醒", 12, UIKit.MUTED))
	sound_row.add_child(sound_text)
	sound_check = CheckButton.new()
	sound_check.button_pressed = true
	sound_check.toggled.connect(_on_sound_toggled)
	sound_row.add_child(sound_check)
	sv.add_child(sound_row)

	var vol_row := UIKit.hbox(10)
	vol_row.add_child(UIKit.label("音量", 14, UIKit.TEXT))
	volume_slider = HSlider.new()
	volume_slider.min_value = 0
	volume_slider.max_value = 100
	volume_slider.step = 1
	volume_slider.custom_minimum_size = Vector2(240, 24)
	volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume_slider.value_changed.connect(_on_volume_changed)
	vol_row.add_child(volume_slider)
	volume_label = UIKit.label("60%", 13, UIKit.MUTED)
	vol_row.add_child(volume_label)
	sv.add_child(vol_row)
	sound_card.add_child(sv)
	root.add_child(sound_card)

	var timer_card := UIKit.card()
	var tv := UIKit.vbox(12)
	tv.add_child(UIKit.label("默认时长", 15, UIKit.TEXT, 700))
	var f_row := UIKit.hbox(10)
	f_row.add_child(UIKit.label("专注时长", 14, UIKit.TEXT))
	focus_spin = SpinBox.new()
	focus_spin.min_value = 1
	focus_spin.max_value = 120
	focus_spin.suffix = "分钟"
	focus_spin.custom_minimum_size = Vector2(140, 38)
	focus_spin.value_changed.connect(func(v: float) -> void:
		Storage.set_value("settings", "focus_minutes", int(v))
		_toast("默认专注时长已设为 %d 分钟" % int(v))
	)
	f_row.add_child(focus_spin)
	f_row.add_child(UIKit.spacer())
	f_row.add_child(UIKit.label("休息时长", 14, UIKit.TEXT))
	break_spin = SpinBox.new()
	break_spin.min_value = 1
	break_spin.max_value = 60
	break_spin.suffix = "分钟"
	break_spin.custom_minimum_size = Vector2(140, 38)
	break_spin.value_changed.connect(func(v: float) -> void:
		Storage.set_value("settings", "break_minutes", int(v))
	)
	f_row.add_child(break_spin)
	tv.add_child(f_row)
	timer_card.add_child(tv)
	root.add_child(timer_card)

	var data_card := UIKit.card()
	var dv := UIKit.vbox(12)
	dv.add_child(UIKit.label("数据", 15, UIKit.TEXT, 700))
	dv.add_child(UIKit.label("存档位置：user://save_data.json（Windows 下位于 %APPDATA%\\Godot\\app_userdata 内）", 12, UIKit.MUTED))
	var danger_row := UIKit.hbox(10)
	var reset_farm := UIKit.button("重置农场数据", "danger", 40)
	reset_farm.custom_minimum_size = Vector2(150, 40)
	reset_farm.pressed.connect(func() -> void: confirm_farm.popup_centered())
	danger_row.add_child(reset_farm)
	var reset_stats := UIKit.button("重置学习统计", "danger", 40)
	reset_stats.custom_minimum_size = Vector2(150, 40)
	reset_stats.pressed.connect(func() -> void: confirm_stats.popup_centered())
	danger_row.add_child(reset_stats)
	danger_row.add_child(UIKit.spacer())
	dv.add_child(danger_row)
	dv.add_child(UIKit.label("重置操作不可恢复，会先进行二次确认。", 12, UIKit.MUTED))
	data_card.add_child(dv)
	root.add_child(data_card)
	root.add_child(UIKit.spacer())

	confirm_farm = _make_confirm("重置农场数据", "确定要重置农场吗？\n地块、金币、等级、背包与装饰都会被清空。")
	confirm_farm.confirmed.connect(func() -> void:
		Storage.reset_section("farm")
		_toast("农场数据已重置")
	)
	confirm_stats = _make_confirm("重置学习统计", "确定要重置学习统计吗？\n所有番茄记录会被删除，任务列表保留。")
	confirm_stats.confirmed.connect(func() -> void:
		Storage.reset_section("stats")
		_toast("学习统计已重置")
	)


func _make_confirm(title: String, text: String) -> ConfirmationDialog:
	var d := ConfirmationDialog.new()
	d.borderless = true
	d.title = title
	d.dialog_text = title + "\n\n" + text
	d.ok_button_text = "确认重置"
	d.cancel_button_text = "取消"
	d.add_theme_font_override("font", UIKit.ui_font())
	var lbl := d.get_label()
	if lbl != null:
		lbl.add_theme_font_override("font", UIKit.ui_font())
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.custom_minimum_size = Vector2(360, 0)
	UIKit.style_button(d.get_ok_button(), "danger")
	UIKit.style_button(d.get_cancel_button(), "ghost")
	add_child(d)
	return d


func _load_values() -> void:
	sound_check.set_pressed_no_signal(bool(Storage.value("settings", "sound_enabled", true)))
	volume_slider.set_value_no_signal(clampf(float(Storage.value("settings", "volume", 0.6)) * 100.0, 0.0, 100.0))
	volume_label.text = "%d%%" % int(volume_slider.value)
	focus_spin.set_value_no_signal(float(Storage.value("settings", "focus_minutes", 25)))
	break_spin.set_value_no_signal(float(Storage.value("settings", "break_minutes", 5)))


func _on_sound_toggled(on: bool) -> void:
	Storage.set_value("settings", "sound_enabled", on)
	_toast("提醒音效已" + ("开启" if on else "关闭"))


func _on_volume_changed(v: float) -> void:
	volume_label.text = "%d%%" % int(v)
	Storage.set_value("settings", "volume", clampf(v / 100.0, 0.0, 1.0))


func _toast(text: String) -> void:
	var main := get_tree().current_scene
	if main != null and main.has_method("toast"):
		main.toast(text)
