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
from pathlib import Path
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


def active_profile() -> str:
    for key in ("SEVENOS_ACTIVE_PROFILE", "SEVENOS_PROFILE_CONTAINER", "SEVENOS_EXEC_PROFILE"):
        value = os.environ.get(key, "").strip().strip("'\"")
        if value:
            return value
    profile_env = Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config"))) / "sevenos" / "profile.env"
    try:
        for line in profile_env.read_text(encoding="utf-8", errors="ignore").splitlines():
            key, _, value = line.partition("=")
            if key.strip() == "SEVENOS_ACTIVE_PROFILE":
                return value.strip().strip("'\"") or "equinox"
    except OSError:
        pass
    return "equinox"


def unique_items(items: list[str]) -> list[str]:
    result: list[str] = []
    seen: set[str] = set()
    for item in items:
        clean = item.strip()
        if clean and clean not in seen:
            seen.add(clean)
            result.append(clean)
    return result


def local_answer(prompt: str, context: dict[str, Any] | None = None) -> dict[str, Any]:
    raw = normalize(prompt)
    context = context or {}
    language = active_language(context)
    system_context = context.get("system_context") if isinstance(context.get("system_context"), dict) else {}
    shell_context = system_context.get("shell_context") if isinstance(system_context.get("shell_context"), dict) else {}
    shell_profile = shell_context.get("profile") if isinstance(shell_context.get("profile"), dict) else {}
    shell_app = shell_context.get("app") if isinstance(shell_context.get("app"), dict) else {}
    shell_layout = shell_context.get("layout") if isinstance(shell_context.get("layout"), dict) else {}
    profile = str(context.get("profile") or shell_profile.get("key") or active_profile())
    app_key = str(shell_app.get("key") or "")
    app_label = str(shell_app.get("label") or app_key)
    service = str(shell_app.get("service") or "")
    density = str(shell_layout.get("density") or "")
    signals: list[str] = []
    if profile:
        signals.append(f"profile:{profile}")
    if app_label:
        signals.append(f"app:{app_label}")
    if service:
        signals.append(f"service:{service}")
    if density:
        signals.append(f"density:{density}")
    suggestions: list[str] = []
    if language == "fr":
        answer = "SevenAI peut aider avec les apps, les espaces de travail, les thèmes, les diagnostics, les réparations et les explications SevenOS."
        suggestions = ["diagnose system", "prépare mon espace pour coder", "raccourcis"]
    else:
        answer = "SevenAI can help with apps, workspaces, themes, diagnostics, repairs and SevenOS guidance."
        suggestions = ["diagnose system", "prepare my workspace", "shortcuts"]

    profile_guidance = {
        "equinox": (
            "En mode Equinox, je privilégie l’équilibre, la clarté et les actions sûres avant les changements système."
            if language == "fr"
            else "In Equinox, I prioritize balance, clarity and safe previews before system changes."
        ),
        "forge": (
            "En mode Forge, je privilégie projets, Git, containers, terminal et diagnostics de build."
            if language == "fr"
            else "In Forge, I prioritize projects, Git, containers, terminal and build diagnostics."
        ),
        "shield": (
            "En mode Shield, je privilégie les actions prudentes, l’audit, la sandbox et les preuves."
            if language == "fr"
            else "In Shield, I prioritize cautious actions, audit, sandboxing and evidence."
        ),
        "studio": (
            "En mode Studio, je privilégie médias, assets, exports et outils créatifs."
            if language == "fr"
            else "In Studio, I prioritize media, assets, exports and creative tools."
        ),
        "baobab": (
            "En mode Baobab, je réponds comme guide culturel calme, éducatif et local-first."
            if language == "fr"
            else "In Baobab, I answer as a calm, educational, local-first cultural guide."
        ),
        "pulse": (
            "En mode Pulse, je privilégie performance, jeux, captures et latence."
            if language == "fr"
            else "In Pulse, I prioritize performance, gaming, captures and latency."
        ),
        "windows": (
            "En mode Windows, je privilégie le bridge VM et l’isolation des apps Windows."
            if language == "fr"
            else "In Windows mode, I prioritize the VM bridge and Windows app isolation."
        ),
    }

    if profile in profile_guidance:
        answer = profile_guidance[profile]
        suggestions = ["seven ai workflow", "seven ai diagnose system --json", "seven ai shortcuts"]

    if any(token in raw for token in ("contexte actif", "active context", "app active", "application active", "où suis-je", "ou suis je")):
        if language == "fr":
            answer = f"Tu es dans {shell_profile.get('title', profile)} avec l’app active {app_label or 'desktop'}."
            if service:
                answer += f" Le service détecté est {service}."
            if density:
                answer += f" La densité shell actuelle est {density}."
        else:
            answer = f"You are in {shell_profile.get('title', profile)} with active app {app_label or 'desktop'}."
            if service:
                answer += f" The detected service is {service}."
            if density:
                answer += f" Current shell density is {density}."
        suggestions = ["seven ai context --json", "seven-actions --json", "prépare mon espace pour coder" if language == "fr" else "prepare my workspace"]
    elif app_key in {"terminal", "developer"} and any(token in raw for token in ("aide", "help", "quoi faire", "suggest")):
        answer = (
            "Contexte dev/terminal détecté : je peux expliquer la dernière commande, proposer un diagnostic, ouvrir Forge ou préparer un workspace dev."
            if language == "fr"
            else "Dev/terminal context detected: I can explain the last command, suggest diagnostics, open Forge or prepare a dev workspace."
        )
        suggestions = ["seven ai diagnose system --json", "seven ai workflow", "seven terminal doctor"]
    elif app_key in {"files"} and any(token in raw for token in ("aide", "help", "quoi faire", "suggest")):
        answer = (
            "Contexte fichiers détecté : je peux aider à organiser, rechercher, vérifier les permissions ou préparer une action sûre sur les fichiers."
            if language == "fr"
            else "Files context detected: I can help organize, search, inspect permissions or prepare a safe file action."
        )
        suggestions = ["seven ai context --json", "seven files doctor", "seven ai diagnose disk --json"]

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
    load = system_context.get("load") if isinstance(system_context.get("load"), dict) else {}
    try:
        if float(load.get("1m", 0)) >= 8 and "performance" not in raw and "lent" not in raw:
            answer += (
                " Je remarque aussi une charge système élevée, donc un diagnostic performance peut être utile."
                if language == "fr"
                else " I also notice high system load, so a performance diagnostic may help."
            )
            signals.append(f"load:{float(load.get('1m', 0)):.1f}")
            suggestions.append("seven ai diagnose system --json")
    except (TypeError, ValueError):
        pass
    failed_units = context.get("diagnostics", {}).get("failed_units") or []
    if failed_units:
        signals.append(f"failed-services:{len(failed_units)}")
    if context.get("diagnostics", {}).get("network", {}).get("networkmanager") != "active":
        signals.append("network:review")
    suggestions = unique_items(suggestions)

    return {
        "schema": "sevenos.ai.provider.local.v1",
        "provider": "seven-local",
        "privacy": "local-only",
        "language": language,
        "profile": profile,
        "context": {
            "profile": profile,
            "app": app_label,
            "service": service,
            "density": density,
        },
        "why": {
            "summary": (
                "Réponse basée sur le contexte local SevenOS, sans appel externe."
                if language == "fr"
                else "Answer based on local SevenOS context, without external calls."
            ),
            "signals": signals[:8],
        },
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
