import { defineConfig } from "vitest/config"

export default defineConfig({
  test: {
    dir: "src/assets/js",
    environment: "jsdom",
    coverage: {
      provider: "istanbul",
      include: ["src/assets/js/controllers/**"],
      thresholds: {
        statements: 70,
      },
    },
  },
})
