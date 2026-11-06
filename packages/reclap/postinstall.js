// Installs the prebuilt reclap PPX for this platform as bin/ppx (bin/ppx.exe on
// Windows), replacing the launcher script that would otherwise pick the binary
// on every call. Plain Node, no dependencies.
//
// This is only an optimisation: package managers that skip install scripts
// keep the launcher, which works on its own. In a development checkout bin/
// holds no prebuilt binaries and the script does nothing.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const bin = path.join(path.dirname(fileURLToPath(import.meta.url)), "bin");

const binaries = {
  "linux-x64": "ppx-linux-x64.exe",
  "linux-arm64": "ppx-linux-arm64.exe",
  "darwin-x64": "ppx-osx-x64.exe",
  "darwin-arm64": "ppx-osx-arm64.exe",
  // The x64 build also runs on Windows on Arm through emulation.
  "win32-x64": "ppx-windows.exe",
  "win32-arm64": "ppx-windows.exe",
};

const prebuilt = fs.existsSync(bin)
  ? fs.readdirSync(bin).filter((file) => /^ppx-.+\.exe$/.test(file))
  : [];
if (prebuilt.length === 0) {
  // Development checkout or a build from source: nothing to install.
  process.exit(0);
}

const platform = `${process.platform}-${process.arch}`;
const binary = binaries[platform];
if (binary === undefined || !prebuilt.includes(binary)) {
  console.error(
    [
      `reclap: no prebuilt PPX for ${platform}.`,
      `Supported platforms: ${Object.keys(binaries).join(", ")}.`,
      "Build the PPX from source with OCaml >= 5.1 and dune: cd node_modules/@rolandpeelen/reclap && dune build",
    ].join("\n"),
  );
  process.exit(1);
}

const source = path.join(bin, binary);
const windows = process.platform === "win32";
const target = path.join(bin, windows ? "ppx.exe" : "ppx");
// Copy next to the target, then rename over it, so a concurrent build never
// runs a half-written file.
const temporary = `${target}.${process.pid}.tmp`;
fs.copyFileSync(source, temporary);
fs.chmodSync(temporary, 0o755);
fs.renameSync(temporary, target);
if (windows) {
  // cmd.exe would prefer ppx.cmd over ppx.exe; the launcher is no longer needed.
  fs.rmSync(path.join(bin, "ppx.cmd"), { force: true });
}
