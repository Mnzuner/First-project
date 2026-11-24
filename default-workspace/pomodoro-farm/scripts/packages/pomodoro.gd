## PomodoroPackage 番茄计时包
##
## 职责：番茄倒计时、暂停 / 放弃逻辑、计时状态、计时提醒。
## 依赖：BaseStoragePackage（读写时长配置、获取系统时间）。
## 对外只通过信号与 FarmPackage / TaskStatsPackage 通信，不做直接调用。
extends Node

const PHASE_FOCUS := "focus"
const PHASE_BREAK := "break"

## 单次番茄允许暂停的次数（文档：最多暂停 1 次）。
const MAX_PAUSE := 1
## 暂停超过该秒数，本次番茄自动作废。
const PAUSE_LIMIT_SECONDS := 300

signal tick(remaining: float, total: float, phase: String)
signal phase_changed(phase: String)
signal state_changed(running: bool, paused: bool)
## 一次番茄结束（有效或无效）时发出，供农场发奖、统计记录消费。
signal pomodoro_completed(task_id: String, focus_seconds: int, effective: bool)
## 专注阶段正常结束。
signal focus_finished()
## 休息阶段正常结束。
signal break_finished()
## 面向界面的提示（例如暂停超时作废）。
signal notice(text: String)

var phase: String = PHASE_FOCUS
var total: float = 1500.0
var remaining: float = 1500.0
var running: bool = false
var paused: bool = false
var pause_used: bool = false
var bound_task_id: String = ""

var _pause_started: int = 0
var _last_sec: int = -1


func _ready() -> void:
	_prepare(PHASE_FOCUS)


func _process(delta: float) -> void:
	if not running:
		return
	if paused:
		if _pause_started > 0 and Storage.now_unix() - _pause_started > PAUSE_LIMIT_SECONDS:
			notice.emit("暂停超过 5 分钟，本次番茄已作废")
			abandon()
		return
	remaining = maxf(0.0, remaining - delta)
	_emit_tick()
	if remaining <= 0.0:
		_complete()


# ---------------------------------------------------------------- 配置

func focus_minutes() -> int:
	return int(Storage.value("settings", "focus_minutes", 25))


func break_minutes() -> int:
	return int(Storage.value("settings", "break_minutes", 5))


func minutes_of(current_phase: String) -> int:
	return focus_minutes() if current_phase == PHASE_FOCUS else break_minutes()


# ---------------------------------------------------------------- 控制

func bind_task(task_id_value: String) -> void:
	bound_task_id = task_id_value


## 开始计时；minutes<=0 时使用设置里的默认时长。
func start(minutes: int = -1) -> void:
	if running:
		return
	if minutes > 0:
		total = float(minutes) * 60.0
	else:
		total = float(minutes_of(phase)) * 60.0
	remaining = total
	running = true
	paused = false
	pause_used = false
	_pause_started = 0
	_last_sec = -1
	phase_changed.emit(phase)
	state_changed.emit(true, false)
	_emit_tick()


func pause() -> void:
	if not running or paused:
		return
	if pause_used:
		notice.emit("本次番茄已经暂停过 1 次，不能再次暂停")
		return
	pause_used = true
	paused = true
	_pause_started = Storage.now_unix()
	state_changed.emit(true, true)
	_emit_tick()


func resume() -> void:
	if not running or not paused:
		return
	paused = false
	_pause_started = 0
	state_changed.emit(true, false)
	_emit_tick()


func toggle_pause() -> void:
	if paused:
		resume()
	else:
		pause()


## 放弃本次番茄：专注阶段记为一次“无效番茄”。
func abandon() -> void:
	var was_focus := phase == PHASE_FOCUS
	var elapsed := int(total - remaining)
	var task := bound_task_id
	var had_progress := running or remaining < total
	running = false
	paused = false
	pause_used = false
	_pause_started = 0
	if was_focus and had_progress:
		pomodoro_completed.emit(task, elapsed, false)
	phase = PHASE_FOCUS
	_prepare(PHASE_FOCUS)
	state_changed.emit(false, false)
	notice.emit("已放弃本次番茄")


## 跳过当前的休息阶段。
func skip_break() -> void:
	if phase != PHASE_BREAK:
		return
	running = false
	paused = false
	_prepare(PHASE_FOCUS)
	state_changed.emit(false, false)


## 直接把当前倒计时推到结束（测试与演示用）。
func force_finish() -> void:
	if not running:
		start()
	remaining = 0.01


# ---------------------------------------------------------------- 内部

func _prepare(p: String) -> void:
	phase = p
	total = float(minutes_of(p)) * 60.0
	remaining = total
	running = false
	paused = false
	pause_used = false
	_pause_started = 0
	phase_changed.emit(p)
	tick.emit(remaining, total, phase)


func _complete() -> void:
	running = false
	paused = false
	pause_used = false
	if phase == PHASE_FOCUS:
		var task := bound_task_id
		pomodoro_completed.emit(task, int(total), true)
		focus_finished.emit()
		_prepare(PHASE_BREAK)
	else:
		break_finished.emit()
		_prepare(PHASE_FOCUS)
	state_changed.emit(false, false)


func _emit_tick() -> void:
	var sec := int(ceil(remaining))
	if sec != _last_sec:
		_last_sec = sec
		tick.emit(remaining, total, phase)


func progress() -> float:
	if total <= 0.0:
		return 0.0
	return clampf(1.0 - remaining / total, 0.0, 1.0)
