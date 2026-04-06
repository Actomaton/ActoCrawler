SWIFT ?= swift
SWIFT_WASM ?= $(HOME)/Library/Developer/Toolchains/swift-DEVELOPMENT-SNAPSHOT-2025-09-14-a.xctoolchain/usr/bin/swift
WASM_SDK ?= DEVELOPMENT-SNAPSHOT-2025-09-14-a-wasm32-unknown-wasip1-threads

#--------------------------------------------------
# Build & Test
#--------------------------------------------------

.PHONY: swift-build
swift-build:
	$(SWIFT) build

.PHONY: swift-test
swift-test:
	$(SWIFT) test

#--------------------------------------------------
# Examples
#--------------------------------------------------

.PHONY: run-scraper
run-scraper:
	$(SWIFT) run ScraperExample

.PHONY: run-image
run-image:
	$(SWIFT) run ImageScraperExample

.PHONY: run-paging
run-paging:
	$(SWIFT) run PagingScraperExample

.PHONY: setup-headless-browser
setup-headless-browser:
	cd Examples/HeadlessBrowserExample && uv sync
	cd Examples/HeadlessBrowserExample && uv run playwright install

.PHONY: run-headless-browser
run-headless-browser:
	$(SWIFT) run HeadlessBrowserExample

.PHONY: setup-headless-browser-js
setup-headless-browser-js:
	cd Examples/HeadlessBrowserJSExample && npm install
	cd Examples/HeadlessBrowserJSExample && npx playwright install chromium

.PHONY: build-headless-browser-js
build-headless-browser-js:
	$(SWIFT_WASM) package --disable-sandbox --swift-sdk $(WASM_SDK) js --product HeadlessBrowserJSExample
	npm install --prefix .build/plugins/PackageToJS/outputs/Package

.PHONY: run-headless-browser-js
run-headless-browser-js: build-headless-browser-js
	node Examples/HeadlessBrowserJSExample/main.mjs
