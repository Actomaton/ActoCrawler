import Foundation
import ActoCrawlerPlaywrightPy

/// [playwright-python](https://playwright.dev/python/docs/intro) (headless browser) example.
@main
struct HeadlessBrowserPyExample
{
    static func main() async
    {
        struct Output: Sendable
        {
            let screenshotPath: String
        }

        // Derive `.venv` path from this source file's location.
        // Run `uv sync` in this directory first to create the venv.
        let exampleDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path
        let venvDir = "\(exampleDir)/.venv"
        let sitePackages = "\(venvDir)/lib/python3.9/site-packages"

        // Resolve the venv's Python to its real path, then find libpython alongside it.
        // This works with uv-managed Python installations where the dylib lives in
        // ~/.local/share/uv/python/<version>/lib/.
        let venvPython = URL(fileURLWithPath: "\(venvDir)/bin/python3").resolvingSymlinksInPath()
        let pythonLibDir = venvPython
            .deletingLastPathComponent() // bin/
            .deletingLastPathComponent() // <python-root>/
            .appendingPathComponent("lib/libpython3.9.dylib")
            .path

        // Resolve Python home to the uv-managed installation root so that
        // Python can find its standard library (encodings, etc.).
        let pythonHome = venvPython
            .deletingLastPathComponent() // bin/
            .deletingLastPathComponent() // <python-root>/
            .path
        setenv("PYTHONHOME", pythonHome, 1)

        // Force PythonKit to use the venv's Python library (PythonKit is incompatible with 3.13+).
        // Must be called before any Python usage.
        setenv("PYTHON_LIBRARY", pythonLibDir, 1)
        PythonLibrary.useLibrary(at: pythonLibDir)

        // Create output directory for screenshots.
        let outputDir = "\(exampleDir)/output"
        try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

        let crawler = await Crawler<Output, Void>.withPlaywrightPy(
            pythonPackagePaths: [
                sitePackages
            ],
            config: CrawlerConfig(
                maxTotalRequests: 8,
                domainQueueTable: [
                    ".*": .init(maxConcurrency: 5, delay: 0)
                ]
            ),
            crawl: { request, playwright, browser in
                // NOTE:
                // `playwright` is `PythonObject` that can inter-op with Python using `@dynamicMemberLookup`.
                // For playwright-python APIs, see documentation:
                // https://playwright.dev/python/docs/intro

                let context = await browser.new_context().asPyAsync()
                let page = await context.new_page().asPyAsync()

                // Visit URL.
                await page.goto(request.url.absoluteString).asPyAsync()

                // Take screenshot.
                let screenshotPath = "\(exampleDir)/output/example-\(request.order).png"
                await page.screenshot(path: screenshotPath).asPyAsync()

                // Extract next URL links.
                // https://playwright.dev/python/docs/evaluating
                let linkObjects = await page
                    .evaluate("() => Array.from(document.links).map(item => item.href)")
                    .asPyAsync()

                let nextUserRequests: [UserRequest<Void>]
                if let links: [String] = Array(linkObjects) {
                    nextUserRequests = links
                        .compactMap { URL(string: $0).map(UserRequest.init(url:)) }
                        .shuffled()
                }
                else {
                    nextUserRequests = []
                }

                await page.close().asPyAsync()
                await context.close().asPyAsync()

                return (nextUserRequests, Output(screenshotPath: screenshotPath))
            }
        )

        // Initial crawls.
        crawler.visit(requests: [
            .init(url: URL(string: "https://en.wikipedia.org")!),
            .init(url: URL(string: "https://ja.wikipedia.org")!),
            .init(url: URL(string: "https://zh.wikipedia.org")!),
        ])

        for await event in crawler.events {
            switch event {
            case let .willCrawl(req):
                print("Crawl : 🕸️ [\(req.order)] [d=\(req.depth)] \(req.url)")
            case let .didCrawl(req, .success(output)):
                print("Output: ✅ [\(req.order)] [d=\(req.depth)] \(req.url), screenshotPath = \(output.screenshotPath)")
            case let .didCrawl(req, .failure(error)):
                print("Output: ❌ [\(req.order)] [d=\(req.depth)] \(req.url), error = \(error)")
            }
        }

        print("Output Done")
    }
}
