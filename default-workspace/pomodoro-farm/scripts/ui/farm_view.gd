## 农场视图：4×4 地块、商店、背包、道具、等级与金币。
extends Control

const COLS := 4
const ROWS := 4

var level_label: Label
var coins_label: Label
var exp_label: Label
var exp_bar: ProgressBar
var grid: GridContainer
var plot_buttons: Array = []
var sel_name: Label
var sel_time: Label
var sel_action: Button
var bag_hint: Label
var modal_layer: PanelContainer

var selected: int = -1
var _acc: float = 0.0


func _ready() -> void:
	_build()
	Farm.farm_changed.connect(_refresh)
	Farm.level_up.connect(_on_level_up)
	Farm.reward_gained.connect(_on_reward)
	_refresh()


func _process(delta: float) -> void:
	if not visible:
		return
	_acc += delta
	if _acc < 1.0:
		return
	_acc = 0.0
	_refresh_plots()
	_refresh_selection()


# ---------------------------------------------------------------- 构建

func _build() -> void:
	var root := UIKit.vbox(16)
	var w := UIKit.margin(root, 24, 18, 24, 18)
	w.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(w)

	root.add_child(_build_status())

	var body := UIKit.hbox(16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_build_grid_card())
	body.add_child(_build_side_card())
	root.add_child(body)

	_build_modal()


func _build_status() -> Control:
	var card := UIKit.card()
	var row := UIKit.hbox(16)
	var pill := UIKit.card(UIKit.SOFT, 12, 0, UIKit.LINE, 10)
	level_label = UIKit.label("Lv.1", 18, UIKit.TEXT, 700)
	pill.add_child(level_label)
	row.add_child(pill)

	var coin_box := UIKit.hbox(6)
	coin_box.add_child(UIKit.label("金币", 13, UIKit.MUTED))
	coins_label = UIKit.label("120", 20, UIKit.GOLD, 700)
	coin_box.add_child(coins_label)
	row.add_child(coin_box)

	var exp_box := UIKit.vbox(4)
	exp_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	exp_label = UIKit.label("经验 0/200", 12, UIKit.MUTED)
	exp_bar = UIKit.progress(12, UIKit.BLUE)
	exp_box.add_child(exp_label)
	exp_box.add_child(exp_bar)
	row.add_child(exp_box)

	var shop_btn := UIKit.button("商店", "blue", 40)
	shop_btn.custom_minimum_size = Vector2(88, 40)
	shop_btn.pressed.connect(_open_shop)
	row.add_child(shop_btn)

	var bag_btn := UIKit.button("背包", "ghost", 40)
	bag_btn.custom_minimum_size = Vector2(88, 40)
	bag_btn.pressed.connect(_open_bag)
	row.add_child(bag_btn)

	card.add_child(row)
	return card


func _build_grid_card() -> Control:
	var card := UIKit.card()
	var v := UIKit.vbox(14)
	var head := UIKit.hbox(10)
	head.add_child(UIKit.label("我的农场", 18, UIKit.TEXT, 700))
	head.add_child(UIKit.spacer())
	bag_hint = UIKit.label("", 13, UIKit.MUTED)
	head.add_child(bag_hint)
	v.add_child(head)

	grid = GridContainer.new()
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for i in Farm.plots_count():
		var b := Button.new()
		b.custom_minimum_size = Vector2(96, 96)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_vertical = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_override("font", UIKit.ui_font(700))
		b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(_on_plot_pressed.bind(i))
		grid.add_child(b)
		plot_buttons.append(b)
	v.add_child(grid)
	card.add_child(v)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_stretch_ratio = 1.6
	return card


func _build_side_card() -> Control:
	var card := UIKit.card()
	card.custom_minimum_size = Vector2(300, 0)
	var v := UIKit.vbox(12)
	v.add_child(UIKit.label("地块信息", 16, UIKit.TEXT, 700))

	sel_name = UIKit.label("未选中地块", 22, UIKit.TEXT, 700)
	sel_time = UIKit.label("点击左侧空闲地块开始种植", 13, UIKit.MUTED)
	sel_time.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sel_name)
	v.add_child(sel_time)

	sel_action = UIKit.button("选择一块地", "primary", 42)
	sel_action.disabled = true
	sel_action.pressed.connect(_on_action_pressed)
	v.add_child(sel_action)

	v.add_child(UIKit.hsep(8))
	v.add_child(UIKit.label("玩法提示", 13, UIKit.MUTED, 700))
	var tips := UIKit.vbox(6)
	for t in [
		"完成有效番茄可获金币、经验与随机种子",
		"升级后自动解锁新地块（每级 +2）",
		"播种消耗背包里的种子，可去商店购买",
		"成熟后点击地块即可收获并换取金币",
	]:
		var line := UIKit.label("· " + t, 12, UIKit.MUTED)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tips.add_child(line)
	v.add_child(tips)
	v.add_child(UIKit.spacer())
	card.add_child(v)
	return card


# ---------------------------------------------------------------- 刷新

func _refresh() -> void:
	level_label.text = "Lv.%d" % Farm.level()
	coins_label.text = str(Farm.coins())
	var need := Farm.exp_needed()
	exp_label.text = "经验 %d/%d" % [Farm.exp_points(), need]
	exp_bar.max_value = float(need)
	exp_bar.value = float(Farm.exp_points())
	if selected >= Farm.unlocked_count():
		selected = -1
	_refresh_plots()
	_refresh_selection()
	_refresh_bag_hint()


func _refresh_bag_hint() -> void:
	var parts: Array = []
	for cid in Farm.crop_ids():
		var n := Farm.seed_count(cid)
		if n > 0:
			parts.append("%s种子×%d" % [String(Farm.crop_info(cid).get("name", cid)), n])
	bag_hint.text = "  ".join(parts) if not parts.is_empty() else "背包暂无种子"


func _refresh_plots() -> void:
	for i in range(plot_buttons.size()):
		var b: Button = plot_buttons[i]
		var st := Farm.plot_state(i)
		var text := ""
		var fg := UIKit.TEXT
		var bg := UIKit.SOFT
		var border := 0
		var border_color := UIKit.LINE
		match st:
			"locked":
				text = "锁定\nLv.%d 解锁" % Farm.level_for_plot(i)
				fg = Color("#9aa3b5")
				bg = Color("#f0f2f7")
			"idle":
				text = "空闲\n点击播种"
				fg = UIKit.MUTED
				bg = Color("#fafbfe")
			"growing":
				var p := Farm.plot(i)
				var info := Farm.crop_info(String(p.get("crop", "")))
				var rem := Farm.remaining_seconds(i)
				text = "%s\n%s" % [String(info.get("name", "作物")), _fmt_short(rem)]
				fg = UIKit.GREEN
				bg = Color("#eef7f0")
			"ready":
				var p2 := Farm.plot(i)
				var info2 := Farm.crop_info(String(p2.get("crop", "")))
				text = "%s\n可收获" % String(info2.get("name", "作物"))
				fg = UIKit.GOLD
				bg = Color("#fdf4e2")
		if i == selected:
			border = 2
			border_color = UIKit.TOMATO
		b.text = text
		b.add_theme_color_override("font_color", fg)
		b.add_theme_color_override("font_hover_color", fg)
		b.add_theme_color_override("font_pressed_color", fg)
		b.add_theme_stylebox_override("normal", UIKit.box(bg, 12, border, border_color, 8))
		b.add_theme_stylebox_override("hover", UIKit.box(bg.lightened(0.02), 12, maxi(border, 1), border_color, 8))
		b.add_theme_stylebox_override("pressed", UIKit.box(bg.darkened(0.04), 12, maxi(border, 1), border_color, 8))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _refresh_selection() -> void:
	if selected < 0:
		sel_name.text = "未选中地块"
		sel_time.text = "点击左侧空闲地块开始种植"
		sel_action.text = "选择一块地"
		sel_action.disabled = true
		return
	var st := Farm.plot_state(selected)
	var i := selected
	sel_action.disabled = false
	match st:
		"locked":
			sel_name.text = "地块 #%d（未解锁）" % (i + 1)
			sel_time.text = "升到 Lv.%d 即可解锁这块地。" % Farm.level_for_plot(i)
			sel_action.text = "尚未解锁"
			sel_action.disabled = true
		"idle":
			sel_name.text = "地块 #%d（空闲）" % (i + 1)
			sel_time.text = "选择一种种子播种，成熟后即可收获金币与经验。"
			sel_action.text = "播种"
		"growing":
			var p := Farm.plot(i)
			var info := Farm.crop_info(String(p.get("crop", "")))
			sel_name.text = String(info.get("name", "作物"))
			var rem := Farm.remaining_seconds(i)
			sel_time.text = "剩余生长 %s\n预计收获 +%d 金币 / +%d 经验" % [_fmt_long(rem), int(info.get("sell_price", 0)), int(info.get("exp", 0))]
			sel_action.text = "使用道具"
		"ready":
			var p2 := Farm.plot(i)
			var info2 := Farm.crop_info(String(p2.get("crop", "")))
			sel_name.text = String(info2.get("name", "作物")) + "（成熟）"
			sel_time.text = "点击收获，获得 %d 金币与 %d 经验。" % [int(info2.get("sell_price", 0)), int(info2.get("exp", 0))]
			sel_action.text = "收获"


# ---------------------------------------------------------------- 交互

func _on_plot_pressed(i: int) -> void:
	selected = i
	_refresh_plots()
	_refresh_selection()


func _on_action_pressed() -> void:
	if selected < 0:
		return
	match Farm.plot_state(selected):
		"idle":
			_open_seed_picker()
		"growing":
			_open_item_picker()
		"ready":
			var r := Farm.harvest(selected)
			if not r.is_empty():
				_toast("收获 %s：+%d 金币，+%d 经验" % [String(r.get("name", "")), int(r.get("coins", 0)), int(r.get("exp", 0))])
			_refresh()


func _on_level_up(level: int) -> void:
	_toast("升级到 Lv.%d，解锁了新的地块！" % level)


func _on_reward(text: String) -> void:
	_toast(text)


# ---------------------------------------------------------------- 商店 / 背包

func _open_shop() -> void:
	var v := _modal_open("农场商店")
	v.add_child(UIKit.label("金币余额：%d" % Farm.coins(), 13, UIKit.MUTED))
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(0, 320)
	tabs.add_theme_font_override("font", UIKit.ui_font())
	v.add_child(tabs)

	tabs.add_child(_shop_tab("种子", "crops"))
	tabs.add_child(_shop_tab("道具", "items"))
	tabs.add_child(_shop_tab("装饰", "decorations"))


func _shop_tab(title: String, kind: String) -> Control:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := UIKit.vbox(10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var entries: Array = Farm.config.get(kind, []) if kind != "decorations" else Farm.config.get("decorations", [])
	for e in entries:
		var row := UIKit.card(UIKit.SOFT, 12, 0, UIKit.LINE, 12)
		var h := UIKit.hbox(12)
		var info := UIKit.vbox(3)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(UIKit.label(String(e.get("name", "")), 15, UIKit.TEXT, 700))
		var desc := String(e.get("desc", ""))
		if desc == "":
			desc = "生长 %s，卖价 %d 金币" % [_fmt_long(int(e.get("grow_seconds", 0))), int(e.get("sell_price", 0))]
		info.add_child(UIKit.label(desc, 12, UIKit.MUTED))
		h.add_child(info)
		var price := int(e.get("seed_price", e.get("price", 0)))
		h.add_child(UIKit.label("%d 金币" % price, 14, UIKit.GOLD, 700))
		var buy := UIKit.button("购买", "blue", 36)
		buy.custom_minimum_size = Vector2(76, 36)
		buy.disabled = Farm.coins() < price
		var id := String(e.get("id", ""))
		match kind:
			"crops":
				buy.pressed.connect(func() -> void: _buy_seed(id))
			"items":
				buy.pressed.connect(func() -> void: _buy_item(id))
			_:
				buy.pressed.connect(func() -> void: _buy_decor(id))
		h.add_child(buy)
		row.add_child(h)
		list.add_child(row)
	return scroll


func _buy_seed(id: String) -> void:
	if Farm.buy_seed(id):
		_toast("购买了 %s 种子" % String(Farm.crop_info(id).get("name", "")))
		_refresh()
		_open_shop()
	else:
		_toast("金币不足，无法购买")


func _buy_item(id: String) -> void:
	if Farm.buy_item(id):
		_toast("购买了 %s" % String(Farm.item_info(id).get("name", "")))
		_refresh()
		_open_shop()
	else:
		_toast("金币不足，无法购买")


func _buy_decor(id: String) -> void:
	if Farm.buy_decor(id):
		_toast("购买了 %s" % String(Farm.decor_info(id).get("name", "")))
		_refresh()
		_open_shop()
	else:
		_toast("金币不足，无法购买")


func _open_bag() -> void:
	var v := _modal_open("背包")
	v.add_child(UIKit.label("种子", 14, UIKit.TEXT, 700))
	var any_seed := false
	for cid in Farm.crop_ids():
		var n := Farm.seed_count(cid)
		if n <= 0:
			continue
		any_seed = true
		var row := UIKit.card(UIKit.SOFT, 10, 0, UIKit.LINE, 10)
		var h := UIKit.hbox(10)
		h.add_child(UIKit.label(String(Farm.crop_info(cid).get("name", cid)) + "种子", 14))
		h.add_child(UIKit.spacer())
		h.add_child(UIKit.label("×%d" % n, 14, UIKit.TEXT, 700))
		row.add_child(h)
		v.add_child(row)
	if not any_seed:
		v.add_child(UIKit.label("暂无种子，去商店买一些吧。", 13, UIKit.MUTED))

	v.add_child(UIKit.hsep(6))
	v.add_child(UIKit.label("道具", 14, UIKit.TEXT, 700))
	var any_item := false
	for item in Farm.config.get("items", []):
		var iid := String(item.get("id", ""))
		var n := Farm.item_count(iid)
		if n <= 0:
			continue
		any_item = true
		var row2 := UIKit.card(UIKit.SOFT, 10, 0, UIKit.LINE, 10)
		var h2 := UIKit.hbox(10)
		h2.add_child(UIKit.label(String(item.get("name", iid)), 14))
		h2.add_child(UIKit.spacer())
		h2.add_child(UIKit.label("×%d" % n, 14, UIKit.TEXT, 700))
		row2.add_child(h2)
		v.add_child(row2)
	if not any_item:
		v.add_child(UIKit.label("暂无道具。", 13, UIKit.MUTED))

	v.add_child(UIKit.hsep(6))
	var decor: Array = Farm.state.get("decor", [])
	v.add_child(UIKit.label("装饰（%d 件）" % decor.size(), 14, UIKit.TEXT, 700))
	if decor.is_empty():
		v.add_child(UIKit.label("还没有装饰，农场略朴素。", 13, UIKit.MUTED))


func _open_seed_picker() -> void:
	var v := _modal_open("选择种子")
	var any := false
	for cid in Farm.crop_ids():
		var n := Farm.seed_count(cid)
		var info := Farm.crop_info(cid)
		var row := UIKit.card(UIKit.SOFT, 12, 0, UIKit.LINE, 12)
		var h := UIKit.hbox(12)
		var info_box := UIKit.vbox(3)
		info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_box.add_child(UIKit.label(String(info.get("name", cid)), 15, UIKit.TEXT, 700))
		info_box.add_child(UIKit.label("生长 %s · 卖价 %d 金币 · +%d 经验" % [_fmt_long(int(info.get("grow_seconds", 0))), int(info.get("sell_price", 0)), int(info.get("exp", 0))], 12, UIKit.MUTED))
		h.add_child(info_box)
		h.add_child(UIKit.label("持有 ×%d" % n, 13, UIKit.MUTED))
		var plant_btn := UIKit.button("播种", "success", 36)
		plant_btn.custom_minimum_size = Vector2(76, 36)
		plant_btn.disabled = n <= 0
		plant_btn.pressed.connect(func() -> void: _plant(cid))
		h.add_child(plant_btn)
		row.add_child(h)
		v.add_child(row)
		any = true
	if not any:
		v.add_child(UIKit.label("没有可播种的作物配置。", 13, UIKit.MUTED))


func _plant(cid: String) -> void:
	if Farm.plant(selected, cid):
		_toast("已播种 %s" % String(Farm.crop_info(cid).get("name", "")))
		_modal_close()
		_refresh()
	else:
		_toast("播种失败：种子不足或地块状态不符")


func _open_item_picker() -> void:
	var v := _modal_open("使用道具")
	var any := false
	for item in Farm.config.get("items", []):
		var iid := String(item.get("id", ""))
		var n := Farm.item_count(iid)
		var row := UIKit.card(UIKit.SOFT, 12, 0, UIKit.LINE, 12)
		var h := UIKit.hbox(12)
		var info_box := UIKit.vbox(3)
		info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_box.add_child(UIKit.label(String(item.get("name", iid)), 15, UIKit.TEXT, 700))
		info_box.add_child(UIKit.label(String(item.get("desc", "")), 12, UIKit.MUTED))
		h.add_child(info_box)
		h.add_child(UIKit.label("持有 ×%d" % n, 13, UIKit.MUTED))
		var use_btn := UIKit.button("使用", "gold", 36)
		use_btn.custom_minimum_size = Vector2(76, 36)
		use_btn.disabled = n <= 0
		use_btn.pressed.connect(func() -> void: _use_item(iid))
		h.add_child(use_btn)
		row.add_child(h)
		v.add_child(row)
		any = true
	if not any:
		v.add_child(UIKit.label("没有可用道具配置。", 13, UIKit.MUTED))


func _use_item(iid: String) -> void:
	if Farm.use_item(selected, iid):
		_toast("已使用 %s" % String(Farm.item_info(iid).get("name", "")))
		_modal_close()
		_refresh()
	else:
		_toast("使用失败：没有该道具或地块不可用")


# ---------------------------------------------------------------- 模态框

func _build_modal() -> void:
	modal_layer = PanelContainer.new()
	modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.add_theme_stylebox_override("panel", UIKit.box(Color(0.10, 0.12, 0.16, 0.45), 0, 0, UIKit.LINE, 0))
	modal_layer.visible = false
	add_child(modal_layer)


func _modal_open(title: String) -> VBoxContainer:
	for c in modal_layer.get_children():
		c.queue_free()
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.add_child(center)
	var card := UIKit.card(UIKit.CARD, 16, 0, UIKit.LINE, 20)
	card.custom_minimum_size = Vector2(560, 0)
	center.add_child(card)
	var v := UIKit.vbox(12)
	card.add_child(v)
	var head := UIKit.hbox(10)
	head.add_child(UIKit.label(title, 20, UIKit.TEXT, 700))
	head.add_child(UIKit.spacer())
	var close_btn := UIKit.button("关闭", "ghost", 34)
	close_btn.custom_minimum_size = Vector2(72, 34)
	close_btn.pressed.connect(_modal_close)
	head.add_child(close_btn)
	v.add_child(head)
	v.add_child(UIKit.hsep(2))
	modal_layer.visible = true
	return v


func _modal_close() -> void:
	modal_layer.visible = false
	for c in modal_layer.get_children():
		c.queue_free()


# ---------------------------------------------------------------- 工具

func _fmt_short(sec: int) -> String:
	var s := maxi(sec, 0)
	return "%02d:%02d" % [int(s / 60), s % 60]


func _fmt_long(sec: int) -> String:
	var s := maxi(sec, 0)
	var m := int(s / 60)
	var h := int(m / 60)
	if h > 0:
		return "%d 小时 %d 分钟" % [h, m % 60]
	if m > 0:
		return "%d 分 %d 秒" % [m, s % 60]
	return "%d 秒" % s


func _toast(text: String) -> void:
	var main := get_tree().current_scene
	if main != null and main.has_method("toast"):
		main.toast(text)
