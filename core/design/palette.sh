#!/usr/bin/env bash
# ==============================================================================
# SevenOS — Design System v2.0
# ==============================================================================
#
# "Dark by nature. Precise by design. Human by experience."
#
# Central visual language for SevenOS.
#
# Architecture:
#   01. Core Identity
#   02. System States
#   03. Surfaces
#   04. Typography
#   05. Glass / Borders
#   06. Gradient
#   07. Cultural Layer
#   08. Experience Accents
#   09. Legacy Compatibility Aliases
#
# IMPORTANT:
#   - New code SHOULD use the canonical tokens.
#   - Legacy aliases exist only to avoid breaking older scripts.
#   - Do not introduce new color aliases without updating this file.
#
# ==============================================================================


# ==============================================================================
# 01 — CORE IDENTITY
# ==============================================================================
#
# These are the colors that visually identify SevenOS.
#
# Blue   → Technology / Trust / Precision
# Violet → Intelligence / Creativity / Experimentation
# Cyan   → Information / Connection / Interaction
# Green  → Active / Secure / Successful
#
# ==============================================================================

SEVENOS_COLOR_PRIMARY="#4DA3FF"
SEVENOS_COLOR_SECONDARY="#7A5CFF"
SEVENOS_COLOR_ACCENT="#00D4FF"
SEVENOS_COLOR_SUCCESS="#00FFB3"


# Short aliases for internal SevenOS scripts
SEVENOS_PRIMARY="$SEVENOS_COLOR_PRIMARY"
SEVENOS_SECONDARY="$SEVENOS_COLOR_SECONDARY"
SEVENOS_ACCENT="$SEVENOS_COLOR_ACCENT"
SEVENOS_SUCCESS="$SEVENOS_COLOR_SUCCESS"


# ==============================================================================
# 02 — SYSTEM STATES
# ==============================================================================
#
# Used to communicate system status.
#
# Success → Everything is OK
# Warning → Attention required
# Error   → Something failed
# Info    → Informational state
#
# ==============================================================================

SEVENOS_COLOR_WARNING="#FFB547"
SEVENOS_COLOR_ERROR="#FF5976"
SEVENOS_COLOR_INFO="#00D4FF"

SEVENOS_WARNING="$SEVENOS_COLOR_WARNING"
SEVENOS_ERROR="$SEVENOS_COLOR_ERROR"
SEVENOS_INFO="$SEVENOS_COLOR_INFO"


# ==============================================================================
# 03 — SURFACES
# ==============================================================================
#
# SevenOS uses layered dark surfaces instead of heavy borders.
#
# Level 0 → System background
# Level 1 → Main application surface
# Level 2 → Panel / Card
# Level 3 → Elevated element / Menu / Popover
#
# ==============================================================================

SEVENOS_SURFACE_0="#09090B"
SEVENOS_SURFACE_1="#12131A"
SEVENOS_SURFACE_2="#1C1F2C"
SEVENOS_SURFACE_3="#272B3D"


# Semantic surface names

SEVENOS_BG="$SEVENOS_SURFACE_0"
SEVENOS_SURFACE="$SEVENOS_SURFACE_1"
SEVENOS_PANEL="$SEVENOS_SURFACE_2"
SEVENOS_ELEVATED="$SEVENOS_SURFACE_3"


# ==============================================================================
# 04 — TEXT
# ==============================================================================
#
# Text hierarchy.
#
# Primary   → Main readable content
# Secondary → Supporting information
# Muted     → Low-priority information
# Disabled  → Disabled / unavailable elements
#
# ==============================================================================

SEVENOS_TEXT_PRIMARY="#EDEDED"
SEVENOS_TEXT_SECONDARY="#B9C0CC"
SEVENOS_TEXT_MUTED="#8A8F98"
SEVENOS_TEXT_DISABLED="#606776"


# Convenient aliases

SEVENOS_TEXT="$SEVENOS_TEXT_PRIMARY"
SEVENOS_TEXT_1="$SEVENOS_TEXT_PRIMARY"
SEVENOS_TEXT_2="$SEVENOS_TEXT_SECONDARY"
SEVENOS_TEXT_3="$SEVENOS_TEXT_MUTED"
SEVENOS_TEXT_4="$SEVENOS_TEXT_DISABLED"


# ==============================================================================
# 05 — GLASS & BORDERS
# ==============================================================================
#
# Glass is a depth system, not a default decoration.
#
# Use:
#   GLASS_1 → subtle
#   GLASS_2 → normal
#   GLASS_3 → elevated
#
# ==============================================================================

SEVENOS_GLASS_1="rgba(255,255,255,0.06)"
SEVENOS_GLASS_2="rgba(255,255,255,0.09)"
SEVENOS_GLASS_3="rgba(255,255,255,0.13)"

SEVENOS_BORDER="rgba(255,255,255,0.08)"
SEVENOS_BORDER_STRONG="rgba(255,255,255,0.14)"

# Accent borders

SEVENOS_BORDER_PRIMARY="rgba(77,163,255,0.32)"
SEVENOS_BORDER_ACCENT="rgba(0,212,255,0.32)"
SEVENOS_BORDER_SUCCESS="rgba(0,255,179,0.28)"
SEVENOS_BORDER_ERROR="rgba(255,89,118,0.30)"

# Hex-style aliases for tools that cannot interpret rgba()

SEVENOS_GLASS="#ffffff0f"
SEVENOS_GLASS_2_HEX="#ffffff17"
SEVENOS_GLASS_3_HEX="#ffffff21"

SEVENOS_GLASS_BORDER="#ffffff14"
SEVENOS_GLASS_BORDER_2="#4da3ff52"


# ==============================================================================
# 06 — GRADIENT
# ==============================================================================
#
# Official SevenOS signature gradient.
#
# Blue → Violet → Cyan
#
# Reserved for:
#   - Branding
#   - Seven AI
#   - SevenStore
#   - Onboarding
#   - Important highlights
#   - Marketing / presentation
#
# Do not use it everywhere.
#
# ==============================================================================

SEVENOS_GRADIENT_PRIMARY="linear-gradient(135deg, #4DA3FF 0%, #7A5CFF 50%, #00D4FF 100%)"

SEVENOS_GRADIENT_START="$SEVENOS_COLOR_PRIMARY"
SEVENOS_GRADIENT_MIDDLE="$SEVENOS_COLOR_SECONDARY"
SEVENOS_GRADIENT_END="$SEVENOS_COLOR_ACCENT"


# ==============================================================================
# 07 — CULTURAL LAYER
# ==============================================================================
#
# These names represent concepts inside the SevenOS visual language.
#
# They should NOT automatically become UI colors.
#
# Nile      → Connection / Flow / Network
# Baobab    → Stability / Foundation / Resilience
# Kente     → Expression / Identity / Personalization
# Sand      → Learning / Knowledge / Simplicity
# Hibiscus  → Attention / Alert / Interruption
# Soil      → Infrastructure / Storage / Foundation
#
# ==============================================================================

SEVENOS_CULTURE_NILE="$SEVENOS_COLOR_PRIMARY"
SEVENOS_CULTURE_BAOBAB="$SEVENOS_COLOR_SUCCESS"
SEVENOS_CULTURE_KENTE="$SEVENOS_COLOR_SECONDARY"
SEVENOS_CULTURE_SAND="$SEVENOS_TEXT_PRIMARY"
SEVENOS_CULTURE_HIBISCUS="$SEVENOS_COLOR_ERROR"
SEVENOS_CULTURE_SOIL="$SEVENOS_SURFACE_1"


# Human-readable cultural aliases

SEVENOS_NILE="$SEVENOS_CULTURE_NILE"
SEVENOS_BAOBAB="$SEVENOS_CULTURE_BAOBAB"
SEVENOS_KENTE="$SEVENOS_CULTURE_KENTE"
SEVENOS_SAND="$SEVENOS_CULTURE_SAND"
SEVENOS_HIBISCUS="$SEVENOS_CULTURE_HIBISCUS"
SEVENOS_SOIL="$SEVENOS_CULTURE_SOIL"


# ==============================================================================
# 08 — EXPERIENCE ACCENTS
# ==============================================================================
#
# Four major SevenOS experiences.
#
# LEARN   → Cyan
# BUILD   → Violet
# PROTECT → Green
# CONNECT → Blue
#
# These accents modify an experience without creating a separate theme.
#
# ==============================================================================

SEVENOS_LEARN="$SEVENOS_COLOR_ACCENT"
SEVENOS_BUILD="$SEVENOS_COLOR_SECONDARY"
SEVENOS_PROTECT="$SEVENOS_COLOR_SUCCESS"
SEVENOS_CONNECT="$SEVENOS_COLOR_PRIMARY"


# Explicit semantic names

SEVENOS_EXPERIENCE_LEARN="$SEVENOS_LEARN"
SEVENOS_EXPERIENCE_BUILD="$SEVENOS_BUILD"
SEVENOS_EXPERIENCE_PROTECT="$SEVENOS_PROTECT"
SEVENOS_EXPERIENCE_CONNECT="$SEVENOS_CONNECT"


# ==============================================================================
# 09 — LIGHT MODE IDENTITY
# ==============================================================================
#
# Same SevenOS signature, tuned for clarity on bright surfaces.
#
# ==============================================================================

SEVENOS_LIGHT_COLOR_PRIMARY="#2F7BFF"
SEVENOS_LIGHT_COLOR_SECONDARY="#6A5CFF"
SEVENOS_LIGHT_COLOR_ACCENT="#00B8D9"
SEVENOS_LIGHT_COLOR_SUCCESS="#00A77A"
SEVENOS_LIGHT_COLOR_WARNING="#C98200"
SEVENOS_LIGHT_COLOR_ERROR="#D9365A"
SEVENOS_LIGHT_COLOR_INFO="#00B8D9"

SEVENOS_LIGHT_SURFACE_0="#FFFFFF"
SEVENOS_LIGHT_SURFACE_1="#EEF1F5"
SEVENOS_LIGHT_SURFACE_2="#F5F7FA"
SEVENOS_LIGHT_SURFACE_3="#DDE3EA"

SEVENOS_LIGHT_TEXT_PRIMARY="#1C1F26"
SEVENOS_LIGHT_TEXT_SECONDARY="#384152"
SEVENOS_LIGHT_TEXT_MUTED="#6B7280"
SEVENOS_LIGHT_TEXT_DISABLED="#9AA3AF"

SEVENOS_LIGHT_GLASS_1="rgba(255, 255, 255, 0.70)"
SEVENOS_LIGHT_GLASS_2="rgba(255, 255, 255, 0.82)"
SEVENOS_LIGHT_GLASS_3="rgba(255, 255, 255, 0.92)"
SEVENOS_LIGHT_BORDER="rgba(0, 0, 0, 0.06)"
SEVENOS_LIGHT_BORDER_STRONG="rgba(47, 123, 255, 0.24)"


# ==============================================================================
# 10 — NATIVE COMFORT PALETTE
# ==============================================================================
#
# Glass surfaces for native GTK apps (Settings, Files, Hub…).
# Derived from canonical dark/light tokens for a fluid, cohesive feel.
#
# ==============================================================================

SEVENOS_COMFORT_DARK_BG="$SEVENOS_SURFACE_0"
SEVENOS_COMFORT_DARK_PANEL="rgba(18, 19, 26, 0.82)"
SEVENOS_COMFORT_DARK_PANEL_2="rgba(28, 31, 44, 0.76)"
SEVENOS_COMFORT_DARK_SIDEBAR="rgba(9, 9, 11, 0.86)"
SEVENOS_COMFORT_DARK_TEXT="$SEVENOS_TEXT_PRIMARY"
SEVENOS_COMFORT_DARK_MUTED="$SEVENOS_TEXT_MUTED"
SEVENOS_COMFORT_DARK_BORDER="rgba(77, 163, 255, 0.10)"
SEVENOS_COMFORT_DARK_HOVER="rgba(77, 163, 255, 0.13)"
SEVENOS_COMFORT_DARK_SELECTED="rgba(77, 163, 255, 0.20)"

SEVENOS_COMFORT_LIGHT_BG="#F6F9FD"
SEVENOS_COMFORT_LIGHT_PANEL="#FAFCFF"
SEVENOS_COMFORT_LIGHT_PANEL_2="#F3F7FC"
SEVENOS_COMFORT_LIGHT_PANEL_3="#ECF3FC"
SEVENOS_COMFORT_LIGHT_SIDEBAR="#F8FBFF"
SEVENOS_COMFORT_LIGHT_TEXT="#20283A"
SEVENOS_COMFORT_LIGHT_MUTED="#667287"
SEVENOS_COMFORT_LIGHT_BORDER="rgba(54, 76, 112, 0.12)"
SEVENOS_COMFORT_LIGHT_HOVER="rgba(47, 123, 255, 0.10)"
SEVENOS_COMFORT_LIGHT_SELECTED="rgba(47, 123, 255, 0.17)"


# ==============================================================================
# 11 — LEGACY COMPATIBILITY
# ==============================================================================
#
# DO NOT use these names for new development.
#
# They are maintained so existing SevenOS scripts do not immediately break.
#
# ==============================================================================


# ------------------------------------------------------------------------------
# Old Core Colors
# ------------------------------------------------------------------------------

SEVENOS_BLUE="$SEVENOS_COLOR_PRIMARY"
SEVENOS_VIOLET="$SEVENOS_COLOR_SECONDARY"
SEVENOS_CYAN="$SEVENOS_COLOR_ACCENT"

SEVENOS_GREEN="$SEVENOS_COLOR_SUCCESS"
SEVENOS_GREEN_ACTIVE="#00E676"


# ------------------------------------------------------------------------------
# Old Surface Names
# ------------------------------------------------------------------------------

SEVENOS_DEEP_VOID="$SEVENOS_SURFACE_0"
SEVENOS_CYBER_VOID="#0A0F0D"

SEVENOS_SURFACE_DARK="$SEVENOS_SURFACE_1"
SEVENOS_SURFACE_CYBER="#002B22"

SEVENOS_SURFACE_0="$SEVENOS_SURFACE_0"
SEVENOS_SURFACE_1="$SEVENOS_SURFACE_1"
SEVENOS_SURFACE_2="$SEVENOS_SURFACE_2"
SEVENOS_SURFACE_3="$SEVENOS_SURFACE_3"


# ------------------------------------------------------------------------------
# Old Text Names
# ------------------------------------------------------------------------------

SEVENOS_SOFT_WHITE="$SEVENOS_TEXT_PRIMARY"
SEVENOS_MUTED_GRAY="$SEVENOS_TEXT_MUTED"


# ------------------------------------------------------------------------------
# Old Semantic Names
# ------------------------------------------------------------------------------

SEVENOS_INK="$SEVENOS_SURFACE_0"
SEVENOS_GRAPHITE="$SEVENOS_SURFACE_1"

SEVENOS_BRASS="$SEVENOS_COLOR_SECONDARY"
SEVENOS_COPPER="$SEVENOS_COLOR_ERROR"
SEVENOS_MALACHITE="$SEVENOS_COLOR_SUCCESS"

SEVENOS_COBALT="$SEVENOS_COLOR_PRIMARY"
SEVENOS_OXBLOOD="$SEVENOS_COLOR_ERROR"

SEVENOS_IVORY="$SEVENOS_TEXT_PRIMARY"
SEVENOS_RAFFIA="$SEVENOS_TEXT_SECONDARY"
SEVENOS_SHADOW="$SEVENOS_SURFACE_0"


# ------------------------------------------------------------------------------
# Old Cultural Names
# ------------------------------------------------------------------------------

SEVENOS_VOID="$SEVENOS_SURFACE_0"
SEVENOS_MIDNIGHT="$SEVENOS_SURFACE_1"
SEVENOS_PALACE="$SEVENOS_SURFACE_1"

SEVENOS_KENTE_GOLD="$SEVENOS_COLOR_SECONDARY"
SEVENOS_SUNFIRE="$SEVENOS_COLOR_ERROR"
SEVENOS_HIBISCUS="$SEVENOS_COLOR_ERROR"

SEVENOS_NILE="$SEVENOS_COLOR_PRIMARY"
SEVENOS_EMERALD="$SEVENOS_COLOR_SUCCESS"


# ------------------------------------------------------------------------------
# Old Material Names
# ------------------------------------------------------------------------------

SEVENOS_OBSIDIAN="$SEVENOS_SURFACE_0"
SEVENOS_CHARCOAL="$SEVENOS_SURFACE_1"
SEVENOS_SOIL="$SEVENOS_SURFACE_1"
SEVENOS_SAND="$SEVENOS_TEXT_PRIMARY"


# ------------------------------------------------------------------------------
# Old Compatibility Names
# ------------------------------------------------------------------------------

SEVENOS_EBENE="$SEVENOS_SURFACE_0"
SEVENOS_EBENE="$SEVENOS_SURFACE_0"

SEVENOS_GOLD="$SEVENOS_COLOR_SECONDARY"
SEVENOS_GOLD_BRIGHT="$SEVENOS_COLOR_ACCENT"
SEVENOS_GOLD_DIM="#6B53D4"

SEVENOS_CLAY="$SEVENOS_COLOR_ERROR"
SEVENOS_CLAY_DIM="#C94563"

SEVENOS_BAOBA_BRIGHT="$SEVENOS_COLOR_SUCCESS"
SEVENOS_BAOBAB_BRIGHT="#00E676"

SEVENOS_INDIGO="$SEVENOS_COLOR_PRIMARY"
SEVENOS_INDIGO_BRIGHT="$SEVENOS_COLOR_ACCENT"


# ==============================================================================
# 12 — DESIGN SYSTEM METADATA
# ==============================================================================
#
# Useful for scripts, diagnostics and future SevenOS tooling.
#
# ==============================================================================

SEVENOS_DESIGN_SYSTEM_VERSION="2.0.0"
SEVENOS_DESIGN_SYSTEM_NAME="SevenOS Design System"
SEVENOS_DESIGN_SYSTEM_MODE="dark"

SEVENOS_DESIGN_SYSTEM_PHILOSOPHY="Dark by nature. Precise by design. Human by experience."


# ==============================================================================
# 13 — OPTIONAL EXPORT
# ==============================================================================

export SEVENOS_COLOR_PRIMARY SEVENOS_COLOR_SECONDARY SEVENOS_COLOR_ACCENT
export SEVENOS_COLOR_SUCCESS SEVENOS_COLOR_WARNING SEVENOS_COLOR_ERROR SEVENOS_COLOR_INFO
export SEVENOS_SURFACE_0 SEVENOS_SURFACE_1 SEVENOS_SURFACE_2 SEVENOS_SURFACE_3
export SEVENOS_TEXT_PRIMARY SEVENOS_TEXT_SECONDARY SEVENOS_TEXT_MUTED SEVENOS_TEXT_DISABLED
export SEVENOS_GLASS_1 SEVENOS_GLASS_2 SEVENOS_GLASS_3 SEVENOS_BORDER SEVENOS_BORDER_STRONG
export SEVENOS_BORDER_PRIMARY SEVENOS_BORDER_ACCENT SEVENOS_GRADIENT_PRIMARY
export SEVENOS_LIGHT_COLOR_PRIMARY SEVENOS_LIGHT_COLOR_SECONDARY SEVENOS_LIGHT_COLOR_ACCENT
export SEVENOS_LIGHT_COLOR_SUCCESS SEVENOS_LIGHT_COLOR_WARNING SEVENOS_LIGHT_COLOR_ERROR
export SEVENOS_LIGHT_SURFACE_0 SEVENOS_LIGHT_TEXT_PRIMARY
export SEVENOS_COMFORT_DARK_BG SEVENOS_COMFORT_DARK_PANEL SEVENOS_COMFORT_DARK_PANEL_2
export SEVENOS_COMFORT_DARK_SIDEBAR SEVENOS_COMFORT_DARK_TEXT SEVENOS_COMFORT_DARK_MUTED
export SEVENOS_COMFORT_DARK_BORDER SEVENOS_COMFORT_DARK_HOVER SEVENOS_COMFORT_DARK_SELECTED
export SEVENOS_COMFORT_LIGHT_BG SEVENOS_COMFORT_LIGHT_PANEL SEVENOS_COMFORT_LIGHT_PANEL_2
export SEVENOS_COMFORT_LIGHT_SIDEBAR SEVENOS_COMFORT_LIGHT_TEXT SEVENOS_COMFORT_LIGHT_MUTED
export SEVENOS_COMFORT_LIGHT_BORDER SEVENOS_COMFORT_LIGHT_HOVER SEVENOS_COMFORT_LIGHT_SELECTED
export SEVENOS_DESIGN_SYSTEM_VERSION


# ==============================================================================
# END — SevenOS Design System v2.0
# ==============================================================================
