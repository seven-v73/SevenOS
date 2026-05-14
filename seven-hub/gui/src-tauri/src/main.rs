use serde::Serialize;
use std::path::PathBuf;
use std::process::Command;

#[derive(Serialize)]
struct Readiness {
    score: u64,
    max: u64,
    percent: u64,
}

#[derive(Serialize)]
struct ServiceCard {
    label: String,
    state: String,
    detail: String,
}

#[derive(Serialize)]
struct ProfileCard {
    key: String,
    title: String,
    description: String,
    state: String,
    action: String,
}

#[derive(Serialize)]
struct Recommendation {
    command: String,
    reason: String,
}

#[derive(Serialize)]
struct HubSnapshot {
    readiness: Readiness,
    services: Vec<ServiceCard>,
    profiles: Vec<ProfileCard>,
    recommendations: Vec<Recommendation>,
}

fn root_dir() -> PathBuf {
    if let Ok(root) = std::env::var("SEVENOS_ROOT") {
        let path = PathBuf::from(root);
        if path.join("install.sh").is_file() {
            return path;
        }
    }

    let home = std::env::var("HOME").unwrap_or_default();
    let home_code = format!("{home}/Code/OS/SevenOS");
    let home_repo = format!("{home}/SevenOS");

    for candidate in ["/opt/SevenOS".to_string(), home_code, home_repo] {
        let path = PathBuf::from(candidate);
        if path.join("install.sh").is_file() {
            return path;
        }
    }

    std::env::current_dir().unwrap_or_else(|_| PathBuf::from("."))
}

fn run_shell(command: &str) -> Result<String, String> {
    let output = Command::new("sh")
        .arg("-lc")
        .arg(command)
        .env("SEVENOS_ROOT", root_dir())
        .output()
        .map_err(|error| error.to_string())?;

    let stdout = String::from_utf8_lossy(&output.stdout).trim().to_string();
    let stderr = String::from_utf8_lossy(&output.stderr).trim().to_string();

    if output.status.success() {
        Ok(if stdout.is_empty() {
            "Done".into()
        } else {
            stdout
        })
    } else {
        Err(if stderr.is_empty() {
            "Command failed".into()
        } else {
            stderr
        })
    }
}

fn command_ok(command: &str) -> bool {
    Command::new("sh")
        .arg("-lc")
        .arg(command)
        .env("SEVENOS_ROOT", root_dir())
        .status()
        .map(|status| status.success())
        .unwrap_or(false)
}

fn profile_state(package_file: &str) -> String {
    let root = root_dir();
    let path = root.join(package_file);
    let script = format!(
        r#"
installed=0
total=0
while IFS= read -r package; do
  package="${{package%%#*}}"
  package="$(printf '%s' "$package" | tr -d '[:space:]')"
  [ -z "$package" ] && continue
  total=$((total + 1))
  pacman -Q "$package" >/dev/null 2>&1 && installed=$((installed + 1))
done < '{}'
if [ "$total" -eq 0 ]; then
  printf MISS
elif [ "$installed" -eq "$total" ]; then
  printf OK
elif [ "$installed" -gt 0 ]; then
  printf PART
else
  printf MISS
fi
"#,
        path.display()
    );
    run_shell(&script).unwrap_or_else(|_| "MISS".into())
}

fn profile_cards_from_sevenpkg() -> Option<Vec<ProfileCard>> {
    let output = run_shell("sevenpkg status --json").ok()?;
    let items: serde_json::Value = serde_json::from_str(&output).ok()?;
    let array = items.as_array()?;

    let wanted = [
        ("forge", "Forge", "seven profile forge"),
        ("shield", "Shield", "seven profile shield"),
        ("studio", "Studio", "seven profile studio"),
        ("windows", "Windows", "seven windows status"),
    ];

    let mut cards = Vec::new();
    for (key, title, action) in wanted {
        if let Some(item) = array
            .iter()
            .find(|entry| entry.get("name").and_then(|value| value.as_str()) == Some(key))
        {
            cards.push(ProfileCard {
                key: key.into(),
                title: title.into(),
                description: item
                    .get("description")
                    .and_then(|value| value.as_str())
                    .unwrap_or("")
                    .to_string(),
                state: item
                    .get("state")
                    .and_then(|value| value.as_str())
                    .unwrap_or("MISS")
                    .to_string(),
                action: action.into(),
            });
        }
    }

    if cards.is_empty() {
        None
    } else {
        Some(cards)
    }
}

fn readiness_snapshot() -> (Readiness, Vec<Recommendation>) {
    let command = format!("{}/scripts/readiness.sh --json", root_dir().display());
    let output = run_shell(&command).unwrap_or_else(|_| "{}".into());
    let value: serde_json::Value = serde_json::from_str(&output).unwrap_or_default();

    let readiness = Readiness {
        score: value.get("score").and_then(|v| v.as_u64()).unwrap_or(0),
        max: value.get("max").and_then(|v| v.as_u64()).unwrap_or(0),
        percent: value.get("percent").and_then(|v| v.as_u64()).unwrap_or(0),
    };

    let recommendations = value
        .get("recommendations")
        .and_then(|v| v.as_array())
        .map(|items| {
            items
                .iter()
                .filter_map(|item| {
                    Some(Recommendation {
                        command: item.get("command")?.as_str()?.to_string(),
                        reason: item.get("reason")?.as_str()?.to_string(),
                    })
                })
                .collect()
        })
        .unwrap_or_default();

    (readiness, recommendations)
}

#[tauri::command]
fn get_hub_snapshot() -> Result<String, String> {
    let (readiness, recommendations) = readiness_snapshot();

    let services = vec![
        ServiceCard {
            label: "Network".into(),
            state: if command_ok("systemctl is-active --quiet NetworkManager") {
                "OK"
            } else {
                "MISS"
            }
            .into(),
            detail: "NetworkManager desktop connectivity".into(),
        },
        ServiceCard {
            label: "Firewall".into(),
            state: if command_ok("systemctl is-active --quiet ufw") {
                "OK"
            } else {
                "PART"
            }
            .into(),
            detail: "UFW trust baseline".into(),
        },
        ServiceCard {
            label: "Windows Mode".into(),
            state: if command_ok(
                "command -v virt-manager >/dev/null 2>&1 && command -v virsh >/dev/null 2>&1",
            ) {
                "OK"
            } else {
                "PART"
            }
            .into(),
            detail: "Wine, Bottles, QEMU and libvirt path".into(),
        },
        ServiceCard {
            label: "Seven Server".into(),
            state: if command_ok("systemctl --user is-active --quiet seven-server.service") {
                "OK"
            } else {
                "PART"
            }
            .into(),
            detail: "Local API and deployment foundation".into(),
        },
    ];

    let profiles = profile_cards_from_sevenpkg().unwrap_or_else(|| {
        vec![
            ProfileCard {
                key: "forge".into(),
                title: "Forge".into(),
                description: "Development workspace for Git, containers, Node, Python and Rust."
                    .into(),
                state: profile_state("scripts/packages-dev.txt"),
                action: "seven profile forge".into(),
            },
            ProfileCard {
                key: "shield".into(),
                title: "Shield".into(),
                description: "Cybersecurity workspace with audit, sandbox and lab tooling.".into(),
                state: profile_state("scripts/packages-cybersecurity.txt"),
                action: "seven profile shield".into(),
            },
            ProfileCard {
                key: "studio".into(),
                title: "Studio".into(),
                description: "Creative production workspace for image, vector, video and 3D tools."
                    .into(),
                state: profile_state("scripts/packages-creation.txt"),
                action: "seven profile studio".into(),
            },
            ProfileCard {
                key: "windows".into(),
                title: "Windows".into(),
                description: "Compatibility layer with Wine, Bottles, Lutris and KVM helpers."
                    .into(),
                state: profile_state("scripts/packages-windows.txt"),
                action: "seven windows status".into(),
            },
        ]
    });

    let snapshot = HubSnapshot {
        readiness,
        services,
        profiles,
        recommendations,
    };

    serde_json::to_string(&snapshot).map_err(|error| error.to_string())
}

#[tauri::command]
fn run_seven_command(command: String) -> Result<String, String> {
    let allowed_prefixes = [
        "seven architecture",
        "seven readiness",
        "seven status",
        "seven profile",
        "seven shield",
        "seven windows",
        "seven server",
        "seven installer",
        "seven flatpak",
        "seven files",
        "seven doctor",
        "seven repair",
        "sevenpkg",
    ];

    if !allowed_prefixes
        .iter()
        .any(|prefix| command.starts_with(prefix))
    {
        return Err("Command not allowed by Seven Hub".into());
    }

    run_shell(&command)
}

fn main() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![
            get_hub_snapshot,
            run_seven_command
        ])
        .run(tauri::generate_context!())
        .expect("error while running Seven Hub");
}
