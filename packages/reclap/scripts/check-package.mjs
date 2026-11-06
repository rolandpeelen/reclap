// Fails when the npm package would ship a file outside the expected set, such
// as the repository's own development skills, test fixtures or build output.
// Runs `npm pack --dry-run`, so it checks what `npm publish` would upload.
import { execFileSync } from "node:child_process";

const allowed = [
  /^package\.json$/,
  /^README\.md$/,
  /^LICENSE$/,
  /^rescript\.json$/,
  /^postinstall\.js$/,
  /^dune$/,
  /^dune-project$/,
  /^src\/(bindings\/)?[A-Za-z]+\.(res|resi|res\.mjs)$/,
  /^bin\/ppx(\.cmd)?$/,
  /^bin\/ppx-(linux-x64|linux-arm64|osx-x64|osx-arm64|windows)\.exe$/,
  /^ppx\/(bin|lib)\/(dune|[a-z0-9_]+\.ml)$/,
  // The only agent skill the package ships.
  /^skills\/reclap\/SKILL\.md$/,
];

const output = execFileSync("npm", ["pack", "--dry-run", "--json", "--ignore-scripts"], {
  encoding: "utf8",
  stdio: ["ignore", "pipe", "inherit"],
});
const files = JSON.parse(output)[0].files.map((file) => file.path);
const unexpected = files.filter((path) => !allowed.some((pattern) => pattern.test(path)));
const missing = ["skills/reclap/SKILL.md", "bin/ppx", "src/Clap.res"].filter(
  (path) => !files.includes(path),
);

if (unexpected.length > 0 || missing.length > 0) {
  for (const path of unexpected) console.error(`unexpected file in the package: ${path}`);
  for (const path of missing) console.error(`missing from the package: ${path}`);
  process.exit(1);
}
console.log(`package contents: ${files.length} files, all expected`);
