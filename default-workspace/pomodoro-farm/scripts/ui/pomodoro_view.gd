## 番茄钟视图：环形倒计时 + 任务绑定 + 时长模板 + 开始/暂停/放弃。
extends Control

var ring: RingTimer
var task_option: OptionButton
var duration_option: OptionButton
var custom_spin: SpinBox
var custom_row: HBoxContainer
var start_btn: Button
var pause_btn: Button
var abandon_btn: Button
var skip_btn: Button
var hint: Label
var task_dialog: AcceptDialog
var task_title_edit: LineEdit
var task_tag_edit: LineEdit
var confirm_abandon: ConfirmationDialog

const DURATIONS := [25, 45, 50]


func _ready() -> void:
	_build()
	_build_confirm()
	Pomodoro.tick.connect(_on_tick)
	Pomodoro.state_changed.connect(_on_state_changed)
	Pomodoro.phase_changed.connect(_on_phase_changed)
	Pomodoro.notice.connect(_on_notice)
	TaskStats.tasks_changed.connect(_refresh_tasks)
	_refresh_tasks()
	_refresh_all()


func _build() -> void:
	var outer := UIKit.margin(_build_body(), 24, 20, 24, 20)
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(outer)


func _build_confirm() -> void:
	confirm_abandon = ConfirmationDialog.new()
	confirm_abandon.borderless = true
	confirm_abandon.title = "放弃本次番茄"
	confirm_abandon.dialog_text = "放弃本次番茄？\n\n已专注的时间会记为一次无效番茄，本次不发金币、经验与种子。"
	confirm_abandon.ok_button_text = "确认放弃"
	confirm_abandon.cancel_button_text = "继续专注"
	confirm_abandon.add_theme_font_override("font", UIKit.ui_font())
	var lbl := confirm_abandon.get_label()
	if lbl != null:
		lbl.add_theme_font_override("font", UIKit.ui_font())
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.custom_minimum_size = Vector2(360, 0)
	UIKit.style_button(confirm_abandon.get_ok_button(), "danger")
	UIKit.style_button(confirm_abandon.get_cancel_button(), "ghost")
	confirm_abandon.confirmed.connect(_do_abandon)
	add_child(confirm_abandon)


func _build_body() -> Control:
	var row := UIKit.hbox(20)

	var left := UIKit.card()
	var lv := UIKit.vbox(8)
	lv.alignment = BoxContainer.ALIGNMENT_CENTER
	ring = RingTimer.new()
	ring.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ring.custom_minimum_size = Vector2(360, 360)
	lv.add_child(ring)
	lv.add_child(_center(UIKit.label("单次番茄最多暂停 1 次，暂停超时本次番茄失效", 13, UIKit.MUTED)))
	left.add_child(lv)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.15
	row.add_child(left)

	var right := UIKit.card()
	var rv := UIKit.vbox(14)

	rv.add_child(UIKit.label("当前任务", 13, UIKit.MUTED, 700))
	var task_row := UIKit.hbox(8)
	task_option = OptionButton.new()
	task_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	task_option.custom_minimum_size = Vector2(0, 40)
	task_option.add_theme_font_override("font", UIKit.ui_font())
	task_option.add_theme_font_size_override("font_size", 15)
	task_option.item_selected.connect(_on_task_selected)
	task_row.add_child(task_option)
	var add_task_btn := UIKit.button("新建", "ghost", 40)
	add_task_btn.custom_minimum_size = Vector2(68, 40)
	add_task_btn.pressed.connect(_open_task_dialog)
	task_row.add_child(add_task_btn)
	rv.add_child(task_row)

	rv.add_child(UIKit.hsep(6))
	rv.add_child(UIKit.label("时长设置", 13, UIKit.MUTED, 700))
	duration_option = OptionButton.new()
	duration_option.custom_minimum_size = Vector2(0, 40)
	duration_option.add_theme_font_size_override("font_size", 15)
	for i in range(DURATIONS.size()):
		duration_option.add_item("模板 %d 分钟" % DURATIONS[i], i)
	duration_option.add_item("自定义时长", DURATIONS.size())
	duration_option.select(0)
	duration_option.item_selected.connect(_on_duration_selected)
	rv.add_child(duration_option)

	custom_row = UIKit.hbox(8)
	custom_row.add_child(UIKit.label("自定义", 14, UIKit.MUTED))
	custom_spin = SpinBox.new()
	custom_spin.min_value = 1
	custom_spin.max_value = 120
	custom_spin.value = 25
	custom_spin.suffix = "分钟"
	custom_spin.custom_minimum_size = Vector2(0, 38)
	custom_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_row.add_child(custom_spin)
	custom_row.visible = false
	rv.add_child(custom_row)

	rv.add_child(UIKit.hsep(10))
	var btns := UIKit.hbox(10)
	start_btn = UIKit.button("▷ 开始专注", "primary", 46)
	start_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_btn.pressed.connect(_on_start)
	btns.add_child(start_btn)
	pause_btn = UIKit.button("‖ 暂停", "ghost", 46)
	pause_btn.custom_minimum_size = Vector2(96, 46)
	pause_btn.pressed.connect(_on_pause)
	btns.add_child(pause_btn)
	rv.add_child(btns)

	abandon_btn = UIKit.button("✖ 放弃本次番茄", "ghost", 42)
	abandon_btn.pressed.connect(_on_abandon)
	rv.add_child(abandon_btn)

	skip_btn = UIKit.button("跳过休息", "ghost", 42)
	skip_btn.pressed.connect(func() -> void: Pomodoro.skip_break())
	skip_btn.visible = false
	rv.add_child(skip_btn)

	hint = UIKit.label("", 13, UIKit.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rv.add_child(hint)

	rv.add_child(UIKit.spacer())

	var tip := UIKit.card(UIKit.SOFT, 12, 0, UIKit.LINE, 14)
	tip.add_child(UIKit.label("完成一次有效番茄：+20 金币、+15 经验，还有概率掉落种子。", 13, UIKit.MUTED))
	rv.add_child(tip)

	right.add_child(rv)
	right.custom_minimum_size = Vector2(400, 0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)

	_task_dialog()
	return row


func _center(c: Control) -> CenterContainer:
	var cc := CenterContainer.new()
	cc.add_child(c)
	return cc


func _task_dialog() -> void:
	task_dialog = AcceptDialog.new()
	task_dialog.title = "新建学习任务"
	task_dialog.ok_button_text = "添加"
	task_dialog.add_theme_font_override("font", UIKit.ui_font())
	var box := UIKit.vbox(10)
	var w := UIKit.margin(box, 20, 12, 20, 12)
	w.custom_minimum_size = Vector2(340, 0)
	box.add_child(UIKit.label("任务名称", 13, UIKit.MUTED))
	task_title_edit = LineEdit.new()
	task_title_edit.placeholder_text = "例如：数学错题整理"
	task_title_edit.custom_minimum_size = Vector2(0, 38)
	box.add_child(task_title_edit)
	box.add_child(UIKit.label("标签", 13, UIKit.MUTED))
	task_tag_edit = LineEdit.new()
	task_tag_edit.placeholder_text = "数学 / 英语 / 复习"
	task_tag_edit.custom_minimum_size = Vector2(0, 38)
	box.add_child(task_tag_edit)
	task_dialog.add_child(w)
	task_dialog.confirmed.connect(_on_task_confirmed)
	add_child(task_dialog)


# ---------------------------------------------------------------- 交互

func _open_task_dialog() -> void:
	task_title_edit.text = ""
	task_tag_edit.text = ""
	task_dialog.popup_centered()
	task_title_edit.grab_focus()


func _on_task_confirmed() -> void:
	var t := TaskStats.add_task(task_title_edit.text, task_tag_edit.text)
	if t.is_empty():
		_toast("任务名称不能为空")
		return
	_refresh_tasks()
	var idx := _index_of_task(String(t.get("id", "")))
	if idx >= 0:
		task_option.select(idx)
		Pomodoro.bind_task(String(t.get("id", "")))
	_refresh_ring()


func _on_task_selected(index: int) -> void:
	var id := String(task_option.get_item_metadata(index)) if index >= 0 else ""
	Pomodoro.bind_task(id)
	_refresh_ring()


func _on_duration_selected(index: int) -> void:
	custom_row.visible = index >= DURATIONS.size()


func _on_start() -> void:
	if Pomodoro.running:
		return
	var minutes := -1
	var idx := duration_option.selected
	if idx >= 0 and idx < DURATIONS.size():
		minutes = DURATIONS[idx]
	elif custom_row.visible:
		minutes = int(custom_spin.value)
	Pomodoro.start(minutes)
	_refresh_all()


func _on_pause() -> void:
	if not Pomodoro.running:
		return
	Pomodoro.toggle_pause()
	_refresh_all()


func _on_abandon() -> void:
	if not (Pomodoro.running or Pomodoro.remaining < Pomodoro.total):
		return
	confirm_abandon.popup_centered()


func _do_abandon() -> void:
	Pomodoro.abandon()
	_refresh_all()


func _on_notice(text: String) -> void:
	hint.text = text
	_refresh_all()


func _on_tick(_remaining: float, _total: float, _phase: String) -> void:
	_refresh_ring()


func _on_state_changed(_running: bool, _paused: bool) -> void:
	_refresh_all()


func _on_phase_changed(_phase: String) -> void:
	_refresh_all()


# ---------------------------------------------------------------- 刷新

func _refresh_tasks() -> void:
	var keep := Pomodoro.bound_task_id
	task_option.clear()
	task_option.add_item("未绑定任务")
	task_option.set_item_metadata(0, "")
	var list := TaskStats.tasks()
	for t in list:
		var idx := task_option.item_count
		task_option.add_item("%s  ·  %s" % [String(t.get("title", "")), String(t.get("tag", ""))])
		task_option.set_item_metadata(idx, String(t.get("id", "")))
	if keep == "":
		task_option.select(0)
	else:
		var idx := _index_of_task(keep)
		task_option.select(idx if idx >= 0 else 0)
		if idx < 0:
			Pomodoro.bind_task("")


func _index_of_task(task_id: String) -> int:
	for i in range(task_option.item_count):
		if String(task_option.get_item_metadata(i)) == task_id:
			return i
	return -1


func _refresh_all() -> void:
	var focus_phase := Pomodoro.phase == Pomodoro.PHASE_FOCUS
	if focus_phase:
		start_btn.text = "▷ 开始专注"
		start_btn.add_theme_stylebox_override("normal", UIKit.box(UIKit.TOMATO, 10, 0, UIKit.LINE, 10))
	else:
		start_btn.text = "▷ 开始休息"
		start_btn.add_theme_stylebox_override("normal", UIKit.box(UIKit.GREEN, 10, 0, UIKit.LINE, 10))
	start_btn.disabled = Pomodoro.running
	pause_btn.text = "▶ 继续" if Pomodoro.paused else "‖ 暂停"
	pause_btn.disabled = not Pomodoro.running
	abandon_btn.disabled = not (Pomodoro.running or Pomodoro.remaining < Pomodoro.total)
	skip_btn.visible = not focus_phase
	duration_option.disabled = Pomodoro.running
	task_option.disabled = Pomodoro.running
	custom_spin.editable = not Pomodoro.running
	if Pomodoro.paused:
		hint.text = "已暂停：本句番茄只能暂停 1 次，继续前请勿离开太久（超过 5 分钟自动作废）。"
	_refresh_ring()


func _refresh_ring() -> void:
	var focus_phase := Pomodoro.phase == Pomodoro.PHASE_FOCUS
	ring.progress = Pomodoro.progress()
	ring.time_text = _fmt(Pomodoro.remaining)
	ring.phase_text = ("专注中" if focus_phase else "休息中") + ("（已暂停）" if Pomodoro.paused else "")
	ring.ring_color = (UIKit.TOMATO if focus_phase else UIKit.GREEN) if not Pomodoro.paused else UIKit.GOLD
	var task_id := Pomodoro.bound_task_id
	var title := TaskStats.task_title(task_id) if task_id != "" else "未绑定任务"
	ring.sub_text = title


func _fmt(sec: float) -> String:
	var s := int(ceil(maxf(sec, 0.0)))
	return "%02d:%02d" % [int(s / 60), s % 60]


func _toast(text: String) -> void:
	var main := get_tree().current_scene
	if main != null and main.has_method("toast"):
		main.toast(text)
