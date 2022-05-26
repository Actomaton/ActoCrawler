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
    public static func withPlaywright(
        pythonPackagePaths: [String],
        config: CrawlerConfig,
        browser: (@Sendable (_ playwright: PythonObject) async -> PythonObject)? = nil,
        crawl: @escaping @CrawlActor @Sendable (
            Request<URLInfo>,
            _ playwright: PythonObject,
            _ browser: PythonObject
        ) async throws -> ([UserRequest<URLInfo>], Output)
    ) async -> Crawler<Output, URLInfo>
    {
        let playwrightActor = await PlaywrightActor(
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

/// Global actor for cooperative Playwright crawling to avoid `EXC_BAD_ACCESS`.
@globalActor
internal actor CrawlActor
{
    static let shared: CrawlActor = CrawlActor()
}
