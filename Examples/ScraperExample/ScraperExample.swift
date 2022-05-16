import Foundation
import ActoCrawler

/// Basic HTML scraping example using `Crawler.htmlScraper`.
@main
struct ScraperExample
{
    static func main() async
    {
        struct Output: Sendable
        {
            let nextLinksCount: Int
        }

        let htmlCrawler = await Crawler<Output, Void>.htmlScraper(
            config: CrawlerConfig(
                maxTotalRequests: 10
            ),
            scrapeHTML: { response in
                let html = response.data
                let links = try html.select("a").map { try $0.attr("href") }

                let nextRequests = links
                    .compactMap(URL.init(string:))
                    .filter { $0.scheme != nil }
                    .map { UserRequest(url: $0) }

                return (nextRequests, Output(nextLinksCount: nextRequests.count))
            }
        )

        htmlCrawler.visit(url: URL(string: "https://www.wikipedia.org")!)

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
    }
}
