# Personal nullshell settings

Install the independent `nullshell` package first. This directory contains only
user preferences: terminal/idle settings and wallpaper defaults. The package owns
QML, Rust, service units and the greeter. Runtime choices are stored separately in
`$XDG_STATE_HOME/nullshell/` and are not committed here.

Deploy with `./deploy/deploy nullshell` or the Home Manager `nullshell` profile.
The first nullshell desktop/locker startup imports old Quickshell state once,
without overwriting existing nullshell state or deleting the source.
