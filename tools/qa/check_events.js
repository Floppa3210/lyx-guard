#!/usr/bin/env node
/* eslint-disable no-console */
/**
 * LyxGuard QA - Offline event/schema coverage checker
 *
 * Goals:
 * - Ensure every `RegisterNetEvent('lyxguard:panel:*')` is:
 *   - allowlisted in `server/trigger_protection.lua`
 *   - has a schema entry in `server/trigger_protection.lua` when applicable
 *
 * This is static analysis (no FiveM runtime required).
 */

const fs = require("fs");
const path = require("path");

const REPO_ROOT = path.resolve(__dirname, "..", "..");

function readText(filePath) {
  return fs.readFileSync(filePath, "utf8");
}

function listFilesRecursive(dir, predicate) {
  const out = [];
  for (const ent of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, ent.name);
    if (ent.isDirectory()) out.push(...listFilesRecursive(full, predicate));
    else if (!predicate || predicate(full)) out.push(full);
  }
  return out;
}

function extractRegisterNetEvents(luaText) {
  const out = new Set();
  const re = /RegisterNetEvent\s*\(\s*['"]([^'"]+)['"]/g;
  let m;
  while ((m = re.exec(luaText))) out.add(m[1]);
  return out;
}

function extractAllowlistKeys(luaText) {
  const out = new Set();
  const re = /\[['"]([^'"]+)['"]\]\s*=\s*true/g;
  let m;
  while ((m = re.exec(luaText))) out.add(m[1]);
  return out;
}

function extractSchemaKeys(luaText) {
  const out = new Set();
  const re = /\[['"]([^'"]+)['"]\]\s*=\s*{\s*/g;
  let m;
  while ((m = re.exec(luaText))) out.add(m[1]);
  return out;
}

function main() {
  const serverDir = path.join(REPO_ROOT, "server");
  const tpPath = path.join(serverDir, "trigger_protection.lua");
  if (!fs.existsSync(tpPath)) {
    console.error("Missing:", tpPath);
    process.exit(2);
  }

  const luaFiles = listFilesRecursive(serverDir, (p) => p.endsWith(".lua"));
  const registered = new Set();
  for (const f of luaFiles) {
    const txt = readText(f);
    for (const e of extractRegisterNetEvents(txt)) registered.add(e);
  }

  const tpTxt = readText(tpPath);
  const allowlist = extractAllowlistKeys(tpTxt);
  const schemas = extractSchemaKeys(tpTxt);

  const critical = [...registered].filter(
    (e) => e.startsWith("lyxguard:panel:") || e === "lyxguard:heartbeat"
  );

  const missingAllowlist = critical.filter((e) => !allowlist.has(e));
  // Schemas are expected for panel events and heartbeat.
  const missingSchema = critical.filter((e) => !schemas.has(e));

  // Also catch allowlisted critical events without schemas.
  const allowlistedCritical = [...allowlist].filter(
    (e) => e.startsWith("lyxguard:panel:") || e === "lyxguard:heartbeat"
  );
  const allowlistedWithoutSchema = allowlistedCritical.filter((e) => !schemas.has(e));

  const issues = [];
  if (missingAllowlist.length) issues.push({ title: "Missing allowlist entries", items: missingAllowlist });
  if (missingSchema.length) issues.push({ title: "Missing schema entries", items: missingSchema });
  if (allowlistedWithoutSchema.length)
    issues.push({ title: "Allowlisted critical events without schema", items: allowlistedWithoutSchema });

  if (!issues.length) {
    console.log("[OK] lyxguard panel/heartbeat allowlist + schema coverage looks complete.");
    return;
  }

  console.error("[FAIL] Event/schema coverage issues found:\n");
  for (const g of issues) {
    console.error("==", g.title);
    for (const it of g.items.sort()) console.error("-", it);
    console.error("");
  }
  process.exit(1);
}

main();

