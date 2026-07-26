import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";

export default defineConfig({
  // GitHub Pages serves this as a project page (amirulnasir93.github.io/cryptoTA/),
  // not a user page at the domain root, so every asset URL needs the subpath.
  base: "/cryptoTA/",
  plugins: [react(), tailwindcss()],
  server: {
    port: 5173,
  },
});
