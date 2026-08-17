#!/usr/bin/env node
// Convert documents dropped in ./ingest/ to markdown using the markitdown MCP
// server (the same one opencode's `markitdown` MCP wraps), bypassing opencode's
// per-session MCP loading. Output lands in ./ingest/converted/.
//
// Usage:
//   node scripts/convert-ingest.mjs                  # every file in ingest/
//   node scripts/convert-ingest.mjs path a path b    # specific files
//
// Source files are left in place; a <name>.md is written to ingest/converted/.

import { spawn } from "node:child_process";
import { createInterface } from "node:readline";
import { readdir, writeFile, mkdir } from "node:fs/promises";
import { basename, extname, join, resolve } from "node:path";
import { pathToFileURL, fileURLToPath } from "node:url";

const DROP = join(fileURLToPath(new URL("..", import.meta.url)), "ingest");
const OUT = join(DROP, "converted");
const SKIP = new Set([".gitkeep", ".gitignore", "converted"]);

async function allTargets() {
  const entries = await readdir(DROP, { withFileTypes: true });
  return entries
    .filter((e) => e.isFile() && !SKIP.has(e.name))
    .map((e) => join(DROP, e.name));
}

async function main() {
  await mkdir(OUT, { recursive: true });

  const child = spawn("npx", ["-y", "markitdown-mcp-npx"], {
    stdio: ["pipe", "pipe", "pipe"],
  });
  const pending = new Map();
  createInterface({ input: child.stdout }).on("line", (line) => {
    let msg;
    try {
      msg = JSON.parse(line);
    } catch {
      return;
    }
    if (msg.id != null && pending.has(msg.id)) {
      const { resolve, reject } = pending.get(msg.id);
      pending.delete(msg.id);
      msg.error ? reject(new Error(JSON.stringify(msg.error))) : resolve(msg.result);
    }
  });

  let nextId = 0;
  const call = (method, params = {}) =>
    new Promise((resolve, reject) => {
      const id = ++nextId;
      pending.set(id, { resolve, reject });
      child.stdin.write(JSON.stringify({ jsonrpc: "2.0", id, method, params }) + "\n");
    });

  await call("initialize", {
    protocolVersion: "2024-11-05",
    capabilities: {},
    clientInfo: { name: "convert-ingest", version: "1.0.0" },
  });
  child.stdin.write(
    JSON.stringify({ jsonrpc: "2.0", method: "notifications/initialized", params: {} }) + "\n"
  );

  const args = process.argv.slice(2);
  const sources = args.length ? args.map((a) => resolve(a)) : await allTargets();

  let ok = 0;
  for (const src of sources) {
    try {
      const result = await call("tools/call", {
        name: "convert_to_markdown",
        arguments: { uri: pathToFileURL(src).href },
      });
      const text = (result.content || [])
        .filter((c) => c.type === "text")
        .map((c) => c.text)
        .join("\n");
      const out = join(OUT, basename(src, extname(src)) + ".md");
      await writeFile(out, text, "utf8");
      console.log(`ok: ${basename(src)} -> ${basename(out)}`);
      ok++;
    } catch (err) {
      console.error(`ERR ${basename(src)}: ${err.message}`);
    }
  }

  child.kill();
  console.log(`\nConverted ${ok} file(s) -> ${OUT}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});