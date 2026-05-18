#!/usr/bin/env python3
"""Local-only SevenAI provider.

This is not an external LLM adapter. It is a deterministic, privacy-preserving
reasoning layer that turns SevenOS context, intents, diagnostics and memory into
short structured guidance. It exists so SevenAI has a provider interface without
tokens, accounts or data leaving the machine.
"""

from __future__ import annotations

import json
import re
import sys
from typing import Any


def normalize(value: str) -> str:
    return re.sub(r"\s+", " ", value.strip().lower())


def local_answer(prompt: str, context: dict[str, Any] | None = None) -> dict[str, Any]:
    raw = normalize(prompt)
    context = context or {}
    suggestions: list[str] = []
    answer = "SevenAI can help with apps, workspaces, themes, diagnostics, repairs and SevenOS guidance."

    if any(token in raw for token in ("wifi", "network", "réseau", "reseau")):
        answer = "For Wi-Fi issues, SevenAI should inspect NetworkManager state before restarting services."
        suggestions = [
            "seven ai diagnose network --json",
            "seven ai playbook wifi_repair --json",
            "seven ai \"mon wifi ne marche pas\"",
        ]
    elif any(token in raw for token in ("slow", "lent", "performance", "ram", "cpu")):
        answer = "For a slow system, SevenAI should compare load, memory, top processes and failed services."
        suggestions = [
            "seven ai diagnose system --json",
            "seven ai playbook slow_system --json",
            "seven ai \"optimise mon système\"",
        ]
    elif any(token in raw for token in ("workspace", "travail", "focus", "organise")):
        answer = "SevenOS works best when Spotlight is the command center and workspaces are separated by context."
        suggestions = [
            "seven ai workflow",
            "seven ai shortcuts",
            "seven ai \"workspace 2\"",
        ]
    elif any(token in raw for token in ("sevenos", "raccourci", "shortcut", "theme", "thème")):
        answer = "SevenOS is a Hyprland-based intelligent Linux experience with local-first AI, profiles and premium shell surfaces."
        suggestions = [
            "seven ai knowledge",
            "seven ai shortcuts",
            "seven ai \"mets le thème light\"",
        ]

    if context.get("diagnostics", {}).get("failed_units"):
        suggestions.append("seven ai playbook failed_services --json")
    if context.get("diagnostics", {}).get("network", {}).get("networkmanager") != "active":
        suggestions.append("seven ai playbook wifi_repair --json")

    return {
        "schema": "sevenos.ai.provider.local.v1",
        "provider": "seven-local",
        "privacy": "local-only",
        "prompt": prompt,
        "answer": answer,
        "suggestions": suggestions[:6],
        "external_calls": [],
    }


def main() -> int:
    payload = {}
    if not sys.stdin.isatty():
        try:
            payload = json.loads(sys.stdin.read() or "{}")
        except json.JSONDecodeError:
            payload = {}
    prompt = " ".join(sys.argv[1:]).strip() or payload.get("prompt", "")
    print(json.dumps(local_answer(prompt, payload.get("context")), indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
