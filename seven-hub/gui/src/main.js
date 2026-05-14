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
    { key: "forge", title: "Forge", description: "Development workspace", state: "MISS", action: "seven profile forge" },
    { key: "shield", title: "Shield", description: "Cybersecurity workspace", state: "MISS", action: "seven profile shield" },
    { key: "studio", title: "Studio", description: "Creative production workspace", state: "MISS", action: "seven profile studio" },
    { key: "windows", title: "Windows", description: "Compatibility layer", state: "MISS", action: "seven windows status" }
  ],
  recommendations: []
};

const actions = {
  security: [
    ["Security Audit", "seven shield audit", "Review firewall, sandbox and cyber tooling."],
    ["Enable Shield", "seven shield enable", "Apply the base security profile."],
    ["Repair Security", "seven repair security", "Generate a guided security repair plan."],
    ["Cyber Lab", "seven shield lab --preset web", "Open an isolated web testing workspace."]
  ],
  apps: [
    ["SevenPkg Status", "sevenpkg status", "View package groups and installation state."],
    ["Install Studio", "seven profile studio", "Install the creative workspace."],
    ["Flatpak Bridge", "seven flatpak status", "Check Flathub and Flatpak readiness."],
    ["Windows Apps", "seven windows status", "Check Wine, Bottles and VM readiness."]
  ],
  system: [
    ["Doctor", "seven doctor", "Check system health and post-install blockers."],
    ["Repair UX", "seven repair ux", "Review desktop and shell repair actions."],
    ["Server Status", "seven server status", "Check the local SevenOS API service."],
    ["Installer Stack", "seven installer status", "Check Calamares and ISO foundations."]
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
const refresh = document.querySelector("#refresh");
const score = document.querySelector("#readiness-score");
const scoreDetail = document.querySelector("#readiness-detail");
const statusGrid = document.querySelector("#status-grid");
const profileGrid = document.querySelector("#profile-grid");
const recommendations = document.querySelector("#recommendations");
const output = document.querySelector("#output");
const outputTitle = document.querySelector("#output-title");
const clearOutput = document.querySelector("#clear-output");

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
    .map((profile) => `
      <article class="profile-card">
        <div class="profile-icon">${escapeHtml(profile.title.slice(0, 1))}</div>
        <div class="profile-body">
          <div class="profile-title">
            <h3>${escapeHtml(profile.title)}</h3>
            ${pill(profile.state)}
          </div>
          <p>${escapeHtml(profile.description)}</p>
          <button class="btn-ghost" data-command="${escapeHtml(profile.action)}">Open</button>
        </div>
      </article>
    `)
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
        <button class="btn-ghost compact" data-command="${escapeHtml(item.command)}">Run</button>
      </article>
    `)
    .join("");
}

function renderActionGrid(id, list) {
  const target = document.querySelector(id);
  target.innerHTML = list
    .map(([title, command, description]) => `
      <article class="action-card">
        <h3>${escapeHtml(title)}</h3>
        <p>${escapeHtml(description)}</p>
        <button class="btn-ghost" data-command="${escapeHtml(command)}">Run</button>
      </article>
    `)
    .join("");
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

async function runCommand(command, button) {
  button.disabled = true;
  button.textContent = "Running";
  outputTitle.textContent = command;
  output.textContent = "Running...";
  try {
    const result = await invoke("run_seven_command", { command });
    output.textContent = result || "Done.";
    await loadSnapshot();
  } catch (error) {
    output.textContent = String(error);
  } finally {
    button.disabled = false;
    button.textContent = button.dataset.originalLabel || "Run";
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
    button.dataset.originalLabel ||= button.textContent;
    runCommand(button.dataset.command, button);
  }
});

refresh.addEventListener("click", loadSnapshot);
clearOutput.addEventListener("click", () => {
  outputTitle.textContent = "Action Output";
  output.textContent = "Ready.";
});

renderActionGrid("#security-actions", actions.security);
renderActionGrid("#app-actions", actions.apps);
renderActionGrid("#system-actions", actions.system);
loadSnapshot();
