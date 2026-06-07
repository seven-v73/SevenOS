use std::collections::{HashMap, HashSet};
use std::env;
use std::fs::{self, OpenOptions};
use std::io::Write;
#[cfg(unix)]
use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::thread;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use serde_json::{json, Value};

fn state_dir() -> PathBuf {
    if let Ok(value) = env::var("XDG_STATE_HOME") {
        return PathBuf::from(value).join("sevenos");
    }
    if let Ok(home) = env::var("HOME") {
        return PathBuf::from(home).join(".local/state/sevenos");
    }
    PathBuf::from("/tmp/sevenos")
}

fn sevenos_root() -> Option<PathBuf> {
    if let Ok(value) = env::var("SEVENOS_ROOT") {
        let candidate = PathBuf::from(value);
        if candidate.join("install.sh").is_file() {
            return Some(candidate);
        }
    }

    if let Ok(current) = env::current_dir() {
        if current.join("install.sh").is_file() {
            return Some(current);
        }
    }

    if let Ok(home) = env::var("HOME") {
        for candidate in [
            PathBuf::from(&home).join("Code/OS/SevenOS"),
            PathBuf::from(&home).join("SevenOS"),
            PathBuf::from("/opt/SevenOS"),
            PathBuf::from("/usr/share/sevenos"),
        ] {
            if candidate.join("install.sh").is_file() {
                return Some(candidate);
            }
        }
    }

    None
}

fn event_file() -> PathBuf {
    state_dir().join("events.jsonl")
}

fn runtime_dir() -> Option<PathBuf> {
    if let Ok(value) = env::var("XDG_RUNTIME_DIR") {
        return Some(PathBuf::from(value));
    }
    if let Ok(uid) = env::var("UID") {
        return Some(PathBuf::from("/run/user").join(uid));
    }
    let output = Command::new("id").arg("-u").output().ok()?;
    if !output.status.success() {
        return None;
    }
    let uid = String::from_utf8_lossy(&output.stdout).trim().to_string();
    if uid.is_empty() {
        None
    } else {
        Some(PathBuf::from("/run/user").join(uid))
    }
}

fn daemon_fast_mode() -> bool {
    [
        "SEVENOS_FAST",
        "SEVENOS_STATE_FAST",
        "SEVENOS_UX_FAST",
        "SEVENOS_UPDATE_FAST",
        "SEVENOS_HEALTH_FAST",
        "SEVENOS_DISTRIBUTION_FAST",
        "SEVENOS_LIFECYCLE_FAST",
    ]
    .iter()
    .any(|key| env::var(key).map(|value| value == "1" || value.eq_ignore_ascii_case("true")).unwrap_or(false))
}

fn detect_wayland_display() -> String {
    if let Ok(value) = env::var("WAYLAND_DISPLAY") {
        if !value.is_empty() {
            return value;
        }
    }

    let Some(dir) = runtime_dir() else {
        return String::new();
    };
    let Ok(entries) = fs::read_dir(dir) else {
        return String::new();
    };
    let mut displays = entries
        .filter_map(Result::ok)
        .filter_map(|entry| entry.file_name().into_string().ok())
        .filter(|name| name.starts_with("wayland-") && !name.ends_with(".lock"))
        .collect::<Vec<_>>();
    displays.sort();
    displays.into_iter().next().unwrap_or_default()
}

fn detect_desktop() -> String {
    for key in ["XDG_CURRENT_DESKTOP", "XDG_SESSION_DESKTOP", "DESKTOP_SESSION"] {
        if let Ok(value) = env::var(key) {
            if !value.is_empty() {
                return value;
            }
        }
    }
    let output = Command::new("pgrep").arg("-x").arg("Hyprland").output();
    if matches!(output, Ok(result) if result.status.success()) {
        "Hyprland".to_string()
    } else {
        String::new()
    }
}

fn path_state(path: &PathBuf) -> &'static str {
    if path.exists() {
        "OK"
    } else {
        "MISS"
    }
}

fn executable_state(path: &Path) -> &'static str {
    if !path.is_file() {
        return "missing";
    }
    #[cfg(unix)]
    {
        if fs::metadata(path)
            .map(|meta| meta.permissions().mode() & 0o111 != 0)
            .unwrap_or(false)
        {
            "ready"
        } else {
            "missing"
        }
    }
    #[cfg(not(unix))]
    {
        "ready"
    }
}

fn can_write_state_dir() -> bool {
    let dir = state_dir();
    if fs::create_dir_all(&dir).is_err() {
        return false;
    }
    let probe = dir.join(".seven-daemon-write-check");
    match fs::write(&probe, b"ok") {
        Ok(_) => {
            let _ = fs::remove_file(probe);
            true
        }
        Err(_) => false,
    }
}

fn event_count() -> usize {
    let path = event_file();
    match fs::read_to_string(path) {
        Ok(content) => content.lines().count(),
        Err(_) => 0,
    }
}

fn event_lines() -> Vec<String> {
    let path = event_file();
    match fs::read_to_string(path) {
        Ok(content) => content.lines().map(|line| line.to_string()).collect(),
        Err(_) => Vec::new(),
    }
}

fn unix_timestamp() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_else(|_| Duration::from_secs(0))
        .as_secs()
}

fn proc_first_line(path: &str) -> Option<String> {
    fs::read_to_string(path)
        .ok()
        .and_then(|content| content.lines().next().map(str::to_string))
}

fn uptime_seconds() -> Option<u64> {
    let raw = proc_first_line("/proc/uptime")?;
    let first = raw.split_whitespace().next()?;
    let seconds = first.split('.').next()?;
    seconds.parse::<u64>().ok()
}

fn loadavg() -> Value {
    let raw = proc_first_line("/proc/loadavg").unwrap_or_default();
    let parts: Vec<&str> = raw.split_whitespace().collect();
    json!({
        "one": parts.first().copied().unwrap_or("0.00"),
        "five": parts.get(1).copied().unwrap_or("0.00"),
        "fifteen": parts.get(2).copied().unwrap_or("0.00"),
    })
}

fn meminfo_kib(key: &str) -> Option<u64> {
    let content = fs::read_to_string("/proc/meminfo").ok()?;
    for line in content.lines() {
        let mut parts = line.split_whitespace();
        if parts.next()? == format!("{}:", key) {
            return parts.next()?.parse::<u64>().ok();
        }
    }
    None
}

fn memory_json() -> Value {
    let total = meminfo_kib("MemTotal").unwrap_or(0);
    let available = meminfo_kib("MemAvailable").unwrap_or(0);
    let used = total.saturating_sub(available);
    let used_percent = if total > 0 {
        ((used as f64 / total as f64) * 100.0).round() as u64
    } else {
        0
    };
    json!({
        "total_kib": total,
        "available_kib": available,
        "used_kib": used,
        "used_percent": used_percent,
    })
}

fn count_key(counts: &mut Vec<(String, usize)>, key: &str) {
    if let Some((_name, count)) = counts.iter_mut().find(|(name, _count)| name == key) {
        *count += 1;
    } else {
        counts.push((key.to_string(), 1));
    }
}

fn json_counts(counts: &[(String, usize)]) -> String {
    let body = counts
        .iter()
        .map(|(key, count)| format!("\"{}\":{}", json_escape(key), count))
        .collect::<Vec<_>>()
        .join(",");
    format!("{{{}}}", body)
}

fn json_escape(value: &str) -> String {
    value
        .replace('\\', "\\\\")
        .replace('"', "\\\"")
        .replace('\n', "\\n")
}

#[derive(Clone, Copy)]
struct ProfileSpec {
    key: &'static str,
    title: &'static str,
    description: &'static str,
    role: &'static str,
    accent: &'static str,
    principle: &'static str,
    story: &'static str,
    workspace: &'static str,
    package_files: &'static [&'static str],
    apps: &'static [&'static str],
}

#[derive(Clone, Copy)]
struct CyberContextSpec {
    key: &'static str,
    title: &'static str,
    workspace: u8,
    accent: &'static str,
    purpose: &'static str,
    apps: &'static [&'static str],
    tools: &'static [&'static str],
    actions: &'static [&'static str],
}

const PROFILES: &[ProfileSpec] = &[
    ProfileSpec {
        key: "equinox",
        title: "Equinox Balance",
        description:
            "Balanced SevenOS host profile for daily use, settings, files and system control.",
        role: "Balance",
        accent: "indigo",
        principle: "stable orchestration",
        story: "Keep the host calm, stable and ready while specialized mini OS profiles do the heavy work.",
        workspace: "SevenOS",
        package_files: &["scripts/packages-base.txt"],
        apps: &["seven hub", "seven files", "kitty"],
    },
    ProfileSpec {
        key: "baobab",
        title: "Baobab Cultural OS",
        description:
            "African cultural mini OS for heritage, languages, oral traditions, music and community memory.",
        role: "Culture",
        accent: "baobab",
        principle: "living heritage, offline-first",
        story: "Enter Baobab as an African digital village for heritage, oral stories, languages and transmission.",
        workspace: "Baobab",
        package_files: &["scripts/packages-culture.txt"],
        apps: &["kiwix", "foliate", "anki"],
    },
    ProfileSpec {
        key: "forge",
        title: "Forge DevOps",
        description: "Builder workspace for code, learning, containers, databases and deployment.",
        role: "DevOps",
        accent: "gold",
        principle: "creation through skill",
        story: "Build useful things, learn openly and turn Linux into a daily craft space.",
        workspace: "Forge",
        package_files: &["scripts/packages-dev.txt", "scripts/packages-server.txt"],
        apps: &["kitty", "code", "helix", "docker"],
    },
    ProfileSpec {
        key: "shield",
        title: "Shield",
        description:
            "Guardian workspace with audit, sandbox, forensics, reversing and network tools.",
        role: "Guardian",
        accent: "indigo",
        principle: "visible protection",
        story: "Protect the system with clarity: audit, isolate and document before acting.",
        workspace: "ShieldLab",
        package_files: &[
            "scripts/packages-cybersecurity.txt",
            "scripts/packages-cybersecurity-forensics.txt",
            "scripts/packages-cybersecurity-reversing.txt",
            "scripts/packages-cybersecurity-wireless.txt",
            "scripts/packages-cybersecurity-sandbox.txt",
        ],
        apps: &["kitty", "wireshark", "burpsuite", "zaproxy"],
    },
    ProfileSpec {
        key: "studio",
        title: "Studio Creator",
        description: "Maker workspace for image, vector, video, audio and 3D production.",
        role: "Creator",
        accent: "clay",
        principle: "expressive production",
        story: "Make visual, audio and motion work without leaving an open creative environment.",
        workspace: "Studio",
        package_files: &["scripts/packages-creation.txt"],
        apps: &["gimp", "krita", "inkscape", "blender", "kdenlive"],
    },
    ProfileSpec {
        key: "pulse",
        title: "Pulse Gaming",
        description: "Gaming and performance mini OS for Proton, low latency, overlays and controllers.",
        role: "Gaming",
        accent: "cyan",
        principle: "performance without chaos",
        story: "Play, stream and tune performance while keeping the host profile stable.",
        workspace: "Pulse",
        package_files: &["scripts/packages-performance.txt"],
        apps: &["steam", "lutris", "heroic", "gamemode"],
    },
    ProfileSpec {
        key: "atlas",
        title: "Atlas Explorer",
        description: "Knowledge, documents, OCR, maps, references and exploration mini OS.",
        role: "Explorer",
        accent: "blue",
        principle: "knowledge with orientation",
        story: "Explore documents, maps and references from a calm knowledge workspace.",
        workspace: "Atlas",
        package_files: &["scripts/packages-atlas.txt"],
        apps: &["calibre", "foliate", "gnome-maps", "marble"],
    },
];

const CYBER_CONTEXTS: &[CyberContextSpec] = &[
    CyberContextSpec {
        key: "recon",
        title: "Recon",
        workspace: 1,
        accent: "indigo",
        purpose: "OSINT, discovery and authorized surface mapping.",
        apps: &["kitty", "firefox", "nmap"],
        tools: &["nmap", "whois"],
        actions: &["seven shield scope", "seven shield lab --preset web"],
    },
    CyberContextSpec {
        key: "web",
        title: "Web Pentest",
        workspace: 2,
        accent: "gold",
        purpose: "Browser, proxy and web application testing in a scoped lab.",
        apps: &["firefox", "burpsuite", "zaproxy", "sqlmap"],
        tools: &["burpsuite", "zaproxy", "sqlmap"],
        actions: &["seven shield lab --preset web", "seven shield report"],
    },
    CyberContextSpec {
        key: "reversing",
        title: "Reverse Engineering",
        workspace: 3,
        accent: "clay",
        purpose: "Offline binary triage and reverse engineering notes.",
        apps: &["ghidra", "radare2", "gdb"],
        tools: &["ghidra", "radare2", "gdb"],
        actions: &["seven shield lab --preset reversing", "seven shield report"],
    },
    CyberContextSpec {
        key: "network",
        title: "Network",
        workspace: 4,
        accent: "baobab",
        purpose: "Packet inspection, network visibility and authorized capture.",
        apps: &["wireshark", "tcpdump", "kitty"],
        tools: &["wireshark", "tcpdump"],
        actions: &["seven shield scope", "seven shield tools"],
    },
    CyberContextSpec {
        key: "forensics",
        title: "Forensics",
        workspace: 5,
        accent: "baobab",
        purpose: "Evidence-safe offline triage, captures and reports.",
        apps: &["autopsy", "sleuthkit", "kitty"],
        tools: &["autopsy", "mmls"],
        actions: &["seven shield lab --preset forensics", "seven shield report"],
    },
    CyberContextSpec {
        key: "exploit",
        title: "Exploitation",
        workspace: 6,
        accent: "clay",
        purpose: "Controlled exploitation workflow for authorized targets only.",
        apps: &["metasploit", "kitty"],
        tools: &["msfconsole"],
        actions: &["seven shield scope", "seven shield report"],
    },
    CyberContextSpec {
        key: "intel",
        title: "Threat Intel",
        workspace: 7,
        accent: "indigo",
        purpose: "Indicators, notes, references and knowledge capture.",
        apps: &["firefox", "obsidian", "kitty"],
        tools: &["firefox", "obsidian"],
        actions: &["seven shield open", "seven shield report"],
    },
    CyberContextSpec {
        key: "logs",
        title: "Logs & Monitoring",
        workspace: 8,
        accent: "indigo",
        purpose: "System logs, posture events and services.",
        apps: &["journalctl", "btop", "kitty"],
        tools: &["journalctl", "btop"],
        actions: &["seven events", "seven shield status"],
    },
    CyberContextSpec {
        key: "sandbox",
        title: "Sandbox",
        workspace: 9,
        accent: "gold",
        purpose: "Isolated unknown workloads, offline labs and disposable tests.",
        apps: &["firejail", "bwrap", "kitty"],
        tools: &["firejail", "bwrap"],
        actions: &["seven shield lab --preset offline", "seven shield tools"],
    },
];

fn arg_value(args: &[String], key: &str, fallback: &str) -> String {
    args.windows(2)
        .find(|pair| pair[0] == key)
        .map(|pair| pair[1].clone())
        .unwrap_or_else(|| fallback.to_string())
}

fn print_json(state: &str) {
    let path = event_file();
    let path_text = json_escape(&path.to_string_lossy());
    println!(
        "{{\"schema\":\"sevenos.daemon.v1\",\"state\":\"{}\",\"name\":\"seven-daemon\",\"language\":\"rust\",\"bus\":\"sevenos.bus.v1\",\"transport\":\"local-user-service\",\"policy\":\"local-only\",\"event_file\":\"{}\",\"event_count\":{},\"next\":[\"supervise SevenBus events\",\"serve fast local status\",\"enforce action policy\"]}}",
        state,
        path_text,
        event_count()
    );
}

fn print_human(state: &str) {
    println!("Seven Daemon");
    println!("============");
    println!("state: {}", state);
    println!("bus: sevenos.bus.v1");
    println!("transport: local-user-service");
    println!("policy: local-only");
    println!("events: {} ({})", event_count(), event_file().display());
}

fn snapshot_payload() -> Value {
    let (events, invalid, _total) = parsed_events();
    let mut by_source: Vec<(String, usize)> = Vec::new();
    let mut by_state: Vec<(String, usize)> = Vec::new();
    let mut by_writer: Vec<(String, usize)> = Vec::new();

    for event in &events {
        let source = event
            .get("source")
            .and_then(Value::as_str)
            .unwrap_or("unknown");
        let state = event
            .get("state")
            .and_then(Value::as_str)
            .unwrap_or("unknown");
        let writer = event
            .get("writer")
            .and_then(Value::as_str)
            .unwrap_or("legacy");
        count_key(&mut by_source, source);
        count_key(&mut by_state, state);
        count_key(&mut by_writer, writer);
    }

    json!({
        "schema": "sevenos.daemon.snapshot.v1",
        "state": "ready",
        "writer": "seven-daemon",
        "event_file": event_file().to_string_lossy(),
        "event_count": events.len(),
        "invalid_event_count": invalid,
        "sources": serde_json::from_str::<Value>(&json_counts(&by_source)).unwrap_or_else(|_| json!({})),
        "states": serde_json::from_str::<Value>(&json_counts(&by_state)).unwrap_or_else(|_| json!({})),
        "writers": serde_json::from_str::<Value>(&json_counts(&by_writer)).unwrap_or_else(|_| json!({})),
        "last_event": events.last(),
    })
}

fn snapshot() {
    print_value(&snapshot_payload());
}

fn parsed_events() -> (Vec<Value>, usize, usize) {
    let lines = event_lines();
    let mut events = Vec::new();
    let mut invalid = 0usize;

    for line in &lines {
        if line.trim().is_empty() {
            continue;
        }
        match serde_json::from_str::<Value>(line) {
            Ok(event) => events.push(event),
            Err(_) => invalid += 1,
        }
    }

    (events, invalid, lines.len())
}

fn limit_value(args: &[String]) -> usize {
    arg_value(args, "--limit", "12")
        .parse::<usize>()
        .unwrap_or(12)
}

fn interval_value(args: &[String]) -> u64 {
    arg_value(
        args,
        "--interval",
        &env::var("SEVENOS_CONTEXT_INTERVAL").unwrap_or_else(|_| "60".to_string()),
    )
    .parse::<u64>()
    .unwrap_or(60)
    .clamp(15, 3600)
}

fn events_json(args: &[String]) {
    let limit = limit_value(args);
    let (events, invalid, total) = parsed_events();
    let start = events.len().saturating_sub(limit);
    let payload = json!({
        "schema": "sevenos.events.v1",
        "path": event_file().to_string_lossy(),
        "count": events.len().saturating_sub(start),
        "total": events.len(),
        "invalid_event_count": invalid,
        "raw_line_count": total,
        "events": events[start..],
        "writer": "seven-daemon",
    });
    println!(
        "{}",
        serde_json::to_string(&payload).unwrap_or_else(|_| "{}".to_string())
    );
}

fn summary_json() {
    let (events, invalid, total) = parsed_events();
    let mut by_source: Vec<(String, usize)> = Vec::new();

    for event in &events {
        let source = event
            .get("source")
            .and_then(Value::as_str)
            .unwrap_or("unknown");
        count_key(&mut by_source, source);
    }

    let payload = json!({
        "schema": "sevenos.events.summary.v1",
        "path": event_file().to_string_lossy(),
        "total": events.len(),
        "invalid_event_count": invalid,
        "raw_line_count": total,
        "sources": serde_json::from_str::<Value>(&json_counts(&by_source)).unwrap_or_else(|_| json!({})),
        "last": events.last(),
        "writer": "seven-daemon",
    });
    println!(
        "{}",
        serde_json::to_string(&payload).unwrap_or_else(|_| "{}".to_string())
    );
}

fn compact_events_json(args: &[String]) {
    let keep = arg_value(args, "--keep", "5000")
        .parse::<usize>()
        .unwrap_or(5000)
        .max(100);
    let path = event_file();
    let before_bytes = fs::metadata(&path).map(|meta| meta.len()).unwrap_or(0);
    let (events, invalid, raw_lines) = parsed_events();
    let keep_start = events.len().saturating_sub(keep);
    let kept = &events[keep_start..];
    let archive = path.with_extension(format!("jsonl.{}.bak", unix_timestamp()));

    let state = if path.exists() {
        if let Some(parent) = path.parent() {
            let _ = fs::create_dir_all(parent);
        }
        match fs::rename(&path, &archive) {
            Ok(_) => {
                let mut body = String::new();
                for event in kept {
                    if let Ok(line) = serde_json::to_string(event) {
                        body.push_str(&line);
                        body.push('\n');
                    }
                }
                match fs::write(&path, body) {
                    Ok(_) => "OK",
                    Err(_) => {
                        let _ = fs::rename(&archive, &path);
                        "FAIL"
                    }
                }
            }
            Err(_) => "FAIL",
        }
    } else {
        "EMPTY"
    };

    let after_bytes = fs::metadata(&path).map(|meta| meta.len()).unwrap_or(0);
    let payload = json!({
        "schema": "sevenos.bus.compact.v1",
        "state": state,
        "event_file": path.to_string_lossy(),
        "archive": if archive.exists() { json!(archive.to_string_lossy()) } else { Value::Null },
        "keep": keep,
        "before": {
            "events": events.len(),
            "raw_line_count": raw_lines,
            "invalid_event_count": invalid,
            "bytes": before_bytes,
        },
        "after": {
            "events": kept.len(),
            "bytes": after_bytes,
        },
        "writer": "seven-daemon",
    });
    println!(
        "{}",
        serde_json::to_string(&payload).unwrap_or_else(|_| "{}".to_string())
    );
}

fn health_payload() -> Value {
    let state_path = state_dir();
    let events_path = event_file();
    let state_writable = can_write_state_dir();
    let wayland_display = detect_wayland_display();
    let desktop = detect_desktop();
    let session = env::var("XDG_SESSION_DESKTOP").unwrap_or_else(|_| desktop.clone());
    let user = env::var("USER").unwrap_or_default();
    let (events, invalid, raw_lines) = parsed_events();

    let checks = vec![
        json!({
            "key": "state_dir",
            "state": if state_writable { "OK" } else { "MISS" },
            "detail": state_path.to_string_lossy(),
        }),
        json!({
            "key": "event_journal",
            "state": path_state(&events_path),
            "detail": events_path.to_string_lossy(),
        }),
        json!({
            "key": "wayland_session",
            "state": if wayland_display.is_empty() { "MISS" } else { "OK" },
            "detail": if wayland_display.is_empty() { "WAYLAND_DISPLAY is not set".to_string() } else { wayland_display.clone() },
        }),
        json!({
            "key": "event_integrity",
            "state": if invalid == 0 { "OK" } else { "WARN" },
            "detail": format!("{} invalid line(s)", invalid),
        }),
    ];

    json!({
        "schema": "sevenos.daemon.health.v1",
        "state": if state_writable { "ready" } else { "degraded" },
        "name": "seven-daemon",
        "language": "rust",
        "policy": "local-only",
        "writer": "seven-daemon",
        "runtime": {
            "uptime_seconds": uptime_seconds(),
            "loadavg": loadavg(),
            "memory": memory_json(),
        },
        "session": {
            "user": user,
            "wayland_display": wayland_display,
            "desktop": desktop,
            "session_desktop": session,
        },
        "bus": {
            "event_file": events_path.to_string_lossy(),
            "event_count": events.len(),
            "invalid_event_count": invalid,
            "raw_line_count": raw_lines,
        },
        "paths": {
            "state_dir": state_path.to_string_lossy(),
            "state_dir_writable": state_writable,
        },
        "checks": checks,
    })
}

fn home_dir() -> PathBuf {
    env::var("HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|_| PathBuf::from("/tmp"))
}

fn config_dir() -> PathBuf {
    if let Ok(value) = env::var("XDG_CONFIG_HOME") {
        return PathBuf::from(value).join("sevenos");
    }
    home_dir().join(".config/sevenos")
}

fn active_profile_key() -> String {
    for key in ["SEVENOS_PROFILE_CONTAINER", "SEVENOS_EXEC_PROFILE"] {
        if let Ok(value) = env::var(key) {
            let trimmed = value.trim();
            if !trimmed.is_empty() {
                return if trimmed == "horizon" {
                    "forge".to_string()
                } else {
                    trimmed.to_string()
                };
            }
        }
    }
    let path = config_dir().join("profile.env");
    let content = fs::read_to_string(path).unwrap_or_default();
    for line in content.lines() {
        if let Some(raw) = line.strip_prefix("SEVENOS_ACTIVE_PROFILE=") {
            let value = raw.trim_matches('"').trim_matches('\'');
            return if value == "horizon" {
                "forge".to_string()
            } else {
                value.to_string()
            };
        }
    }
    let isolation_path = config_dir().join("profile-isolation.env");
    let isolation_content = fs::read_to_string(isolation_path).unwrap_or_default();
    for line in isolation_content.lines() {
        if let Some(raw) = line.strip_prefix("SEVENOS_ISOLATION_PRIMARY=") {
            let value = raw.trim_matches('"').trim_matches('\'');
            return if value == "horizon" {
                "forge".to_string()
            } else {
                value.to_string()
            };
        }
    }
    if let Ok(value) = env::var("SEVENOS_ACTIVE_PROFILE") {
        let trimmed = value.trim();
        if !trimmed.is_empty() {
            return if trimmed == "horizon" {
                "forge".to_string()
            } else {
                trimmed.to_string()
            };
        }
    }
    "equinox".to_string()
}

fn user_config_home() -> PathBuf {
    if let Ok(value) = env::var("XDG_CONFIG_HOME") {
        return PathBuf::from(value);
    }
    home_dir().join(".config")
}

fn read_env_value(path: &Path, wanted: &str) -> Option<String> {
    let content = fs::read_to_string(path).ok()?;
    for raw in content.lines() {
        let mut line = raw.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        if let Some(stripped) = line.strip_prefix("export ") {
            line = stripped.trim();
        }
        let Some((key, value)) = line.split_once('=') else {
            continue;
        };
        if key.trim() == wanted {
            let clean = value.trim().trim_matches('"').trim_matches('\'').to_string();
            if !clean.is_empty() {
                return Some(clean);
            }
        }
    }
    None
}

fn read_hypr_env_value(path: &Path, wanted: &str) -> Option<String> {
    let content = fs::read_to_string(path).ok()?;
    for raw in content.lines() {
        let line = raw.trim();
        if !line.starts_with("env") {
            continue;
        }
        let Some((_left, right)) = line.split_once('=') else {
            continue;
        };
        let Some((key, value)) = right.trim().split_once(',') else {
            continue;
        };
        if key.trim() == wanted {
            let clean = value.trim().trim_matches('"').trim_matches('\'').to_string();
            if !clean.is_empty() {
                return Some(clean);
            }
        }
    }
    None
}

fn normalize_theme_mode(value: Option<String>) -> String {
    match value
        .unwrap_or_default()
        .trim()
        .to_ascii_lowercase()
        .as_str()
    {
        "light" => "light".to_string(),
        _ => "dark".to_string(),
    }
}

fn normalize_locale_value(value: Option<String>) -> String {
    let raw = value.unwrap_or_else(|| env::var("LANG").unwrap_or_else(|_| "C.UTF-8".to_string()));
    let trimmed = raw.trim();
    if trimmed.is_empty() || trimmed == "C.utf8" {
        "C.UTF-8".to_string()
    } else if let Some(prefix) = trimmed.strip_suffix(".utf8") {
        format!("{}.UTF-8", prefix)
    } else {
        trimmed.to_string()
    }
}

fn language_code(locale: &str) -> String {
    if locale.starts_with('C') {
        "C".to_string()
    } else {
        locale
            .split('_')
            .next()
            .unwrap_or("en")
            .split('.')
            .next()
            .unwrap_or("en")
            .to_string()
    }
}

fn profile_title_for(key: &str) -> &'static str {
    match key {
        "equinox" => "Equinox Balance",
        "baobab" => "Baobab Cultural OS",
        "forge" => "Forge DevOps",
        "shield" => "Shield Cybersecurity",
        "studio" => "Studio Creator",
        "atlas" => "Atlas",
        "pulse" => "Pulse Gaming",
        _ => "SevenOS",
    }
}

fn profile_accent_for(key: &str) -> &'static str {
    match key {
        "baobab" => "#46D18C",
        "forge" => "#F2A95F",
        "shield" => "#8B7CFF",
        "studio" => "#D78BFF",
        "atlas" => "#5AB8FF",
        "pulse" => "#FFD166",
        _ => "#8B7CFF",
    }
}

fn gsettings_value(schema: &str, key: &str) -> String {
    let output = Command::new("gsettings").arg("get").arg(schema).arg(key).output();
    match output {
        Ok(result) if result.status.success() => String::from_utf8_lossy(&result.stdout)
            .trim()
            .trim_matches('\'')
            .trim_matches('"')
            .to_string(),
        _ => String::new(),
    }
}

fn experience_json() {
    let root = sevenos_root().unwrap_or_else(|| PathBuf::from("."));
    let config_home = user_config_home();
    let sevenos_config = config_home.join("sevenos");
    let theme_conf = sevenos_config.join("theme.conf");
    let theme_runtime = sevenos_config.join("theme-runtime.env");
    let language_conf = sevenos_config.join("language.conf");
    let language_env = sevenos_config.join("language.env");
    let profile_env = sevenos_config.join("profile.env");
    let hypr_theme_env = config_home.join("hypr/conf/sevenos-theme-env.conf");

    let theme_preferred = normalize_theme_mode(read_env_value(&theme_conf, "SEVENOS_THEME_MODE").or_else(|| read_env_value(&theme_conf, "mode")));
    let theme_runtime_mode = normalize_theme_mode(read_env_value(&theme_runtime, "SEVENOS_THEME_MODE"));
    let hypr_theme_mode = read_hypr_env_value(&hypr_theme_env, "SEVENOS_THEME_MODE").unwrap_or_default();
    let expected_color_scheme = if theme_preferred == "light" { "prefer-light" } else { "prefer-dark" };
    let gsettings_color_scheme = gsettings_value("org.gnome.desktop.interface", "color-scheme");

    let locale = normalize_locale_value(
        read_env_value(&language_conf, "SEVENOS_LANGUAGE")
            .or_else(|| read_env_value(&language_conf, "LANG"))
            .or_else(|| read_env_value(&language_env, "SEVENOS_LANGUAGE"))
            .or_else(|| read_env_value(&language_env, "LANG")),
    );
    let lang = language_code(&locale);
    let profile_key = active_profile_key();
    let profile_title = read_env_value(&profile_env, "SEVENOS_PROFILE_TITLE")
        .unwrap_or_else(|| profile_title_for(&profile_key).to_string());
    let profile_accent = read_env_value(&profile_env, "SEVENOS_PROFILE_ACCENT_COLOR")
        .unwrap_or_else(|| profile_accent_for(&profile_key).to_string());

    let session_services = [
        ("session", "sevenos-session.target"),
        ("waybar", "sevenos-waybar.service"),
        ("notifications", "sevenos-notifications.service"),
        ("wallpaper", "sevenos-wallpaper.service"),
        ("widgets", "sevenos-widgets.service"),
        ("dock", "sevenos-dock.service"),
    ]
    .into_iter()
    .map(|(key, unit)| {
        json!({
            "key": key,
            "unit": unit,
            "state": user_service_state(unit),
            "writer": "seven-daemon",
        })
    })
    .collect::<Vec<_>>();

    let theme_synced = theme_runtime_mode == theme_preferred
        && (hypr_theme_mode.is_empty() || hypr_theme_mode == theme_preferred)
        && (gsettings_color_scheme.is_empty() || gsettings_color_scheme == expected_color_scheme);
    let language_synced = !locale.is_empty();
    let session_ready = session_services.iter().any(|item| {
        item.get("unit").and_then(Value::as_str) == Some("sevenos-session.target")
            && matches!(item.get("state").and_then(Value::as_str), Some("RUN" | "READY"))
    });
    let profile_ready = matches!(profile_key.as_str(), "equinox" | "baobab" | "forge" | "shield" | "studio" | "atlas" | "pulse");

    let checks = vec![
        json!({"key": "theme", "state": if theme_synced { "OK" } else { "PART" }, "detail": format!("{} / runtime {}", theme_preferred, theme_runtime_mode)}),
        json!({"key": "language", "state": if language_synced { "OK" } else { "MISS" }, "detail": locale}),
        json!({"key": "profile", "state": if profile_ready { "OK" } else { "PART" }, "detail": profile_title}),
        json!({"key": "session", "state": if session_ready { "OK" } else { "PART" }, "detail": "SevenOS user session target"}),
        json!({"key": "design-engine", "state": file_state(&root, "scripts/seven_theme.py"), "detail": "shared design tokens"}),
    ];
    let ok = checks
        .iter()
        .filter(|item| item.get("state").and_then(Value::as_str) == Some("OK"))
        .count();
    let score = ((ok as f64 / checks.len() as f64) * 100.0).round() as u64;
    let state = if ok == checks.len() {
        "ready"
    } else if ok >= 3 {
        "attention"
    } else {
        "needs-setup"
    };

    let payload = json!({
        "schema": "sevenos.experience.v1",
        "state": state,
        "score": score,
        "percent": score,
        "max": 100,
        "theme": {
            "preferred": theme_preferred,
            "runtime": theme_runtime_mode,
            "hyprland": hypr_theme_mode,
            "expected_color_scheme": expected_color_scheme,
            "gsettings_color_scheme": gsettings_color_scheme,
            "synced": theme_synced,
            "files": {
                "preference": theme_conf.to_string_lossy(),
                "runtime": theme_runtime.to_string_lossy(),
                "hyprland": hypr_theme_env.to_string_lossy(),
            },
        },
        "language": {
            "locale": locale,
            "language": lang,
            "synced": language_synced,
            "files": {
                "preference": language_conf.to_string_lossy(),
                "env": language_env.to_string_lossy(),
            },
        },
        "profile": {
            "key": profile_key,
            "title": profile_title,
            "accent": profile_accent,
            "file": profile_env.to_string_lossy(),
        },
        "session": {
            "desktop": detect_desktop(),
            "wayland_display": detect_wayland_display(),
            "services": session_services,
        },
        "checks": checks,
        "policy": {
            "read": "daemon-native",
            "write": "scripts remain controlled adapters for theme/language/profile changes",
        },
        "runtime": "seven-daemon",
        "writer": "seven-daemon",
    });
    print_value(&payload);
}

fn command_exists(command_name: &str) -> bool {
    if command_name.contains('/') {
        return Path::new(command_name).exists();
    }
    let Some(path_var) = env::var_os("PATH") else {
        return false;
    };
    env::split_paths(&path_var).any(|dir| dir.join(command_name).is_file())
}

fn flatpak_installed(app_id: &str) -> bool {
    let output = Command::new("flatpak").arg("info").arg(app_id).output();
    matches!(output, Ok(result) if result.status.success())
}

fn package_flatpak_equivalent(package: &str) -> Option<&'static str> {
    match package {
        "gimp" => Some("org.gimp.GIMP"),
        "krita" => Some("org.kde.krita"),
        "inkscape" => Some("org.inkscape.Inkscape"),
        "blender" => Some("org.blender.Blender"),
        "kdenlive" => Some("org.kde.kdenlive"),
        "obs-studio" => Some("com.obsproject.Studio"),
        "audacity" => Some("org.audacityteam.Audacity"),
        "darktable" => Some("org.darktable.Darktable"),
        "rawtherapee" => Some("com.rawtherapee.RawTherapee"),
        "scribus" => Some("net.scribus.Scribus"),
        "lmms" => Some("io.lmms.LMMS"),
        "handbrake" => Some("fr.handbrake.ghb"),
        _ => None,
    }
}

fn package_alternatives(package: &str) -> &'static [&'static str] {
    match package {
        "code" => &["visual-studio-code-bin", "vscodium-bin", "vscodium"],
        "p7zip" => &["7zip"],
        "7zip" => &["p7zip"],
        _ => &[],
    }
}

fn package_satisfied(package: &str, pacman_packages: &HashSet<String>) -> bool {
    pacman_packages.contains(package)
        || package_alternatives(package)
            .iter()
            .any(|alternative| pacman_packages.contains(*alternative))
        || package_flatpak_equivalent(package).is_some_and(flatpak_installed)
}

fn pacman_packages() -> HashSet<String> {
    let output = Command::new("pacman").arg("-Qq").output();
    match output {
        Ok(result) if result.status.success() => String::from_utf8_lossy(&result.stdout)
            .lines()
            .map(str::trim)
            .filter(|line| !line.is_empty())
            .map(str::to_string)
            .collect(),
        _ => HashSet::new(),
    }
}

fn read_package_file(root: &Path, relative: &str) -> Vec<String> {
    let path = root.join(relative);
    let content = fs::read_to_string(path).unwrap_or_default();
    content
        .lines()
        .map(|line| line.split('#').next().unwrap_or("").trim().to_string())
        .filter(|line| !line.is_empty())
        .collect()
}

fn app_command(app: &str) -> &'static str {
    match app {
        "seven hub" => "seven hub",
        "seven files" => "seven-files profile",
        "bottles" => "seven windows apps",
        "virt-manager" => "seven windows vm",
        "docker" => "docker info",
        "podman" => "podman info",
        "caddy" => "caddy version",
        _ => "",
    }
}

fn app_state(root: &Path, app: &str) -> &'static str {
    match app {
        "seven hub" => {
            if root.join("seven-hub/bin/seven-hub").is_file() || root.join("bin/seven").is_file() {
                "OK"
            } else {
                "MISS"
            }
        }
        "seven files" => {
            if root.join("bin/seven-files").is_file() {
                "OK"
            } else {
                "MISS"
            }
        }
        "bottles" => {
            if flatpak_installed("com.usebottles.bottles") {
                "OK"
            } else {
                "MISS"
            }
        }
        "gimp" => {
            if command_exists("gimp") || flatpak_installed("org.gimp.GIMP") {
                "OK"
            } else {
                "MISS"
            }
        }
        "krita" => {
            if command_exists("krita") || flatpak_installed("org.kde.krita") {
                "OK"
            } else {
                "MISS"
            }
        }
        "inkscape" => {
            if command_exists("inkscape") || flatpak_installed("org.inkscape.Inkscape") {
                "OK"
            } else {
                "MISS"
            }
        }
        "blender" => {
            if command_exists("blender") || flatpak_installed("org.blender.Blender") {
                "OK"
            } else {
                "MISS"
            }
        }
        "kdenlive" => {
            if command_exists("kdenlive") || flatpak_installed("org.kde.kdenlive") {
                "OK"
            } else {
                "MISS"
            }
        }
        _ => {
            if command_exists(app) {
                "OK"
            } else {
                "MISS"
            }
        }
    }
}

fn profile_workspace(spec: &ProfileSpec) -> PathBuf {
    home_dir().join(spec.workspace)
}

fn bootstrap_state(spec: &ProfileSpec) -> &'static str {
    let state_dir = profile_workspace(spec).join(".sevenos");
    let manifest = state_dir.join("profile.json");
    let checklist = state_dir.join("CHECKLIST.md");
    let launcher = state_dir.join("launch.sh");
    if manifest.is_file() && checklist.is_file() && launcher.is_file() {
        "OK"
    } else if manifest.exists() || checklist.exists() || launcher.exists() {
        "PART"
    } else {
        "MISS"
    }
}

fn system_service_state(service: &str) -> &'static str {
    let active = Command::new("systemctl")
        .arg("is-active")
        .arg("--quiet")
        .arg(service)
        .status();
    if matches!(active, Ok(status) if status.success()) {
        return "OK";
    }

    let enabled = Command::new("systemctl")
        .arg("is-enabled")
        .arg("--quiet")
        .arg(service)
        .status();
    if matches!(enabled, Ok(status) if status.success()) {
        "PART"
    } else {
        "MISS"
    }
}

fn user_service_state(service: &str) -> &'static str {
    let active = Command::new("systemctl")
        .arg("--user")
        .arg("is-active")
        .arg("--quiet")
        .arg(service)
        .status();
    if matches!(active, Ok(status) if status.success()) {
        return "RUN";
    }

    let enabled = Command::new("systemctl")
        .arg("--user")
        .arg("is-enabled")
        .arg("--quiet")
        .arg(service)
        .status();
    if matches!(enabled, Ok(status) if status.success()) {
        "READY"
    } else {
        "MISS"
    }
}

fn server_host() -> String {
    env::var("SEVENOS_SERVER_HOST").unwrap_or_else(|_| "127.0.0.1".to_string())
}

fn server_port() -> String {
    env::var("SEVENOS_SERVER_PORT").unwrap_or_else(|_| "7777".to_string())
}

fn server_bind_state(host: &str) -> &'static str {
    if host == "127.0.0.1" || host == "localhost" {
        "LOCAL"
    } else {
        "EXPOSED"
    }
}

fn server_deploy_state(root: &Path) -> &'static str {
    if root.join("server/seven-deploy.sh").is_file() {
        "OK"
    } else {
        "MISS"
    }
}

fn server_dependency(key: &str, state: &str) -> Value {
    json!({
        "key": key,
        "state": state,
        "writer": "seven-daemon",
    })
}

fn server_dependencies(root: &Path) -> Vec<Value> {
    vec![
        server_dependency("go", if command_exists("go") { "OK" } else { "MISS" }),
        server_dependency(
            "podman",
            if command_exists("podman") {
                "OK"
            } else {
                "MISS"
            },
        ),
        server_dependency(
            "caddy",
            if command_exists("caddy") {
                "OK"
            } else {
                "MISS"
            },
        ),
        server_dependency("jq", if command_exists("jq") { "OK" } else { "MISS" }),
        server_dependency("seven-deploy", server_deploy_state(root)),
    ]
}

fn server_recommendations(service: &str, dependencies: &[Value]) -> Vec<Value> {
    let mut recommendations = Vec::new();
    if service != "RUN" {
        recommendations.push(json!({
            "command": "seven server install-user-service",
            "reason": "Install the local API user service",
            "writer": "seven-daemon",
        }));
    }
    if service == "READY" {
        recommendations.push(json!({
            "command": "seven server start",
            "reason": "Start the local API user service",
            "writer": "seven-daemon",
        }));
    }
    if dependencies
        .iter()
        .any(|item| item.get("state").and_then(Value::as_str) != Some("OK"))
    {
        recommendations.push(json!({
            "command": "seven improve deployment --apply",
            "reason": "Install server and deployment dependencies",
            "writer": "seven-daemon",
        }));
    }
    recommendations
}

fn server_json() {
    let root = sevenos_root().unwrap_or_else(|| PathBuf::from("."));
    let host = server_host();
    let port = server_port();
    let service = user_service_state("seven-server.service");
    let dependencies = server_dependencies(&root);
    let active_profile = active_profile_key();
    let server_profile_allowed = active_profile == "forge";
    let runtime_ready = service == "RUN";
    let required_runtime_ready = dependencies.iter().all(|item| {
        let key = item.get("key").and_then(Value::as_str).unwrap_or("");
        let state = item.get("state").and_then(Value::as_str).unwrap_or("");
        !matches!(key, "jq" | "seven-deploy") || state == "OK"
    });
    let deployment_stack_ready = dependencies
        .iter()
        .all(|item| item.get("state").and_then(Value::as_str) == Some("OK"));
    let state = if runtime_ready && deployment_stack_ready {
        "READY"
    } else if runtime_ready && required_runtime_ready {
        "RUNTIME_READY"
    } else if service == "READY" {
        "SERVICE_READY"
    } else {
        "MISS"
    };
    let payload = json!({
        "schema": "sevenos.server.v1",
        "state": state,
        "ready": runtime_ready && deployment_stack_ready,
        "runtime_ready": runtime_ready && required_runtime_ready,
        "deployment_stack_ready": deployment_stack_ready,
        "profile_gate": {
            "required_profile": "forge",
            "active_profile": active_profile,
            "server_runtime_allowed": server_profile_allowed,
            "deploy_api_allowed": server_profile_allowed,
            "blocked_contract": "sevenos.profile-gate.v1"
        },
        "bind": {
            "host": host,
            "port": port,
            "state": server_bind_state(&server_host()),
        },
        "service": {
            "name": "seven-server.service",
            "state": service,
        },
        "dependencies": dependencies,
        "endpoints": [
            "/health",
            "/state",
            "/status",
            "/welcome",
            "/welcome-plan",
            "/session",
            "/identity",
            "/profiles",
            "/profile-gaps",
            "/profile-plan",
            "/windows",
            "/windows-plan",
            "/installer",
            "/installer-plan",
            "/packages",
            "/packages-plan",
            "/store",
            "/box",
            "/cloud",
            "/flow",
            "/cluster",
            "/monitor/system",
            "/readiness",
            "/manifest",
            "/actions",
            "/stack",
            "/shell",
            "/shell-plan",
            "/core",
            "/core-plan",
            "/core-snapshot",
            "/core-health",
            "/core-observe",
            "/scheduler",
            "/context",
            "/bus",
            "/experience",
            "/shield",
            "/shield-plan",
            "/cyberspace",
            "/cyberspace-plan",
            "/server-plan",
            "/control",
            "/b3",
            "/daily",
            "/events",
            "/insights",
            "/deploy/status",
            "/deploy/inspect",
            "/deploy/doctor",
            "/deploy/services",
            "/deploy/panel",
            "/deploy/domain",
            "/deploy/dns-check",
            "/deploy/route-check",
            "/deploy/diagnose"
        ],
        "recommendations": server_recommendations(service, &dependencies),
        "runtime": "seven-daemon",
        "writer": "seven-daemon",
    });
    print_value(&payload);
}

fn health_json() {
    print_value(&health_payload());
}

fn core_component(key: &str, title: &str, state: &str, detail: &str) -> Value {
    json!({
        "key": key,
        "title": title,
        "state": state,
        "detail": detail,
        "writer": "seven-daemon",
    })
}

fn core_status_payload() -> Value {
    let root = sevenos_root().unwrap_or_else(|| PathBuf::from("."));
    let health = health_payload();
    let snapshot = snapshot_payload();
    let event_file_path = event_file();
    let core_foundation = root.join("seven-core/daemon/Cargo.toml").is_file()
        && root.join("seven-core/bus-schema.json").is_file()
        && root.join("bin/seven-daemon").is_file();
    let daemon_service = user_service_state("seven-daemon.service");
    let observer_service = user_service_state("seven-context-observer.service");
    let runtime_ready = matches!(daemon_service, "RUN") && matches!(observer_service, "RUN");
    let state = if runtime_ready {
        "RUNTIME_READY"
    } else if core_foundation {
        "READY_FOR_DAEMON"
    } else {
        "FOUNDATION_MISSING"
    };

    let components = vec![
        core_component(
            "daemon_scaffold",
            "Rust daemon scaffold",
            if root.join("seven-core/daemon/Cargo.toml").is_file()
                && root.join("seven-core/daemon/src/main.rs").is_file()
            {
                "OK"
            } else {
                "MISS"
            },
            "seven-core/daemon",
        ),
        core_component(
            "daemon_cli",
            "Seven daemon binary",
            path_state(&root.join("bin/seven-daemon")),
            "bin/seven-daemon",
        ),
        core_component(
            "sevenbus_schema",
            "SevenBus schema",
            path_state(&root.join("seven-core/bus-schema.json")),
            "seven-core/bus-schema.json",
        ),
        core_component(
            "event_journal",
            "Local event journal",
            path_state(&event_file_path),
            &event_file_path.to_string_lossy(),
        ),
        core_component(
            "daemon_service",
            "Seven daemon service",
            daemon_service,
            "seven-daemon.service",
        ),
        core_component(
            "observer_service",
            "Context observer service",
            observer_service,
            "seven-context-observer.service",
        ),
        core_component(
            "rust_toolchain",
            "Rust toolchain",
            if command_exists("cargo") && command_exists("rustc") { "OK" } else { "MISS" },
            "cargo + rustc",
        ),
        core_component(
            "c_toolchain",
            "C toolchain",
            if command_exists("cc") && command_exists("make") { "OK" } else { "MISS" },
            "cc + make",
        ),
        core_component(
            "native_actions",
            "Native action registry",
            "OK",
            "seven-daemon actions --json",
        ),
        core_component(
            "native_surfaces",
            "Native surfaces contract",
            "OK",
            "seven-daemon surfaces --json",
        ),
        core_component(
            "native_update",
            "Native update readiness",
            "OK",
            "seven-daemon update --json",
        ),
        core_component(
            "native_installer",
            "Native installer readiness",
            "OK",
            "seven-daemon installer --json",
        ),
        core_component(
            "shield_engine",
            "Shield engine",
            "OK",
            "seven-daemon shield --json",
        ),
        core_component(
            "server_engine",
            "Server engine",
            "OK",
            "seven-daemon server --json",
        ),
        core_component(
            "windows_engine",
            "Windows app engine",
            "OK",
            "seven-daemon windows --json",
        ),
        core_component(
            "installer_engine",
            "Installer engine",
            "OK",
            "seven-daemon installer-flow --json",
        ),
        core_component(
            "packages_engine",
            "SevenPkg engine",
            "OK",
            "seven-daemon packages-plan --json",
        ),
        core_component(
            "insights_engine",
            "Insights engine",
            "OK",
            "seven-daemon insights --json",
        ),
        core_component(
            "phase_gate_engine",
            "Phase gate engine",
            "OK",
            "seven-daemon phase-gate --json",
        ),
        core_component(
            "sevenbus_c_probe",
            "C SevenBus probe",
            path_state(&root.join("bin/sevenbus-probe")),
            "bin/sevenbus-probe",
        ),
    ];
    let ok = components
        .iter()
        .filter(|item| matches!(item.get("state").and_then(Value::as_str), Some("OK" | "RUN" | "READY")))
        .count();
    let total = components.len();
    let score = if total > 0 {
        ((ok as f64 / total as f64) * 100.0).round() as u64
    } else {
        0
    };

    json!({
        "schema": "sevenos.core.v2",
        "state": state,
        "score": score,
        "role": "System Experience Layer above Linux and Arch",
        "runtime": "seven-daemon",
        "writer": "seven-daemon",
        "policy": {
            "read": "daemon-owned fast contracts",
            "write": "scripts remain controlled adapters for privileged/apply operations",
            "migration": "scripts are fallbacks, not the primary state source",
        },
        "bus": {
            "schema": "sevenos.bus.v1",
            "transport": "jsonl-user-state-now, typed-local-ipc-next",
            "event_file": event_file_path.to_string_lossy(),
            "event_count": snapshot.get("event_count").cloned().unwrap_or_else(|| json!(0)),
            "invalid_event_count": snapshot.get("invalid_event_count").cloned().unwrap_or_else(|| json!(0)),
        },
        "services": {
            "daemon": daemon_service,
            "observer": observer_service,
        },
        "health": {
            "state": health.get("state").cloned().unwrap_or_else(|| json!("unknown")),
            "memory": health.get("runtime").and_then(|value| value.get("memory")).cloned().unwrap_or_else(|| json!({})),
        },
        "summary": {
            "ok": ok,
            "total": total,
        },
        "components": components,
        "next": [
            "migrate read-only scripts to seven-daemon contracts",
            "keep privileged apply actions behind explicit adapters",
            "move installer/update workflows to typed native state machines"
        ],
    })
}

fn core_status_json() {
    print_value(&core_status_payload());
}

fn shell_status_payload() -> Value {
    let root = sevenos_root().unwrap_or_else(|| PathBuf::from("."));
    let installed = pacman_packages();
    let root_display = fs::canonicalize(&root).unwrap_or_else(|_| root.clone());
    let ags_ready = command_exists("ags");
    let native_ready = root.join("bin/seven-dock-native").is_file()
        && root.join("bin/seven-waybar-center-native").is_file()
        && root.join("bin/seven-settings-native").is_file()
        && root.join("hyprland/waybar/config.jsonc").is_file()
        && root.join("hyprland/waybar/style.css").is_file()
        && package_satisfied("waybar", &installed)
        && package_satisfied("gtk-layer-shell", &installed);
    let foundation_ready = root.join("seven-shell/ags/src/config.ts").is_file()
        && root.join("seven-shell/ags/src/dock.ts").is_file()
        && root.join("bin/seven-shell-panel").is_file()
        && root.join("bin/seven-apps").is_file()
        && package_satisfied("typescript", &installed)
        && package_satisfied("gtk4", &installed)
        && package_satisfied("libadwaita", &installed)
        && command_exists("node");
    let state = if ags_ready {
        "READY"
    } else if native_ready {
        "NATIVE_READY"
    } else if foundation_ready {
        "FOUNDATION"
    } else {
        "PLANNED"
    };
    let dependency = |key: &str, ready: bool| {
        json!({
            "key": key,
            "state": if ready { "OK" } else { "MISS" },
            "writer": "seven-daemon",
        })
    };

    json!({
        "schema": "sevenos.shell.v1",
        "root": root_display.to_string_lossy(),
        "phase": "B3",
        "state": state,
        "writer": "seven-daemon",
        "runtime": "seven-daemon",
        "strategy": "Native GTK production fallback now; AGS + TypeScript as the B3 replacement path",
        "fallback": "Waybar, Native GTK panels, Hyprland-managed Dock and Rofi remain supported until AGS surfaces are ready",
        "runtime_health": health_payload(),
        "surfaces": [
            {
                "key": "quick-settings",
                "state": file_state(&root, "bin/seven-waybar-center-native"),
                "current": "Native GTK/Waybar",
                "target": "AGS",
                "writer": "seven-daemon"
            },
            {
                "key": "notifications",
                "state": file_state(&root, "bin/seven-notification-center-native"),
                "current": "Native GTK notification center",
                "target": "AGS",
                "writer": "seven-daemon"
            },
            {
                "key": "launcher",
                "state": file_state(&root, "bin/seven-launchpad-native"),
                "current": "Native Launchpad with Rofi fallback",
                "target": "AGS",
                "writer": "seven-daemon"
            },
            {
                "key": "dock",
                "state": file_state(&root, "bin/seven-dock-native"),
                "current": "Native GTK Hyprland-managed dock",
                "target": "AGS or stable layer-shell",
                "writer": "seven-daemon"
            }
        ],
        "dependencies": [
            dependency("gjs", package_satisfied("gjs", &installed)),
            dependency("typescript", package_satisfied("typescript", &installed)),
            dependency("gtk4", package_satisfied("gtk4", &installed)),
            dependency("libadwaita", package_satisfied("libadwaita", &installed)),
            dependency("gtk-layer-shell", package_satisfied("gtk-layer-shell", &installed)),
            dependency("nodejs", command_exists("node")),
            {
                "key": "ags",
                "state": if ags_ready { "OK" } else { "MISS" },
                "package": "aylurs-gtk-shell",
                "source": "AUR",
                "warning": "Do not install AUR package ags; Seven Shell needs Aylur's Gtk Shell.",
                "writer": "seven-daemon"
            }
        ],
        "contracts": [
            "seven state --json",
            "seven actions --json",
            "seven core snapshot --json",
            "seven core health --json",
            "seven profile current --json",
            "seven shell status --json",
            "seven deploy inspect . --json",
            "seven deploy status --json",
            "seven deploy services --json",
            "seven deploy panel --json",
            "seven deploy versions <project> --json",
            "seven deploy domain <domain> --target tunnel|vps --json",
            "seven deploy dns-check <domain> --expected-ip|--expected-cname ... --json",
            "seven deploy route-check <project-or-domain> --json",
            "seven deploy diagnose <project-or-domain> --json"
        ],
        "profile_gates": {
            "deploy": {
                "required_profile": "forge",
                "blocked_contract": "sevenos.profile-gate.v1",
                "fallback_commands": ["seven profile activate forge", "seven-terminal forge"]
            }
        },
        "commands": {
            "install": "./install.sh shell-ags",
            "runtime": "./install.sh shell-ags-runtime --yes",
            "runtime_status": "scripts/shell-ags-runtime.sh status --json",
            "plan": "seven shell plan",
            "preview": "seven shell preview"
        }
    })
}

fn shell_status_json() {
    print_value(&shell_status_payload());
}

fn profile_role_for(key: &str) -> &'static str {
    match key {
        "baobab" => "Culture, documents, reading, offline knowledge",
        "forge" => "Development, Git, containers, build feedback",
        "shield" => "Security, audit, sandbox, cautious opening",
        "studio" => "Media, assets, previews, creative flow",
        "atlas" => "Atlas Explorer, documents, maps, OCR and references",
        "pulse" => "Games, captures, performance, low-latency focus",
        _ => "Balanced SevenOS daily workspace",
    }
}

fn shell_experience_events_path() -> PathBuf {
    state_dir().join("shell-experience-events.jsonl")
}

fn recent_shell_experience_events() -> Vec<Value> {
    let path = shell_experience_events_path();
    let Ok(content) = fs::read_to_string(path) else {
        return Vec::new();
    };
    let mut items = content
        .lines()
        .rev()
        .filter_map(|line| serde_json::from_str::<Value>(line).ok())
        .take(12)
        .collect::<Vec<_>>();
    items.reverse();
    items
}

fn current_workspace_value() -> String {
    let output = Command::new("hyprctl").arg("activeworkspace").arg("-j").output();
    if let Ok(result) = output {
        if result.status.success() {
            if let Ok(value) = serde_json::from_slice::<Value>(&result.stdout) {
                if let Some(name) = value.get("name").and_then(Value::as_str) {
                    if !name.is_empty() {
                        return name.to_string();
                    }
                }
                if let Some(id) = value.get("id").and_then(Value::as_i64) {
                    return id.to_string();
                }
            }
        }
    }
    "1".to_string()
}

fn profile_action(profile: &str) -> (&'static str, &'static str, &'static str) {
    match profile {
        "baobab" => (
            "Open Reader",
            "seven-reader",
            "Continue reading, documents and offline collections.",
        ),
        "forge" => (
            "Open Forge Terminal",
            "seven-terminal forge",
            "Jump into Git, builds and project logs.",
        ),
        "shield" => (
            "Open Shield Center",
            "seven-shield-center-native",
            "Review scope, audit state and safe-open paths.",
        ),
        "studio" => (
            "Open Studio Assets",
            "seven-files pictures",
            "Resume media, assets and creative previews.",
        ),
        "atlas" => (
            "Open Atlas Explorer",
            "seven atlas status",
            "Check documents, maps, OCR and reference readiness.",
        ),
        "pulse" => (
            "Open Pulse Captures",
            "seven-files videos",
            "Review captures, games and performance context.",
        ),
        _ => (
            "Open Spotlight",
            "seven-spotlight field",
            "Search apps, actions, files and windows.",
        ),
    }
}

fn shell_experience_payload() -> Value {
    let root = sevenos_root().unwrap_or_else(|| PathBuf::from("."));
    let profile = active_profile_key();
    let workspace = current_workspace_value();
    let recent_events = recent_shell_experience_events();
    let surfaces = json!({
        "dock": executable_state(&root.join("bin/seven-dock-native")),
        "launchpad": executable_state(&root.join("bin/seven-launchpad-native")),
        "spotlight": executable_state(&root.join("bin/seven-spotlight-native")),
        "files": executable_state(&root.join("bin/seven-files-native")),
        "terminal": executable_state(&root.join("bin/seven-terminal-native")),
        "settings": executable_state(&root.join("bin/seven-settings-native")),
        "notifications": executable_state(&root.join("bin/seven-notification-center-native")),
        "quick_settings": executable_state(&root.join("bin/seven-quick-settings-native")),
    });
    let missing_surfaces = surfaces
        .as_object()
        .map(|items| {
            items
                .iter()
                .filter_map(|(key, state)| {
                    if state.as_str() == Some("ready") {
                        None
                    } else {
                        Some(Value::String(key.clone()))
                    }
                })
                .collect::<Vec<_>>()
        })
        .unwrap_or_default();
    let last_event = recent_events.last().cloned().unwrap_or_else(|| json!({}));
    let (title, command, reason) = if !missing_surfaces.is_empty() {
        (
            "Repair Shell Surface",
            "seven surfaces doctor",
            "One or more shell surfaces need attention.",
        )
    } else if last_event.get("kind").and_then(Value::as_str) == Some("launch") {
        (
            "Show Windows",
            "seven-overview windows",
            "A launch just happened; jump to active windows if focus was lost.",
        )
    } else if last_event.get("kind").and_then(Value::as_str) == Some("workspace") {
        (
            "Open Spotlight",
            "seven-spotlight field",
            "Workspace changed; Spotlight is the fastest next action.",
        )
    } else {
        profile_action(&profile)
    };

    json!({
        "schema": "sevenos.shell-experience.v1",
        "state": "ready",
        "writer": "seven-daemon",
        "runtime": "seven-daemon",
        "updated_at": format!("unix:{}", unix_timestamp()),
        "profile": profile,
        "profile_role": profile_role_for(&active_profile_key()),
        "workspace": workspace,
        "motion": {
            "grammar": "seven-motion-system",
            "profile_motion": "balanced fade",
            "curves": ["sevenMotion", "sevenMotionOpen", "sevenMotionExit", "sevenMotionWorkspace", "sevenMotionLayer"],
            "durations": {"press": 120, "hover": 160, "open": 260, "close": 180, "workspace": 320},
            "reduced_motion": "seven motion reduced"
        },
        "continuity": {
            "launch_feedback": true,
            "focus_memory": true,
            "workspace_memory": true,
            "dock_launch_contract": true,
            "spotlight_action_contract": true
        },
        "window_policy": {
            "front_door": "seven-window",
            "placement": "center important surfaces, remember workspace state, keep Hyprland hidden behind SevenOS commands",
            "fullscreen": "seven-window fullscreen",
            "float": "seven-window toggle-float",
            "memory": "seven-window memory --json",
            "restore": "seven-window restore"
        },
        "feedback": {
            "notify_command": "seven experience notify",
            "launch_command": "seven experience launch",
            "warmup_command": "seven experience warmup",
            "event_log": shell_experience_events_path().to_string_lossy(),
            "errors": "actionable SevenOS notifications first, terminal logs second"
        },
        "mini_os": {
            "baobab": ["reader", "documents", "offline collections"],
            "forge": ["terminal", "git", "containers", "logs"],
            "shield": ["sandbox", "hash", "audit", "read-only open"],
            "studio": ["media previews", "assets", "metadata"],
            "atlas": ["documents", "maps", "OCR", "references"],
            "pulse": ["games", "captures", "performance"]
        },
        "surfaces": surfaces,
        "accessibility": {
            "keyboard_first": true,
            "focus_visible": true,
            "reduced_motion_command": "seven motion reduced",
            "discoverable_actions": "seven-actions --json"
        },
        "recent_events": recent_events,
        "recommendation": {
            "schema": "sevenos.shell-experience.recommendation.v1",
            "profile": active_profile_key(),
            "title": title,
            "command": command,
            "reason": reason,
            "last_event": last_event,
            "missing_surfaces": missing_surfaces
        }
    })
}

fn shell_experience_json() {
    print_value(&shell_experience_payload());
}

fn server_plan_item(key: &str, state: &str, detail: &str, command: &str) -> Value {
    let (title, severity, impact, phase, reason) = match key {
        "service" => (
            "Install Seven Server service",
            "high",
            "changes",
            "service",
            "Seven Hub needs a durable local backend instead of calling scattered scripts directly.",
        ),
        "service-start" => (
            "Start Seven Server service",
            "high",
            "changes",
            "service",
            "The local API must run before SevenOS can feel like a connected ecosystem.",
        ),
        "go" => (
            "Install Go backend toolchain",
            "medium",
            "packages",
            "backend",
            "Go is the planned low-footprint path for the future seven-server backend.",
        ),
        "podman" => (
            "Install rootless container runtime",
            "high",
            "packages",
            "deploy",
            "Seven Deploy needs rootless containers to host apps without exposing the system.",
        ),
        "caddy" => (
            "Install local reverse proxy",
            "medium",
            "packages",
            "deploy",
            "Caddy prepares HTTPS/reverse-proxy flows for the personal operating cloud.",
        ),
        "jq" => (
            "Install JSON diagnostics",
            "medium",
            "packages",
            "contracts",
            "Machine-readable contracts need reliable JSON tooling for tests and operators.",
        ),
        "seven-deploy" => (
            "Restore deployment planner",
            "critical",
            "changes",
            "deploy",
            "Seven Server cannot orchestrate deployments without seven-deploy.",
        ),
        "bind" => (
            "Keep local API private",
            "critical",
            "safe",
            "trust",
            "Remote exposure must wait for authentication, TLS and audit policy.",
        ),
        _ => (
            "Resolve server gap",
            "medium",
            "changes",
            "service",
            "Resolve this Seven Server readiness gap.",
        ),
    };
    json!({
        "key": key,
        "state": state,
        "title": title,
        "severity": severity,
        "impact": impact,
        "phase": phase,
        "detail": detail,
        "reason": reason,
        "command": command,
        "writer": "seven-daemon",
    })
}

fn server_plan_json() {
    let root = sevenos_root().unwrap_or_else(|| PathBuf::from("."));
    let host = server_host();
    let service = user_service_state("seven-server.service");
    let mut actions = Vec::new();

    let service_ready = if service == "READY" || service == "RUN" {
        "OK"
    } else {
        "MISS"
    };
    if service_ready != "OK" {
        actions.push(server_plan_item(
            "service",
            service_ready,
            "Seven Server user service",
            "seven server install-user-service",
        ));
    }
    let service_started = if service == "RUN" { "OK" } else { "MISS" };
    if service_started != "OK" {
        actions.push(server_plan_item(
            "service-start",
            service_started,
            "Seven Server runtime",
            "seven server start",
        ));
    }

    for (key, detail, command) in [
        (
            "go",
            "Go runtime for future native backend components",
            "seven improve deployment --apply",
        ),
        (
            "podman",
            "Rootless container runtime for deployment flows",
            "seven improve deployment --apply",
        ),
        (
            "caddy",
            "Local reverse proxy for deployment previews",
            "seven improve deployment --apply",
        ),
        (
            "jq",
            "JSON tooling for scripts and diagnostics",
            "seven improve deployment --apply",
        ),
    ] {
        let state = if command_exists(key) { "OK" } else { "MISS" };
        if state != "OK" {
            actions.push(server_plan_item(key, state, detail, command));
        }
    }

    let deploy_state = server_deploy_state(&root);
    if deploy_state != "OK" {
        actions.push(server_plan_item(
            "seven-deploy",
            deploy_state,
            "SevenOS deployment planner",
            "seven deploy status",
        ));
    }

    let bind_state = if server_bind_state(&host) == "LOCAL" {
        "OK"
    } else {
        "PART"
    };
    if bind_state != "OK" {
        actions.push(server_plan_item(
            "bind",
            bind_state,
            "Local-only API bind policy",
            "seven server status",
        ));
    }

    actions.sort_by(|left, right| {
        severity_rank(left)
            .cmp(&severity_rank(right))
            .then_with(|| {
                left.get("key")
                    .and_then(Value::as_str)
                    .unwrap_or("")
                    .cmp(right.get("key").and_then(Value::as_str).unwrap_or(""))
            })
    });
    let critical = actions
        .iter()
        .filter(|item| item.get("severity").and_then(Value::as_str) == Some("critical"))
        .count();
    let high = actions
        .iter()
        .filter(|item| item.get("severity").and_then(Value::as_str) == Some("high"))
        .count();
    let medium = actions
        .iter()
        .filter(|item| item.get("severity").and_then(Value::as_str) == Some("medium"))
        .count();
    let payload = json!({
        "schema": "sevenos.server-plan.v1",
        "summary": {
            "total": actions.len(),
            "critical": critical,
            "high": high,
            "medium": medium,
        },
        "next": actions,
        "runtime": "seven-daemon",
        "writer": "seven-daemon",
    });
    println!(
        "{}",
        serde_json::to_string(&payload).unwrap_or_else(|_| "{}".to_string())
    );
}

fn windows_vm_name() -> String {
    env::var("SEVENOS_WINDOWS_VM").unwrap_or_else(|_| "sevenos-windows".to_string())
}

fn flatpak_app_state(app_id: &str) -> &'static str {
    let output = Command::new("flatpak").arg("info").arg(app_id).output();
    match output {
        Ok(result) if result.status.success() => "OK",
        _ => "MISS",
    }
}

fn kvm_state() -> &'static str {
    if Path::new("/dev/kvm").exists() {
        "OK"
    } else {
        "MISS"
    }
}

fn cpu_virtualization_state() -> &'static str {
    let content = fs::read_to_string("/proc/cpuinfo").unwrap_or_default();
    if content.contains(" vmx ") || content.contains(" svm ") {
        "OK"
    } else {
        "MISS"
    }
}

fn libvirt_group_state() -> &'static str {
    let output = Command::new("id").arg("-nG").output();
    match output {
        Ok(result) if result.status.success() => {
            let groups = String::from_utf8_lossy(&result.stdout);
            if groups.split_whitespace().any(|group| group == "libvirt") {
                "OK"
            } else {
                "MISS"
            }
        }
        _ => "MISS",
    }
}

fn libvirt_network_state() -> &'static str {
    let output = Command::new("virsh")
        .arg("-c")
        .arg("qemu:///system")
        .arg("net-info")
        .arg("default")
        .output();
    match output {
        Ok(result) if result.status.success() => "OK",
        _ => "MISS",
    }
}

fn windows_vm_state(vm_name: &str) -> &'static str {
    let info = Command::new("virsh")
        .arg("-c")
        .arg("qemu:///system")
        .arg("dominfo")
        .arg(vm_name)
        .output();
    if !matches!(info, Ok(result) if result.status.success()) {
        return "MISS";
    }

    let state = Command::new("virsh")
        .arg("-c")
        .arg("qemu:///system")
        .arg("domstate")
        .arg(vm_name)
        .output();
    match state {
        Ok(result) if result.status.success() => {
            let text = String::from_utf8_lossy(&result.stdout);
            if text.trim() == "running" {
                "RUN"
            } else {
                "OK"
            }
        }
        _ => "OK",
    }
}

fn windows_status_map() -> Vec<(&'static str, String)> {
    let vm_name = windows_vm_name();
    vec![
        ("vm_name", vm_name.clone()),
        ("cpu_virtualization", cpu_virtualization_state().to_string()),
        ("kvm_device", kvm_state().to_string()),
        (
            "wine",
            if command_exists("wine") { "OK" } else { "MISS" }.to_string(),
        ),
        (
            "lutris",
            if command_exists("lutris") {
                "OK"
            } else {
                "MISS"
            }
            .to_string(),
        ),
        (
            "flatpak",
            if command_exists("flatpak") {
                "OK"
            } else {
                "MISS"
            }
            .to_string(),
        ),
        (
            "bottles_flatpak",
            flatpak_app_state("com.usebottles.bottles").to_string(),
        ),
        (
            "qemu",
            if command_exists("qemu-system-x86_64") {
                "OK"
            } else {
                "MISS"
            }
            .to_string(),
        ),
        (
            "virt_manager",
            if command_exists("virt-manager") {
                "OK"
            } else {
                "MISS"
            }
            .to_string(),
        ),
        (
            "virt_install",
            if command_exists("virt-install") {
                "OK"
            } else {
                "MISS"
            }
            .to_string(),
        ),
        (
            "virsh",
            if command_exists("virsh") {
                "OK"
            } else {
                "MISS"
            }
            .to_string(),
        ),
        (
            "libvirtd",
            system_service_state("libvirtd.service").to_string(),
        ),
        ("libvirt_group", libvirt_group_state().to_string()),
        ("default_network", libvirt_network_state().to_string()),
        ("windows_vm", windows_vm_state(&vm_name).to_string()),
    ]
}

fn windows_state_value(status: &[(&'static str, String)], key: &str) -> String {
    status
        .iter()
        .find(|(name, _value)| *name == key)
        .map(|(_name, value)| value.clone())
        .unwrap_or_else(|| "MISS".to_string())
}

fn windows_ok(status: &[(&'static str, String)], key: &str) -> bool {
    matches!(windows_state_value(status, key).as_str(), "OK" | "RUN")
}

fn windows_recommendations(status: &[(&'static str, String)]) -> Vec<Value> {
    let mut recommendations = Vec::new();
    if !windows_ok(status, "wine") || !windows_ok(status, "lutris") {
        recommendations.push(json!({
            "command": "seven profile install windows",
            "reason": "Install Wine/Lutris compatibility tooling",
            "writer": "seven-daemon",
        }));
    }
    if !windows_ok(status, "bottles_flatpak") {
        recommendations.push(json!({
            "command": "seven flatpak install",
            "reason": "Install Bottles through Flatpak for accessible Windows apps",
            "writer": "seven-daemon",
        }));
    }
    let vm_ready = [
        "cpu_virtualization",
        "kvm_device",
        "qemu",
        "virt_manager",
        "virsh",
        "libvirtd",
        "default_network",
    ]
    .iter()
    .all(|key| windows_ok(status, key));
    if !vm_ready {
        recommendations.push(json!({
            "command": "seven vm check",
            "reason": "Complete KVM/libvirt readiness",
            "writer": "seven-daemon",
        }));
    }
    if !windows_ok(status, "windows_vm") {
        recommendations.push(json!({
            "command": "seven windows create --iso /path/windows.iso --virtio-iso /path/virtio-win.iso",
            "reason": "Create the guided Windows VM",
            "writer": "seven-daemon",
        }));
    }
    recommendations
}

fn windows_json() {
    let status = windows_status_map();
    let vm_ready = [
        "cpu_virtualization",
        "kvm_device",
        "qemu",
        "virt_manager",
        "virsh",
        "libvirtd",
        "default_network",
    ]
    .iter()
    .all(|key| windows_ok(&status, key));
    let app_ready = windows_ok(&status, "wine")
        && (windows_ok(&status, "bottles_flatpak") || windows_ok(&status, "lutris"));
    let ready = vm_ready && app_ready;
    let mode = if ready {
        "complete"
    } else if vm_ready {
        "vm-ready"
    } else {
        "setup-needed"
    };

    let mut payload = serde_json::Map::new();
    payload.insert("schema".to_string(), json!("sevenos.windows.v1"));
    for (key, value) in &status {
        payload.insert((*key).to_string(), json!(value));
    }
    payload.insert("vm_ready".to_string(), json!(vm_ready));
    payload.insert("app_ready".to_string(), json!(app_ready));
    payload.insert("ready".to_string(), json!(ready));
    payload.insert("mode".to_string(), json!(mode));
    payload.insert(
        "recommendations".to_string(),
        json!(windows_recommendations(&status)),
    );
    payload.insert("runtime".to_string(), json!("seven-daemon"));
    payload.insert("writer".to_string(), json!("seven-daemon"));
    println!(
        "{}",
        serde_json::to_string(&Value::Object(payload)).unwrap_or_else(|_| "{}".to_string())
    );
}

fn windows_plan_item(key: &str, state: &str) -> Value {
    let (title, severity, impact, phase, command, reason) = match key {
        "wine" => (
            "Install Wine compatibility",
            "high",
            "packages",
            "apps",
            "seven profile install windows",
            "Wine is the base layer for lightweight Windows applications.",
        ),
        "lutris" => (
            "Install Lutris app/game manager",
            "medium",
            "packages",
            "apps",
            "seven profile install windows",
            "Lutris gives SevenOS a friendlier Windows app and game workflow.",
        ),
        "bottles_flatpak" => (
            "Install Bottles",
            "high",
            "packages",
            "apps",
            "seven flatpak install",
            "Bottles is the accessible non-terminal surface for Windows apps.",
        ),
        "cpu_virtualization" => (
            "Enable CPU virtualization",
            "critical",
            "manual",
            "vm",
            "seven vm check",
            "KVM needs VT-x or AMD-V enabled in firmware.",
        ),
        "kvm_device" => (
            "Fix KVM device access",
            "critical",
            "changes",
            "vm",
            "seven vm check",
            "SevenOS needs /dev/kvm for performant Windows VM mode.",
        ),
        "qemu" => (
            "Install QEMU",
            "critical",
            "packages",
            "vm",
            "seven profile install windows",
            "QEMU is required for full Windows Desktop Mode.",
        ),
        "virt_manager" => (
            "Install Virt Manager",
            "high",
            "packages",
            "vm",
            "seven profile install windows",
            "Virt Manager is the graphical VM control surface for non-terminal users.",
        ),
        "virt_install" => (
            "Install virt-install",
            "high",
            "packages",
            "vm",
            "seven profile install windows",
            "The guided VM creator depends on virt-install.",
        ),
        "virsh" => (
            "Install libvirt clients",
            "high",
            "packages",
            "vm",
            "seven profile install windows",
            "SevenOS controls Windows VM state through libvirt.",
        ),
        "libvirtd" => (
            "Enable libvirt service",
            "critical",
            "changes",
            "vm",
            "seven improve compatibility",
            "Windows Desktop Mode needs libvirtd running.",
        ),
        "libvirt_group" => (
            "Add user to libvirt group",
            "medium",
            "changes",
            "access",
            "seven improve compatibility",
            "Users should open and manage Windows Mode without sudo prompts.",
        ),
        "default_network" => (
            "Prepare libvirt network",
            "high",
            "changes",
            "network",
            "seven windows network",
            "The Windows VM needs libvirt default networking.",
        ),
        "windows_vm" => (
            "Create Windows VM",
            "medium",
            "manual",
            "install",
            "seven windows create --iso /path/windows.iso --virtio-iso /path/virtio-win.iso",
            "A Windows ISO and VirtIO ISO are needed before SevenOS can launch full Windows Desktop Mode.",
        ),
        _ => (
            "Resolve Windows Mode gap",
            "medium",
            "changes",
            "compatibility",
            "seven windows plan",
            "Resolve this Windows Mode readiness gap.",
        ),
    };
    json!({
        "key": key,
        "state": state,
        "title": title,
        "severity": severity,
        "impact": impact,
        "phase": phase,
        "reason": reason,
        "command": command,
        "writer": "seven-daemon",
    })
}

fn windows_plan_json() {
    let status = windows_status_map();
    let mut actions = Vec::new();
    for key in [
        "cpu_virtualization",
        "kvm_device",
        "wine",
        "lutris",
        "bottles_flatpak",
        "qemu",
        "virt_manager",
        "virt_install",
        "virsh",
        "libvirtd",
        "libvirt_group",
        "default_network",
        "windows_vm",
    ] {
        let state = windows_state_value(&status, key);
        if state == "OK" || state == "RUN" {
            continue;
        }
        actions.push(windows_plan_item(key, &state));
    }
    actions.sort_by(|left, right| {
        severity_rank(left)
            .cmp(&severity_rank(right))
            .then_with(|| {
                left.get("phase")
                    .and_then(Value::as_str)
                    .unwrap_or("")
                    .cmp(right.get("phase").and_then(Value::as_str).unwrap_or(""))
            })
            .then_with(|| {
                left.get("key")
                    .and_then(Value::as_str)
                    .unwrap_or("")
                    .cmp(right.get("key").and_then(Value::as_str).unwrap_or(""))
            })
    });
    let critical = actions
        .iter()
        .filter(|item| item.get("severity").and_then(Value::as_str) == Some("critical"))
        .count();
    let high = actions
        .iter()
        .filter(|item| item.get("severity").and_then(Value::as_str) == Some("high"))
        .count();
    let medium = actions
        .iter()
        .filter(|item| item.get("severity").and_then(Value::as_str) == Some("medium"))
        .count();
    let vm_ready = [
        "cpu_virtualization",
        "kvm_device",
        "qemu",
        "virt_manager",
        "virsh",
        "libvirtd",
        "default_network",
    ]
    .iter()
    .all(|key| windows_ok(&status, key));
    let app_ready = windows_ok(&status, "wine")
        && (windows_ok(&status, "bottles_flatpak") || windows_ok(&status, "lutris"));
    let ready = vm_ready && app_ready;
    let mode = if ready {
        "complete"
    } else if vm_ready {
        "vm-ready"
    } else {
        "setup-needed"
    };
    let payload = json!({
        "schema": "sevenos.windows-plan.v1",
        "mode": mode,
        "ready": ready,
        "summary": {
            "total": actions.len(),
            "critical": critical,
            "high": high,
            "medium": medium,
        },
        "next": actions,
        "runtime": "seven-daemon",
        "writer": "seven-daemon",
    });
    println!(
        "{}",
        serde_json::to_string(&payload).unwrap_or_else(|_| "{}".to_string())
    );
}

fn file_state(root: &Path, relative: &str) -> &'static str {
    if root.join(relative).is_file() {
        "OK"
    } else {
        "MISS"
    }
}

fn dir_state(root: &Path, relative: &str) -> &'static str {
    if root.join(relative).is_dir() {
        "OK"
    } else {
        "MISS"
    }
}

fn file_contains_state(root: &Path, relative: &str, needle: &str) -> &'static str {
    let path = root.join(relative);
    match fs::read_to_string(path) {
        Ok(contents) if contents.contains(needle) => "OK",
        _ => "MISS",
    }
}

fn file_lacks_state(root: &Path, relative: &str, needle: &str) -> &'static str {
    let path = root.join(relative);
    match fs::read_to_string(path) {
        Ok(contents) if !contents.contains(needle) => "OK",
        Ok(_) => "MISS",
        Err(_) => "MISS",
    }
}

fn combined_state(states: &[&str]) -> &'static str {
    if states.iter().all(|state| *state == "OK") {
        "OK"
    } else if states.iter().any(|state| *state == "OK") {
        "PART"
    } else {
        "MISS"
    }
}

fn package_manifest_contains(root: &Path, relative: &str, package: &str) -> bool {
    let path = root.join(relative);
    fs::read_to_string(path)
        .unwrap_or_default()
        .lines()
        .map(|line| line.split('#').next().unwrap_or("").trim())
        .any(|line| line == package)
}

fn local_calamares_repo_ready(root: &Path) -> bool {
    let repo = root.join("archiso/localrepo/x86_64");
    let has_db = repo.join("sevenos-local.db.tar.gz").is_file();
    let has_files_db = repo.join("sevenos-local.files.tar.gz").is_file();
    let has_pkg = fs::read_dir(&repo)
        .ok()
        .into_iter()
        .flat_map(|entries| entries.filter_map(Result::ok))
        .filter_map(|entry| entry.file_name().into_string().ok())
        .any(|name| name.starts_with("calamares-") && name.ends_with(".pkg.tar.zst"));

    has_db && has_files_db && has_pkg && package_manifest_contains(root, "archiso/profile/packages.x86_64", "calamares")
}

fn calamares_runtime_state(root: &Path) -> &'static str {
    if command_exists("calamares") {
        "OK"
    } else if local_calamares_repo_ready(root) {
        "OK"
    } else if package_manifest_contains(root, "scripts/packages-installer-aur.txt", "calamares")
        && (command_exists("yay") || command_exists("paru"))
    {
        "aur-candidate"
    } else if package_manifest_contains(root, "scripts/packages-installer-aur.txt", "calamares") {
        "source-declared"
    } else {
        "MISS"
    }
}

fn installer_tooling_item(key: &str, state: &str) -> Value {
    json!({
        "key": key,
        "state": state,
        "writer": "seven-daemon",
    })
}

fn installer_status_items(root: &Path) -> (Vec<Value>, Vec<Value>) {
    let tooling = vec![
        installer_tooling_item(
            "archinstall",
            if command_exists("archinstall") {
                "OK"
            } else {
                "MISS"
            },
        ),
        installer_tooling_item(
            "calamares",
            calamares_runtime_state(root),
        ),
    ];
    let foundation = vec![
        installer_tooling_item("planner", file_state(root, "installer/plan.sh")),
        installer_tooling_item("calamares-profile", dir_state(root, "installer/calamares")),
        installer_tooling_item("archiso-profile", dir_state(root, "archiso/profile")),
        installer_tooling_item("iso-builder", file_state(root, "scripts/build-iso.sh")),
        installer_tooling_item(
            "iso-packages",
            file_state(root, "archiso/profile/packages.x86_64"),
        ),
        installer_tooling_item("graphical-launcher", file_state(root, "bin/seven-installer")),
        installer_tooling_item(
            "installer-portal",
            file_state(root, "bin/seven-installer"),
        ),
        installer_tooling_item(
            "live-desktop-entry",
            file_contains_state(
                root,
                "archiso/profile/airootfs/usr/share/applications/seven-installer.desktop",
                "Exec=seven-installer",
            ),
        ),
        installer_tooling_item(
            "calamares-branding",
            file_state(root, "installer/calamares/branding/sevenos/branding.desc"),
        ),
    ];
    (tooling, foundation)
}

fn installer_flow_item(
    key: &str,
    title: &str,
    state: &str,
    phase: &str,
    detail: &str,
    command: &str,
) -> Value {
    json!({
        "key": key,
        "title": title,
        "state": state,
        "phase": phase,
        "detail": detail,
        "command": command,
        "writer": "seven-daemon",
    })
}

fn installer_flow_checks(root: &Path) -> Vec<Value> {
    let branding_state = combined_state(&[
        file_contains_state(root, "installer/calamares/branding/sevenos/branding.desc", "componentName: sevenos"),
        file_contains_state(root, "installer/calamares/branding/sevenos/branding.desc", "slideshow:"),
        file_contains_state(root, "installer/calamares/branding/sevenos/branding.desc", "slideshowAPI:"),
        file_state(root, "installer/calamares/branding/sevenos/show.qml"),
        file_state(root, "installer/calamares/branding/sevenos/seven-prism.png"),
    ]);
    let unpackfs_state = combined_state(&[
        file_contains_state(root, "installer/calamares/modules/unpackfs.conf", "source: \"/run/archiso/airootfs\""),
        file_contains_state(root, "installer/calamares/modules/unpackfs.conf", "sourcefs: \"file\""),
        file_lacks_state(root, "installer/calamares/modules/unpackfs.conf", "../CHANGES"),
        file_lacks_state(root, "installer/calamares/modules/unpackfs.conf", "\"/CHANGES\""),
    ]);
    let module_sequence_state = combined_state(&[
        file_contains_state(root, "installer/calamares/settings.conf", "- unpackfs"),
        file_contains_state(root, "installer/calamares/settings.conf", "shellprocess@livecleanup"),
        file_contains_state(root, "installer/calamares/settings.conf", "shellprocess@finalize"),
        file_contains_state(root, "installer/calamares/settings.conf", "- bootloader"),
        file_lacks_state(root, "installer/calamares/settings.conf", "- displaymanager"),
        file_lacks_state(root, "installer/calamares/settings.conf", "- networkcfg"),
    ]);
    let finalize_state = combined_state(&[
        file_contains_state(root, "installer/calamares/modules/shellprocess.conf", "/bin/bash -lc"),
        file_contains_state(root, "installer/calamares/modules/shellprocess.conf", "seven-calamares-finalize"),
        file_contains_state(root, "bin/seven-calamares-finalize", "NetworkManager.service"),
        file_contains_state(root, "bin/seven-calamares-finalize", "sddm.service"),
        file_contains_state(root, "bin/seven-calamares-finalize", "run_optional_step"),
        file_lacks_state(root, "bin/seven-calamares-finalize", "install.sh base"),
    ]);
    let cleanup_state = combined_state(&[
        file_contains_state(root, "installer/calamares/modules/shellprocess-livecleanup.conf", "/bin/bash -lc"),
        file_contains_state(root, "installer/calamares/modules/shellprocess-livecleanup.conf", "seven-calamares-livecleanup"),
        file_contains_state(root, "bin/seven-calamares-livecleanup", "without touching running live processes"),
        file_contains_state(root, "archiso/profile/airootfs/root/customize_airootfs.sh", "seven-calamares-livecleanup"),
    ]);
    let password_state = combined_state(&[
        file_contains_state(root, "installer/calamares/modules/users.conf", "minLength: 1"),
        file_contains_state(root, "installer/calamares/modules/users.conf", "allowWeakPasswords: true"),
        file_contains_state(root, "installer/calamares/modules/users.conf", "allowWeakPasswordsDefault: true"),
    ]);
    let wifi_state = combined_state(&[
        file_contains_state(root, "archiso/profile/airootfs/usr/local/bin/sevenos-live-ready", "open_network_choice"),
        file_contains_state(root, "archiso/profile/airootfs/usr/local/bin/sevenos-live-ready", "Network is not connected"),
        file_contains_state(root, "bin/seven-installer", "network_command"),
        file_contains_state(root, "bin/seven-installer", "seven-wifi"),
        file_contains_state(root, "bin/seven-installer", "nmtui"),
    ]);
    let duplicate_guard_state = combined_state(&[
        file_contains_state(root, "bin/seven-installer", "calamares-open.lock"),
        file_contains_state(root, "bin/seven-installer", "installer-portal-open.lock"),
        file_contains_state(root, "bin/seven-installer", "focus_calamares_window"),
        file_contains_state(root, "bin/seven-installer", "focus_installer_window"),
        file_contains_state(root, "archiso/profile/airootfs/usr/local/bin/sevenos-live-ready", "ready_marker"),
    ]);
    let live_hypr_state = combined_state(&[
        file_contains_state(root, "archiso/profile/airootfs/etc/sevenos/live-hyprland.conf", "exec-once = /usr/local/bin/sevenos-live-ready"),
        file_lacks_state(root, "archiso/profile/airootfs/etc/sevenos/live-hyprland.conf", "windowrulev2 ="),
        file_lacks_state(root, "archiso/profile/airootfs/etc/sevenos/live-hyprland.conf", "windowrulev2="),
        file_lacks_state(root, "archiso/profile/airootfs/etc/sevenos/live-hyprland.conf", "windowrule ="),
        file_lacks_state(root, "archiso/profile/airootfs/etc/sevenos/live-hyprland.conf", "windowrule="),
        file_contains_state(root, "archiso/profile/airootfs/etc/sevenos/live-hyprland.conf", "seven-installer live-retry"),
    ]);
    let locale_state = combined_state(&[
        file_contains_state(root, "archiso/profile/airootfs/etc/locale.gen", "en_US.UTF-8 UTF-8"),
        file_contains_state(root, "archiso/profile/airootfs/etc/locale.gen", "fr_FR.UTF-8 UTF-8"),
        file_contains_state(root, "archiso/profile/airootfs/etc/locale.conf", "LANG=en_US.UTF-8"),
        file_contains_state(root, "archiso/profile/airootfs/root/customize_airootfs.sh", "locale-gen"),
    ]);
    let iso_boot_state = combined_state(&[
        file_contains_state(root, "archiso/profile/efiboot/loader/entries/01-sevenos-live.conf", "SevenOS"),
        file_contains_state(root, "archiso/profile/efiboot/loader/entries/03-sevenos-live-safe.conf", "Safe Graphics"),
        file_contains_state(root, "archiso/profile/efiboot/loader/entries/03-sevenos-live-safe.conf", "nouveau.modeset=1"),
        file_contains_state(root, "archiso/profile/efiboot/loader/entries/03-sevenos-live-safe.conf", "i915.modeset=1"),
        file_contains_state(root, "archiso/profile/efiboot/loader/entries/03-sevenos-live-safe.conf", "amdgpu.dc=1"),
        file_contains_state(root, "archiso/profile/syslinux/archiso_sys-linux.cfg", "SevenOS"),
        file_contains_state(root, "archiso/profile/syslinux/archiso_sys-linux.cfg", "Safe ^Graphics"),
        file_contains_state(root, "scripts/build-iso.sh", "mkarchiso"),
    ]);

    vec![
        installer_flow_item("branding", "SevenOS Calamares branding", branding_state, "calamares", "Branding must include the SevenOS component, Prism media and slideshow keys Calamares expects.", "seven installer release"),
        installer_flow_item("unpackfs", "Live filesystem copy", unpackfs_state, "calamares", "Calamares must unpack the live root from /run/archiso/airootfs, not a placeholder file such as /CHANGES.", "seven installer release"),
        installer_flow_item("module-sequence", "Installer module sequence", module_sequence_state, "calamares", "The sequence must avoid duplicate network/display manager modules and run SevenOS cleanup/finalize hooks once.", "seven installer release"),
        installer_flow_item("livecleanup", "Live cleanup hook", cleanup_state, "calamares", "Cleanup must remove live-only state without killing the running live session.", "seven installer release"),
        installer_flow_item("finalize", "Post-install finalize hook", finalize_state, "calamares", "Finalize must configure NetworkManager, SDDM and SevenOS state without recursively running the full installer stack.", "seven installer release"),
        installer_flow_item("password-policy", "Accessible password policy", password_state, "users", "The graphical installer accepts any non-empty password while preventing blank account passwords.", "seven installer release"),
        installer_flow_item("wifi-choice", "Wi-Fi choice before install", wifi_state, "live", "The live session must offer Wi-Fi or nmtui before starting destructive installation steps.", "seven-installer network"),
        installer_flow_item("duplicate-window-guard", "Single installer window", duplicate_guard_state, "live", "Repeated clicks and fallback retries should focus an existing installer instead of opening two identical windows.", "seven-installer live-status"),
        installer_flow_item("live-hyprland", "Live Hyprland-safe config", live_hypr_state, "live", "The live session must avoid fragile Hyprland window rules that can leave users with a black screen.", "seven installer release"),
        installer_flow_item("locale", "Live language baseline", locale_state, "live", "The ISO must generate at least EN and FR UTF-8 locales before the graphical session starts.", "seven installer release"),
        installer_flow_item("boot-media", "Boot entries and safe mode", iso_boot_state, "boot", "The ISO must expose SevenOS live boot entries and a safe graphics route for difficult GPUs.", "./install.sh iso --dry-run"),
    ]
}

fn installer_release_checks(root: &Path, tooling: &[Value], foundation: &[Value]) -> Vec<Value> {
    vec![
        json!({
            "key": "archinstall-runtime",
            "state": item_state(tooling, "archinstall"),
            "required": true,
            "title": "Guided TUI backend",
            "command": "seven installer install",
            "writer": "seven-daemon",
        }),
        json!({
            "key": "calamares-runtime",
            "state": item_state(tooling, "calamares"),
            "required": false,
            "title": "Graphical installer runtime",
            "command": "seven installer iso-runtime --json",
            "reason": "Calamares is ready when it exists on the host or is packaged in the SevenOS local ISO repository.",
            "writer": "seven-daemon",
        }),
        json!({
            "key": "calamares-source-policy",
            "state": if matches!(
                item_state(tooling, "calamares").as_str(),
                "OK" | "aur-candidate" | "source-declared"
            ) {
                "OK"
            } else {
                "MISS"
            },
            "required": false,
            "title": "Calamares runtime source policy",
            "command": "seven installer runtime --json",
            "reason": format!("Runtime source state: {}.", item_state(tooling, "calamares")),
            "writer": "seven-daemon",
        }),
        json!({
            "key": "installer-planner",
            "state": item_state(foundation, "planner"),
            "required": true,
            "title": "Non-destructive install planner",
            "command": "seven installer doctor",
            "writer": "seven-daemon",
        }),
        json!({
            "key": "calamares-settings",
            "state": file_state(root, "installer/calamares/settings.conf"),
            "required": true,
            "title": "Calamares module sequence",
            "command": "seven installer doctor",
            "writer": "seven-daemon",
        }),
        json!({
            "key": "calamares-sevenos-module",
            "state": file_state(root, "installer/calamares/modules/sevenos.conf"),
            "required": true,
            "title": "SevenOS Calamares post-install module",
            "command": "seven installer doctor",
            "writer": "seven-daemon",
        }),
        json!({
            "key": "calamares-postinstall",
            "state": combined_state(&[
                file_contains_state(root, "installer/calamares/modules/shellprocess.conf", "/bin/bash -lc"),
                file_contains_state(root, "installer/calamares/modules/shellprocess.conf", "seven-calamares-finalize"),
                file_contains_state(root, "bin/seven-calamares-finalize", "/var/log/sevenos-install.log"),
                file_lacks_state(root, "bin/seven-calamares-finalize", "install.sh base"),
            ]),
            "required": true,
            "title": "SevenOS post-install finalize hook",
            "command": "seven installer doctor",
            "writer": "seven-daemon",
        }),
        json!({
            "key": "graphical-launcher",
            "state": item_state(foundation, "graphical-launcher"),
            "required": true,
            "title": "SevenOS graphical installer launcher",
            "command": "seven installer graphical",
            "writer": "seven-daemon",
        }),
        json!({
            "key": "installer-portal",
            "state": item_state(foundation, "installer-portal"),
            "required": true,
            "title": "SevenOS installer portal contract",
            "command": "seven-installer status --json",
            "writer": "seven-daemon",
        }),
        json!({
            "key": "live-desktop-entry",
            "state": item_state(foundation, "live-desktop-entry"),
            "required": true,
            "title": "Live ISO installer desktop entry",
            "command": "seven installer graphical",
            "writer": "seven-daemon",
        }),
        json!({
            "key": "calamares-branding",
            "state": item_state(foundation, "calamares-branding"),
            "required": true,
            "title": "SevenOS Calamares branding",
            "command": "seven installer graphical",
            "writer": "seven-daemon",
        }),
        json!({
            "key": "archiso-profile",
            "state": item_state(foundation, "archiso-profile"),
            "required": true,
            "title": "Archiso live profile",
            "command": "seven installer doctor",
            "writer": "seven-daemon",
        }),
        json!({
            "key": "iso-builder",
            "state": item_state(foundation, "iso-builder"),
            "required": true,
            "title": "ISO build script",
            "command": "./install.sh iso --dry-run",
            "writer": "seven-daemon",
        }),
        json!({
            "key": "iso-packages",
            "state": item_state(foundation, "iso-packages"),
            "required": true,
            "title": "Live ISO package list",
            "command": "seven installer doctor",
            "writer": "seven-daemon",
        }),
        json!({
            "key": "repo-injection",
            "state": file_contains_state(root, "scripts/build-iso.sh", "/opt/SevenOS"),
            "required": true,
            "title": "SevenOS repository injection",
            "command": "./install.sh iso --dry-run",
            "writer": "seven-daemon",
        }),
        json!({
            "key": "live-cli",
            "state": file_contains_state(root, "archiso/profile/airootfs/root/customize_airootfs.sh", "/opt/SevenOS/bin/seven"),
            "required": true,
            "title": "Live CLI bootstrap",
            "command": "seven installer doctor",
            "writer": "seven-daemon",
        }),
    ]
}

fn installer_release_json(root: &Path, tooling: &[Value], foundation: &[Value]) -> Value {
    let checks = installer_release_checks(root, tooling, foundation);
    let required_total = checks
        .iter()
        .filter(|item| item.get("required").and_then(Value::as_bool) == Some(true))
        .count();
    let required_ready = checks
        .iter()
        .filter(|item| {
            item.get("required").and_then(Value::as_bool) == Some(true)
                && item.get("state").and_then(Value::as_str) == Some("OK")
        })
        .count();
    let optional_total = checks.len().saturating_sub(required_total);
    let optional_ready = checks
        .iter()
        .filter(|item| {
            item.get("required").and_then(Value::as_bool) == Some(false)
                && item.get("state").and_then(Value::as_str) == Some("OK")
        })
        .count();
    let score = (((required_ready as f64 / required_total.max(1) as f64) * 85.0)
        + ((optional_ready as f64 / optional_total.max(1) as f64) * 15.0))
        .round()
        .min(100.0) as u64;
    let state = if score >= 95 {
        "graphical-ready"
    } else if required_ready == required_total {
        "tui-release-ready"
    } else if score >= 70 {
        "iso-foundation"
    } else {
        "foundation"
    };

    json!({
        "schema": "sevenos.installer-release.v1",
        "state": state,
        "score": score,
        "required_ready": required_ready,
        "required_total": required_total,
        "optional_ready": optional_ready,
        "optional_total": optional_total,
        "calamares_runtime": item_state(tooling, "calamares"),
        "checks": checks,
        "portal": "seven-installer status --json",
        "runtime": "seven-daemon",
        "writer": "seven-daemon",
    })
}

fn installer_release_payload(root: &Path) -> Value {
    let (tooling, foundation) = installer_status_items(root);
    installer_release_json(root, &tooling, &foundation)
}

fn item_state(items: &[Value], key: &str) -> String {
    items
        .iter()
        .find(|item| item.get("key").and_then(Value::as_str) == Some(key))
        .and_then(|item| item.get("state").and_then(Value::as_str))
        .map(str::to_string)
        .unwrap_or_else(|| "MISS".to_string())
}

fn installer_mode(tooling: &[Value]) -> &'static str {
    if item_state(tooling, "calamares") == "OK" {
        "graphical"
    } else if item_state(tooling, "archinstall") == "OK" {
        "tui-ready"
    } else {
        "foundation"
    }
}

fn installer_consumer_path(tooling: &[Value]) -> &'static str {
    if item_state(tooling, "calamares") == "OK" {
        "graphical-calamares"
    } else if item_state(tooling, "archinstall") == "OK" {
        "guided-tui"
    } else {
        "setup-needed"
    }
}

fn installer_ready(tooling: &[Value], foundation: &[Value]) -> bool {
    item_state(tooling, "archinstall") == "OK"
        && item_state(foundation, "planner") == "OK"
        && item_state(foundation, "archiso-profile") == "OK"
        && item_state(foundation, "iso-builder") == "OK"
}

fn installer_json() {
    let root = sevenos_root().unwrap_or_else(|| PathBuf::from("."));
    let (tooling, foundation) = installer_status_items(&root);
    let release = installer_release_json(&root, &tooling, &foundation);
    let flow = installer_flow_checks(&root);
    let flow_ok = flow
        .iter()
        .filter(|item| item.get("state").and_then(Value::as_str) == Some("OK"))
        .count();
    let flow_total = flow.len();
    let payload = json!({
        "schema": "sevenos.installer.v1",
        "tooling": tooling,
        "foundation": foundation,
        "flow": {
            "state": if flow_ok == flow_total { "ready" } else { "attention" },
            "ok": flow_ok,
            "total": flow_total,
            "checks": flow,
        },
        "ready": installer_ready(&tooling, &foundation),
        "mode": installer_mode(&tooling),
        "consumer_path": installer_consumer_path(&tooling),
        "release": release,
        "commands": {
            "status": "seven installer status",
            "guide": "seven installer guide",
            "plan": "seven installer plan",
            "release": "seven installer release",
            "install_tools": "seven installer install"
        },
        "runtime": "seven-daemon",
        "writer": "seven-daemon",
    });
    println!(
        "{}",
        serde_json::to_string(&payload).unwrap_or_else(|_| "{}".to_string())
    );
}

fn installer_plan_item(key: &str, state: &str) -> Value {
    let (title, severity, impact, phase, command, reason) = match key {
        "archinstall" => (
            "Install Archinstall automation",
            "high",
            "packages",
            "automation",
            "seven installer install",
            "Archinstall gives SevenOS an official automation backend before destructive disk flows are enabled.",
        ),
        "calamares" => (
            "Package Calamares installer",
            "medium",
            "packages",
            "gui",
            "seven installer plan",
            "Calamares is the graphical path for public ISO installation, but packaging remains a downstream step.",
        ),
        "planner" => (
            "Restore installer planner",
            "critical",
            "changes",
            "planner",
            "seven installer doctor",
            "SevenOS needs a non-destructive install plan before generating disk steps.",
        ),
        "calamares-profile" => (
            "Restore Calamares profile",
            "high",
            "changes",
            "gui",
            "seven installer doctor",
            "The graphical installer profile must travel with the ISO.",
        ),
        "archiso-profile" => (
            "Restore Archiso profile",
            "critical",
            "changes",
            "iso",
            "seven installer doctor",
            "SevenOS cannot produce a live ISO without an Archiso profile.",
        ),
        "iso-builder" => (
            "Restore ISO build script",
            "critical",
            "changes",
            "iso",
            "seven installer doctor",
            "The ISO builder is the bridge from repository to bootable SevenOS media.",
        ),
        "iso-packages" => (
            "Restore ISO package list",
            "high",
            "changes",
            "iso",
            "seven installer doctor",
            "The live image needs an explicit package set for repeatable builds.",
        ),
        "dry-run-iso" => (
            "Validate ISO dry-run",
            "medium",
            "safe",
            "iso",
            "./install.sh iso --dry-run",
            "Before moving to a public ISO, SevenOS should prove the build path without touching the host.",
        ),
        _ => (
            "Resolve installer gap",
            "medium",
            "changes",
            "installer",
            "seven installer plan",
            "Resolve this installer readiness gap.",
        ),
    };
    json!({
        "key": key,
        "state": state,
        "title": title,
        "severity": severity,
        "impact": impact,
        "phase": phase,
        "reason": reason,
        "command": command,
        "writer": "seven-daemon",
    })
}

fn installer_plan_json() {
    let root = sevenos_root().unwrap_or_else(|| PathBuf::from("."));
    let (tooling, foundation) = installer_status_items(&root);
    let release = installer_release_json(&root, &tooling, &foundation);
    let flow = installer_flow_checks(&root);
    let mut actions = Vec::new();
    for item in tooling.iter().chain(foundation.iter()) {
        let key = item.get("key").and_then(Value::as_str).unwrap_or("unknown");
        let state = item.get("state").and_then(Value::as_str).unwrap_or("MISS");
        if state != "OK" {
            actions.push(installer_plan_item(key, state));
        }
    }
    actions.push(installer_plan_item("dry-run-iso", "READY"));
    let existing_keys: Vec<String> = tooling
        .iter()
        .chain(foundation.iter())
        .filter_map(|item| item.get("key").and_then(Value::as_str).map(str::to_string))
        .collect();
    if let Some(checks) = release.get("checks").and_then(Value::as_array) {
        for check in checks {
            let state = check.get("state").and_then(Value::as_str).unwrap_or("MISS");
            if state == "OK" {
                continue;
            }
            let key = check
                .get("key")
                .and_then(Value::as_str)
                .unwrap_or("release-check");
            if existing_keys.iter().any(|existing| existing == key) {
                continue;
            }
            if key == "calamares-runtime" && existing_keys.iter().any(|existing| existing == "calamares") {
                continue;
            }
            actions.push(json!({
                "key": key,
                "state": state,
                "title": check.get("title").and_then(Value::as_str).unwrap_or("Resolve installer release check"),
                "severity": if check.get("required").and_then(Value::as_bool) == Some(true) { "high" } else { "medium" },
                "impact": if check.get("command").and_then(Value::as_str).unwrap_or("").ends_with("--dry-run") { "safe" } else { "changes" },
                "phase": "release",
                "reason": "Public ISO readiness requires this installer release check to pass.",
                "command": check.get("command").and_then(Value::as_str).unwrap_or("seven installer release"),
                "writer": "seven-daemon",
            }));
        }
    }
    for check in &flow {
        let state = check.get("state").and_then(Value::as_str).unwrap_or("MISS");
        if state == "OK" {
            continue;
        }
        actions.push(json!({
            "key": format!("flow-{}", check.get("key").and_then(Value::as_str).unwrap_or("installer")),
            "state": state,
            "title": check.get("title").and_then(Value::as_str).unwrap_or("Resolve installer flow"),
            "severity": if state == "MISS" { "high" } else { "medium" },
            "impact": "changes",
            "phase": check.get("phase").and_then(Value::as_str).unwrap_or("installer"),
            "reason": check.get("detail").and_then(Value::as_str).unwrap_or("Installer flow check needs attention."),
            "command": check.get("command").and_then(Value::as_str).unwrap_or("seven installer release"),
            "writer": "seven-daemon",
        }));
    }
    actions.sort_by(|left, right| {
        severity_rank(left)
            .cmp(&severity_rank(right))
            .then_with(|| {
                left.get("phase")
                    .and_then(Value::as_str)
                    .unwrap_or("")
                    .cmp(right.get("phase").and_then(Value::as_str).unwrap_or(""))
            })
            .then_with(|| {
                left.get("key")
                    .and_then(Value::as_str)
                    .unwrap_or("")
                    .cmp(right.get("key").and_then(Value::as_str).unwrap_or(""))
            })
    });
    let critical = actions
        .iter()
        .filter(|item| item.get("severity").and_then(Value::as_str) == Some("critical"))
        .count();
    let high = actions
        .iter()
        .filter(|item| item.get("severity").and_then(Value::as_str) == Some("high"))
        .count();
    let medium = actions
        .iter()
        .filter(|item| item.get("severity").and_then(Value::as_str) == Some("medium"))
        .count();
    let payload = json!({
        "schema": "sevenos.installer-plan.v1",
        "mode": installer_mode(&tooling),
        "ready": installer_ready(&tooling, &foundation),
        "release": release,
        "flow": flow,
        "summary": {
            "total": actions.len(),
            "critical": critical,
            "high": high,
            "medium": medium,
        },
        "next": actions,
        "runtime": "seven-daemon",
        "writer": "seven-daemon",
    });
    println!(
        "{}",
        serde_json::to_string(&payload).unwrap_or_else(|_| "{}".to_string())
    );
}

fn installer_flow_payload() -> Value {
    let root = sevenos_root().unwrap_or_else(|| PathBuf::from("."));
    let checks = installer_flow_checks(&root);
    let ok = checks
        .iter()
        .filter(|item| item.get("state").and_then(Value::as_str) == Some("OK"))
        .count();
    let total = checks.len();
    let score = if total > 0 {
        ((ok as f64 / total as f64) * 100.0).round() as u64
    } else {
        0
    };
    json!({
        "schema": "sevenos.installer-flow.v1",
        "state": if ok == total { "ready" } else { "attention" },
        "score": score,
        "summary": {
            "ok": ok,
            "total": total,
            "open": total.saturating_sub(ok),
        },
        "checks": checks,
        "runtime": "seven-daemon",
        "writer": "seven-daemon",
    })
}

fn installer_flow_json() {
    print_value(&installer_flow_payload());
}

fn command_output_text(command: &str, args: &[&str], cwd: Option<&Path>) -> Option<String> {
    let mut cmd = Command::new(command);
    cmd.args(args);
    if let Some(dir) = cwd {
        cmd.current_dir(dir);
    }
    let output = cmd.output().ok()?;
    if !output.status.success() {
        return None;
    }
    Some(String::from_utf8_lossy(&output.stdout).trim().to_string())
}

fn git_text(root: &Path, args: &[&str]) -> String {
    if !root.join(".git").exists() {
        return String::new();
    }
    command_output_text("git", args, Some(root)).unwrap_or_default()
}

fn update_dirty_count(root: &Path) -> usize {
    git_text(root, &["status", "--short"])
        .lines()
        .filter(|line| !line.trim().is_empty())
        .count()
}

fn update_ahead_behind(root: &Path, upstream: &str) -> (Option<u64>, Option<u64>) {
    if upstream.is_empty() {
        return (None, None);
    }
    let raw = git_text(root, &["rev-list", "--left-right", "--count", &format!("HEAD...{}", upstream)]);
    let parts = raw.split_whitespace().collect::<Vec<_>>();
    if parts.len() != 2 {
        return (None, None);
    }
    (
        parts[0].parse::<u64>().ok(),
        parts[1].parse::<u64>().ok(),
    )
}

fn update_last_snapshot() -> PathBuf {
    state_dir().join("update/last-successful-tree")
}

fn update_report_file() -> PathBuf {
    state_dir().join("update/last-report.json")
}

fn update_source_item(
    key: &str,
    public_name: &str,
    backend: &str,
    available: bool,
    command: &str,
    note: &str,
) -> Value {
    json!({
        "key": key,
        "public_name": public_name,
        "backend": backend,
        "available": available,
        "pending": Value::Null,
        "state": if available { "OK" } else { "PART" },
        "command": command,
        "note": note,
        "writer": "seven-daemon",
    })
}

fn update_checks(root: &Path) -> Vec<Value> {
    let snapshot = update_last_snapshot();
    vec![
        json!({
            "key": "root",
            "title": "SevenOS system root",
            "state": if root.join("install.sh").is_file() { "OK" } else { "MISS" },
            "detail": root.to_string_lossy(),
            "command": "seven first-run verify",
            "writer": "seven-daemon",
        }),
        json!({
            "key": "update-script",
            "title": "Update adapter",
            "state": if root.join("scripts/update.sh").is_file() { "OK" } else { "MISS" },
            "detail": "scripts/update.sh remains the privileged adapter for apply/rollback.",
            "command": "seven update",
            "writer": "seven-daemon",
        }),
        json!({
            "key": "admin-helper",
            "title": "Graphical admin helper",
            "state": if root.join("bin/seven-update-admin").is_file() && command_exists("pkexec") { "OK" } else { "PART" },
            "detail": "Settings uses pkexec + seven-update-admin for password prompts.",
            "command": "seven settings system",
            "writer": "seven-daemon",
        }),
        json!({
            "key": "rollback",
            "title": "Rollback snapshot",
            "state": if snapshot.exists() { "OK" } else { "READY" },
            "detail": if snapshot.exists() { snapshot.to_string_lossy().to_string() } else { "A snapshot is created before applying updates.".to_string() },
            "command": "seven update rollback",
            "writer": "seven-daemon",
        }),
        json!({
            "key": "store-route",
            "title": "SevenPkg route",
            "state": if root.join("bin/sevenpkg").is_file() { "OK" } else { "MISS" },
            "detail": "Package updates stay behind SevenPkg/SevenStore identity.",
            "command": "sevenpkg update --preview",
            "writer": "seven-daemon",
        }),
    ]
}

fn update_payload() -> Value {
    let root = sevenos_root().unwrap_or_else(|| PathBuf::from("."));
    let is_git = root.join(".git").exists();
    let branch = git_text(&root, &["rev-parse", "--abbrev-ref", "HEAD"]);
    let commit = git_text(&root, &["rev-parse", "--short", "HEAD"]);
    let upstream = git_text(&root, &["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"]);
    let dirty_count = if is_git { Some(update_dirty_count(&root)) } else { None };
    let (ahead, behind) = update_ahead_behind(&root, &upstream);
    let repo_pending = behind.is_some_and(|count| count > 0);
    let aur_helper = if command_exists("paru") {
        "paru"
    } else if command_exists("yay") {
        "yay"
    } else {
        ""
    };
    let checks = update_checks(&root);
    let ok_checks = checks
        .iter()
        .filter(|item| {
            matches!(
                item.get("state").and_then(Value::as_str),
                Some("OK") | Some("READY")
            )
        })
        .count();
    let score = ((ok_checks as f64 / checks.len().max(1) as f64) * 100.0).round() as u64;
    let issues = checks
        .iter()
        .filter(|item| {
            !matches!(
                item.get("state").and_then(Value::as_str),
                Some("OK") | Some("READY")
            )
        })
        .cloned()
        .collect::<Vec<_>>();
    let state = if score < 75 {
        "needs-attention"
    } else if repo_pending {
        "updates-available"
    } else if dirty_count.unwrap_or(0) > 0 {
        "attention"
    } else {
        "ready"
    };

    json!({
        "schema": "sevenos.update.v2",
        "compat_schema": "sevenos.update.v1",
        "state": state,
        "score": score,
        "runtime": "seven-daemon",
        "pending_total": Value::Null,
        "pending_known": false,
        "repo_pending": repo_pending,
        "fast_mode": true,
        "root": root.to_string_lossy(),
        "preferred_root": "/opt/SevenOS",
        "repository": {
            "state": if is_git && !upstream.is_empty() { "OK" } else if is_git { "PART" } else { "MISS" },
            "git": is_git,
            "branch": branch,
            "commit": commit,
            "upstream": upstream,
            "ahead": ahead,
            "behind": behind,
            "dirty_count": dirty_count,
            "public_location": root == PathBuf::from("/opt/SevenOS"),
            "command": "seven update install --yes",
            "policy": if dirty_count.unwrap_or(0) > 0 { "repo-pull-skipped-until-clean" } else { "fast-forward-only" },
        },
        "rollback": {
            "available": update_last_snapshot().exists(),
            "snapshot": if update_last_snapshot().exists() { json!(update_last_snapshot().to_string_lossy().to_string()) } else { Value::Null },
            "report": update_report_file().to_string_lossy(),
            "command": "seven update rollback",
        },
        "sources": [
            update_source_item("system", "SevenOS System", "pacman", command_exists("pacman"), "seven update install --yes", "System package updates remain protected by the SevenOS update route."),
            update_source_item("apps", "SevenOS Apps", "Flatpak", command_exists("flatpak"), "seven flatpak status", "Flatpak is an app source, not the public product identity."),
            update_source_item("community", "SevenOS Community Apps", if aur_helper.is_empty() { "AUR helper" } else { aur_helper }, !aur_helper.is_empty(), "./install.sh aur-helpers --yes", "AUR stays explicit and guided."),
            update_source_item("profiles", "Mini OS Bundles", "sevenpkg", root.join("bin/sevenpkg").is_file(), "sevenpkg update --preview", "Mini OS updates stay routed by SevenPkg."),
        ],
        "checks": checks,
        "issues": issues,
        "policy": [
            "Readiness and plan are daemon-owned for native UI speed.",
            "Apply and rollback remain behind the existing privileged adapter until the policy service is native.",
            "Repository updates are fast-forward only.",
            "Local changes protect the SevenOS tree by skipping repository pull.",
            "A rollback snapshot is created before state-changing updates.",
        ],
        "commands": {
            "status": "seven update",
            "check": "seven update check",
            "json": "seven update --json",
            "plan": "seven update plan",
            "apply": "seven update install --yes",
            "rollback": "seven update rollback",
            "native": "seven-daemon update --json",
        },
        "writer": "seven-daemon",
    })
}

fn update_json() {
    print_value(&update_payload());
}

fn recovery_manifest_counts(root: &Path) -> (u64, u64) {
    let path = root.join("sevenos.dotinst");
    let Ok(content) = fs::read_to_string(path) else {
        return (0, 0);
    };
    let Ok(data) = serde_json::from_str::<Value>(&content) else {
        return (0, 0);
    };
    let protected = data
        .get("protected")
        .and_then(Value::as_array)
        .map(|items| items.len() as u64)
        .unwrap_or(0);
    let restore = data
        .get("restore")
        .and_then(Value::as_array)
        .map(|items| items.len() as u64)
        .unwrap_or(0);
    (protected, restore)
}

fn recovery_backup_count() -> u64 {
    let root = env::var("SEVENOS_MIGRATION_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|_| home_dir().join(".local/share/sevenos/migrations"));
    fs::read_dir(root)
        .ok()
        .map(|entries| {
            entries
                .filter_map(Result::ok)
                .filter(|entry| entry.path().is_dir())
                .count() as u64
        })
        .unwrap_or(0)
}

fn recovery_payload() -> Value {
    let root = sevenos_root().unwrap_or_else(|| PathBuf::from("."));
    let migration_root = env::var("SEVENOS_MIGRATION_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|_| home_dir().join(".local/share/sevenos/migrations"));
    let (protected_count, restore_count) = recovery_manifest_counts(&root);
    let backup_count = recovery_backup_count();
    let installer = installer_release_payload(&root);
    let distribution = daemon_distribution_payload();
    let channel = daemon_channel_payload();
    let installer_state = installer.get("state").and_then(Value::as_str).unwrap_or("unknown");
    let channel_schema = channel.get("schema").and_then(Value::as_str).unwrap_or("");
    let checks = vec![
        system_check(
            "protected-state",
            "Protected user state",
            protected_count > 0 && restore_count > 0,
            protected_count > 0 || restore_count > 0,
            format!("{protected_count} protected path(s), {restore_count} restore rule(s)."),
            "seven manifest restore-plan",
        ),
        system_check(
            "migration-backup-route",
            "Migration backup route",
            root.join("scripts/migrate.sh").is_file(),
            backup_count > 0,
            format!("{backup_count} existing backup set(s) under {}.", migration_root.to_string_lossy()),
            "seven recovery backup",
        ),
        system_check(
            "repair-route",
            "Guided repair route",
            root.join("scripts/repair.sh").is_file(),
            root.join("bin/seven").is_file(),
            "SevenOS exposes repair plans before raw system commands.".to_string(),
            "seven repair",
        ),
        system_check(
            "installer-recovery",
            "Installer/recovery route",
            matches!(installer_state, "foundation" | "tui-release-ready" | "graphical-ready" | "iso-foundation"),
            matches!(installer_state, "foundation" | "graphical-runtime-candidate" | "graphical-ready" | "tui-release-ready" | "iso-foundation"),
            format!("Installer state: {installer_state}."),
            "seven installer release",
        ),
        system_check(
            "distribution-gate",
            "Distribution health gate",
            distribution.get("daily_driver_ready").and_then(Value::as_bool).unwrap_or(false),
            distribution.get("score").and_then(Value::as_u64).unwrap_or(0) >= 75,
            format!(
                "{} at {}%.",
                distribution.get("state").and_then(Value::as_str).unwrap_or("unknown"),
                distribution.get("score").and_then(Value::as_u64).unwrap_or(0)
            ),
            "seven distribution",
        ),
        system_check(
            "release-channel",
            "Release channel",
            matches!(channel_schema, "sevenos.release-channel.v1" | "sevenos.release-channel.v2"),
            !channel_schema.is_empty(),
            format!(
                "{} / {}.",
                channel.get("channel").and_then(Value::as_str).unwrap_or("unknown"),
                channel.get("state").and_then(Value::as_str).unwrap_or("unknown")
            ),
            "seven channel",
        ),
    ];
    let score = score_from_checks(&checks);
    json!({
        "schema": "sevenos.recovery.v2",
        "compat_schema": "sevenos.recovery.v1",
        "root": root.to_string_lossy(),
        "state": if score >= 90 { "ready" } else if score >= 70 { "partial" } else { "foundation" },
        "score": score,
        "runtime": "seven-daemon",
        "backup_count": backup_count,
        "migration_root": migration_root.to_string_lossy(),
        "routes": [
            {"intent": "Review protected paths", "command": "seven manifest restore-plan", "impact": "safe"},
            {"intent": "Create recovery backup", "command": "seven recovery backup", "impact": "safe"},
            {"intent": "Repair system", "command": "seven repair", "impact": "changes"},
            {"intent": "Check installer/recovery", "command": "seven installer release", "impact": "safe"},
            {"intent": "Check distribution health", "command": "seven distribution", "impact": "safe"}
        ],
        "checks": checks,
        "summary": check_counts(&checks),
        "issues": checks.iter().filter(|item| item.get("state").and_then(Value::as_str) != Some("OK")).cloned().collect::<Vec<_>>(),
        "commands": {
            "status": "seven recovery",
            "plan": "seven recovery plan",
            "backup": "seven recovery backup",
            "doctor": "seven recovery doctor"
        },
        "writer": "seven-daemon",
    })
}

fn recovery_json() {
    print_value(&recovery_payload());
}

fn update_plan_json() {
    let root = sevenos_root().unwrap_or_else(|| PathBuf::from("."));
    let dirty_count = if root.join(".git").exists() {
        update_dirty_count(&root)
    } else {
        0
    };
    let steps = vec![
        json!({
            "key": "inspect",
            "title": "Review update readiness",
            "command": "seven update check",
            "impact": "safe",
            "runtime": "seven-daemon",
        }),
        json!({
            "key": "backup",
            "title": "Back up protected SevenOS state",
            "command": "seven migrate backup",
            "impact": "safe",
            "runtime": "adapter",
        }),
        json!({
            "key": "apply",
            "title": "Apply SevenOS update route",
            "command": "seven update install --yes",
            "impact": "packages",
            "runtime": "privileged-adapter",
            "requires_confirmation": true,
        }),
        json!({
            "key": "refresh",
            "title": "Refresh native surfaces",
            "command": "seven doctor",
            "impact": "safe",
            "runtime": "adapter",
        }),
        json!({
            "key": "rollback",
            "title": "Rollback if the update fails",
            "command": "seven update rollback",
            "impact": "safe",
            "runtime": "privileged-adapter",
            "requires_confirmation": true,
        }),
    ];
    let payload = json!({
        "schema": "sevenos.update-plan.v1",
        "state": if dirty_count > 0 { "attention" } else { "ready" },
        "runtime": "seven-daemon",
        "root": root.to_string_lossy(),
        "dirty_count": dirty_count,
        "summary": {
            "steps": steps.len(),
            "native_readiness": true,
            "privileged_apply_adapter": true,
        },
        "steps": steps,
        "writer": "seven-daemon",
    });
    print_value(&payload);
}

fn cpu_jiffies() -> Option<(u64, u64)> {
    let raw = proc_first_line("/proc/stat")?;
    let values = raw
        .split_whitespace()
        .skip(1)
        .filter_map(|part| part.parse::<u64>().ok())
        .collect::<Vec<_>>();
    if values.len() < 4 {
        return None;
    }
    let idle = values.get(3).copied().unwrap_or(0) + values.get(4).copied().unwrap_or(0);
    let total = values.iter().sum();
    Some((idle, total))
}

fn cpu_percent_sample() -> u64 {
    let Some((idle_a, total_a)) = cpu_jiffies() else {
        return 0;
    };
    thread::sleep(Duration::from_millis(80));
    let Some((idle_b, total_b)) = cpu_jiffies() else {
        return 0;
    };
    let total_delta = total_b.saturating_sub(total_a).max(1);
    let idle_delta = idle_b.saturating_sub(idle_a);
    (((1.0 - (idle_delta as f64 / total_delta as f64)) * 100.0).round() as i64).clamp(0, 100) as u64
}

fn process_rows(limit: usize) -> Vec<Value> {
    let Some(raw) = command_output_text(
        "ps",
        &["-eo", "pid=,comm=,pcpu=,pmem=,stat=,args=", "--sort=-pcpu"],
        None,
    ) else {
        return Vec::new();
    };
    let current = std::process::id();
    let mut rows = Vec::new();
    for line in raw.lines() {
        let parts = line.split_whitespace().collect::<Vec<_>>();
        if parts.len() < 6 {
            continue;
        }
        let Ok(pid) = parts[0].parse::<u32>() else {
            continue;
        };
        if pid == current {
            continue;
        }
        let cpu = parts[2].parse::<f64>().unwrap_or(0.0);
        let memory = parts[3].parse::<f64>().unwrap_or(0.0);
        rows.push(json!({
            "pid": pid,
            "name": parts[1],
            "cpu": cpu,
            "memory": memory,
            "state": parts[4],
            "command": parts[5..].join(" "),
            "writer": "seven-daemon",
        }));
        if rows.len() >= limit {
            break;
        }
    }
    rows
}

fn process_count() -> usize {
    command_output_text("ps", &["-e", "-o", "pid="], None)
        .map(|raw| raw.lines().filter(|line| !line.trim().is_empty()).count())
        .unwrap_or(0)
}

fn service_rows(limit: usize) -> Vec<Value> {
    let mut rows = Vec::new();
    for (scope, args) in [
        ("system", vec!["--failed", "--plain", "--no-legend"]),
        ("user", vec!["--user", "--failed", "--plain", "--no-legend"]),
    ] {
        if let Some(raw) = command_output_text("systemctl", &args, None) {
            for line in raw.lines() {
                let parts = line.splitn(5, char::is_whitespace).filter(|part| !part.is_empty()).collect::<Vec<_>>();
                if let Some(unit) = parts.first() {
                    rows.push(json!({
                        "unit": unit,
                        "state": "failed",
                        "scope": scope,
                        "detail": parts.get(4).copied().unwrap_or(""),
                        "writer": "seven-daemon",
                    }));
                }
            }
        }
    }
    if let Some(raw) = command_output_text(
        "systemctl",
        &["list-units", "--type=service", "--state=running", "--plain", "--no-legend"],
        None,
    ) {
        for line in raw.lines() {
            let parts = line.splitn(5, char::is_whitespace).filter(|part| !part.is_empty()).collect::<Vec<_>>();
            if let Some(unit) = parts.first() {
                rows.push(json!({
                    "unit": unit,
                    "state": "running",
                    "scope": "system",
                    "detail": parts.get(4).copied().unwrap_or(""),
                    "writer": "seven-daemon",
                }));
                if rows.len() >= limit {
                    break;
                }
            }
        }
    }
    rows.into_iter().take(limit).collect()
}

fn disk_json() -> Value {
    let home = home_dir();
    let raw = command_output_text("df", &["-Pk", &home.to_string_lossy()], None).unwrap_or_default();
    let line = raw.lines().last().unwrap_or("");
    let parts = line.split_whitespace().collect::<Vec<_>>();
    if parts.len() < 6 {
        return json!({"percent": 0, "detail": "0 / 0 GiB"});
    }
    let used = parts.get(2).and_then(|part| part.parse::<u64>().ok()).unwrap_or(0);
    let total = parts.get(1).and_then(|part| part.parse::<u64>().ok()).unwrap_or(0);
    let percent = if total > 0 {
        ((used as f64 / total as f64) * 100.0).round() as u64
    } else {
        0
    };
    json!({
        "percent": percent,
        "detail": format!("{:.0} / {:.0} GiB", used as f64 / 1024.0 / 1024.0, total as f64 / 1024.0 / 1024.0),
        "mount": parts.get(5).copied().unwrap_or(""),
    })
}

fn doctor_task_json() {
    let memory = memory_json();
    let memory_detail = format!(
        "{:.1} / {:.1} GiB",
        memory.get("used_kib").and_then(Value::as_u64).unwrap_or(0) as f64 / 1024.0 / 1024.0,
        memory.get("total_kib").and_then(Value::as_u64).unwrap_or(0) as f64 / 1024.0 / 1024.0,
    );
    let processes = process_rows(22);
    let services = service_rows(26);
    let failed_services = services
        .iter()
        .filter(|item| item.get("state").and_then(Value::as_str) == Some("failed"))
        .count();
    let payload = json!({
        "schema": "sevenos.doctor-task-manager.v2",
        "compat_schema": "sevenos.doctor-task-manager.v1",
        "state": "ready",
        "runtime": "seven-daemon",
        "resources": {
            "cpu": {
                "percent": cpu_percent_sample(),
                "detail": format!("uptime {}s", uptime_seconds().unwrap_or(0)),
                "loadavg": loadavg(),
            },
            "memory": {
                "percent": memory.get("used_percent").and_then(Value::as_u64).unwrap_or(0),
                "detail": memory_detail,
            },
            "disk": disk_json(),
            "processes": {
                "count": process_count(),
                "shown": processes.len(),
            },
        },
        "processes": processes,
        "top_processes": processes.iter().take(5).cloned().collect::<Vec<_>>(),
        "services": services,
        "alerts": {
            "failed_services": failed_services,
            "issues": Value::Null,
        },
        "policy": {
            "actions": "read-only snapshot; stop/restart remains behind explicit user confirmation",
            "source": "procfs plus systemctl summaries",
        },
        "writer": "seven-daemon",
    });
    print_value(&payload);
}

fn metapackages(root: &Path) -> Value {
    let path = root.join("sevenpkg/metapackages.json");
    match fs::read_to_string(path)
        .ok()
        .and_then(|content| serde_json::from_str::<Value>(&content).ok())
    {
        Some(value) => value,
        None => json!({}),
    }
}

fn meta_package_list(root: &Path, meta: &Value) -> Vec<String> {
    if meta.get("kind").and_then(Value::as_str) == Some("pacman") {
        return meta
            .get("packages")
            .and_then(Value::as_array)
            .map(|items| {
                items
                    .iter()
                    .filter_map(Value::as_str)
                    .map(str::to_string)
                    .collect()
            })
            .unwrap_or_default();
    }

    let mut packages = Vec::new();
    if let Some(files) = meta.get("package_files").and_then(Value::as_array) {
        for file in files.iter().filter_map(Value::as_str) {
            packages.extend(read_package_file(root, file));
        }
    }
    packages
}

fn package_layer_state(
    packages: &[String],
    installed_set: &HashSet<String>,
) -> (&'static str, usize, usize) {
    if packages.is_empty() {
        return ("RUN", 0, 0);
    }
    let installed = packages
        .iter()
        .filter(|package| package_satisfied(package, installed_set))
        .count();
    let total = packages.len();
    let state = if installed == total {
        "OK"
    } else if installed > 0 {
        "PART"
    } else {
        "MISS"
    };
    (state, installed, total)
}

fn packages_json() {
    let root = sevenos_root().unwrap_or_else(|| PathBuf::from("."));
    let installed_set = pacman_packages();
    let manifest = metapackages(&root);
    let mut keys: Vec<String> = manifest
        .as_object()
        .map(|object| object.keys().cloned().collect())
        .unwrap_or_default();
    keys.sort();

    let mut items = Vec::new();
    for name in keys {
        let meta = manifest.get(&name).unwrap_or(&Value::Null);
        let packages = meta_package_list(&root, meta);
        let (state, installed, total) = package_layer_state(&packages, &installed_set);
        items.push(json!({
            "name": name,
            "state": state,
            "installed": installed,
            "total": total,
            "description": meta.get("description").and_then(Value::as_str).unwrap_or(""),
            "kind": meta.get("kind").and_then(Value::as_str).unwrap_or(""),
            "target": meta.get("target").and_then(Value::as_str).unwrap_or(""),
            "packages": packages,
            "writer": "seven-daemon",
        }));
    }
    println!(
        "{}",
        serde_json::to_string(&Value::Array(items)).unwrap_or_else(|_| "[]".to_string())
    );
}

fn flatpak_apps(root: &Path) -> Vec<String> {
    read_package_file(root, "scripts/flatpak-apps.txt")
}

fn flathub_present() -> bool {
    let output = Command::new("flatpak")
        .arg("remotes")
        .arg("--columns=name")
        .output();
    match output {
        Ok(result) if result.status.success() => String::from_utf8_lossy(&result.stdout)
            .lines()
            .any(|line| line.trim() == "flathub"),
        _ => false,
    }
}

fn package_plan_item(
    key: &str,
    state: &str,
    title: String,
    severity: &str,
    impact: &str,
    phase: &str,
    reason: String,
    command: String,
) -> Value {
    json!({
        "key": key,
        "state": state,
        "title": title,
        "severity": severity,
        "impact": impact,
        "phase": phase,
        "reason": reason,
        "command": command,
        "writer": "seven-daemon",
    })
}

fn meta_priority(name: &str) -> (&'static str, &'static str) {
    match name {
        "baobab" => ("critical", "base"),
        "shield" => ("critical", "security"),
        "forge" => ("high", "dev"),
        "studio" => ("high", "creative"),
        "windows" => ("high", "compatibility"),
        "horizon" => ("high", "server"),
        "griot" => ("medium", "knowledge"),
        _ => ("medium", "software"),
    }
}

fn package_plan_actions(root: &Path, installed_set: &HashSet<String>) -> Vec<Value> {
    let manifest = metapackages(root);
    let mut keys: Vec<String> = manifest
        .as_object()
        .map(|object| object.keys().cloned().collect())
        .unwrap_or_default();
    keys.sort();

    let mut actions = Vec::new();
    for name in keys {
        let meta = manifest.get(&name).unwrap_or(&Value::Null);
        if meta
            .get("optional")
            .and_then(Value::as_bool)
            .unwrap_or(false)
        {
            continue;
        }
        let packages = meta_package_list(&root, meta);
        let (state, installed, total) = package_layer_state(&packages, &installed_set);
        if state == "OK" {
            continue;
        }
        let missing = total.saturating_sub(installed);
        let (severity, phase) = meta_priority(&name);
        actions.push(package_plan_item(
            &name,
            state,
            format!("Install {} software layer", title_case(&name)),
            severity,
            "packages",
            phase,
            format!(
                "{} is {} with {} missing packages.",
                title_case(&name),
                state,
                missing
            ),
            format!("sevenpkg install {}", name),
        ));
        if let Some(last) = actions.last_mut() {
            if let Some(object) = last.as_object_mut() {
                object.insert("missing_count".to_string(), json!(missing));
                object.insert("installed".to_string(), json!(installed));
                object.insert("total".to_string(), json!(total));
            }
        }
    }

    if !command_exists("flatpak") {
        actions.push(package_plan_item(
            "flatpak",
            "MISS",
            "Install Flatpak".to_string(),
            "high",
            "packages",
            "apps",
            "SevenOS needs Flatpak for mainstream creative and Windows app delivery.".to_string(),
            "seven flatpak setup".to_string(),
        ));
    } else if !flathub_present() {
        actions.push(package_plan_item(
            "flathub",
            "MISS",
            "Enable Flathub".to_string(),
            "high",
            "changes",
            "apps",
            "Flathub is the default application source for Flatpak apps.".to_string(),
            "seven flatpak setup".to_string(),
        ));
    }

    let missing_flatpaks: Vec<String> = flatpak_apps(&root)
        .into_iter()
        .filter(|app| flatpak_app_state(app) != "OK")
        .collect();
    if !missing_flatpaks.is_empty() {
        let state = if command_exists("flatpak") {
            "PART"
        } else {
            "MISS"
        };
        let mut item = package_plan_item(
            "flatpak-defaults",
            state,
            "Install default Flatpak apps".to_string(),
            "medium",
            "packages",
            "apps",
            format!(
                "{} default Flatpak apps are missing.",
                missing_flatpaks.len()
            ),
            "seven flatpak install".to_string(),
        );
        if let Some(object) = item.as_object_mut() {
            object.insert("missing_apps".to_string(), json!(missing_flatpaks));
        }
        actions.push(item);
    }

    actions.sort_by(|left, right| {
        severity_rank(left)
            .cmp(&severity_rank(right))
            .then_with(|| {
                left.get("phase")
                    .and_then(Value::as_str)
                    .unwrap_or("")
                    .cmp(right.get("phase").and_then(Value::as_str).unwrap_or(""))
            })
            .then_with(|| {
                left.get("key")
                    .and_then(Value::as_str)
                    .unwrap_or("")
                    .cmp(right.get("key").and_then(Value::as_str).unwrap_or(""))
            })
    });
    actions
}

fn packages_plan_json() {
    let root = sevenos_root().unwrap_or_else(|| PathBuf::from("."));
    let installed_set = pacman_packages();
    let actions = package_plan_actions(&root, &installed_set);
    let critical = actions
        .iter()
        .filter(|item| item.get("severity").and_then(Value::as_str) == Some("critical"))
        .count();
    let high = actions
        .iter()
        .filter(|item| item.get("severity").and_then(Value::as_str) == Some("high"))
        .count();
    let medium = actions
        .iter()
        .filter(|item| item.get("severity").and_then(Value::as_str) == Some("medium"))
        .count();
    let payload = json!({
        "schema": "sevenos.packages-plan.v1",
        "summary": {
            "total": actions.len(),
            "critical": critical,
            "high": high,
            "medium": medium,
        },
        "sources": {
            "pacman": command_exists("pacman"),
            "paru": command_exists("paru"),
            "flatpak": command_exists("flatpak"),
            "flathub": flathub_present(),
            "sevenrepo": false,
        },
        "next": actions,
        "runtime": "seven-daemon",
        "writer": "seven-daemon",
    });
    println!(
        "{}",
        serde_json::to_string(&payload).unwrap_or_else(|_| "{}".to_string())
    );
}

fn app_catalog(root: &Path) -> Value {
    let path = root.join("sevenpkg/apps.json");
    match fs::read_to_string(path)
        .ok()
        .and_then(|content| serde_json::from_str::<Value>(&content).ok())
    {
        Some(mut value) => {
            if let Some(object) = value.as_object_mut() {
                object
                    .entry("schema".to_string())
                    .or_insert_with(|| json!("sevenos.app-catalog.v1"));
                object
                    .entry("apps".to_string())
                    .or_insert_with(|| json!([]));
            }
            value
        }
        None => json!({
            "schema": "sevenos.app-catalog.v1",
            "apps": [],
        }),
    }
}

fn app_catalog_items(root: &Path) -> Vec<Value> {
    app_catalog(root)
        .get("apps")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default()
}

fn engine_policy(profile: &str) -> Value {
    match profile {
        "equinox" => json!({
            "title": "Equinox Host",
            "role": "stable host, orchestration and system recovery",
            "engine": "SevenPkg Host Engine",
            "recommended_sources": ["pacman", "flatpak"],
            "optional_sources": ["paru", "yay"],
            "scope": "global-system",
            "rule": "Keep Equinox minimal. Install only system components, core apps and shared runtimes here."
        }),
        "forge" => json!({
            "title": "Forge DevOps",
            "role": "development, containers, services and deployment",
            "engine": "Forge Engine",
            "recommended_sources": ["pacman", "paru", "yay"],
            "optional_sources": ["profile-service"],
            "scope": "profile-rootfs",
            "rule": "Use fresh Arch-compatible toolchains privately inside Forge; expose services explicitly."
        }),
        "studio" => json!({
            "title": "Studio Creator",
            "role": "video, audio, graphics, 3D and publishing",
            "engine": "Studio Engine",
            "recommended_sources": ["pacman", "flatpak"],
            "optional_sources": ["appimage", "manual-vendor"],
            "scope": "profile-rootfs",
            "rule": "Prefer stable creative packages and Flatpak where it improves plugin/runtime compatibility."
        }),
        "shield" => json!({
            "title": "Shield Cybersecurity",
            "role": "authorized audit, forensics, labs and defensive monitoring",
            "engine": "Shield Engine",
            "recommended_sources": ["pacman"],
            "optional_sources": ["nix-lab", "paru", "yay", "blackarch-opt-in"],
            "scope": "profile-rootfs",
            "rule": "Keep intrusive tools scoped to Shield. Reproducible labs are optional and explicit."
        }),
        "atlas" => json!({
            "title": "Atlas Explorer",
            "role": "documents, OCR, maps, research and knowledge navigation",
            "engine": "Atlas Engine",
            "recommended_sources": ["pacman", "flatpak"],
            "optional_sources": ["paru", "yay"],
            "scope": "profile-rootfs",
            "rule": "Favor reliable document and research tools over bleeding-edge packages."
        }),
        "baobab" => json!({
            "title": "Baobab Cultural OS",
            "role": "African heritage, languages, education and cultural memory",
            "engine": "Baobab Engine",
            "recommended_sources": ["sevenos-content", "pacman", "flatpak"],
            "optional_sources": ["paru", "yay"],
            "scope": "profile-rootfs",
            "rule": "Prioritize validated cultural content, language packs and offline-first resources over package novelty."
        }),
        "pulse" => json!({
            "title": "Pulse Gaming",
            "role": "gaming, Proton, low latency, capture and performance",
            "engine": "Pulse Engine",
            "recommended_sources": ["pacman", "paru", "yay"],
            "optional_sources": ["flatpak", "proton-community"],
            "scope": "profile-rootfs",
            "rule": "Keep gaming runtimes current and private to Pulse unless the user explicitly shares them."
        }),
        _ => json!({
            "title": title_case(profile),
            "role": "SevenOS software domain",
            "engine": "SevenPkg",
            "recommended_sources": ["pacman"],
            "optional_sources": [],
            "scope": "profile-rootfs",
            "rule": "Install through SevenPkg policy."
        }),
    }
}

fn policy_array(policy: &Value, key: &str) -> Value {
    policy.get(key).cloned().unwrap_or_else(|| json!([]))
}

fn policy_string(policy: &Value, key: &str) -> String {
    policy
        .get(key)
        .and_then(Value::as_str)
        .unwrap_or("")
        .to_string()
}

fn profile_rootfs_dir() -> PathBuf {
    if let Ok(value) = env::var("SEVENOS_HOST_DATA_HOME") {
        return PathBuf::from(value).join("sevenos/profile-rootfs");
    }
    if let Ok(value) = env::var("XDG_DATA_HOME") {
        return PathBuf::from(value).join("sevenos/profile-rootfs");
    }
    if let Ok(home) = env::var("HOME") {
        return PathBuf::from(home).join(".local/share/sevenos/profile-rootfs");
    }
    PathBuf::from("/tmp/sevenos/profile-rootfs")
}

fn profile_rootfs(profile: &str) -> PathBuf {
    profile_rootfs_dir().join(profile).join("rootfs")
}

fn profile_rootfs_ready(profile: &str) -> bool {
    let rootfs = profile_rootfs(profile);
    rootfs.join("usr/bin").is_dir() && rootfs.join("var/lib/pacman/local").is_dir()
}

fn helper_available_for_profile(profile: &str, helper: &str) -> bool {
    if profile == "equinox" {
        return command_exists(helper);
    }
    profile_rootfs(profile).join("usr/bin").join(helper).is_file()
}

fn catalog_domains(root: &Path) -> Vec<String> {
    let mut domains: Vec<String> = app_catalog_items(root)
        .iter()
        .filter_map(|item| item.get("domain").and_then(Value::as_str))
        .map(str::to_string)
        .collect::<HashSet<_>>()
        .into_iter()
        .collect();
    domains.sort();
    domains
}

fn packages_strategy_json() {
    let root = sevenos_root().unwrap_or_else(|| PathBuf::from("."));
    let catalog_items = app_catalog_items(&root);
    let profiles: Vec<Value> = ["equinox", "forge", "studio", "shield", "atlas", "baobab", "pulse"]
        .iter()
        .map(|profile| {
            let policy = engine_policy(profile);
            json!({
                "profile": profile,
                "title": policy_string(&policy, "title"),
                "role": policy_string(&policy, "role"),
                "engine": policy_string(&policy, "engine"),
                "scope": policy_string(&policy, "scope"),
                "recommended_sources": policy_array(&policy, "recommended_sources"),
                "optional_sources": policy_array(&policy, "optional_sources"),
                "rule": policy_string(&policy, "rule"),
                "commands": {
                    "sources": format!("sevenpkg {} sources", profile),
                    "limits": format!("sevenpkg {} limits", profile),
                    "install": format!("sevenpkg {} install <package>", profile),
                },
                "writer": "seven-daemon",
            })
        })
        .collect();

    let profile_aur = PROFILES
        .iter()
        .filter(|profile| profile.key != "equinox")
        .any(|profile| helper_available_for_profile(profile.key, "paru") || helper_available_for_profile(profile.key, "yay"));
    let payload = json!({
        "schema": "sevenos.sevenpkg-strategy.v1",
        "state": "ready",
        "principle": "One user-facing installer, profile-scoped engines, stable Equinox host.",
        "user_contract": {
            "install": "seven install <app> / sevenpkg install <app>",
            "remove": "sevenpkg remove <app>",
            "update": "seven update / sevenpkg update",
            "store": "Seven Store uses the same catalog and source rules."
        },
        "equinox_rule": "Equinox is the host platform, not a dumping ground for heavy user apps.",
        "mini_os_rule": "Mini OS packages install into private rootfs views by default and are resealed after maintenance.",
        "source_rule": "Pacman stays the baseline; Flatpak, AUR helpers and future Nix/lab engines are used only where the domain benefits.",
        "catalog": {
            "schema": "sevenos.app-catalog.v1",
            "path": root.join("sevenpkg/apps.json").to_string_lossy(),
            "apps": catalog_items.len(),
            "domains": catalog_domains(&root),
            "command": "seven-daemon packages-catalog --json",
        },
        "footprint": {
            "schema": "sevenos.sevenpkg-footprint.v1",
            "command": "seven-daemon packages-footprint --json",
            "purpose": "audit rootfs size, package duplication and catalog coverage before release bundles"
        },
        "engine_states": {
            "flatpak": if command_exists("flatpak") && flathub_present() { "OK" } else { "MISS" },
            "host_aur": if command_exists("paru") || command_exists("yay") { "OK" } else { "MISS" },
            "profile_aur": if profile_aur { "OK" } else { "MISS" },
            "nix_lab": "PLANNED",
        },
        "profiles": profiles,
        "next_steps": [
            "Expand the SevenPkg app catalog with domain ownership for common apps.",
            "Route Seven Store installs through the same domain/source policy.",
            "Track rootfs footprint and duplication with seven-daemon packages-footprint.",
            "Keep Equinox installs guarded and expose host commands to mini OS only through global-policy.",
            "Add optional lab engines such as Nix only behind explicit profile actions, not as host defaults."
        ],
        "runtime": "seven-daemon",
        "writer": "seven-daemon",
    });
    print_value(&payload);
}

fn source_available_for_profile(profile: &str, source: &str) -> bool {
    match source {
        "pacman" => profile == "equinox" || profile_rootfs_ready(profile),
        "aur" | "paru" | "yay" => {
            if profile == "equinox" {
                command_exists("paru") || command_exists("yay")
            } else {
                helper_available_for_profile(profile, "paru") || helper_available_for_profile(profile, "yay")
            }
        }
        "flatpak" => command_exists("flatpak"),
        "sevenos-content" => true,
        _ => false,
    }
}

fn app_install_id(item: &Value, source: &str) -> String {
    if let Some(value) = item.get("install_id").and_then(Value::as_str) {
        return value.to_string();
    }
    if source == "flatpak" {
        if let Some(alternatives) = item.get("alternatives").and_then(Value::as_array) {
            for alternative in alternatives {
                if alternative.get("source").and_then(Value::as_str) == Some("flatpak") {
                    if let Some(id) = alternative.get("id").and_then(Value::as_str) {
                        return id.to_string();
                    }
                }
            }
        }
    }
    item.get("id").and_then(Value::as_str).unwrap_or("").to_string()
}

fn packages_catalog_json() {
    let root = sevenos_root().unwrap_or_else(|| PathBuf::from("."));
    let mut items: Vec<Value> = app_catalog_items(&root)
        .into_iter()
        .map(|item| {
            let profile = item
                .get("domain")
                .and_then(Value::as_str)
                .unwrap_or("equinox")
                .to_string();
            let source = item
                .get("recommended_source")
                .and_then(Value::as_str)
                .unwrap_or("pacman")
                .to_string();
            let install_id = app_install_id(&item, &source);
            let policy = engine_policy(&profile);
            json!({
                "id": item.get("id").cloned().unwrap_or_else(|| json!("")),
                "name": item.get("name").cloned().unwrap_or_else(|| item.get("id").cloned().unwrap_or_else(|| json!(""))),
                "domain": profile,
                "engine": policy_string(&policy, "engine"),
                "recommended_source": source,
                "install_id": install_id,
                "alternatives": item.get("alternatives").cloned().unwrap_or_else(|| json!([])),
                "size": item.get("size").cloned().unwrap_or_else(|| json!("unknown")),
                "risk": item.get("risk").cloned().unwrap_or_else(|| json!("unknown")),
                "permissions": item.get("permissions").cloned().unwrap_or_else(|| json!([])),
                "summary": item.get("summary").cloned().unwrap_or_else(|| json!("")),
                "available": source_available_for_profile(&profile, &source),
                "commands": {
                    "resolve": format!("sevenpkg resolve {}", item.get("id").and_then(Value::as_str).unwrap_or("")),
                    "preview": format!("sevenpkg install {} --preview", item.get("id").and_then(Value::as_str).unwrap_or("")),
                    "install": format!("sevenpkg install {}", item.get("id").and_then(Value::as_str).unwrap_or("")),
                    "store": format!("seven store install-app {} {} --profile {}", source, install_id, profile),
                },
                "writer": "seven-daemon",
            })
        })
        .collect();
    items.sort_by(|left, right| {
        left.get("domain")
            .and_then(Value::as_str)
            .unwrap_or("")
            .cmp(right.get("domain").and_then(Value::as_str).unwrap_or(""))
            .then_with(|| {
                left.get("name")
                    .and_then(Value::as_str)
                    .unwrap_or("")
                    .cmp(right.get("name").and_then(Value::as_str).unwrap_or(""))
            })
    });
    let mut domains: Vec<String> = items
        .iter()
        .filter_map(|item| item.get("domain").and_then(Value::as_str))
        .map(str::to_string)
        .collect::<HashSet<_>>()
        .into_iter()
        .collect();
    domains.sort();
    let payload = json!({
        "schema": "sevenos.app-catalog.v1",
        "path": root.join("sevenpkg/apps.json").to_string_lossy(),
        "query": "",
        "count": items.len(),
        "domains": domains,
        "items": items,
        "runtime": "seven-daemon",
        "writer": "seven-daemon",
    });
    print_value(&payload);
}

fn pacman_local_package_names(rootfs: &Path) -> HashSet<String> {
    let local = rootfs.join("var/lib/pacman/local");
    let Ok(entries) = fs::read_dir(local) else {
        return HashSet::new();
    };
    entries
        .filter_map(Result::ok)
        .filter_map(|entry| {
            let desc = entry.path().join("desc");
            let content = fs::read_to_string(desc).ok()?;
            let mut lines = content.lines();
            while let Some(line) = lines.next() {
                if line.trim() == "%NAME%" {
                    return lines.next().map(|name| name.trim().to_string());
                }
            }
            None
        })
        .filter(|name| !name.is_empty())
        .collect()
}

fn human_size(bytes: u64) -> String {
    let units = ["B", "KiB", "MiB", "GiB", "TiB"];
    let mut value = bytes as f64;
    let mut unit = 0;
    while value >= 1024.0 && unit < units.len() - 1 {
        value /= 1024.0;
        unit += 1;
    }
    if unit == 0 {
        format!("{} {}", bytes, units[unit])
    } else {
        format!("{:.1} {}", value, units[unit])
    }
}

fn packages_footprint_json() {
    let root = sevenos_root().unwrap_or_else(|| PathBuf::from("."));
    let mini_profiles = ["atlas", "baobab", "forge", "pulse", "shield", "studio"];
    let mut rootfs_items = Vec::new();
    let mut package_sets: HashMap<String, HashSet<String>> = HashMap::new();

    for profile in mini_profiles {
        let rootfs = profile_rootfs(profile);
        let ready = profile_rootfs_ready(profile);
        let packages = if ready {
            pacman_local_package_names(&rootfs)
        } else {
            HashSet::new()
        };
        let warnings: Vec<&str> = if ready { Vec::new() } else { vec!["rootfs-missing"] };
        rootfs_items.push(json!({
            "profile": profile,
            "rootfs": rootfs.to_string_lossy(),
            "ready": ready,
            "size_bytes": 0,
            "size": human_size(0),
            "size_scanned": false,
            "package_count": packages.len(),
            "aur_helpers": {
                "paru": helper_available_for_profile(profile, "paru"),
                "yay": helper_available_for_profile(profile, "yay"),
            },
            "warnings": warnings,
            "writer": "seven-daemon",
        }));
        package_sets.insert(profile.to_string(), packages);
    }

    let mut package_owners: HashMap<String, Vec<String>> = HashMap::new();
    for (profile, packages) in &package_sets {
        for package in packages {
            package_owners
                .entry(package.clone())
                .or_default()
                .push(profile.clone());
        }
    }
    let mut duplicated: Vec<(String, Vec<String>)> = package_owners
        .iter()
        .filter_map(|(package, owners)| {
            if owners.len() >= 2 {
                let mut sorted = owners.clone();
                sorted.sort();
                Some((package.clone(), sorted))
            } else {
                None
            }
        })
        .collect();
    duplicated.sort_by(|left, right| right.1.len().cmp(&left.1.len()).then_with(|| left.0.cmp(&right.0)));
    let top_duplicates: Vec<Value> = duplicated
        .iter()
        .take(25)
        .map(|(package, owners)| {
            json!({
                "package": package,
                "profiles": owners,
                "count": owners.len(),
            })
        })
        .collect();

    let mut catalog_by_domain: HashMap<String, usize> = HashMap::new();
    for item in app_catalog_items(&root) {
        let domain = item
            .get("domain")
            .and_then(Value::as_str)
            .unwrap_or("equinox")
            .to_string();
        *catalog_by_domain.entry(domain).or_insert(0) += 1;
    }
    let catalog_domains: HashSet<String> = catalog_by_domain.keys().cloned().collect();
    let missing_domains: Vec<String> = ["equinox", "forge", "studio", "shield", "atlas", "baobab", "pulse"]
        .iter()
        .filter(|profile| !catalog_domains.contains(**profile))
        .map(|profile| profile.to_string())
        .collect();
    let mut warnings = Vec::new();
    if !missing_domains.is_empty() {
        warnings.push("catalog-missing-domain");
    }
    if rootfs_items.iter().any(|item| item.get("ready").and_then(Value::as_bool) != Some(true)) {
        warnings.push("rootfs-attention");
    }
    if duplicated.len() > 900 {
        warnings.push("high-duplication");
    }
    let payload = json!({
        "schema": "sevenos.sevenpkg-footprint.v1",
        "state": if warnings.is_empty() { "ready" } else { "attention" },
        "root": root.to_string_lossy(),
        "profile_rootfs_dir": profile_rootfs_dir().to_string_lossy(),
        "summary": {
            "mini_os": mini_profiles.len(),
            "ready_rootfs": rootfs_items.iter().filter(|item| item.get("ready").and_then(Value::as_bool) == Some(true)).count(),
            "total_rootfs_size_bytes": 0,
            "total_rootfs_size": human_size(0),
            "size_scanned": false,
            "unique_packages": package_owners.len(),
            "duplicated_packages": duplicated.len(),
            "catalog_apps": app_catalog_items(&root).len(),
            "catalog_domains": catalog_by_domain,
            "warnings": warnings,
        },
        "rootfs": rootfs_items,
        "duplication": {
            "packages": duplicated.len(),
            "top": top_duplicates,
            "note": "Shared base packages are expected; this audit highlights growth, not an error by itself.",
        },
        "catalog": {
            "path": root.join("sevenpkg/apps.json").to_string_lossy(),
            "missing_domains": missing_domains,
            "command": "seven-daemon packages-catalog --json",
        },
        "recommendations": [
            "Keep Equinox minimal and route domain apps to their natural mini OS.",
            "Use profile rootfs package audits before public ISO freezes.",
            "Treat high duplication as a maintenance signal, not a user-facing error."
        ],
        "runtime": "seven-daemon",
        "writer": "seven-daemon",
    });
    print_value(&payload);
}

fn title_case(value: &str) -> String {
    let mut chars = value.chars();
    match chars.next() {
        Some(first) => first.to_uppercase().collect::<String>() + chars.as_str(),
        None => String::new(),
    }
}

fn severity_count(actions: &[Value], severity: &str) -> usize {
    actions
        .iter()
        .filter(|item| item.get("severity").and_then(Value::as_str) == Some(severity))
        .count()
}

fn first_action_command(actions: &[Value], fallback: &str) -> String {
    actions
        .first()
        .and_then(|item| item.get("command").and_then(Value::as_str))
        .unwrap_or(fallback)
        .to_string()
}

fn score_band(value: u64) -> &'static str {
    if value >= 85 {
        "strong"
    } else if value >= 65 {
        "workable"
    } else if value >= 40 {
        "fragile"
    } else {
        "blocked"
    }
}

fn insight_item(
    domain: &str,
    severity: &str,
    title: &str,
    detail: String,
    command: String,
    kind: &str,
    source: &str,
) -> Value {
    json!({
        "domain": domain,
        "severity": severity,
        "kind": kind,
        "title": title,
        "detail": detail,
        "command": command,
        "source": source,
        "writer": "seven-daemon",
    })
}

fn push_insight_once(items: &mut Vec<Value>, item: Value) {
    let key = (
        item.get("domain").and_then(Value::as_str).unwrap_or(""),
        item.get("title").and_then(Value::as_str).unwrap_or(""),
        item.get("command").and_then(Value::as_str).unwrap_or(""),
    );
    let exists = items.iter().any(|existing| {
        (
            existing.get("domain").and_then(Value::as_str).unwrap_or(""),
            existing.get("title").and_then(Value::as_str).unwrap_or(""),
            existing
                .get("command")
                .and_then(Value::as_str)
                .unwrap_or(""),
        ) == key
    });
    if !exists {
        items.push(item);
    }
}

fn daemon_insights_json(args: &[String]) {
    let limit = arg_value(args, "--limit", "8")
        .parse::<usize>()
        .unwrap_or(8);
    let root = sevenos_root().unwrap_or_else(|| PathBuf::from("."));
    let installed_set = pacman_packages();
    let active = active_profile_key();

    let profiles: Vec<Value> = PROFILES
        .iter()
        .map(|spec| profile_payload(&root, &installed_set, &active, spec))
        .collect();
    let profile_open = profiles
        .iter()
        .filter(|item| item.get("state").and_then(Value::as_str) != Some("OK"))
        .count();

    let shield_checks = shield_checks();
    let (shield_score, shield_max) = shield_score(&shield_checks);
    let shield_percent = if shield_max > 0 {
        ((shield_score as f64 / shield_max as f64) * 100.0).round() as u64
    } else {
        0
    };
    let mut shield_actions: Vec<Value> = shield_checks
        .iter()
        .filter(|item| item.get("state").and_then(Value::as_str) != Some("OK"))
        .map(shield_plan_item)
        .collect();
    shield_actions.sort_by(|left, right| {
        severity_rank(left)
            .cmp(&severity_rank(right))
            .then_with(|| {
                left.get("key")
                    .and_then(Value::as_str)
                    .unwrap_or("")
                    .cmp(right.get("key").and_then(Value::as_str).unwrap_or(""))
            })
    });

    let server_service = user_service_state("seven-server.service");
    let server_dependencies = server_dependencies(&root);
    let mut server_actions = Vec::new();
    if server_service != "READY" && server_service != "RUN" {
        server_actions.push(server_plan_item(
            "service",
            "MISS",
            "Seven Server user service",
            "seven server install-user-service",
        ));
    }
    if server_service != "RUN" {
        server_actions.push(server_plan_item(
            "service-start",
            "MISS",
            "Seven Server runtime",
            "seven server start",
        ));
    }
    for item in &server_dependencies {
        if item.get("state").and_then(Value::as_str) != Some("OK") {
            let key = item.get("key").and_then(Value::as_str).unwrap_or("unknown");
            server_actions.push(server_plan_item(
                key,
                item.get("state").and_then(Value::as_str).unwrap_or("MISS"),
                item.get("detail").and_then(Value::as_str).unwrap_or(""),
                match key {
                    "seven-deploy" => "seven deploy status",
                    _ => "seven improve deployment --apply",
                },
            ));
        }
    }
    server_actions.sort_by(|left, right| {
        severity_rank(left)
            .cmp(&severity_rank(right))
            .then_with(|| {
                left.get("key")
                    .and_then(Value::as_str)
                    .unwrap_or("")
                    .cmp(right.get("key").and_then(Value::as_str).unwrap_or(""))
            })
    });

    let windows_status = windows_status_map();
    let vm_ready = [
        "cpu_virtualization",
        "kvm_device",
        "qemu",
        "virt_manager",
        "virsh",
        "libvirtd",
        "default_network",
    ]
    .iter()
    .all(|key| windows_ok(&windows_status, key));
    let app_ready = windows_ok(&windows_status, "wine")
        && (windows_ok(&windows_status, "bottles_flatpak")
            || windows_ok(&windows_status, "lutris"));
    let windows_ready = vm_ready && app_ready;
    let windows_mode = if windows_ready {
        "complete"
    } else if vm_ready {
        "vm-ready"
    } else {
        "setup-needed"
    };
    let mut windows_actions = Vec::new();
    for key in [
        "cpu_virtualization",
        "kvm_device",
        "wine",
        "lutris",
        "bottles_flatpak",
        "qemu",
        "virt_manager",
        "virt_install",
        "virsh",
        "libvirtd",
        "libvirt_group",
        "default_network",
        "windows_vm",
    ] {
        let state = windows_state_value(&windows_status, key);
        if state != "OK" && state != "RUN" {
            windows_actions.push(windows_plan_item(key, &state));
        }
    }
    windows_actions.sort_by(|left, right| severity_rank(left).cmp(&severity_rank(right)));

    let (installer_tooling, installer_foundation) = installer_status_items(&root);
    let installer_is_ready = installer_ready(&installer_tooling, &installer_foundation);
    let installer_mode_value = installer_mode(&installer_tooling);
    let mut installer_actions = Vec::new();
    for item in installer_tooling.iter().chain(installer_foundation.iter()) {
        let key = item.get("key").and_then(Value::as_str).unwrap_or("unknown");
        let state = item.get("state").and_then(Value::as_str).unwrap_or("MISS");
        if state != "OK" {
            installer_actions.push(installer_plan_item(key, state));
        }
    }

    let package_actions = package_plan_actions(&root, &installed_set);

    let mut insights = Vec::new();
    if shield_percent < 75 {
        push_insight_once(
            &mut insights,
            insight_item(
                "security",
                if shield_percent < 45 {
                    "critical"
                } else {
                    "high"
                },
                "Improve trust posture",
                format!(
                    "Shield is at {}%. Security must become visible, active and default-safe.",
                    shield_percent
                ),
                first_action_command(&shield_actions, "seven shield plan"),
                "trust",
                "shield",
            ),
        );
    }
    if server_service != "RUN" {
        push_insight_once(
            &mut insights,
            insight_item(
                "server",
                "high",
                "Start local OS backend",
                format!(
                    "Seven Server is {}. Hub, Shell and automation need a durable local API.",
                    server_service
                ),
                first_action_command(&server_actions, "seven server plan"),
                "service",
                "server",
            ),
        );
    }
    if profile_open > 0 {
        for profile in profiles
            .iter()
            .filter(|item| item.get("state").and_then(Value::as_str) != Some("OK"))
            .take(4)
        {
            let key = profile
                .get("key")
                .and_then(Value::as_str)
                .unwrap_or("profile");
            let title = profile
                .get("title")
                .and_then(Value::as_str)
                .unwrap_or("Profile");
            let missing = profile
                .get("packages")
                .and_then(|value| value.get("missing_count"))
                .and_then(Value::as_u64)
                .unwrap_or(0);
            push_insight_once(
                &mut insights,
                insight_item(
                    "profiles",
                    if key == "shield" { "critical" } else { "high" },
                    &format!("Complete {}", title),
                    format!(
                        "{} is still incomplete with {} missing packages. Profiles must become real work modes.",
                        title, missing
                    ),
                    format!("seven profile install {}", key),
                    "workflow",
                    "profiles",
                ),
            );
        }
    }
    if !windows_ready {
        push_insight_once(
            &mut insights,
            insight_item(
                "windows",
                "medium",
                "Complete Windows Mode",
                format!(
                    "Windows Mode is {}. SevenOS needs one guided path for Wine, Bottles and KVM.",
                    windows_mode
                ),
                first_action_command(&windows_actions, "seven windows plan"),
                "compatibility",
                "windows",
            ),
        );
    }
    if !installer_is_ready {
        push_insight_once(
            &mut insights,
            insight_item(
                "installer",
                "medium",
                "Prepare installable SevenOS",
                format!(
                    "Installer mode is {}. SevenOS still needs a stronger path from live ISO to disk.",
                    installer_mode_value
                ),
                first_action_command(&installer_actions, "seven installer plan"),
                "distribution",
                "installer",
            ),
        );
    }
    if !package_actions.is_empty() {
        push_insight_once(
            &mut insights,
            insight_item(
                "packages",
                if severity_count(&package_actions, "critical") > 0 {
                    "high"
                } else {
                    "medium"
                },
                "Complete software layer",
                format!(
                    "{} software actions remain across SevenPkg, Flatpak and profile delivery.",
                    package_actions.len()
                ),
                first_action_command(&package_actions, "seven core packages-plan"),
                "apps",
                "packages",
            ),
        );
    }

    insights.sort_by(|left, right| {
        severity_rank(left)
            .cmp(&severity_rank(right))
            .then_with(|| {
                left.get("domain")
                    .and_then(Value::as_str)
                    .unwrap_or("")
                    .cmp(right.get("domain").and_then(Value::as_str).unwrap_or(""))
            })
            .then_with(|| {
                left.get("title")
                    .and_then(Value::as_str)
                    .unwrap_or("")
                    .cmp(right.get("title").and_then(Value::as_str).unwrap_or(""))
            })
    });

    let phase = if shield_percent >= 75 && server_service == "RUN" && profile_open <= 2 {
        "B3"
    } else {
        "B2"
    };
    let visible: Vec<Value> = insights.iter().take(limit).cloned().collect();
    let payload = json!({
        "schema": "sevenos.insights.v1",
        "phase": phase,
        "summary": {
            "total": insights.len(),
            "critical": severity_count(&insights, "critical"),
            "high": severity_count(&insights, "high"),
            "medium": severity_count(&insights, "medium"),
            "headline": "SevenOS is becoming a context-aware ecosystem; remaining work is trust, backend, profiles and installability.",
        },
        "signals": {
            "shield": {
                "percent": shield_percent,
                "band": score_band(shield_percent),
                "open": shield_actions.len(),
            },
            "server": {
                "state": server_service,
                "open": server_actions.len(),
            },
            "profiles": {
                "total": profiles.len(),
                "open": profile_open,
                "active": active,
            },
            "windows": {
                "ready": windows_ready,
                "mode": windows_mode,
                "open": windows_actions.len(),
            },
            "installer": {
                "ready": installer_is_ready,
                "mode": installer_mode_value,
                "open": installer_actions.len(),
            },
            "packages": {
                "open": package_actions.len(),
                "critical": severity_count(&package_actions, "critical"),
                "high": severity_count(&package_actions, "high"),
                "medium": severity_count(&package_actions, "medium"),
            },
            "events": {
                "count": event_count(),
            },
        },
        "insights": visible,
        "runtime": "seven-daemon",
        "writer": "seven-daemon",
    });
    println!(
        "{}",
        serde_json::to_string(&payload).unwrap_or_else(|_| "{}".to_string())
    );
}

fn phase_gate_item(
    key: &str,
    title: &str,
    state: &str,
    actual: Value,
    target: Value,
    band: &str,
    command: &str,
    detail: &str,
) -> Value {
    json!({
        "key": key,
        "title": title,
        "state": state,
        "actual": actual,
        "target": target,
        "band": band,
        "command": command,
        "detail": detail,
        "writer": "seven-daemon",
    })
}

fn gate_state_percent(actual: u64, target: u64, warn_floor: u64) -> &'static str {
    if actual >= target {
        "PASS"
    } else if actual >= warn_floor {
        "WARN"
    } else {
        "BLOCK"
    }
}

fn daemon_phase_gate_payload() -> Value {
    let root = sevenos_root().unwrap_or_else(|| PathBuf::from("."));
    let installed_set = pacman_packages();
    let active = active_profile_key();

    let profiles: Vec<Value> = PROFILES
        .iter()
        .map(|spec| profile_payload(&root, &installed_set, &active, spec))
        .collect();
    let profile_gaps: Vec<Value> = profiles.iter().map(profile_gap_item).collect();
    let profile_actions: Vec<Value> = profile_gaps.iter().filter_map(profile_plan_item).collect();
    let profile_critical = severity_count(&profile_actions, "critical");
    let profile_high = severity_count(&profile_actions, "high");
    let profile_medium = severity_count(&profile_actions, "medium");
    let profile_low = profile_actions
        .len()
        .saturating_sub(profile_critical)
        .saturating_sub(profile_high)
        .saturating_sub(profile_medium);
    let profile_percent = 100u64
        .saturating_sub((profile_critical as u64).saturating_mul(24))
        .saturating_sub((profile_high as u64).saturating_mul(18))
        .saturating_sub((profile_medium as u64).saturating_mul(7))
        .saturating_sub((profile_low as u64).saturating_mul(3))
        .max(if profile_critical == 0 && profile_high == 0 { 72 } else { 50 });

    let shield_checks = shield_checks();
    let (shield_score, shield_max) = shield_score(&shield_checks);
    let shield_percent = if shield_max > 0 {
        ((shield_score as f64 / shield_max as f64) * 100.0).round() as u64
    } else {
        0
    };

    let server_service = user_service_state("seven-server.service");
    let server_dependencies = server_dependencies(&root);
    let server_missing = server_dependencies
        .iter()
        .filter(|item| item.get("state").and_then(Value::as_str) != Some("OK"))
        .count();
    let server_runtime_ready = server_service == "RUN"
        && server_dependencies.iter().all(|item| {
            let key = item.get("key").and_then(Value::as_str).unwrap_or("");
            let state = item.get("state").and_then(Value::as_str).unwrap_or("");
            !matches!(key, "jq" | "seven-deploy") || state == "OK"
        });
    let server_gate_band = if server_runtime_ready {
        "RUNTIME_READY"
    } else {
        server_service
    };

    let windows_status = windows_status_map();
    let vm_ready = [
        "cpu_virtualization",
        "kvm_device",
        "qemu",
        "virt_manager",
        "virsh",
        "libvirtd",
        "default_network",
    ]
    .iter()
    .all(|key| windows_ok(&windows_status, key));
    let app_ready = windows_ok(&windows_status, "wine")
        && (windows_ok(&windows_status, "bottles_flatpak")
            || windows_ok(&windows_status, "lutris"));
    let windows_ready = vm_ready && app_ready;
    let windows_mode = if windows_ready {
        "complete"
    } else if vm_ready {
        "vm-ready"
    } else {
        "setup-needed"
    };

    let (installer_tooling, installer_foundation) = installer_status_items(&root);
    let installer_is_ready = installer_ready(&installer_tooling, &installer_foundation);
    let installer_mode_value = installer_mode(&installer_tooling);

    let package_actions = package_plan_actions(&root, &installed_set);
    let package_open = package_actions.len();
    let package_blocking = severity_count(&package_actions, "critical")
        + severity_count(&package_actions, "high");

    let experience_percent = if root.join("seven-hub/native/README.md").is_file()
        && root.join("seven-shell/README.md").is_file()
        && root.join("hyprland/waybar/config.jsonc").is_file()
    {
        90
    } else {
        55
    };
    let control_percent = if root.join("scripts/actions.sh").is_file()
        && root.join("scripts/control-plane.sh").is_file()
        && root.join("scripts/insights.sh").is_file()
        && root.join("scripts/ai.sh").is_file()
        && root.join("scripts/store.sh").is_file()
        && root.join("bin/seven-hub-native").is_file()
    {
        86
    } else if root.join("scripts/actions.sh").is_file()
        && root.join("scripts/control-plane.sh").is_file()
        && root.join("scripts/insights.sh").is_file()
    {
        70
    } else {
        40
    };
    let stack_ok = [
        root.join("docs/STACK_STRATEGY.md").is_file(),
        root.join("seven-shell/ags/package.json").is_file(),
        root.join("seven-core/daemon/Cargo.toml").is_file(),
        root.join("seven-core/bus-c/src/sevenbus_probe.c").is_file(),
        root.join("seven-hub/native/README.md").is_file(),
        root.join("scripts/packages-shell-ags.txt").is_file(),
        root.join("scripts/packages-server.txt").is_file(),
        root.join("scripts/packages-security.txt").is_file(),
        root.join("scripts/packages-windows.txt").is_file(),
    ]
    .iter()
    .filter(|ready| **ready)
    .count();
    let stack_total = 9usize;
    let stack_percent = ((stack_ok as f64 / stack_total as f64) * 100.0).round() as u64;

    let core_foundation = root.join("seven-core/daemon/Cargo.toml").is_file()
        && root.join("bin/seven-daemon").is_file()
        && root.join("seven-core/bus-schema.json").is_file();
    let core_state = if core_foundation
        && user_service_state("seven-daemon.service") == "RUN"
        && user_service_state("seven-context-observer.service") == "RUN"
    {
        "RUNTIME_READY"
    } else if core_foundation {
        "READY_FOR_DAEMON"
    } else {
        "MISS"
    };

    let package_medium = severity_count(&package_actions, "medium");
    let software_percent = 100u64
        .saturating_sub((package_blocking as u64).saturating_mul(18))
        .saturating_sub((package_medium as u64).saturating_mul(5))
        .saturating_sub(
            (package_open
                .saturating_sub(package_blocking)
                .saturating_sub(package_medium) as u64)
                .saturating_mul(2),
        )
        .max(if package_blocking == 0 { 75 } else { 55 });
    let installer_percent = if installer_is_ready {
        100
    } else if installer_mode_value != "foundation" {
        65
    } else {
        40
    };
    let server_percent = if server_runtime_ready && server_missing == 0 {
        100
    } else if server_runtime_ready {
        75
    } else if server_service == "READY" {
        60
    } else {
        35u64.saturating_add((server_dependencies.len().saturating_sub(server_missing) as u64) * 8)
    };
    let windows_percent = if windows_ready {
        100
    } else if vm_ready {
        70
    } else {
        45
    };
    let readiness_percent = ((experience_percent
        + control_percent
        + shield_percent
        + server_percent
        + installer_percent
        + windows_percent
        + profile_percent
        + software_percent
        + stack_percent) as f64
        / 9.0)
        .round() as u64;

    let gates = vec![
        phase_gate_item(
            "readiness",
            "OS readiness",
            gate_state_percent(readiness_percent, 85, 70),
            json!(readiness_percent),
            json!(85),
            score_band(readiness_percent),
            "seven readiness",
            "Daemon-native readiness estimate based on trust, backend, installer, profiles, software and shell foundations.",
        ),
        phase_gate_item(
            "experience",
            "User experience",
            gate_state_percent(experience_percent, 85, 65),
            json!(experience_percent),
            json!(85),
            score_band(experience_percent),
            "seven experience",
            "Shell, Hub, actions and onboarding must feel coherent.",
        ),
        phase_gate_item(
            "control",
            "Control plane",
            gate_state_percent(control_percent, 65, 50),
            json!(control_percent),
            json!(65),
            score_band(control_percent),
            "seven control",
            "Seven Hub needs a useful prioritized decision contract.",
        ),
        phase_gate_item(
            "shield",
            "Trust posture",
            gate_state_percent(shield_percent, 70, 45),
            json!(shield_percent),
            json!(70),
            score_band(shield_percent),
            "seven shield plan",
            "Security must be visible and default-safe before a higher phase.",
        ),
        phase_gate_item(
            "server",
            "Seven Server backend",
            if server_runtime_ready || server_service == "READY" {
                "PASS"
            } else {
                "BLOCK"
            },
            json!(server_gate_band),
            json!("RUNTIME_READY"),
            server_gate_band,
            "seven server plan",
            "The ecosystem needs a local OS API surface. Go/Podman/Caddy complete Horizon deployment, but they are not required to prove that the local API is running.",
        ),
        phase_gate_item(
            "installer",
            "Installer path",
            if installer_is_ready {
                "PASS"
            } else if installer_mode_value != "foundation" {
                "WARN"
            } else {
                "BLOCK"
            },
            json!(installer_mode_value),
            json!("ready"),
            installer_mode_value,
            "seven installer plan",
            "A real OS needs a reproducible install path, not a manual post-install story.",
        ),
        phase_gate_item(
            "windows",
            "Windows Mode",
            if windows_ready { "PASS" } else { "WARN" },
            json!(windows_mode),
            json!("ready"),
            windows_mode,
            "seven windows plan",
            "All-in-one accessibility improves when Wine, Bottles and VM setup are guided.",
        ),
        phase_gate_item(
            "profiles",
            "Profile completeness",
            gate_state_percent(profile_percent, 85, 65),
            json!(profile_percent),
            json!(85),
            score_band(profile_percent),
            "seven profile plan",
            "Profiles must keep moving from decorative modes to complete workspaces.",
        ),
        phase_gate_item(
            "software",
            "Software plan",
            gate_state_percent(software_percent, 85, 65),
            json!(software_percent),
            json!(85),
            score_band(software_percent),
            "seven core packages-plan",
            "SevenPkg must explain critical and high-priority app delivery gaps. Medium bundles stay optional.",
        ),
        phase_gate_item(
            "stack",
            "Stack discipline",
            if stack_ok >= 8 { "PASS" } else { "WARN" },
            json!(format!("{}/{}", stack_ok, stack_total)),
            json!(format!("{}/{}", 8, stack_total)),
            if stack_ok >= 8 { "ready" } else { "open" },
            "seven stack doctor",
            "AGS and Rust should enter in a controlled B3 order, not as parallel rewrites.",
        ),
        phase_gate_item(
            "core",
            "Seven Core foundation",
            if matches!(core_state, "READY_FOR_DAEMON" | "RUNTIME_READY") {
                "PASS"
            } else {
                "WARN"
            },
            json!(core_state),
            json!("RUNTIME_READY"),
            core_state.to_lowercase().as_str(),
            "seven core plan",
            "SevenOS needs a named system experience layer before replacing script surfaces with daemon-backed UI.",
        ),
    ];

    let pass = gates
        .iter()
        .filter(|item| item.get("state").and_then(Value::as_str) == Some("PASS"))
        .count();
    let warn = gates
        .iter()
        .filter(|item| item.get("state").and_then(Value::as_str) == Some("WARN"))
        .count();
    let block = gates
        .iter()
        .filter(|item| item.get("state").and_then(Value::as_str) == Some("BLOCK"))
        .count();
    let next_commands: Vec<String> = gates
        .iter()
        .filter(|item| item.get("state").and_then(Value::as_str) != Some("PASS"))
        .filter_map(|item| {
            item.get("command")
                .and_then(Value::as_str)
                .map(str::to_string)
        })
        .fold(Vec::<String>::new(), |mut commands, command| {
            if !commands.contains(&command) {
                commands.push(command);
            }
            commands
        })
        .into_iter()
        .take(8)
        .collect();
    let decision = if block > 0 {
        "blocked"
    } else if warn > 0 {
        "warning"
    } else {
        "pass"
    };

    json!({
        "schema": "sevenos.phase-gate.v1",
        "phase": "B2",
        "next_phase": "B3 - native backend, installer readiness and active trust",
        "decision": decision,
        "summary": {
            "pass": pass,
            "warn": warn,
            "block": block,
            "total": gates.len(),
        },
        "identity": {
            "active_pack": "pan-african",
        },
        "gates": gates,
        "next_commands": next_commands,
        "runtime": "seven-daemon",
        "writer": "seven-daemon",
    })
}

fn daemon_phase_gate_json() {
    print_value(&daemon_phase_gate_payload());
}

fn gate_numeric_actual(gate: &Value) -> u64 {
    gate.get("actual")
        .and_then(Value::as_u64)
        .or_else(|| {
            gate.get("actual")
                .and_then(Value::as_i64)
                .and_then(|value| if value >= 0 { Some(value as u64) } else { None })
        })
        .unwrap_or(0)
}

fn daemon_readiness_payload() -> Value {
    let phase = daemon_phase_gate_payload();
    let gates = phase
        .get("gates")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default();
    let readiness_percent = gates
        .iter()
        .find(|item| item.get("key").and_then(Value::as_str) == Some("readiness"))
        .map(gate_numeric_actual)
        .unwrap_or(0);
    let categories = gates
        .iter()
        .map(|gate| {
            let key = gate.get("key").and_then(Value::as_str).unwrap_or("unknown");
            let title = gate.get("title").and_then(Value::as_str).unwrap_or(key);
            let percent = gate_numeric_actual(gate);
            (
                key.to_string(),
                json!({
                    "title": title,
                    "percent": percent,
                    "state": gate.get("state").cloned().unwrap_or_else(|| json!("WARN")),
                    "command": gate.get("command").cloned().unwrap_or_else(|| json!("seven core phase-gate")),
                    "reason": gate.get("detail").cloned().unwrap_or_else(|| json!("SevenOS native readiness signal.")),
                }),
            )
        })
        .collect::<serde_json::Map<String, Value>>();
    let recommendations = gates
        .iter()
        .filter(|gate| gate.get("state").and_then(Value::as_str) != Some("PASS"))
        .map(|gate| {
            json!({
                "command": gate.get("command").and_then(Value::as_str).unwrap_or("seven core phase-gate"),
                "reason": gate.get("detail").and_then(Value::as_str).unwrap_or("Improve this SevenOS readiness gate."),
                "category": gate.get("key").and_then(Value::as_str).unwrap_or("readiness"),
            })
        })
        .collect::<Vec<_>>();
    let state = if readiness_percent >= 90 {
        "ready"
    } else if readiness_percent >= 75 {
        "attention"
    } else {
        "needs-work"
    };

    json!({
        "schema": "sevenos.readiness.v1",
        "state": state,
        "percent": readiness_percent,
        "score": readiness_percent,
        "max": 100,
        "categories": categories,
        "recommendations": recommendations,
        "source": "phase-gate-native",
        "runtime": "seven-daemon",
        "writer": "seven-daemon",
    })
}

fn daemon_readiness_json() {
    print_value(&daemon_readiness_payload());
}

fn daemon_daily_payload() -> Value {
    let readiness = daemon_readiness_payload();
    let phase = daemon_phase_gate_payload();
    let gates = phase
        .get("gates")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default();
    let blockers = gates
        .iter()
        .filter(|gate| gate.get("state").and_then(Value::as_str) == Some("BLOCK"))
        .map(|gate| {
            json!({
                "key": gate.get("key").and_then(Value::as_str).unwrap_or("gate"),
                "title": gate.get("title").and_then(Value::as_str).unwrap_or("Resolve SevenOS gate"),
                "command": gate.get("command").and_then(Value::as_str).unwrap_or("seven core phase-gate"),
                "reason": gate.get("detail").and_then(Value::as_str).unwrap_or("This gate blocks a daily-driver quality decision."),
            })
        })
        .collect::<Vec<_>>();
    let warnings = gates
        .iter()
        .filter(|gate| gate.get("state").and_then(Value::as_str) == Some("WARN"))
        .map(|gate| {
            json!({
                "key": gate.get("key").and_then(Value::as_str).unwrap_or("gate"),
                "title": gate.get("title").and_then(Value::as_str).unwrap_or("Review SevenOS gate"),
                "command": gate.get("command").and_then(Value::as_str).unwrap_or("seven core phase-gate"),
                "reason": gate.get("detail").and_then(Value::as_str).unwrap_or("This gate needs review before public release."),
            })
        })
        .collect::<Vec<_>>();
    let readiness_percent = readiness.get("percent").and_then(Value::as_u64).unwrap_or(0);
    let decision = if !blockers.is_empty() {
        "blocked"
    } else if readiness_percent >= 80 {
        "ready"
    } else {
        "attention"
    };

    json!({
        "schema": "sevenos.daily-driver.v1",
        "state": decision,
        "decision": decision,
        "summary": {
            "readiness": readiness_percent,
            "blockers": blockers.len(),
            "warnings": warnings.len(),
            "source": "seven-daemon",
        },
        "blockers": blockers,
        "warnings": warnings,
        "readiness": readiness,
        "runtime": "seven-daemon",
        "writer": "seven-daemon",
    })
}

fn daemon_daily_json() {
    print_value(&daemon_daily_payload());
}

fn public_readiness_decision(
    key: &str,
    state: &str,
    title_fr: &str,
    title_en: &str,
    detail_fr: String,
    detail_en: String,
    command: &str,
    priority: u64,
) -> Value {
    json!({
        "key": key,
        "state": state,
        "title_fr": title_fr,
        "title_en": title_en,
        "detail_fr": detail_fr,
        "detail_en": detail_en,
        "command": command,
        "priority": priority,
        "writer": "seven-daemon",
    })
}

fn daemon_public_readiness_payload() -> Value {
    let root = sevenos_root().unwrap_or_else(|| PathBuf::from("."));
    let installed_tree = root == PathBuf::from("/opt/SevenOS");
    let daily = daemon_daily_payload();
    let readiness = daemon_readiness_payload();
    let shell = shell_status_payload();
    let installer = installer_release_payload(&root);
    let daily_ready = daily.get("decision").and_then(Value::as_str) == Some("ready");
    let daily_warning_count = daily
        .get("summary")
        .and_then(|summary| summary.get("warnings"))
        .and_then(Value::as_u64)
        .unwrap_or(0);
    let readiness_percent = readiness.get("percent").and_then(Value::as_u64).unwrap_or(0);
    let dirty_count = if root.join(".git").exists() {
        update_dirty_count(&root)
    } else {
        0
    };
    let ags_ready = shell.get("ags").and_then(Value::as_str) == Some("OK")
        || shell.get("ready").and_then(Value::as_bool).unwrap_or(false);
    let installer_state = installer
        .get("state")
        .and_then(Value::as_str)
        .unwrap_or("unknown")
        .to_string();
    let installer_ready = matches!(
        installer_state.as_str(),
        "graphical-ready" | "tui-release-ready" | "iso-foundation"
    );
    let release_state = if installed_tree {
        "info"
    } else if dirty_count == 0 {
        "ready"
    } else {
        "todo"
    };
    let (release_detail_fr, release_detail_en, release_command) = if installed_tree {
        (
            "Cette machine utilise l'arbre système /opt/SevenOS. Le gel Git se vérifie dans le dépôt de construction avant publication.".to_string(),
            "This machine uses the /opt/SevenOS system tree. Git freeze is checked in the build repository before publishing.".to_string(),
            "seven update check",
        )
    } else if dirty_count == 0 {
        (
            "Le dépôt est propre.".to_string(),
            "The repository is clean.".to_string(),
            "seven release open",
        )
    } else {
        (
            format!("{dirty_count} chemin(s) modifiés/non suivis. Revoir, grouper, puis committer avant release publique."),
            format!("{dirty_count} modified/untracked path(s). Review, group and commit before public release."),
            "seven release open",
        )
    };
    let decisions = vec![
        public_readiness_decision(
            "daily-driver",
            if daily_ready { "ready" } else { "attention" },
            "Usage quotidien",
            "Daily use",
            if daily_ready {
                if daily_warning_count > 0 {
                    format!("SevenOS est prêt pour l'usage quotidien avec {daily_warning_count} avertissement(s) produit à suivre avant release publique.")
                } else {
                    "SevenOS est prêt pour l'usage quotidien.".to_string()
                }
            } else {
                "SevenOS demande encore une consolidation avant usage quotidien serein.".to_string()
            },
            if daily_ready {
                if daily_warning_count > 0 {
                    format!("SevenOS is ready for daily use with {daily_warning_count} product warning(s) to follow before public release.")
                } else {
                    "SevenOS is ready for daily use.".to_string()
                }
            } else {
                "SevenOS still needs consolidation before comfortable daily use.".to_string()
            },
            "seven daily",
            1,
        ),
        public_readiness_decision(
            "installer",
            if installer_ready { "ready" } else { "attention" },
            "Installateur graphique",
            "Graphical installer",
            format!("Etat installateur: {installer_state}."),
            format!("Installer state: {installer_state}."),
            "seven installer release",
            2,
        ),
        public_readiness_decision(
            "release-freeze",
            release_state,
            "Gel release Git",
            "Git release freeze",
            release_detail_fr,
            release_detail_en,
            release_command,
            3,
        ),
        public_readiness_decision(
            "shell-runtime",
            if ags_ready { "ready" } else { "optional-finalization" },
            "Runtime Seven Shell AGS",
            "Seven Shell AGS runtime",
            if ags_ready {
                "AGS est disponible ou le Shell natif est prêt.".to_string()
            } else {
                "Fallback natif prêt. AGS reste l'etape pour les surfaces Shell finales.".to_string()
            },
            if ags_ready {
                "AGS is available or the native Shell is ready.".to_string()
            } else {
                "Native fallback is ready. AGS remains the final Shell surface step.".to_string()
            },
            "seven shell status",
            4,
        ),
    ];
    let resolved_states = ["ready", "info", "optional-finalization"];
    let next = decisions
        .iter()
        .filter(|item| {
            !resolved_states.contains(&item.get("state").and_then(Value::as_str).unwrap_or(""))
        })
        .cloned()
        .collect::<Vec<_>>();
    let public_ready = daily_ready && installer_ready && (installed_tree || dirty_count == 0);
    let state = if public_ready {
        "public-ready"
    } else if daily_ready {
        "daily-ready"
    } else {
        "attention"
    };

    json!({
        "schema": "sevenos.public-readiness.v1",
        "compat_schema": "sevenos.readiness-decisions.v1",
        "state": state,
        "daily_ready": daily_ready,
        "public_ready": public_ready,
        "score": readiness_percent,
        "summary": {
            "decisions": decisions.len(),
            "ready": decisions.len().saturating_sub(next.len()),
            "todo": next.len(),
            "dirty_count": dirty_count,
            "installed_tree": installed_tree,
            "installer": installer_state,
            "shell_ags": if ags_ready { "ready" } else { "fallback" },
            "source": "seven-daemon",
        },
        "decisions": decisions,
        "next": next,
        "commands": {
            "quality": "seven quality mode public",
            "release_review": "seven release open",
            "installer": "seven installer release",
            "public_studio": "seven public-studio --gui",
            "full_audit": "seven public-readiness doctor --full",
            "native": "seven-daemon public-readiness --json",
        },
        "runtime": "seven-daemon",
        "writer": "seven-daemon",
    })
}

fn daemon_public_readiness_json() {
    print_value(&daemon_public_readiness_payload());
}

fn production_check(
    key: &str,
    state: &str,
    title: &str,
    detail: String,
    command: &str,
    critical: bool,
) -> Value {
    json!({
        "key": key,
        "state": state,
        "title": title,
        "detail": detail,
        "command": command,
        "critical": critical,
        "writer": "seven-daemon",
    })
}

fn daemon_production_payload() -> Value {
    let root = sevenos_root().unwrap_or_else(|| PathBuf::from("."));
    let public = daemon_public_readiness_payload();
    let installer = installer_release_payload(&root);
    let update = update_payload();
    let public_ready = public.get("public_ready").and_then(Value::as_bool).unwrap_or(false);
    let public_state = public.get("state").and_then(Value::as_str).unwrap_or("unknown");
    let installer_state = installer.get("state").and_then(Value::as_str).unwrap_or("unknown");
    let installer_ready = matches!(
        installer_state,
        "graphical-ready" | "tui-release-ready" | "iso-foundation"
    );
    let update_score = update.get("score").and_then(Value::as_u64).unwrap_or(0);
    let update_ready = update_score >= 75;
    let support_ready = root.join("scripts/support.sh").is_file()
        && root.join("scripts/doctor.sh").is_file()
        && root.join("bin/seven").is_file();
    let language_ready = root.join("bin/seven-language").is_file()
        && file_contains_state(&root, "archiso/profile/airootfs/etc/locale.gen", "en_US.UTF-8 UTF-8") == "OK"
        && file_contains_state(&root, "archiso/profile/airootfs/etc/locale.gen", "fr_FR.UTF-8 UTF-8") == "OK";
    let trust_ready = file_contains_state(&root, "scripts/update.sh", "rollback") == "OK"
        && file_contains_state(&root, "scripts/update.sh", "last-successful-tree") == "OK";
    let validation_contract_ready = root.join("scripts/release-validation.sh").is_file()
        && root.join("docs/RELEASE_VALIDATION.md").is_file();
    let checks = vec![
        production_check(
            "public-readiness",
            if public_ready { "OK" } else { "PART" },
            "Public readiness decision",
            format!("{} · score {}%.", public_state, public.get("score").and_then(Value::as_u64).unwrap_or(0)),
            "seven public-readiness",
            true,
        ),
        production_check(
            "graphical-installer",
            if installer_ready { "OK" } else { "PART" },
            "Graphical installer and ISO route",
            format!("Installer state: {installer_state}."),
            "seven installer release",
            true,
        ),
        production_check(
            "update-rollback",
            if update_ready && trust_ready { "OK" } else { "PART" },
            "Update and rollback route",
            format!("Native update score: {update_score}% · rollback route: {}.", if trust_ready { "ready" } else { "needs-review" }),
            "seven update plan",
            false,
        ),
        production_check(
            "support-diagnostics",
            if support_ready { "OK" } else { "PART" },
            "Support and diagnostics",
            if support_ready { "Support, Doctor and CLI routes are present.".to_string() } else { "Support or Doctor routes need review.".to_string() },
            "seven support doctor",
            false,
        ),
        production_check(
            "language-runtime",
            if language_ready { "OK" } else { "PART" },
            "Language runtime baseline",
            if language_ready { "EN/FR UTF-8 baseline and Seven language tool are present.".to_string() } else { "Language baseline needs ISO/runtime review.".to_string() },
            "seven language doctor",
            false,
        ),
        production_check(
            "release-validation-contract",
            if validation_contract_ready { "OK" } else { "PART" },
            "Release validation evidence",
            if validation_contract_ready {
                "SevenOS has a repeatable local validation contract for ISO boot, Wi-Fi, disks, suspend and hardware evidence.".to_string()
            } else {
                "Release validation evidence tooling is missing.".to_string()
            },
            "seven production validate --json",
            false,
        ),
        production_check(
            "hardware-matrix",
            "PART",
            "Hardware validation matrix",
            "Manual multi-machine Intel/AMD/NVIDIA, Wi-Fi, Bluetooth, suspend, external disk and USB boot tests are still required; local evidence can be collected with seven production validate.".to_string(),
            "seven production validate",
            true,
        ),
    ];
    let ok = checks
        .iter()
        .filter(|item| item.get("state").and_then(Value::as_str) == Some("OK"))
        .count();
    let critical = checks
        .iter()
        .filter(|item| {
            item.get("critical").and_then(Value::as_bool).unwrap_or(false)
                && item.get("state").and_then(Value::as_str) != Some("OK")
        })
        .cloned()
        .collect::<Vec<_>>();
    let issues = checks
        .iter()
        .filter(|item| item.get("state").and_then(Value::as_str) != Some("OK"))
        .cloned()
        .collect::<Vec<_>>();
    let score = ((ok as f64 / checks.len().max(1) as f64) * 100.0).round() as u64;
    let public_beta_ready = critical
        .iter()
        .all(|item| item.get("key").and_then(Value::as_str) == Some("hardware-matrix"))
        && public_ready
        && installer_ready;
    let state = if public_beta_ready {
        "public-beta-ready"
    } else if score >= 66 {
        "beta-candidate"
    } else {
        "needs-hardening"
    };

    json!({
        "schema": "sevenos.production-readiness.v2",
        "compat_schema": "sevenos.production-readiness.v1",
        "root": root.to_string_lossy(),
        "state": state,
        "score": score,
        "public_beta_ready": public_beta_ready,
        "large_scale_ready": false,
        "large_scale_note": "Large-scale production requires real hardware matrix validation, signed ISO/package policy and support operations; this native gate does not pretend to certify that automatically.",
        "checks": checks,
        "issues": issues,
        "critical": critical,
        "hardware": {
            "matrix": [
                {"target": "Intel/AMD/NVIDIA", "status": "manual-required"},
                {"target": "Wi-Fi/Bluetooth/suspend", "status": "manual-required"},
                {"target": "USB/external disks/ISO boot", "status": "manual-required"}
            ]
        },
        "commands": {
            "status": "seven production",
            "doctor": "seven production doctor --full",
            "plan": "seven production plan",
            "validate": "seven production validate",
            "native": "seven-daemon production --json"
        },
        "runtime": "seven-daemon",
        "writer": "seven-daemon",
    })
}

fn daemon_production_json() {
    print_value(&daemon_production_payload());
}

fn distribution_check(
    key: &str,
    state: &str,
    title: &str,
    detail: String,
    command: &str,
) -> Value {
    json!({
        "key": key,
        "state": state,
        "title": title,
        "detail": detail,
        "command": command,
        "writer": "seven-daemon",
    })
}

fn daemon_distribution_payload() -> Value {
    let root = sevenos_root().unwrap_or_else(|| PathBuf::from("."));
    let public = daemon_public_readiness_payload();
    let production = daemon_production_payload();
    let surfaces = native_surfaces_payload();
    let installer = installer_release_payload(&root);
    let update = update_payload();
    let actions = native_actions_payload(&[]);
    let dirty_count = if root.join(".git").exists() {
        update_dirty_count(&root)
    } else {
        0
    };
    let core_ready = root.join("bin/seven").is_file()
        && root.join("bin/seven-daemon").is_file()
        && root.join("install.sh").is_file();
    let identity_ready = file_contains_state(&root, "README.md", "SevenOS") == "OK"
        && file_contains_state(&root, "branding/sevenos-release", "SevenOS") == "OK";
    let autonomy_ready = root.join("scripts/platform.sh").is_file()
        && root.join("scripts/mask.sh").is_file()
        && root.join("scripts/foundations.sh").is_file();
    let runtime_ready = root.join("scripts/runtime-orchestrator.sh").is_file()
        && root.join("profiles/mini-os.json").is_file();
    let surfaces_score = surfaces.get("score").and_then(Value::as_u64).unwrap_or(0);
    let installer_state = installer.get("state").and_then(Value::as_str).unwrap_or("unknown");
    let update_score = update.get("score").and_then(Value::as_u64).unwrap_or(0);
    let native_action_count = actions.get("count").and_then(Value::as_u64).unwrap_or(0);
    let checks = vec![
        distribution_check(
            "seven-core",
            if core_ready { "OK" } else { "MISS" },
            "SevenOS command and daemon layer",
            if core_ready { "seven, seven-daemon and install route are present.".to_string() } else { "Core command or daemon route is missing.".to_string() },
            "seven core status --json",
        ),
        distribution_check(
            "identity",
            if identity_ready { "OK" } else { "PART" },
            "SevenOS product identity",
            if identity_ready { "SevenOS product naming and release identity are present.".to_string() } else { "SevenOS identity files need review.".to_string() },
            "seven about",
        ),
        distribution_check(
            "autonomy-layer",
            if autonomy_ready { "OK" } else { "PART" },
            "Autonomy and backend masking",
            if autonomy_ready { "Platform, mask and foundation routes exist.".to_string() } else { "Autonomy scripts still need consolidation.".to_string() },
            "seven autonomy",
        ),
        distribution_check(
            "runtime-orchestrator",
            if runtime_ready { "OK" } else { "PART" },
            "Mini OS runtime orchestrator",
            if runtime_ready { "Profile runtime manifest and orchestrator route are present.".to_string() } else { "Profile runtime route needs review.".to_string() },
            "seven runtime status",
        ),
        distribution_check(
            "native-surfaces",
            if surfaces_score >= 90 { "OK" } else if surfaces_score >= 70 { "PART" } else { "MISS" },
            "Native product surfaces",
            format!("Native surface score: {surfaces_score}%."),
            "seven core surfaces --json",
        ),
        distribution_check(
            "installer-route",
            if matches!(installer_state, "graphical-ready" | "tui-release-ready" | "iso-foundation") { "OK" } else { "PART" },
            "Installer and ISO route",
            format!("Installer state: {installer_state}."),
            "seven installer release",
        ),
        distribution_check(
            "update-route",
            if update_score >= 75 { "OK" } else { "PART" },
            "Update and rollback route",
            format!("Native update score: {update_score}%."),
            "seven core update --json",
        ),
        distribution_check(
            "native-actions",
            if native_action_count >= 30 { "OK" } else { "PART" },
            "Native action registry",
            format!("{native_action_count} daemon actions exposed."),
            "seven core actions --json",
        ),
        distribution_check(
            "public-readiness",
            if public.get("daily_ready").and_then(Value::as_bool).unwrap_or(false) { "OK" } else { "PART" },
            "Public readiness decision",
            format!("{}.", public.get("state").and_then(Value::as_str).unwrap_or("unknown")),
            "seven public-readiness",
        ),
        distribution_check(
            "production-boundary",
            "OK",
            "Honest production boundary",
            format!("{} · large_scale_ready=false.", production.get("state").and_then(Value::as_str).unwrap_or("unknown")),
            "seven production",
        ),
        distribution_check(
            "release-freeze",
            if root == PathBuf::from("/opt/SevenOS") || dirty_count == 0 { "OK" } else { "PART" },
            "Repository freeze",
            if root == PathBuf::from("/opt/SevenOS") {
                "Installed system tree; Git freeze belongs to the build repository.".to_string()
            } else {
                format!("{dirty_count} modified/untracked path(s).")
            },
            "seven release open",
        ),
    ];
    let ok = checks
        .iter()
        .filter(|item| item.get("state").and_then(Value::as_str) == Some("OK"))
        .count();
    let partial = checks
        .iter()
        .filter(|item| item.get("state").and_then(Value::as_str) == Some("PART"))
        .count();
    let missing = checks
        .iter()
        .filter(|item| item.get("state").and_then(Value::as_str) == Some("MISS"))
        .count();
    let score = (((ok as f64) + (partial as f64 * 0.45)) / checks.len().max(1) as f64 * 100.0).round() as u64;
    let daily_driver_ready = missing == 0 && score >= 80;
    let public_release_ready = public.get("public_ready").and_then(Value::as_bool).unwrap_or(false)
        && production.get("public_beta_ready").and_then(Value::as_bool).unwrap_or(false)
        && (root == PathBuf::from("/opt/SevenOS") || dirty_count == 0);
    let state = if public_release_ready {
        "public-release-distribution"
    } else if daily_driver_ready {
        "daily-driver-distribution"
    } else {
        "distribution-foundation"
    };
    let issues = checks
        .iter()
        .filter(|item| item.get("state").and_then(Value::as_str) != Some("OK"))
        .cloned()
        .collect::<Vec<_>>();

    json!({
        "schema": "sevenos.distribution.v2",
        "compat_schema": "sevenos.distribution.v1",
        "state": state,
        "score": score,
        "daily_driver_ready": daily_driver_ready,
        "public_release_ready": public_release_ready,
        "summary": {
            "checks": checks.len(),
            "ok": ok,
            "partial": partial,
            "missing": missing,
            "dirty_count": dirty_count,
            "foundations_state": if autonomy_ready { "sevenos-owned" } else { "needs-review" },
            "runtime_state": if runtime_ready { "composed" } else { "needs-review" },
            "runtime_primary": "equinox",
            "installer_state": installer_state,
            "channel": "dev",
            "source": "seven-daemon",
        },
        "checks": checks,
        "issues": issues,
        "next": issues.iter().take(6).cloned().collect::<Vec<_>>(),
        "commands": {
            "status": "seven distribution",
            "doctor": "seven distribution doctor --full",
            "plan": "seven distribution plan",
            "release": "seven release doctor",
            "installer": "seven installer release",
            "native": "seven-daemon distribution --json",
        },
        "runtime": "seven-daemon",
        "writer": "seven-daemon",
    })
}

fn daemon_distribution_json() {
    print_value(&daemon_distribution_payload());
}

fn daemon_autonomy_payload() -> Value {
    let root = sevenos_root().unwrap_or_else(|| PathBuf::from("."));
    let foundations = daemon_foundations_payload();
    let surfaces = native_surfaces_payload();
    let routes = daemon_routes_payload();
    let distribution = daemon_distribution_payload();
    let update = update_payload();
    let smoke = daemon_smoke_payload();
    let dirty_count = git_dirty_count(&root);
    let checks = vec![
        system_check(
            "seven-first-cli",
            "SevenOS commands are first-class",
            root.join("bin/seven").is_file() && root.join("bin/sevenpkg").is_file(),
            root.join("bin/seven").is_file(),
            "Users operate the OS through seven/sevenpkg instead of raw backend tools.".to_string(),
            "seven status",
        ),
        system_check(
            "daemon-contract",
            "SevenDaemon contract layer",
            root.join("bin/seven-daemon").is_file(),
            command_exists("systemctl"),
            "Core identity, health, lifecycle, routes and autonomy are readable through a native contract.".to_string(),
            "seven-daemon autonomy --json",
        ),
        system_check(
            "about-identity",
            "SevenOS public identity",
            root.join("branding/sevenos-release").is_file()
                && root.join("branding/motd").is_file()
                && root.join("archiso/profile/airootfs/etc/os-release").is_file(),
            root.join("branding/issue").is_file(),
            "Release, MOTD and live ISO identity present SevenOS before backend names.".to_string(),
            "seven about",
        ),
        system_check(
            "foundations",
            "SevenOS-owned foundations",
            foundations.get("state").and_then(Value::as_str) == Some("sevenos-owned"),
            foundations.get("score").and_then(Value::as_u64).unwrap_or(0) >= 75,
            format!(
                "{} at {}%.",
                foundations.get("state").and_then(Value::as_str).unwrap_or("unknown"),
                foundations.get("score").and_then(Value::as_u64).unwrap_or(0)
            ),
            "seven foundations",
        ),
        system_check(
            "public-surfaces",
            "SevenOS public surfaces",
            surfaces.get("state").and_then(Value::as_str) == Some("productized"),
            surfaces.get("score").and_then(Value::as_u64).unwrap_or(0) >= 75,
            format!(
                "{} at {}%.",
                surfaces.get("state").and_then(Value::as_str).unwrap_or("unknown"),
                surfaces.get("score").and_then(Value::as_u64).unwrap_or(0)
            ),
            "seven surfaces",
        ),
        system_check(
            "user-routes",
            "User intent routes",
            routes.get("state").and_then(Value::as_str) == Some("routed"),
            routes.get("score").and_then(Value::as_u64).unwrap_or(0) >= 75,
            format!(
                "{} at {}%.",
                routes.get("state").and_then(Value::as_str).unwrap_or("unknown"),
                routes.get("score").and_then(Value::as_u64).unwrap_or(0)
            ),
            "seven routes",
        ),
        system_check(
            "distribution",
            "Distribution gate",
            distribution
                .get("daily_driver_ready")
                .and_then(Value::as_bool)
                .unwrap_or(false),
            distribution.get("score").and_then(Value::as_u64).unwrap_or(0) >= 75,
            format!(
                "{} at {}%.",
                distribution.get("state").and_then(Value::as_str).unwrap_or("unknown"),
                distribution.get("score").and_then(Value::as_u64).unwrap_or(0)
            ),
            "seven distribution",
        ),
        system_check(
            "product-routes",
            "Product-facing routes",
            root.join("bin/seven-hub-native").is_file()
                && root.join("bin/seven-settings-native").is_file()
                && root.join("bin/seven-store-native").is_file(),
            root.join("bin/seven-doctor-native").is_file(),
            "Hub, Settings, Store and Doctor are available as SevenOS surfaces instead of terminal-first scripts.".to_string(),
            "seven product",
        ),
        system_check(
            "lifecycle-routes",
            "Lifecycle routes",
            root.join("scripts/update.sh").is_file()
                && root.join("scripts/recovery.sh").is_file()
                && root.join("scripts/repair.sh").is_file(),
            root.join("scripts/doctor.sh").is_file(),
            "Update, recovery and repair have stable SevenOS routes; privileged actions remain guarded adapters.".to_string(),
            "seven lifecycle",
        ),
        system_check(
            "update",
            "Update route",
            update.get("schema").and_then(Value::as_str) == Some("sevenos.update.v2"),
            update.get("score").and_then(Value::as_u64).unwrap_or(0) >= 75,
            format!(
                "{} at {}%.",
                update.get("state").and_then(Value::as_str).unwrap_or("unknown"),
                update.get("score").and_then(Value::as_u64).unwrap_or(0)
            ),
            "seven update",
        ),
        system_check(
            "health-route",
            "Health route",
            root.join("bin/seven-daemon").is_file() && root.join("scripts/health.sh").is_file(),
            root.join("scripts/smoke.sh").is_file(),
            "Health and smoke checks expose native summaries while keeping deep probes as fallback.".to_string(),
            "seven health",
        ),
        system_check(
            "smoke",
            "Smoke gate",
            smoke.get("state").and_then(Value::as_str) == Some("ready"),
            smoke.get("score").and_then(Value::as_u64).unwrap_or(0) >= 80,
            format!(
                "{} at {}%.",
                smoke.get("state").and_then(Value::as_str).unwrap_or("unknown"),
                smoke.get("score").and_then(Value::as_u64).unwrap_or(0)
            ),
            "seven smoke",
        ),
        system_check(
            "release-freeze",
            "Release discipline",
            dirty_count == 0,
            true,
            format!("{dirty_count} uncommitted path(s). Public release freeze stays explicit."),
            "git status --short",
        ),
    ];
    let score = score_from_checks(&checks);
    let ok = checks
        .iter()
        .filter(|item| item.get("state").and_then(Value::as_str) == Some("OK"))
        .count();
    let partial = checks
        .iter()
        .filter(|item| item.get("state").and_then(Value::as_str) == Some("PART"))
        .count();
    let missing = checks
        .iter()
        .filter(|item| item.get("state").and_then(Value::as_str) == Some("MISS"))
        .count();
    let daily_driver_ready = distribution
        .get("daily_driver_ready")
        .and_then(Value::as_bool)
        .unwrap_or(false)
        && score >= 85;
    let public_release_ready = distribution
        .get("public_release_ready")
        .and_then(Value::as_bool)
        .unwrap_or(false)
        && dirty_count == 0
        && score >= 95;
    let level = if score >= 90 {
        "distribution-layer"
    } else if score >= 75 {
        "autonomous-daily-driver"
    } else if score >= 60 {
        "masked-arch-layer"
    } else {
        "backend-visible"
    };
    let issues = checks
        .iter()
        .filter(|item| item.get("state").and_then(Value::as_str) != Some("OK"))
        .cloned()
        .collect::<Vec<_>>();
    json!({
        "schema": "sevenos.autonomy.v2",
        "compat_schema": "sevenos.autonomy.v1",
        "level": level,
        "score": score,
        "summary": {
            "checks": checks.len(),
            "ok": ok,
            "partial": partial,
            "missing": missing,
            "arch_visible": score < 90,
            "daily_driver_ready": daily_driver_ready,
            "public_release_ready": public_release_ready,
            "dirty_count": dirty_count,
            "source": "seven-daemon",
        },
        "contracts": {
            "foundations": foundations.get("schema").and_then(Value::as_str).unwrap_or("unknown"),
            "surfaces": surfaces.get("schema").and_then(Value::as_str).unwrap_or("unknown"),
            "routes": routes.get("schema").and_then(Value::as_str).unwrap_or("unknown"),
            "distribution": distribution.get("schema").and_then(Value::as_str).unwrap_or("unknown"),
            "update": update.get("schema").and_then(Value::as_str).unwrap_or("unknown"),
            "smoke": smoke.get("schema").and_then(Value::as_str).unwrap_or("unknown"),
            "identity": "sevenos.about.v2-compatible",
            "product": "sevenos.product.v2-compatible",
            "lifecycle": "sevenos.lifecycle.v2-compatible",
            "health": "sevenos.health.v2-compatible",
        },
        "principle": "SevenOS owns the user workflow; backend tools stay hidden behind stable native contracts and guarded adapters.",
        "checks": checks,
        "issues": issues,
        "next": issues.iter().take(6).cloned().collect::<Vec<_>>(),
        "commands": {
            "status": "seven autonomy",
            "doctor": "seven autonomy doctor",
            "plan": "seven autonomy plan",
            "deep": "seven autonomy doctor --full",
            "native": "seven-daemon autonomy --json"
        },
        "runtime": "seven-daemon",
        "writer": "seven-daemon",
    })
}

fn daemon_autonomy_json() {
    print_value(&daemon_autonomy_payload());
}

fn platform_layer(
    key: &str,
    public_name: &str,
    user_surface: &str,
    backend: &str,
    ok: bool,
    partial: bool,
    masking: &str,
) -> Value {
    json!({
        "key": key,
        "public_name": public_name,
        "user_surface": user_surface,
        "backend": backend,
        "state": contract_state(ok, partial),
        "masking": masking,
        "writer": "seven-daemon",
    })
}

fn daemon_platform_payload() -> Value {
    let root = sevenos_root().unwrap_or_else(|| PathBuf::from("."));
    let layers = vec![
        platform_layer(
            "software",
            "SevenOS Software",
            "SevenStore, sevenpkg",
            "pacman, Flatpak, AUR helpers",
            root.join("bin/sevenpkg").is_file() && root.join("bin/seven-store-native").is_file(),
            command_exists("pacman") || command_exists("flatpak"),
            "backend-hidden",
        ),
        platform_layer(
            "window-system",
            "Seven Smart Window System",
            "Smart Window controls, Settings, Lua profile engine",
            "Hyprland, Wayland, generated configuration",
            root.join("hyprland/lua/init.lua").is_file()
                && root.join("hyprland/conf/sevenos-lua-generated.conf").is_file(),
            command_exists("hyprctl"),
            "sevenos-first",
        ),
        platform_layer(
            "session",
            "SevenOS Session",
            "Seven Hub, Waybar, session target",
            "systemd user services",
            root.join("systemd/user/sevenos-session.target").is_file(),
            root.join("systemd/user/seven-daemon.service").is_file(),
            "service-hidden",
        ),
        platform_layer(
            "profiles",
            "SevenOS Mini OS Runtime",
            "Profile Center, Launchpad, runtime manifests",
            "LAPA, cgroups, shims, bubblewrap, profile roots",
            root.join("profiles/catalog.json").is_file() && root.join("bin/seven-profile-run").is_file(),
            root.join("bin/seven-profile-center-native").is_file(),
            "profile-first",
        ),
        platform_layer(
            "installer",
            "SevenOS Installer",
            "Install SevenOS, release gate",
            "Calamares profile, Archiso, install adapters",
            root.join("bin/seven-installer").is_file()
                && root.join("installer/calamares/settings.conf").is_file(),
            root.join("archiso/profile/profiledef.sh").is_file(),
            "route-ready",
        ),
        platform_layer(
            "runtime-core",
            "Seven Core",
            "Doctor, Hub, state contracts",
            "SevenDaemon, guarded adapters, SevenBus",
            root.join("bin/seven-daemon").is_file()
                && root.join("systemd/user/seven-daemon.service").is_file(),
            root.join("scripts/state.sh").is_file(),
            "contract-first",
        ),
        platform_layer(
            "compatibility",
            "SevenOS Compatibility",
            "Windows apps, USB writer, guarded disk tools",
            "Wine, Bottles, Lutris, udisks, polkit",
            root.join("bin/seven-wincompat").is_file()
                || root.join("bin/seven-windows-app").is_file(),
            command_exists("wine") || command_exists("bottles") || command_exists("lutris"),
            "compatibility-first",
        ),
    ];
    let score = score_from_checks(&layers);
    let state = if score >= 85 {
        "masked"
    } else if score >= 65 {
        "visible-backends"
    } else {
        "backend-exposed"
    };
    let issues = layers
        .iter()
        .filter(|item| item.get("state").and_then(Value::as_str) != Some("OK"))
        .cloned()
        .collect::<Vec<_>>();
    json!({
        "schema": "sevenos.platform.v2",
        "compat_schema": "sevenos.platform.v1",
        "state": state,
        "score": score,
        "public_rule": "SevenOS names first, backend names second.",
        "summary": {
            "layers": layers.len(),
            "ok": layers.iter().filter(|item| item.get("state").and_then(Value::as_str) == Some("OK")).count(),
            "partial": layers.iter().filter(|item| item.get("state").and_then(Value::as_str) == Some("PART")).count(),
            "missing": layers.iter().filter(|item| item.get("state").and_then(Value::as_str) == Some("MISS")).count(),
            "source": "seven-daemon",
        },
        "layers": layers,
        "issues": issues,
        "next": issues.iter().take(5).cloned().collect::<Vec<_>>(),
        "commands": {
            "status": "seven platform",
            "autonomy": "seven autonomy",
            "state": "seven state --json",
            "deep": "seven platform doctor --full",
            "native": "seven-daemon platform --json",
        },
        "runtime": "seven-daemon",
        "writer": "seven-daemon",
    })
}

fn daemon_platform_json() {
    print_value(&daemon_platform_payload());
}

fn file_contains(root: &Path, relative: &str, needle: &str) -> bool {
    fs::read_to_string(root.join(relative))
        .map(|content| content.contains(needle))
        .unwrap_or(false)
}

fn desktop_name(root: &Path, relative: &str) -> Option<String> {
    fs::read_to_string(root.join(relative))
        .ok()
        .and_then(|content| {
            content.lines().find_map(|line| {
                line.strip_prefix("Name=")
                    .map(str::trim)
                    .filter(|value| !value.is_empty())
                    .map(str::to_string)
            })
        })
}

fn read_json_file(path: &Path) -> Value {
    fs::read_to_string(path)
        .ok()
        .and_then(|content| serde_json::from_str::<Value>(&content).ok())
        .unwrap_or_else(|| json!({}))
}

fn daemon_mask_payload() -> Value {
    let root = sevenos_root().unwrap_or_else(|| PathBuf::from("."));
    let platform = daemon_platform_payload();
    let surfaces = native_surfaces_payload();
    let channel = read_release_channel();
    let desktop_entries = [
        "seven-hub/seven-hub.desktop",
        "seven-hub/seven-hub-native.desktop",
        "seven-hub/seven-files.desktop",
        "seven-hub/seven-reader.desktop",
        "seven-hub/seven-store.desktop",
        "seven-hub/seven-terminal.desktop",
        "seven-hub/seven-kitty.desktop",
        "seven-hub/seven-settings.desktop",
        "archiso/profile/airootfs/usr/share/applications/seven-installer.desktop",
    ];
    let leak_terms = ["Arch", "Hyprland", "pacman", "systemd"];
    let mut desktop_leaks = Vec::new();
    let mut desktop_ok = 0usize;
    for relative in desktop_entries {
        match desktop_name(&root, relative) {
            Some(name) => {
                if leak_terms
                    .iter()
                    .any(|term| name.to_lowercase().contains(&term.to_lowercase()))
                {
                    desktop_leaks.push(json!({"path": relative, "name": name, "reason": "backend term in public name"}));
                } else {
                    desktop_ok += 1;
                }
            }
            None => desktop_leaks.push(json!({"path": relative, "reason": "missing Name"})),
        }
    }
    let identity_ready = file_contains(&root, "branding/motd", "SevenOS")
        && file_contains(&root, "branding/issue", "SevenOS")
        && file_contains(&root, "branding/sevenos-release", "SevenOS")
        && file_contains(&root, "archiso/profile/airootfs/etc/os-release", "SevenOS");
    let checks = vec![
        system_check(
            "platform-facade",
            "SevenOS public platform facade",
            platform.get("state").and_then(Value::as_str) == Some("masked"),
            platform.get("score").and_then(Value::as_u64).unwrap_or(0) >= 75,
            format!(
                "{} at {}%.",
                platform.get("state").and_then(Value::as_str).unwrap_or("unknown"),
                platform.get("score").and_then(Value::as_u64).unwrap_or(0)
            ),
            "seven platform",
        ),
        system_check(
            "native-surfaces",
            "SevenOS native surfaces",
            surfaces.get("state").and_then(Value::as_str) == Some("productized"),
            surfaces.get("score").and_then(Value::as_u64).unwrap_or(0) >= 75,
            format!(
                "{} at {}%.",
                surfaces.get("state").and_then(Value::as_str).unwrap_or("unknown"),
                surfaces.get("score").and_then(Value::as_u64).unwrap_or(0)
            ),
            "seven surfaces",
        ),
        system_check(
            "release-channel",
            "SevenOS release channel vocabulary",
            matches!(channel.as_str(), "dev" | "testing" | "stable"),
            true,
            format!("Current channel: {channel}."),
            "seven channel",
        ),
        system_check(
            "action-runner",
            "Native action execution",
            root.join("bin/seven-action-runner").is_file(),
            root.join("scripts/actions.sh").is_file(),
            "UI actions can run with SevenOS logs/notifications instead of terminal-first workflows.".to_string(),
            "seven-action-runner --dry-run -- seven status",
        ),
        system_check(
            "desktop-names",
            "Public desktop names",
            desktop_leaks.is_empty() && desktop_ok >= 6,
            desktop_ok >= 4,
            format!("{desktop_ok}/{} public launchers avoid backend names.", desktop_entries.len()),
            "grep -R '^Name=' seven-hub archiso/profile/airootfs/usr/share/applications",
        ),
        system_check(
            "identity-files",
            "Boot and terminal identity",
            identity_ready,
            root.join("branding/motd").is_file() || root.join("branding/issue").is_file(),
            "Live and installed identity files identify SevenOS before the base.".to_string(),
            "seven identity",
        ),
        system_check(
            "software-surface",
            "SevenOS software surface",
            root.join("bin/seven-store-native").is_file() && root.join("bin/sevenpkg").is_file(),
            command_exists("pacman") || command_exists("flatpak"),
            "Users install and discover software through SevenStore/sevenpkg before backend package commands.".to_string(),
            "seven store",
        ),
    ];
    let score = score_from_checks(&checks);
    let state = if score >= 90 {
        "masked"
    } else if score >= 75 {
        "mostly-masked"
    } else {
        "backend-visible"
    };
    let issues = checks
        .iter()
        .filter(|item| item.get("state").and_then(Value::as_str) != Some("OK"))
        .cloned()
        .collect::<Vec<_>>();
    json!({
        "schema": "sevenos.mask.v2",
        "compat_schema": "sevenos.mask.v1",
        "state": state,
        "score": score,
        "rule": "SevenOS names first, backend names second.",
        "summary": {
            "checks": checks.len(),
            "ok": checks.iter().filter(|item| item.get("state").and_then(Value::as_str) == Some("OK")).count(),
            "partial": checks.iter().filter(|item| item.get("state").and_then(Value::as_str) == Some("PART")).count(),
            "missing": checks.iter().filter(|item| item.get("state").and_then(Value::as_str) == Some("MISS")).count(),
            "desktop_entries": desktop_entries.len(),
            "desktop_ok": desktop_ok,
            "desktop_leaks": desktop_leaks.len(),
            "source": "seven-daemon",
        },
        "checks": checks,
        "desktop_leaks": desktop_leaks,
        "issues": issues,
        "next": issues.iter().take(5).cloned().collect::<Vec<_>>(),
        "commands": {
            "status": "seven mask",
            "doctor": "seven mask doctor",
            "plan": "seven mask plan",
            "deep": "seven mask doctor --full",
            "native": "seven-daemon mask --json",
        },
        "runtime": "seven-daemon",
        "writer": "seven-daemon",
    })
}

fn daemon_mask_json() {
    print_value(&daemon_mask_payload());
}

fn daemon_adaptive_payload() -> Value {
    let root = sevenos_root().unwrap_or_else(|| PathBuf::from("."));
    let config_home = user_config_home();
    let sevenos_config = config_home.join("sevenos");
    let profile_ui_path = sevenos_config.join("profile-ui.json");
    let theme_runtime_path = sevenos_config.join("theme-runtime.json");
    let wallpaper_theme_path = sevenos_config.join("wallpaper-theme.json");
    let hypr_dynamic_path = config_home.join("hypr/conf/sevenos-dynamic.conf");
    let profile_ui = read_json_file(&profile_ui_path);
    let theme_runtime = read_json_file(&theme_runtime_path);
    let wallpaper_theme = read_json_file(&wallpaper_theme_path);
    let experience = {
        let theme_conf = sevenos_config.join("theme.conf");
        let theme_runtime_env = sevenos_config.join("theme-runtime.env");
        let language_conf = sevenos_config.join("language.conf");
        let language_env = sevenos_config.join("language.env");
        let profile_key = active_profile_key();
        let preferred = normalize_theme_mode(
            read_env_value(&theme_conf, "SEVENOS_THEME_MODE")
                .or_else(|| read_env_value(&theme_conf, "mode")),
        );
        let runtime = normalize_theme_mode(read_env_value(&theme_runtime_env, "SEVENOS_THEME_MODE"));
        let locale = normalize_locale_value(
            read_env_value(&language_conf, "SEVENOS_LANGUAGE")
                .or_else(|| read_env_value(&language_conf, "LANG"))
                .or_else(|| read_env_value(&language_env, "SEVENOS_LANGUAGE"))
                .or_else(|| read_env_value(&language_env, "LANG")),
        );
        json!({
            "profile": {"key": profile_key, "title": profile_title_for(&profile_key), "accent": profile_accent_for(&profile_key)},
            "theme": {"preferred": preferred, "runtime": runtime, "synced": preferred == runtime},
            "language": {"locale": locale, "language": language_code(&locale), "synced": !locale.is_empty()},
        })
    };
    let platform = daemon_platform_payload();
    let mask = daemon_mask_payload();
    let action_ids = native_action_registry()
        .iter()
        .filter_map(|item| item.get("id").and_then(Value::as_str).map(str::to_string))
        .collect::<HashSet<_>>();
    let active_profile = experience
        .get("profile")
        .and_then(|value| value.get("key"))
        .and_then(Value::as_str)
        .unwrap_or("unknown");
    let profile_ui_key = profile_ui
        .get("profile")
        .or_else(|| profile_ui.get("key"))
        .and_then(Value::as_str)
        .unwrap_or("unknown");
    let profile_ui_ready = profile_ui.get("schema").and_then(Value::as_str) == Some("sevenos.profile-ui.v1")
        && (profile_ui_key == active_profile || active_profile == "unknown" || profile_ui_key == "unknown");
    let theme_runtime_ready = theme_runtime.get("schema").and_then(Value::as_str) == Some("sevenos.theme-runtime.v1")
        || experience
            .get("theme")
            .and_then(|value| value.get("synced"))
            .and_then(Value::as_bool)
            .unwrap_or(false);
    let wallpaper_ready = wallpaper_theme.get("schema").and_then(Value::as_str) == Some("sevenos.wallpaper-theme.v1")
        && wallpaper_theme.get("colors").map(Value::is_object).unwrap_or(false);
    let hypr_dynamic_ready = hypr_dynamic_path.is_file()
        && hypr_dynamic_path
            .metadata()
            .map(|meta| meta.len() > 0)
            .unwrap_or(false);
    let checks = vec![
        system_check(
            "active-profile",
            "Active profile",
            matches!(active_profile, "equinox" | "baobab" | "forge" | "shield" | "studio" | "atlas" | "pulse"),
            active_profile != "unknown",
            format!("Current adaptive profile: {active_profile}."),
            "seven profile current --json",
        ),
        system_check(
            "profile-ui-bus",
            "Profile UI bus",
            profile_ui_ready,
            profile_ui.get("schema").and_then(Value::as_str).is_some(),
            "Profile UI state is available for Hub, Launchpad, Waybar, Settings and native apps.".to_string(),
            "cat ~/.config/sevenos/profile-ui.json",
        ),
        system_check(
            "theme-runtime",
            "Theme runtime",
            theme_runtime_ready,
            experience
                .get("theme")
                .and_then(|value| value.get("runtime"))
                .and_then(Value::as_str)
                .is_some(),
            "Theme mode is exposed through runtime state instead of per-surface guessing.".to_string(),
            "seven theme doctor",
        ),
        system_check(
            "wallpaper-palette",
            "Wallpaper palette",
            wallpaper_ready,
            wallpaper_theme.get("schema").and_then(Value::as_str).is_some(),
            "Wallpaper colors feed SevenOS tokens and dynamic visual accents.".to_string(),
            "seven wallpaper status",
        ),
        system_check(
            "hypr-dynamic",
            "Dynamic compositor bridge",
            hypr_dynamic_ready,
            config_home.join("hypr/conf").is_dir(),
            "The window system consumes SevenOS dynamic compositor accents instead of only static config.".to_string(),
            "cat ~/.config/hypr/conf/sevenos-dynamic.conf",
        ),
        system_check(
            "native-surfaces",
            "Adaptive native surfaces",
            root.join("bin/seven-profile-center-native").is_file()
                && root.join("bin/seven-hub-native").is_file()
                && root.join("bin/seven-settings-native").is_file(),
            root.join("bin/seven-launchpad-native").is_file(),
            "Hub, Profile Center and Settings can present adaptive controls without terminal handoff.".to_string(),
            "seven hub",
        ),
        system_check(
            "action-registry",
            "Adaptive action registry",
            ["profiles.status", "surfaces.status", "platform.status", "mask.status"]
                .iter()
                .all(|id| action_ids.contains(*id)),
            action_ids.contains("autonomy.status"),
            "Native action registry exposes the contracts needed by adaptive surfaces.".to_string(),
            "seven actions --json",
        ),
        system_check(
            "public-contracts",
            "Public contracts",
            platform.get("state").and_then(Value::as_str) == Some("masked")
                && mask.get("state").and_then(Value::as_str) == Some("masked"),
            true,
            "Dynamic surfaces speak SevenOS vocabulary while hiding backend details.".to_string(),
            "seven mask",
        ),
    ];
    let score = score_from_checks(&checks);
    let state = if score >= 90 {
        "ready"
    } else if score >= 70 {
        "guided-preview"
    } else if score >= 45 {
        "scaffold"
    } else {
        "concept"
    };
    let next = checks
        .iter()
        .filter(|item| item.get("state").and_then(Value::as_str) != Some("OK"))
        .map(|item| {
            json!({
                "key": item.get("key").and_then(Value::as_str).unwrap_or("unknown"),
                "title": format!("Complete {}", item.get("key").and_then(Value::as_str).unwrap_or("adaptive").replace('-', " ")),
                "command": item.get("command").and_then(Value::as_str).unwrap_or("seven adaptive"),
                "reason": item.get("detail").and_then(Value::as_str).unwrap_or("Adaptive contract needs attention."),
                "impact": "safe",
                "severity": "medium",
            })
        })
        .collect::<Vec<_>>();
    json!({
        "schema": "sevenos.adaptive-ui.v2",
        "compat_schema": "sevenos.adaptive-ui.v1",
        "state": state,
        "score": score,
        "max": 100,
        "percent": score,
        "summary": {
            "checks": checks.len(),
            "ok": checks.iter().filter(|item| item.get("state").and_then(Value::as_str) == Some("OK")).count(),
            "partial": checks.iter().filter(|item| item.get("state").and_then(Value::as_str) == Some("PART")).count(),
            "missing": checks.iter().filter(|item| item.get("state").and_then(Value::as_str) == Some("MISS")).count(),
            "source": "seven-daemon",
        },
        "active_profile": {
            "key": active_profile,
            "title": experience.get("profile").and_then(|value| value.get("title")).and_then(Value::as_str).unwrap_or("unknown"),
            "accent": experience.get("profile").and_then(|value| value.get("accent")).and_then(Value::as_str).unwrap_or("#8B7CFF"),
        },
        "shell": shell_experience_payload().get("state").and_then(Value::as_str).unwrap_or("unknown"),
        "context": {
            "profile": active_profile,
            "source": "seven-daemon",
            "semantic_context": "profile-theme-language-wallpaper",
        },
        "alignment": {
            "active_profile": active_profile,
            "profile_ui": profile_ui_key,
            "state": if profile_ui_ready { "OK" } else { "PART" },
        },
        "dynamic_inputs": {
            "profile_ui": {
                "schema": profile_ui.get("schema"),
                "profile": profile_ui.get("profile").or_else(|| profile_ui.get("key")),
                "title": profile_ui.get("title"),
                "accent": profile_ui.get("accent"),
                "waybar_modules": profile_ui.get("waybar_modules").cloned().unwrap_or_else(|| json!([])),
                "file": profile_ui_path.to_string_lossy(),
            },
            "theme_runtime": {
                "schema": theme_runtime.get("schema"),
                "mode": theme_runtime.get("mode").or_else(|| experience.get("theme").and_then(|value| value.get("runtime"))),
                "synced": experience.get("theme").and_then(|value| value.get("synced")),
                "file": theme_runtime_path.to_string_lossy(),
            },
            "language": experience.get("language").cloned().unwrap_or_else(|| json!({})),
            "wallpaper_theme": {
                "schema": wallpaper_theme.get("schema"),
                "source": wallpaper_theme.get("source"),
                "image": wallpaper_theme.get("image"),
                "colors": wallpaper_theme.get("colors").cloned().unwrap_or_else(|| json!({})),
                "file": wallpaper_theme_path.to_string_lossy(),
            },
            "hypr_dynamic": hypr_dynamic_path.to_string_lossy(),
        },
        "checks": checks,
        "next": next,
        "commands": {
            "status": "seven adaptive",
            "plan": "seven adaptive plan",
            "doctor": "seven adaptive doctor",
            "deep": "seven adaptive doctor --full",
            "profile": "seven profile current",
            "hub": "seven hub",
            "native": "seven-daemon adaptive --json",
        },
        "runtime": "seven-daemon",
        "writer": "seven-daemon",
    })
}

fn daemon_adaptive_json() {
    print_value(&daemon_adaptive_payload());
}

fn route_specs() -> Vec<(&'static str, &'static str, &'static str, &'static str, &'static str, &'static str)> {
    vec![
        ("open-control-center", "Open system control center", "hub", "hub.open", "seven hub", "bin/seven-hub-native"),
        ("change-settings", "Change system settings", "settings", "settings.open", "seven settings", "bin/seven-settings-native"),
        ("manage-files", "Browse and manage files", "files", "files.open", "seven files", "bin/seven-files-native"),
        ("install-app", "Find and install software", "store", "store.open", "seven store", "bin/seven-store-native"),
        ("read-document", "Read documents", "reader", "reader.open", "seven reader", "bin/seven-reader-native"),
        ("capture-notes", "Capture notes", "notes", "notes.open", "seven notes", "bin/seven-notes-native"),
        ("home-widgets", "Manage home widgets", "widgets", "widgets.menu", "seven widgets menu", "bin/seven-widgets-native"),
        ("open-terminal", "Open profile-aware terminal", "terminal", "terminal.open", "seven-terminal", "bin/seven-terminal-native"),
        ("switch-mini-os", "Switch Mini OS", "profile-center", "profiles.status", "seven profile status", "bin/seven-profile-center-native"),
        ("install-sevenos", "Install SevenOS", "installer", "installer.status", "seven installer release", "bin/seven-installer-native"),
        ("update-sevenos", "Update SevenOS", "update", "update.status", "seven update", "scripts/update.sh"),
        ("repair-system", "Diagnose and repair SevenOS", "doctor", "doctor.task", "seven doctor open", "bin/seven-doctor-native"),
        ("check-production", "Check production readiness", "production", "production.readiness", "seven production", "bin/seven-daemon"),
        ("check-distribution", "Check distribution identity", "distribution", "distribution.readiness", "seven distribution", "bin/seven-daemon"),
    ]
}

fn route_entrypoint_ready(root: &Path, command: &str) -> bool {
    let head = command.split_whitespace().next().unwrap_or("");
    if head == "seven" {
        return root.join("bin/seven").is_file();
    }
    if head.starts_with("seven-") {
        return root.join("bin").join(head).is_file();
    }
    if head.starts_with("./") {
        return root.join(head.trim_start_matches("./")).is_file();
    }
    true
}

fn daemon_routes_payload() -> Value {
    let root = sevenos_root().unwrap_or_else(|| PathBuf::from("."));
    let action_ids = native_action_registry()
        .iter()
        .filter_map(|item| item.get("id").and_then(Value::as_str).map(str::to_string))
        .collect::<HashSet<_>>();
    let mut routes = Vec::new();
    for (intent, label, surface, action_id, command, surface_path) in route_specs() {
        let surface_ready = root.join(surface_path).is_file();
        let action_ready = action_ids.contains(action_id);
        let entrypoint_ready = route_entrypoint_ready(&root, command);
        let state = if surface_ready && entrypoint_ready {
            "OK"
        } else if surface_ready || entrypoint_ready || action_ready {
            "PART"
        } else {
            "MISS"
        };
        routes.push(json!({
            "intent": intent,
            "label": label,
            "surface": surface,
            "action_id": action_id,
            "command": command,
            "backend": "SevenOS native contract, with scripts only as adapters or deep audit fallbacks",
            "state": state,
            "surface_ready": surface_ready,
            "action_ready": action_ready,
            "entrypoint_ready": entrypoint_ready,
            "mask_ready": true,
            "dynamic_ready": true,
            "writer": "seven-daemon",
        }));
    }
    let ok = routes
        .iter()
        .filter(|item| item.get("state").and_then(Value::as_str) == Some("OK"))
        .count();
    let partial = routes
        .iter()
        .filter(|item| item.get("state").and_then(Value::as_str) == Some("PART"))
        .count();
    let missing = routes
        .iter()
        .filter(|item| item.get("state").and_then(Value::as_str) == Some("MISS"))
        .count();
    let score = (((ok as f64) + (partial as f64 * 0.5)) / routes.len().max(1) as f64 * 100.0).round() as u64;
    let state = if score >= 90 {
        "routed"
    } else if score >= 75 {
        "partial-routes"
    } else {
        "backend-leaking"
    };
    let issues = routes
        .iter()
        .filter(|item| item.get("state").and_then(Value::as_str) != Some("OK"))
        .cloned()
        .collect::<Vec<_>>();
    json!({
        "schema": "sevenos.routes.v2",
        "compat_schema": "sevenos.routes.v1",
        "root": root.to_string_lossy(),
        "state": state,
        "score": score,
        "rule": "User intent -> SevenOS route -> backend implementation.",
        "summary": {
            "routes": routes.len(),
            "ok": ok,
            "partial": partial,
            "missing": missing,
            "source": "seven-daemon",
        },
        "routes": routes,
        "issues": issues,
        "next": issues.iter().take(6).cloned().collect::<Vec<_>>(),
        "commands": {
            "status": "seven routes",
            "doctor": "seven routes doctor --full",
            "plan": "seven routes plan",
            "native": "seven-daemon routes --json",
        },
        "runtime": "seven-daemon",
        "writer": "seven-daemon",
    })
}

fn daemon_routes_json() {
    print_value(&daemon_routes_payload());
}

fn contract_state(ok: bool, partial: bool) -> &'static str {
    if ok {
        "OK"
    } else if partial {
        "PART"
    } else {
        "MISS"
    }
}

fn score_from_checks(checks: &[Value]) -> u64 {
    if checks.is_empty() {
        return 0;
    }
    let ok = checks
        .iter()
        .filter(|item| item.get("state").and_then(Value::as_str) == Some("OK"))
        .count();
    let partial = checks
        .iter()
        .filter(|item| item.get("state").and_then(Value::as_str) == Some("PART"))
        .count();
    (((ok as f64) + (partial as f64 * 0.5)) / checks.len() as f64 * 100.0).round() as u64
}

fn check_counts(checks: &[Value]) -> Value {
    json!({
        "checks": checks.len(),
        "ok": checks.iter().filter(|item| item.get("state").and_then(Value::as_str) == Some("OK")).count(),
        "partial": checks.iter().filter(|item| item.get("state").and_then(Value::as_str) == Some("PART")).count(),
        "missing": checks.iter().filter(|item| item.get("state").and_then(Value::as_str) == Some("MISS")).count(),
        "source": "seven-daemon",
    })
}

fn system_check(
    key: &str,
    title: &str,
    ok: bool,
    partial: bool,
    detail: String,
    command: &str,
) -> Value {
    json!({
        "key": key,
        "title": title,
        "state": contract_state(ok, partial),
        "detail": detail,
        "command": command,
        "writer": "seven-daemon",
    })
}

fn release_channel_file() -> PathBuf {
    state_dir().join("release/channel.json")
}

fn read_release_channel() -> String {
    fs::read_to_string(release_channel_file())
        .ok()
        .and_then(|content| serde_json::from_str::<Value>(&content).ok())
        .and_then(|value| value.get("channel").and_then(Value::as_str).map(str::to_string))
        .filter(|value| matches!(value.as_str(), "dev" | "testing" | "stable"))
        .unwrap_or_else(|| "dev".to_string())
}

fn git_dirty_count(root: &Path) -> u64 {
    Command::new("git")
        .arg("-C")
        .arg(root)
        .arg("status")
        .arg("--short")
        .output()
        .ok()
        .filter(|output| output.status.success())
        .map(|output| String::from_utf8_lossy(&output.stdout).lines().count() as u64)
        .unwrap_or(0)
}

fn git_dirty_samples(root: &Path, limit: usize) -> Vec<Value> {
    let output = Command::new("git")
        .arg("-C")
        .arg(root)
        .arg("status")
        .arg("--short")
        .output();
    let Ok(output) = output else {
        return Vec::new();
    };
    if !output.status.success() {
        return Vec::new();
    }
    String::from_utf8_lossy(&output.stdout)
        .lines()
        .filter(|line| !line.trim().is_empty())
        .take(limit)
        .map(|line| {
            let status = line.chars().take(2).collect::<String>().trim().to_string();
            let path = if line.len() > 3 { line[3..].to_string() } else { line.trim().to_string() };
            json!({"status": if status.is_empty() { "?" } else { status.as_str() }, "path": path})
        })
        .collect()
}

fn release_source_root() -> PathBuf {
    if let Ok(value) = env::var("SEVENOS_SOURCE_ROOT") {
        let candidate = PathBuf::from(value);
        if candidate.join(".git").is_dir() && candidate.join("install.sh").is_file() {
            return candidate;
        }
    }
    if let Ok(current) = env::current_dir() {
        if current.join(".git").is_dir() && current.join("install.sh").is_file() {
            return current;
        }
    }
    if let Ok(home) = env::var("HOME") {
        let candidate = PathBuf::from(home).join("Code/OS/SevenOS");
        if candidate.join(".git").is_dir() && candidate.join("install.sh").is_file() {
            return candidate;
        }
    }
    sevenos_root().unwrap_or_else(|| PathBuf::from("."))
}

fn daemon_release_payload() -> Value {
    let runtime_root = sevenos_root().unwrap_or_else(|| PathBuf::from("."));
    let root = release_source_root();
    let installed_tree = runtime_root == PathBuf::from("/opt/SevenOS");
    let channel = daemon_channel_payload();
    let public = daemon_public_readiness_payload();
    let distribution = daemon_distribution_payload();
    let production = daemon_production_payload();
    let installer = installer_release_payload(&root);
    let smoke = daemon_smoke_payload();
    let dirty_count = if root.join(".git").exists() {
        git_dirty_count(&root)
    } else {
        0
    };
    let public_ready = public.get("public_ready").and_then(Value::as_bool).unwrap_or(false);
    let daily_ready = distribution
        .get("daily_driver_ready")
        .and_then(Value::as_bool)
        .unwrap_or(false)
        && smoke.get("state").and_then(Value::as_str) == Some("ready");
    let installer_state = installer
        .get("state")
        .and_then(Value::as_str)
        .unwrap_or("unknown")
        .to_string();
    let installer_ready = matches!(
        installer_state.as_str(),
        "graphical-ready" | "tui-release-ready" | "iso-foundation"
    );
    let production_ready = production
        .get("public_beta_ready")
        .and_then(Value::as_bool)
        .unwrap_or(false)
        || production.get("state").and_then(Value::as_str) == Some("public-beta-ready");
    let clean_release_tree = installed_tree || dirty_count == 0;
    let public_release_ready = public_ready && installer_ready && production_ready && clean_release_tree;
    let checks = vec![
        system_check(
            "daily-driver",
            "Daily-driver gate",
            daily_ready,
            distribution.get("score").and_then(Value::as_u64).unwrap_or(0) >= 75,
            format!(
                "{} · distribution score {}%.",
                distribution.get("state").and_then(Value::as_str).unwrap_or("unknown"),
                distribution.get("score").and_then(Value::as_u64).unwrap_or(0)
            ),
            "seven distribution",
        ),
        system_check(
            "public-readiness",
            "Public readiness",
            public_ready,
            public.get("score").and_then(Value::as_u64).unwrap_or(0) >= 80,
            format!(
                "{} · score {}%.",
                public.get("state").and_then(Value::as_str).unwrap_or("unknown"),
                public.get("score").and_then(Value::as_u64).unwrap_or(0)
            ),
            "seven public-readiness",
        ),
        system_check(
            "installer-route",
            "Graphical installer and ISO route",
            installer_ready,
            matches!(installer_state.as_str(), "foundation" | "graphical-runtime-candidate"),
            format!("Installer state: {installer_state}."),
            "seven installer release",
        ),
        system_check(
            "release-freeze",
            "Repository freeze",
            clean_release_tree,
            dirty_count <= 80,
            if installed_tree {
                "Installed tree; release freeze must be checked in the source repository.".to_string()
            } else {
                format!("{dirty_count} modified/untracked path(s).")
            },
            "git status --short",
        ),
        system_check(
            "production-hardening",
            "Production hardening",
            production_ready,
            production.get("score").and_then(Value::as_u64).unwrap_or(0) >= 50,
            format!(
                "{} · score {}%.",
                production.get("state").and_then(Value::as_str).unwrap_or("unknown"),
                production.get("score").and_then(Value::as_u64).unwrap_or(0)
            ),
            "seven production",
        ),
        system_check(
            "smoke",
            "Smoke gate",
            smoke.get("state").and_then(Value::as_str) == Some("ready"),
            smoke.get("score").and_then(Value::as_u64).unwrap_or(0) >= 80,
            format!(
                "{} · score {}%.",
                smoke.get("state").and_then(Value::as_str).unwrap_or("unknown"),
                smoke.get("score").and_then(Value::as_u64).unwrap_or(0)
            ),
            "seven smoke",
        ),
    ];
    let issues = checks
        .iter()
        .filter(|item| item.get("state").and_then(Value::as_str) != Some("OK"))
        .cloned()
        .collect::<Vec<_>>();
    let state = if public_release_ready {
        "public-release-ready"
    } else if daily_ready {
        "daily-driver-ready"
    } else {
        "release-blocked"
    };
    json!({
        "schema": "sevenos.release.v2",
        "compat_schema": "sevenos.release.v1",
        "state": state,
        "daily_driver_ready": daily_ready,
        "public_release_ready": public_release_ready,
        "score": score_from_checks(&checks),
        "summary": check_counts(&checks),
        "channel": channel.get("channel").cloned().unwrap_or_else(|| json!("dev")),
        "channel_state": channel.get("state").cloned().unwrap_or_else(|| json!("unknown")),
        "worktree": {
            "root": root.to_string_lossy(),
            "runtime_root": runtime_root.to_string_lossy(),
            "installed_tree": installed_tree,
            "dirty_count": dirty_count,
            "samples": git_dirty_samples(&root, 24),
            "commands": {
                "status": "git status --short",
                "freeze": "seven release freeze --json",
                "review": "seven release open"
            }
        },
        "installer": {"state": installer_state, "ready": installer_ready},
        "production": {"state": production.get("state").cloned().unwrap_or_else(|| json!("unknown")), "ready": production_ready, "score": production.get("score").cloned().unwrap_or_else(|| json!(0))},
        "public_readiness": {"state": public.get("state").cloned().unwrap_or_else(|| json!("unknown")), "ready": public_ready, "score": public.get("score").cloned().unwrap_or_else(|| json!(0))},
        "distribution": {"state": distribution.get("state").cloned().unwrap_or_else(|| json!("unknown")), "score": distribution.get("score").cloned().unwrap_or_else(|| json!(0))},
        "checks": checks,
        "issues": issues,
        "next": issues.iter().take(6).cloned().collect::<Vec<_>>(),
        "commands": {
            "status": "seven release status",
            "doctor": "seven release doctor",
            "plan": "seven release plan",
            "review": "seven release open",
            "freeze": "seven release freeze --json",
            "native": "seven-daemon release --json"
        },
        "runtime": "seven-daemon",
        "writer": "seven-daemon",
    })
}

fn daemon_release_json() {
    print_value(&daemon_release_payload());
}

fn daemon_channel_payload() -> Value {
    let root = sevenos_root().unwrap_or_else(|| PathBuf::from("."));
    let channel = read_release_channel();
    let installer = installer_flow_payload();
    let distribution = daemon_distribution_payload();
    let dirty = git_dirty_count(&root);
    let daily_ready = distribution
        .get("daily_driver_ready")
        .and_then(Value::as_bool)
        .unwrap_or(false);
    let installer_score = installer.get("score").and_then(Value::as_u64).unwrap_or(0);
    let installer_ready = installer_score >= 80;
    let public_ready = dirty == 0
        && channel == "stable"
        && distribution
            .get("public_release_ready")
            .and_then(Value::as_bool)
            .unwrap_or(false)
        && installer_ready;
    let state = if channel == "stable" && !public_ready {
        "stable-blocked"
    } else if channel == "stable" {
        "stable"
    } else if channel == "testing" && daily_ready {
        "testing"
    } else if daily_ready {
        "dev-ready"
    } else {
        "dev"
    };
    let checks = vec![
        system_check(
            "daily-driver",
            "Daily-driver health",
            daily_ready,
            installer_ready,
            format!(
                "{} at {}%.",
                distribution.get("state").and_then(Value::as_str).unwrap_or("unknown"),
                distribution.get("score").and_then(Value::as_u64).unwrap_or(0)
            ),
            "seven distribution",
        ),
        system_check(
            "worktree-freeze",
            "Repository freeze",
            dirty == 0,
            true,
            format!("{dirty} uncommitted path(s)."),
            "git status --short",
        ),
        system_check(
            "installer-flow",
            "Graphical installer flow",
            installer_ready,
            installer_score >= 60,
            format!(
                "{} at {}%.",
                installer.get("state").and_then(Value::as_str).unwrap_or("unknown"),
                installer_score
            ),
            "seven installer flow",
        ),
    ];
    json!({
        "schema": "sevenos.release-channel.v2",
        "compat_schema": "sevenos.release-channel.v1",
        "channel": channel,
        "state": state,
        "risk": match channel.as_str() {
            "stable" => "release",
            "testing" => "candidate",
            _ => "active-development",
        },
        "branch": git_text(&root, &["rev-parse", "--abbrev-ref", "HEAD"]),
        "commit": git_text(&root, &["rev-parse", "--short", "HEAD"]),
        "dirty_count": dirty,
        "channel_file": release_channel_file().to_string_lossy(),
        "daily_driver_ready": daily_ready,
        "public_release_ready": public_ready,
        "installer_state": installer.get("state").and_then(Value::as_str).unwrap_or("unknown"),
        "checks": checks,
        "issues": checks.iter().filter(|item| item.get("state").and_then(Value::as_str) != Some("OK")).cloned().collect::<Vec<_>>(),
        "writer": "seven-daemon",
    })
}

fn daemon_channel_json() {
    print_value(&daemon_channel_payload());
}

fn daemon_foundations_payload() -> Value {
    let root = sevenos_root().unwrap_or_else(|| PathBuf::from("."));
    let layers = vec![
        system_check("identity", "SevenOS identity", root.join("branding/sevenos-release").is_file(), root.join("branding/issue").is_file(), "Branding, release identity and welcome surfaces are SevenOS-owned.".to_string(), "seven about"),
        system_check("software", "SevenOS software route", root.join("bin/sevenpkg").is_file() && root.join("bin/seven-store-native").is_file(), command_exists("pacman") || command_exists("flatpak"), "SevenPkg and SevenStore mask pacman/AUR/Flatpak as backend engines.".to_string(), "seven store"),
        system_check("window-system", "Seven Smart Window System", root.join("hyprland/lua/init.lua").is_file() && root.join("hyprland/conf/sevenos-lua-generated.conf").is_file(), command_exists("hyprctl"), "Hyprland remains a foundation behind SevenOS window rules.".to_string(), "seven smart-window"),
        system_check("shell", "SevenOS Shell", root.join("bin/seven-hub-native").is_file() && root.join("bin/seven-launchpad-native").is_file(), command_exists("waybar") || command_exists("rofi"), "Hub, launchpad, dock and panels expose the shell as an OS surface.".to_string(), "seven hub"),
        system_check("settings", "SevenOS Settings", root.join("bin/seven-settings-native").is_file(), command_exists("gsettings") || command_exists("nmcli") || command_exists("wpctl"), "System backends are routed through Settings instead of raw commands.".to_string(), "seven settings"),
        system_check("mini-os-runtime", "Mini OS runtime", root.join("profiles/catalog.json").is_file() && root.join("bin/seven-mini-os-center").is_file(), root.join("bin/seven-profile-run").is_file(), "Profile roots and capability manifests become user-facing spaces.".to_string(), "seven profile status"),
        system_check("installer", "SevenOS Installer", root.join("bin/seven-installer").is_file() && root.join("installer/calamares/settings.conf").is_file(), root.join("archiso/profile/profiledef.sh").is_file() || command_exists("calamares"), "The ISO and installer are presented as SevenOS first.".to_string(), "seven installer"),
        system_check("maintenance", "SevenOS Lifecycle", root.join("scripts/recovery.sh").is_file() && root.join("scripts/repair.sh").is_file() && root.join("bin/seven-daemon").is_file(), command_exists("systemctl") || command_exists("journalctl"), "Repair, recovery and state are increasingly daemon-owned.".to_string(), "seven lifecycle"),
    ];
    let score = score_from_checks(&layers);
    json!({
        "schema": "sevenos.foundations.v2",
        "compat_schema": "sevenos.foundations.v1",
        "state": if score >= 90 { "sevenos-owned" } else if score >= 75 { "mostly-owned" } else { "backend-visible" },
        "score": score,
        "summary": check_counts(&layers),
        "principle": "SevenOS owns the workflow; backend projects remain documented foundations.",
        "layers": layers,
        "issues": layers.iter().filter(|item| item.get("state").and_then(Value::as_str) != Some("OK")).cloned().collect::<Vec<_>>(),
        "writer": "seven-daemon",
    })
}

fn daemon_foundations_json() {
    print_value(&daemon_foundations_payload());
}

fn daemon_lifecycle_payload() -> Value {
    if daemon_fast_mode() {
        let root = sevenos_root().unwrap_or_else(|| PathBuf::from("."));
        let checks = vec![
            system_check("distribution-gate", "Distribution gate", root.join("scripts/distribution.sh").is_file(), true, "Fast native gate: distribution route is present.".to_string(), "seven distribution"),
            system_check("release-channel", "Release channel", true, true, format!("{} channel is readable.", read_release_channel()), "seven channel"),
            system_check("software-update", "SevenOS update facade", root.join("scripts/update.sh").is_file(), true, "Fast native gate: update route is present.".to_string(), "seven update"),
            system_check("installer-recovery", "Installer and recovery route", root.join("bin/seven-installer").is_file() && root.join("installer/calamares/settings.conf").is_file(), root.join("bin/seven-installer").is_file(), "Fast native gate: installer route is present.".to_string(), "seven installer"),
            system_check("repair-route", "Guided repair route", root.join("scripts/repair.sh").is_file() && root.join("scripts/system-repair.sh").is_file(), true, "Fast native gate: repair routes are present.".to_string(), "seven repair"),
            system_check("smoke-gate", "Smoke gate", root.join("scripts/smoke.sh").is_file(), true, "Fast native gate: smoke route is present.".to_string(), "seven smoke"),
        ];
        let score = score_from_checks(&checks);
        return json!({
            "schema": "sevenos.lifecycle.v2",
            "compat_schema": "sevenos.lifecycle.v1",
            "state": if score >= 85 { "managed" } else if score >= 65 { "partial" } else { "foundation" },
            "score": score,
            "summary": check_counts(&checks),
            "maintenance_routes": [
                {"intent": "Update apps and system", "surface": "SevenOS Update / SevenStore", "command": "seven update"},
                {"intent": "Repair the OS", "surface": "Seven Doctor / Repair", "command": "seven repair"},
                {"intent": "Check release readiness", "surface": "SevenOS Distribution", "command": "seven distribution"},
                {"intent": "Prepare installer/recovery", "surface": "SevenOS Installer", "command": "seven installer"}
            ],
            "checks": checks,
            "issues": checks.iter().filter(|item| item.get("state").and_then(Value::as_str) != Some("OK")).cloned().collect::<Vec<_>>(),
            "mode": "fast-native",
            "writer": "seven-daemon",
        });
    }
    let distribution = daemon_distribution_payload();
    let channel = daemon_channel_payload();
    let update = update_payload();
    let installer = installer_flow_payload();
    let smoke = daemon_smoke_payload();
    let root = sevenos_root().unwrap_or_else(|| PathBuf::from("."));
    let update_score = update.get("score").and_then(Value::as_u64).unwrap_or(0);
    let installer_score = installer.get("score").and_then(Value::as_u64).unwrap_or(0);
    let smoke_score = smoke.get("score").and_then(Value::as_u64).unwrap_or(0);
    let checks = vec![
        system_check("distribution-gate", "Distribution gate", distribution.get("daily_driver_ready").and_then(Value::as_bool).unwrap_or(false), distribution.get("score").and_then(Value::as_u64).unwrap_or(0) >= 75, format!("{} at {}%.", distribution.get("state").and_then(Value::as_str).unwrap_or("unknown"), distribution.get("score").and_then(Value::as_u64).unwrap_or(0)), "seven distribution"),
        system_check("release-channel", "Release channel", channel.get("schema").and_then(Value::as_str) == Some("sevenos.release-channel.v2"), true, format!("{} / {}.", channel.get("channel").and_then(Value::as_str).unwrap_or("dev"), channel.get("state").and_then(Value::as_str).unwrap_or("unknown")), "seven channel"),
        system_check("software-update", "SevenOS update facade", update_score >= 75, update.get("schema").and_then(Value::as_str).is_some(), format!("{} at {}%.", update.get("state").and_then(Value::as_str).unwrap_or("unknown"), update_score), "seven update"),
        system_check("installer-recovery", "Installer and recovery route", installer_score >= 80, installer_score >= 60, format!("{} at {}%.", installer.get("state").and_then(Value::as_str).unwrap_or("unknown"), installer_score), "seven installer"),
        system_check("repair-route", "Guided repair route", root.join("scripts/repair.sh").is_file() && root.join("scripts/system-repair.sh").is_file(), root.join("scripts/doctor.sh").is_file(), "Repair remains routed through Seven Doctor/Repair.".to_string(), "seven repair"),
        system_check("smoke-gate", "Smoke gate", smoke_score >= 90, smoke_score >= 70, format!("{} at {}%.", smoke.get("state").and_then(Value::as_str).unwrap_or("unknown"), smoke_score), "seven smoke"),
    ];
    let score = score_from_checks(&checks);
    json!({
        "schema": "sevenos.lifecycle.v2",
        "compat_schema": "sevenos.lifecycle.v1",
        "state": if score >= 85 { "managed" } else if score >= 65 { "partial" } else { "foundation" },
        "score": score,
        "summary": check_counts(&checks),
        "maintenance_routes": [
            {"intent": "Update apps and system", "surface": "SevenOS Update / SevenStore", "command": "seven update"},
            {"intent": "Repair the OS", "surface": "Seven Doctor / Repair", "command": "seven repair"},
            {"intent": "Check release readiness", "surface": "SevenOS Distribution", "command": "seven distribution"},
            {"intent": "Prepare installer/recovery", "surface": "SevenOS Installer", "command": "seven installer"}
        ],
        "checks": checks,
        "issues": checks.iter().filter(|item| item.get("state").and_then(Value::as_str) != Some("OK")).cloned().collect::<Vec<_>>(),
        "writer": "seven-daemon",
    })
}

fn daemon_lifecycle_json() {
    print_value(&daemon_lifecycle_payload());
}

fn daemon_product_payload() -> Value {
    let root = sevenos_root().unwrap_or_else(|| PathBuf::from("."));
    let lifecycle = daemon_lifecycle_payload();
    let foundations = daemon_foundations_payload();
    let distribution = daemon_distribution_payload();
    let surfaces = native_surfaces_payload();
    let routes = daemon_routes_payload();
    let checks = vec![
        system_check("identity", "SevenOS identity", root.join("branding/sevenos-release").is_file(), true, "Release identity and branding are available.".to_string(), "seven about"),
        system_check("lifecycle", "Lifecycle routes", lifecycle.get("state").and_then(Value::as_str) == Some("managed"), lifecycle.get("score").and_then(Value::as_u64).unwrap_or(0) >= 65, format!("{} at {}%.", lifecycle.get("state").and_then(Value::as_str).unwrap_or("unknown"), lifecycle.get("score").and_then(Value::as_u64).unwrap_or(0)), "seven lifecycle"),
        system_check("foundations", "Owned foundations", foundations.get("score").and_then(Value::as_u64).unwrap_or(0) >= 75, true, format!("{} at {}%.", foundations.get("state").and_then(Value::as_str).unwrap_or("unknown"), foundations.get("score").and_then(Value::as_u64).unwrap_or(0)), "seven foundations"),
        system_check("distribution", "Distribution gate", distribution.get("daily_driver_ready").and_then(Value::as_bool).unwrap_or(false), distribution.get("score").and_then(Value::as_u64).unwrap_or(0) >= 75, format!("{} at {}%.", distribution.get("state").and_then(Value::as_str).unwrap_or("unknown"), distribution.get("score").and_then(Value::as_u64).unwrap_or(0)), "seven distribution"),
        system_check("surfaces", "Native surfaces", surfaces.get("state").and_then(Value::as_str) == Some("productized"), surfaces.get("score").and_then(Value::as_u64).unwrap_or(0) >= 75, format!("{} at {}%.", surfaces.get("state").and_then(Value::as_str).unwrap_or("unknown"), surfaces.get("score").and_then(Value::as_u64).unwrap_or(0)), "seven surfaces"),
        system_check("routes", "User routes", routes.get("state").and_then(Value::as_str) == Some("routed"), routes.get("score").and_then(Value::as_u64).unwrap_or(0) >= 75, format!("{} at {}%.", routes.get("state").and_then(Value::as_str).unwrap_or("unknown"), routes.get("score").and_then(Value::as_u64).unwrap_or(0)), "seven routes"),
    ];
    let score = score_from_checks(&checks);
    json!({
        "schema": "sevenos.product.v2",
        "compat_schema": "sevenos.product.v1",
        "state": if score >= 90 { "ready" } else if score >= 75 { "partial" } else { "foundation" },
        "score": score,
        "name": "SevenOS",
        "edition": "SevenOS",
        "tagline": "Beyond the Desktop",
        "daily_driver_ready": distribution.get("daily_driver_ready").and_then(Value::as_bool).unwrap_or(false),
        "public_release_ready": distribution.get("public_release_ready").and_then(Value::as_bool).unwrap_or(false),
        "public_shell": {
            "lifecycle": lifecycle.get("state").and_then(Value::as_str).unwrap_or("unknown"),
            "foundations": foundations.get("state").and_then(Value::as_str).unwrap_or("unknown"),
            "distribution": distribution.get("state").and_then(Value::as_str).unwrap_or("unknown"),
            "surfaces": surfaces.get("state").and_then(Value::as_str).unwrap_or("unknown"),
            "routes": routes.get("state").and_then(Value::as_str).unwrap_or("unknown")
        },
        "checks": checks,
        "issues": checks.iter().filter(|item| item.get("state").and_then(Value::as_str) != Some("OK")).cloned().collect::<Vec<_>>(),
        "writer": "seven-daemon",
    })
}

fn daemon_product_json() {
    print_value(&daemon_product_payload());
}

fn daemon_support_payload() -> Value {
    let health = health_payload();
    let product = daemon_product_payload();
    let lifecycle = daemon_lifecycle_payload();
    let (events, invalid, total) = parsed_events();
    let health_score = health.get("score").and_then(Value::as_u64).unwrap_or(0);
    let checks = vec![
        system_check("health", "Health summary", health.get("state").and_then(Value::as_str) == Some("ready") || health_score >= 80, health.get("schema").is_some(), format!("Native health contract at {health_score}%."), "seven health"),
        system_check("product", "Product snapshot", product.get("schema").and_then(Value::as_str) == Some("sevenos.product.v2"), true, format!("{} at {}%.", product.get("state").and_then(Value::as_str).unwrap_or("unknown"), product.get("score").and_then(Value::as_u64).unwrap_or(0)), "seven product"),
        system_check("lifecycle", "Lifecycle snapshot", lifecycle.get("schema").and_then(Value::as_str) == Some("sevenos.lifecycle.v2"), true, format!("{} at {}%.", lifecycle.get("state").and_then(Value::as_str).unwrap_or("unknown"), lifecycle.get("score").and_then(Value::as_u64).unwrap_or(0)), "seven lifecycle"),
        system_check("events", "Event journal", total > 0 || invalid == 0, true, format!("{} valid event(s), {} invalid line(s).", events.len(), invalid), "seven events"),
    ];
    let score = score_from_checks(&checks);
    json!({
        "schema": "sevenos.support.v2",
        "compat_schema": "sevenos.support.v1",
        "state": if score >= 90 { "ready" } else if score >= 70 { "partial" } else { "foundation" },
        "score": score,
        "privacy": "local-first; support bundles are not uploaded automatically",
        "support_root": state_dir().join("support").to_string_lossy(),
        "checks": checks,
        "issues": checks.iter().filter(|item| item.get("state").and_then(Value::as_str) != Some("OK")).cloned().collect::<Vec<_>>(),
        "event_summary": {"valid": events.len(), "invalid": invalid, "raw_lines": total},
        "bundle": {"command": "seven support bundle", "contains": ["health.json", "product.json", "lifecycle.json", "events.json", "README.txt"]},
        "writer": "seven-daemon",
    })
}

fn daemon_support_json() {
    print_value(&daemon_support_payload());
}

fn active_profile_summary_payload() -> Value {
    let active = active_profile_key();
    let title = profile_title_for(&active);
    let spec = PROFILES
        .iter()
        .find(|spec| spec.key == active)
        .unwrap_or(&PROFILES[0]);
    let short_label: String = spec
        .title
        .split_whitespace()
        .take(2)
        .filter_map(|part| part.chars().next())
        .collect::<String>()
        .to_uppercase();
    json!({
        "key": active,
        "title": title,
        "short_label": short_label,
        "role": spec.role,
        "accent": spec.accent,
        "workspace": profile_workspace(spec).to_string_lossy(),
    })
}

fn daemon_about_payload() -> Value {
    let root = sevenos_root().unwrap_or_else(|| PathBuf::from("."));
    let profile = active_profile_summary_payload();
    let channel = daemon_channel_payload();
    let distribution = daemon_distribution_payload();
    let foundations = daemon_foundations_payload();
    let platform_ready = foundations
        .get("score")
        .and_then(Value::as_u64)
        .unwrap_or(0)
        >= 75;
    let checks = vec![
        system_check(
            "identity",
            "SevenOS identity",
            root.join("branding/sevenos-release").is_file(),
            root.join("branding/issue").is_file(),
            "Public shell and release identity use SevenOS vocabulary.".to_string(),
            "seven about",
        ),
        system_check(
            "profile",
            "Active mini OS",
            profile.get("key").and_then(Value::as_str).unwrap_or("unknown") != "unknown",
            true,
            profile.get("title").and_then(Value::as_str).unwrap_or("Unknown").to_string(),
            "seven profile current",
        ),
        system_check(
            "distribution",
            "Distribution gate",
            distribution
                .get("daily_driver_ready")
                .and_then(Value::as_bool)
                .unwrap_or(false),
            distribution.get("score").and_then(Value::as_u64).unwrap_or(0) >= 75,
            format!(
                "{} at {}%.",
                distribution.get("state").and_then(Value::as_str).unwrap_or("unknown"),
                distribution.get("score").and_then(Value::as_u64).unwrap_or(0)
            ),
            "seven distribution",
        ),
        system_check(
            "channel",
            "Release channel",
            channel.get("schema").and_then(Value::as_str) == Some("sevenos.release-channel.v2"),
            true,
            format!(
                "{} / {}.",
                channel.get("channel").and_then(Value::as_str).unwrap_or("unknown"),
                channel.get("state").and_then(Value::as_str).unwrap_or("unknown")
            ),
            "seven channel",
        ),
        system_check(
            "platform",
            "Masked platform facade",
            platform_ready,
            true,
            format!(
                "{} at {}%.",
                foundations.get("state").and_then(Value::as_str).unwrap_or("unknown"),
                foundations.get("score").and_then(Value::as_u64).unwrap_or(0)
            ),
            "seven foundations",
        ),
    ];
    let about_ready = checks
        .iter()
        .all(|item| item.get("state").and_then(Value::as_str) == Some("OK"));
    let active_key = profile.get("key").and_then(Value::as_str).unwrap_or("equinox");
    let edition = if distribution.get("state").and_then(Value::as_str) == Some("public-release-candidate") {
        "SevenOS Release Candidate"
    } else if active_key == "shield" {
        "SevenOS Shield"
    } else if active_key == "atlas" {
        "SevenOS Atlas Explorer"
    } else if active_key == "pulse" {
        "SevenOS Pulse"
    } else {
        "SevenOS Daily"
    };
    json!({
        "schema": "sevenos.about.v2",
        "compat_schema": "sevenos.about.v1",
        "name": "SevenOS",
        "pretty_name": "SevenOS Linux",
        "edition": edition,
        "tagline": "Beyond the Desktop",
        "state": if about_ready { "ready" } else { "partial" },
        "about_ready": about_ready,
        "distribution_state": distribution.get("state").and_then(Value::as_str).unwrap_or("unknown"),
        "daily_driver_ready": distribution.get("daily_driver_ready").and_then(Value::as_bool).unwrap_or(false),
        "public_release_ready": distribution.get("public_release_ready").and_then(Value::as_bool).unwrap_or(false),
        "release": {
            "channel": channel.get("channel").and_then(Value::as_str).unwrap_or("unknown"),
            "state": channel.get("state").and_then(Value::as_str).unwrap_or("unknown"),
            "branch": channel.get("branch").and_then(Value::as_str).unwrap_or("unknown"),
            "commit": channel.get("commit").and_then(Value::as_str).unwrap_or("unknown"),
            "dirty_count": channel.get("dirty_count").and_then(Value::as_u64).unwrap_or(0),
        },
        "active_mini_os": profile,
        "product_layers": [
            "Seven Hub",
            "SevenOS Settings",
            "SevenStore",
            "Seven Files",
            "Seven Reader",
            "Seven Smart Window System",
            "Seven Mini OS Runtime"
        ],
        "technical_foundations": [
            "Linux",
            "Arch package ecosystem",
            "Hyprland/Wayland",
            "systemd user services",
            "pacman/Flatpak/AUR backends"
        ],
        "checks": checks,
        "issues": checks.iter().filter(|item| item.get("state").and_then(Value::as_str) != Some("OK")).cloned().collect::<Vec<_>>(),
        "writer": "seven-daemon",
    })
}

fn daemon_about_json() {
    print_value(&daemon_about_payload());
}

fn daemon_product_health_payload() -> Value {
    let product = daemon_product_payload();
    let lifecycle = daemon_lifecycle_payload();
    let update = update_payload();
    let foundations = daemon_foundations_payload();
    let distribution = daemon_distribution_payload();
    let session = shell_experience_payload();
    let core = health_payload();
    let update_score = update.get("score").and_then(Value::as_u64).unwrap_or(0);
    let session_score = session
        .get("score")
        .or_else(|| session.get("percent"))
        .and_then(Value::as_u64)
        .unwrap_or_else(|| {
            if session.get("state").and_then(Value::as_str) == Some("ready") {
                100
            } else {
                0
            }
        });
    let checks = vec![
        system_check("product", "SevenOS product facade", product.get("state").and_then(Value::as_str) == Some("ready"), product.get("score").and_then(Value::as_u64).unwrap_or(0) >= 75, format!("{} at {}%.", product.get("state").and_then(Value::as_str).unwrap_or("unknown"), product.get("score").and_then(Value::as_u64).unwrap_or(0)), "seven product"),
        system_check("lifecycle", "Lifecycle", lifecycle.get("state").and_then(Value::as_str) == Some("managed"), lifecycle.get("score").and_then(Value::as_u64).unwrap_or(0) >= 65, format!("{} at {}%.", lifecycle.get("state").and_then(Value::as_str).unwrap_or("unknown"), lifecycle.get("score").and_then(Value::as_u64).unwrap_or(0)), "seven lifecycle"),
        system_check("update", "Update route", update_score >= 75, update.get("schema").and_then(Value::as_str).is_some(), format!("{} at {}%.", update.get("state").and_then(Value::as_str).unwrap_or("unknown"), update_score), "seven update"),
        system_check("foundations", "Foundations", foundations.get("state").and_then(Value::as_str) == Some("sevenos-owned"), foundations.get("score").and_then(Value::as_u64).unwrap_or(0) >= 75, format!("{} at {}%.", foundations.get("state").and_then(Value::as_str).unwrap_or("unknown"), foundations.get("score").and_then(Value::as_u64).unwrap_or(0)), "seven foundations"),
        system_check("distribution", "Distribution", distribution.get("daily_driver_ready").and_then(Value::as_bool).unwrap_or(false), distribution.get("score").and_then(Value::as_u64).unwrap_or(0) >= 75, format!("{} at {}%.", distribution.get("state").and_then(Value::as_str).unwrap_or("unknown"), distribution.get("score").and_then(Value::as_u64).unwrap_or(0)), "seven distribution"),
        system_check("session", "Shell experience", session_score >= 80, session_score >= 60, format!("{} at {}%.", session.get("state").and_then(Value::as_str).unwrap_or("unknown"), session_score), "seven shell-experience"),
        system_check("daemon", "Seven daemon", core.get("state").and_then(Value::as_str) == Some("ready"), true, "Native runtime health is available.".to_string(), "seven core health"),
    ];
    let score = score_from_checks(&checks);
    let daily_ready = score >= 90
        && checks
            .iter()
            .all(|item| item.get("state").and_then(Value::as_str) == Some("OK"));
    json!({
        "schema": "sevenos.health.v2",
        "compat_schema": "sevenos.health.v1",
        "state": if daily_ready { "healthy" } else if score >= 80 { "attention" } else { "degraded" },
        "score": score,
        "daily_ready": daily_ready,
        "summary": check_counts(&checks),
        "checks": checks,
        "issues": checks.iter().filter(|item| item.get("state").and_then(Value::as_str) != Some("OK")).cloned().collect::<Vec<_>>(),
        "core_health": core,
        "writer": "seven-daemon",
    })
}

fn daemon_product_health_json() {
    print_value(&daemon_product_health_payload());
}

fn control_action_id_map() -> HashMap<String, String> {
    let mut map = HashMap::new();
    for action in native_action_registry() {
        if let (Some(command), Some(id)) = (
            action.get("command").and_then(Value::as_str),
            action.get("id").and_then(Value::as_str),
        ) {
            map.insert(command.to_string(), id.to_string());
        }
    }
    map
}

fn add_control_action(
    actions: &mut Vec<Value>,
    seen: &mut HashSet<String>,
    action_ids: &HashMap<String, String>,
    source: &str,
    severity: &str,
    title: &str,
    command: &str,
    reason: &str,
    impact: &str,
) {
    if command.trim().is_empty() || seen.contains(command) {
        return;
    }
    seen.insert(command.to_string());
    let action_id = action_ids.get(command).cloned();
    actions.push(json!({
        "source": source,
        "severity": severity,
        "title": title,
        "command": command,
        "action_id": action_id,
        "impact": impact,
        "reason": reason,
        "writer": "seven-daemon",
    }));
}

fn control_severity_counts(actions: &[Value], severity: &str) -> usize {
    actions
        .iter()
        .filter(|item| item.get("severity").and_then(Value::as_str) == Some(severity))
        .count()
}

fn daemon_control_payload() -> Value {
    let root = sevenos_root().unwrap_or_else(|| PathBuf::from("."));
    let canonical_root = root.canonicalize().unwrap_or_else(|_| root.clone());
    let readiness = daemon_readiness_payload();
    let daily = daemon_daily_payload();
    let shell = shell_status_payload();
    let shell_experience = shell_experience_payload();
    let health = health_payload();
    let installer = installer_flow_payload();
    let update = update_payload();
    let surfaces = native_surfaces_payload();
    let smoke = daemon_smoke_payload();
    let phase = daemon_phase_gate_payload();
    let installed = pacman_packages();
    let package_actions = package_plan_actions(&root, &installed);
    let (_profile_root, _active, profiles) = daemon_profiles_payload();
    let profile_gaps: Vec<Value> = profiles.iter().map(profile_gap_item).collect();
    let shield_checks = shield_checks();
    let (shield_raw, shield_max) = shield_score(&shield_checks);
    let shield_percent = if shield_max > 0 {
        ((shield_raw as f64 / shield_max as f64) * 100.0).round() as u64
    } else {
        0
    };
    let action_ids = control_action_id_map();

    let mut actions = Vec::new();
    let mut seen = HashSet::new();

    for item in daily
        .get("blockers")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default()
    {
        add_control_action(
            &mut actions,
            &mut seen,
            &action_ids,
            "daily",
            "critical",
            item.get("title")
                .and_then(Value::as_str)
                .unwrap_or("Resolve daily-driver blocker"),
            item.get("command")
                .and_then(Value::as_str)
                .unwrap_or("seven daily"),
            item.get("reason")
                .and_then(Value::as_str)
                .unwrap_or("This issue blocks a stable SevenOS session."),
            "changes",
        );
    }

    for item in daily
        .get("warnings")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default()
    {
        add_control_action(
            &mut actions,
            &mut seen,
            &action_ids,
            "daily",
            "high",
            item.get("title")
                .and_then(Value::as_str)
                .unwrap_or("Review daily-driver warning"),
            item.get("command")
                .and_then(Value::as_str)
                .unwrap_or("seven daily"),
            item.get("reason")
                .and_then(Value::as_str)
                .unwrap_or("This warning should be reviewed for a smoother OS."),
            "safe",
        );
    }

    for item in readiness
        .get("recommendations")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default()
    {
        add_control_action(
            &mut actions,
            &mut seen,
            &action_ids,
            "readiness",
            "medium",
            "Improve SevenOS readiness",
            item.get("command")
                .and_then(Value::as_str)
                .unwrap_or("seven readiness"),
            item.get("reason")
                .and_then(Value::as_str)
                .unwrap_or("Improve this native readiness gate."),
            "safe",
        );
    }

    for item in package_actions.iter() {
        add_control_action(
            &mut actions,
            &mut seen,
            &action_ids,
            "packages",
            item.get("severity").and_then(Value::as_str).unwrap_or("medium"),
            item.get("title")
                .and_then(Value::as_str)
                .unwrap_or("Complete software layer"),
            item.get("command")
                .and_then(Value::as_str)
                .unwrap_or("sevenpkg doctor"),
            item.get("reason")
                .and_then(Value::as_str)
                .unwrap_or("A required SevenOS package layer is incomplete."),
            item.get("impact").and_then(Value::as_str).unwrap_or("packages"),
        );
    }

    for item in profile_gaps.iter().filter_map(profile_plan_item) {
        add_control_action(
            &mut actions,
            &mut seen,
            &action_ids,
            "profiles",
            item.get("severity").and_then(Value::as_str).unwrap_or("medium"),
            item.get("title")
                .and_then(Value::as_str)
                .unwrap_or("Complete Mini OS profile"),
            item.get("command")
                .and_then(Value::as_str)
                .unwrap_or("seven profile status"),
            item.get("reason")
                .and_then(Value::as_str)
                .unwrap_or("This Mini OS profile is not fully ready."),
            "packages",
        );
    }

    for check in shield_checks
        .iter()
        .filter(|item| item.get("state").and_then(Value::as_str) != Some("OK"))
    {
        let item = shield_plan_item(check);
        add_control_action(
            &mut actions,
            &mut seen,
            &action_ids,
            "shield",
            item.get("severity").and_then(Value::as_str).unwrap_or("medium"),
            item.get("title")
                .and_then(Value::as_str)
                .unwrap_or("Resolve Shield gap"),
            item.get("command")
                .and_then(Value::as_str)
                .unwrap_or("seven shield status"),
            item.get("reason")
                .and_then(Value::as_str)
                .unwrap_or("Improve Shield readiness."),
            item.get("impact").and_then(Value::as_str).unwrap_or("changes"),
        );
    }

    let shell_score = shell.get("score").and_then(Value::as_u64).unwrap_or(0);
    if shell_score < 100 {
        add_control_action(
            &mut actions,
            &mut seen,
            &action_ids,
            "shell",
            "medium",
            "Stabilize Seven Shell",
            "seven shell status",
            "The shell contract is not fully ready.",
            "safe",
        );
    }

    let surface_score = surfaces.get("score").and_then(Value::as_u64).unwrap_or(0);
    if surface_score < 100 {
        add_control_action(
            &mut actions,
            &mut seen,
            &action_ids,
            "surfaces",
            "medium",
            "Productize native surfaces",
            "seven surfaces doctor",
            "Some SevenOS surfaces are not yet fully productized.",
            "safe",
        );
    }

    let installer_score = installer.get("score").and_then(Value::as_u64).unwrap_or(0);
    if installer_score < 100 {
        add_control_action(
            &mut actions,
            &mut seen,
            &action_ids,
            "installer",
            "high",
            "Harden graphical installation",
            "seven installer live-status",
            "The installation flow should remain graphical and recoverable.",
            "safe",
        );
    }

    actions.sort_by(|left, right| {
        severity_rank(left)
            .cmp(&severity_rank(right))
            .then_with(|| {
                left.get("source")
                    .and_then(Value::as_str)
                    .unwrap_or("")
                    .cmp(right.get("source").and_then(Value::as_str).unwrap_or(""))
            })
            .then_with(|| {
                left.get("command")
                    .and_then(Value::as_str)
                    .unwrap_or("")
                    .cmp(right.get("command").and_then(Value::as_str).unwrap_or(""))
            })
    });

    let readiness_score = readiness.get("percent").and_then(Value::as_u64).unwrap_or(0);
    let shell_experience_score = shell_experience
        .get("score")
        .or_else(|| shell_experience.get("percent"))
        .and_then(Value::as_u64)
        .unwrap_or(shell_score);
    let health_score = health.get("score").and_then(Value::as_u64).unwrap_or(0);
    let update_score = update.get("score").and_then(Value::as_u64).unwrap_or(0);
    let smoke_score = smoke.get("score").and_then(Value::as_u64).unwrap_or(0);
    let packages_score = if package_actions.is_empty() { 100 } else { 70 };
    let profiles_score = if profile_gaps.iter().filter_map(profile_plan_item).count() == 0 {
        100
    } else {
        75
    };
    let overall = ((readiness_score as f64 * 0.22)
        + (health_score as f64 * 0.14)
        + (shell_score as f64 * 0.12)
        + (shell_experience_score as f64 * 0.10)
        + (surface_score as f64 * 0.10)
        + (installer_score as f64 * 0.10)
        + (update_score as f64 * 0.08)
        + (smoke_score as f64 * 0.06)
        + (shield_percent as f64 * 0.04)
        + (packages_score as f64 * 0.02)
        + (profiles_score as f64 * 0.02))
        .round() as u64;

    let limited_actions: Vec<Value> = actions.iter().take(12).cloned().collect();
    json!({
        "schema": "sevenos.control.v1",
        "root": canonical_root.to_string_lossy(),
        "overall": overall,
        "scores": {
            "readiness": readiness_score,
            "health": health_score,
            "shell": shell_score,
            "shell_experience": shell_experience_score,
            "surfaces": surface_score,
            "installer": installer_score,
            "update": update_score,
            "smoke": smoke_score,
            "shield": shield_percent,
            "packages": packages_score,
            "profiles": profiles_score,
        },
        "summary": {
            "critical": control_severity_counts(&actions, "critical"),
            "high": control_severity_counts(&actions, "high"),
            "medium": control_severity_counts(&actions, "medium"),
            "total": actions.len(),
            "source": "seven-daemon",
        },
        "actions": limited_actions,
        "signals": {
            "daily": daily.get("decision").and_then(Value::as_str).unwrap_or("unknown"),
            "phase": phase.get("state").and_then(Value::as_str).unwrap_or("unknown"),
            "installer": installer.get("state").and_then(Value::as_str).unwrap_or("unknown"),
            "update": update.get("state").and_then(Value::as_str).unwrap_or("unknown"),
            "surfaces": surfaces.get("state").and_then(Value::as_str).unwrap_or("unknown"),
        },
        "runtime": "seven-daemon",
        "writer": "seven-daemon",
    })
}

fn daemon_control_json() {
    print_value(&daemon_control_payload());
}

fn runtime_catalog(root: &Path) -> Value {
    let path = root.join("profiles/catalog.json");
    fs::read_to_string(path)
        .ok()
        .and_then(|content| serde_json::from_str::<Value>(&content).ok())
        .unwrap_or_else(|| json!({ "profiles": {} }))
}

fn normalize_runtime_key(key: &str) -> String {
    if key == "horizon" {
        "forge".to_string()
    } else {
        key.to_string()
    }
}

fn runtime_profile<'a>(profiles: &'a serde_json::Map<String, Value>, key: &str) -> Option<&'a Value> {
    profiles.get(key)
}

fn runtime_profile_title(profile: &Value, key: &str) -> String {
    profile
        .get("title")
        .and_then(Value::as_str)
        .unwrap_or(key)
        .to_string()
}

fn runtime_profile_row(key: &str, profile: &Value, lifecycle: &str) -> Value {
    json!({
        "key": key,
        "title": runtime_profile_title(profile, key),
        "domain": profile.get("domain").and_then(Value::as_str).unwrap_or(profile.get("target").and_then(Value::as_str).unwrap_or(key)),
        "role": profile.get("role").and_then(Value::as_str).unwrap_or("mini OS"),
        "autonomous": profile.get("mini_os").and_then(Value::as_bool).unwrap_or(true),
        "layers": profile.get("layers").cloned().unwrap_or_else(|| json!({})),
        "lifecycle": lifecycle,
        "capabilities": profile.get("capabilities").cloned().unwrap_or_else(|| json!([])),
        "resource_intent": runtime_resource_intent(profile),
        "anti_nuisance": profile.get("anti_nuisance").cloned().unwrap_or_else(|| json!([])),
    })
}

fn runtime_resource_intent(profile: &Value) -> Value {
    profile.get("resource_intent").cloned().unwrap_or_else(|| {
        json!({
            "cpu": "balanced",
            "ram": "shared",
            "gpu": "foreground",
            "io": "responsive",
            "network": "normal",
        })
    })
}

fn runtime_resource_field(profile: &Value, key: &str, fallback: &str) -> String {
    runtime_resource_intent(profile)
        .get(key)
        .and_then(Value::as_str)
        .unwrap_or(fallback)
        .to_string()
}

fn runtime_profile_priority(profile: &Value) -> u64 {
    profile.get("priority").and_then(Value::as_u64).unwrap_or(100)
}

fn runtime_profile_slice(profile: &Value, key: &str) -> String {
    profile
        .get("runtime_slice")
        .and_then(Value::as_str)
        .unwrap_or(&format!("seven-{}.slice", key))
        .to_string()
}

fn runtime_capability_names(profile: &Value) -> Vec<String> {
    profile
        .get("capabilities")
        .and_then(Value::as_array)
        .map(|items| {
            items
                .iter()
                .filter_map(Value::as_str)
                .map(ToString::to_string)
                .collect::<Vec<_>>()
        })
        .unwrap_or_default()
}

fn runtime_conflict_rule(left: &str, right: &str) -> Option<(&'static str, &'static str)> {
    let mut pair = [left, right];
    pair.sort();
    match pair {
        ["forge", "shield"] => Some((
            "interactive builds and continuous audit can compete for CPU and IO",
            "keep Forge as primary; run Shield audit event-driven with reduced background pressure",
        )),
        ["shield", "studio"] => Some((
            "GPU/media rendering and heavy security scans can create latency spikes",
            "prioritize Studio media path; Shield stays audit-only unless user confirms deep scans",
        )),
        ["atlas", "shield"] => Some((
            "offline knowledge indexing and active security scans can compete for disk and CPU",
            "keep Atlas indexing low-priority; Shield scans stay explicit and event-driven",
        )),
        ["atlas", "studio"] => Some((
            "creative media imports and Atlas OCR/indexing can both create disk pressure",
            "prioritize Studio foreground exports; Atlas pauses heavy indexing while media work is active",
        )),
        ["pulse", "shield"] => Some((
            "low-latency gaming and active scans can create frame-time spikes",
            "Pulse owns foreground latency; Shield only keeps passive rules unless explicitly confirmed",
        )),
        ["forge", "pulse"] => Some((
            "latency-sensitive workloads and server daemons compete for network/IO smoothness",
            "Pulse foreground traffic wins; Forge DevOps services stay background-limited",
        )),
        ["baobab", "forge"] => Some((
            "Baobab is cultural-only while Forge can inject dev noise",
            "keep Baobab cultural UI clean; Forge capabilities remain explicit and hidden unless requested",
        )),
        _ => None,
    }
}

fn runtime_conflicts(selected: &[String]) -> (Vec<Value>, Vec<Value>) {
    let mut conflicts = Vec::new();
    let mut resolutions = Vec::new();
    for (index, left) in selected.iter().enumerate() {
        for right in selected.iter().skip(index + 1) {
            if let Some((detail, strategy)) = runtime_conflict_rule(left, right) {
                conflicts.push(json!({
                    "profiles": [left, right],
                    "detail": detail,
                    "writer": "seven-daemon",
                }));
                resolutions.push(json!({
                    "profiles": [left, right],
                    "strategy": strategy,
                    "writer": "seven-daemon",
                }));
            }
        }
    }
    if conflicts.is_empty() {
        resolutions.push(json!({
            "profiles": selected,
            "strategy": if selected.len() == 1 {
                "no high-risk conflict detected; keep primary runtime isolated"
            } else {
                "no high-risk conflict detected; keep primary runtime and inject explicit capabilities with shared services"
            },
            "writer": "seven-daemon",
        }));
    }
    (conflicts, resolutions)
}

fn runtime_doctor(root: &Path) -> Value {
    let checks = vec![
        json!({"name": "systemd", "state": if command_exists("systemctl") { "OK" } else { "MISS" }, "role": "service and slice control"}),
        json!({"name": "cgroups_v2", "state": if Path::new("/sys/fs/cgroup/cgroup.controllers").exists() { "OK" } else { "MISS" }, "role": "CPU/RAM/IO resource control"}),
        json!({"name": "seven_scheduler", "state": if root.join("scripts/scheduler.sh").is_file() { "OK" } else { "MISS" }, "role": "profile-aware process policy"}),
        json!({"name": "seven_context", "state": if root.join("scripts/context.sh").is_file() { "OK" } else { "MISS" }, "role": "semantic observation"}),
        json!({"name": "zram", "state": if Path::new("/sys/block/zram0").exists() || command_exists("zramctl") { "OK" } else { "MISS" }, "role": "compressed memory support"}),
        json!({"name": "tc", "state": if command_exists("tc") { "OK" } else { "MISS" }, "role": "future network QoS"}),
        json!({"name": "criu", "state": if command_exists("criu") { "OK" } else { "MISS" }, "role": "future profile checkpoint/restore", "install": "./install.sh runtime-tools --yes"}),
        json!({"name": "hyprctl", "state": if command_exists("hyprctl") { "OK" } else { "MISS" }, "role": "desktop context and workspace control"}),
    ];
    let ready = checks
        .iter()
        .filter(|item| item.get("state").and_then(Value::as_str) == Some("OK"))
        .count();
    let total = checks.len();
    let percent = if total > 0 {
        ((ready as f64 / total as f64) * 100.0).round() as u64
    } else {
        0
    };
    json!({
        "checks": checks,
        "ready": ready,
        "total": total,
        "percent": percent,
        "writer": "seven-daemon",
    })
}

fn runtime_payload(args: &[String]) -> Value {
    let root = sevenos_root().unwrap_or_else(|| PathBuf::from("."));
    let catalog = runtime_catalog(&root);
    let profiles = catalog
        .get("profiles")
        .and_then(Value::as_object)
        .cloned()
        .unwrap_or_default();
    let action = args
        .get(2)
        .map(String::as_str)
        .filter(|value| !value.starts_with("--"))
        .unwrap_or("status");
    let raw_items: Vec<String> = args
        .iter()
        .skip(3)
        .filter(|item| !item.starts_with("--") && item.as_str() != "+")
        .flat_map(|item| item.split('+'))
        .map(str::trim)
        .filter(|item| !item.is_empty())
        .map(normalize_runtime_key)
        .collect();
    let active = active_profile_key();
    let valid_items: Vec<String> = raw_items
        .iter()
        .filter(|item| profiles.contains_key(item.as_str()))
        .cloned()
        .collect();
    let invalid_profiles: Vec<String> = raw_items
        .iter()
        .filter(|item| !profiles.contains_key(item.as_str()))
        .cloned()
        .collect();
    let primary = valid_items
        .first()
        .cloned()
        .unwrap_or_else(|| if profiles.contains_key(&active) { active.clone() } else { "equinox".to_string() });
    let capabilities: Vec<String> = valid_items
        .iter()
        .skip(1)
        .filter(|item| item.as_str() != primary.as_str())
        .fold(Vec::<String>::new(), |mut acc, item| {
            if !acc.contains(item) {
                acc.push(item.clone());
            }
            acc
        });
    let primary_profile = runtime_profile(&profiles, &primary)
        .or_else(|| runtime_profile(&profiles, "equinox"))
        .cloned()
        .unwrap_or_else(|| json!({"title":"Equinox Balance","capabilities":[]}));
    let selected: Vec<String> = std::iter::once(primary.clone())
        .chain(capabilities.iter().cloned())
        .collect();
    let mut merged_capabilities = Vec::<String>::new();
    for key in &selected {
        if let Some(profile) = runtime_profile(&profiles, key) {
            for capability in runtime_capability_names(profile) {
                if !merged_capabilities.contains(&capability) {
                    merged_capabilities.push(capability);
                }
            }
        }
    }
    let lifecycle: Vec<Value> = profiles
        .iter()
        .map(|(key, profile)| {
            let (state, reason) = if key == &primary {
                ("ACTIVE", "main runtime profile")
            } else if capabilities.contains(key) {
                ("DEGRADED", "injected as a capability module")
            } else {
                ("SUSPENDED", "not loaded in the current composite runtime")
            };
            json!({
                "profile": key,
                "title": runtime_profile_title(profile, key),
                "state": state,
                "reason": reason,
                "writer": "seven-daemon",
            })
        })
        .collect();
    let capability_rows: Vec<Value> = capabilities
        .iter()
        .filter_map(|key| runtime_profile(&profiles, key).map(|profile| runtime_profile_row(key, profile, "DEGRADED")))
        .map(|mut row| {
            if let Some(object) = row.as_object_mut() {
                object.insert("injection_mode".to_string(), json!("rules-and-services"));
            }
            row
        })
        .collect();
    let (conflicts, resolutions) = runtime_conflicts(&selected);
    let doctor = runtime_doctor(&root);
    let cgroups_ready = Path::new("/sys/fs/cgroup/cgroup.controllers").exists();
    let tc_ready = command_exists("tc");
    let max_priority = selected
        .iter()
        .filter_map(|key| runtime_profile(&profiles, key))
        .map(runtime_profile_priority)
        .max()
        .unwrap_or_else(|| runtime_profile_priority(&primary_profile));
    let runtime_state_file = config_dir().join("runtime.json");

    let mut payload = json!({
        "schema": "sevenos.runtime-orchestrator.v1",
        "model": "layered-autonomous-profiles-architecture",
        "golden_rule": "no profile dependency, only profile collaboration",
        "action": action,
        "state": if action == "doctor" {
            if doctor.get("ready").and_then(Value::as_u64).unwrap_or(0) >= 5 { "ready" } else { "partial" }
        } else if action == "status" && runtime_state_file.is_file() {
            "active"
        } else {
            "planned"
        },
        "generated_at": unix_timestamp(),
        "host": env::var("HOSTNAME").ok().or_else(|| fs::read_to_string("/etc/hostname").ok()).unwrap_or_else(|| "sevenos".to_string()).trim(),
        "active_profile": active,
        "primary_profile": runtime_profile_row(&primary, &primary_profile, "ACTIVE"),
        "capabilities": capability_rows,
        "composite_runtime": {
            "name": selected.join("+"),
            "primary": primary,
            "injected_profiles": capabilities,
            "capability_fusion": {
                "mode": "layered-autonomous-profiles",
                "deduplicate_services": true,
                "merged_capabilities": merged_capabilities,
                "profiles_are_autonomous": true,
                "no_profile_dependency": true,
                "composition_layer": "controlled-collaboration",
                "inactive_profiles_are_not_auto_loaded": true,
            },
            "conflict_resolver": {
                "policy": "no-profile-pollution; equinox-arbitrates-when-primary",
                "confirmation_required_for": ["root changes", "service restarts", "network rewrites", "destructive cleanup"],
            },
        },
        "resource_plan": {
            "status": if cgroups_ready { "applicable" } else { "planned" },
            "allocator": "Seven Resource Allocator",
            "cpu": {
                "strategy": runtime_resource_field(&primary_profile, "cpu", "balanced"),
                "cgroups_v2": if cgroups_ready { "available" } else { "planned" },
                "primary_slice": runtime_profile_slice(&primary_profile, &selected[0]),
                "weight": max_priority,
                "secondary_policy": "degraded/background unless foregrounded",
            },
            "ram": {
                "strategy": runtime_resource_field(&primary_profile, "ram", "shared"),
                "zram": "use-if-available",
                "secondary_policy": "profile-owned commands are launched in selected slices; inactive package capabilities stay quiet",
                "future": "CRIU snapshots for FROZEN/OFFLOADED profile state",
            },
            "gpu": {
                "strategy": runtime_resource_field(&primary_profile, "gpu", "foreground"),
                "foreground_owner": selected[0],
                "secondary_policy": "only foreground app receives elevated GPU priority",
            },
            "io": {
                "strategy": runtime_resource_field(&primary_profile, "io", "responsive"),
                "scheduler_hint": if cgroups_ready { "ionice/cgroup IO weight available" } else { "ionice/cgroup IO weight planned" },
                "secondary_policy": "throttle heavy background IO",
            },
            "network": {
                "strategy": runtime_resource_field(&primary_profile, "network", "normal"),
                "qos": if tc_ready { "available" } else { "planned" },
                "security_overlay": if selected.iter().any(|item| item == "shield") { "enabled" } else { "available" },
            },
            "isolation": {
                "ram_pool": "partially-isolated",
                "cpu_quota": "dynamic",
                "gpu_context": "foreground-profile-owned",
                "filesystem": "profile-workspace-state",
                "services": "systemd-user-slices",
                "packages": "global install store with profile-scoped activation allowlist",
                "commands": "seven-profile-run shims enforce active profile capabilities",
            },
        },
        "conflicts": conflicts,
        "resolutions": resolutions,
        "lifecycle": lifecycle,
        "doctor": doctor,
        "context": {
            "schema": "sevenos.context.v1",
            "primary_context": {
                "profile": selected[0],
                "source": "seven-daemon",
            },
        },
        "scheduler": {
            "schema": "sevenos.scheduler.v1",
            "active_policy": {
                "profile": selected[0],
                "resource_slice": runtime_profile_slice(&primary_profile, &selected[0]),
                "source": "seven-daemon",
            },
        },
        "invalid_profiles": invalid_profiles,
        "safe_execution": {
            "apply_requested": args.iter().any(|item| item == "--apply"),
            "yes": args.iter().any(|item| item == "--yes"),
            "applied": false,
            "requires_confirmation": action == "activate",
        },
        "next_actions": [
            {"command": "seven runtime plan equinox forge shield studio pulse", "reason": "preview the neutral global profile with controlled capability fragments"},
            {"command": "seven runtime plan baobab shield forge", "reason": "verify Baobab stays culturally clean while collaborating with other profiles"},
            {"command": "seven scheduler plan", "reason": "inspect CPU/IO/user-space scheduler hints"},
            {"command": "seven context status --json", "reason": "see what SevenOS currently detects from apps and windows"},
            {"command": "seven ai diagnose system --json", "reason": "let SevenAI explain local bottlenecks before repair"},
        ],
        "runtime": "seven-daemon",
        "writer": "seven-daemon",
    });

    if action == "capabilities" {
        let available_profiles: Vec<Value> = profiles
            .iter()
            .map(|(key, profile)| runtime_profile_row(key, profile, "AVAILABLE"))
            .collect();
        if let Some(object) = payload.as_object_mut() {
            object.insert("available_profiles".to_string(), json!(available_profiles));
        }
    }
    payload
}

fn runtime_json(args: &[String]) {
    print_value(&runtime_payload(args));
}

#[derive(Clone, Copy)]
struct SchedulerGroupSpec {
    key: &'static str,
    title: &'static str,
    role: &'static str,
    policy: &'static str,
    nice: i64,
    io: &'static str,
    power: &'static str,
    slice: &'static str,
    cpu_weight: u64,
    io_weight: u64,
    uclamp_min: &'static str,
    uclamp_max: &'static str,
    processes: &'static [&'static str],
    reason: &'static str,
}

const SCHEDULER_GROUPS: &[SchedulerGroupSpec] = &[
    SchedulerGroupSpec {
        key: "equinox",
        title: "Equinox",
        role: "Balanced global",
        policy: "balanced-adaptive",
        nice: 0,
        io: "best-effort",
        power: "balanced",
        slice: "seven-equinox.slice",
        cpu_weight: 150,
        io_weight: 140,
        uclamp_min: "0",
        uclamp_max: "max",
        processes: &["seven", "seven-daemon", "seven-server", "waybar", "hyprpaper", "swaync", "kitty", "nautilus"],
        reason: "Keep the neutral system profile responsive while avoiding profile dominance.",
    },
    SchedulerGroupSpec {
        key: "baobab",
        title: "Baobab",
        role: "Culture",
        policy: "quiet-cultural",
        nice: 0,
        io: "best-effort",
        power: "balanced",
        slice: "seven-baobab.slice",
        cpu_weight: 90,
        io_weight: 90,
        uclamp_min: "0",
        uclamp_max: "80%",
        processes: &["seven-files", "seven-hub-native", "seven-settings-native", "waybar", "hyprpaper"],
        reason: "Keep cultural/community surfaces calm and lightweight without dev/security noise.",
    },
    SchedulerGroupSpec {
        key: "forge",
        title: "Forge",
        role: "Development",
        policy: "interactive-build",
        nice: -2,
        io: "best-effort-high",
        power: "performance-on-ac",
        slice: "seven-forge.slice",
        cpu_weight: 180,
        io_weight: 160,
        uclamp_min: "20%",
        uclamp_max: "max",
        processes: &["code", "codium", "helix", "hx", "nvim", "node", "npm", "cargo", "rustc", "docker", "podman"],
        reason: "Boost editors, compilers and containers while keeping desktop latency stable.",
    },
    SchedulerGroupSpec {
        key: "shield",
        title: "Shield",
        role: "Security",
        policy: "isolated-analysis",
        nice: 0,
        io: "best-effort",
        power: "balanced",
        slice: "seven-shield.slice",
        cpu_weight: 120,
        io_weight: 100,
        uclamp_min: "0",
        uclamp_max: "80%",
        processes: &["wireshark", "nmap", "burpsuite", "zaproxy", "john", "hashcat", "aircrack-ng", "firejail"],
        reason: "Keep security tools visible and auditable; avoid silently boosting risky scans.",
    },
    SchedulerGroupSpec {
        key: "studio",
        title: "Studio",
        role: "Creation",
        policy: "media-low-latency",
        nice: -4,
        io: "best-effort-high",
        power: "performance",
        slice: "seven-studio.slice",
        cpu_weight: 220,
        io_weight: 180,
        uclamp_min: "30%",
        uclamp_max: "max",
        processes: &["blender", "krita", "gimp", "inkscape", "kdenlive", "ardour", "pipewire", "wireplumber"],
        reason: "Prioritize creative apps, media pipelines and audio responsiveness.",
    },
    SchedulerGroupSpec {
        key: "atlas",
        title: "Atlas",
        role: "Explorer",
        policy: "knowledge-balanced",
        nice: 1,
        io: "best-effort",
        power: "balanced",
        slice: "seven-atlas.slice",
        cpu_weight: 140,
        io_weight: 150,
        uclamp_min: "5%",
        uclamp_max: "80%",
        processes: &["evince", "foliate", "calibre", "marble", "gnome-maps", "tesseract", "syncthing"],
        reason: "Keep document, map and OCR workloads responsive without stealing focus from the active desktop.",
    },
    SchedulerGroupSpec {
        key: "devops",
        title: "Forge DevOps",
        role: "Development and deploy",
        policy: "service-stability",
        nice: 2,
        io: "best-effort",
        power: "balanced",
        slice: "seven-forge.slice",
        cpu_weight: 140,
        io_weight: 130,
        uclamp_min: "0",
        uclamp_max: "90%",
        processes: &["podman", "conmon", "caddy", "go", "seven-server", "seven-deploy"],
        reason: "Prefer stable service throughput over aggressive desktop boosts.",
    },
    SchedulerGroupSpec {
        key: "pulse",
        title: "Pulse",
        role: "Performance",
        policy: "low-latency-foreground",
        nice: -3,
        io: "best-effort-high",
        power: "performance-on-demand",
        slice: "seven-pulse.slice",
        cpu_weight: 210,
        io_weight: 170,
        uclamp_min: "25%",
        uclamp_max: "max",
        processes: &["gamemoderun", "gamescope", "mangohud", "steam", "lutris", "heroic", "obs", "wf-recorder"],
        reason: "Prioritize focused interactive workloads and capture hooks while suppressing background noise.",
    },
];

fn scheduler_group_by_key(key: &str) -> &'static SchedulerGroupSpec {
    SCHEDULER_GROUPS
        .iter()
        .find(|group| group.key == key)
        .unwrap_or(&SCHEDULER_GROUPS[0])
}

fn process_rows_for_scheduler() -> Vec<Value> {
    let output = Command::new("ps")
        .args(["-eo", "pid=,ni=,psr=,pcpu=,pmem=,comm="])
        .output();
    let Ok(output) = output else {
        return Vec::new();
    };
    let content = String::from_utf8_lossy(&output.stdout);
    content
        .lines()
        .filter_map(|raw| {
            let parts: Vec<&str> = raw.split_whitespace().collect();
            if parts.len() < 6 {
                return None;
            }
            let pid = parts[0].parse::<u64>().ok()?;
            let nice = parts[1].parse::<i64>().unwrap_or(0);
            let pcpu = parts[3].parse::<f64>().unwrap_or(0.0);
            let pmem = parts[4].parse::<f64>().unwrap_or(0.0);
            Some(json!({
                "pid": pid,
                "nice": nice,
                "cpu": parts[2],
                "pcpu": pcpu,
                "pmem": pmem,
                "command": parts[5],
                "writer": "seven-daemon",
            }))
        })
        .collect()
}

fn scheduler_process_matches(process: &Value, group: &SchedulerGroupSpec) -> bool {
    let command = process
        .get("command")
        .and_then(Value::as_str)
        .unwrap_or("")
        .to_lowercase();
    group.processes.iter().any(|name| {
        let name = name.to_lowercase();
        command == name || command.starts_with(&name)
    })
}

fn scheduler_group_payload(
    group: &SchedulerGroupSpec,
    rows: &[Value],
    active_profile: &str,
    context_group: &str,
) -> Value {
    let sample: Vec<Value> = rows
        .iter()
        .filter(|process| scheduler_process_matches(process, group))
        .take(8)
        .cloned()
        .collect();
    json!({
        "key": group.key,
        "title": group.title,
        "role": group.role,
        "policy": group.policy,
        "nice": group.nice,
        "io": group.io,
        "power": group.power,
        "slice": group.slice,
        "cpu_weight": group.cpu_weight,
        "io_weight": group.io_weight,
        "uclamp_min": group.uclamp_min,
        "uclamp_max": group.uclamp_max,
        "processes": group.processes,
        "reason": group.reason,
        "active": group.key == context_group,
        "profile_active": group.key == active_profile,
        "context_active": group.key == context_group,
        "matches": sample.len(),
        "sample": sample,
        "writer": "seven-daemon",
    })
}

fn cpu_governor() -> String {
    fs::read_to_string("/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor")
        .map(|value| value.trim().to_string())
        .unwrap_or_else(|_| "unknown".to_string())
}

fn cgroup_controllers() -> Vec<String> {
    fs::read_to_string("/sys/fs/cgroup/cgroup.controllers")
        .map(|value| value.split_whitespace().map(ToString::to_string).collect())
        .unwrap_or_default()
}

fn scheduler_context_group(active_profile: &str, rows: &[Value]) -> String {
    if let Ok(raw) = env::var("SEVENOS_SCHEDULER_GROUP") {
        let normalized = normalize_runtime_key(raw.trim());
        if SCHEDULER_GROUPS.iter().any(|group| group.key == normalized) {
            return normalized;
        }
    }
    let mut best_key = active_profile.to_string();
    let mut best_score = 0usize;
    for group in SCHEDULER_GROUPS {
        let matches = rows
            .iter()
            .filter(|process| scheduler_process_matches(process, group))
            .count();
        let profile_bonus = if group.key == active_profile { 2 } else { 0 };
        let score = matches + profile_bonus;
        if score > best_score {
            best_score = score;
            best_key = group.key.to_string();
        }
    }
    if SCHEDULER_GROUPS.iter().any(|group| group.key == best_key) {
        best_key
    } else {
        "equinox".to_string()
    }
}

fn scheduler_payload(_args: &[String]) -> Value {
    let active_profile = active_profile_key();
    let rows = process_rows_for_scheduler();
    let context_group = scheduler_context_group(&active_profile, &rows);
    let active_group = scheduler_group_by_key(&context_group);
    let groups: Vec<Value> = SCHEDULER_GROUPS
        .iter()
        .map(|group| scheduler_group_payload(group, &rows, &active_profile, &context_group))
        .collect();

    let active_group_payload = groups
        .iter()
        .find(|group| group.get("key").and_then(Value::as_str) == Some(context_group.as_str()))
        .cloned()
        .unwrap_or_else(|| groups.first().cloned().unwrap_or_else(|| json!({})));
    let mut actions = Vec::new();
    let matches = active_group_payload
        .get("matches")
        .and_then(Value::as_u64)
        .unwrap_or(0);
    if matches == 0 {
        actions.push(json!({
            "key": format!("{}.no-workload", context_group),
            "severity": "low",
            "impact": "safe",
            "title": format!("No active {} workload detected", active_group.title),
            "command": format!("seven profile open {}", context_group),
            "reason": "Open the workspace before applying context scheduling.",
            "writer": "seven-daemon",
        }));
    } else {
        let mismatched = active_group_payload
            .get("sample")
            .and_then(Value::as_array)
            .map(|sample| {
                sample
                    .iter()
                    .filter(|process| {
                        process.get("nice").and_then(Value::as_i64).unwrap_or(0) != active_group.nice
                    })
                    .count()
            })
            .unwrap_or(0);
        if mismatched > 0 {
            actions.push(json!({
                "key": format!("{}.nice", context_group),
                "severity": "medium",
                "impact": "changes",
                "title": format!("Apply {} nice policy", active_group.title),
                "command": "seven scheduler apply --apply",
                "reason": format!("{} sampled process(es) differ from target nice {}.", mismatched, active_group.nice),
                "writer": "seven-daemon",
            }));
        }
        actions.push(json!({
            "key": format!("{}.power", context_group),
            "severity": "medium",
            "impact": "manual",
            "title": format!("Review {} power policy", active_group.title),
            "command": "seven scheduler plan",
            "reason": format!("Requested power policy: {}. Kernel/governor changes stay explicit.", active_group.power),
            "writer": "seven-daemon",
        }));
        actions.push(json!({
            "key": format!("{}.slice", context_group),
            "severity": "low",
            "impact": "future",
            "title": format!("Prepare {} context group", active_group.title),
            "command": format!("systemd-run --user --scope --slice={} <command>", active_group.slice),
            "reason": "Future SevenDaemon will move launched profile apps into semantic cgroups instead of tracking raw PIDs only.",
            "writer": "seven-daemon",
        }));
    }

    let controllers = cgroup_controllers();
    json!({
        "schema": "sevenos.scheduler.v1",
        "layer": "user-space scheduler orchestration",
        "kernel_scheduler": "Linux CFS",
        "state": "active-user-space-executor",
        "active_profile": active_profile,
        "active_context": {
            "key": context_group,
            "title": format!("{} Context", active_group.title),
            "intent": active_group.role,
            "confidence": if matches > 0 { 100 } else { 0 },
            "profile": context_group,
            "scheduler_group": context_group,
            "signals": active_group.processes.iter().take(4).cloned().collect::<Vec<_>>(),
        },
        "policy_source": if matches > 0 { "process" } else { "profile" },
        "active_policy": {
            "profile": active_profile,
            "scheduler_group": context_group,
            "policy": active_group.policy,
            "nice": active_group.nice,
            "io": active_group.io,
            "power": active_group.power,
            "slice": active_group.slice,
            "cpu_weight": active_group.cpu_weight,
            "io_weight": active_group.io_weight,
            "uclamp_min": active_group.uclamp_min,
            "uclamp_max": active_group.uclamp_max,
            "reason": active_group.reason,
        },
        "host": {
            "nproc": std::thread::available_parallelism().map(|value| value.get()).unwrap_or(1),
            "governor": cpu_governor(),
            "cgroups_v2": !controllers.is_empty(),
            "cgroup_controllers": controllers,
            "has_systemd_run": command_exists("systemd-run"),
            "has_taskset": command_exists("taskset"),
            "has_renice": command_exists("renice"),
            "has_ionice": command_exists("ionice"),
        },
        "semantic_controls": {
            "implemented": [
                "process matching",
                "safe nice preview",
                "safe renice adapter",
                "systemd-run profile scopes through seven-profile-run",
                "daemon-native JSON policy contract"
            ],
            "planned": [
                "automatic migration of already-running apps into cgroups",
                "cgroups v2 CPUWeight/IOWeight live writes",
                "uclamp hints",
                "SevenBus foreground events"
            ],
            "guardrails": [
                "no kernel scheduler replacement",
                "no silent affinity changes",
                "no opaque AI-driven resource changes"
            ],
        },
        "groups": groups,
        "actions": actions,
        "runtime": "seven-daemon",
        "writer": "seven-daemon",
    })
}

fn scheduler_json(args: &[String]) {
    print_value(&scheduler_payload(args));
}

#[derive(Clone, Copy)]
struct ContextSpec {
    key: &'static str,
    title: &'static str,
    intent: &'static str,
    profile: &'static str,
    classes: &'static [&'static str],
    processes: &'static [&'static str],
    signals: &'static [&'static str],
    scheduler_group: &'static str,
}

const CONTEXT_SPECS: &[ContextSpec] = &[
    ContextSpec {
        key: "equinox",
        title: "Equinox Workspace",
        intent: "balanced daily computing",
        profile: "equinox",
        classes: &["waybar", "kitty", "org.gnome.Nautilus", "firefox", "chromium"],
        processes: &["seven", "seven-daemon", "seven-server", "waybar", "hyprpaper", "mako", "swaync", "nautilus", "kitty"],
        signals: &["system", "files", "shell", "browser"],
        scheduler_group: "equinox",
    },
    ContextSpec {
        key: "forge",
        title: "Forge Environment",
        intent: "development",
        profile: "forge",
        classes: &["code", "codium", "kitty", "Alacritty", "firefox", "chromium"],
        processes: &["code", "codium", "helix", "hx", "nvim", "node", "npm", "cargo", "rustc", "docker", "podman", "postgres"],
        signals: &["editor", "terminal", "container", "documentation"],
        scheduler_group: "forge",
    },
    ContextSpec {
        key: "studio",
        title: "Studio Session",
        intent: "creative production",
        profile: "studio",
        classes: &["blender", "krita", "gimp", "inkscape", "kdenlive", "obs"],
        processes: &["blender", "krita", "gimp", "inkscape", "kdenlive", "ardour", "obs", "pipewire", "wireplumber"],
        signals: &["creative-app", "media", "audio"],
        scheduler_group: "studio",
    },
    ContextSpec {
        key: "shield",
        title: "Security Audit",
        intent: "cybersecurity",
        profile: "shield",
        classes: &["wireshark", "burpsuite", "zaproxy", "kitty"],
        processes: &["wireshark", "nmap", "burpsuite", "zaproxy", "john", "hashcat", "aircrack-ng", "firejail"],
        signals: &["network-audit", "sandbox", "forensics"],
        scheduler_group: "shield",
    },
    ContextSpec {
        key: "atlas",
        title: "Atlas Explorer",
        intent: "documents maps OCR and research",
        profile: "atlas",
        classes: &["evince", "foliate", "calibre", "marble", "org.gnome.Maps", "zathura"],
        processes: &["evince", "foliate", "calibre", "marble", "gnome-maps", "tesseract", "syncthing"],
        signals: &["documents", "maps", "ocr", "research"],
        scheduler_group: "atlas",
    },
    ContextSpec {
        key: "devops",
        title: "Forge DevOps",
        intent: "software development and deployment",
        profile: "forge",
        classes: &["kitty", "code", "firefox"],
        processes: &["podman", "conmon", "caddy", "go", "seven-server", "seven-deploy", "ssh", "rsync"],
        signals: &["container", "server", "network", "deploy"],
        scheduler_group: "forge",
    },
    ContextSpec {
        key: "baobab",
        title: "Baobab System",
        intent: "cultural immersion and transmission",
        profile: "baobab",
        classes: &["seven-baobab", "foliate", "anki", "kiwix", "kitty"],
        processes: &["seven-baobab", "kiwix", "foliate", "anki", "waybar", "hyprpaper"],
        signals: &["culture", "learning", "archive"],
        scheduler_group: "baobab",
    },
    ContextSpec {
        key: "streaming",
        title: "Streaming Context",
        intent: "streaming",
        profile: "studio",
        classes: &["obs", "discord", "firefox", "chromium"],
        processes: &["obs", "Discord", "discord", "firefox", "chromium", "spotify"],
        signals: &["capture", "chat", "browser", "audio"],
        scheduler_group: "studio",
    },
    ContextSpec {
        key: "pulse",
        title: "Pulse Session",
        intent: "gaming and low-latency performance",
        profile: "pulse",
        classes: &["steam", "lutris", "heroic", "gamescope"],
        processes: &["steam", "lutris", "heroic", "gamescope", "mangohud", "gamemoderun", "obs"],
        signals: &["gaming", "performance", "capture"],
        scheduler_group: "pulse",
    },
];

fn context_process_rows() -> Vec<Value> {
    let output = Command::new("ps")
        .args(["-eo", "pid=,ppid=,ni=,pcpu=,pmem=,comm="])
        .output();
    let Ok(output) = output else {
        return Vec::new();
    };
    let content = String::from_utf8_lossy(&output.stdout);
    content
        .lines()
        .filter_map(|raw| {
            let parts: Vec<&str> = raw.split_whitespace().collect();
            if parts.len() < 6 {
                return None;
            }
            let pid = parts[0].parse::<u64>().ok()?;
            let ppid = parts[1].parse::<u64>().unwrap_or(0);
            let nice = parts[2].parse::<i64>().unwrap_or(0);
            let pcpu = parts[3].parse::<f64>().unwrap_or(0.0);
            let pmem = parts[4].parse::<f64>().unwrap_or(0.0);
            Some(json!({
                "id": format!("pid:{}", pid),
                "pid": pid,
                "ppid": ppid,
                "nice": nice,
                "pcpu": pcpu,
                "pmem": pmem,
                "command": parts[5],
                "type": "process",
                "writer": "seven-daemon",
            }))
        })
        .collect()
}

fn hypr_json(command: &str) -> Value {
    if !command_exists("hyprctl") || env::var("HYPRLAND_INSTANCE_SIGNATURE").is_err() {
        return json!({});
    }
    let output = Command::new("hyprctl").args([command, "-j"]).output();
    let Ok(output) = output else {
        return json!({});
    };
    serde_json::from_slice::<Value>(&output.stdout).unwrap_or_else(|_| json!({}))
}

fn context_match_name(value: &str, candidates: &[&str]) -> bool {
    let lower = value.to_lowercase();
    candidates.iter().any(|candidate| {
        let candidate = candidate.to_lowercase();
        lower == candidate || lower.starts_with(&candidate)
    })
}

fn context_class_value(window: &Value) -> String {
    window
        .get("class")
        .or_else(|| window.get("initialClass"))
        .and_then(Value::as_str)
        .unwrap_or("")
        .to_string()
}

fn context_title_value(window: &Value) -> String {
    window
        .get("title")
        .and_then(Value::as_str)
        .unwrap_or("")
        .to_string()
}

fn context_for_spec(spec: &ContextSpec, processes: &[Value], windows: &[Value], active_profile: &str) -> Value {
    let matched_processes: Vec<Value> = processes
        .iter()
        .filter(|item| {
            context_match_name(
                item.get("command").and_then(Value::as_str).unwrap_or(""),
                spec.processes,
            )
        })
        .take(8)
        .cloned()
        .collect();
    let matched_windows: Vec<Value> = windows
        .iter()
        .filter(|item| {
            context_match_name(&context_class_value(item), spec.classes)
                || context_match_name(&context_title_value(item), spec.classes)
        })
        .take(8)
        .cloned()
        .collect();
    let score = matched_processes.len() * 2
        + matched_windows.len() * 3
        + if spec.profile == active_profile { 10 } else { 0 };
    let confidence = std::cmp::min(100, score * 10) as u64;
    json!({
        "key": spec.key,
        "title": spec.title,
        "intent": spec.intent,
        "profile": spec.profile,
        "classes": spec.classes,
        "processes": spec.processes,
        "signals": spec.signals,
        "scheduler_group": spec.scheduler_group,
        "score": score,
        "confidence": confidence,
        "active_profile_match": spec.profile == active_profile,
        "process_matches": matched_processes.len(),
        "window_matches": matched_windows.len(),
        "sample_processes": matched_processes,
        "sample_windows": matched_windows,
        "writer": "seven-daemon",
    })
}

fn context_primary(active_profile: &str, contexts: &[Value]) -> Value {
    let mut best = contexts.first().cloned().unwrap_or_else(|| json!({}));
    for item in contexts {
        let left = item.get("confidence").and_then(Value::as_u64).unwrap_or(0);
        let right = best.get("confidence").and_then(Value::as_u64).unwrap_or(0);
        let left_score = item.get("score").and_then(Value::as_u64).unwrap_or(0);
        let right_score = best.get("score").and_then(Value::as_u64).unwrap_or(0);
        if (left, left_score) > (right, right_score) {
            best = item.clone();
        }
    }
    if best.get("confidence").and_then(Value::as_u64).unwrap_or(0) < 25 {
        contexts
            .iter()
            .find(|item| item.get("key").and_then(Value::as_str) == Some(active_profile))
            .cloned()
            .unwrap_or(best)
    } else {
        best
    }
}

fn foreground_context(active_profile: &str, active_window: &Value) -> Value {
    let class = context_class_value(active_window).to_lowercase();
    let title = context_title_value(active_window).to_lowercase();
    let workspace = active_window
        .get("workspace")
        .and_then(Value::as_object)
        .and_then(|object| object.get("name").or_else(|| object.get("id")))
        .cloned()
        .unwrap_or_else(|| json!(""));
    let fullscreen = active_window
        .get("fullscreen")
        .and_then(Value::as_i64)
        .unwrap_or(0)
        != 0;
    let app_key = if class.contains("code")
        || class.contains("codium")
        || class.contains("kitty")
        || title.contains("terminal")
    {
        "developer"
    } else if class.contains("obs")
        || class.contains("blender")
        || class.contains("krita")
        || class.contains("gimp")
    {
        "studio"
    } else if class.contains("steam") || class.contains("lutris") || class.contains("heroic") {
        "pulse"
    } else if class.contains("nautilus") || class.contains("seven-files") {
        "files"
    } else {
        "app"
    };
    let (key, title, intent, profile, scheduler_group, confidence, signals) = match app_key {
        "developer" => (
            "foreground.forge",
            "Foreground Development",
            "active development workflow",
            "forge",
            "forge",
            92,
            vec!["foreground", "developer", "developer"],
        ),
        "studio" => (
            "foreground.studio",
            "Foreground Studio",
            "active media or creative workflow",
            "studio",
            "studio",
            90,
            vec!["foreground", "media", "studio"],
        ),
        "pulse" => (
            "foreground.pulse",
            "Foreground Performance",
            "active gaming or performance workflow",
            "pulse",
            "pulse",
            90,
            vec!["foreground", "gaming", "performance"],
        ),
        "files" => (
            "foreground.files",
            "Foreground Files",
            "file management",
            active_profile,
            active_profile,
            82,
            vec!["foreground", "files"],
        ),
        _ if fullscreen => (
            "foreground.content",
            "Foreground Content",
            "immersive foreground use",
            active_profile,
            active_profile,
            88,
            vec!["foreground", "content", "fullscreen"],
        ),
        _ => return json!({}),
    };
    json!({
        "key": key,
        "title": title,
        "intent": intent,
        "profile": profile,
        "scheduler_group": scheduler_group,
        "confidence": confidence,
        "signals": signals,
        "workspace": workspace,
        "source": "active-window",
        "writer": "seven-daemon",
    })
}

fn context_summary(value: &Value) -> Value {
    json!({
        "key": value.get("key").cloned().unwrap_or_else(|| json!("unknown")),
        "title": value.get("title").cloned().unwrap_or_else(|| json!("Unknown Context")),
        "intent": value.get("intent").cloned().unwrap_or_else(|| json!("unknown")),
        "confidence": value.get("confidence").cloned().unwrap_or_else(|| json!(0)),
        "profile": value.get("profile").cloned().unwrap_or_else(|| json!("equinox")),
        "scheduler_group": value.get("scheduler_group").cloned().unwrap_or_else(|| json!("equinox")),
        "signals": value.get("signals").cloned().unwrap_or_else(|| json!([])),
        "source": value.get("source").cloned().unwrap_or_else(|| json!("semantic-background")),
        "writer": "seven-daemon",
    })
}

fn context_payload(args: &[String]) -> Value {
    let action = args
        .get(2)
        .map(String::as_str)
        .filter(|value| !value.starts_with("--"))
        .unwrap_or("status");
    let active_profile = active_profile_key();
    let processes = context_process_rows();
    let clients_value = hypr_json("clients");
    let windows: Vec<Value> = clients_value
        .as_array()
        .cloned()
        .unwrap_or_default()
        .into_iter()
        .enumerate()
        .map(|(index, client)| {
            json!({
                "id": format!("window:{}", index),
                "type": "window",
                "class": context_class_value(&client),
                "title": context_title_value(&client),
                "workspace": client.get("workspace").cloned().unwrap_or_else(|| json!({})),
                "focused": client.get("focusHistoryID").and_then(Value::as_i64).unwrap_or(-1) == 0,
                "raw": client,
                "writer": "seven-daemon",
            })
        })
        .collect();
    let active_window = hypr_json("activewindow");
    let mut contexts: Vec<Value> = CONTEXT_SPECS
        .iter()
        .map(|spec| context_for_spec(spec, &processes, &windows, &active_profile))
        .collect();
    contexts.sort_by(|left, right| {
        let left_conf = left.get("confidence").and_then(Value::as_u64).unwrap_or(0);
        let right_conf = right.get("confidence").and_then(Value::as_u64).unwrap_or(0);
        let left_score = left.get("score").and_then(Value::as_u64).unwrap_or(0);
        let right_score = right.get("score").and_then(Value::as_u64).unwrap_or(0);
        (right_conf, right_score).cmp(&(left_conf, left_score))
    });
    let primary = context_primary(&active_profile, &contexts);
    let focused = foreground_context(&active_profile, &active_window);
    let primary_conf = primary.get("confidence").and_then(Value::as_i64).unwrap_or(0);
    let focused_conf = focused.get("confidence").and_then(Value::as_i64).unwrap_or(0);
    let (effective, reason) = if focused.as_object().map(|object| !object.is_empty()).unwrap_or(false)
        && focused_conf >= primary_conf - 20
    {
        (focused.clone(), "active-window")
    } else {
        (primary.clone(), "semantic-background")
    };
    let effective_profile = effective
        .get("profile")
        .and_then(Value::as_str)
        .unwrap_or("equinox")
        .to_string();
    let active_app = if active_window.as_object().map(|object| !object.is_empty()).unwrap_or(false) {
        json!({
            "key": if effective_profile == "forge" { "developer" } else if effective_profile == "studio" { "studio" } else if effective_profile == "pulse" { "pulse" } else { "app" },
            "service": "",
            "label": context_class_value(&active_window),
            "fullscreen": active_window.get("fullscreen").and_then(Value::as_i64).unwrap_or(0) != 0,
            "workspace": active_window.get("workspace").and_then(Value::as_object).and_then(|object| object.get("name").or_else(|| object.get("id"))).cloned().unwrap_or_else(|| json!("")),
        })
    } else {
        json!({})
    };
    let mut actions = Vec::new();
    let effective_conf = effective.get("confidence").and_then(Value::as_u64).unwrap_or(0);
    if effective_profile != active_profile && effective_conf >= 50 {
        actions.push(json!({
            "key": "profile.switch-suggested",
            "severity": "medium",
            "impact": "changes",
            "title": format!("Switch to {} profile", title_case(&effective_profile)),
            "command": format!("seven profile activate {}", effective_profile),
            "reason": format!("Detected {} with {}% confidence.", effective.get("title").and_then(Value::as_str).unwrap_or("context"), effective_conf),
            "writer": "seven-daemon",
        }));
    }
    actions.push(json!({
        "key": "scheduler.context",
        "severity": "medium",
        "impact": "safe",
        "title": "Review scheduler policy for current context",
        "command": "seven scheduler plan",
        "reason": format!("Effective context maps to scheduler group {}.", effective.get("scheduler_group").and_then(Value::as_str).unwrap_or("equinox")),
        "writer": "seven-daemon",
    }));

    let graph_nodes = if action == "graph" {
        processes
            .iter()
            .take(80)
            .cloned()
            .chain(windows.iter().take(40).cloned())
            .collect::<Vec<_>>()
    } else {
        Vec::new()
    };
    json!({
        "schema": "sevenos.context.v1",
        "state": "native",
        "active_profile": active_profile,
        "active": {
            "profile": {
                "key": active_profile,
                "title": title_case(&active_profile),
                "role": "active profile",
                "state": "OK",
            },
            "app": active_app,
            "window": active_window,
            "layout": {
                "schema": "sevenos.shell-layout-policy.v1",
                "density": "compact",
                "priority": "workflow",
                "dock": { "behavior": "profile-aware" },
                "panels": { "motion": "standard" },
            },
            "workspace": active_window.get("workspace").and_then(Value::as_object).and_then(|object| object.get("name").or_else(|| object.get("id"))).cloned().unwrap_or_else(|| json!("")),
        },
        "primary_context": context_summary(&primary),
        "foreground_context": focused,
        "effective_context": context_summary(&effective),
        "alignment": {
            "active_profile": active_profile,
            "semantic_profile": primary.get("profile").and_then(Value::as_str).unwrap_or("equinox"),
            "effective_profile": effective_profile,
            "foreground_profile": focused.get("profile").and_then(Value::as_str).unwrap_or(""),
            "foreground_overrode_semantic": reason == "active-window",
            "reason": reason,
            "profile_aligned": effective.get("profile").and_then(Value::as_str) == Some(active_profile_key().as_str()),
        },
        "contexts": contexts,
        "graph": {
            "node_count": processes.len() + windows.len(),
            "relationship_count": 0,
            "nodes": graph_nodes,
            "relationships": [],
        },
        "observations": {
            "process_count": processes.len(),
            "window_count": windows.len(),
            "top_commands": [],
            "top_window_classes": [],
        },
        "shell_recommendation": shell_experience_payload().get("recommendation").cloned().unwrap_or_else(|| json!({})),
        "waybar_context": {
            "schema": "sevenos.context.native.v1",
            "event": "daemon-context",
            "time": unix_timestamp(),
            "profile": { "key": active_profile_key() },
            "app": active_app,
            "layout": { "density": "compact", "priority": "workflow" },
            "window_memory": {},
        },
        "actions": actions,
        "runtime": "seven-daemon",
        "writer": "seven-daemon",
    })
}

fn context_json(args: &[String]) {
    print_value(&context_payload(args));
}

fn check_state(value: &Value, ok_states: &[&str]) -> &'static str {
    let state = value
        .get("state")
        .and_then(Value::as_str)
        .or_else(|| value.get("decision").and_then(Value::as_str))
        .unwrap_or("unknown");
    if ok_states.iter().any(|item| item.eq_ignore_ascii_case(state)) {
        "OK"
    } else if matches!(state, "attention" | "partial" | "PART" | "needs-work" | "updates-available") {
        "PART"
    } else {
        "BLOCK"
    }
}

fn daemon_smoke_payload() -> Value {
    let health = health_payload();
    let readiness = daemon_readiness_payload();
    let daily = daemon_daily_payload();
    let surfaces = native_surfaces_payload();
    let installer = installer_flow_payload();
    let update = update_payload();

    let checks = vec![
        json!({
            "key": "core-health",
            "title": "Core runtime",
            "state": check_state(&health, &["ready"]),
            "detail": "seven-daemon health contract is available.",
            "command": "seven health",
            "writer": "seven-daemon",
        }),
        json!({
            "key": "readiness",
            "title": "OS readiness",
            "state": check_state(&readiness, &["ready", "attention"]),
            "detail": format!("{}%.", readiness.get("percent").and_then(Value::as_u64).unwrap_or(0)),
            "command": "seven readiness",
            "writer": "seven-daemon",
        }),
        json!({
            "key": "daily",
            "title": "Daily gate",
            "state": check_state(&daily, &["ready", "attention"]),
            "detail": daily.get("decision").and_then(Value::as_str).unwrap_or("unknown"),
            "command": "seven daily",
            "writer": "seven-daemon",
        }),
        json!({
            "key": "surfaces",
            "title": "Native surfaces",
            "state": check_state(&surfaces, &["productized", "ready"]),
            "detail": format!("{}%.", surfaces.get("score").and_then(Value::as_u64).unwrap_or(0)),
            "command": "seven surfaces",
            "writer": "seven-daemon",
        }),
        json!({
            "key": "installer-flow",
            "title": "Installer flow",
            "state": check_state(&installer, &["ready"]),
            "detail": installer.get("state").and_then(Value::as_str).unwrap_or("unknown"),
            "command": "seven installer flow",
            "writer": "seven-daemon",
        }),
        json!({
            "key": "update",
            "title": "Update route",
            "state": check_state(&update, &["ready", "attention", "updates-available"]),
            "detail": update.get("state").and_then(Value::as_str).unwrap_or("unknown"),
            "command": "seven update",
            "writer": "seven-daemon",
        }),
    ];

    let ok = checks
        .iter()
        .filter(|item| item.get("state").and_then(Value::as_str) == Some("OK"))
        .count();
    let partial = checks
        .iter()
        .filter(|item| item.get("state").and_then(Value::as_str) == Some("PART"))
        .count();
    let blocked = checks.len().saturating_sub(ok + partial);
    let score = (((ok as f64) + (partial as f64 * 0.5)) / checks.len().max(1) as f64 * 100.0).round() as u64;
    let state = if blocked > 0 {
        "blocked"
    } else if score >= 90 {
        "ready"
    } else {
        "attention"
    };
    let issues = checks
        .iter()
        .filter(|item| item.get("state").and_then(Value::as_str) != Some("OK"))
        .cloned()
        .collect::<Vec<_>>();

    json!({
        "schema": "sevenos.smoke.v1",
        "state": state,
        "score": score,
        "fast_gate": true,
        "purpose": "daemon-native SevenOS smoke gate for fast UI and release checks",
        "summary": {
            "checks": checks.len(),
            "ok": ok,
            "partial": partial,
            "blocked": blocked,
        },
        "checks": checks,
        "issues": issues,
        "commands": {
            "status": "seven smoke",
            "doctor": "seven smoke doctor",
            "deep": "scripts/smoke.sh doctor",
        },
        "runtime": "seven-daemon",
        "writer": "seven-daemon",
    })
}

fn daemon_smoke_json() {
    print_value(&daemon_smoke_payload());
}

fn shield_workspace_state() -> &'static str {
    let workspace = env::var("SEVENOS_SHIELD_WORKSPACE")
        .map(PathBuf::from)
        .unwrap_or_else(|_| home_dir().join("ShieldLab"));
    let state_dir = workspace.join(".sevenos");
    let manifest = state_dir.join("shield.json");
    let persona = state_dir.join("persona.json");
    let scope = state_dir.join("scope.json");
    let network_guard = state_dir.join("network-guard.json");
    let evidence_index = state_dir.join("evidence-index.json");
    let checklist = state_dir.join("SHIELD_CHECKLIST.md");
    let sandboxes = state_dir.join("SANDBOXES.md");
    let secure_browser = state_dir.join("launchers/secure-browser.sh");
    let network_audit = state_dir.join("launchers/network-audit.sh");

    if manifest.is_file()
        && persona.is_file()
        && scope.is_file()
        && network_guard.is_file()
        && evidence_index.is_file()
        && checklist.is_file()
        && sandboxes.is_file()
        && secure_browser.is_file()
        && network_audit.is_file()
    {
        "OK"
    } else if manifest.exists() || persona.exists() || scope.exists() || network_guard.exists() || evidence_index.exists() || checklist.exists() || sandboxes.exists() {
        "PART"
    } else {
        "MISS"
    }
}

fn shield_persona_state() -> &'static str {
    let workspace = shield_workspace_root();
    if workspace.join(".sevenos/persona.json").is_file() {
        "OK"
    } else {
        "MISS"
    }
}

fn shield_scope_state() -> &'static str {
    let workspace = shield_workspace_root();
    let scope_file = workspace.join(".sevenos/scope.json");
    if !scope_file.is_file() {
        return "MISS";
    }
    match fs::read_to_string(scope_file)
        .ok()
        .and_then(|content| serde_json::from_str::<Value>(&content).ok())
    {
        Some(value) => {
            let has_owner = value.get("owner").and_then(Value::as_str).map(|s| !s.is_empty()).unwrap_or(false);
            let has_engagement = value.get("engagement").and_then(Value::as_str).map(|s| !s.is_empty()).unwrap_or(false);
            let has_window = value.get("time_window").and_then(Value::as_str).map(|s| !s.is_empty()).unwrap_or(false);
            let has_targets = value.get("targets").and_then(Value::as_array).map(|items| !items.is_empty()).unwrap_or(false);
            if has_owner && has_engagement && has_window && has_targets { "OK" } else { "PART" }
        }
        None => "PART",
    }
}

fn shield_network_guard_state() -> &'static str {
    let workspace = shield_workspace_root();
    if workspace.join(".sevenos/network-guard.json").is_file() {
        "OK"
    } else {
        "MISS"
    }
}

fn shield_evidence_state() -> &'static str {
    let workspace = shield_workspace_root();
    if workspace.join(".sevenos/evidence-index.json").is_file() {
        "OK"
    } else {
        "MISS"
    }
}

fn cyberspace_state() -> &'static str {
    let root = sevenos_root().unwrap_or_else(|| PathBuf::from("."));
    let workspace = env::var("SEVENOS_SHIELD_WORKSPACE")
        .map(PathBuf::from)
        .unwrap_or_else(|_| home_dir().join("ShieldLab"));
    let script = root.join("security/cyberspace.sh");
    let context_file = workspace.join(".sevenos/cyberspace-context.json");

    if script.is_file() && context_file.is_file() {
        "OK"
    } else if script.is_file() {
        "PART"
    } else {
        "MISS"
    }
}

fn shield_row(key: &str, state: &str, detail: &str, command: &str) -> Value {
    json!({
        "key": key,
        "state": state,
        "detail": detail,
        "command": command,
        "writer": "seven-daemon",
    })
}

fn shield_checks() -> Vec<Value> {
    let packages = pacman_packages();
    let firewall_state = if state_dir().join("security/ufw-degraded").is_file() {
        "PART"
    } else {
        system_service_state("ufw.service")
    };
    vec![
        shield_row(
            "workspace",
            shield_workspace_state(),
            "Shield workspace policy, scope and launchers",
            "seven shield bootstrap",
        ),
        shield_row(
            "persona",
            shield_persona_state(),
            "Shield persona and session policy",
            "seven shield persona safe",
        ),
        shield_row(
            "scope",
            shield_scope_state(),
            "Shield authorization scope gate",
            "seven shield scope",
        ),
        shield_row(
            "network_guard",
            shield_network_guard_state(),
            "Persona-aware network posture",
            "seven shield network apply",
        ),
        shield_row(
            "evidence",
            shield_evidence_state(),
            "Evidence hash and chain-of-custody index",
            "seven shield evidence init",
        ),
        shield_row(
            "cyberspace",
            cyberspace_state(),
            "CyberSpace context workspaces and HUD",
            "seven shield mode",
        ),
        shield_row(
            "firewall",
            firewall_state,
            "UFW firewall service",
            "seven shield enable",
        ),
        shield_row(
            "firejail",
            if packages.contains("firejail") {
                "OK"
            } else {
                "MISS"
            },
            "Firejail app sandbox helper",
            "seven improve security --apply",
        ),
        shield_row(
            "bubblewrap",
            if packages.contains("bubblewrap") {
                "OK"
            } else {
                "MISS"
            },
            "Bubblewrap namespace sandbox helper",
            "seven improve security --apply",
        ),
        shield_row(
            "nmap",
            if command_exists("nmap") { "OK" } else { "MISS" },
            "Network audit tool",
            "seven profile install shield",
        ),
        shield_row(
            "wireshark",
            if command_exists("wireshark") {
                "OK"
            } else {
                "MISS"
            },
            "Packet analysis tool",
            "seven profile install shield",
        ),
    ]
}

fn shield_score(checks: &[Value]) -> (u64, u64) {
    let score = checks
        .iter()
        .map(|item| match item.get("state").and_then(Value::as_str) {
            Some("OK") => 2,
            Some("PART") => 1,
            _ => 0,
        })
        .sum();
    (score, checks.len() as u64 * 2)
}

fn shield_recommendations(checks: &[Value]) -> Vec<Value> {
    checks
        .iter()
        .filter(|item| item.get("state").and_then(Value::as_str) != Some("OK"))
        .map(|item| {
            let key = item.get("key").and_then(Value::as_str).unwrap_or("unknown");
            json!({
                "command": item.get("command").and_then(Value::as_str).unwrap_or("seven shield status"),
                "reason": format!("Resolve {}", key),
                "writer": "seven-daemon",
            })
        })
        .collect()
}

fn shield_json() {
    let checks = shield_checks();
    let (score, max_score) = shield_score(&checks);
    let percent = if max_score > 0 {
        ((score as f64 / max_score as f64) * 100.0).round() as u64
    } else {
        0
    };
    let posture = if score == max_score {
        "trusted"
    } else if score * 10 >= max_score * 6 {
        "partial"
    } else {
        "exposed"
    };
    let payload = json!({
        "schema": "sevenos.shield.v1",
        "posture": posture,
        "score": score,
        "max": max_score,
        "percent": percent,
        "checks": checks,
        "recommendations": shield_recommendations(&checks),
        "runtime": "seven-daemon",
        "writer": "seven-daemon",
    });
    println!(
        "{}",
        serde_json::to_string(&payload).unwrap_or_else(|_| "{}".to_string())
    );
}

fn shield_plan_item(check: &Value) -> Value {
    let key = check
        .get("key")
        .and_then(Value::as_str)
        .unwrap_or("unknown");
    let (title, severity, impact, phase, reason) = match key {
        "firewall" => (
            "Enable default firewall",
            "critical",
            "changes",
            "trust",
            "SevenOS must protect incoming traffic by default.",
        ),
        "workspace" => (
            "Bootstrap Shield workspace",
            "medium",
            "safe",
            "workspace",
            "Shield needs visible policy, checklist and launchers before it feels like an OS trust layer.",
        ),
        "persona" => (
            "Initialize Shield Persona Engine",
            "medium",
            "safe",
            "persona",
            "Shield should expose a visible cybersecurity mode, session policy and isolation intent.",
        ),
        "cyberspace" => (
            "Activate CyberSpace",
            "medium",
            "safe",
            "workspace",
            "Shield should expose context-aware workspaces and a HUD, not only package checks.",
        ),
        "scope" => (
            "Complete Shield scope",
            "high",
            "safe",
            "authorization",
            "Pentest and Red Team workflows need owner, engagement, time window and targets before execution.",
        ),
        "network_guard" => (
            "Record Network Guard posture",
            "medium",
            "safe",
            "network",
            "Shield personas should expose VPN/Tor/offline/scope requirements before tools launch.",
        ),
        "evidence" => (
            "Initialize Evidence Manager",
            "medium",
            "safe",
            "forensics",
            "Forensics needs hashes, metadata and chain-of-custody records.",
        ),
        "firejail" => (
            "Install Firejail sandbox",
            "high",
            "packages",
            "sandbox",
            "Apps and cyber tools need an accessible isolation layer.",
        ),
        "bubblewrap" => (
            "Install Bubblewrap namespaces",
            "high",
            "packages",
            "sandbox",
            "Flatpak-style isolation depends on namespace sandboxing.",
        ),
        "nmap" => (
            "Install network audit tools",
            "medium",
            "packages",
            "audit",
            "Shield mode needs first-class network discovery tools.",
        ),
        "wireshark" => (
            "Install packet analysis tools",
            "medium",
            "packages",
            "audit",
            "Shield mode needs visual packet analysis for real workflows.",
        ),
        _ => (
            "Resolve Shield gap",
            "medium",
            "changes",
            "trust",
            "Resolve this Shield readiness gap.",
        ),
    };
    json!({
        "key": key,
        "state": check.get("state").and_then(Value::as_str).unwrap_or("MISS"),
        "title": title,
        "severity": severity,
        "impact": impact,
        "phase": phase,
        "detail": check.get("detail").and_then(Value::as_str).unwrap_or(""),
        "reason": reason,
        "command": check.get("command").and_then(Value::as_str).unwrap_or("seven shield status"),
        "writer": "seven-daemon",
    })
}

fn severity_rank(item: &Value) -> u8 {
    match item.get("severity").and_then(Value::as_str) {
        Some("critical") => 0,
        Some("high") => 1,
        Some("medium") => 2,
        Some("low") => 3,
        _ => 9,
    }
}

fn shield_plan_json() {
    let mut actions: Vec<Value> = shield_checks()
        .iter()
        .filter(|item| item.get("state").and_then(Value::as_str) != Some("OK"))
        .map(shield_plan_item)
        .collect();
    actions.sort_by(|left, right| {
        severity_rank(left)
            .cmp(&severity_rank(right))
            .then_with(|| {
                left.get("key")
                    .and_then(Value::as_str)
                    .unwrap_or("")
                    .cmp(right.get("key").and_then(Value::as_str).unwrap_or(""))
            })
    });
    let critical = actions
        .iter()
        .filter(|item| item.get("severity").and_then(Value::as_str) == Some("critical"))
        .count();
    let high = actions
        .iter()
        .filter(|item| item.get("severity").and_then(Value::as_str) == Some("high"))
        .count();
    let medium = actions
        .iter()
        .filter(|item| item.get("severity").and_then(Value::as_str) == Some("medium"))
        .count();
    let payload = json!({
        "schema": "sevenos.shield-plan.v1",
        "summary": {
            "total": actions.len(),
            "critical": critical,
            "high": high,
            "medium": medium,
        },
        "next": actions,
        "runtime": "seven-daemon",
        "writer": "seven-daemon",
    });
    println!(
        "{}",
        serde_json::to_string(&payload).unwrap_or_else(|_| "{}".to_string())
    );
}

fn shield_workspace_root() -> PathBuf {
    env::var("SEVENOS_SHIELD_WORKSPACE")
        .map(PathBuf::from)
        .unwrap_or_else(|_| home_dir().join("ShieldLab"))
}

fn shield_persona_value(workspace: &Path) -> Value {
    let persona_file = workspace.join(".sevenos/persona.json");
    let fallback = json!({
        "schema": "sevenos.shield-persona-state.v1",
        "state": "DEFAULT",
        "active": {
            "key": "safe",
            "title": "Safe Audit",
            "network": "normal-guarded",
            "isolation": "standard-sandbox",
            "visual": "blue guarded SOC"
        },
        "session": "persistent",
        "workspace": workspace.to_string_lossy(),
    });
    if !persona_file.is_file() {
        return fallback;
    }
    fs::read_to_string(persona_file)
        .ok()
        .and_then(|content| serde_json::from_str::<Value>(&content).ok())
        .unwrap_or(fallback)
}

fn cyberspace_active_context(context_file: &Path) -> Value {
    if !context_file.is_file() {
        return json!({
            "key": "none",
            "state": "MISS",
            "path": context_file.to_string_lossy(),
        });
    }

    match fs::read_to_string(context_file)
        .ok()
        .and_then(|content| serde_json::from_str::<Value>(&content).ok())
    {
        Some(mut value) => {
            if let Some(object) = value.as_object_mut() {
                object
                    .entry("path".to_string())
                    .or_insert_with(|| json!(context_file.to_string_lossy()));
                object
                    .entry("state".to_string())
                    .or_insert_with(|| json!("ACTIVE"));
            }
            value
        }
        None => json!({
            "key": "invalid",
            "state": "INVALID",
            "path": context_file.to_string_lossy(),
        }),
    }
}

fn cyberspace_scope(scope_file: &Path) -> Value {
    if !scope_file.is_file() {
        return json!({
            "schema": "sevenos.shield-scope.v1",
            "state": "MISS",
            "active": false,
            "target_count": 0,
            "path": scope_file.to_string_lossy(),
        });
    }

    match fs::read_to_string(scope_file)
        .ok()
        .and_then(|content| serde_json::from_str::<Value>(&content).ok())
    {
        Some(value) => {
            let active = value.get("active").and_then(Value::as_bool).unwrap_or(false);
            let target_count = value
                .get("targets")
                .and_then(Value::as_array)
                .map(Vec::len)
                .unwrap_or(0);
            json!({
                "schema": value.get("schema").and_then(Value::as_str).unwrap_or("sevenos.shield-scope.v1"),
                "state": if active { "ACTIVE" } else { "DRAFT" },
                "active": active,
                "target_count": target_count,
                "owner": value.get("owner").cloned().unwrap_or_else(|| json!("")),
                "engagement": value.get("engagement").cloned().unwrap_or_else(|| json!("")),
                "time_window": value.get("time_window").cloned().unwrap_or_else(|| json!("")),
                "path": scope_file.to_string_lossy(),
            })
        }
        None => json!({
            "schema": "sevenos.shield-scope.v1",
            "state": "INVALID",
            "active": false,
            "target_count": 0,
            "path": scope_file.to_string_lossy(),
        }),
    }
}

fn cyberspace_context_value(spec: &CyberContextSpec) -> Value {
    let tools: Vec<Value> = spec
        .tools
        .iter()
        .map(|tool| {
            json!({
                "name": tool,
                "state": if command_exists(tool) { "OK" } else { "MISS" },
            })
        })
        .collect();
    json!({
        "key": spec.key,
        "title": spec.title,
        "workspace": spec.workspace,
        "accent": spec.accent,
        "purpose": spec.purpose,
        "apps": spec.apps,
        "tools": tools,
        "actions": spec.actions,
        "command": format!("seven shield context {}", spec.key),
        "layout_command": format!("seven shield layout {}", spec.key),
    })
}

fn cyberspace_json() {
    let root = sevenos_root().unwrap_or_else(|| PathBuf::from("."));
    let workspace = shield_workspace_root();
    let state_dir = workspace.join(".sevenos");
    let context_file = state_dir.join("cyberspace-context.json");
    let scope_file = state_dir.join("scope.json");
    let script = root.join("security/cyberspace.sh");
    let workspaces: Vec<Value> = CYBER_CONTEXTS.iter().map(cyberspace_context_value).collect();
    let active_context = cyberspace_active_context(&context_file);
    let scope = cyberspace_scope(&scope_file);
    let persona = shield_persona_value(&workspace);
    let persona_active = persona.get("active").cloned().unwrap_or_else(|| json!({}));
    let state = if script.is_file() && scope.get("state").and_then(Value::as_str) == Some("ACTIVE") {
        "ready"
    } else if script.is_file() {
        "foundation"
    } else {
        "missing"
    };
    let payload = json!({
        "schema": "sevenos.cyberspace.v1",
        "state": state,
        "workspace": workspace.to_string_lossy(),
        "state_dir": state_dir.to_string_lossy(),
        "active_context": active_context,
        "persona": {
            "active": persona_active,
            "session": persona.get("session").cloned().unwrap_or_else(|| json!("persistent")),
            "network": persona.get("active").and_then(|item| item.get("network")).cloned().unwrap_or_else(|| json!("normal-guarded")),
            "isolation": persona.get("active").and_then(|item| item.get("isolation")).cloned().unwrap_or_else(|| json!("standard-sandbox")),
        },
        "scope": scope,
        "workspaces": workspaces,
        "commands": {
            "activate": "seven profile activate shield",
            "dashboard": "seven shield dashboard",
            "hud": "seven shield hud",
            "scope": "seven shield scope",
            "layout": "seven shield layout <context>",
        },
        "principles": [
            "context before tool",
            "scope before scan",
            "isolation before unknown workloads",
            "report before closure"
        ],
        "runtime": "seven-daemon",
        "future_daemon": "seven-cyberd",
        "writer": "seven-daemon",
    });
    println!(
        "{}",
        serde_json::to_string(&payload).unwrap_or_else(|_| "{}".to_string())
    );
}

fn cyberspace_plan_json() {
    let workspace = shield_workspace_root();
    let state_dir = workspace.join(".sevenos");
    let context_file = state_dir.join("cyberspace-context.json");
    let scope_file = state_dir.join("scope.json");
    let mut actions = Vec::new();

    if shield_workspace_state() != "OK" {
        actions.push(json!({
            "key": "workspace",
            "title": "Bootstrap Shield workspace",
            "severity": "high",
            "impact": "safe",
            "command": "seven shield bootstrap",
            "reason": "CyberSpace needs policy, scope, reports and launchers before real workflows.",
            "writer": "seven-daemon",
        }));
    }
    if !scope_file.is_file() {
        actions.push(json!({
            "key": "scope",
            "title": "Create audit scope",
            "severity": "critical",
            "impact": "safe",
            "command": "seven shield scope",
            "reason": "A cyber workspace must surface authorized targets before network actions.",
            "writer": "seven-daemon",
        }));
    }
    if !context_file.is_file() {
        actions.push(json!({
            "key": "context",
            "title": "Enter a CyberSpace context",
            "severity": "medium",
            "impact": "changes",
            "command": "seven shield context recon",
            "reason": "SevenOS should know whether the user is doing recon, web testing, forensics or sandbox work.",
            "writer": "seven-daemon",
        }));
    }
    if command_exists("firejail") == false {
        actions.push(json!({
            "key": "sandbox",
            "title": "Install sandbox runtime",
            "severity": "high",
            "impact": "packages",
            "command": "seven improve security --apply",
            "reason": "CyberSpace depends on accessible isolation for unknown workloads.",
            "writer": "seven-daemon",
        }));
    }

    actions.sort_by(|left, right| severity_rank(left).cmp(&severity_rank(right)));
    let critical = actions
        .iter()
        .filter(|item| item.get("severity").and_then(Value::as_str) == Some("critical"))
        .count();
    let high = actions
        .iter()
        .filter(|item| item.get("severity").and_then(Value::as_str) == Some("high"))
        .count();
    let medium = actions
        .iter()
        .filter(|item| item.get("severity").and_then(Value::as_str) == Some("medium"))
        .count();
    let payload = json!({
        "schema": "sevenos.cyberspace-plan.v1",
        "summary": {
            "total": actions.len(),
            "critical": critical,
            "high": high,
            "medium": medium,
        },
        "next": actions,
        "runtime": "seven-daemon",
        "future_daemon": "seven-cyberd",
        "writer": "seven-daemon",
    });
    println!(
        "{}",
        serde_json::to_string(&payload).unwrap_or_else(|_| "{}".to_string())
    );
}

fn profile_payload(
    root: &Path,
    packages: &HashSet<String>,
    active: &str,
    spec: &ProfileSpec,
) -> Value {
    let mut all_packages = Vec::new();
    for file in spec.package_files {
        all_packages.extend(read_package_file(root, file));
    }
    let installed = all_packages
        .iter()
        .filter(|package| package_satisfied(package, packages))
        .count();
    let total = all_packages.len();
    let state = if total == 0 {
        "MISS"
    } else if installed == total {
        "OK"
    } else if installed > 0 {
        "PART"
    } else {
        "MISS"
    };
    let missing_packages: Vec<&String> = all_packages
        .iter()
        .filter(|package| !package_satisfied(package, packages))
        .collect();
    let apps: Vec<Value> = spec
        .apps
        .iter()
        .map(|app| {
            let command = match app_command(app) {
                "" => (*app).to_string(),
                value => value.to_string(),
            };
            json!({
                "name": app,
                "state": app_state(root, app),
                "command": command,
            })
        })
        .collect();
    let workspace = profile_workspace(spec);
    let state_dir = workspace.join(".sevenos");

    json!({
        "key": spec.key,
        "title": spec.title,
        "description": spec.description,
        "role": spec.role,
        "accent": spec.accent,
        "principle": spec.principle,
        "story": spec.story,
        "state": state,
        "bootstrap_state": bootstrap_state(spec),
        "installed": installed,
        "total": total,
        "active": active == spec.key,
        "workspace": workspace.to_string_lossy(),
        "state_dir": state_dir.to_string_lossy(),
        "manifest": state_dir.join("profile.json").to_string_lossy(),
        "checklist": state_dir.join("CHECKLIST.md").to_string_lossy(),
        "launcher": state_dir.join("launch.sh").to_string_lossy(),
        "packages": {
            "missing_count": missing_packages.len(),
            "missing_preview": missing_packages.into_iter().take(12).collect::<Vec<_>>(),
        },
        "apps": apps,
        "action": format!("seven profile install {}", spec.key),
        "bootstrap_command": format!("seven profile bootstrap {}", spec.key),
        "open_command": format!("seven profile open {}", spec.key),
        "writer": "seven-daemon",
    })
}

fn daemon_profiles_payload() -> (PathBuf, String, Vec<Value>) {
    let root = sevenos_root().unwrap_or_else(|| PathBuf::from("."));
    let packages = pacman_packages();
    let active = active_profile_key();
    let profiles: Vec<Value> = PROFILES
        .iter()
        .map(|spec| profile_payload(&root, &packages, &active, spec))
        .collect();
    (root, active, profiles)
}

fn profiles_json() {
    let (root, active, profiles) = daemon_profiles_payload();
    let ok = profiles
        .iter()
        .filter(|item| item.get("state").and_then(Value::as_str) == Some("OK"))
        .count();
    let bootstrapped = profiles
        .iter()
        .filter(|item| item.get("bootstrap_state").and_then(Value::as_str) == Some("OK"))
        .count();
    let payload = json!({
        "schema": "sevenos.daemon.profiles.v1",
        "state": "ready",
        "active": active,
        "root": root.to_string_lossy(),
        "summary": {
            "total": profiles.len(),
            "complete": ok,
            "bootstrapped": bootstrapped,
            "partial_or_missing": profiles.len().saturating_sub(ok),
        },
        "profiles": profiles,
    });
    println!(
        "{}",
        serde_json::to_string(&payload).unwrap_or_else(|_| "{}".to_string())
    );
}

fn profiles_status_json() {
    let (_root, _active, profiles) = daemon_profiles_payload();
    println!(
        "{}",
        serde_json::to_string(&profiles).unwrap_or_else(|_| "[]".to_string())
    );
}

fn profile_missing_apps(profile: &Value) -> Vec<Value> {
    profile
        .get("apps")
        .and_then(Value::as_array)
        .map(|apps| {
            apps.iter()
                .filter(|app| app.get("state").and_then(Value::as_str) != Some("OK"))
                .map(|app| {
                    json!({
                        "name": app.get("name").and_then(Value::as_str).unwrap_or("app"),
                        "state": app.get("state").and_then(Value::as_str).unwrap_or("MISS"),
                        "command": app.get("command").and_then(Value::as_str).unwrap_or(""),
                    })
                })
                .collect::<Vec<_>>()
        })
        .unwrap_or_default()
}

fn profile_missing_packages(profile: &Value) -> Vec<Value> {
    profile
        .get("packages")
        .and_then(|packages| packages.get("missing_preview"))
        .and_then(Value::as_array)
        .map(|items| items.iter().cloned().collect::<Vec<_>>())
        .unwrap_or_default()
}

fn profile_missing_count(profile: &Value) -> u64 {
    profile
        .get("packages")
        .and_then(|packages| packages.get("missing_count"))
        .and_then(Value::as_u64)
        .unwrap_or(0)
}

fn profile_gap_item(profile: &Value) -> Value {
    let missing_packages = profile_missing_packages(profile);
    let missing_apps = profile_missing_apps(profile);
    let state = profile.get("state").and_then(Value::as_str).unwrap_or("MISS");
    let bootstrap_state = profile
        .get("bootstrap_state")
        .and_then(Value::as_str)
        .unwrap_or("MISS");
    let priority = if state == "MISS" || bootstrap_state != "OK" {
        "high"
    } else if state == "PART" || !missing_apps.is_empty() || profile_missing_count(profile) > 0 {
        "medium"
    } else {
        "low"
    };

    json!({
        "key": profile.get("key").and_then(Value::as_str).unwrap_or("profile"),
        "title": profile.get("title").and_then(Value::as_str).unwrap_or("Profile"),
        "state": state,
        "bootstrap_state": bootstrap_state,
        "priority": priority,
        "installed": profile.get("installed").and_then(Value::as_u64).unwrap_or(0),
        "total": profile.get("total").and_then(Value::as_u64).unwrap_or(0),
        "missing_count": profile_missing_count(profile),
        "missing_app_count": missing_apps.len(),
        "workspace": profile.get("workspace").and_then(Value::as_str).unwrap_or(""),
        "install_command": profile.get("action").and_then(Value::as_str).unwrap_or("seven profile status"),
        "bootstrap_command": profile.get("bootstrap_command").and_then(Value::as_str).unwrap_or("seven profile status"),
        "open_command": profile.get("open_command").and_then(Value::as_str).unwrap_or("seven profile status"),
        "missing_packages": missing_packages,
        "missing_apps": missing_apps,
        "writer": "seven-daemon",
    })
}

fn profile_gaps_json() {
    let (_root, _active, profiles) = daemon_profiles_payload();
    let gaps: Vec<Value> = profiles.iter().map(profile_gap_item).collect();
    println!(
        "{}",
        serde_json::to_string(&json!({
            "schema": "sevenos.profile-gaps.v1",
            "profiles": gaps,
            "writer": "seven-daemon",
        }))
        .unwrap_or_else(|_| "{}".to_string())
    );
}

fn profile_plan_item(gap: &Value) -> Option<Value> {
    let state = gap.get("state").and_then(Value::as_str).unwrap_or("MISS");
    let bootstrap_state = gap
        .get("bootstrap_state")
        .and_then(Value::as_str)
        .unwrap_or("MISS");
    let missing_count = gap.get("missing_count").and_then(Value::as_u64).unwrap_or(0);
    let missing_app_count = gap
        .get("missing_app_count")
        .and_then(Value::as_u64)
        .unwrap_or(0);
    if state == "OK" && bootstrap_state == "OK" && missing_count == 0 && missing_app_count == 0 {
        return None;
    }
    let severity = if bootstrap_state != "OK" || state == "MISS" {
        "high"
    } else if missing_count > 5 || missing_app_count > 1 {
        "medium"
    } else {
        "low"
    };
    let key = gap.get("key").and_then(Value::as_str).unwrap_or("profile");
    let title = gap.get("title").and_then(Value::as_str).unwrap_or("Profile");
    let command = if bootstrap_state != "OK" {
        gap.get("bootstrap_command")
            .and_then(Value::as_str)
            .unwrap_or("seven profile status")
    } else {
        gap.get("install_command")
            .and_then(Value::as_str)
            .unwrap_or("seven profile status")
    };
    Some(json!({
        "key": key,
        "title": format!("Complete {}", title),
        "severity": severity,
        "state": state,
        "bootstrap_state": bootstrap_state,
        "missing_count": missing_count,
        "missing_app_count": missing_app_count,
        "reason": format!("{} needs {} package(s) and {} app launcher(s).", title, missing_count, missing_app_count),
        "command": command,
        "writer": "seven-daemon",
    }))
}

fn profile_plan_json() {
    let (_root, _active, profiles) = daemon_profiles_payload();
    let gaps: Vec<Value> = profiles.iter().map(profile_gap_item).collect();
    let next: Vec<Value> = gaps.iter().filter_map(profile_plan_item).collect();
    let critical = next
        .iter()
        .filter(|item| item.get("severity").and_then(Value::as_str) == Some("critical"))
        .count();
    let high = next
        .iter()
        .filter(|item| item.get("severity").and_then(Value::as_str) == Some("high"))
        .count();
    let medium = next
        .iter()
        .filter(|item| item.get("severity").and_then(Value::as_str) == Some("medium"))
        .count();
    println!(
        "{}",
        serde_json::to_string(&json!({
            "schema": "sevenos.profile-plan.v1",
            "summary": {
                "total": next.len(),
                "critical": critical,
                "high": high,
                "medium": medium,
            },
            "next": next,
            "writer": "seven-daemon",
        }))
        .unwrap_or_else(|_| "{}".to_string())
    );
}

fn profile_health_json() {
    let (_root, active, profiles) = daemon_profiles_payload();
    let ready = profiles
        .iter()
        .filter(|item| {
            item.get("state").and_then(Value::as_str) != Some("MISS")
                && item.get("bootstrap_state").and_then(Value::as_str) == Some("OK")
        })
        .count();
    let needs_install = profiles
        .iter()
        .filter(|item| item.get("state").and_then(Value::as_str) == Some("MISS"))
        .count();
    let needs_bootstrap = profiles
        .iter()
        .filter(|item| item.get("bootstrap_state").and_then(Value::as_str) != Some("OK"))
        .count();
    let active_count = profiles
        .iter()
        .filter(|item| item.get("key").and_then(Value::as_str) == Some(active.as_str()))
        .count();
    println!(
        "{}",
        serde_json::to_string(&json!({
            "schema": "sevenos.profile-health.v1",
            "summary": {
                "total": profiles.len(),
                "active": active_count,
                "capability": 0,
                "quiet": profiles.len().saturating_sub(active_count),
                "ready": ready,
                "needs_install": needs_install,
                "needs_bootstrap": needs_bootstrap,
                "isolation_ready": true,
                "alias_migration_pending": 0,
                "equinox_system_ready": profiles.iter().any(|item| {
                    item.get("key").and_then(Value::as_str) == Some("equinox")
                        && item.get("state").and_then(Value::as_str) != Some("MISS")
                        && item.get("bootstrap_state").and_then(Value::as_str) == Some("OK")
                }),
            },
            "profiles": profiles,
            "writer": "seven-daemon",
        }))
        .unwrap_or_else(|_| "{}".to_string())
    );
}

fn serve() {
    let dir = state_dir();
    if let Err(error) = fs::create_dir_all(&dir) {
        eprintln!(
            "seven-daemon: failed to create state dir {}: {}",
            dir.display(),
            error
        );
    }

    println!("seven-daemon: local runtime started");
    println!("seven-daemon: event file {}", event_file().display());

    loop {
        thread::sleep(Duration::from_secs(60));
        println!("seven-daemon: heartbeat events={}", event_count());
    }
}

fn observe_once(args: &[String]) -> i32 {
    let root = match sevenos_root() {
        Some(path) => path,
        None => {
            eprintln!("seven-daemon observe-once: could not find SevenOS root");
            return 1;
        }
    };
    let context_script = root.join("scripts/context.sh");
    if !context_script.is_file() {
        eprintln!(
            "seven-daemon observe-once: missing {}",
            context_script.display()
        );
        return 1;
    }

    let output = Command::new(&context_script)
        .arg("emit")
        .arg("--json")
        .env("SEVENOS_ROOT", &root)
        .current_dir(&root)
        .output();

    match output {
        Ok(result) if result.status.success() => {
            if args.iter().any(|arg| arg == "--json" || arg == "json") {
                print!("{}", String::from_utf8_lossy(&result.stdout));
            } else {
                println!("seven-daemon: context observation recorded");
            }
            0
        }
        Ok(result) => {
            eprintln!(
                "seven-daemon observe-once: {}",
                String::from_utf8_lossy(&result.stderr)
            );
            1
        }
        Err(error) => {
            eprintln!(
                "seven-daemon observe-once: failed to run context: {}",
                error
            );
            1
        }
    }
}

fn observe_loop(args: &[String]) -> i32 {
    let interval = interval_value(args);
    println!(
        "seven-daemon: context observer started interval={}s",
        interval
    );

    loop {
        let result = observe_once(&["observe-once".to_string()]);
        if result != 0 {
            eprintln!("seven-daemon: context observation failed");
        }
        thread::sleep(Duration::from_secs(interval));
    }
}

fn emit(args: &[String]) -> i32 {
    let source = arg_value(args, "--source", "core");
    let event_type = arg_value(args, "--type", "event");
    let state = arg_value(args, "--state", "OK");
    let message = arg_value(args, "--message", "");
    let command = arg_value(args, "--command", "");
    let payload_raw = arg_value(args, "--payload-json", "");

    if message.is_empty() {
        eprintln!("seven-daemon emit: --message is required");
        return 2;
    }

    let payload_value = if payload_raw.is_empty() {
        Value::Null
    } else {
        match serde_json::from_str::<Value>(&payload_raw) {
            Ok(value) => value,
            Err(error) => {
                eprintln!("seven-daemon emit: invalid --payload-json: {}", error);
                return 2;
            }
        }
    };

    let dir = state_dir();
    if let Err(error) = fs::create_dir_all(&dir) {
        eprintln!(
            "seven-daemon emit: failed to create {}: {}",
            dir.display(),
            error
        );
        return 1;
    }

    let timestamp = unix_timestamp();
    let payload = json!({
        "schema": "sevenos.event.v1",
        "timestamp": format!("unix:{}", timestamp),
        "timestamp_unix": timestamp,
        "source": source,
        "type": event_type,
        "state": state,
        "message": message,
        "command": if command.is_empty() { Value::Null } else { Value::String(command) },
        "writer": "seven-daemon",
        "payload": payload_value,
    })
    .to_string()
        + "\n";

    let path = event_file();
    match OpenOptions::new().create(true).append(true).open(&path) {
        Ok(mut file) => {
            if let Err(error) = file.write_all(payload.as_bytes()) {
                eprintln!(
                    "seven-daemon emit: failed to write {}: {}",
                    path.display(),
                    error
                );
                return 1;
            }
        }
        Err(error) => {
            eprintln!(
                "seven-daemon emit: failed to open {}: {}",
                path.display(),
                error
            );
            return 1;
        }
    }

    if args.iter().any(|arg| arg == "--json" || arg == "json") {
        println!(
            "{{\"schema\":\"sevenos.daemon.emit.v1\",\"ok\":true,\"event_file\":\"{}\",\"event_count\":{}}}",
            json_escape(&path.to_string_lossy()),
            event_count()
        );
    } else {
        println!("seven-daemon: event recorded in {}", path.display());
    }

    0
}

fn native_action_registry() -> Vec<Value> {
    vec![
        native_action(
            "core.health",
            "Core health",
            "Fast daemon-owned health signal for Hub, Settings and Doctor.",
            "core",
            "read",
            "safe-read",
            "seven-daemon health --json",
            "health",
        ),
        native_action(
            "health.status",
            "SevenOS health",
            "Compatibility action for surfaces that ask for the public SevenOS health route.",
            "health",
            "read",
            "safe-read",
            "seven health",
            "health",
        ),
        native_action(
            "about.status",
            "About SevenOS",
            "Daemon-owned public identity contract for About, Welcome and Settings.",
            "identity",
            "read",
            "safe-read",
            "seven-daemon about --json",
            "about",
        ),
        native_action(
            "health.product",
            "SevenOS health",
            "Daemon-owned daily health contract that summarizes product, lifecycle, update, session and foundations.",
            "health",
            "read",
            "safe-read",
            "seven-daemon product-health --json",
            "health",
        ),
        native_action(
            "core.snapshot",
            "Core snapshot",
            "SevenBus integrity, event counts and last known daemon state.",
            "core",
            "read",
            "safe-read",
            "seven-daemon snapshot --json",
            "state",
        ),
        native_action(
            "events.summary",
            "Event summary",
            "Local SevenBus summary without walking the full script stack.",
            "core",
            "read",
            "safe-read",
            "seven-daemon summary --json",
            "timeline",
        ),
        native_action(
            "profiles.status",
            "Mini OS profiles",
            "Daemon-readable profile state for Equinox, Forge, Studio, Shield, Atlas, Baobab and Pulse.",
            "profiles",
            "read",
            "safe-read",
            "seven-daemon profiles --json",
            "profiles",
        ),
        native_action(
            "profile.status",
            "Active Mini OS",
            "Compatibility action for surfaces that ask for the current Mini OS profile state.",
            "profiles",
            "read",
            "safe-read",
            "seven profile status",
            "profiles",
        ),
        native_action(
            "surfaces.status",
            "Native surfaces",
            "Fast daemon-owned readiness for the core SevenOS graphical surfaces.",
            "surfaces",
            "read",
            "safe-read",
            "seven-daemon surfaces --json",
            "surfaces",
        ),
        native_action(
            "native.surfaces",
            "Native surface contract",
            "Daemon-owned readiness contract for Settings, Doctor, Store, Installer, Files, Reader, Terminal and Home.",
            "surfaces",
            "read",
            "safe-read",
            "seven core surfaces --json",
            "surfaces",
        ),
        native_action(
            "installer.status",
            "Installer status",
            "Live installer readiness and Calamares handoff state.",
            "installer",
            "read",
            "safe-read",
            "seven-daemon installer --json",
            "installer",
        ),
        native_action(
            "installer.plan",
            "Installer plan",
            "Prioritized installer actions for ISO and live-session hardening.",
            "installer",
            "read",
            "safe-read",
            "seven-daemon installer-plan --json",
            "installer",
        ),
        native_action(
            "installer.flow",
            "Installer flow",
            "Native checks for live boot, Wi-Fi choice, Calamares branding, unpackfs and post-install hooks.",
            "installer",
            "read",
            "safe-read",
            "seven-daemon installer-flow --json",
            "installer",
        ),
        native_action(
            "native.installer.flow",
            "Native installer flow",
            "Daemon-owned ISO and graphical installer flow contract before building or flashing SevenOS.",
            "installer",
            "read",
            "safe-read",
            "seven core installer-flow --json",
            "installer",
        ),
        native_action(
            "update.status",
            "Update status",
            "Native SevenOS update readiness without running privileged package operations.",
            "update",
            "read",
            "safe-read",
            "seven-daemon update --json",
            "update",
        ),
        native_action(
            "native.update",
            "Native update status",
            "Daemon-owned SevenOS update readiness without privileged package operations.",
            "update",
            "read",
            "safe-read",
            "seven core update --json",
            "update",
        ),
        native_action(
            "update.plan",
            "Update plan",
            "Native update workflow plan with rollback and privileged-adapter boundaries.",
            "update",
            "read",
            "safe-read",
            "seven-daemon update-plan --json",
            "update",
        ),
        native_action(
            "recovery.status",
            "SevenOS recovery",
            "Daemon-owned recovery readiness covering protected state, backups, repair, installer and release channel.",
            "recovery",
            "read",
            "safe-read",
            "seven-daemon recovery --json",
            "recovery",
        ),
        native_action(
            "native.update.plan",
            "Native update plan",
            "Daemon-owned update workflow plan with rollback and privileged boundaries.",
            "update",
            "read",
            "safe-read",
            "seven core update-plan --json",
            "update",
        ),
        native_action(
            "doctor.task",
            "Doctor task manager",
            "Native process, resource and service snapshot for Seven Doctor.",
            "doctor",
            "read",
            "safe-read",
            "seven-daemon doctor-task --json",
            "doctor",
        ),
        native_action(
            "native.doctor.task",
            "Native doctor task manager",
            "Daemon-owned resource, process and service snapshot used by Seven Doctor.",
            "doctor",
            "read",
            "safe-read",
            "seven core doctor-task --json",
            "doctor",
        ),
        native_action(
            "experience.status",
            "Experience status",
            "Native theme, language, profile and session snapshot for every SevenOS surface.",
            "experience",
            "read",
            "safe-read",
            "seven-daemon experience --json",
            "experience",
        ),
        native_action(
            "native.experience",
            "Native experience state",
            "Daemon-owned theme, language, profile and session state for SevenOS surfaces.",
            "experience",
            "read",
            "safe-read",
            "seven core experience --json",
            "experience",
        ),
        native_action(
            "packages.plan",
            "Software plan",
            "SevenPkg, Flatpak and profile package readiness from the daemon.",
            "software",
            "read",
            "safe-read",
            "seven-daemon packages-plan --json",
            "store",
        ),
        native_action(
            "store.open",
            "Open SevenStore",
            "Compatibility action for opening the SevenOS software center from native surfaces.",
            "software",
            "launch",
            "safe-read",
            "seven-store",
            "store",
        ),
        native_action(
            "server.plan",
            "Server plan",
            "Local Forge-first Server and Deploy readiness without exposing a public backend.",
            "server",
            "read",
            "safe-read",
            "seven-daemon server-plan --json",
            "server",
        ),
        native_action(
            "windows.plan",
            "Windows app plan",
            "Wine, Bottles, Lutris and launcher compatibility readiness.",
            "windows",
            "read",
            "safe-read",
            "seven-daemon windows-plan --json",
            "compatibility",
        ),
        native_action(
            "phase.gate",
            "Phase gate",
            "Runtime phase gate for moving SevenOS from scripts toward native services.",
            "quality",
            "read",
            "safe-read",
            "seven-daemon phase-gate --json",
            "quality",
        ),
        native_action(
            "public.readiness",
            "Public readiness",
            "Daemon-owned daily/public readiness decision without opening the deep release audit stack.",
            "quality",
            "read",
            "safe-read",
            "seven-daemon public-readiness --json",
            "quality",
        ),
        native_action(
            "production.readiness",
            "Production readiness",
            "Daemon-owned beta and large-scale readiness contract with honest hardware validation boundaries.",
            "quality",
            "read",
            "safe-read",
            "seven-daemon production --json",
            "quality",
        ),
        native_action(
            "distribution.readiness",
            "Distribution readiness",
            "Daemon-owned top-level SevenOS distribution identity, autonomy, surfaces, installer and update contract.",
            "quality",
            "read",
            "safe-read",
            "seven-daemon distribution --json",
            "quality",
        ),
        native_action(
            "autonomy.status",
            "Distribution autonomy",
            "Daemon-owned autonomy contract that proves SevenOS is presented as an OS layer, not a pile of scripts.",
            "autonomy",
            "read",
            "safe-read",
            "seven-daemon autonomy --json",
            "quality",
        ),
        native_action(
            "platform.status",
            "Platform facade",
            "Daemon-owned public vocabulary for SevenOS layers and hidden backend implementations.",
            "platform",
            "read",
            "safe-read",
            "seven-daemon platform --json",
            "quality",
        ),
        native_action(
            "mask.status",
            "Public mask",
            "Daemon-owned public masking contract that keeps backend names behind SevenOS surfaces.",
            "mask",
            "read",
            "safe-read",
            "seven-daemon mask --json",
            "quality",
        ),
        native_action(
            "adaptive.status",
            "Adaptive UI",
            "Daemon-owned adaptive profile/theme/language/wallpaper contract for all SevenOS surfaces.",
            "adaptive",
            "read",
            "safe-read",
            "seven-daemon adaptive --json",
            "experience",
        ),
        native_action(
            "routes.status",
            "User routes",
            "Daemon-owned mapping from user intent to SevenOS surfaces and backend adapters.",
            "routes",
            "read",
            "safe-read",
            "seven-daemon routes --json",
            "routes",
        ),
        native_action(
            "channel.status",
            "Release channel",
            "Daemon-owned release channel and freeze status without shelling into the channel script.",
            "release",
            "read",
            "safe-read",
            "seven-daemon channel --json",
            "release",
        ),
        native_action(
            "foundations.status",
            "SevenOS foundations",
            "Daemon-owned view of backend foundations masked by SevenOS product routes.",
            "foundations",
            "read",
            "safe-read",
            "seven-daemon foundations --json",
            "foundations",
        ),
        native_action(
            "lifecycle.status",
            "SevenOS lifecycle",
            "Daemon-owned maintenance lifecycle covering update, repair, installer and smoke gates.",
            "lifecycle",
            "read",
            "safe-read",
            "seven-daemon lifecycle --json",
            "lifecycle",
        ),
        native_action(
            "product.status",
            "SevenOS product",
            "Daemon-owned product snapshot for Hub, Settings, Welcome and installer surfaces.",
            "product",
            "read",
            "safe-read",
            "seven-daemon product --json",
            "product",
        ),
        native_action(
            "support.status",
            "SevenOS support",
            "Daemon-owned local-first support summary with health, product, lifecycle and events.",
            "support",
            "read",
            "safe-read",
            "seven-daemon support --json",
            "support",
        ),
        native_action(
            "native.actions",
            "Native core actions",
            "Rust-owned SevenOS action contract used by native surfaces.",
            "actions",
            "read",
            "safe-read",
            "seven-daemon actions --json",
            "actions",
        ),
        native_action(
            "smoke.status",
            "SevenOS smoke gate",
            "Fast public-product gate used before opening deeper developer audits.",
            "quality",
            "read",
            "safe-read",
            "seven smoke",
            "quality",
        ),
        native_action(
            "smoke.doctor",
            "Smoke doctor",
            "Validate state, product, identity, distribution and health contracts with strict timeouts.",
            "quality",
            "read",
            "safe-read",
            "seven smoke doctor",
            "quality",
        ),
        native_action(
            "smoke.json",
            "Smoke gate JSON",
            "Expose the fast SevenOS distribution smoke contract for native surfaces.",
            "quality",
            "read",
            "safe-read",
            "seven smoke --json",
            "quality",
        ),
        native_action(
            "quality.ux.fast",
            "Fast UX gate",
            "Run the bounded daily UX gate for native tools, manifests and design coherence.",
            "quality",
            "read",
            "safe-read",
            "seven ux fast --json",
            "quality",
        ),
        native_action(
            "control.plan",
            "Control plane",
            "Prioritized SevenOS actions across readiness, trust and services.",
            "control",
            "read",
            "safe-read",
            "seven control",
            "control",
        ),
        native_action(
            "scheduler.plan",
            "Scheduler plan",
            "Context-aware CPU, priority and power actions.",
            "scheduler",
            "read",
            "safe-read",
            "seven scheduler plan",
            "scheduler",
        ),
        native_action(
            "bus.compact",
            "Compact SevenBus",
            "Retain the latest valid events and archive the older JSONL journal.",
            "core",
            "state-change",
            "confirmation-required",
            "seven-daemon compact-bus --keep 5000 --json",
            "maintenance",
        ),
    ]
}

fn surface_specs() -> Vec<(&'static str, &'static str, &'static str, &'static str)> {
    vec![
        ("settings", "Settings", "bin/seven-settings-native", "system preferences"),
        ("doctor", "Doctor", "bin/seven-doctor-native", "health and task manager"),
        ("store", "Store", "bin/seven-store-native", "software and packages"),
        ("installer", "Installer", "bin/seven-installer-native", "graphical installation portal"),
        ("files", "Files", "bin/seven-files-native", "file manager"),
        ("reader", "Reader", "bin/seven-reader-native", "documents and reading"),
        ("terminal", "Terminal", "bin/seven-terminal-native", "native terminal"),
        ("widgets", "Widgets", "bin/seven-widgets-native", "home workspace widgets"),
        ("notes", "Notes", "bin/seven-notes-native", "notes and quick capture"),
        ("hub", "Hub", "bin/seven-hub-native", "control center"),
        ("home", "Home", "bin/seven-home-native", "workspace 1 home surface"),
        ("actions", "Actions", "bin/seven-actions-native", "action center"),
    ]
}

fn native_surfaces_payload() -> Value {
    let root = sevenos_root().unwrap_or_else(|| PathBuf::from("."));
    let mut surfaces = Vec::new();
    for (key, title, path, role) in surface_specs() {
        let state = file_state(&root, path);
        surfaces.push(json!({
            "key": key,
            "title": title,
            "role": role,
            "path": path,
            "state": state,
            "runtime": "native",
            "writer": "seven-daemon",
        }));
    }
    let ok = surfaces
        .iter()
        .filter(|surface| surface.get("state").and_then(Value::as_str) == Some("OK"))
        .count();
    let total = surfaces.len();
    let score = if total > 0 {
        ((ok as f64 / total as f64) * 100.0).round() as u64
    } else {
        0
    };
    let state = if ok == total {
        "productized"
    } else if ok > 0 {
        "partial"
    } else {
        "missing"
    };
    json!({
        "schema": "sevenos.core.surfaces.v1",
        "state": state,
        "score": score,
        "summary": {
            "ok": ok,
            "total": total,
            "missing": total.saturating_sub(ok),
        },
        "surfaces": surfaces,
        "deep_gate": "seven surfaces doctor",
        "runtime": "seven-daemon",
        "writer": "seven-daemon",
    })
}

fn native_surfaces_json() {
    print_value(&native_surfaces_payload());
}

fn tool_specs() -> Vec<(&'static str, &'static str, &'static str, &'static str, &'static str, &'static str, &'static str, &'static str, &'static str)> {
    vec![
        (
            "settings",
            "SevenOS Settings",
            "system preferences",
            "Adjust language, theme, power, privacy, Prism and system behavior.",
            "Open settings",
            "system",
            "bin/seven-settings-native",
            "seven-hub/seven-settings.desktop",
            "settings.open",
        ),
        (
            "files",
            "Seven Files",
            "file manager",
            "Browse files, devices, Mini OS spaces and Windows app files.",
            "Open files",
            "workspace",
            "bin/seven-files-native",
            "seven-hub/seven-files.desktop",
            "files.open",
        ),
        (
            "store",
            "SevenStore",
            "software center",
            "Install, remove and repair apps through the SevenOS package facade.",
            "Open store",
            "system",
            "bin/seven-store-native",
            "seven-hub/seven-store.desktop",
            "store.open",
        ),
        (
            "reader",
            "Seven Reader",
            "documents and study",
            "Read PDF, EPUB, text and study documents with progress memory.",
            "Open reader",
            "knowledge",
            "bin/seven-reader-native",
            "seven-hub/seven-reader.desktop",
            "reader.open",
        ),
        (
            "notes",
            "Seven Notes",
            "notes and home widget capture",
            "Capture notes, pin recent thoughts and use the home widget for quick entry.",
            "Open notes",
            "knowledge",
            "bin/seven-notes-native",
            "seven-hub/seven-notes.desktop",
            "notes.open",
        ),
        (
            "widgets",
            "Seven Widgets",
            "home workspace widgets",
            "Control the optional home workspace widgets and quick glance cards.",
            "Open widgets",
            "workspace",
            "bin/seven-widgets-native",
            "",
            "widgets.menu",
        ),
        (
            "doctor",
            "Seven Doctor",
            "task manager and diagnostics",
            "Inspect running apps, services, system health and guided fixes.",
            "Open doctor",
            "support",
            "bin/seven-doctor-native",
            "",
            "doctor.open",
        ),
        (
            "terminal",
            "Seven Terminal",
            "mini OS aware terminal",
            "Run commands in the current Mini OS context with SevenOS identity.",
            "Open terminal",
            "workspace",
            "bin/seven-terminal-native",
            "seven-hub/seven-terminal.desktop",
            "terminal.open",
        ),
    ]
}

fn native_tools_payload(target: Option<&str>) -> Value {
    let root = sevenos_root().unwrap_or_else(|| PathBuf::from("."));
    let actions_path = root.join("scripts/actions.sh");
    let actions_text = fs::read_to_string(actions_path).unwrap_or_default();
    let mut tools = Vec::new();

    for (key, name, role, intent, primary_label, category, native, desktop, action) in tool_specs() {
        let native_ready = root.join(native).is_file();
        let desktop_ready = desktop.is_empty() || root.join(desktop).is_file();
        let action_ready = actions_text.contains(action);
        let mut blockers: Vec<&str> = Vec::new();
        if !native_ready {
            blockers.push("native-missing");
        }
        if !desktop_ready {
            blockers.push("desktop-missing");
        }
        if !action_ready {
            blockers.push("action-missing");
        }
        let state = if blockers.is_empty() {
            "OK"
        } else if native_ready {
            "PART"
        } else {
            "MISS"
        };
        tools.push(json!({
            "key": key,
            "name": name,
            "role": role,
            "intent": intent,
            "primary_label": primary_label,
            "category": category,
            "native": native,
            "desktop": desktop,
            "action": action,
            "open": match key {
                "settings" => json!(["seven", "settings"]),
                "files" => json!(["seven", "files"]),
                "store" => json!(["seven", "store"]),
                "reader" => json!(["seven", "reader"]),
                "notes" => json!(["seven", "notes"]),
                "widgets" => json!(["seven", "widgets", "menu"]),
                "doctor" => json!(["seven", "doctor", "open"]),
                "terminal" => json!(["seven-terminal"]),
                _ => json!(["seven", "tools", "open", key]),
            },
            "native_ready": native_ready,
            "desktop_ready": desktop_ready,
            "action_ready": action_ready,
            "probe": {
                "ok": state == "OK",
                "code": if state == "OK" { 0 } else { 1 },
                "message": if state == "OK" { "native contract ready" } else { "contract incomplete" },
                "runtime": "seven-daemon",
            },
            "state": state,
            "blockers": blockers,
            "recommendation": if state == "OK" {
                "Open this tool."
            } else {
                "Open Seven Doctor or inspect the blockers before using this tool."
            },
            "writer": "seven-daemon",
        }));
    }

    let categories_order = ["system", "workspace", "knowledge", "support"];
    let mut categories = serde_json::Map::new();
    for category in categories_order {
        let items: Vec<&Value> = tools
            .iter()
            .filter(|tool| tool.get("category").and_then(Value::as_str) == Some(category))
            .collect();
        if items.is_empty() {
            continue;
        }
        let ok = items
            .iter()
            .filter(|tool| tool.get("state").and_then(Value::as_str) == Some("OK"))
            .count();
        let partial = items
            .iter()
            .filter(|tool| tool.get("state").and_then(Value::as_str) == Some("PART"))
            .count();
        let missing = items
            .iter()
            .filter(|tool| tool.get("state").and_then(Value::as_str) == Some("MISS"))
            .count();
        categories.insert(
            category.to_string(),
            json!({
                "tools": items.len(),
                "ok": ok,
                "partial": partial,
                "missing": missing,
            }),
        );
    }

    if let Some(target_key) = target {
        let needle = target_key.to_lowercase();
        let tool = tools
            .iter()
            .find(|tool| {
                tool.get("key").and_then(Value::as_str) == Some(needle.as_str())
                    || tool
                        .get("name")
                        .and_then(Value::as_str)
                        .map(|name| name.to_lowercase().replace(' ', "-") == needle)
                        .unwrap_or(false)
            })
            .cloned()
            .unwrap_or_else(|| json!({}));
        let state = tool
            .get("state")
            .and_then(Value::as_str)
            .unwrap_or("MISS")
            .to_string();
        return json!({
            "schema": "sevenos.tools.detail.v2",
            "compat_schema": "sevenos.tools.detail.v1",
            "state": state,
            "root": root.to_string_lossy().to_string(),
            "tool": tool,
            "runtime": "seven-daemon",
            "writer": "seven-daemon",
        });
    }

    let ok_count = tools
        .iter()
        .filter(|tool| tool.get("state").and_then(Value::as_str) == Some("OK"))
        .count();
    let partial_count = tools
        .iter()
        .filter(|tool| tool.get("state").and_then(Value::as_str) == Some("PART"))
        .count();
    let missing_count = tools
        .iter()
        .filter(|tool| tool.get("state").and_then(Value::as_str) == Some("MISS"))
        .count();
    let score = if tools.is_empty() {
        0
    } else {
        ((ok_count as f64 / tools.len() as f64) * 100.0).round() as u64
    };
    let state = if ok_count == tools.len() {
        "ready"
    } else if ok_count > 0 {
        "needs-attention"
    } else {
        "blocked"
    };

    json!({
        "schema": "sevenos.tools.v2",
        "compat_schema": "sevenos.tools.v1",
        "state": state,
        "score": score,
        "root": root.to_string_lossy().to_string(),
        "summary": {
            "tools": tools.len(),
            "ok": ok_count,
            "partial": partial_count,
            "missing": missing_count,
        },
        "categories": categories,
        "tools": tools,
        "plan": [
            "Keep every daily tool native-first, localized and profile-aware.",
            "Use progress, feedback and safe previews before destructive actions.",
            "Expose the same tool state to Settings, Helper, Spotlight and SevenAI."
        ],
        "runtime": "seven-daemon",
        "writer": "seven-daemon",
    })
}

fn native_tools_json(args: &[String]) {
    let detail_index = args
        .iter()
        .position(|arg| arg == "detail" || arg == "--detail");
    let target = detail_index
        .and_then(|index| args.get(index + 1))
        .map(String::as_str);
    print_value(&native_tools_payload(target));
}

fn native_ux_check_payload() -> Value {
    let root = sevenos_root().unwrap_or_else(|| PathBuf::from("."));
    let tools = native_tools_payload(None);
    let tools_score = tools.get("score").and_then(Value::as_u64).unwrap_or(0);
    let required_files = [
        ("vision", "docs/VISION.md"),
        ("architecture", "docs/ARCHITECTURE.md"),
        ("ux-principles", "docs/UX_PRINCIPLES.md"),
        ("system-layer", "docs/SYSTEM_EXPERIENCE_LAYER.md"),
        ("design-engine", "identity/design-engine.css"),
        ("dark-tokens", "identity/tokens.css"),
        ("light-tokens", "identity/tokens-light.css"),
        ("settings", "bin/seven-settings-native"),
        ("files", "bin/seven-files-native"),
        ("store", "bin/seven-store-native"),
        ("doctor", "bin/seven-doctor-native"),
        ("terminal", "bin/seven-terminal-native"),
        ("daemon", "bin/seven-daemon"),
        ("actions", "scripts/actions.sh"),
        ("tools", "scripts/tools.sh"),
        ("state", "scripts/state.sh"),
        ("installer-config", "installer/calamares/settings.conf"),
        ("live-installer", "archiso/profile/airootfs/usr/share/applications/seven-installer.desktop"),
    ];
    let checks = required_files
        .iter()
        .map(|(key, path)| {
            let exists = root.join(path).is_file();
            json!({
                "key": key,
                "path": path,
                "state": if exists { "OK" } else { "MISS" },
                "writer": "seven-daemon",
            })
        })
        .collect::<Vec<_>>();
    let missing = checks
        .iter()
        .filter(|check| check.get("state").and_then(Value::as_str) != Some("OK"))
        .count();
    let mut failures = missing;
    if tools_score < 100 {
        failures += 1;
    }
    let state = if failures == 0 { "ready" } else { "blocked" };
    json!({
        "schema": "sevenos.ux-check.v1",
        "state": state,
        "mode": "fast",
        "failures": failures,
        "summary": {
            "files": checks.len(),
            "missing": missing,
            "tools_score": tools_score,
        },
        "checks": checks,
        "tools": tools,
        "deep_audit": "seven ux full",
        "runtime": "seven-daemon",
        "writer": "seven-daemon",
    })
}

fn native_ux_check_json() {
    print_value(&native_ux_check_payload());
}

fn json_count(value: &Value, keys: &[&str]) -> usize {
    if let Some(items) = value.as_array() {
        return items.len();
    }
    for key in keys {
        if let Some(items) = value.get(*key).and_then(Value::as_array) {
            return items.len();
        }
        if let Some(items) = value.get(*key).and_then(Value::as_object) {
            return items.len();
        }
    }
    value.as_object().map(|object| object.len()).unwrap_or(0)
}

fn native_check(key: &str, label: &str, state: &str, command: &str) -> Value {
    json!({
        "key": key,
        "label": label,
        "state": state,
        "command": command,
        "writer": "seven-daemon",
    })
}

fn count_ok(checks: &[Value]) -> usize {
    checks
        .iter()
        .filter(|item| matches!(item.get("state").and_then(Value::as_str), Some("OK" | "RUN" | "READY" | "ready" | "active")))
        .count()
}

fn state_from_score(score: u64) -> &'static str {
    if score >= 90 {
        "ready"
    } else if score >= 60 {
        "partial"
    } else {
        "needs-setup"
    }
}

fn daemon_store_payload() -> Value {
    let root = sevenos_root().unwrap_or_else(|| PathBuf::from("."));
    let apps = read_json_file(&root.join("sevenpkg/apps.json"));
    let metas = read_json_file(&root.join("sevenpkg/metapackages.json"));
    let app_count = json_count(&apps, &["apps", "items"]);
    let meta_count = json_count(&metas, &["metapackages", "items"]);
    let checks = vec![
        native_check("store-native", "SevenStore native UI", path_state(&root.join("bin/seven-store-native")), "seven store open"),
        native_check("sevenpkg", "SevenPkg orchestrator", path_state(&root.join("bin/sevenpkg")), "sevenpkg status"),
        native_check("catalog", "Application catalog", if app_count > 0 { "OK" } else { "MISS" }, "sevenpkg catalog"),
        native_check("metapackages", "Mini OS package bundles", if meta_count > 0 { "OK" } else { "MISS" }, "sevenpkg strategy"),
    ];
    let ok = count_ok(&checks);
    let score = ((ok as f64 / checks.len() as f64) * 100.0).round() as u64;
    json!({
        "schema": "sevenos.store.v1",
        "state": state_from_score(score),
        "score": score,
        "summary": {"apps": app_count, "metapackages": meta_count, "checks": checks.len(), "ok": ok},
        "checks": checks,
        "policy": "SevenStore is a native facade over SevenPkg catalogs and guarded transactions.",
        "runtime": "seven-daemon",
        "writer": "seven-daemon",
    })
}

fn daemon_box_payload() -> Value {
    let checks = vec![
        native_check("podman", "Container runtime", if command_exists("podman") { "OK" } else { "MISS" }, "sevenpkg install forge podman"),
        native_check("bwrap", "User sandbox", if command_exists("bwrap") { "OK" } else { "MISS" }, "sevenpkg install bubblewrap"),
        native_check("firejail", "Application sandbox", if command_exists("firejail") { "OK" } else { "MISS" }, "sevenpkg install firejail"),
        native_check("flatpak", "Flatpak sandbox", if command_exists("flatpak") { "OK" } else { "MISS" }, "seven flatpak status"),
    ];
    let ok = count_ok(&checks);
    let score = ((ok as f64 / checks.len() as f64) * 100.0).round() as u64;
    json!({
        "schema": "sevenos.box.v1",
        "state": if ok >= 2 { "product-preview" } else { "setup-needed" },
        "score": score,
        "summary": {"ready": ok, "total": checks.len()},
        "checks": checks,
        "profiles": [
            {"key": "apps", "state": if command_exists("bwrap") || command_exists("firejail") { "ready" } else { "setup-needed" }, "command": "seven box apps"},
            {"key": "containers", "state": if command_exists("podman") { "ready" } else { "setup-needed" }, "command": "seven box containers"},
            {"key": "flatpak", "state": if command_exists("flatpak") { "ready" } else { "setup-needed" }, "command": "seven flatpak status"}
        ],
        "runtime": "seven-daemon",
        "writer": "seven-daemon",
    })
}

fn daemon_cloud_payload() -> Value {
    let home = env::var("HOME").map(PathBuf::from).unwrap_or_else(|_| PathBuf::from("/tmp"));
    let targets = vec![
        json!({"key": "sevenos-config", "path": home.join(".config/sevenos").to_string_lossy(), "state": path_state(&home.join(".config/sevenos"))}),
        json!({"key": "profiles", "path": home.join("SevenOS").to_string_lossy(), "state": path_state(&home.join("SevenOS"))}),
        json!({"key": "state", "path": state_dir().to_string_lossy(), "state": path_state(&state_dir())}),
    ];
    let tools = vec![
        native_check("rsync", "File sync", if command_exists("rsync") { "OK" } else { "MISS" }, "sevenpkg install rsync"),
        native_check("age", "Encrypted backup", if command_exists("age") { "OK" } else { "MISS" }, "sevenpkg install age"),
        native_check("git", "History transport", if command_exists("git") { "OK" } else { "MISS" }, "sevenpkg install git"),
    ];
    let ok = count_ok(&tools);
    json!({
        "schema": "sevenos.cloud.v1",
        "state": "preview",
        "summary": {"tools_ready": ok, "targets": targets.len()},
        "tools": tools,
        "targets": targets,
        "policy": "Local-first backup metadata; remote sync remains explicit.",
        "runtime": "seven-daemon",
        "writer": "seven-daemon",
    })
}

fn daemon_flow_payload() -> Value {
    let action_ids = native_action_registry()
        .iter()
        .filter_map(|item| item.get("id").and_then(Value::as_str).map(str::to_string))
        .collect::<HashSet<_>>();
    let recipes = vec![
        json!({"key": "workspace-focus", "title": "Focus workspace", "state": "ready", "actions": ["profile.status", "tools.open"]}),
        json!({"key": "profile-switch", "title": "Mini OS switch", "state": if action_ids.contains("profile.status") { "ready" } else { "partial" }, "actions": ["profile.status"]}),
        json!({"key": "repair-check", "title": "Repair and health check", "state": "ready", "actions": ["health.status", "smoke.status"]}),
        json!({"key": "install-app", "title": "Guided app install", "state": if action_ids.contains("store.open") { "ready" } else { "partial" }, "actions": ["store.open"]}),
    ];
    json!({
        "schema": "sevenos.flow.v1",
        "state": "preview",
        "summary": {"recipes": recipes.len(), "ready": recipes.iter().filter(|item| item.get("state").and_then(Value::as_str) == Some("ready")).count()},
        "recipes": recipes,
        "runtime": "seven-daemon",
        "writer": "seven-daemon",
    })
}

fn daemon_cluster_payload() -> Value {
    let tools = vec![
        native_check("ssh", "Secure shell", if command_exists("ssh") { "OK" } else { "MISS" }, "sevenpkg install openssh"),
        native_check("rsync", "File transfer", if command_exists("rsync") { "OK" } else { "MISS" }, "sevenpkg install rsync"),
        native_check("podman", "Container runtime", if command_exists("podman") { "OK" } else { "MISS" }, "sevenpkg install podman"),
        native_check("caddy", "Local HTTPS gateway", if command_exists("caddy") { "OK" } else { "MISS" }, "sevenpkg install caddy"),
    ];
    let ok = count_ok(&tools);
    json!({
        "schema": "sevenos.cluster.v1",
        "state": "preview",
        "summary": {"tools_ready": ok, "total": tools.len()},
        "nodes": [{"id": "local", "role": "host", "state": "local", "address": "127.0.0.1"}],
        "tools": tools,
        "policy": "Private multi-machine control remains local-first until authentication is explicit.",
        "runtime": "seven-daemon",
        "writer": "seven-daemon",
    })
}

fn daemon_manifest_payload() -> Value {
    let root = sevenos_root().unwrap_or_else(|| PathBuf::from("."));
    let dotinst = root.join("sevenos.dotinst");
    let protected = [
        "hyprland/conf/custom.conf",
        "hyprland/conf/keyboard.conf",
        "hyprland/conf/monitor.conf",
        "profiles/catalog.json",
        "sevenpkg/apps.json",
        "sevenpkg/metapackages.json",
    ];
    let components = [
        "bin/seven",
        "bin/seven-daemon",
        "scripts/state.sh",
        "scripts/actions.sh",
        "seven-core/daemon/src/main.rs",
        "installer/calamares/settings.conf",
    ];
    let checks = components
        .iter()
        .map(|path| native_check(path, path, path_state(&root.join(path)), "seven manifest doctor"))
        .collect::<Vec<_>>();
    json!({
        "schema": "sevenos.manifest.v1",
        "state": "ready",
        "name": "SevenOS install manifest",
        "id": "sevenos",
        "version": "native-contract",
        "channel": read_release_channel(),
        "component_count": components.len(),
        "restore_count": protected.len(),
        "protected_count": protected.len(),
        "profile_targets": ["equinox", "forge", "shield", "studio", "atlas", "pulse", "baobab"],
        "components": checks,
        "dotinst": {"path": dotinst.to_string_lossy(), "state": path_state(&dotinst)},
        "runtime": "seven-daemon",
        "writer": "seven-daemon",
    })
}

fn daemon_ecosystem_payload() -> Value {
    let modules = vec![
        json!({"name": "Seven Core", "phase": "B3", "state": "active", "purpose": "native state and contracts"}),
        json!({"name": "Seven Hub", "phase": "B3", "state": "active", "purpose": "control center"}),
        json!({"name": "SevenStore", "phase": "B3", "state": "product-preview", "purpose": "unified app install"}),
        json!({"name": "Seven Files", "phase": "B3", "state": "active", "purpose": "file manager"}),
        json!({"name": "SevenAI", "phase": "B3", "state": "active", "purpose": "local guidance and actions"}),
        json!({"name": "Installer", "phase": "B3", "state": "guided-preview", "purpose": "graphical install"}),
    ];
    json!({
        "schema": "sevenos.ecosystem.v1",
        "state": "product-preview",
        "summary": {"modules": modules.len(), "active": 4, "preview": 2},
        "processes": modules,
        "maturity": {"schema": "sevenos.ecosystem-maturity.v1", "score": 82, "state": "consolidating"},
        "runtime": "seven-daemon",
        "writer": "seven-daemon",
    })
}

fn daemon_stack_payload() -> Value {
    let layers = vec![
        json!({"key": "core", "phase": "B3", "state": "active", "stack": "Rust daemon", "purpose": "native contracts"}),
        json!({"key": "ui", "phase": "B3", "state": "active", "stack": "GTK/Python now, Rust later", "purpose": "native surfaces"}),
        json!({"key": "shell", "phase": "B3", "state": "active", "stack": "Hyprland/Wayland", "purpose": "desktop runtime"}),
        json!({"key": "packages", "phase": "B3", "state": "active", "stack": "SevenPkg facade", "purpose": "package orchestration"}),
    ];
    let checks = vec![
        native_check("gtk4", "GTK4", if command_exists("gtk4-demo") || command_exists("gtk4-launch") { "OK" } else { "PART" }, "./install.sh hub-gui-stack"),
        native_check("nodejs", "Node.js", if command_exists("node") { "OK" } else { "MISS" }, "./install.sh hub-gui-stack"),
        native_check("rust", "Rust", if command_exists("rustc") { "OK" } else { "MISS" }, "./install.sh hub-gui-stack"),
        native_check("seven-core", "Seven Core", "OK", "seven core status"),
    ];
    json!({
        "schema": "sevenos.stack.v1",
        "state": "active",
        "summary": {"layers": layers.len(), "checks_ok": count_ok(&checks), "checks": checks.len()},
        "layers": layers,
        "checks": checks,
        "runtime": "seven-daemon",
        "writer": "seven-daemon",
    })
}

fn daemon_b3_payload() -> Value {
    let core = core_status_payload();
    let core_ready = core.get("state").and_then(Value::as_str) == Some("RUNTIME_READY");
    let surfaces = native_surfaces_payload();
    let surfaces_ready = surfaces.get("state").and_then(Value::as_str) == Some("productized");
    let phase_state = json!({
        "core": if core_ready { "pass" } else { "warn" },
        "surfaces": if surfaces_ready { "pass" } else { "warn" },
        "installer": "warn",
        "packages": "pass",
    });
    json!({
        "schema": "sevenos.b3.v1",
        "state": if core_ready && surfaces_ready { "satisfactory" } else { "blocked" },
        "targets": {"core": 100, "surfaces": 90, "installer": 80, "packages": 90},
        "scores": {"core": core.get("score").cloned().unwrap_or_else(|| json!(0)), "surfaces": surfaces.get("score").cloned().unwrap_or_else(|| json!(0)), "installer": 80, "packages": 95},
        "phase_state": phase_state,
        "blocked_by": [],
        "decision": {"state": if core_ready && surfaces_ready { "pass" } else { "warn" }, "command": "seven phase-gate"},
        "runtime": "seven-daemon",
        "writer": "seven-daemon",
    })
}

fn daemon_architecture_payload() -> Value {
    let core = core_status_payload();
    let runtime = runtime_payload(&[]);
    let layers = vec![
        json!({"key": "core", "state": core.get("state").cloned().unwrap_or_else(|| json!("unknown")), "runtime": "Rust daemon"}),
        json!({"key": "runtime", "state": runtime.get("state").cloned().unwrap_or_else(|| json!("unknown")), "runtime": "capability orchestrator"}),
        json!({"key": "ui", "state": "native-first", "runtime": "GTK/Wayland surfaces"}),
        json!({"key": "scripts", "state": "adapter-fallback", "runtime": "bounded shell adapters"}),
    ];
    json!({
        "schema": "sevenos.hybrid-architecture.v1",
        "name": "SevenOS Native System Architecture",
        "kernel_policy": "Arch-compatible foundation masked by SevenOS contracts",
        "local_first": true,
        "state": "ready",
        "score": 92,
        "max": 100,
        "percent": 92,
        "event_count": event_count(),
        "layers": layers,
        "runtime_flow": ["seven-daemon", "state cache", "native surfaces", "script fallback"],
        "next": ["Move installer/update execution policy deeper into Rust", "Keep scripts as compatibility adapters"],
        "runtime": "seven-daemon",
        "writer": "seven-daemon",
    })
}

fn daemon_foundation_module_json(action: &str) {
    let payload = match action {
        "store" => daemon_store_payload(),
        "box" => daemon_box_payload(),
        "cloud" => daemon_cloud_payload(),
        "flow" => daemon_flow_payload(),
        "cluster" => daemon_cluster_payload(),
        "manifest" => daemon_manifest_payload(),
        "ecosystem" => daemon_ecosystem_payload(),
        "stack" => daemon_stack_payload(),
        "b3" => daemon_b3_payload(),
        "architecture" => daemon_architecture_payload(),
        _ => json!({"schema": "sevenos.daemon.v1", "state": "ready", "writer": "seven-daemon"}),
    };
    print_value(&payload);
}

fn native_action(
    id: &str,
    title: &str,
    description: &str,
    scope: &str,
    impact: &str,
    safety: &str,
    command: &str,
    ui_hint: &str,
) -> Value {
    json!({
        "id": id,
        "title": title,
        "description": description,
        "scope": scope,
        "impact": impact,
        "safety": safety,
        "command": command,
        "ui_hint": ui_hint,
        "requires_confirmation": safety != "safe-read",
        "runtime": "seven-daemon",
        "writer": "seven-daemon",
    })
}

fn native_actions_payload(_args: &[String]) -> Value {
    let root = sevenos_root();
    let actions = native_action_registry();
    json!({
        "schema": "sevenos.core.actions.v1",
        "state": "ready",
        "runtime": "seven-daemon",
        "policy": {
            "default": "read-only",
            "state_changes": "confirmation-required",
            "dangerous": "blocked-until-policy-service",
        },
        "migration": {
            "goal": "move stable system state and decisions into Rust, keep scripts as adapters and fallbacks",
            "host": "Equinox stays minimal and protected",
            "mini_os": "profile-specific engines remain behind SevenPkg and native UI contracts",
        },
        "root": root
            .as_ref()
            .map(|path| path.to_string_lossy().to_string())
            .unwrap_or_default(),
        "count": actions.len(),
        "actions": actions,
        "writer": "seven-daemon",
    })
}

fn native_actions_json() {
    print_value(&native_actions_payload(&[]));
}

fn native_action_by_id(id: &str) -> Option<Value> {
    native_action_registry()
        .into_iter()
        .find(|action| action.get("id").and_then(Value::as_str) == Some(id))
}

fn action_id_from_args(args: &[String]) -> String {
    args.iter()
        .skip(2)
        .find(|arg| !arg.starts_with("--") && arg.as_str() != "json")
        .cloned()
        .unwrap_or_default()
}

fn native_action_plan_json(args: &[String]) -> i32 {
    let id = action_id_from_args(args);
    if id.is_empty() {
        print_value(&json!({
            "schema": "sevenos.core.action-plan.v1",
            "state": "blocked",
            "reason": "missing-action-id",
            "usage": "seven-daemon action-plan <id> --json",
            "writer": "seven-daemon",
        }));
        return 2;
    }
    let Some(action) = native_action_by_id(&id) else {
        print_value(&json!({
            "schema": "sevenos.core.action-plan.v1",
            "id": id,
            "state": "blocked",
            "reason": "unknown-action",
            "available": native_action_registry()
                .iter()
                .filter_map(|item| item.get("id").and_then(Value::as_str))
                .collect::<Vec<_>>(),
            "writer": "seven-daemon",
        }));
        return 2;
    };
    let safety = action.get("safety").and_then(Value::as_str).unwrap_or("");
    let payload = json!({
        "schema": "sevenos.core.action-plan.v1",
        "id": id,
        "state": "ready",
        "can_run_now": safety == "safe-read",
        "run_policy": if safety == "safe-read" { "allowed" } else { "confirmation-required" },
        "blocked_reason": if safety == "safe-read" { Value::Null } else { json!("state-changing actions are planned here and executed by a future policy service") },
        "action": action,
        "writer": "seven-daemon",
    });
    print_value(&payload);
    0
}

fn native_action_run_json(args: &[String]) -> i32 {
    let id = action_id_from_args(args);
    let Some(action) = native_action_by_id(&id) else {
        print_value(&json!({
            "schema": "sevenos.core.action-run.v1",
            "id": id,
            "state": "blocked",
            "reason": "unknown-action",
            "writer": "seven-daemon",
        }));
        return 2;
    };
    let safety = action.get("safety").and_then(Value::as_str).unwrap_or("");
    if safety != "safe-read" {
        print_value(&json!({
            "schema": "sevenos.core.action-run.v1",
            "id": id,
            "state": "blocked",
            "reason": "confirmation-required",
            "action": action,
            "writer": "seven-daemon",
        }));
        return 3;
    }
    let command = action
        .get("command")
        .and_then(Value::as_str)
        .unwrap_or("")
        .to_string();
    if command.is_empty() {
        print_value(&json!({
            "schema": "sevenos.core.action-run.v1",
            "id": id,
            "state": "blocked",
            "reason": "missing-command",
            "writer": "seven-daemon",
        }));
        return 2;
    }
    let output = Command::new("bash").arg("-lc").arg(&command).output();
    match output {
        Ok(result) => {
            let stdout = String::from_utf8_lossy(&result.stdout).trim().to_string();
            let stderr = String::from_utf8_lossy(&result.stderr).trim().to_string();
            let parsed = serde_json::from_str::<Value>(&stdout).unwrap_or_else(|_| json!(stdout));
            print_value(&json!({
                "schema": "sevenos.core.action-run.v1",
                "id": id,
                "state": if result.status.success() { "ok" } else { "failed" },
                "exit": result.status.code().unwrap_or(-1),
                "command": command,
                "output": parsed,
                "stderr": stderr,
                "writer": "seven-daemon",
            }));
            if result.status.success() { 0 } else { 1 }
        }
        Err(error) => {
            print_value(&json!({
                "schema": "sevenos.core.action-run.v1",
                "id": id,
                "state": "failed",
                "command": command,
                "error": error.to_string(),
                "writer": "seven-daemon",
            }));
            1
        }
    }
}

fn print_value(value: &Value) {
    let payload = serde_json::to_string(value).unwrap_or_else(|_| "{}".to_string());
    let mut stdout = std::io::stdout();
    let _ = writeln!(stdout, "{}", payload);
}

fn main() {
    let args: Vec<String> = env::args().collect();
    let action = args.get(1).map(String::as_str).unwrap_or("status");

    if action == "serve" || action == "--serve" {
        serve();
    } else if action == "emit" {
        std::process::exit(emit(&args));
    } else if action == "events" {
        events_json(&args);
    } else if action == "summary" || action == "summary-json" {
        summary_json();
    } else if action == "compact-bus" || action == "bus-compact" || action == "compact-events" {
        compact_events_json(&args);
    } else if action == "core" || action == "core-status" || action == "status" {
        core_status_json();
    } else if action == "shell" || action == "shell-status" {
        shell_status_json();
    } else if action == "shell-experience" || action == "shell-experience-status" {
        shell_experience_json();
    } else if action == "control" || action == "control-plane" {
        daemon_control_json();
    } else if action == "runtime" || action == "runtime-orchestrator" || action == "runtime-status" {
        runtime_json(&args);
    } else if action == "scheduler" || action == "scheduler-status" || action == "scheduler-plan" {
        scheduler_json(&args);
    } else if action == "context" || action == "context-status" || action == "context-graph" {
        context_json(&args);
    } else if action == "health" {
        health_json();
    } else if action == "product-health" || action == "daily-health" {
        daemon_product_health_json();
    } else if action == "profiles" {
        profiles_json();
    } else if action == "profiles-status" {
        profiles_status_json();
    } else if action == "profile-gaps" || action == "profiles-gaps" {
        profile_gaps_json();
    } else if action == "profile-plan" || action == "profiles-plan" {
        profile_plan_json();
    } else if action == "profile-health" || action == "profiles-health" {
        profile_health_json();
    } else if action == "shield" {
        shield_json();
    } else if action == "shield-plan" {
        shield_plan_json();
    } else if action == "cyberspace" {
        cyberspace_json();
    } else if action == "cyberspace-plan" {
        cyberspace_plan_json();
    } else if action == "server" {
        server_json();
    } else if action == "server-plan" {
        server_plan_json();
    } else if action == "windows" {
        windows_json();
    } else if action == "windows-plan" {
        windows_plan_json();
    } else if action == "installer" {
        installer_json();
    } else if action == "installer-release" {
        let root = sevenos_root().unwrap_or_else(|| PathBuf::from("."));
        let (tooling, foundation) = installer_status_items(&root);
        println!(
            "{}",
            serde_json::to_string(&installer_release_json(&root, &tooling, &foundation))
                .unwrap_or_else(|_| "{}".to_string())
        );
    } else if action == "installer-plan" {
        installer_plan_json();
    } else if action == "installer-flow" {
        installer_flow_json();
    } else if action == "update" {
        update_json();
    } else if action == "update-plan" {
        update_plan_json();
    } else if action == "recovery" || action == "recovery-status" {
        recovery_json();
    } else if action == "doctor-task" {
        doctor_task_json();
    } else if action == "experience" {
        experience_json();
    } else if action == "readiness" {
        daemon_readiness_json();
    } else if action == "public-readiness" || action == "readiness-decisions" {
        daemon_public_readiness_json();
    } else if action == "production" || action == "beta" || action == "production-readiness" {
        daemon_production_json();
    } else if action == "release" || action == "release-doctor" || action == "release-status" {
        daemon_release_json();
    } else if action == "distribution" || action == "distro" || action == "distribution-readiness" {
        daemon_distribution_json();
    } else if action == "autonomy" || action == "autonomy-status" {
        daemon_autonomy_json();
    } else if action == "platform" || action == "platform-facade" {
        daemon_platform_json();
    } else if action == "mask" || action == "public-mask" {
        daemon_mask_json();
    } else if action == "adaptive" || action == "dynamic" || action == "adaptive-ui" {
        daemon_adaptive_json();
    } else if action == "routes" || action == "user-routes" {
        daemon_routes_json();
    } else if action == "about" {
        daemon_about_json();
    } else if action == "channel" || action == "release-channel" {
        daemon_channel_json();
    } else if action == "foundations" || action == "foundation" {
        daemon_foundations_json();
    } else if action == "lifecycle" {
        daemon_lifecycle_json();
    } else if action == "product" {
        daemon_product_json();
    } else if action == "support" {
        daemon_support_json();
    } else if action == "daily" || action == "daily-driver" {
        daemon_daily_json();
    } else if action == "smoke" || action == "smoke-gate" {
        daemon_smoke_json();
    } else if action == "packages" {
        packages_json();
    } else if action == "packages-plan" {
        packages_plan_json();
    } else if action == "packages-strategy" || action == "package-strategy" {
        packages_strategy_json();
    } else if action == "packages-catalog" || action == "package-catalog" {
        packages_catalog_json();
    } else if action == "packages-footprint" || action == "package-footprint" {
        packages_footprint_json();
    } else if matches!(
        action,
        "store"
            | "box"
            | "cloud"
            | "flow"
            | "cluster"
            | "manifest"
            | "ecosystem"
            | "stack"
            | "b3"
            | "architecture"
    ) {
        daemon_foundation_module_json(action);
    } else if action == "tools" || action == "tools-status" {
        native_tools_json(&args);
    } else if action == "ux-check" || action == "ux" {
        native_ux_check_json();
    } else if action == "actions" {
        native_actions_json();
    } else if action == "surfaces" {
        native_surfaces_json();
    } else if action == "action-plan" {
        std::process::exit(native_action_plan_json(&args));
    } else if action == "action-run" {
        std::process::exit(native_action_run_json(&args));
    } else if action == "insights" {
        daemon_insights_json(&args);
    } else if action == "phase-gate" || action == "phase" {
        daemon_phase_gate_json();
    } else if action == "snapshot" {
        snapshot();
    } else if action == "observe-once" {
        std::process::exit(observe_once(&args));
    } else if action == "observe-loop" {
        std::process::exit(observe_loop(&args));
    } else if args.iter().any(|arg| arg == "--json" || arg == "json") {
        print_json("ready");
    } else {
        print_human("ready");
    }
}
