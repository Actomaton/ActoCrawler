import Foundation
import AsyncChannel

/// Effectful environment for making arbitrary crawler.
struct Environment<Output, URLInfo>: Sendable
    where Output: Sendable, URLInfo: Sendable
{
    let config: CrawlerConfig

    /// Receives `Request` to perform some async operations (e.g. network requesting and parsing),
    /// and returns array of next `Request`s as well as `Output`.
    let crawl: @Sendable (Request<URLInfo>) async throws -> ([UserRequest<URLInfo>], Output?)

    /// Output `AsyncSequence`  as a result of `crawl`.
    /// - Todo: `any `AsyncSequence`.
    let outputs: AsyncChannel<(Request<URLInfo>, Result<Output, CrawlError>)> = .init()

    init<Dependency>(
        config: CrawlerConfig,
        dependency: Dependency,
        crawl: @escaping @Sendable (Request<URLInfo>, Dependency) async throws -> ([UserRequest<URLInfo>], Output?)
    )
        where Dependency: Sendable
    {
        self.config = config
        self.crawl = { request in
            try await crawl(request, dependency)
        }
    }
}
