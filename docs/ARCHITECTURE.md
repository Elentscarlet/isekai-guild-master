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
│   ├── table_screen.tscn            对局桌面（顶栏/地图/命令/手牌）
│   ├── dialog_frame.tscn            参考版式弹窗共用的外框
│   └── styles/*.tres                按钮与面板样式（编辑器预览用）
├── scripts/
│   ├── ui_kit.gd                    控件工厂：label/button/panel/card/scroll…
│   ├── preview.gd                   按住 Alt 的放大预览
│   ├── toaster.gd                   提示条与终局公告
│   ├── preferences.gd               preferences.cfg 的键名、默认值与迁移
│   ├── theme_builder.gd             主题（字体、按钮、滚动条样式）
│   ├── paper_skin.gd                纸张皮肤与立体按钮
│   ├── screen_base.gd               场景式界面的基类（语言切换、按钮接线）
│   ├── home_screen.gd               主页填文字/立绘/回调
│   ├── lobby_screen.gd              大厅房间列表
│   ├── room_screen.gd               按房间状态显隐座位与按钮
│   ├── screens.gd                   实例化 home/room 场景
│   ├── table_widgets.gd             桌面排版工具与通用小部件
│   ├── table_classic.gd             经典桌面布局
│   ├── table_dashboard.gd           总览桌面布局
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
3. `main.gd::_render()` 按状态选择界面：
   - 有对局 → `table_classic.gd` 或 `table_dashboard.gd`（填进 `table_screen.tscn`）
   - 有房间 → `room_screen.tscn`
   - 无房间无对局 → `home_screen.tscn`
   - 大厅列表 → `lobby_screen.tscn`
4. 弹窗走 `dialogs_overlay.overlay()` → `dialog_frame.tscn`；大厅类简单弹窗走
   `main.open_dialog()`。

### 界面改造约定

- 场景里能摆的节点尽量摆进 `.tscn`；`*_screen.gd` 只填文字、显隐和回调。
- 场景按钮统一用 `GuildScreen.wire_button()`（或 `ui.wire_button()` + `GuildTableWidgets.decorate()`），
  保证字号、纸张样式、点击音效和代码生成的按钮一致。
- 场景中文原文在 `GuildScreen._ready()` 里自动记录，切繁简时 `apply_language()` 重套；
  不要在 `_ready()` 里手动再抄一份文本表。

## 规则唯一来源

规则只在 `guild-server/*.py` 维护；`tools/prepare_update.py` 会把它复制到
`GuildMaster-Godot/rules/`，离线模式再由 `rules/local_bridge.py` 加载。**不要直接改 rules 里的副本**。

## 常见改动位置

| 想改什么 | 改哪里 |
| --- | --- |
| 主页/房间/桌面的位置、尺寸 | 对应 `.tscn`，编辑器里直接拖 |
| 场景按钮的行为 | 对应的 `*_screen.gd` |
| 按钮样式（颜色、底图） | `ui/styles/*.tres`（编辑器）+ `paper_skin.gd`（运行时） |
| 弹窗外框标题/关闭按钮位置 | `ui/dialog_frame.tscn` |
| 对局里某块内容 | `table_classic.gd` / `table_dashboard.gd` |
| 某个弹窗的内容 | `dialogs_overlay.gd`（参考版式）或 `dialogs.gd`（简单弹窗） |
| 控件外观 | `ui_kit.gd` |
| 规则、卡牌、角色数据 | `guild-server/guild_content.py` 等，然后重跑 `tools/prepare_update.py` |
| 联机协议 | `session.gd` 与 `guild_network.py`（版本号必须一致） |

## 验证

```sh
python -m unittest discover -s tests -v                  # 服务器与素材，48 项
python GuildMaster-Godot-src/tools/regression/compare.py before after   # 截图逐像素对比
```

客户端自检（需要 Godot 4.7.2 可执行文件）：

```sh
# 逐个打开全部弹窗，确认没有缺失方法或场景（headless 可跑）
godot --headless --path GuildMaster-Godot-src -s res://tools/dialog_qa.gd

# 主页/两种桌面布局/设置，并把截图写到 qa/ 目录
godot --path GuildMaster-Godot-src -s res://tools/update_qa.gd -- --qa-output=<绝对路径>\qa

# 改动前后各截一套图再对比（输出在 tools/regression/out/）
powershell -File GuildMaster-Godot-src/tools/regression/run.ps1 -Tag before
powershell -File GuildMaster-Godot-src/tools/regression/run.ps1 -Tag after
```

客户端在 Godot 里按 F5 运行；改场景后先 `项目 → 重新加载当前项目`。
