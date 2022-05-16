/// Crawler output event to be delivered to ``Crawler/events``.
public enum CrawlEvent<Output, URLInfo>: Sendable
    where Output: Sendable, URLInfo: Sendable
{
    case willCrawl(Request<URLInfo>)
    case didCrawl(Request<URLInfo>, Result<Output, CrawlError>)
}
