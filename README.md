# 🕸️ ActoCrawler

**ActoCrawler** is a Swift Concurrency-powered crawler engine on top of [Actomaton](https://github.com/inamiy/Actomaton), with flexible customizability to create various HTML scrapers, image scrapers, etc.

## Products

- `ActoCrawler`: Core crawler engine with generic dependency injection and queueing logic.
- `ActoCrawlerNetworking`: Networking helpers such as `NetworkSession`, `Response`, and `withNetworkSession`.
- `ActoCrawlerHTML`: HTML scraping helpers such as `htmlScraper` backed by [SwiftSoup](https://github.com/scinfu/SwiftSoup).
- `ActoCrawlerPlaywright`: Native headless-browser adapter using [playwright-python](https://playwright.dev/python/docs/intro) via [PythonKit](https://github.com/pvieito/PythonKit.git).
- `ActoCrawlerPlaywrightJS`: WebAssembly headless-browser adapter using npm `playwright` via [JavaScriptKit](https://github.com/swiftwasm/JavaScriptKit).

## Example

- [Examples](Examples)

```swift
import ActoCrawlerHTML

struct Output: Sendable
{
    let nextLinksCount: Int
}

let htmlCrawler = await Crawler<Output, Void>.htmlScraper(
    config: CrawlerConfig(
        maxDepths: 10,
        maxTotalRequests: 100,
        timeoutPerRequest: 5,
        userAgent: "ActoCrawler",
        domainFilteringPolicy: .disallowedDomains([".*google.com*" /* ... */]),
        domainQueueTable: [
            ".*example1.com*": .init(maxConcurrency: 1, delay: 0),
            ".*example2.com*": .init(maxConcurrency: 5, delay: 0.1 ... 0.5)
        ]
    ),
    scrapeHTML: { response in
        let html = response.data
        let links = try html.select("a").map { try $0.attr("href") }

        let nextRequests = links
            .compactMap(URL.init(string:))
            .map { UserRequest(url: $0) }

        return (nextRequests, Output(nextLinksCount: nextRequests.count))
    }
)

// Visit initial page.
htmlCrawler.visit(url: URL(string: "https://www.wikipedia.org")!)

// Observe crawl events.
for await event in htmlCrawler.events {
    switch event {
    case let .willCrawl(req):
        print("Crawl : 🕸️ [\(req.order)] [d=\(req.depth)] \(req.url)")
    case let .didCrawl(req, .success(output)):
        print("Output: ✅ [\(req.order)] [d=\(req.depth)] \(req.url), nextLinksCount = \(output.nextLinksCount)")
    case let .didCrawl(req, .failure(error)):
        print("Output: ❌ [\(req.order)] [d=\(req.depth)] \(req.url), error = \(error)")
    }
}

print("Output Done")
```

## Headless Browser Adapters

Two Playwright integrations are available.

- `ActoCrawlerPlaywright` is the native macOS path and is demonstrated by `Examples/HeadlessBrowserExample`.
- `ActoCrawlerPlaywrightJS` is the WebAssembly path and is demonstrated by `Examples/HeadlessBrowserJSExample`.

The JavaScriptKit adapter expects the surrounding JavaScript runtime to install Playwright on `globalThis.__actoCrawlerPlaywright.playwright` before the wasm module is instantiated. The example bootstrap in `Examples/HeadlessBrowserJSExample/main.mjs` does this automatically.

## Acknowledgements

- [mattsse/voyager](https://github.com/mattsse/voyager)

## License

[MIT](LICENSE)
