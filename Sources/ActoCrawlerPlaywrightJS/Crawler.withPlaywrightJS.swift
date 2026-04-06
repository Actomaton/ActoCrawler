import Foundation
import ActoCrawler
import JavaScriptEventLoop
@preconcurrency import JavaScriptKit

extension Crawler
{
    /// Helper initializer that adds Playwright from the JavaScript runtime as ActoCrawler's dependency.
    ///
    /// The surrounding JavaScript environment must install Playwright on
    /// `globalThis.__actoCrawlerPlaywright.playwright` before instantiating the wasm module.
    ///
    /// - Parameters:
    ///   - browser:
    ///     Creates a reusable object from Playwright, usually a `Browser`.
    ///     If `nil`, Chromium with non-headless mode will launch.
    ///
    ///   - crawl:
    ///     Crawling function that receives Playwright and Browser as `JSObject`s for JavaScript inter-op.
    public static func withPlaywrightJS(
        config: CrawlerConfig,
        browser: (@Sendable (_ playwright: JSObject) async throws -> JSObject)? = nil,
        crawl: @escaping @Sendable (
            _ isolation: isolated (any Actor),
            _ request: Request<URLInfo>,
            _ playwright: JSObject,
            _ browser: JSObject
        ) async throws -> ([UserRequest<URLInfo>], Output)
    ) async -> Crawler<Output, URLInfo>
    {
        JavaScriptEventLoop.installGlobalExecutor()

        let playwrightActor = PlaywrightJSActor(
            prepare: browser ?? { playwright in
                let chromium = try jsObjectProperty(
                    playwright,
                    "chromium",
                    label: "globalThis.__actoCrawlerPlaywright.playwright.chromium"
                )
                let options: JSObject = ["headless": .boolean(false)]
                return try await callJSMethodObject(
                    chromium,
                    method: "launch",
                    arguments: [options],
                    label: "playwright.chromium.launch"
                )
            }
        )

        return Crawler<Output, URLInfo>(
            config: config,
            dependency: playwrightActor,
            crawl: { request, playwrightActor in
                try await playwrightActor.runCrawl {
                    try await crawl($0, request, $1, $2)
                }
            }
        )
    }
}
