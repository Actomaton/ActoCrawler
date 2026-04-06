import Foundation
import ActoCrawler

extension Crawler
{
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
}
