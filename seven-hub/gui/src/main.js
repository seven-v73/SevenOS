import "./styles.css";
import { invoke } from "@tauri-apps/api/core";

const cards = document.querySelector("#cards");
const refresh = document.querySelector("#refresh");

const actions = [
  ["Architecture", "seven architecture doctor"],
  ["Readiness", "seven readiness"],
  ["Profiles", "seven profile status"],
  ["Security", "seven shield audit"],
  ["Windows", "seven windows status"],
  ["Server", "seven server status"],
  ["Files", "seven files"],
  ["Repair UX", "seven repair ux --apply"]
];

function render(items) {
  cards.innerHTML = "";
  for (const [title, command, output = "Ready"] of items) {
    const card = document.createElement("article");
    card.className = "card";
    card.innerHTML = `
      <h2>${title}</h2>
      <p>${output}</p>
      <button data-command="${command}">Run</button>
    `;
    cards.appendChild(card);
  }
}

cards.addEventListener("click", async (event) => {
  const button = event.target.closest("button[data-command]");
  if (!button) return;
  button.disabled = true;
  button.textContent = "Running";
  const output = await invoke("run_seven_command", { command: button.dataset.command });
  button.closest(".card").querySelector("p").textContent = output || "Done";
  button.disabled = false;
  button.textContent = "Run";
});

refresh.addEventListener("click", () => render(actions));
render(actions);
