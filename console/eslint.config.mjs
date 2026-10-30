import js from "@eslint/js";
import globals from "globals";
import reactHooks from "eslint-plugin-react-hooks";
import tseslint from "typescript-eslint";

export default tseslint.config(
  { ignores: ["dist", "build", "coverage"] },
  {
    files: ["**/*.{ts,tsx}"],
    extends: [js.configs.recommended, ...tseslint.configs.recommended],
    languageOptions: { ecmaVersion: 2022, globals: globals.browser },
    plugins: { "react-hooks": reactHooks },
    rules: {
      // Includes react-hooks/set-state-in-effect (CLAUDE.md §0.3.3).
      ...reactHooks.configs.recommended.rules,
      // Number-format tests match the narrow no-break space Intl puts in Mongolian numbers.
      "no-irregular-whitespace": ["error", { skipRegExps: true }],
    },
  },
);
