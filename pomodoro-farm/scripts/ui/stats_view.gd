## 统计看板：日 / 周视图切换、汇总卡片、柱状图与历史记录。
extends Control

var day_btn: Button
var week_btn: Button
var count_value: Label
var focus_value: Label
var invalid_value: Label
var chart: BarChart
var chart_title: Label
var history_list: VBoxContainer
var subtitle: Label

var mode: String = "day"


func _ready() -> void:
	_build()
	TaskStats.records_changed.connect(_refresh)
	Pomodoro.pomodoro_completed.connect(func(_a: String, _b: int, _c: bool) -> void: _refresh())
	_refresh()


func _build() -> void:
	var root := UIKit.vbox(16)
	var w := UIKit.margin(root, 24, 18, 24, 18)
	w.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(w)

	var head := UIKit.hbox(12)
	head.add_child(UIKit.label("统计看板", 22, UIKit.TEXT, 700))
	head.add_child(UIKit.spacer())
	day_btn = UIKit.button("日视图", "primary", 38)
	day_btn.custom_minimum_size = Vector2(92, 38)
	day_btn.pressed.connect(func() -> void: _set_mode("day"))
	head.add_child(day_btn)
	week_btn = UIKit.button("周视图", "ghost", 38)
	week_btn.custom_minimum_size = Vector2(92, 38)
	week_btn.pressed.connect(func() -> void: _set_mode("week"))
	head.add_child(week_btn)
	root.add_child(head)

	var cards := UIKit.hbox(14)
	cards.add_child(_stat_card("有效番茄", "0 个", UIKit.TOMATO, "count"))
	cards.add_child(_stat_card("累计专注", "0 分钟", UIKit.GREEN, "focus"))
	cards.add_child(_stat_card("无效番茄", "0 个", UIKit.MUTED, "invalid"))
	root.add_child(cards)

	var chart_card := UIKit.card()
	var cv := UIKit.vbox(10)
	var ch := UIKit.hbox(10)
	chart_title = UIKit.label("最近 7 天", 15, UIKit.TEXT, 700)
	ch.add_child(chart_title)
	ch.add_child(UIKit.spacer())
	subtitle = UIKit.label("", 12, UIKit.MUTED)
	ch.add_child(subtitle)
	cv.add_child(ch)
	chart = BarChart.new()
	chart.custom_minimum_size = Vector2(0, 190)
	chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cv.add_child(chart)
	chart_card.add_child(cv)
	root.add_child(chart_card)

	var hist_card := UIKit.card()
	var hv := UIKit.vbox(8)
	hv.add_child(UIKit.label("历史记录", 15, UIKit.TEXT, 700))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	history_list = UIKit.vbox(6)
	history_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(history_list)
	hv.add_child(scroll)
	hist_card.add_child(hv)
	hist_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(hist_card)


var _value_labels := {}


func _stat_card(title: String, value: String, color: Color, key: String) -> Control:
	var card := UIKit.card()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UIKit.vbox(4)
	v.add_child(UIKit.label(title, 13, UIKit.MUTED))
	var val := UIKit.label(value, 26, color, 700)
	_value_labels[key] = val
	v.add_child(val)
	card.add_child(v)
	return card


func _set_mode(m: String) -> void:
	mode = m
	UIKit.style_button(day_btn, "primary" if m == "day" else "ghost")
	UIKit.style_button(week_btn, "primary" if m == "week" else "ghost")
	_refresh()


func _refresh() -> void:
	var count := 0
	var seconds := 0
	var invalid := 0
	var series: Array = []
	if mode == "day":
		var s := TaskStats.summary(Storage.now_unix() - _seconds_of_today(), Storage.now_unix())
		count = int(s.count)
		seconds = int(s.seconds)
		invalid = int(s.invalid)
		series = TaskStats.daily_series(7)
		chart_title.text = "最近 7 天有效番茄"
		subtitle.text = "今天 %d 个 · %s" % [count, _fmt_duration(seconds)]
		chart.bar_color = UIKit.TOMATO
	else:
		var start := Storage.week_start(Storage.now_unix())
		var s2 := TaskStats.summary(start, Storage.now_unix())
		count = int(s2.count)
		seconds = int(s2.seconds)
		invalid = int(s2.invalid)
		series = TaskStats.weekly_series(6)
		chart_title.text = "最近 6 周有效番茄"
		subtitle.text = "本周 %d 个 · %s" % [count, _fmt_duration(seconds)]
		chart.bar_color = UIKit.BLUE
	_value_labels["count"].text = "%d 个" % count
	_value_labels["focus"].text = _fmt_duration(seconds)
	_value_labels["invalid"].text = "%d 个" % invalid
	chart.items = series
	_refresh_history()


func _seconds_of_today() -> int:
	var d := Time.get_datetime_dict_from_unix_time(Storage.now_unix())
	return int(d.hour) * 3600 + int(d.minute) * 60 + int(d.second)


func _refresh_history() -> void:
	for c in history_list.get_children():
		c.queue_free()
	var rows := TaskStats.history(30)
	if rows.is_empty():
		history_list.add_child(UIKit.label("还没有记录，去完成一次番茄吧。", 13, UIKit.MUTED))
		return
	for r in rows:
		var row := UIKit.card(UIKit.SOFT, 10, 0, UIKit.LINE, 10)
		var h := UIKit.hbox(10)
		var eff := bool(r.get("effective", false))
		var day := String(r.get("day", ""))
		var ts := int(r.get("ts", 0))
		h.add_child(UIKit.label("%s %s" % [day, Storage.time_of_day(ts)], 12, UIKit.MUTED))
		var title_text := String(r.get("title", "未绑定任务"))
		var title := UIKit.label(title_text, 14, UIKit.TEXT, 700)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(title)
		var tag := String(r.get("tag", ""))
		if tag != "" and tag != title_text:
			h.add_child(UIKit.label(tag, 12, UIKit.MUTED))
		h.add_child(UIKit.label(_fmt_duration(int(r.get("seconds", 0))), 12, UIKit.MUTED))
		var badge := UIKit.label("有效" if eff else "无效", 12, UIKit.GREEN if eff else Color("#c0392b"), 700)
		h.add_child(badge)
		row.add_child(h)
		history_list.add_child(row)


func _fmt_duration(sec: int) -> String:
	var s := maxi(sec, 0)
	if s < 60:
		return "%d 秒" % s
	var m := int(s / 60)
	if m < 60:
		return "%d 分钟" % m
	var h := int(m / 60)
	return "%d 小时 %d 分" % [h, m % 60]
