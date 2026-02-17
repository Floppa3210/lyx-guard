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

function extractLuaTableBlock(luaText, tableName) {
  // Minimal Lua table extractor for `local <name> = { ... }`.
  const re = new RegExp(`\\b${tableName}\\b\\s*=\\s*{`);
  const m = re.exec(luaText);
  if (!m) return null;

  let i = m.index + m[0].length - 1;
  let depth = 0;
  let start = -1;
  let end = -1;

  let inSingle = false;
  let inDouble = false;
  let inLineComment = false;
  let inBlockComment = false;

  for (; i < luaText.length; i++) {
    const ch = luaText[i];
    const next = i + 1 < luaText.length ? luaText[i + 1] : "";
    const next2 = i + 2 < luaText.length ? luaText[i + 2] : "";
    const next3 = i + 3 < luaText.length ? luaText[i + 3] : "";

    if (inLineComment) {
      if (ch === "\n") inLineComment = false;
      continue;
    }
    if (inBlockComment) {
      if (ch === "]" && next === "]") {
        inBlockComment = false;
        i++;
      }
      continue;
    }
    if (inSingle) {
      if (ch === "\\") {
        i++;
        continue;
      }
      if (ch === "'") inSingle = false;
      continue;
    }
    if (inDouble) {
      if (ch === "\\") {
        i++;
        continue;
      }
      if (ch === '"') inDouble = false;
      continue;
    }

    if (ch === "-" && next === "-") {
      if (next2 === "[" && next3 === "[") {
        inBlockComment = true;
        i += 3;
      } else {
        inLineComment = true;
        i++;
      }
      continue;
    }
    if (ch === "'") {
      inSingle = true;
      continue;
    }
    if (ch === '"') {
      inDouble = true;
      continue;
    }

    if (ch === "{") {
      if (depth === 0) start = i;
      depth++;
      continue;
    }
    if (ch === "}") {
      depth--;
      if (depth === 0) {
        end = i;
        break;
      }
      continue;
    }
  }

  if (start === -1 || end === -1) return null;
  return luaText.slice(start, end + 1);
}

function extractAllowlistKeysFromBlock(luaBlockText) {
  const out = new Set();
  if (!luaBlockText) return out;
  const re = /\[['"]([^'"]+)['"]\]\s*=\s*true/g;
  let m;
  while ((m = re.exec(luaBlockText))) out.add(m[1]);
  return out;
}

function extractTableKeysFromBlock(luaBlockText) {
  const out = new Set();
  if (!luaBlockText) return out;
  const re = /\[['"]([^'"]+)['"]\]\s*=\s*{\s*/g;
  let m;
  while ((m = re.exec(luaBlockText))) out.add(m[1]);
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
  const allowlistBlock = extractLuaTableBlock(tpTxt, "AllowedLyxGuardEvents");
  const coreSchemasBlock = extractLuaTableBlock(tpTxt, "_GuardCoreDefaultSchemas");
  const panelSchemasBlock = extractLuaTableBlock(tpTxt, "_GuardPanelDefaultSchemas");

  const allowlist = extractAllowlistKeysFromBlock(allowlistBlock);
  const schemas = new Set([
    ...extractTableKeysFromBlock(coreSchemasBlock),
    ...extractTableKeysFromBlock(panelSchemasBlock),
  ]);

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
