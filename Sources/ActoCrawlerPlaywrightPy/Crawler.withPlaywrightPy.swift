import Foundation
import ActoCrawler

extension Crawler
{
    /// Helper initializer that adds [playwright-python](https://playwright.dev/python/docs/intro) (headless browser) as ActoCrawler's dependency.
    ///
    /// As written in the documentation, make sure to setup Python environment before calling this method:
    ///
    /// 1. `pip install playwright`
    /// 2. `playwright install`
    ///
    /// - Parameters:
    ///   - pythonPackagePaths:
    ///     Python library paths for interacting with `playwright-python`. Use `pip show playwright` to find its locaiton.
    ///
    ///   - browser:
    ///     Creates a new `Browser` object from `playwright` to reuse during crawling iterations.
    ///     If `nil`, Chromium with non-headless mode will launch.
    ///
    ///     Example of this closure is:
    ///     ```
    ///     let browser = { await $0.chromium.launch(headless: false).asPyAsync() }
    ///     ```
    ///
    ///   - crawl:
    ///     Crawling function that receives
    ///     [Playwright](https://github.com/microsoft/playwright-python/blob/v1.22.0/playwright/async_api/_generated.py#L12153)
    ///     and [Browser](https://github.com/microsoft/playwright-python/blob/v1.22.0/playwright/async_api/_generated.py#L11134)
    ///     as `PythonObject`s to inter-op with Python.
    public static func withPlaywrightPy(
        pythonPackagePaths: [String],
        config: CrawlerConfig,
        browser: (@CrawlPyActor @Sendable (_ playwright: PythonObject) async -> PythonObject)? = nil,
        crawl: @escaping @CrawlPyActor @Sendable (
            Request<URLInfo>,
            _ playwright: PythonObject,
            _ browser: PythonObject
        ) async throws -> ([UserRequest<URLInfo>], Output)
    ) async -> Crawler<Output, URLInfo>
    {
        let playwrightActor = await PlaywrightPyActor(
            pythonPackagePaths: pythonPackagePaths,
            prepare: browser ?? { await $0.chromium.launch(headless: false).asPyAsync() }
        )

        return Crawler<Output, URLInfo>(
            config: config,
            dependency: playwrightActor,
            crawl: { request, playwrightActor in
                try await playwrightActor.runCrawl {
                    try await crawl(request, $0, $1)
                }
            }
        )
    }
}

// MARK: - Private

/// Global actor for cooperative Playwright (Python) crawling to avoid `EXC_BAD_ACCESS`.
/// Pinned to ``PythonSerialExecutor`` so that Python's GIL is managed per-job.
@globalActor
internal actor CrawlPyActor
{
    static let shared: CrawlPyActor = CrawlPyActor()

    nonisolated var unownedExecutor: UnownedSerialExecutor
    {
        PythonSerialExecutor.shared.asUnownedSerialExecutor()
    }
}
