## BaseStoragePackage 基础存储包
##
## 职责：本地 JSON 读写、配置加载、数据重置、获取系统时间。
## 依赖：无（不依赖任何上层业务包）。
extends Node

const SAVE_PATH := "user://save_data.json"

## 某个分区被写入后发出，UI 可据此刷新。
signal section_changed(section: String)
## 某个分区被重置后发出。
signal section_reset(section: String)

var _data: Dictionary = {}
var _dirty: bool = false
var _accum: float = 0.0


func _ready() -> void:
	_load()


func _process(delta: float) -> void:
	if not _dirty:
		return
	_accum += delta
	if _accum >= 0.4:
		_accum = 0.0
		flush()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		flush()


func _load() -> void:
	_data = {}
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		push_warning("BaseStoragePackage: 无法打开存档 %s" % SAVE_PATH)
		return
	var txt := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) == TYPE_DICTIONARY:
		_data = parsed
	else:
		push_warning("BaseStoragePackage: 存档解析失败，已按空存档启动")


## 取整个分区（返回的是内部引用，改完请调用 touch() 或 set_section()）。
func get_section(name: String) -> Dictionary:
	var v: Variant = _data.get(name)
	if typeof(v) == TYPE_DICTIONARY:
		return v
	var fresh: Dictionary = {}
	_data[name] = fresh
	return fresh


## 覆盖写入整个分区。
func set_section(name: String, value: Dictionary) -> void:
	_data[name] = value
	_dirty = true
	section_changed.emit(name)


## 读取单个配置项，缺省时写入默认值。
func value(section: String, key: String, default_value: Variant) -> Variant:
	var d := get_section(section)
	if d.has(key):
		return d[key]
	d[key] = default_value
	_dirty = true
	return default_value


## 写入单个配置项。
func set_value(section: String, key: String, value: Variant) -> void:
	var d := get_section(section)
	d[key] = value
	_dirty = true
	section_changed.emit(section)


## 标记分区已变更（调用方直接改字典时使用）。
func touch(section: String) -> void:
	_dirty = true
	section_changed.emit(section)


## 立即落盘。
func flush() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("BaseStoragePackage: 无法写入存档 %s" % SAVE_PATH)
		return
	f.store_string(JSON.stringify(_data, "\t"))
	f.close()
	_dirty = false


## 重置一个分区（用于设置页的“重置农场数据 / 重置学习统计”）。
func reset_section(name: String) -> void:
	_data.erase(name)
	_dirty = true
	flush()
	section_changed.emit(name)
	section_reset.emit(name)


func now_unix() -> int:
	return int(Time.get_unix_time_from_system())


func is_today(ts: int) -> bool:
	return day_key(ts) == day_key(now_unix())


func day_key(ts: int = -1) -> String:
	var t := ts if ts > 0 else now_unix()
	var d := Time.get_datetime_dict_from_unix_time(t)
	return "%04d-%02d-%02d" % [int(d.year), int(d.month), int(d.day)]


func time_of_day(ts: int) -> String:
	var d := Time.get_datetime_dict_from_unix_time(int(ts))
	return "%02d:%02d" % [int(d.hour), int(d.minute)]


## 星期一 = 0 的周序号（用于周视图聚合）。
func week_start(ts: int) -> int:
	var d := Time.get_datetime_dict_from_unix_time(int(ts))
	var t := int(ts) - (int(d.hour) * 3600 + int(d.minute) * 60 + int(d.second))
	# Godot 里 weekday 0=周日、1=周一……6=周六，先换算成“距本周一的天数”。
	var days_since_monday := (int(d.weekday) + 6) % 7
	return t - days_since_monday * 86400
