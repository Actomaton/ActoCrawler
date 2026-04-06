import Foundation
import ActoCrawlerPlaywrightJS

/// Playwright + JavaScriptKit example that mirrors `HeadlessBrowserPyExample`.
@main
struct HeadlessBrowserJSExample
{
    static func main()
    {
        JavaScriptEventLoop.installGlobalExecutor()

        Task {
            await self.run()
        }
    }

    private static func run() async
    {
        let browserBox = BrowserBox()

        struct Output: Sendable
        {
            let screenshotPath: String
        }

        let exampleDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path
        let outputDir = "\(exampleDir)/output"

        let crawler = await Crawler<Output, Void>.withPlaywrightJS(
            config: CrawlerConfig(
                maxTotalRequests: 8,
                domainQueueTable: [
                    ".*": .init(maxConcurrency: 5, delay: 0)
                ]
            ),
            browser: { playwright in
                let chromium = try object(from: playwright["chromium"], label: "playwright.chromium")
                let options: JSObject = ["headless": .boolean(false)]
                let browser = try await awaitObject(
                    chromium.launch!(options),
                    label: "playwright.chromium.launch"
                )
                browserBox.object = browser
                return browser
            },
            crawl: { request, _, browser in
                let context = try await awaitObject(browser.newContext!(), label: "browser.newContext")
                let page = try await awaitObject(context.newPage!(), label: "context.newPage")

                _ = try await awaitValue(
                    page.goto!(request.url.absoluteString),
                    label: "page.goto"
                )

                let screenshotPath = "\(outputDir)/example-\(request.order).png"
                let screenshotOptions: JSObject = ["path": .string(screenshotPath)]
                _ = try await awaitValue(
                    page.screenshot!(screenshotOptions),
                    label: "page.screenshot"
                )

                let linksLocator = try object(from: page.locator!("a"), label: "page.locator")
                let linkCountValue = try await awaitValue(
                    linksLocator.count!(),
                    label: "locator.count"
                )
                guard let linkCount = linkCountValue.number else {
                    throw ExampleError.expectedNumber("locator.count")
                }

                var nextUserRequests: [UserRequest<Void>] = []

                for index in 0 ..< Int(linkCount) {
                    let linkLocator = try object(from: linksLocator.nth!(index), label: "locator.nth")
                    let hrefValue = try await awaitValue(
                        linkLocator.getAttribute!("href"),
                        label: "locator.getAttribute"
                    )

                    if hrefValue.isNull || hrefValue.isUndefined {
                        continue
                    }

                    guard let href = hrefValue.string else {
                        throw ExampleError.expectedString("locator.getAttribute")
                    }

                    if let nextURL = URL(string: href, relativeTo: request.url)?.absoluteURL
                    {
                        nextUserRequests.append(UserRequest(url: nextURL))
                    }
                }

                nextUserRequests.shuffle()

                _ = try await awaitValue(page.close!(), label: "page.close")
                _ = try await awaitValue(context.close!(), label: "context.close")

                return (nextUserRequests, Output(screenshotPath: screenshotPath))
            }
        )

        crawler.visit(requests: [
            UserRequest(url: URL(string: "https://en.wikipedia.org")!),
            UserRequest(url: URL(string: "https://ja.wikipedia.org")!),
            UserRequest(url: URL(string: "https://zh.wikipedia.org")!),
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

        if let browser = browserBox.object {
            _ = try? await awaitValue(browser.close!(), label: "browser.close")
        }

        print("Output Done")

        if let exitProcess = JSObject.global.__actoCrawlerPlaywright.object?["exitProcess"].object {
            _ = exitProcess.callAsFunction(0)
        }
    }
}

// MARK: - Private

private final class BrowserBox: @unchecked Sendable
{
    var object: JSObject?
}

private func awaitValue(_ value: JSValue, label: String) async throws -> JSValue
{
    guard let object = value.object, let promise = JSPromise(object) else {
        throw ExampleError.expectedPromise(label)
    }
    return try await promise.value
}

private func object(from value: JSValue, label: String) throws -> JSObject
{
    guard let object = value.object else {
        throw ExampleError.expectedObject(label)
    }
    return object
}

private func awaitObject(_ value: JSValue, label: String) async throws -> JSObject
{
    let awaitedValue = try await awaitValue(value, label: label)
    guard let object = awaitedValue.object else {
        throw ExampleError.expectedObject(label)
    }
    return object
}

private enum ExampleError: Error
{
    case expectedPromise(String)
    case expectedObject(String)
    case expectedString(String)
    case expectedNumber(String)
}
