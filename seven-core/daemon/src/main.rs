use std::env;
use std::fs::{self, OpenOptions};
use std::io::Write;
use std::path::PathBuf;
use std::thread;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

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

fn unix_timestamp() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_else(|_| Duration::from_secs(0))
        .as_secs()
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

fn serve() {
    let dir = state_dir();
    if let Err(error) = fs::create_dir_all(&dir) {
        eprintln!("seven-daemon: failed to create state dir {}: {}", dir.display(), error);
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
        eprintln!("seven-daemon emit: failed to create {}: {}", dir.display(), error);
        return 1;
    }

    let command_json = if command.is_empty() {
        "null".to_string()
    } else {
        format!("\"{}\"", json_escape(&command))
    };

    let payload = format!(
        "{{\"schema\":\"sevenos.event.v1\",\"timestamp\":\"unix:{}\",\"timestamp_unix\":{},\"source\":\"{}\",\"type\":\"{}\",\"state\":\"{}\",\"message\":\"{}\",\"command\":{},\"writer\":\"seven-daemon\"}}\n",
        unix_timestamp(),
        unix_timestamp(),
        json_escape(&source),
        json_escape(&event_type),
        json_escape(&state),
        json_escape(&message),
        command_json
    );

    let path = event_file();
    match OpenOptions::new().create(true).append(true).open(&path) {
        Ok(mut file) => {
            if let Err(error) = file.write_all(payload.as_bytes()) {
                eprintln!("seven-daemon emit: failed to write {}: {}", path.display(), error);
                return 1;
            }
        }
        Err(error) => {
            eprintln!("seven-daemon emit: failed to open {}: {}", path.display(), error);
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
    } else if args.iter().any(|arg| arg == "--json" || arg == "json") {
        print_json("ready");
    } else {
        print_human("ready");
    }
}
