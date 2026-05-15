export type SevenState = {
  schema: "sevenos.state.v1";
  active_profile?: SevenProfile;
  actions?: SevenActions;
  shell?: SevenShellStatus;
};

export type SevenProfile = {
  key?: string;
  title?: string;
  workspace?: string;
};

export type SevenAction = {
  id: string;
  category: string;
  title: string;
  command: string;
  impact: "safe" | "changes" | "packages" | string;
  description: string;
};

export type SevenActions = {
  schema: "sevenos.actions.v1";
  actions: SevenAction[];
};

export type SevenShellStatus = {
  schema: "sevenos.shell.v1";
  phase: "B3";
  state: "READY" | "FOUNDATION" | "PLANNED" | string;
  strategy: string;
  fallback: string;
  surfaces: SevenShellSurface[];
};

export type SevenShellSurface = {
  key: "quick-settings" | "notifications" | "launcher" | "dock" | string;
  state: "OK" | "MISS" | string;
  current: string;
  target: string;
};

export type ShellTile = {
  icon: string;
  title: string;
  subtitle: string;
  actionId: string;
};
