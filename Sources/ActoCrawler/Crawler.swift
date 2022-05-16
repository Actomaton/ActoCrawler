@preconcurrency import Foundation
import Actomaton
import AsyncChannel

/// Swift Concurrency-powered crawler engine on top of [Actomaton](https://github.com/inamiy/Actomaton).
///
/// Initializers:
/// - ``Crawler/init(config:dependency:crawl:)`` is the designated initializer for arbitrary effectful crawling logic.
/// - ``Crawler/withNetworkSession(config:crawl:)`` is a helper initializer that uses ``NetworkSession`` as dependency.
/// - ``Crawler/htmlScraper(config:scrapeHTML:)`` is a helper initializer to scrape HTML using [SwiftSoup](https://github.com/scinfu/SwiftSoup) .
public struct Crawler<Output, URLInfo>: Sendable
    where Output: Sendable, URLInfo: Sendable
{
    private let actomaton: Actomaton<Action<Output, URLInfo>, State>
    private let environment: Environment<Output, URLInfo>

    /// Designated initializer for arbitrary crawling logic.
    ///
    /// - Parameters:
    ///   - dependency: ``Crawler``-retained reference that is passed on every `crawl`.
    ///   - crawl:
    ///     Receives `Request` to perform some async operations (e.g. network requesting and parsing),
    ///     and returns array of next `UserRequest`s as well as `Output` for current request output.
    ///     If `Error` is thrown inside this closure, it will be observed as a failure of ``Crawler/events``.
    public init<Dependency>(
        config: CrawlerConfig,
        dependency: Dependency,
        crawl: @escaping @Sendable (Request<URLInfo>, Dependency) async throws -> ([UserRequest<URLInfo>], Output)
    )
        where Dependency: Sendable
    {
        let environment = Environment(config: config, dependency: dependency, crawl: crawl)

        self.actomaton = Actomaton<Action, State>(
            state: State(),
            reducer: reducer(),
            environment: environment
        )
        self.environment = environment
    }

    /// Helper initializer that adds ``NetworkSession`` as dependency.
    public static func withNetworkSession(
        config: CrawlerConfig,
        crawl: @escaping @Sendable (Request<URLInfo>, NetworkSession) async throws -> ([UserRequest<URLInfo>], Output)
    ) async -> Crawler<Output, URLInfo>
    {
        let configuration: URLSessionConfiguration = {
            let configuration = URLSessionConfiguration.default
            configuration.httpAdditionalHeaders = ["User-Agent": config.userAgent]
            return configuration
        }()

        return .init(config: config, dependency: await NetworkSession(configuration: configuration), crawl: crawl)
    }

    /// Crawler output event `AsyncSequence`.
    /// - Todo: `any `AsyncSequence`.`
    public var events: AsyncChannel<CrawlEvent<Output, URLInfo>>
    {
        self.environment.events
    }

    /// Visits `url` as depth = 1 without `urlInfo`.
    public func visit(url: URL) where URLInfo == Void
    {
        self.visit(
            requests: [UserRequest(url: url)]
        )
    }

    /// Visits `request` as depth = 1 with `urlInfo` as additive information.
    public func visit(url: URL, urlInfo: URLInfo)
    {
        self.visit(
            request: UserRequest(url: url, urlInfo: urlInfo)
        )
    }

    /// Visits `request` as depth = 1.
    public func visit(request: UserRequest<URLInfo>)
    {
        self.visit(requests: [request])
    }

    /// Visits multiple `requests` as depth = 1.
    public func visit(requests: [UserRequest<URLInfo>])
    {
        Task { [actomaton] in
            await actomaton.send(.visit(requests))
        }
    }
}
