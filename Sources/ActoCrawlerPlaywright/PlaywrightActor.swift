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
        prepare: @CrawlActor @Sendable (_ playwright: PythonObject) async -> PythonObject
    ) async
    {
        // Phase 1: Synchronous Python setup.
        // GIL is held from Py_Initialize (triggered by first Python.import call).
        let sys = Python.import("sys")
        for path in pythonPackagePaths {
            sys.path.append(path)
        }
        sys.path.append(PythonKitAsync.bundleResourcePath) // For importing `pythonkit-async.py`.

        // Pre-import the async helper while GIL is still held.
        preparePythonKitAsync()

        let playwrightModule = Python.import("playwright.async_api")
        self.playwrightContextManager = playwrightModule.async_playwright()

        // Eagerly create the coroutine while we still hold the initial GIL.
        let startCoroutine = self.playwrightContextManager.start()

        // Phase 2: Release the initial GIL and enable per-job GIL management.
        // After this call, every Python access must go through PythonGIL.withGIL
        // or run on PythonSerialExecutor.
        PythonGIL.activate()

        // Phase 3: Async Python work.
        // asPyAsync() internally uses PythonGIL.withGIL to acquire the GIL.
        self.playwright = await startCoroutine.asPyAsync()
        self.preparedObject = await prepare(self.playwright)
    }

    deinit
    {
        // Release PythonObjects on the GIL-protected queue to avoid
        // Py_DecRef being called without the GIL during process teardown.
        let contextManager = playwrightContextManager
        PythonGIL.queue.async {
            PythonGIL.withGIL {
                _ = contextManager  // prevent capture optimization; release here under GIL
            }
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

    // Pin all Python work to the shared serial executor with GIL management.
    internal nonisolated var unownedExecutor: UnownedSerialExecutor
    {
        PythonSerialExecutor.shared.asUnownedSerialExecutor()
    }
}
