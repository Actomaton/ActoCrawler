import Foundation
import ActoCrawler
import ActoCrawlerPlaywright

/// [playwright-python](https://playwright.dev/python/docs/intro) (headless browser) example.
@main
struct HeadlessBrowserExample
{
    static func main() async
    {
        struct Output: Sendable
        {
            let screenshotPath: String
        }

        let home = NSHomeDirectory()

        let crawler = await Crawler<Output, Void>.withPlaywright(
            pythonPackagePaths: [
                // NOTE: Change path to your own settings.
                "\(home)/.pyenv/versions/miniforge3-4.10.3-10/envs/ml/lib/python3.9/site-packages"
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
                let screenshotPath = "screenshots/example-\(request.order).png"
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
