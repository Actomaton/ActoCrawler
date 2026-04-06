# Examples

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
