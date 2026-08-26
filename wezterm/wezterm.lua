local wezterm = require("wezterm")

local config = wezterm.config_builder()

config.color_scheme = "CGA"
config.window_background_opacity = 0.7
config.wayland_window_background_blur = true
config.text_background_opacity = 1.0
config.window_decorations = "TITLE | RESIZE"
config.window_padding = {
	left = 7,
	right = 7,
	top = 7,
	bottom = 7,
}

config.font = wezterm.font_with_fallback({
	"IosevkaTerm Nerd Font Mono",
	"Sarasa Mono SC",
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
config.detect_password_input = false

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
		"#e85d5d",
		"#4fd66d",
		"#d6ad4f",
		"#5fa8ff",
		"#e46bd0",
		"#42c7bd",
		"#d8d8d8",
	},
	brights = {
		"#555555",
		"#ff9a9a",
		"#9affb7",
		"#ffe69a",
		"#a8d4ff",
		"#ffadeb",
		"#9ff7ea",
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
