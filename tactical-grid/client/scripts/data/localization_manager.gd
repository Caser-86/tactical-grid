extends Node

## 本地化/多语言管理器

const DEFAULT_LANGUAGE := "zh"
const SUPPORTED_LANGUAGES := ["zh", "en"]

var _data: Dictionary = {}
var current_language: String = DEFAULT_LANGUAGE

func _ready() -> void:
	_load_file("zh", "res://data/localization_zh.json")
	_load_file("en", "res://data/localization_en.json")
	var saved = _load_saved_language()
	if saved != "" and saved in SUPPORTED_LANGUAGES:
		current_language = saved

func _load_file(lang: String, path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var text = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		_data[lang] = parsed

func _load_saved_language() -> String:
	var cfg = FileAccess.open("user://locale.cfg", FileAccess.READ)
	if not cfg:
		return ""
	var lang = cfg.get_as_text().strip_edges()
	cfg.close()
	return lang

func _save_language() -> void:
	var cfg = FileAccess.open("user://locale.cfg", FileAccess.WRITE)
	if cfg:
		cfg.store_string(current_language)
		cfg.close()

func set_language(lang: String) -> void:
	if lang in SUPPORTED_LANGUAGES:
		current_language = lang
		_save_language()

func get_text(key: String, fallback: String = "") -> String:
	var table = _data.get(current_language, {})
	var text = table.get(key, "")
	if text == "" and current_language != DEFAULT_LANGUAGE:
		text = _data.get(DEFAULT_LANGUAGE, {}).get(key, "")
	if text == "" and fallback != "":
		return fallback
	if text == "":
		return key
	return text

func get_language_name(lang: String) -> String:
	match lang:
		"zh": return "简体中文"
		"en": return "English"
		_: return lang
