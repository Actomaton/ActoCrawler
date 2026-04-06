# Examples

Repository root has a convenience `Makefile` for running the examples.

## ScraperExample

Basic HTML scraper using `ActoCrawlerHTML` and [SwiftSoup](https://github.com/scinfu/SwiftSoup).

```bash
swift run ScraperExample
```

## ImageScraperExample

Image scraper that combines `ActoCrawlerNetworking` and `ActoCrawlerHTML`.

```bash
swift run ImageScraperExample
```

## PagingScraperExample

Scraper with pagination support built on `ActoCrawlerHTML`.

```bash
swift run PagingScraperExample
```

## HeadlessBrowserExample

Headless browser crawler using [playwright-python](https://playwright.dev/python/docs/intro) via [PythonKit](https://github.com/pvieito/PythonKit.git).
This example launches a real browser (Chromium) to render pages, take screenshots, and extract links.

### Prerequisites

- [uv](https://docs.astral.sh/uv/) (Python package manager)

### Setup

1. Install Python dependencies via `uv`:

```bash
cd Examples/HeadlessBrowserExample
uv sync
```

2. Install Playwright browser binaries:

```bash
uv run playwright install
```

### Run

```bash
swift run HeadlessBrowserExample
```

Screenshots will be saved to `screenshots/` in the working directory.

## HeadlessBrowserJSExample

Headless browser crawler using npm `playwright` via [JavaScriptKit](https://github.com/swiftwasm/JavaScriptKit).
This example builds Swift to WebAssembly, injects Playwright from Node.js, visits real pages, and saves screenshots through the JavaScriptKit adapter.

### Prerequisites

- A SwiftWasm-compatible `swift` toolchain. Do not use the default Xcode toolchain for the `js` command.
- A matching wasm SDK. The validated SDK ID for this repository is `DEVELOPMENT-SNAPSHOT-2025-09-14-a-wasm32-unknown-wasip1-threads`.
- Node.js and npm

### Setup

1. Install npm dependencies:

```bash
cd Examples/HeadlessBrowserJSExample
npm install
```

2. Install Playwright browser binaries:

```bash
npx playwright install chromium
```

### Build

```bash
swift package --disable-sandbox --swift-sdk DEVELOPMENT-SNAPSHOT-2025-09-14-a-wasm32-unknown-wasip1-threads js --product HeadlessBrowserJSExample
npm install --prefix .build/plugins/PackageToJS/outputs/Package
```

### Run

```bash
node Examples/HeadlessBrowserJSExample/main.mjs
```

Screenshots will be saved to `Examples/HeadlessBrowserJSExample/output/`.
