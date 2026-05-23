local M = {
  schema = "sevenos.hypr-lua.windows.v1",
  phase = "common-window-rules",
}

M.common_rules = {
  "windowrule = match:title ^(Open File)(.*)$, float on, center on",
  "windowrule = match:title ^(Select a File)(.*)$, float on, center on",
  "windowrule = match:title ^(Open Folder)(.*)$, float on, center on",
  "windowrule = match:title ^(Save As)(.*)$, float on, center on",
  "windowrule = match:title ^(File Upload)(.*)$, float on, center on",
  "windowrule = match:title ^(Preferences|Settings|Properties)(.*)$, float on, center on",
  "windowrule = match:title ^(About)(.*)$, float on, center on",
  "windowrule = match:class ^(pavucontrol)$, float on, center on, size 46% 46%",
  "windowrule = match:class ^(nm-connection-editor)$, float on, center on, size 50% 58%",
  "windowrule = match:class ^(blueman-manager)$, float on, center on, size 52% 58%",
  "windowrule = match:class ^(org.gnome.Calculator)$, float on, center on, size 420 560",
  "windowrule = match:class ^(org.gnome.Loupe)$, float on, center on, size 72% 72%",
  "windowrule = match:class ^(org.gnome.Nautilus)$, float on, center on, size 78% 76%",
  "windowrule = match:class ^(Nautilus)$, float on, center on, size 78% 76%",
  "windowrule = match:class ^(SevenTerminalNative)$, float on, center on, size 760 480",
  "windowrule = match:title ^(Seven Terminal · .*)$, float on, center on, size 760 480",
  "windowrule = match:class ^(SevenTerminalClassic)$, float on, center on, size 760 480",
  "windowrule = match:class ^(SevenTerminalDark)$, float on, center on, size 760 480",
  "windowrule = match:class ^(SevenTerminalLight)$, float on, center on, size 760 480",
  "windowrule = match:class ^(SevenTerminalForge)$, float on, center on, size 760 480",
  "windowrule = match:class ^(SevenTerminalCyber)$, float on, center on, size 760 480",
  "windowrule = match:class ^(SevenTerminalWindows)$, float on, center on, size 820 500",
  "windowrule = match:class ^(SevenTerminalFocus)$, float on, center on, size 760 480",
  "windowrule = match:class ^(SevenTerminalAdmin)$, float on, center on, size 760 480",
  "windowrule = match:class ^(SevenLaunchpadNative)$, float on, center on, size 86% 82%",
  "windowrule = match:class ^(SevenSpotlightNative)$, float on, center on",
  "windowrule = match:title ^(SevenOS Spotlight)$, float on, center on",
  "windowrule = match:class ^(SevenNotificationCenterNative)$, float on, center on",
  "windowrule = match:title ^(SevenOS Notifications)$, float on, center on",
  "windowrule = match:class ^(SevenProfileCenterNative)$, float on, center on",
  "windowrule = match:title ^(SevenOS Profiles)$, float on, center on",
  "windowrule = match:class ^(SevenShieldCenterNative)$, float on, center on",
  "windowrule = match:title ^(SevenOS Shield)$, float on, center on",
  "windowrule = match:class ^(SevenWaybarCenterNative)$, float on, center on",
  "windowrule = match:class ^(SevenSettingsNative)$, float on, center on, size 980 660",
  "windowrule = match:title ^(SevenOS Settings)$, float on, center on, size 980 660",
  "windowrule = match:title ^(SevenOS .*)$, float on, center on",
  "windowrule = match:class ^(SevenQuickSettingsNative)$, float on, size 360 520, move 70% 10%",
  "windowrule = match:title ^(SevenOS Quick Settings)$, float on, size 360 520, move 70% 10%",
  "windowrule = match:class ^(SevenFilesNative)$, float on, center on, size 1040 660",
  "windowrule = match:title ^(Seven Files)$, float on, center on, size 1040 660",
  "windowrule = match:class ^(SevenReaderNative)$, float on, center on, size 1220 760",
  "windowrule = match:title ^(Seven Reader)$, float on, center on, size 1220 760",
  "windowrule = match:class ^(SevenDockNative)$, float on, pin on, size 540 82",
  "windowrule = match:title ^(Seven Dock)$, float on, pin on, size 540 82",
  "windowrule = match:class ^(SevenWindowControlsNative)$, float on, pin on, center on, size 420 62",
  "windowrule = match:title ^(Seven Window Controls)$, float on, pin on, center on, size 420 62",
  "windowrule = match:title ^(SevenOS Help)(.*)$, float on, center on",
  "windowrule = match:title ^(SevenOS Migration)(.*)$, float on, center on",
  "windowrule = match:title ^(Picture[- ]?[Ii]n[- ]?[Pp]icture)(.*)$, float on, pin on, size 25% 25%, move 73% 72%",
  "windowrule = match:class ^(mpv)$, float on, center on, size 72% 72%",
  "windowrule = match:class ^(vlc)$, float on, center on, size 72% 72%",
  "windowrule = match:class ^(Spotify)$, float on, center on, size 54% 62%",
}

M.workspace_rules = {
  "workspace = special:seven, gapsout:30",
}

function M.rules()
  return M.common_rules
end

return M
