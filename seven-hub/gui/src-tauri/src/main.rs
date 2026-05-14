use std::process::Command;

#[tauri::command]
fn run_seven_command(command: String) -> Result<String, String> {
    let allowed_prefixes = [
        "seven architecture",
        "seven readiness",
        "seven profile",
        "seven shield",
        "seven windows",
        "seven server",
        "seven files",
        "seven repair ux",
    ];

    if !allowed_prefixes.iter().any(|prefix| command.starts_with(prefix)) {
        return Err("Command not allowed by Seven Hub".into());
    }

    let output = Command::new("sh")
        .arg("-lc")
        .arg(command)
        .output()
        .map_err(|error| error.to_string())?;

    let stdout = String::from_utf8_lossy(&output.stdout).trim().to_string();
    let stderr = String::from_utf8_lossy(&output.stderr).trim().to_string();

    if output.status.success() {
        Ok(if stdout.is_empty() { "Done".into() } else { stdout })
    } else {
        Err(if stderr.is_empty() { "Command failed".into() } else { stderr })
    }
}

fn main() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![run_seven_command])
        .run(tauri::generate_context!())
        .expect("error while running Seven Hub");
}
