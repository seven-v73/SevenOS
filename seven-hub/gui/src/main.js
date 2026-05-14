import "./styles.css";
import { invoke } from "@tauri-apps/api/core";

const fallbackSnapshot = {
  readiness: { score: 0, max: 0, percent: 0 },
  services: [
    { label: "Network", state: "MISS", detail: "Waiting for SevenOS backend" },
    { label: "Firewall", state: "MISS", detail: "Waiting for SevenOS backend" },
    { label: "Windows Mode", state: "MISS", detail: "Waiting for SevenOS backend" },
    { label: "Server", state: "MISS", detail: "Waiting for SevenOS backend" }
  ],
  profiles: [
    { key: "forge", title: "Forge", description: "Development workspace", state: "MISS", action: "seven profile install forge", active: false, workspace: "~/Forge" },
    { key: "shield", title: "Shield", description: "Cybersecurity workspace", state: "MISS", action: "seven profile install shield", active: false, workspace: "~/ShieldLab" },
    { key: "studio", title: "Studio", description: "Creative production workspace", state: "MISS", action: "seven profile install studio", active: false, workspace: "~/Studio" },
    { key: "windows", title: "Windows", description: "Compatibility layer", state: "MISS", action: "seven profile install windows", active: false, workspace: "~/WindowsMode" }
  ],
  recommendations: []
};

const actions = {
  security: [
    {
      title: "Security Audit",
      command: "seven shield audit",
      description: "Review firewall, sandbox and cyber tooling.",
      label: "Audit",
      impact: "safe"
    },
    {
      title: "Enable Shield",
      command: "seven shield enable",
      description: "Apply the base security profile.",
      label: "Enable",
      impact: "changes"
    },
    {
      title: "Repair Security",
      command: "seven repair security",
      description: "Generate a guided security repair plan.",
      label: "Repair",
      impact: "changes"
    },
    {
      title: "Cyber Lab",
      command: "seven shield lab --preset web",
      description: "Open an isolated web testing workspace.",
      label: "Open Lab",
      impact: "safe"
    }
  ],
  apps: [
    {
      title: "SevenPkg Status",
      command: "sevenpkg status",
      description: "View package groups and installation state.",
      label: "Inspect",
      impact: "safe"
    },
    {
      title: "Install Studio",
      command: "seven profile studio",
      description: "Install the creative workspace.",
      label: "Install",
      impact: "packages"
    },
    {
      title: "Flatpak Bridge",
      command: "seven flatpak status",
      description: "Check Flathub and Flatpak readiness.",
      label: "Check",
      impact: "safe"
    },
    {
      title: "Windows Apps",
      command: "seven windows status",
      description: "Check Wine, Bottles and VM readiness.",
      label: "Check",
      impact: "safe"
    }
  ],
  system: [
    {
      title: "Doctor",
      command: "seven doctor",
      description: "Check system health and post-install blockers.",
      label: "Check",
      impact: "safe"
    },
    {
      title: "Repair UX",
      command: "seven repair ux",
      description: "Review desktop and shell repair actions.",
      label: "Repair",
      impact: "changes"
    },
    {
      title: "Server Status",
      command: "seven server status",
      description: "Check the local SevenOS API service.",
      label: "Check",
      impact: "safe"
    },
    {
      title: "Installer Stack",
      command: "seven installer status",
      description: "Check Calamares and ISO foundations.",
      label: "Check",
      impact: "safe"
    }
  ]
};

const stateClass = {
  OK: "pill-green",
  PART: "pill-gold",
  MISS: "pill-clay",
  RUN: "pill-indigo"
};

const panels = document.querySelectorAll("[data-panel]");
const navItems = document.querySelectorAll(".nav-item");
const content = document.querySelector(".content");
const refresh = document.querySelector("#refresh");
const score = document.querySelector("#readiness-score");
const scoreDetail = document.querySelector("#readiness-detail");
const statusGrid = document.querySelector("#status-grid");
const profileGrid = document.querySelector("#profile-grid");
const recommendations = document.querySelector("#recommendations");
const output = document.querySelector("#output");
const outputTitle = document.querySelector("#output-title");
const outputDrawer = document.querySelector("#output-drawer");
const clearOutput = document.querySelector("#clear-output");
const confirmLayer = document.querySelector("#confirm-layer");
const confirmTitle = document.querySelector("#confirm-title");
const confirmCopy = document.querySelector("#confirm-copy");
const confirmCommand = document.querySelector("#confirm-command");
const confirmCancel = document.querySelector("#confirm-cancel");
const confirmRun = document.querySelector("#confirm-run");

let pendingAction = null;

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function pill(state) {
  const cls = stateClass[state] || "pill-indigo";
  return `<span class="pill ${cls}"><span class="pill-dot"></span>${escapeHtml(state)}</span>`;
}

function setPanel(name) {
  for (const panel of panels) {
    panel.classList.toggle("hidden", panel.dataset.panel !== name);
  }
  for (const item of navItems) {
    item.classList.toggle("active", item.dataset.section === name);
  }
  content.scrollTo({ top: 0, behavior: "smooth" });
}

function renderStatus(snapshot) {
  const readiness = snapshot.readiness || fallbackSnapshot.readiness;
  const percent = readiness.percent ?? 0;
  score.textContent = `${percent}%`;
  scoreDetail.textContent = `${readiness.score ?? 0}/${readiness.max ?? 0} checks passed`;

  statusGrid.innerHTML = (snapshot.services || fallbackSnapshot.services)
    .map((item) => `
      <article class="stat-card">
        <div>${pill(item.state)}</div>
        <h3>${escapeHtml(item.label)}</h3>
        <p>${escapeHtml(item.detail)}</p>
      </article>
    `)
    .join("");
}

function renderProfiles(snapshot) {
  profileGrid.innerHTML = (snapshot.profiles || fallbackSnapshot.profiles)
    .map((profile) => {
      const ready = profile.state === "OK";
      const command = ready ? `seven profile activate ${profile.key}` : profile.action;
      const label = profile.active ? "Active" : ready ? "Activate" : "Install";
      const impact = ready ? "changes" : "packages";
      return `
      <article class="profile-card${profile.active ? " active-profile" : ""}">
        <div class="profile-icon">${escapeHtml(profile.title.slice(0, 1))}</div>
        <div class="profile-body">
          <div class="profile-title">
            <h3>${escapeHtml(profile.title)}</h3>
            <div class="profile-pills">
              ${profile.active ? '<span class="pill pill-indigo"><span class="pill-dot"></span>ACTIVE</span>' : ""}
              ${pill(profile.state)}
            </div>
          </div>
          <p>${escapeHtml(profile.description)}</p>
          <span class="profile-workspace">${escapeHtml(profile.workspace || "Workspace not configured")}</span>
          <div class="profile-actions">
            <button class="btn-ghost" data-command="seven profile show ${escapeHtml(profile.key)}" data-label="Details" data-impact="safe" data-title="${escapeHtml(profile.title)}">Details</button>
            <button class="btn-ghost" data-command="${escapeHtml(command)}" data-label="${escapeHtml(label)}" data-impact="${escapeHtml(impact)}" data-title="${escapeHtml(profile.title)}" ${profile.active ? "disabled" : ""}>${escapeHtml(label)}</button>
          </div>
        </div>
      </article>
    `;
    })
    .join("");
}

function renderRecommendations(snapshot) {
  const items = snapshot.recommendations || [];
  if (!items.length) {
    recommendations.innerHTML = `
      <article class="recommendation-card">
        <span class="pill pill-green"><span class="pill-dot"></span>OK</span>
        <p>No urgent recommendation. Continue polishing the user experience.</p>
      </article>
    `;
    return;
  }

  recommendations.innerHTML = items.slice(0, 3)
    .map((item) => `
      <article class="recommendation-card">
        <span class="pill pill-gold"><span class="pill-dot"></span>FIX</span>
        <p>${escapeHtml(item.reason)}</p>
        <button class="btn-ghost compact" data-command="${escapeHtml(item.command)}" data-label="Fix" data-impact="changes" data-title="Recommended Fix">Fix</button>
      </article>
    `)
    .join("");
}

function renderActionGrid(id, list) {
  const target = document.querySelector(id);
  target.innerHTML = list
    .map((action) => `
      <article class="action-card" data-impact="${escapeHtml(action.impact)}">
        <span class="action-meta">${escapeHtml(action.impact)}</span>
        <h3>${escapeHtml(action.title)}</h3>
        <p>${escapeHtml(action.description)}</p>
        <button class="btn-ghost" data-command="${escapeHtml(action.command)}" data-label="${escapeHtml(action.label)}" data-impact="${escapeHtml(action.impact)}" data-title="${escapeHtml(action.title)}">${escapeHtml(action.label)}</button>
      </article>
    `)
    .join("");
}

function actionNeedsConfirmation(action) {
  if (action.impact === "safe") return false;
  return / install| enable| repair| update| profile| start| stop| setup| apply/.test(` ${action.command}`);
}

function setOutput(title, text, mode = "idle") {
  outputTitle.textContent = title;
  output.textContent = text;
  outputDrawer.dataset.mode = mode;
}

function summarizeResult(command, result) {
  const lines = String(result || "Done.")
    .split("\n")
    .map((line) => line.trimEnd())
    .filter(Boolean);

  const notes = lines.filter((line) => /\b(warn|fail|miss|error|partial)\b/i.test(line)).slice(0, 5);
  const preview = lines.slice(0, 16).join("\n");

  if (notes.length) {
    return `Completed with notes.\n\n${notes.join("\n")}\n\nFull output:\n${preview}`;
  }

  return `Completed successfully.\n\n${preview}`;
}

function actionFromButton(button) {
  return {
    command: button.dataset.command,
    label: button.dataset.label || button.textContent || "Run",
    impact: button.dataset.impact || "safe",
    title: button.dataset.title || button.textContent || "SevenOS Action",
    button
  };
}

function openConfirm(action) {
  pendingAction = action;
  confirmTitle.textContent = action.title;
  confirmCopy.textContent = action.impact === "packages"
    ? "This may install packages and change your current SevenOS profile."
    : "This may change your current SevenOS configuration.";
  confirmCommand.textContent = action.command;
  confirmRun.textContent = action.label;
  confirmLayer.classList.remove("hidden");
  confirmCancel.focus();
}

function closeConfirm() {
  confirmLayer.classList.add("hidden");
  pendingAction = null;
}

async function loadSnapshot() {
  refresh.disabled = true;
  refresh.textContent = "Refreshing";
  try {
    const data = await invoke("get_hub_snapshot");
    const snapshot = typeof data === "string" ? JSON.parse(data) : data;
    renderStatus(snapshot);
    renderProfiles(snapshot);
    renderRecommendations(snapshot);
  } catch (error) {
    renderStatus(fallbackSnapshot);
    renderProfiles(fallbackSnapshot);
    renderRecommendations({ recommendations: [{ command: "seven doctor", reason: `Hub snapshot unavailable: ${error}` }] });
  } finally {
    refresh.disabled = false;
    refresh.textContent = "Refresh";
  }
}

async function runCommand(action) {
  const { command, button, label } = action;
  button.disabled = true;
  button.textContent = "Working";
  setOutput(command, "Running action...", "running");
  try {
    const result = await invoke("run_seven_command", { command });
    setOutput(command, summarizeResult(command, result), "success");
    await loadSnapshot();
  } catch (error) {
    setOutput(command, `Action failed.\n\n${String(error)}`, "error");
  } finally {
    button.disabled = false;
    button.textContent = label;
  }
}

document.addEventListener("click", (event) => {
  const nav = event.target.closest(".nav-item");
  if (nav) {
    setPanel(nav.dataset.section);
    return;
  }

  const button = event.target.closest("button[data-command]");
  if (button) {
    const action = actionFromButton(button);
    if (actionNeedsConfirmation(action)) {
      openConfirm(action);
    } else {
      runCommand(action);
    }
  }
});

refresh.addEventListener("click", loadSnapshot);
clearOutput.addEventListener("click", () => {
  setOutput("Action Output", "Ready.");
});
confirmCancel.addEventListener("click", closeConfirm);
confirmRun.addEventListener("click", () => {
  if (!pendingAction) return;
  const action = pendingAction;
  closeConfirm();
  runCommand(action);
});
confirmLayer.addEventListener("click", (event) => {
  if (event.target === confirmLayer) closeConfirm();
});
document.addEventListener("keydown", (event) => {
  if (event.key === "Escape" && !confirmLayer.classList.contains("hidden")) {
    closeConfirm();
  }
});

renderActionGrid("#security-actions", actions.security);
renderActionGrid("#app-actions", actions.apps);
renderActionGrid("#system-actions", actions.system);
loadSnapshot();
