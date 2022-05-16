@preconcurrency import Foundation
@preconcurrency import SwiftSoup

extension Crawler
{
    /// Helper initializer using ``NetworkSession`` as network request, and [SwiftSoup](https://github.com/scinfu/SwiftSoup) as HTML scraper.
    ///
    /// - Parameters:
    ///   - scrapeHTML:
    ///     Receives `Response` that contains HTML `Document` to be scraped,
    ///     and returns array of next `UserRequest`s as well as `Output` for current request output.
    ///     If `Error` is thrown inside this closure, it will be observed as a failure of ``Crawler/events``.
    public static func htmlScraper(
        config: CrawlerConfig,
        scrapeHTML: @escaping @Sendable (Response<Document, URLInfo>) async throws -> ([UserRequest<URLInfo>], Output)
    ) async -> Crawler
        where Output: Sendable
    {
        await Crawler.withNetworkSession(
            config: config,
            crawl: { request, urlSession in
                // Network request.
                let urlRequest: URLRequest = URLRequest(url: request.url, timeoutInterval: config.timeoutPerRequest)
                let (data, httpResponse) = try await urlSession.data(for: urlRequest)

                guard let html = String(data: data, encoding: .utf8) else {
                    throw CrawlError.invalidData
                }

                // SwiftSoup HTML parsing.
                let doc = try SwiftSoup.parse(html)

                let response = Response(
                    request: Request(
                        url: request.url,
                        urlInfo: request.urlInfo,
                        order: request.order,
                        depth: request.depth
                    ),
                    data: doc,
                    httpResponse: httpResponse
                )

                return try await scrapeHTML(response)
            }
        )
    }
}
