# Content Playground

A browser-based content planning studio. No package installation is required.

## Project structure

```text
src/                         Editable web app source
  index.html
  style.css
  app.js
scripts/build.py             Builds the web app and delivery files
dist/                        Generated web app for static hosting
.openai/hosting.json          Hosting configuration (serves dist/)
outputs/
  Content Playground/        Standalone app and user instructions
    Content Playground.html
    START HERE.txt
  releases/                  Downloadable ZIP
  previews/                  Planner preview image
```

## Open the planner

Open [Content Playground.html](outputs/Content%20Playground/Content%20Playground.html) in your browser. This file is self-contained apart from optional Google Fonts. Its existing location has been preserved.

Plans are stored in the browser on your device. Keep using the same browser and file location, and use the app's Backup feature before changing either.

## Make changes

Edit the files in `src/`, then run from the project root:

```sh
python3 scripts/build.py
```

This refreshes `dist/`, the standalone HTML, and `outputs/releases/Content Playground.zip`. Edit the standalone user instructions in `outputs/Content Playground/START HERE.txt`; the build includes them in the ZIP. Generated HTML changes should be made in `src/` so the next build preserves them.

To preview the web version locally:

```sh
python3 -m http.server 8000 --directory dist
```

Visit http://localhost:8000. The hosted version and standalone file may have separate browser storage; use Backup and Restore to transfer plans.
