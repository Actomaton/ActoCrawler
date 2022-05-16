import Foundation
import ActoCrawler

/// Pagination-based scraping example using `URLInfo`.
@main
struct PagingScraperExample
{
    static func main() async
    {
        /// Additive information (page type) attached to requesting URL to track for determining next crawlings.
        enum URLInfo
        {
            case page(UInt64)
            case post
        }

        struct Output: Sendable
        {
            let message: String
        }

        let htmlCrawler = await Crawler<Output, URLInfo>.htmlScraper(
            config: CrawlerConfig(
                maxTotalRequests: 50,
                domainQueueTable: [
                    ".*news.ycombinator.com.*": .init(maxConcurrency: 3, delay: 0.3)
                ]
            ),
            scrapeHTML: { response in
                let html = response.data

                switch response.urlInfo {
                case let .page(page):
                    var nextURLs: [UserRequest<URLInfo>]
                    nextURLs = try html.select("table.itemlist tr.athing")
                        .map { "https://news.ycombinator.com/item?id=\($0.id())" }
                        .compactMap(URL.init)
                        .map { UserRequest<URLInfo>(url: $0, urlInfo: .post) }

                    if page < 100 {
                        if let nextPageURL = URL(string: "https://news.ycombinator.com/news?p=\(page + 1)")
                        {
                            let nextPageRequest = UserRequest<URLInfo>(url: nextPageURL, urlInfo: .page(page + 1))
                            nextURLs.append(nextPageRequest)
                        }
                    }

                    return (nextURLs, Output(message: "Crawled page = \(page)."))

                case .post:
                    let title = try html.title()
                    return ([], Output(message: "Crawled post, title = \(title)"))
                }
            }
        )

        htmlCrawler.visit(url: URL(string: "https://news.ycombinator.com/news")!, urlInfo: .page(1))

        for await (req, result) in htmlCrawler.outputs {
            switch result {
            case let .success(output):
                print("Output: ✅ [\(req.order)] [d=\(req.depth)] \(req.url), message = \(output.message)")
            case let .failure(error):
                print("Output: ❌ [\(req.order)] [d=\(req.depth)] \(req.url), error = \(error)")
            }
        }

        print("Output Done")
    }
}
