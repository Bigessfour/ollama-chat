import js from '@eslint/js'
import globals from 'globals'
import reactHooks from 'eslint-plugin-react-hooks'
import reactRefresh from 'eslint-plugin-react-refresh'
import { defineConfig, globalIgnores } from 'eslint/config'

export default defineConfig([
  globalIgnores(['dist', 'coverage', 'playwright-report', 'test-results']),
  {
    files: ['playwright.config.js', 'vite.config.js'],
    languageOptions: {
      globals: globals.node,
    },
  },
  {
    files: ['**/*.{test,spec}.{js,jsx}', 'src/test/**', 'e2e/**'],
    extends: [js.configs.recommended],
    languageOptions: {
      globals: {
        ...globals.browser,
        ...globals.node,
        describe: 'readonly',
        it: 'readonly',
        expect: 'readonly',
        vi: 'readonly',
        beforeEach: 'readonly',
        afterEach: 'readonly',
      },
      parserOptions: { ecmaFeatures: { jsx: true } },
    },
  },
  {
    files: ['**/*.{js,jsx}'],
    ignores: ['**/*.{test,spec}.{js,jsx}', 'e2e/**', 'playwright.config.js', 'vite.config.js'],
    extends: [
      js.configs.recommended,
      reactHooks.configs.flat.recommended,
      reactRefresh.configs.vite,
    ],
    languageOptions: {
      globals: globals.browser,
      parserOptions: { ecmaFeatures: { jsx: true } },
    },
  },
])
