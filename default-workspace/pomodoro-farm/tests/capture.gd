## 截图脚本：以真实窗口运行，抓取四个页面的效果图到 res://docs/screenshots。
##
## 运行方式（需要可用的桌面环境）：
##   Godot_v4.5-stable_win64_console.exe --path <项目目录> res://tests/capture.tscn
extends Node

const OUT_DIR := "res://docs/screenshots"

var main: Node
var _prefix := ""


func _ready() -> void:
	var fresh := OS.get_cmdline_user_args().has("--fresh")
	if fresh:
		_prefix = "fresh_"
		Storage.reset_section("farm")
		Storage.reset_section("stats")
	else:
		_seed_demo()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _settle(6)

	# 让番茄钟处于“进行中”，截图更有说服力
	Pomodoro.bind_task("t_math")
	Pomodoro.start(25)
	Pomodoro.remaining = 754.0
	Pomodoro._last_sec = -1
	Pomodoro._emit_tick()
	await _settle(3)
	await _shoot("01_pomodoro")

	main._switch("farm")
	await _settle(4)
	await _shoot("02_farm")

	var farm_view: Node = main.view_nodes["farm"]
	farm_view._on_plot_pressed(4)
	await _settle(2)
	farm_view._open_seed_picker()
	await _settle(3)
	await _shoot("03_farm_seed_picker")
	farm_view._modal_close()

	farm_view._open_shop()
	await _settle(3)
	await _shoot("04_farm_shop")
	farm_view._modal_close()

	main._switch("stats")
	await _settle(4)
	await _shoot("05_stats")

	main._switch("settings")
	await _settle(4)
	await _shoot("06_settings")

	var settings_view: Node = main.view_nodes["settings"]
	settings_view.confirm_farm.popup_centered()
	await _settle(4)
	await _shoot("07_confirm_reset")
	settings_view.confirm_farm.hide()
	await _settle(2)

	main._switch("pomodoro")
	await _settle(3)
	var pomo_view: Node = main.view_nodes["pomodoro"]
	pomo_view._on_abandon()
	await _settle(4)
	await _shoot("08_confirm_abandon")
	pomo_view.confirm_abandon.hide()
	await _settle(2)

	print("capture done")
	get_tree().quit(0)


func _settle(frames: int) -> void:
	for _i in range(frames):
		await get_tree().process_frame


## 造一份接近线框图的演示数据，让截图更能说明玩法。
func _seed_demo() -> void:
	Storage.reset_section("farm")
	Storage.reset_section("stats")
	var now := Storage.now_unix()
	var st: Dictionary = Farm.state
	st["level"] = 3
	st["coins"] = 120
	st["exp"] = 45
	st["unlocked"] = 10
	st["seeds"] = {"wheat": 3, "carrot": 1}
	st["items"] = {"speed_card": 1, "fertilizer": 2}
	st["decor"] = ["fence"]
	st["plots"][0] = {"crop": "wheat", "planted_at": now - 100, "grow": 600}
	st["plots"][1] = {"crop": "carrot", "planted_at": now - 300, "grow": 1200}
	st["plots"][2] = {"crop": "wheat", "planted_at": now - 700, "grow": 600}
	st["plots"][3] = {"crop": "strawberry", "planted_at": now - 900, "grow": 1800}
	Farm._commit()

	var titles := ["数学", "英语", "复习错题"]
	var tags := ["数学", "英语", "复习"]
	var recs: Array = []
	var counts := [3, 2, 4, 1, 3, 2, 2]
	for d in range(7):
		var ts := now - (6 - d) * 86400
		for k in range(int(counts[d])):
			var t := ts - k * 3600 - 600
			recs.append({
				"ts": t,
				"day": Storage.day_key(t),
				"task_id": "t_%d" % (k % 3),
				"title": titles[k % 3],
				"tag": tags[k % 3],
				"seconds": 1500,
				"effective": true,
			})
	recs.append({"ts": now - 7200, "day": Storage.day_key(now - 7200), "task_id": "t_math", "title": "数学", "tag": "数学", "seconds": 300, "effective": false})
	TaskStats.state["records"] = recs
	TaskStats._commit()


func _shoot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s%s.png" % [OUT_DIR, _prefix, shot_name]
	var err := img.save_png(path)
	print("saved %s (err=%d)" % [path, err])
