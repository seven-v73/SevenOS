use std::collections::HashSet;
use std::env;
use std::fs::{self, OpenOptions};
use std::io::Write;
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

fn path_state(path: &PathBuf) -> &'static str {
    if path.exists() {
        "OK"
    } else {
        "MISS"
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
        key: "baobab",
        title: "Baobab",
        description: "Roots workspace for SevenOS desktop, shell, theme and system foundation.",
        role: "Roots",
        accent: "baobab",
        principle: "stability and roots",
        story: "Keep the roots healthy: shell, identity, files, services and daily trust.",
        workspace: "SevenOS",
        package_files: &["scripts/packages-base.txt"],
        apps: &["seven hub", "seven files"],
    },
    ProfileSpec {
        key: "forge",
        title: "Forge",
        description: "Builder workspace for code, learning, containers, databases and deployment.",
        role: "Builder",
        accent: "gold",
        principle: "creation through skill",
        story: "Build useful things, learn openly and turn Linux into a daily craft space.",
        workspace: "Forge",
        package_files: &["scripts/packages-dev.txt"],
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
        title: "Studio",
        description: "Maker workspace for image, vector, video, audio and 3D production.",
        role: "Maker",
        accent: "clay",
        principle: "expressive production",
        story: "Make visual, audio and motion work without leaving an open creative environment.",
        workspace: "Studio",
        package_files: &["scripts/packages-creation.txt"],
        apps: &["gimp", "krita", "inkscape", "blender", "kdenlive"],
    },
    ProfileSpec {
        key: "windows",
        title: "Windows",
        description: "Bridge workspace for Wine, Bottles, Lutris and KVM Windows Mode.",
        role: "Bridge",
        accent: "baobab",
        principle: "compatibility without surrender",
        story: "Bridge Windows applications into SevenOS while keeping Linux as the home base.",
        workspace: "WindowsMode",
        package_files: &["scripts/packages-windows.txt"],
        apps: &["bottles", "lutris", "virt-manager"],
    },
    ProfileSpec {
        key: "horizon",
        title: "Horizon",
        description:
            "Navigator workspace for containers, reverse proxy, self-hosting and personal cloud.",
        role: "Navigator",
        accent: "indigo",
        principle: "deployment and reach",
        story: "Navigate from local project to service, server and personal cloud deployment.",
        workspace: "HorizonDeploy",
        package_files: &["scripts/packages-server.txt"],
        apps: &["kitty", "podman", "caddy"],
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

fn snapshot() {
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

    let payload = json!({
        "schema": "sevenos.daemon.snapshot.v1",
        "state": "ready",
        "event_file": event_file().to_string_lossy(),
        "event_count": events.len(),
        "invalid_event_count": invalid,
        "sources": serde_json::from_str::<Value>(&json_counts(&by_source)).unwrap_or_else(|_| json!({})),
        "states": serde_json::from_str::<Value>(&json_counts(&by_state)).unwrap_or_else(|_| json!({})),
        "writers": serde_json::from_str::<Value>(&json_counts(&by_writer)).unwrap_or_else(|_| json!({})),
        "last_event": events.last(),
    });
    println!(
        "{}",
        serde_json::to_string(&payload).unwrap_or_else(|_| "{}".to_string())
    );
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

fn health_json() {
    let state_path = state_dir();
    let events_path = event_file();
    let state_writable = can_write_state_dir();
    let wayland_display = env::var("WAYLAND_DISPLAY").unwrap_or_default();
    let desktop = env::var("XDG_CURRENT_DESKTOP").unwrap_or_default();
    let session = env::var("XDG_SESSION_DESKTOP").unwrap_or_default();
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

    let payload = json!({
        "schema": "sevenos.daemon.health.v1",
        "state": if state_writable { "ready" } else { "degraded" },
        "name": "seven-daemon",
        "language": "rust",
        "policy": "local-only",
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
    });
    println!(
        "{}",
        serde_json::to_string(&payload).unwrap_or_else(|_| "{}".to_string())
    );
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
    let path = config_dir().join("profile.env");
    let content = fs::read_to_string(path).unwrap_or_default();
    for line in content.lines() {
        if let Some(raw) = line.strip_prefix("SEVENOS_ACTIVE_PROFILE=") {
            return raw.trim_matches('"').trim_matches('\'').to_string();
        }
    }
    "baobab".to_string()
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
            "/insights"
        ],
        "recommendations": server_recommendations(service, &dependencies),
        "runtime": "seven-daemon",
        "writer": "seven-daemon",
    });
    println!(
        "{}",
        serde_json::to_string(&payload).unwrap_or_else(|_| "{}".to_string())
    );
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
            if command_exists("calamares") {
                "OK"
            } else {
                "MISS"
            },
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
            "command": "seven installer plan",
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
            "state": file_contains_state(root, "installer/calamares/modules/sevenos.conf", "/opt/SevenOS/install.sh base"),
            "required": true,
            "title": "SevenOS base install hook",
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
        + (optional_ready as f64 * 15.0))
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
        "checks": checks,
        "portal": "seven-installer status --json",
        "runtime": "seven-daemon",
        "writer": "seven-daemon",
    })
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
    let payload = json!({
        "schema": "sevenos.installer.v1",
        "tooling": tooling,
        "foundation": foundation,
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
                first_action_command(&package_actions, "sevenpkg plan"),
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

fn daemon_phase_gate_json() {
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
    let profile_percent = if profiles.is_empty() {
        0
    } else {
        (((profiles.len().saturating_sub(profile_open)) as f64 / profiles.len() as f64) * 100.0)
            .round() as u64
    };

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

    let core_state = if root.join("seven-core/daemon/Cargo.toml").is_file()
        && root.join("bin/seven-daemon").is_file()
        && root.join("seven-core/bus-schema.json").is_file()
    {
        "READY_FOR_DAEMON"
    } else {
        "MISS"
    };

    let software_percent = if package_open == 0 {
        100
    } else {
        100u64
            .saturating_sub((package_open as u64).saturating_mul(10))
            .max(30)
    };
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
            if profile_open == 0 { "PASS" } else { "WARN" },
            json!(profile_open),
            json!(0),
            if profile_open == 0 { "strong" } else { "open" },
            "seven profile plan",
            "Profiles must keep moving from decorative modes to complete workspaces.",
        ),
        phase_gate_item(
            "software",
            "Software plan",
            if package_blocking == 0 { "PASS" } else { "WARN" },
            json!(package_blocking),
            json!(0),
            if package_blocking == 0 { "strong" } else { "open" },
            "sevenpkg plan",
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
            if core_state == "READY_FOR_DAEMON" {
                "PASS"
            } else {
                "WARN"
            },
            json!(core_state),
            json!("FOUNDATION"),
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

    let payload = json!({
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
    });
    println!(
        "{}",
        serde_json::to_string(&payload).unwrap_or_else(|_| "{}".to_string())
    );
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

fn profiles_json() {
    let root = sevenos_root().unwrap_or_else(|| PathBuf::from("."));
    let packages = pacman_packages();
    let active = active_profile_key();
    let profiles: Vec<Value> = PROFILES
        .iter()
        .map(|spec| profile_payload(&root, &packages, &active, spec))
        .collect();
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
    } else if action == "health" {
        health_json();
    } else if action == "profiles" {
        profiles_json();
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
    } else if action == "packages" {
        packages_json();
    } else if action == "packages-plan" {
        packages_plan_json();
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
