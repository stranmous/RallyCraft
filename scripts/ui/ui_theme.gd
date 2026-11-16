extends RefCounted
class_name UITheme

# Centralized Palette 4 (British Racing Green & Champagne Gold) design tokens and helpers.
# Strictly avoids navy, cyan, and blue tones across all screens, HUD elements, and modals.

const BG_BACKDROP := Color("08130e")
const TOPBAR_BG := Color(0.047, 0.114, 0.086, 0.90)
const GLASS_DARK := Color(0.059, 0.141, 0.110, 0.86)
const GLASS_MODAL := Color(0.051, 0.125, 0.098, 0.95)
const DIMMER_BG := Color(0.020, 0.047, 0.035, 0.78)
const TILE_BG := Color(0.078, 0.180, 0.141, 0.92)
const TILE_BG_HOVER := Color(0.110, 0.243, 0.192, 0.96)
const TILE_BG_PRESSED := Color(0.055, 0.129, 0.102, 0.96)
const TILE_BG_ACTIVE := Color(0.102, 0.231, 0.180, 0.96)

const CANVAS_BG := Color("091711")
const CANVAS_GRID_MINOR := Color(0.14, 0.30, 0.23, 0.35)
const CANVAS_GRID_MAJOR := Color(0.20, 0.42, 0.32, 0.55)

const GOLD := Color("f3c14b")
const GOLD_HOVER := Color("fad06c")
const GOLD_PRESSED := Color("d4a12e")
const GOLD_MUTED := Color(0.953, 0.757, 0.294, 0.24)
const DARK_INK := Color("091711")

const COPPER := Color("d97736")
const COPPER_GLOW := Color(0.851, 0.467, 0.212, 0.92)
const EMERALD := Color("4ade80")
const EMERALD_BG := Color(0.086, 0.247, 0.165, 0.92)
const CRIMSON := Color("f87171")
const CRIMSON_BG := Color(0.290, 0.106, 0.106, 0.92)

const TEXT_PRIMARY := Color("faf6f0")
const TEXT_SECONDARY := Color("a7c4b8")
const TEXT_MUTED := Color("6e8f82")
const OUTLINE_DARK := Color(0.020, 0.047, 0.035, 0.94)

const BORDER_SUBTLE := Color(0.655, 0.769, 0.722, 0.20)
const BORDER_GOLD := Color(0.953, 0.757, 0.294, 0.42)
const BORDER_GOLD_BRIGHT := Color(0.953, 0.757, 0.294, 0.95)
const SHADOW_SOFT := Color(0.0, 0.0, 0.0, 0.42)

static var _display_font: Font
static var _mono_font: Font


static func get_display_font() -> Font:
	if _display_font == null:
		var base := ThemeDB.fallback_font
		if base != null:
			var variation := FontVariation.new()
			variation.base_font = base
			variation.variation_embolden = 0.28
			variation.spacing_glyph = 1
			_display_font = variation
		else:
			_display_font = ThemeDB.fallback_font
	return _display_font


static func get_mono_font() -> Font:
	if _mono_font == null:
		var base := ThemeDB.fallback_font
		if base != null:
			var variation := FontVariation.new()
			variation.base_font = base
			variation.variation_embolden = 0.20
			variation.opentype_features = {"tnum": 1}
			_mono_font = variation
		else:
			_mono_font = ThemeDB.fallback_font
	return _mono_font


static func make_panel_style(
	bg_color: Color = GLASS_DARK,
	radius: int = 16,
	border_color: Color = BORDER_SUBTLE,
	border_width: int = 2,
	shadow_size: int = 10,
	pad_h: float = 0.0,
	pad_v: float = 0.0
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.border_color = border_color
	if shadow_size > 0:
		style.shadow_color = SHADOW_SOFT
		style.shadow_size = shadow_size
		style.shadow_offset = Vector2(0.0, 3.0)
	if pad_h > 0.0 or pad_v > 0.0:
		style.content_margin_left = pad_h
		style.content_margin_right = pad_h
		style.content_margin_top = pad_v
		style.content_margin_bottom = pad_v
	return style


static func apply_button_theme(
	button: Button,
	normal_bg: Color,
	hover_bg: Color,
	pressed_bg: Color,
	font_color: Color,
	border_color: Color,
	radius: int = 12,
	border_width: int = 2,
	icon_color: Color = Color.TRANSPARENT,
	shadow_size: int = 6
) -> void:
	var focus_sb := make_panel_style(normal_bg, radius, BORDER_GOLD_BRIGHT, maxi(border_width, 2), 0)
	var disabled_sb := make_panel_style(Color(normal_bg.r, normal_bg.g, normal_bg.b, 0.42), radius, BORDER_SUBTLE, border_width, 0)
	button.add_theme_stylebox_override("normal", make_panel_style(normal_bg, radius, border_color, border_width, shadow_size))
	button.add_theme_stylebox_override("hover", make_panel_style(hover_bg, radius, border_color.lightened(0.15), border_width, shadow_size))
	button.add_theme_stylebox_override("pressed", make_panel_style(pressed_bg, radius, border_color, border_width, 2))
	button.add_theme_stylebox_override("disabled", disabled_sb)
	button.add_theme_stylebox_override("focus", focus_sb)

	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color)
	button.add_theme_color_override("font_pressed_color", font_color)
	button.add_theme_color_override("font_focus_color", font_color)
	button.add_theme_color_override("font_disabled_color", Color(TEXT_MUTED.r, TEXT_MUTED.g, TEXT_MUTED.b, 0.72))

	var resolved_icon_color := font_color if icon_color == Color.TRANSPARENT else icon_color
	button.add_theme_color_override("icon_normal_color", resolved_icon_color)
	button.add_theme_color_override("icon_hover_color", resolved_icon_color)
	button.add_theme_color_override("icon_pressed_color", resolved_icon_color)
	button.add_theme_color_override("icon_focus_color", resolved_icon_color)
	button.add_theme_color_override("icon_disabled_color", Color(TEXT_MUTED.r, TEXT_MUTED.g, TEXT_MUTED.b, 0.5))

	var font := get_display_font()
	if font != null:
		button.add_theme_font_override("font", font)


static func style_primary_button(button: Button, font_size: int = 21, radius: int = 14) -> void:
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_constant_override("h_separation", 10)
	apply_button_theme(
		button,
		GOLD,
		GOLD_HOVER,
		GOLD_PRESSED,
		DARK_INK,
		Color(1.0, 0.93, 0.72, 0.80),
		radius,
		2,
		DARK_INK,
		10
	)


static func style_secondary_button(button: Button, font_size: int = 18, radius: int = 14) -> void:
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_constant_override("h_separation", 10)
	apply_button_theme(
		button,
		TILE_BG,
		TILE_BG_HOVER,
		TILE_BG_PRESSED,
		TEXT_PRIMARY,
		BORDER_SUBTLE,
		radius,
		2,
		GOLD,
		4
	)


static func style_rim_pill(button: Button, active: bool, font_size: int = 17, radius: int = 12) -> void:
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_constant_override("h_separation", 8)
	if active:
		apply_button_theme(
			button,
			TILE_BG_ACTIVE,
			TILE_BG_HOVER,
			TILE_BG_PRESSED,
			GOLD,
			BORDER_GOLD_BRIGHT,
			radius,
			2,
			GOLD,
			8
		)
	else:
		apply_button_theme(
			button,
			TILE_BG,
			TILE_BG_HOVER,
			TILE_BG_PRESSED,
			TEXT_PRIMARY,
			BORDER_SUBTLE,
			radius,
			1,
			TEXT_SECONDARY,
			0
		)


static func style_gold_pill(button: Button, active: bool, font_size: int = 16, radius: int = 12) -> void:
	if active:
		style_primary_button(button, font_size, radius)
	else:
		style_secondary_button(button, font_size, radius)


static func style_danger_button(button: Button, font_size: int = 17, radius: int = 12) -> void:
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_constant_override("h_separation", 8)
	apply_button_theme(
		button,
		CRIMSON_BG,
		CRIMSON_BG.lightened(0.14),
		CRIMSON_BG.darkened(0.16),
		Color("fecaca"),
		Color(0.973, 0.443, 0.443, 0.65),
		radius,
		2,
		CRIMSON,
		4
	)


static func style_audio_pill(button: Button, muted: bool, font_size: int = 16, radius: int = 18) -> void:
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_constant_override("h_separation", 6)
	if muted:
		apply_button_theme(
			button,
			CRIMSON_BG,
			CRIMSON_BG.lightened(0.14),
			CRIMSON_BG.darkened(0.16),
			Color("fecaca"),
			Color(0.973, 0.443, 0.443, 0.72),
			radius,
			2,
			CRIMSON,
			4
		)
	else:
		apply_button_theme(
			button,
			TILE_BG,
			TILE_BG_HOVER,
			TILE_BG_PRESSED,
			GOLD,
			BORDER_GOLD,
			radius,
			2,
			EMERALD,
			4
		)


static func style_line_edit(edit: LineEdit, font_size: int = 18) -> void:
	edit.add_theme_font_size_override("font_size", font_size)
	edit.add_theme_color_override("font_color", TEXT_PRIMARY)
	edit.add_theme_color_override("font_placeholder_color", TEXT_MUTED)
	edit.add_theme_color_override("caret_color", GOLD)
	edit.add_theme_stylebox_override("normal", make_panel_style(TILE_BG, 10, BORDER_SUBTLE, 2, 0, 12.0, 6.0))
	edit.add_theme_stylebox_override("focus", make_panel_style(TILE_BG_ACTIVE, 10, BORDER_GOLD_BRIGHT, 2, 0, 12.0, 6.0))


static func style_text_edit(edit: TextEdit, font_size: int = 16) -> void:
	edit.add_theme_font_size_override("font_size", font_size)
	edit.add_theme_color_override("font_color", TEXT_PRIMARY)
	edit.add_theme_color_override("font_placeholder_color", TEXT_MUTED)
	edit.add_theme_color_override("caret_color", GOLD)
	edit.add_theme_stylebox_override("normal", make_panel_style(CANVAS_BG, 10, BORDER_SUBTLE, 2, 0, 10.0, 8.0))
	edit.add_theme_stylebox_override("focus", make_panel_style(CANVAS_BG, 10, BORDER_GOLD_BRIGHT, 2, 0, 10.0, 8.0))


static func style_label(
	label: Label,
	font_size: int,
	color: Color = TEXT_PRIMARY,
	display_font: bool = false,
	mono_font: bool = false
) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if mono_font and get_mono_font() != null:
		label.add_theme_font_override("font", get_mono_font())
	elif display_font and get_display_font() != null:
		label.add_theme_font_override("font", get_display_font())


static func style_hud_outlined_label(
	label: Label,
	font_size: int,
	color: Color,
	outline_px: int = 6,
	use_mono: bool = false
) -> void:
	style_label(label, font_size, color, not use_mono, use_mono)
	label.add_theme_color_override("font_outline_color", OUTLINE_DARK)
	label.add_theme_constant_override("outline_size", outline_px)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.65))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)


static func make_stat_tile(parent: Control, pos: Vector2, tile_size: Vector2, kicker_text: String, initial_value: String = "-") -> Label:
	var card := Panel.new()
	card.position = pos
	card.size = tile_size
	card.add_theme_stylebox_override("panel", make_panel_style(TILE_BG, 12, BORDER_SUBTLE, 1, 0))
	parent.add_child(card)

	var kicker := Label.new()
	kicker.text = kicker_text
	kicker.position = Vector2(8.0, 6.0)
	kicker.size = Vector2(tile_size.x - 16.0, 20.0)
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	style_label(kicker, 14, TEXT_MUTED, true, false)
	card.add_child(kicker)

	var value := Label.new()
	value.text = initial_value
	value.position = Vector2(6.0, 26.0)
	value.size = Vector2(tile_size.x - 12.0, tile_size.y - 30.0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.clip_text = true
	style_label(value, 18, TEXT_PRIMARY, false, true)
	card.add_child(value)
	return value
