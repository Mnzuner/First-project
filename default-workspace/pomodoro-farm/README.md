# 番茄农场 Pomodoro Farm

课程小组项目「成员 4」的可运行交付物：**番茄钟 + 农场养成**学习应用。
按《第六组》文档的 UML 逻辑包图与 4 张低保真线框图，用 **Godot 4.x（GDScript）** 实现，本地单机运行，无任何第三方资源依赖。

- 引擎版本：Godot **4.5 stable**（`4.5.stable.official.876b29033`），在 Windows 11 + NVIDIA RTX 3050 上验证通过
- 界面：1280×820，全部由 GDScript 代码构建（`scenes/main.tscn` 只有一个根节点），中文字体使用系统字体回退链
- 存档：`user://save_data.json`（Windows 下位于 `%APPDATA%\Godot\app_userdata\番茄农场 Pomodoro Farm\`）

---

## 1. 快速开始

**方式一：Godot 编辑器**

1. 用 Godot 4.5（或 4.3+）打开本目录下的 `project.godot`；
2. 首次打开会导入资源，按 `F5` 运行主场景 `scenes/main.tscn`。

**方式二：双击 `运行游戏.bat`（Windows）**

双击后会弹出一个黑色命令行窗口，显示引擎路径后**保持打开**（游戏窗口在前面，命令行窗口留在后面，属于正常现象）；关闭游戏时它会显示「游戏已退出，退出码 0」并自己关掉。启动失败时窗口不会消失，会把 ` .runtime\launch.log` 的内容打印出来并停在 `pause`。

脚本会自动做三件事：

1. 依次在「本项目目录 → 上一级 `tools\` → PATH」里找 Godot 4.x；
2. 把 `%APPDATA%` 重定向到项目内的 `.runtime\appdata`（**便携模式**），这样存档、日志都跟着项目走，不受系统目录权限影响；
3. 把引擎输出写进 `.runtime\launch.log`，出错时直接回显。

> 便携模式下的存档位置：`pomodoro-farm\.runtime\appdata\Godot\app_userdata\番茄农场 Pomodoro Farm\save_data.json`
> 用编辑器（方式一）运行时，存档则在系统的 `%APPDATA%\Godot\app_userdata\` 下，两处互不影响。

等价的命令行：

```bat
Godot_v4.5-stable_win64.exe --path <本项目目录>
```

> 首次运行若提示找不到 `UIKit / RingTimer / BarChart` 类，说明脚本类缓存还没生成：用编辑器打开一次项目（或执行
> `--headless --editor --path <项目> --quit-after 600`）即可完成导入。

---

## 2. 界面效果

| 模块 | 截图 | 对应线框图 |
| --- | --- | --- |
| 番茄钟（专注进行中） | ![番茄钟](docs/screenshots/01_pomodoro.png) | 图 1：圆形倒计时 + 任务绑定 + 时长模板 + 开始/暂停/放弃 |
| 农场主界面 | ![农场](docs/screenshots/02_farm.png) | 图 2：等级/金币/经验条 + 4×4 地块 + 地块信息面板 |
| 选择种子 | ![选择种子](docs/screenshots/03_farm_seed_picker.png) | 图 2 交互态：空闲地块 → 选择种子 |
| 农场商店（模态） | ![商店](docs/screenshots/04_farm_shop.png) | 图 3：种子/道具/装饰 三个标签页，买不起置灰 |
| 统计看板 | ![统计](docs/screenshots/05_stats.png) | 图 4：日/周视图、有效番茄、累计专注、柱状图、历史记录 |
| 设置 | ![设置](docs/screenshots/06_settings.png) | 图 4 附属：音效开关、音量、默认时长、重置数据 |
| 破坏性操作二次确认 | ![确认框](docs/screenshots/07_confirm_reset.png) | 交互补充：重置农场 / 重置统计均需确认 |

截图由 `tests/capture.tscn` 用真实窗口渲染后自动抓取（演示数据：Lv.3、120 金币、4 块地在种、近 7 天记录）。

---

## 3. 目录结构

```
pomodoro-farm/
├─ project.godot              # 4 个 autoload + 主场景 + 窗口/渲染设置
├─ icon.svg                   # 番茄图标
├─ data/
│  └─ game_config.json        # 作物/道具/装饰数值 + 等级与奖励参数（改数值不用改代码）
├─ scenes/
│  └─ main.tscn               # 只有根 Control，界面全部代码构建
├─ scripts/
│  ├─ main.gd                 # 顶部导航、视图切换、toast、提醒弹窗、提示音合成与播放
│  ├─ packages/               # 四个逻辑包（对应 UML 包图）
│  │  ├─ base_storage.gd      # BaseStoragePackage
│  │  ├─ pomodoro.gd          # PomodoroPackage
│  │  ├─ farm.gd              # FarmPackage
│  │  └─ task_stats.gd        # TaskStatsPackage
│  └─ ui/
│     ├─ ui_kit.gd            # 色板、字体、圆角卡片、按钮样式、Theme（含自绘图标）
│     ├─ ring_timer.gd        # 环形倒计时控件（纯 _draw）
│     ├─ bar_chart.gd         # 柱状图控件（纯 _draw）
│     ├─ pomodoro_view.gd     # 番茄钟页
│     ├─ farm_view.gd         # 农场页（含商店/背包模态）
│     ├─ stats_view.gd        # 统计看板页
│     └─ settings_view.gd     # 设置页
├─ tests/
│  ├─ smoke.gd / smoke.tscn   # 53 项自动化冒烟测试（headless 可跑）
│  └─ capture.gd / capture.tscn  # 截图脚本（需要真实窗口）
├─ docs/screenshots/          # 上表 7 张效果图
└─ 运行游戏.bat               # Windows 一键启动
```

---

## 4. 架构：包划分与单向依赖

```
        ┌───────────────────────┐            ┌───────────────────────┐
        │   PomodoroPackage     │            │     FarmPackage       │
        │ 倒计时/暂停/放弃/状态  │            │ 地块/作物/商店/背包/   │
        │ 提醒/番茄完成事件      │            │ 收获/道具/等级         │
        └──────────┬────────────┘            └──────────┬────────────┘
                   │ 依赖                               │ 依赖
        ┌──────────▼───────────────────────────────────▼────────────┐
        │                    BaseStoragePackage                     │
        │           JSON 读写 / 配置 / 重置 / 系统时间               │
        └───────────────────────────────────────────────────────────┘
                   ▲
                   │ 依赖
        ┌──────────┴────────────┐
        │  TaskStatsPackage     │─── 依赖 ───▶ PomodoroPackage
        │ 任务增删改查/标签/     │              （消费番茄完成事件）
        │ 番茄聚合/报表          │
        └───────────────────────┘

  PomodoroPackage ──● pomodoro_completed 信号 ──▶ FarmPackage / TaskStatsPackage
                     （虚线：事件通知，不是类调用依赖）
```

**单向依赖规则（无循环）**

- 三个业务包（Pomodoro / Farm / TaskStats）都只依赖 **BaseStorage**，BaseStorage 不反向依赖任何业务包；
- **TaskStats 依赖 Pomodoro**（读取番茄完成事件做聚合）；
- **Pomodoro 与 Farm 之间没有直接调用**——番茄结束只发出 `pomodoro_completed` 信号，农场和统计各自订阅，用虚线表示事件通知；
- 视图层（`scripts/ui/*`、`main.gd`）只调用四个 autoload 的公开 API，四个包不知道 UI 的存在。

### 4.1 包 ←→ 文件 ←→ 对外接口

| 包 | 文件（autoload 名） | 主要接口 / 信号 |
| --- | --- | --- |
| BaseStoragePackage | `scripts/packages/base_storage.gd`（`Storage`） | `get_section/get_value` `set_value/set_section` `flush` `reset_section` `now_unix/day_key/time_of_day/week_start`；信号 `section_changed` `section_reset` |
| PomodoroPackage | `scripts/packages/pomodoro.gd`（`Pomodoro`） | `start/pause/resume/toggle_pause/abandon/skip_break/bind_task/progress`；信号 `tick` `state_changed` `phase_changed` `pomodoro_completed(task_id, focus_seconds, effective)` `focus_finished` `break_finished` `notice` |
| FarmPackage | `scripts/packages/farm.gd`（`Farm`） | `plot_state/plant/harvest/buy_seed/buy_item/buy_decor/use_item/grant_seed/level/coins/exp_points/exp_needed`；信号 `farm_changed` `level_up` `reward_gained` |
| TaskStatsPackage | `scripts/packages/task_stats.gd`（`TaskStats`） | `add_task/remove_task/task_title/task_tag/add_record/summary/daily_series/weekly_series/history`；信号 `tasks_changed` `records_changed` |

### 4.2 事件驱动的落地（对应文档「思考题 2」）

- **架构风格**是全局的、粗粒度的组织方式：本项目整体采用 **事件驱动风格**，业务包之间不互相调用内部函数，只通过信号事件传递消息。番茄计时结束时 `Pomodoro` 发出 `pomodoro_completed`，而不是去调用 `Farm.grant_reward()`；`Pomodoro` 因此不需要知道农场或统计模块是否存在。
- **架构模式**是风格之下可复用的具体解法：这里用 **观察者模式** 落地——`Pomodoro` 是被观察者（Subject），`Farm` 与 `TaskStats` 在 `_ready()` 里 `Pomodoro.pomodoro_completed.connect(...)` 成为观察者（Observer），收到通知后各自完成「发金币/经验/掉种子」和「写入番茄记录」。
- **MVC 视角**：`packages/` 是 Model（状态 + 业务规则），`scripts/ui/*` 是 View（只负责渲染与转发用户操作），`main.gd` 承担轻量 Controller（导航、toast、提醒弹窗）。View 不持有业务状态，Model 不引用任何界面节点，因此把界面换掉（例如改网页版）时四个包可以原样复用。
- 具体收益：新增一个「成就系统」只需新增一个观察者订阅同一事件，番茄包与农场包一行代码都不用改；把番茄时长从 25 分钟改成 45 分钟也只改配置，不触碰奖励逻辑。

---

## 5. 功能与玩法闭环

1. **番茄钟**：绑定任务 → 选择时长模板（25/45/50 分钟或自定义）→ 开始专注 → 结束弹出提醒（按设置播放提示音）。
   - 单次番茄最多暂停 1 次，累计暂停超过 300 秒本次番茄自动作废；
   - 放弃的番茄会记入统计，但标记为「无效」，不发奖励；
   - 切换顶部导航不打断后台计时，右上角常驻显示「专注 · 12:34」。
2. **奖励**：有效番茄 → +20 金币、+15 经验，30% 概率额外掉落 1 颗随机种子（数值见 `data/game_config.json`）。
3. **农场**：初始 6 块地可用，商店买种子 → 播种 → 等待生长（小麦 10 分钟 / 胡萝卜 20 分钟 / 草莓 30 分钟）→ 成熟后收获换金币与经验；每升 1 级自动解锁 2 块新地（最多 16 块）。
4. **道具**：加速卡把剩余生长时间减半，肥料直接缩短 120 秒；装饰（栅栏、稻草人）用于装扮并消耗金币。
5. **统计**：日视图看最近 7 天、周视图看最近 6 周的有效番茄柱状图，以及有效/无效番茄数、累计专注时长、最近 30 条历史记录。
6. **设置**：提醒音效开关与音量、默认专注/休息时长、重置农场数据、重置学习统计（均需二次确认）。

---

## 6. 数据存储

所有状态集中在 `user://save_data.json`，按包分三个分区（写入有 0.4 秒防抖，关窗时强制落盘）。
`user://` 的实际位置：**双击 `运行游戏.bat` 时**在 `pomodoro-farm\.runtime\appdata\Godot\app_userdata\番茄农场 Pomodoro Farm\`；**用编辑器运行时**在 `%APPDATA%\Godot\app_userdata\番茄农场 Pomodoro Farm\`。

```json
{
  "farm": {
    "level": 3, "coins": 120, "exp": 45, "unlocked": 10,
    "seeds": { "wheat": 3, "carrot": 1 },
    "items": { "speed_card": 1 },
    "decor": ["fence"],
    "plots": [ { "crop": "wheat", "planted_at": 1763000000, "grow": 600 } ]
  },
  "stats": {
    "tasks": [ { "id": "t_math", "title": "数学", "tag": "数学" } ],
    "records": [ { "ts": 1763000000, "day": "2026-11-17", "task_id": "t_math",
                   "title": "数学", "tag": "数学", "seconds": 1500, "effective": true } ]
  },
  "settings": { "sound_enabled": true, "volume": 0.6, "focus_minutes": 25, "break_minutes": 5 }
}
```

`BaseStorage` 提供 `reset_section("farm")` / `reset_section("stats")`，设置页的重置按钮直接调用它，因此「重置」不会误删另一块数据。

## 7. 数值配置（`data/game_config.json`）

| 键 | 含义 | 当前值 |
| --- | --- | --- |
| `crops.*.seed_price / grow / sell / exp` | 种子价 / 生长秒数 / 售价 / 经验 | 小麦 30 / 600 / 40 / 10；胡萝卜 45 / 1200 / 65 / 18（Lv.2 解锁）；草莓 60 / 1800 / 100 / 30（Lv.3 解锁） |
| `items.*.price` | 道具价格 | 加速卡 50、肥料 35 |
| `decorations.*.price` | 装饰价格 | 栅栏 80、稻草人 120 |
| `start_coins / start_plots` | 初始金币 / 初始地块 | 120 / 6 |
| `plots_per_level / max_plots` | 每级解锁 / 地块上限 | 2 / 16 |
| `level_base_exp / level_exp_step` | 升级所需经验公式 `base + (lv-1)*step` | 200 / 100 |
| `reward_coins / reward_exp / reward_seed_chance` | 有效番茄奖励 | 20 / 15 / 0.3 |
| `focus_minutes / break_minutes` | 默认时长（设置页可改） | 25 / 5 |

---

## 8. 测试与校验

**自动化冒烟测试（53 项断言，headless 可跑）**

```bat
Godot_v4.5-stable_win64_console.exe --headless --path <项目目录> res://tests/smoke.tscn
```

覆盖：存储读写与 `day_key`、`week_start` 周日边界、任务增删、番茄完成发奖与写入记录、放弃不发奖、暂停仅一次、播种/成熟/收获、加速卡减半、商店扣款与余额不足、升级解锁地块、日/周序列聚合、分区重置。
通过时输出 `SMOKE TEST PASSED: 53 checks` 并以退出码 0 结束。

**截图脚本（需要桌面环境，会打开一个窗口）**

```bat
Godot_v4.5-stable_win64_console.exe --path <项目目录> res://tests/capture.tscn
```

会注入一份演示数据（Lv.3、120 金币、4 块地在种、近 7 天记录），逐页渲染并写入 `docs/screenshots/`。

---

## 9. 与线框图的对照

| 文档要求 | 实现情况 |
| --- | --- |
| 顶部导航【番茄钟｜农场｜统计看板｜设置】，切换不中断计时 | ✅ 四个视图常驻实例化，仅切换 `visible` |
| 圆形倒计时（剩余 24:30） | ✅ `RingTimer` 自绘：进度弧 + 剩余时间 + 阶段文字 |
| 任务绑定下拉 + 使用默认模板 / 自定义时长 | ✅ 下拉绑定任务（可现场新建），时长 25/45/50 或自定义 1–120 分钟 |
| ▷开始 ⏸暂停 ✖放弃本次番茄 + 暂停 1 次提示 | ✅ 提示文案常驻在表盘下方 |
| 结束提醒弹窗，受音效设置控制 | ✅ 弹窗 + 正弦波合成提示音（无需音频文件） |
| Lv.3｜金币120｜经验条 + [商店][背包] | ✅ 数值由存档驱动，demo 数据与线框图一致 |
| 4×4 地块，锁定/空闲/生长中(08:20)/成熟 | ✅ 16 格，按状态着色并实时刷新倒计时 |
| 选中地块：小麦｜剩余生长 8分20秒 [使用道具] | ✅ 右侧信息面板显示名称、剩余时间、预计收益与动态按钮 |
| 商店模态，种子/道具/装饰标签，余额不足置灰 | ✅ `TabContainer` + 遮罩层，买不起的按钮 disabled |
| 统计：日/周切换、有效番茄、累计专注、柱状图、历史记录 | ✅ 见截图 05 |
| 设置：音效、音量、重置农场/统计（二次确认） | ✅ 见截图 06、07 |

---

## 10. 已知限制

- 只做了中文界面与鼠标操作，未适配触屏/小分辨率（窗口固定 1280×820，可缩放但布局按此比例设计）。
- 提示音为运行时合成的双音，风格朴素；如需更好听可把 wav 放进 `res://audio/` 并替换 `main.gd` 的 `_make_tone()`。
- 时间以系统时钟为准，未做防作弊（改系统时间可以加速作物）。
- 未接入云端存档，`save_data.json` 只在本机。
