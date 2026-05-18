# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**mnote** is a mobile-first PWA (Progressive Web App) application for browsing and annotating GitHub Markdown files. It enables offline reading, content caching, and note-taking with a task management system. Built with Vue 3 + Vite, deployed via GitHub Pages, with no backend server required.

**Key Characteristics:**
- Zero backend infrastructure (client-side only, GitHub API driven)
- All data stored locally in browser localStorage
- Supports private GitHub repositories via Personal Access Token
- PWA with Service Worker for offline capability
- Internationalization: UI is in Chinese (Simplified)

## Technology Stack

| Layer | Technology |
|-------|-----------|
| Framework | Vue 3 (Composition API, `<script setup>` SFCs) |
| Build Tool | Vite 8.0+ |
| Routing | Vue Router 4 (Hash History) |
| Markdown | marked.js v18 |
| Styling | Scoped CSS in Vue components |
| Deployment | GitHub Pages + GitHub Actions |

## Directory Structure

```
mnote/
├── src/
│   ├── main.js                 # App entry point
│   ├── App.vue                 # Root component (router outlet)
│   ├── router/
│   │   └── index.js            # Route definitions & auth guard
│   ├── views/                  # Page-level components
│   │   ├── Setup.vue           # Token authentication
│   │   ├── RepoList.vue        # Repository management & favorites
│   │   ├── FileTree.vue        # Directory/file browsing with create
│   │   ├── MarkdownView.vue    # File reading with notes & favorites
│   │   └── TaskList.vue        # Task management (pending/done)
│   ├── composables/
│   │   ├── useStorage.js       # localStorage abstraction (auth, repos, favorites)
│   │   └── useGitHub.js        # GitHub API wrapper
│   └── assets/
│       └── main.css            # Global styles
├── public/
│   ├── manifest.json           # PWA manifest
│   ├── sw.js                   # Service Worker
│   ├── icons.svg
│   └── favicon.svg
├── index.html                  # HTML entry point
├── vite.config.js              # Vite configuration
├── package.json
└── docs/
    ├── product.md              # Feature documentation (Chinese)
    └── superpowers/            # Claude Code workflow docs
```

## Build & Development Commands

```bash
# Install dependencies
npm install

# Development server (hot reload, http://localhost:5173/)
npm run dev

# Production build (outputs to dist/)
npm run build

# Preview production build locally
npm run preview
```

**Base Path:** The app deploys to `/mnote/` on GitHub Pages (configured in `vite.config.js`). Routes use hash history (`#/`).

## Architecture & Data Flow

### Authentication & Storage

1. **useStorage.js** - Composable providing localStorage management:
   - `getToken() / setToken() / clearToken()` - GitHub token lifecycle
   - `getRepos() / addRepo() / removeRepo()` - Repository list persistence
   - `getFavorites() / toggleFavorite() / isFavorite()` - Bookmarked files
   - Token validity checked in router guard (`beforeEach` in `router/index.js`)
   - Invalid token redirects unauthenticated users to `/setup`

2. **useGitHub.js** - GitHub API wrapper:
   - Accepts token as constructor parameter
   - Rate limit detection (error message format: `RATE_LIMIT:${unixTimestamp}`)
   - Authorization error detection (error message: `UNAUTHORIZED`)
   - Base64 encoding/decoding for file content
   - Methods: `validateToken()`, `searchRepos()`, `getContents()`, `getFileContent()`, `putFile()`, `getFileSha()`

### Page Flow

1. **Setup.vue** (`/setup`) - Token input & validation
   - Stores token via `useStorage().setToken()`
   - Redirects to RepoList on success

2. **RepoList.vue** (`/`) - Repository management
   - Displays user's added repositories
   - Search & add repositories via GitHub API
   - Toggle favorites panel
   - Remove repositories
   - Reset token flow

3. **FileTree.vue** (`/repo/:owner/:repo`) - Directory browsing
   - File/directory listing with GitHub API
   - Directory sorting (dirs before files)
   - Breadcrumb navigation
   - Create new `.md` files in current directory

4. **MarkdownView.vue** (`/repo/:owner/:repo/file/:path(*)`) - Content reading
   - Renders Markdown with XSS protection (`marked.Renderer.html = () => ''`)
   - Client-side caching with localStorage
   - Scroll position recovery
   - Favorite toggle (star icon)
   - **Notes system**: Integrates with separate `zlpx96/mnote-data` repo
     - Reads/writes notes to `notes/{owner}/{repo}/{path}` in mnote-data
     - YAML frontmatter metadata
     - Notes persist independently of read repo

5. **TaskList.vue** (`/tasks`) - Task management
   - Reads from `zlpx96/mnote-data` repo
   - Displays tasks from `tasks/pending/` and `tasks/done/` directories
   - Creates new tasks with YAML frontmatter (status, created timestamp, target, options)
   - Tasks support: auto_publish, with_image, with_cover flags
   - Task routing enabled: done tasks link to their original content

### Caching Strategy

- **File Content**: Cached in localStorage with key `mnote_cache_{owner}/{repo}/{path}`
- **Scroll Position**: Stored with key `mnote_scroll_{owner}/{repo}/{path}`
- **Load Behavior**: 
  - Show cached content immediately if available
  - Fetch fresh content in background
  - If network error and cache exists: show cache silently
  - If network error and no cache: show error message
- **Cache Invalidation**: Cleared on token reset (`clearToken()`)
- **Service Worker**: Caches app assets (not API calls); registered in `index.html`

### Special Considerations

1. **External Data Repo**: The app depends on a separate GitHub repo (`zlpx96/mnote-data`) for:
   - User notes (linked to content files)
   - Task management (pending/done directories)
   - This repo must exist and user must have write access

2. **Error Handling Patterns**:
   - Check `error.message` for `UNAUTHORIZED` → redirect to `/setup`
   - Check for `RATE_LIMIT:` prefix → extract Unix timestamp, calculate reset time
   - All API calls wrapped in try/catch with user-facing messages

3. **Component State**:
   - Most page state is reactive (no Vuex/Pinia; local component refs)
   - Navigation state tracked via Vue Router + browser history
   - No global state except router

## Key Architectural Patterns

1. **Composables as API Layers**: `useGitHub` and `useStorage` abstract external dependencies
2. **Reactive Caching**: Content loaded with fallback to localStorage
3. **Error-Driven Redirects**: Token expiry detected on 401 responses
4. **Stateless Auth**: No session; token passed to each API call
5. **localStorage-First**: UI is responsive and functional offline for cached data

## Development Notes

- **Vue version**: Using Vue 3 with Composition API and `<script setup>` syntax
- **Styling**: Component-scoped CSS; global styles in `src/assets/main.css`
- **Routing**: Hash history required for GitHub Pages deployment
- **XSS Protection**: marked.js renderer configured to strip HTML tags
- **No Build Optimization**: Vite handles tree-shaking; no manual optimization needed
- **Chinese Localization**: All UI text is in Simplified Chinese; preserve in PRs

## Testing & Linting

No test suite or linters configured. Follow existing code style: 2-space indentation, Composition API `<script setup>` pattern.

## Deployment

- **Trigger**: Push to main branch
- **CI/CD**: GitHub Actions (workflow in `.github/workflows/`)
- **Output**: Static files deployed to GitHub Pages at `https://{user}.github.io/mnote/`
- **Base Path**: `/mnote/` (affects links, routing, and asset paths)

