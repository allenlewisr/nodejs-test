# NodeJS Template

A simple and clean Node.js starter template with Webpack, Prettier, ESLint, and CI/CD configurations pre-configured.

## Creating a new repo

To create a new repo using this template, create a ticket in Ivanti mentioning this repo. Once the ticket is approved, a new repo will be created using this template.

## Setting Up

**Deploy to JFrog** - The build workflow can be used to deploy to JFrog. Make sure that the repository variable `DEPLOY_TO_JFROG` is set to `true`

**Node Version** - Modify the `NODE_VERSION` variable in `.github/workflows/build.yml` to set the node version

**JFrog Repo Name** - Modify the `JFROG_REPO_NAME` variable in `.github/workflows/build.yml` to set the name of the JFrog repo. If not provided, or if it is empty, the default value `<repo-name>-npm-dev-local` will be used

**JFrog Remote Repo Name** - Modify the `JFROG_REMOTE_REPO_NAME` variable in `.github/workflows/build.yml` to set the name of the JFrog remote repo from which the npm packages should be resolved.

**Build Name** - By default, the build name will be the one defined in the `package.json` file. Modify the `BUILD_NAME` variable in `.github/workflows/build.yml` to set a custom name

## Build Workflow

- The build workflow triggers automatically when a PR to main is raised or the branch is merged to main.
- The workflow will configure JFrog, runs lint on the project, and builds it
- If the changes are merged and `DEPLOY_TO_JFROG` repo is set to `true`
  - The package will be published to JFrog
  - Then, a release bundle will be created in JFrog and set to the DEV stage

## Promotion Workflow

- The promotion workflow is manually triggered
- The target jfrog stage and release bundle version must be provided
- If the release bundle name is not provided, it uses the current package name
- If the JFrog repo name is not provided, it uses `<repo-name>-npm-<target-env>-local`

## Features

- **Webpack 5** - JavaScript bundling
- **ESLint** - Code quality and style enforcement
- **Dependabot** - Automatic dependency updates
- **JFrog Integration** - Upload builds to JFrog along with evidence

## Project Structure

```
webpack-starter-template/
├── .github/
│   ├── dependabot.yml          # Dependabot configuration
│   └── workflows/
│       ├── build.yml           # Build workflow
│       └── jfrog-promotion.yml # Workflow to promote between JFrog release lifecycles
├── src/
│   ├── index.js                # Application entry point
│   └── utils.js                # Example utility module
├── dist/                       # Build output (generated)
├── .eslintrc.json              # ESLint configuration
├── .eslintignore               # ESLint ignore patterns
├── .gitignore                  # Git ignore patterns
├── .npmignore                  # NPM package ignore patterns
├── .prettierignore             # NPM package ignore patterns
├── .prettierrc                 # NPM package ignore patterns
├── webpack.config.js           # Webpack configuration
├── package.json                # Project dependencies and scripts
└── README.md                   # This file
```

## Configuration

### ESLint

ESLint is configured with eslint-config-airbnb-extended. Customize the rules in `eslint.config.js` to match your coding standards.

### Prettier

Prettier is configured with recommended rules for Node.js projects. Customize the rules in `.prettierrc` to match your coding style

### Webpack

The webpack configuration is set up for Node.js targets. Modify `webpack.config.js` to:

- Add loaders for different file types
- Configure additional plugins
- Adjust output settings
- Add multiple entry points

### Dependabot

Dependabot is configured to check for npm dependency updates weekly. It will automatically create pull requests for outdated packages.

## CI/CD

This template includes:

- **Dependabot** - Automated dependency updates
- **JFrog Integration** - Build and publish to JFrog repo
- **JFrog Promotion** - Promote between JFrog lifecycles

## Scripts Reference

| Command                | Description                           |
| ---------------------- | ------------------------------------- |
| `npm run build`        | Build for production                  |
| `npm run dev`          | Build for development with watch mode |
| `npm start`            | Run the built application             |
| `npm run lint`         | Check code for linting errors         |
| `npm run lint:fix`     | Automatically fix linting errors      |
| `npm run format:check` | Check Prettier formatting             |
| `npm run format`       | Auto-format all files with Prettier   |
