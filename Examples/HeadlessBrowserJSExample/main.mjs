import { mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import * as playwright from "playwright";

const exampleDir = dirname(fileURLToPath(import.meta.url));
mkdirSync(join(exampleDir, "output"), { recursive: true });

globalThis.__actoCrawlerPlaywright = {
  playwright,
  exitProcess: (code = 0) => process.exit(code),
};

const packageDir = new URL("../../.build/plugins/PackageToJS/outputs/Package/", import.meta.url);

let instantiate;
let defaultNodeSetup;

try {
  ({ instantiate } = await import(new URL("instantiate.js", packageDir)));
  ({ defaultNodeSetup } = await import(new URL("platforms/node.js", packageDir)));
} catch (error) {
  if (
    error?.code === "ERR_MODULE_NOT_FOUND" &&
    String(error.message).includes("@bjorn3/browser_wasi_shim")
  ) {
    console.error(
      "Missing generated package dependencies. Run `npm install --prefix .build/plugins/PackageToJS/outputs/Package` first."
    );
  }
  throw error;
}

const options = await defaultNodeSetup();
await instantiate(options);
