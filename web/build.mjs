import { build } from "esbuild";
await build({
  entryPoints: ["src/main.jsx"],
  bundle: true,
  outfile: "app.js",
  format: "iife",
  platform: "browser",
  target: ["chrome103"],
  jsx: "automatic",
  minify: false,
  legalComments: "eof",
  define: { "process.env.NODE_ENV": '"production"' },
});
console.log("Built React inventory UI: app.js");
