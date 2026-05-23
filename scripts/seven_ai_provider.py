#!/usr/bin/env python3
"""Local-only SevenAI provider.

This is not an external LLM adapter. It is a deterministic, privacy-preserving
reasoning layer that turns SevenOS context, intents, diagnostics and memory into
short structured guidance. It exists so SevenAI has a provider interface without
tokens, accounts or data leaving the machine.
"""

from __future__ import annotations

import json
import os
import re
import sys
from typing import Any

from seven_i18n import language_code as sevenos_language_code


def normalize(value: str) -> str:
    return re.sub(r"\s+", " ", value.strip().lower())


def active_language(context: dict[str, Any] | None = None) -> str:
    context = context or {}
    requested = str(context.get("language") or os.environ.get("SEVENAI_LANG") or "")
    if requested.startswith("fr"):
        return "fr"
    if requested.startswith("en"):
        return "en"
    try:
        return "fr" if sevenos_language_code().startswith("fr") else "en"
    except Exception:
        return "en"


def local_answer(prompt: str, context: dict[str, Any] | None = None) -> dict[str, Any]:
    raw = normalize(prompt)
    context = context or {}
    language = active_language(context)
    suggestions: list[str] = []
    if language == "fr":
        answer = "SevenAI peut aider avec les apps, les espaces de travail, les thèmes, les diagnostics, les réparations et les explications SevenOS."
    else:
        answer = "SevenAI can help with apps, workspaces, themes, diagnostics, repairs and SevenOS guidance."

    if any(token in raw for token in ("wifi", "network", "réseau", "reseau")):
        answer = (
            "Pour un problème Wi-Fi, SevenAI vérifie d’abord l’état du réseau SevenOS avant de proposer une réparation."
            if language == "fr"
            else "For Wi-Fi issues, SevenAI should inspect SevenOS network state before proposing a repair."
        )
        suggestions = [
            "seven ai diagnose network --json",
            "seven ai playbook wifi_repair --json",
            "seven ai \"mon wifi ne marche pas\"",
        ]
    elif any(token in raw for token in ("slow", "lent", "performance", "ram", "cpu")):
        answer = (
            "Pour un système lent, SevenAI compare la charge, la mémoire, les processus lourds et les services en erreur."
            if language == "fr"
            else "For a slow system, SevenAI should compare load, memory, top processes and failed services."
        )
        suggestions = [
            "seven ai diagnose system --json",
            "seven ai playbook slow_system --json",
            "seven ai \"optimise mon système\"",
        ]
    elif any(token in raw for token in ("workspace", "travail", "focus", "organise")):
        answer = (
            "SevenOS fonctionne mieux quand Spotlight devient le centre de commande et que les espaces sont séparés par contexte."
            if language == "fr"
            else "SevenOS works best when Spotlight is the command center and workspaces are separated by context."
        )
        suggestions = [
            "seven ai workflow",
            "seven ai shortcuts",
            "seven ai \"workspace 2\"",
        ]
    elif any(token in raw for token in ("sevenos", "raccourci", "shortcut", "theme", "thème")):
        answer = (
            "SevenOS est un OS personnel intelligent, local-first, avec profils contextuels et surfaces système premium."
            if language == "fr"
            else "SevenOS is an intelligent personal OS with local-first AI, contextual profiles and premium system surfaces."
        )
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
        "language": language,
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
