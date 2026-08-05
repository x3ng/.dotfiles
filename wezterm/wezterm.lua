local wezterm = require("wezterm")

local config = wezterm.config_builder()

config.color_scheme = "CGA"
config.window_background_opacity = 0.6
config.wayland_window_background_blur = true
config.text_background_opacity = 1.0
config.window_decorations = "TITLE | RESIZE"
config.window_padding = {
	left = 0,
	right = 0,
	top = 0,
	bottom = 0,
}

config.font = wezterm.font_with_fallback({
	"JetBrainsMono Nerd Font Mono",
	"JetBrainsMono Nerd Font",
	"Noto Sans Mono CJK SC",
	"Noto Color Emoji",
})
config.font_size = 12.0
config.line_height = 1
config.freetype_load_target = "Normal"
config.adjust_window_size_when_changing_font_size = false

config.default_cursor_style = "SteadyBlock"
config.cursor_blink_rate = 0

config.scrollback_lines = 100000
config.enable_scroll_bar = true
config.mouse_wheel_scrolls_tabs = false
config.hide_mouse_cursor_when_typing = true
config.audible_bell = "Disabled"

config.window_close_confirmation = "NeverPrompt"
config.check_for_updates = false

config.enable_wayland = true

config.enable_tab_bar = true
config.use_fancy_tab_bar = false
config.hide_tab_bar_if_only_one_tab = false
config.tab_bar_at_bottom = true
config.show_new_tab_button_in_tab_bar = false
config.show_close_tab_button_in_tabs = false
config.tab_max_width = 24
config.colors = {
	foreground = "#d8d8d8",
	background = "#000000",
	cursor_bg = "#ffffff",
	cursor_border = "#ffffff",
	cursor_fg = "#000000",
	selection_bg = "#3a3a3a",
	selection_fg = "#ffffff",
	ansi = {
		"#000000",
		"#b03030",
		"#00aa00",
		"#aaaa00",
		"#0000aa",
		"#aa00aa",
		"#00aaaa",
		"#d8d8d8",
	},
	brights = {
		"#555555",
		"#ff4040",
		"#55ff55",
		"#ffff55",
		"#5555ff",
		"#ff55ff",
		"#55ffff",
		"#ffffff",
	},
	tab_bar = {
		background = "rgba(0, 0, 0, 0)",
		active_tab = {
			bg_color = "rgba(0, 0, 0, 0)",
			fg_color = "#ffffff",
			intensity = "Bold",
			underline = "Single",
		},
		inactive_tab = {
			bg_color = "rgba(0, 0, 0, 0)",
			fg_color = "#9ca3af",
		},
		inactive_tab_hover = {
			bg_color = "#2d2d30",
			fg_color = "#ffffff",
		},
		new_tab = {
			bg_color = "rgba(0, 0, 0, 0)",
			fg_color = "#9ca3af",
		},
		new_tab_hover = {
			bg_color = "#2d2d30",
			fg_color = "#ffffff",
		},
	},
}

return config
