import Foundation

/// `URLSession` wrapped by `Actor`, used in ``Crawler/withNetworkSession(config:crawl:)``.
public actor NetworkSession
{
    private let urlSession: URLSession

    public init(configuration: URLSessionConfiguration) async
    {
        self.urlSession = URLSession(configuration: configuration)
    }

    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
    {
        let (data, urlResponse) = try await urlSession.data(for: request)

        if let urlResponse = urlResponse as? HTTPURLResponse {
            return (data, urlResponse)
        }
        else {
            throw CrawlError.invalidHTTPResponse(urlResponse)
        }
    }
}
