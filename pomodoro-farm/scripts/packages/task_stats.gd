## TaskStatsPackage 任务统计包
##
## 职责：学习任务增删改查、标签管理、番茄记录聚合、统计报表计算。
## 依赖：BaseStoragePackage；通过订阅 PomodoroPackage 的 pomodoro_completed
##       事件消费番茄数据（不直接调用番茄包的内部函数）。
extends Node

const STATE_SECTION := "stats"

signal tasks_changed()
signal records_changed()

var state: Dictionary = {}


func _ready() -> void:
	ensure_state()
	Pomodoro.pomodoro_completed.connect(_on_pomodoro_completed)
	Storage.section_reset.connect(_on_section_reset)


func _on_section_reset(section: String) -> void:
	if section == STATE_SECTION:
		state = {}
		ensure_state()
		tasks_changed.emit()
		records_changed.emit()


func ensure_state() -> void:
	state = Storage.get_section(STATE_SECTION)
	if not state.has("tasks"):
		state["tasks"] = []
	if not state.has("records"):
		state["records"] = []
	if (state["tasks"] as Array).is_empty():
		var now := Storage.now_unix()
		state["tasks"] = [
			{"id": "t_math", "title": "数学", "tag": "数学", "created_at": now},
			{"id": "t_english", "title": "英语", "tag": "英语", "created_at": now},
			{"id": "t_review", "title": "复习错题", "tag": "复习", "created_at": now},
		]
	Storage.touch(STATE_SECTION)


func _commit() -> void:
	Storage.set_section(STATE_SECTION, state)


# ---------------------------------------------------------------- 任务

func tasks() -> Array:
	return state.get("tasks", [])


func add_task(title: String, tag: String = "") -> Dictionary:
	var clean := title.strip_edges()
	if clean == "":
		return {}
	var task := {
		"id": "t_%d_%d" % [Storage.now_unix(), randi() % 10000],
		"title": clean,
		"tag": tag.strip_edges() if tag.strip_edges() != "" else "未分类",
		"created_at": Storage.now_unix(),
	}
	var list: Array = tasks()
	list.append(task)
	state["tasks"] = list
	_commit()
	tasks_changed.emit()
	return task


func remove_task(task_id: String) -> void:
	var list: Array = tasks()
	for i in range(list.size() - 1, -1, -1):
		if String(list[i].get("id", "")) == task_id:
			list.remove_at(i)
	state["tasks"] = list
	_commit()
	tasks_changed.emit()


func task_title(task_id: String) -> String:
	for t in tasks():
		if String(t.get("id", "")) == task_id:
			return String(t.get("title", ""))
	return ""


func task_tag(task_id: String) -> String:
	for t in tasks():
		if String(t.get("id", "")) == task_id:
			return String(t.get("tag", ""))
	return ""


# ---------------------------------------------------------------- 记录

func _on_pomodoro_completed(task_id: String, seconds: int, effective: bool) -> void:
	add_record(task_id, seconds, effective)


func add_record(task_id: String, seconds: int, effective: bool) -> void:
	var list: Array = state.get("records", [])
	var ts := Storage.now_unix()
	list.append({
		"ts": ts,
		"day": Storage.day_key(ts),
		"task_id": task_id,
		"title": task_title(task_id) if task_id != "" else "未绑定任务",
		"tag": task_tag(task_id) if task_id != "" else "未分类",
		"seconds": seconds,
		"effective": effective,
	})
	state["records"] = list
	_commit()
	records_changed.emit()


func records() -> Array:
	return state.get("records", [])


## 某一天（或整个区间）的汇总。
func summary(from_ts: int = -1, to_ts: int = -1) -> Dictionary:
	var count := 0
	var invalid := 0
	var seconds := 0
	for r in records():
		var ts := int(r.get("ts", 0))
		if from_ts > 0 and ts < from_ts:
			continue
		if to_ts > 0 and ts > to_ts:
			continue
		if bool(r.get("effective", false)):
			count += 1
			seconds += int(r.get("seconds", 0))
		else:
			invalid += 1
	return {"count": count, "invalid": invalid, "seconds": seconds}


## 最近 N 天的每日序列（用于日视图柱状图）。
func daily_series(days: int = 7) -> Array:
	var out: Array = []
	var today := Storage.now_unix()
	for i in range(days - 1, -1, -1):
		var day_start := today - i * 86400
		var key := Storage.day_key(day_start)
		var count := 0
		var seconds := 0
		for r in records():
			if String(r.get("day", "")) == key and bool(r.get("effective", false)):
				count += 1
				seconds += int(r.get("seconds", 0))
		out.append({"label": "%d/%d" % [Time.get_datetime_dict_from_unix_time(day_start).month, Time.get_datetime_dict_from_unix_time(day_start).day], "value": count, "seconds": seconds, "day": key})
	return out


## 最近 N 周的每周序列（用于周视图柱状图）。
func weekly_series(weeks: int = 6) -> Array:
	var out: Array = []
	var now := Storage.now_unix()
	for w in range(weeks - 1, -1, -1):
		var start := Storage.week_start(now) - w * 7 * 86400
		var end := start + 7 * 86400 - 1
		var s := summary(start, end)
		var d := Time.get_datetime_dict_from_unix_time(start)
		out.append({"label": "%d/%d周" % [int(d.month), int(d.day)], "value": int(s.count), "seconds": int(s.seconds), "day": Storage.day_key(start)})
	return out


## 历史流水（默认最近 30 条，倒序）。
func history(limit: int = 30) -> Array:
	var list: Array = records()
	var out: Array = []
	for i in range(list.size() - 1, -1, -1):
		out.append(list[i])
		if out.size() >= limit:
			break
	return out
