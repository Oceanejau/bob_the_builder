#!/usr/bin/env node

const { execSync } = require("child_process");
const path = require("path");
const fs = require("fs");

const args = process.argv.slice(2);

// HELP
if (args.length === 0 || args.includes("--help")) {
  console.log(`
Usage:
  bob_the_builder <architecture.txt> [dest]

Options:
  --preview
  --dry-run
  --force
  --y
  --keep-backup
  --no-backup
  --quiet
  --lenient
`);
  process.exit(0);
}

const input = args[0];

// 🔥 FIX IMPORTANT : resolve RELATIVELY SAFE
const inputFile = path.isAbsolute(input)
  ? input
  : path.join(process.cwd(), input);

// check file early (important for npx)
if (!fs.existsSync(inputFile)) {
  console.error("Error: file not found");
  process.exit(1);
}

const rest = args.slice(1).join(" ");
const script = path.join(__dirname, "bob_the_builder.sh");

try {
  execSync(`bash "${script}" "${inputFile}" ${rest}`, {
    stdio: "inherit"
  });
} catch (e) {
  process.exit(e.status || 1);
}
