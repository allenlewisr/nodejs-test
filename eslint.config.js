import js from '@eslint/js';
import globals from 'globals';
import prettierConfig from 'eslint-config-prettier';

export default [
  // Global ignores (replaces .eslintignore)
  {
    ignores: ['node_modules/', 'dist/', 'coverage/', '*.config.js'],
  },

  // Base ESLint recommended rules
  js.configs.recommended,

  // Configuration for all JS files
  {
    files: ['**/*.js'],
    languageOptions: {
      ecmaVersion: 'latest',
      sourceType: 'module',
      globals: {
        ...globals.node,
        ...globals.es2021,
      },
    },
    rules: {
      'no-unused-vars': 'warn',
      'no-console': 'off',
    },
  },

  // Prettier config (must be last to override other configs)
  prettierConfig,
];
