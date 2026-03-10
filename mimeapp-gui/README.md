# MimeApp GUI

A Noctalia plugin to manage MIME default applications from a panel UI.

## Requirements

- `python3` must be installed and available in `PATH`.

## What it does

- Scans installed `.desktop` files for their `MimeType=` entries.
- Lists MIME types and candidate handlers.
- Provides a grouped `Common` tab for frequently used defaults such as web browser, image viewer, music player, video player, and archive manager.
- Allows customizing which MIME types appear in each `Common` tab group from the settings page.
- Updates `~/.config/mimeapps.list` in the `[Default Applications]` section.

## Notes

- This plugin writes user overrides to `~/.config/mimeapps.list`.
- Effective defaults may still be influenced by desktop-specific `*-mimeapps.list` files and system-level files.
- In the `Common` tab, related MIME types can share a single selector. If the same MIME type is assigned to multiple groups in settings, the first group takes precedence.
- For troubleshooting, run: `XDG_UTILS_DEBUG_LEVEL=2 xdg-mime query default <mime-type>`

## Settings

- `Common Tab Groups` lets you edit the comma-separated MIME types assigned to each group shown on the `Common` tab.
- `Reset to defaults` restores the built-in common-group definitions.

## IPC

This plugin exposes an IPC target so the panel can be opened from keybinds, scripts, or a `.desktop` launcher.

```txt
target plugin:mimeapp-gui
	function open(): void
	function toggle(): void
```

Example commands:

```bash
qs -c noctalia-shell ipc call plugin:mimeapp-gui open
qs -c noctalia-shell ipc call plugin:mimeapp-gui toggle
```

Example `.desktop` `Exec` line:

```txt
Exec=qs -c noctalia-shell ipc call plugin:mimeapp-gui open
```
