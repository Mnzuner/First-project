## FarmPackage 农场养成包
##
## 职责：地块管理、作物生长、商店、背包、收获、道具、等级。
## 依赖：BaseStoragePackage。
## 与番茄包不直接调用：订阅 PomodoroPackage 的 pomodoro_completed 事件发奖。
extends Node

const CONFIG_PATH := "res://data/game_config.json"
const STATE_SECTION := "farm"

signal farm_changed()
signal level_up(level: int)
signal reward_gained(text: String)

var config: Dictionary = {}
var state: Dictionary = {}


func _ready() -> void:
	_load_config()
	ensure_state()
	Pomodoro.pomodoro_completed.connect(_on_pomodoro_completed)
	Storage.section_reset.connect(_on_section_reset)


# ---------------------------------------------------------------- 初始化

func _load_config() -> void:
	var f := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if f == null:
		push_error("FarmPackage: 无法读取配置文件 %s" % CONFIG_PATH)
		config = {}
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	config = parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _on_section_reset(section: String) -> void:
	if section == STATE_SECTION:
		state = {}
		ensure_state()
		farm_changed.emit()


func ensure_state() -> void:
	state = Storage.get_section(STATE_SECTION)
	if state.is_empty():
		state["level"] = 1
		state["coins"] = int(config.get("start_coins", 120))
		state["exp"] = 0
		state["unlocked"] = int(config.get("start_plots", 6))
		state["seeds"] = {"wheat": 2}
		state["items"] = {}
		state["decor"] = []
		state["plots"] = []
	for i in int(config.get("max_plots", 16)):
		var plots: Array = state.get("plots", [])
		if plots.size() <= i:
			plots.append({"crop": "", "planted_at": 0, "grow": 0})
			state["plots"] = plots
	state["seeds"] = state.get("seeds", {})
	state["items"] = state.get("items", {})
	state["decor"] = state.get("decor", [])
	Storage.touch(STATE_SECTION)


func _commit() -> void:
	Storage.set_section(STATE_SECTION, state)
	farm_changed.emit()


# ---------------------------------------------------------------- 查询

func plots_count() -> int:
	return int(config.get("max_plots", 16))


func unlocked_count() -> int:
	return int(state.get("unlocked", 6))


## 第 i 块地（0 起）需要升到几级才能解锁。
func level_for_plot(i: int) -> int:
	var start := int(config.get("start_plots", 6))
	var per := maxi(int(config.get("plots_per_level", 2)), 1)
	if i < start:
		return 1
	return 1 + int(ceil(float(i + 1 - start) / float(per)))


func level() -> int:
	return int(state.get("level", 1))


func coins() -> int:
	return int(state.get("coins", 0))


func exp_points() -> int:
	return int(state.get("exp", 0))


func exp_needed() -> int:
	return int(config.get("level_base_exp", 200)) + (level() - 1) * int(config.get("level_exp_step", 100))


func plot(i: int) -> Dictionary:
	var plots: Array = state.get("plots", [])
	if i < 0 or i >= plots.size():
		return {}
	return plots[i]


## 返回 "locked" / "idle" / "growing" / "ready"。
func plot_state(i: int) -> String:
	if i >= unlocked_count():
		return "locked"
	var p := plot(i)
	if p.is_empty() or String(p.get("crop", "")) == "":
		return "idle"
	return "ready" if remaining_seconds(i) <= 0 else "growing"


func remaining_seconds(i: int) -> int:
	var p := plot(i)
	if p.is_empty():
		return 0
	var crop := String(p.get("crop", ""))
	if crop == "":
		return 0
	var end := int(p.get("planted_at", 0)) + int(p.get("grow", 0))
	return maxi(0, end - Storage.now_unix())


func crop_ids() -> Array:
	var out: Array = []
	for c in config.get("crops", []):
		out.append(String(c.get("id", "")))
	return out


func crop_info(crop_id: String) -> Dictionary:
	for c in config.get("crops", []):
		if String(c.get("id", "")) == crop_id:
			return c
	return {}


func item_info(item_id: String) -> Dictionary:
	for c in config.get("items", []):
		if String(c.get("id", "")) == item_id:
			return c
	return {}


func decor_info(decor_id: String) -> Dictionary:
	for c in config.get("decorations", []):
		if String(c.get("id", "")) == decor_id:
			return c
	return {}


func seed_count(crop_id: String) -> int:
	var seeds: Dictionary = state.get("seeds", {})
	return int(seeds.get(crop_id, 0))


func item_count(item_id: String) -> int:
	var items: Dictionary = state.get("items", {})
	return int(items.get(item_id, 0))


# ---------------------------------------------------------------- 操作

## 播种：需要背包里有对应种子。
func plant(i: int, crop_id: String) -> bool:
	if plot_state(i) != "idle":
		return false
	if seed_count(crop_id) <= 0:
		return false
	var info := crop_info(crop_id)
	if info.is_empty():
		return false
	var seeds: Dictionary = state.get("seeds", {})
	seeds[crop_id] = seed_count(crop_id) - 1
	var plots: Array = state.get("plots", [])
	plots[i] = {
		"crop": crop_id,
		"planted_at": Storage.now_unix(),
		"grow": int(info.get("grow_seconds", 600)),
	}
	_commit()
	return true


## 收获：成熟地块 → 金币 + 经验，返回奖励信息（未成熟返回空字典）。
func harvest(i: int) -> Dictionary:
	if plot_state(i) != "ready":
		return {}
	var p := plot(i)
	var info := crop_info(String(p.get("crop", "")))
	var gain_coins := int(info.get("sell_price", 0))
	var gain_exp := int(info.get("exp", 0))
	var plots: Array = state.get("plots", [])
	plots[i] = {"crop": "", "planted_at": 0, "grow": 0}
	state["coins"] = coins() + gain_coins
	_add_exp(gain_exp)
	_commit()
	return {"coins": gain_coins, "exp": gain_exp, "name": String(info.get("name", "作物"))}


func buy_seed(crop_id: String) -> bool:
	var info := crop_info(crop_id)
	if info.is_empty():
		return false
	var price := int(info.get("seed_price", 0))
	if coins() < price:
		return false
	var seeds: Dictionary = state.get("seeds", {})
	seeds[crop_id] = seed_count(crop_id) + 1
	state["coins"] = coins() - price
	_commit()
	return true


func buy_item(item_id: String) -> bool:
	var info := item_info(item_id)
	if info.is_empty():
		return false
	var price := int(info.get("price", 0))
	if coins() < price:
		return false
	var items: Dictionary = state.get("items", {})
	items[item_id] = item_count(item_id) + 1
	state["coins"] = coins() - price
	_commit()
	return true


func buy_decor(decor_id: String) -> bool:
	var info := decor_info(decor_id)
	if info.is_empty():
		return false
	var price := int(info.get("price", 0))
	if coins() < price:
		return false
	var decor: Array = state.get("decor", [])
	decor.append(decor_id)
	state["decor"] = decor
	state["coins"] = coins() - price
	_commit()
	return true


## 使用道具：仅对生长中的地块有效。
func use_item(i: int, item_id: String) -> bool:
	if plot_state(i) != "growing":
		return false
	if item_count(item_id) <= 0:
		return false
	var rem := remaining_seconds(i)
	var plots: Array = state.get("plots", [])
	var p: Dictionary = plots[i]
	match item_id:
		"speed_card":
			p["planted_at"] = int(p.get("planted_at", 0)) - int(rem / 2)
		"fertilizer":
			p["planted_at"] = int(p.get("planted_at", 0)) - mini(rem, 120)
		_:
			return false
	plots[i] = p
	var items: Dictionary = state.get("items", {})
	items[item_id] = item_count(item_id) - 1
	_commit()
	return true


func grant_seed(crop_id: String, amount: int = 1) -> void:
	var seeds: Dictionary = state.get("seeds", {})
	seeds[crop_id] = seed_count(crop_id) + amount
	_commit()


# ---------------------------------------------------------------- 事件

## 番茄结束事件：只有有效番茄才发奖。
func _on_pomodoro_completed(_task_id: String, _seconds: int, effective: bool) -> void:
	if not effective:
		return
	var gain_coins := int(config.get("reward_coins", 20))
	var gain_exp := int(config.get("reward_exp", 15))
	state["coins"] = coins() + gain_coins
	_add_exp(gain_exp)
	# 一定概率额外奖励一颗种子，让番茄与农场形成正反馈。
	var pool := crop_ids()
	if not pool.is_empty() and randf() < float(config.get("reward_seed_chance", 0.3)):
		var pick := String(pool[randi() % pool.size()])
		grant_seed(pick, 1)
		reward_gained.emit("番茄完成：+%d 金币，+%d 经验，获得 1 颗%s种子" % [gain_coins, gain_exp, String(crop_info(pick).get("name", "作物"))])
	else:
		reward_gained.emit("番茄完成：+%d 金币，+%d 经验" % [gain_coins, gain_exp])
	_commit()


func _add_exp(amount: int) -> void:
	state["exp"] = exp_points() + amount
	while exp_points() >= exp_needed():
		state["exp"] = exp_points() - exp_needed()
		state["level"] = level() + 1
		state["unlocked"] = mini(int(config.get("max_plots", 16)), unlocked_count() + int(config.get("plots_per_level", 2)))
		level_up.emit(level())
