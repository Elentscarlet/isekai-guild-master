class_name GuildPreferences
extends RefCounted

# 偏好设定的键名、默认值与 user://preferences.cfg 的读写。
# 运行期仍然用 Dictionary 保存（package_check 会整份备份/还原），
# 这里只把散落在 main.gd 里的键名与一次性迁移集中起来。

const PATH := "user://preferences.cfg"

const DEFAULTS := {
	"name": "公会长",
	"address": "guanpeng666.cn",
	"port": 6677,
	"sounds": true,
	"sound_volume": 0.65,
	"music_volume": 0.3375,
	"voices": false,
	"voice_volume": 0.85,
	"voice_language": "ja",
	"voice_settings_version": 1,
	"motion": true,
	"hints": true,
	"frame_limit": 240,
	"vsync": false,
	"language": "zh_CN",
}

static func defaults() -> Dictionary:
	return DEFAULTS.duplicate(true)

static func load_into(prefs: Dictionary) -> void:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	for key in DEFAULTS:
		prefs[key] = config.get_value("preferences", key, DEFAULTS[key])
	# 旧版默认开启配音；一次性迁移为关闭，之后用户手动开启会照常保存。
	if int(config.get_value("preferences", "voice_settings_version", 0)) < 1:
		prefs.voices = false
		prefs.voice_settings_version = 1
		save(prefs)

static func save(prefs: Dictionary) -> void:
	var config := ConfigFile.new()
	for key in prefs:
		config.set_value("preferences", key, prefs[key])
	config.save(PATH)
