# SevenOS Interaction Contract

SevenOS public surfaces must feel like one operating system, not a set of
scripts. This contract defines the shared rules used by Settings, Files, Store,
Terminal, Prism, Control Center, Experience Center and Mini OS switch surfaces.

## Principles

- **Calm first**: actions explain impact before changing state.
- **One-window flow**: common tasks stay in the current surface through panels,
  sheets or overlays instead of launching raw terminals or config files.
- **Visible result**: every important click has feedback, progress and a final
  state.
- **Prism identity**: profile, motion and status use the same Prism language
  everywhere.
- **Accessible by default**: keyboard focus, readable contrast, labels, reduced
  motion and localized copy are release gates.
- **Details on demand**: logs and commands are available, but hidden behind
  "details" for public workflows.

## Interaction Rules

1. Primary buttons perform the safest recommended action.
2. Secondary buttons are calm alternatives, never hidden destructive actions.
3. Destructive actions require a confirmation with human impact text.
4. Long operations show progress, allow details, and never close the parent page
   unexpectedly.
5. Public workflows must not expose raw shell output unless the user opens
   details.
6. Mini OS changes use the Prism passage overlay and finish only after the target
   profile is ready.
7. Theme, language and motion changes update all public surfaces or report which
   surface still needs reload.

## Motion Rules

- Use SevenOS motion presets: `premium`, `balanced`, `reduced`, `latency`, `off`.
- Respect `reduced` and `off` globally.
- Prism motion can be alive, but it must not block pointer or keyboard work.
- Transition duration should hide loading, not pretend work is done.

## Accessibility Rules

- Every icon-only control needs a tooltip or accessible label.
- Keyboard focus must be visible in light and dark themes.
- Focus styles must use SevenOS tokens and remain visible without relying on
  color alone.
- Text must use SevenOS theme tokens, not hard-coded black or white.
- Windows must fit common laptop displays and allow scrolling when content grows.
- FR/EN copy must be available for public controls.

## Public Quality Command

```bash
seven quality mode public
seven accessibility-gate
seven interaction-gate
```

These commands validate the contract before public release work.
