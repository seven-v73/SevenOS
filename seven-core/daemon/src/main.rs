use std::env;

fn print_json() {
    println!(
        "{{\"schema\":\"sevenos.daemon.v1\",\"state\":\"scaffold\",\"name\":\"seven-daemon\",\"language\":\"rust\",\"bus\":\"sevenos.bus.v1\",\"transport\":\"stdio-preview\",\"policy\":\"local-only\",\"next\":[\"supervise SevenBus events\",\"serve fast local status\",\"enforce action policy\"]}}"
    );
}

fn print_human() {
    println!("Seven Daemon");
    println!("============");
    println!("state: scaffold");
    println!("bus: sevenos.bus.v1");
    println!("transport: stdio-preview");
    println!("policy: local-only");
}

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.iter().any(|arg| arg == "--json" || arg == "json") {
        print_json();
    } else {
        print_human();
    }
}
