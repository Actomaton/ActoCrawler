import Foundation
import ActoCrawler

/// [playwright-python](https://playwright.dev/python/docs/intro) (headless browser) Actor wrapper.
/// - Note: This will be used as a dependency of ActoCrawler, and stored throughout its lifetime.
internal actor PlaywrightActor
{
    /// Root of `playwright/async_api`.
    /// - [async_playwright](https://github.com/microsoft/playwright-python/blob/v1.22.0/playwright/async_api/__init__.py#L85)
    /// - [PlaywrightContextManager](https://github.com/microsoft/playwright-python/blob/v1.22.0/playwright/async_api/_context_manager.py#L25)
    private let playwrightContextManager: PythonObject

    /// Python [Playwright](https://github.com/microsoft/playwright-python/blob/v1.22.0/playwright/async_api/_generated.py#L12153) object.
    internal let playwright: PythonObject

    /// Python object that is prepared via `init`'s `prepare`.
    /// For example, preparing [Browser](https://github.com/microsoft/playwright-python/blob/v1.22.0/playwright/async_api/_generated.py#L11134)
    /// is often useful not to launch multiple times and keep using the same reference.
    internal let preparedObject: PythonObject

    /// - Parameters:
    ///   - pythonPackagePaths:
    ///     Python library paths for interacting with `playwright-python`. Use `pip show playwright` to find its locaiton.
    ///   - prepare:
    ///     Async closure for setting-up `preparedObject`, which is usually a reusable `Browser`.
    internal init(
        pythonPackagePaths: [String],
        prepare: @Sendable (_ playwright: PythonObject) async -> PythonObject
    ) async
    {
        // Set PATH.
        let sys = Python.import("sys")
        for path in pythonPackagePaths {
            sys.path.append(path)
        }
        sys.path.append(PythonKitAsync.bundleResourcePath) // For importing `pythonkit-async.py`.

        let playwrightModule = Python.import("playwright.async_api")
        self.playwrightContextManager = playwrightModule.async_playwright()
        self.playwright = await self.playwrightContextManager.start().asPyAsync()
        self.preparedObject = await prepare(self.playwright)
    }

    deinit
    {
        Task.detached {  [playwrightContextManager] in
            await playwrightContextManager.__aexit__().asPyAsync()
        }
    }

    internal func runCrawl<Res>(
        _ crawl: @Sendable (
            _ playwright: PythonObject,
            _ setupObject: PythonObject
        ) async throws -> Res
    ) async rethrows -> Res
    {
        try await crawl(self.playwright, self.preparedObject)
    }
}
