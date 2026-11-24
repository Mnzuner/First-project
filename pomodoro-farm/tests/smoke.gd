## 无界面冒烟测试：直接驱动四个包，验证核心业务规则。
##
## 运行方式：
##   Godot_v4.5-stable_win64_console.exe --headless --path <项目目录> res://tests/smoke.tscn
## 全部通过时进程退出码为 0，否则为 1。
extends Node

var failures: Array = []
var total := 0


func _ready() -> void:
	await get_tree().process_frame
	Storage.reset_section("farm")
	Storage.reset_section("stats")
	await get_tree().process_frame

	_test_storage()
	_test_tasks()
	await _test_pomodoro_reward()
	_test_farm_plant_harvest()
	_test_farm_shop()
	_test_level_up()
	_test_stats_series()
	_test_week_start()
	_test_reset()

	print("")
	if failures.is_empty():
		print("SMOKE TEST PASSED: %d checks" % total)
		get_tree().quit(0)
	else:
		print("SMOKE TEST FAILED: %d/%d checks failed" % [failures.size(), total])
		for f in failures:
			print("  - " + String(f))
		get_tree().quit(1)


func check(cond: bool, msg: String) -> void:
	total += 1
	if not cond:
		failures.append(msg)
		print("FAIL: " + msg)


# ---------------------------------------------------------------- 用例

func _test_storage() -> void:
	Storage.set_value("test", "k", 42)
	check(int(Storage.value("test", "k", 0)) == 42, "Storage 写入后能读回同一个值")
	check(Storage.day_key(Storage.now_unix()) == Time.get_date_string_from_system(), "day_key 与系统日期一致")
	check(Storage.time_of_day(Storage.now_unix()).length() == 5, "time_of_day 返回 HH:MM")


func _test_tasks() -> void:
	var before := TaskStats.tasks().size()
	var t := TaskStats.add_task("冒烟测试任务", "测试")
	check(not t.is_empty(), "add_task 返回新任务")
	check(TaskStats.tasks().size() == before + 1, "add_task 后任务数量 +1")
	check(TaskStats.task_title(String(t.get("id", ""))) == "冒烟测试任务", "task_title 能查到标题")
	check(TaskStats.add_task("   ", "x").is_empty(), "空标题任务被拒绝")
	TaskStats.remove_task(String(t.get("id", "")))
	check(TaskStats.tasks().size() == before, "remove_task 后任务数量复原")


func _test_pomodoro_reward() -> void:
	var coins_before := Farm.coins()
	var tasks := TaskStats.tasks()
	var task_id := String(tasks[0].get("id", "")) if not tasks.is_empty() else ""
	var records_before := TaskStats.records().size()
	Pomodoro.bind_task(task_id)
	Pomodoro.start(1)
	check(Pomodoro.running, "start 后进入运行状态")
	check(int(Pomodoro.total) == 60, "start(1) 的总时长为 60 秒")
	Pomodoro.force_finish()
	# `process_frame` 信号在节点 _process 之前触发，所以这里等到记录真正产生为止。
	for _i in range(120):
		if TaskStats.records().size() > records_before:
			break
		await get_tree().process_frame
	check(Farm.coins() == coins_before + 20, "有效番茄使金币 +20（实际 %d → %d）" % [coins_before, Farm.coins()])
	check(TaskStats.records().size() == records_before + 1, "番茄结束后新增一条统计记录")
	if TaskStats.records().size() > records_before:
		var rec: Dictionary = TaskStats.records()[-1]
		check(bool(rec.get("effective", false)), "正常完成的番茄记为有效")
		check(String(rec.get("task_id", "")) == task_id, "统计记录带上了绑定的任务 ID")
	check(Pomodoro.phase == Pomodoro.PHASE_BREAK, "专注结束后自动切到休息阶段")

	# 放弃的番茄记录为无效，且不发农场奖励
	var coins_now := Farm.coins()
	Pomodoro.skip_break()
	Pomodoro.start(1)
	Pomodoro.abandon()
	await get_tree().process_frame
	check(Farm.coins() == coins_now, "放弃的番茄不发放农场奖励")
	if not TaskStats.records().is_empty():
		var last: Dictionary = TaskStats.records()[-1]
		check(not bool(last.get("effective", true)), "放弃的番茄记为无效")

	# 暂停只能一次
	Pomodoro.start(1)
	Pomodoro.pause()
	check(Pomodoro.paused, "第一次暂停成功")
	Pomodoro.resume()
	Pomodoro.pause()
	check(not Pomodoro.paused, "第二次暂停被拒绝")
	Pomodoro.abandon()
	await get_tree().process_frame


func _test_farm_plant_harvest() -> void:
	Farm.grant_seed("wheat", 1)
	check(Farm.seed_count("wheat") > 0, "grant_seed 增加种子数量")
	var coins := Farm.coins()
	var ok := Farm.plant(0, "wheat")
	check(ok, "空闲地块可以播种")
	check(Farm.plot_state(0) == "growing", "播种后地块进入生长中")
	check(Farm.plot_state(15) == "locked", "未解锁地块状态为 locked")
	check(not Farm.plant(0, "wheat"), "生长中的地块不能重复播种")

	# 把播种时间往前推，模拟作物成熟
	Farm.state["plots"][0]["planted_at"] = Storage.now_unix() - 700
	check(Farm.plot_state(0) == "ready", "超过生长时间后地块变为可收获")
	var gain := Farm.harvest(0)
	check(not gain.is_empty(), "成熟地块可以收获")
	check(Farm.coins() == coins + 40, "收获小麦获得 40 金币")
	check(Farm.plot_state(0) == "idle", "收获后地块回到空闲")

	# 加速卡：剩余时间减半
	Farm.grant_seed("wheat", 1)
	Farm.plant(1, "wheat")
	var before_rem := Farm.remaining_seconds(1)
	Farm.state["items"]["speed_card"] = 1
	check(Farm.use_item(1, "speed_card"), "加速卡可以对生长中地块使用")
	var after_rem := Farm.remaining_seconds(1)
	check(after_rem <= int(before_rem / 2) + 1, "加速卡把剩余生长时间缩短一半（%d → %d）" % [before_rem, after_rem])
	Farm.state["plots"][1] = {"crop": "", "planted_at": 0, "grow": 0}
	Farm._commit()


func _test_farm_shop() -> void:
	var coins := Farm.coins()
	check(Farm.buy_seed("wheat"), "金币足够时可以购买种子")
	check(Farm.coins() == coins - 30, "购买小麦种子花费 30 金币")
	Farm.state["coins"] = 0
	check(not Farm.buy_seed("wheat"), "金币不足时购买失败")
	check(Farm.coins() == 0, "购买失败不扣金币")
	Farm.state["coins"] = coins - 30
	Farm._commit()


func _test_level_up() -> void:
	var level_before := Farm.level()
	var unlocked_before := Farm.unlocked_count()
	var need := Farm.exp_needed()
	Farm._add_exp(need)
	check(Farm.level() == level_before + 1, "经验达到上限后升级")
	check(Farm.unlocked_count() == unlocked_before + 2, "升级后解锁 2 块新地")
	check(Farm.exp_points() < Farm.exp_needed(), "升级后剩余经验小于新等级所需经验")


func _test_stats_series() -> void:
	var daily := TaskStats.daily_series(7)
	check(daily.size() == 7, "日视图序列长度为 7")
	var weekly := TaskStats.weekly_series(6)
	check(weekly.size() == 6, "周视图序列长度为 6")
	var s := TaskStats.summary()
	check(int(s.get("count", -1)) >= 1, "汇总里至少有 1 个有效番茄")
	check(int(s.get("invalid", -1)) >= 1, "汇总里至少有 1 个无效番茄")
	check(TaskStats.history(1).size() == 1, "history(1) 只返回 1 条")


func _test_week_start() -> void:
	# 以 2026-10-25（周日）为基准：按“周一开始”的规则应归入 2026-10-19 那一周。
	var sunday := Time.get_unix_time_from_datetime_dict({"year": 2026, "month": 10, "day": 25, "hour": 12, "minute": 0, "second": 0})
	var d := Time.get_datetime_dict_from_unix_time(sunday)
	check(int(d.weekday) == 0, "测试基准时间确实是周日")
	var expected := Storage.day_key(sunday - 6 * 86400)
	check(expected == "2026-10-19", "基准周一应当是 2026-10-19，实际 %s" % expected)
	check(Storage.day_key(Storage.week_start(sunday)) == expected, "周日被正确归入本周，实际 %s" % Storage.day_key(Storage.week_start(sunday)))
	check(Storage.day_key(Storage.week_start(sunday - 6 * 86400)) == expected, "本周一归入同一周")
	check(Storage.day_key(Storage.week_start(sunday - 86400)) == expected, "本周六归入同一周")
	check(Storage.day_key(Storage.week_start(sunday + 7 * 86400)) != expected, "下一周不与本周混同")


func _test_reset() -> void:
	Storage.reset_section("farm")
	check(Farm.coins() == 120, "重置农场后金币回到初始 120")
	check(Farm.level() == 1, "重置农场后等级回到 1")
	check(Farm.unlocked_count() == 6, "重置农场后地块回到 6 块")
	Storage.reset_section("stats")
	check(TaskStats.records().is_empty(), "重置统计后番茄记录被清空")
	check(TaskStats.tasks().size() == 3, "重置统计后恢复默认任务")
