# 项目结构说明

本文只讲「东西在哪、该改哪」。规则与部署细节见 README 和各目录原有说明。

## 目录职责

| 路径 | 内容 |
| --- | --- |
| `GuildMaster-Godot-src/` | Godot 客户端源码（GDScript + 场景 + 样式资源） |
| `GuildMaster-Godot/` | 打包后的客户端资源（art/rules/runtime/LICENSES），缺 exe 与 Python 运行时 |
| `guild-server/` | 服务器：权威规则引擎、大厅、回放站、官网，纯标准库 |
| `tools/` | 构建、发布、素材与语音脚本 |
| `tests/` | 服务器与素材回归测试（`python -m unittest discover -s tests`） |
| `docs/` | 版本说明、校验清单、美术与语音清单 |

`GuildMaster-Godot-src/.godot/`、`tools/regression/out/`、`.idea/`、
`GuildMaster-Godot-src/addons/` 都是本机生成物或编辑器工具，已被 `.gitignore` 忽略，
不随游戏发佈。`addons/gdscript_refactoring` 只是编辑器里重命名符号的插件：
新机器上没有它时，Godot 编辑器会提示一次插件加载失败，在「项目设置 → 插件」里取消勾选即可，
不影响游戏运行，也不影响构建。

## 客户端结构

```
GuildMaster-Godot-src/
├── main.tscn / scripts/main.gd      主控制器：会话、偏好、音频、输入、界面分发
├── ui/                              界面场景 + 样式资源
│   ├── home_screen.tscn             主页
│   ├── lobby_screen.tscn            大厅（房间列表）
│   ├── room_screen.tscn             房间准备页
│   ├── table_screen.tscn            对局外壳：顶栏、左侧座位、布局槽、阶段槽
│   ├── table_layout_classic.tscn    经典桌面：地图 / 王权命令 / 手牌
│   ├── table_layout_dashboard.tscn  总览桌面：侧栏 / 公共区 / 地图 / 资源条
│   ├── table_face.tscn              情报收集后选择黑白面
│   ├── table_selection.tscn         开局轮抽与情报收集
│   ├── table_results.tscn           终局结算
│   ├── potion_button.tscn           单个秘药行动按钮
│   ├── dialog_frame.tscn            参考版式弹窗共用的外框
│   └── styles/*.tres                按钮与面板样式（编辑器预览用）
├── scripts/
│   ├── ui_kit.gd                    控件工厂：label/button/panel/card/scroll…
│   ├── preview.gd                   对局卡牌悬停预览与 Alt 大图
│   ├── music.gd / music_panel.gd     本地曲目、音乐音轨与常驻音乐栏
│   ├── toaster.gd                   提示条与终局公告
│   ├── preferences.gd               preferences.cfg 的键名、默认值与迁移
│   ├── theme_builder.gd             主题（字体、按钮、滚动条样式）
│   ├── paper_skin.gd                纸张皮肤与立体按钮
│   ├── screen_base.gd               场景式界面的基类（语言切换、按钮接线）
│   ├── home_screen.gd               主页填文字/立绘/回调
│   ├── lobby_screen.gd              大厅房间列表
│   ├── room_screen.gd               按房间状态显隐座位与按钮
│   ├── screens.gd                   实例化 home/room/table 场景
│   ├── table_screen.gd              对局外壳：顶栏、座位列、阶段分发
│   ├── table_classic.gd             经典布局填数值与动态列表
│   ├── table_dashboard.gd           总览布局填数值与动态列表
│   ├── table_face.gd                选面阶段
│   ├── table_selection.gd           轮抽 / 情报收集阶段
│   ├── table_results.gd             终局结算
│   ├── table_widgets.gd             桌面排版工具与通用小部件
│   ├── dialogs.gd                   弹窗底座：简单弹窗与共用控件
│   ├── dialogs_overlay.gd           参考版式弹窗内容
│   ├── dialog_frame.gd              弹窗外框：尺寸/标题/关闭
│   ├── session.gd                   TCP/WebSocket 连接与快照
│   ├── art_store.gd                 卡图、立绘、板块缓存
│   ├── rules_logic.gd               客户端侧的规则小助手（费用/上限）
│   └── hex_map.gd / card_art.gd     自绘节点（编辑器不可拖内部图形）
└── tools/                           客户端自检与截图回归
```

### 运行时数据流

1. `main.tscn` 启动，`main.gd` 读取偏好、建主题、加载目录数据。
2. `session.gd` 连服务器（`4 字节大端长度 + JSON`），收到 `snapshot` 后触发重绘。
3. `GuildScreens.table()` 挂入 `table_screen.tscn`；它按状态选择内容：
   - 行动 / 最终行动 → `table_layout_classic.tscn` 或 `table_layout_dashboard.tscn`
   - 选黑白面 → `table_face.tscn`
   - 轮抽 / 情报收集 → `table_selection.tscn`
   - 终局 → `table_results.tscn`
   顶栏与左侧座位始终由 `table_screen.tscn` 提供（总览布局在行动阶段隐藏它们）。
   有房间 → `room_screen.tscn`；没有房间没有对局 → `home_screen.tscn`；大厅列表 → `lobby_screen.tscn`。
   对局期间保留桌面外壳和当前行动布局。手牌、公共王权、日志和选中板块按各自的数据变化更新。
4. 弹窗走 `dialogs_overlay.overlay()` → `dialog_frame.tscn`；大厅类简单弹窗走
   `main.open_dialog()`。

### 开局顺序

1. 房间准备页：展示本席全部候选人物的完整肖像。点选肖像后，可查看 1–3 级卡面、切换黑白面预览，再确认锁定人物。黑白面留到情报收集后选择。
2. 房主开始：服务端按人物创建引擎；`setup_draft` 开启且 2 人以上时先进入
   `phase = "draft"` 做开局轮抽。
3. 轮抽结束进入 `phase = "research"`（情报收集）。此时黑白面未定，只按两版中
   较低的开局资源起步；角色专属抽牌、标签、私有牌堆与开场效果暂不发放。
4. 全员完成情报收集后进入 `phase = "face"`：选择该人物的白面或黑面。选面后补足
   所选面的资源差额，并发放该面的初始抽牌、标签、私有牌堆与角色专属开场效果。
5. 全员选完面后进入 `phase = "action"`，按先手顺序开始公会行动。

对应实现可见 `guild-server/guild_face_select.py`、`guild_full_rules.py` 的
`_begin_action_phase()` 以及客户端 `table_face.gd`。

### 秘药行动

- `guild-server/guild_potions.py` 是唯一校验入口：
  - `slot_error()`：格子是否已被使用、是否因人数关闭；
  - `target_error()`：建设药水是否有可据点化的营地、灵药/炼金召唤是否有可免费打出的事件卡；
  - `use_error()`：执行前的完整校验；
  - `potion_state()`：客户端显示的状态文案。
- `FullRules._potion()`、`guild_resolution` 的秘药选项、`action_hints()` 都调用同一组函数。
- `FullRules.view()` 只给本人下发 `potion_states`，客户端
  `GuildRulesLogic.potion_state()` 优先显示服务端状态；旧服务端没有该字段时才走本地回退。

### 界面改造约定

- 场景里能摆的节点尽量摆进 `.tscn`；`*_screen.gd` / `table_*.gd` 只填文字、显隐和回调。
- 对局桌面同样拆成场景：顶栏与座位在 `table_screen.tscn`，两种布局与各阶段各有自己的场景。
  卡牌、日志行、玩家行、王权卡等**数量随数据变化**的列表才在代码里生成。
- 场景按钮统一用 `GuildScreen.wire_button()` 或 `GuildTableWidgets.scene_button()`，
  保证字号、纸张样式、点击音效和代码生成的按钮一致。
- 场景里的字体与按钮样式只用于编辑器预览；绑定前调用
  `GuildTableWidgets.reset_scene_fonts()`，运行时才会跟随主题字体（含繁体字型）。
- 场景中文原文在 `GuildScreen._ready()` 里自动记录，切繁简时 `apply_language()` 重套；
  不要在 `_ready()` 里手动再抄一份文本表。

## 规则唯一来源

规则只在 `guild-server/*.py` 维护；`tools/prepare_update.py` 会把它复制到
`GuildMaster-Godot/rules/` 和 `GuildMaster-Godot-src/rules/`，离线模式再由 `rules/local_bridge.py` 加载。
只同步规则可运行 `python tools/prepare_update.py --rules-only`，发行构建也使用同一个同步入口。
离线专用的 `local_bridge.py`、`guild_session.py` 和 `guild_lossless_art.py` 从发行目录同步到编辑器目录。

每个 `Engine` 创建或读档时生成该局的卡牌目录，单人及多人印刷版的效果与计分在同一进程中独立。
王权和发展预览由 Python 复用实际支付校验，并随当前行动者的私人快照下发。

## 常见改动位置

| 想改什么 | 改哪里 |
| --- | --- |
| 主页/房间/桌面的位置、尺寸 | 对应 `.tscn`，编辑器里直接拖 |
| 对局顶栏、左侧座位 | `ui/table_screen.tscn` |
| 经典桌面的地图/命令/手牌 | `ui/table_layout_classic.tscn` + `table_classic.gd` |
| 总览桌面的侧栏/公共区/资源条 | `ui/table_layout_dashboard.tscn` + `table_dashboard.gd` |
| 选黑白面、轮抽、情报收集、结算 | `ui/table_face.tscn` / `table_selection.tscn` / `table_results.tscn` |
| 场景按钮的行为 | 对应的 `*_screen.gd` / `table_*.gd` |
| 按钮样式（颜色、底图） | `ui/styles/*.tres`（编辑器）+ `paper_skin.gd`（运行时） |
| 弹窗外框标题/关闭按钮位置 | `ui/dialog_frame.tscn` |
| 某个弹窗的内容 | `dialogs_overlay.gd`（参考版式）或 `dialogs.gd`（简单弹窗） |
| 控件外观 | `ui_kit.gd` |
| 规则、卡牌、角色数据 | `guild-server/guild_content.py` 等，然后运行 `python tools/prepare_update.py` |
| 替换某块迷宫板块整图 | 所有板块统一放 `GuildMaster-Godot-src/art/images/piece_png/<编号>.png`（普通 1–22、变动 068–082、魔王 240/258 等）；不再读 `data/card_layouts.json`，自动去透明边、居中并识别尖顶/平顶 |
| 联机协议 | `session.gd` 与 `guild_network.py`（版本号必须一致） |

### 板块图

- 所有迷宫板块统一放在 `art/images/piece_png/`，文件名使用原板块编号：
  - 普通：`1.png` … `22.png`
  - 变动：`068.png` … `082.png`
  - 变动背面：`083.png`
  - 魔王背面：`087.png`、`088.png`
  - 魔王正面：`240.png`、`258.png`
  - 阻挡：`063.png`
- `art/images/piece_png/<编号>.png` 就是唯一来源；客户端不再加载 `card_layouts.json`。
- `tile_angle()` 按尖顶/平顶自动决定绘制角度；`tile_texture()` 自动去透明边、居中并套六角遮罩。
- 换图后需重启客户端；已打包的 exe 需要重新构建。

## 验证

```sh
python -m unittest discover -s tests -v                  # 服务器与素材回归
python GuildMaster-Godot-src/tools/regression/compare.py before after   # 截图逐像素对比
```

客户端自检（需要 Godot 4.7.2 可执行文件）：

```sh
# 逐个打开全部弹窗，确认没有缺失方法或场景（headless 可跑）
godot --headless --path GuildMaster-Godot-src -s res://tools/dialog_qa.gd

# 逐个渲染桌面阶段（行动/选面/轮抽/情报/结算）；不带 --qa-output 时 headless 也能跑
godot --headless --path GuildMaster-Godot-src -s res://tools/table_qa.gd
godot --path GuildMaster-Godot-src -s res://tools/table_qa.gd -- --qa-output=<绝对路径>\qa

# 真实离线开局：开始冒险 → 选人 → 情报收集 → 选面 → 公会行动
godot --headless --path GuildMaster-Godot-src -s res://tools/offline_qa.gd

# 主页/两种桌面布局/设置，并把截图写到 qa/ 目录
godot --path GuildMaster-Godot-src -s res://tools/update_qa.gd -- --qa-output=<绝对路径>\qa

# 改动前后各截一套图再对比（输出在 tools/regression/out/）
powershell -File GuildMaster-Godot-src/tools/regression/run.ps1 -Tag before
powershell -File GuildMaster-Godot-src/tools/regression/run.ps1 -Tag after
```

客户端在 Godot 里按 F5 运行；改场景后先 `项目 → 重新加载当前项目`。
