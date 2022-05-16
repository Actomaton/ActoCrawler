@preconcurrency import Foundation

/// Crawler error type.
public enum CrawlError: Error
{
    /// Failed to convert `URLResponse` into `HTTPURLResponse`.
    case invalidHTTPResponse(URLResponse)

    /// Failed to convert `Data` into crawler's perferred format.
    case invalidData

    /// Error when ``ActoCrawlerConfig/domainFilteringPolicy`` did not allow URL to pass.
    case domainNotAllowed(Domain)

    /// Crawling failed during ``Crawler/init(config:dependency:crawl:)``'s `crawl` method.
    case crawlFailed(Error)
}
