import XCTest

#if arch(wasm32)
@testable import ActoCrawlerPlaywrightJS
import JavaScriptEventLoop
@preconcurrency import JavaScriptKit

final class ActoCrawlerPlaywrightJSTests: XCTestCase
{
    override class func setUp()
    {
        JavaScriptEventLoop.installGlobalExecutor()
    }

    func testBrowserIsReusedAcrossCrawls() async throws
    {
        let fixture = FakePlaywrightFixture(
            linksByURL: [
                "https://example.com": [
                    "https://example.com/child-1",
                    "https://example.com/child-2",
                ],
                "https://example.com/child-1": [],
                "https://example.com/child-2": [],
            ]
        )
        fixture.install()
        defer { fixture.uninstall() }

        let crawler = await Crawler<String, Void>.withPlaywrightJS(
            config: CrawlerConfig(
                maxTotalRequests: 3,
                domainQueueTable: [
                    ".*": .init(maxConcurrency: 3, delay: 0)
                ]
            ),
            crawl: { request, _, browser in
                let context = try await callJSMethodObject(
                    browser,
                    method: "newContext",
                    label: "browser.newContext"
                )
                let page = try await callJSMethodObject(
                    context,
                    method: "newPage",
                    label: "context.newPage"
                )

                _ = try await callJSMethodValue(
                    page,
                    method: "goto",
                    arguments: [request.url.absoluteString],
                    label: "page.goto"
                )

                let screenshotPath = "/tmp/example-\(request.order).png"
                let screenshotOptions: JSObject = ["path": .string(screenshotPath)]
                _ = try await callJSMethodValue(
                    page,
                    method: "screenshot",
                    arguments: [screenshotOptions],
                    label: "page.screenshot"
                )

                let linkObjects = try await callJSMethodObject(
                    page,
                    method: "evaluate",
                    arguments: ["() => Array.from(document.links).map(item => item.href)"],
                    label: "page.evaluate"
                )
                let nextRequests = try jsStringArray(from: linkObjects, label: "page.evaluate")
                    .compactMap { URL(string: $0).map(UserRequest.init(url:)) }

                _ = try await callJSMethodValue(page, method: "close", label: "page.close")
                _ = try await callJSMethodValue(context, method: "close", label: "context.close")

                return (nextRequests, screenshotPath)
            }
        )

        crawler.visit(url: URL(string: "https://example.com")!)

        var outputs: [String] = []
        for await event in crawler.events {
            if case let .didCrawl(_, .success(output)) = event {
                outputs.append(output)
            }
        }

        XCTAssertEqual(outputs.count, 3)
        XCTAssertEqual(fixture.launchCallCount, 1)
        XCTAssertEqual(fixture.newContextCallCount, 3)
        XCTAssertEqual(fixture.gotoURLs, [
            "https://example.com",
            "https://example.com/child-1",
            "https://example.com/child-2",
        ])
        XCTAssertEqual(fixture.screenshotPaths, [
            "/tmp/example-0.png",
            "/tmp/example-1.png",
            "/tmp/example-2.png",
        ])
    }

    func testMissingBootstrapBecomesCrawlFailure() async throws
    {
        JSObject.global["__actoCrawlerPlaywright"] = .undefined

        let crawler = await Crawler<Int, Void>.withPlaywrightJS(
            config: CrawlerConfig(
                maxTotalRequests: 1,
                domainQueueTable: [
                    ".*": .init(maxConcurrency: 1, delay: 0)
                ]
            ),
            crawl: { _, _, _ in
                XCTFail("crawl should not be called when bootstrap is missing")
                return ([], 0)
            }
        )

        crawler.visit(url: URL(string: "https://example.com")!)

        var receivedError: CrawlError?
        for await event in crawler.events {
            if case let .didCrawl(_, .failure(error)) = event {
                receivedError = error
            }
        }

        guard case let .crawlFailed(underlyingError)? = receivedError else {
            return XCTFail("Expected crawlFailed error, got \(String(describing: receivedError))")
        }
        guard case let .missingGlobal(label) = underlyingError as? PlaywrightJSBootstrapError else {
            return XCTFail("Expected missingGlobal error, got \(underlyingError)")
        }
        XCTAssertEqual(label, "globalThis.__actoCrawlerPlaywright")
    }
}

private final class FakePlaywrightFixture
{
    private var retainedClosures: [JSClosure] = []

    private let browser = JSObject()
    private let context = JSObject()
    private let page = JSObject()

    let linksByURL: [String: [String]]
    var launchCallCount = 0
    var newContextCallCount = 0
    var gotoURLs: [String] = []
    var screenshotPaths: [String] = []

    init(linksByURL: [String: [String]])
    {
        self.linksByURL = linksByURL
    }

    func install()
    {
        let container = JSObject()
        let playwright = JSObject()
        let chromium = JSObject()

        chromium["launch"] = .object(self.retain { _ in
            self.launchCallCount += 1
            return JSPromise.resolve(self.browser).jsValue()
        })

        self.browser["newContext"] = .object(self.retain { _ in
            self.newContextCallCount += 1
            return JSPromise.resolve(self.context).jsValue()
        })

        self.context["newPage"] = .object(self.retain { _ in
            JSPromise.resolve(self.page).jsValue()
        })

        self.context["close"] = .object(self.retain { _ in
            JSPromise.resolve(JSValue.undefined).jsValue()
        })

        self.page["goto"] = .object(self.retain { args in
            self.gotoURLs.append(args.first?.string ?? "")
            return JSPromise.resolve(JSValue.undefined).jsValue()
        })

        self.page["screenshot"] = .object(self.retain { args in
            let path = args.first?.object?["path"].string ?? ""
            self.screenshotPaths.append(path)
            return JSPromise.resolve(JSValue.undefined).jsValue()
        })

        self.page["evaluate"] = .object(self.retain { _ in
            let currentURL = self.gotoURLs.last ?? ""
            let array = self.makeJSArray(self.linksByURL[currentURL] ?? [])
            return JSPromise.resolve(array).jsValue()
        })

        self.page["close"] = .object(self.retain { _ in
            JSPromise.resolve(JSValue.undefined).jsValue()
        })

        playwright["chromium"] = .object(chromium)
        container["playwright"] = .object(playwright)
        JSObject.global["__actoCrawlerPlaywright"] = .object(container)
    }

    func uninstall()
    {
        JSObject.global["__actoCrawlerPlaywright"] = .undefined
        self.retainedClosures.removeAll()
    }

    private func retain(_ body: @escaping ([JSValue]) -> JSValue) -> JSClosure
    {
        let closure = JSClosure(body)
        self.retainedClosures.append(closure)
        return closure
    }

    private func makeJSArray(_ strings: [String]) -> JSObject
    {
        let array = JSObject.global.Array.object!.new()
        for (index, string) in strings.enumerated() {
            array[index] = .string(string)
        }
        return array
    }
}
#endif
