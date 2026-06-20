extends Node

## 游戏字体管理器
## 优先加载 assets/fonts/ 下的商用免费字体，未找到则使用 Godot 默认字体
## 推荐字体：
##   中文：思源黑体 Source Han Sans / 思源宋体 Source Han Serif (SIL OFL)
##   英文标题：Orbitron (SIL OFL) / Teko (SIL OFL)

const FONT_DIR := "res://assets/fonts/"

var title_font: Font
var body_font: Font


func _ready() -> void:
	_load_fonts()
	_apply_theme_fonts()


func _load_fonts() -> void:
	# 标题字体：优先英文科幻字体，其次中文黑体
	title_font = _try_load([
		FONT_DIR + "Orbitron-Bold.ttf",
		FONT_DIR + "Teko-Bold.ttf",
		FONT_DIR + "SourceHanSansSC-Bold.otf",
		FONT_DIR + "cn_title.ttf"
	])

	# 正文字体：优先清晰可读的无衬线字体
	body_font = _try_load([
		FONT_DIR + "SourceHanSansSC-Regular.otf",
		FONT_DIR + "NotoSansSC-Regular.otf",
		FONT_DIR + "cn_body.ttf",
		FONT_DIR + "Orbitron-Regular.ttf"
	])

	if title_font == null:
		title_font = ThemeDB.fallback_font
	if body_font == null:
		body_font = ThemeDB.fallback_font

	print("FontManager: title=", _font_name(title_font), ", body=", _font_name(body_font))


func _try_load(paths: Array[String]) -> Font:
	for path in paths:
		if ResourceLoader.exists(path):
			var f = load(path)
			if f is Font:
				return f
	return null


func _font_name(font: Font) -> String:
	if font == null:
		return "null"
	if font == ThemeDB.fallback_font:
		return "fallback"
	return font.resource_path.get_file()


func _apply_theme_fonts() -> void:
	var theme := ThemeDB.get_project_theme()
	if theme == null:
		theme = Theme.new()
		get_tree().root.theme = theme

	# 只覆盖常用字体类型，其余 fallback
	theme.set_font("title", "", title_font)
	theme.set_font("body", "", body_font)
	theme.set_font("font", "", body_font)
