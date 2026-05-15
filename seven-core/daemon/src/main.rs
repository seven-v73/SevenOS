use std::env;
use std::fs::{self, OpenOptions};
use std::io::Write;
use std::path::PathBuf;
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

fn event_file() -> PathBuf {
    state_dir().join("events.jsonl")
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

fn emit(args: &[String]) -> i32 {
    let source = arg_value(args, "--source", "core");
    let event_type = arg_value(args, "--type", "event");
    let state = arg_value(args, "--state", "OK");
    let message = arg_value(args, "--message", "");
    let command = arg_value(args, "--command", "");

    if message.is_empty() {
        eprintln!("seven-daemon emit: --message is required");
        return 2;
    }

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
    } else if action == "snapshot" {
        snapshot();
    } else if args.iter().any(|arg| arg == "--json" || arg == "json") {
        print_json("ready");
    } else {
        print_human("ready");
    }
}
