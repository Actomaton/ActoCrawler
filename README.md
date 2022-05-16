# 🕸️ ActoCrawler

**ActoCrawler** is a Swift Concurrency-powered crawler engine on top of [Actomaton](https://github.com/inamiy/Actomaton), with flexible customizability to create various HTML scrapers, image scrapers, etc.

## Example

- [Examples](Examples)

```swift
@main
struct ReadMeExample
{
    static func main() async
    {
        struct Output: Sendable
        {
            let nextLinksCount: Int
        }

        let htmlCrawler = Crawler<Output, Void>.htmlScraper(
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

        // Observe visited outputs.
        for await (req, result) in htmlCrawler.outputs {
            switch result {
            case let .success(output):
                print("Output: ✅ [\(req.order)] [d=\(req.depth)] \(req.url), nextLinksCount = \(output.nextLinksCount)")
            case let .failure(error):
                print("Output: ❌ [\(req.order)] [d=\(req.depth)] \(req.url), error = \(error)")
            }
        }

        print("Output Done")
    }
}
```

## Acknowledgements

- [mattsse/voyager](https://github.com/mattsse/voyager)

## License

[MIT](LICENSE)
