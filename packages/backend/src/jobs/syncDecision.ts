// The pure decision core of the shadow-copy 3-way diff, isolated from all I/O
// so it can be unit tested without live Sheets/DB access. See the sync
// algorithm section of the plan for the full table this implements.

import { createHash } from "node:crypto";

export type SyncAction = "noop" | "push" | "pull" | "converge" | "conflict";

/** local/sheet/base are content hashes of the same row, taken at each side and
 * at the last successful sync (the "common ancestor"). Only called once both
 * sides already have a mapping (a base hash exists) — brand-new rows on
 * either side are handled separately by the orchestrator as create/append. */
export function decideSyncAction(local: string, sheet: string, base: string): SyncAction {
  const localChanged = local !== base;
  const sheetChanged = sheet !== base;

  if (!localChanged && !sheetChanged) return "noop";
  if (localChanged && !sheetChanged) return "push";
  if (!localChanged && sheetChanged) return "pull";
  return local === sheet ? "converge" : "conflict";
}

/** Canonical, order-independent hash of a row's editable fields. */
export function hashRowFields(fields: Record<string, string>): string {
  const sortedKeys = Object.keys(fields).sort();
  const canonical = sortedKeys.map((k) => `${k}=${fields[k]}`).join("");
  return createHash("sha256").update(canonical).digest("hex");
}

export function parseLabelList(value: string): string[] {
  return value
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
}

export function formatLabelList(names: string[]): string {
  return [...names].sort((a, b) => a.localeCompare(b)).join(", ");
}
