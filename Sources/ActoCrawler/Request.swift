@preconcurrency import Foundation

// MARK: - UserRequest

/// User-defined requesting `URL` with additional `URLInfo`.
public struct UserRequest<URLInfo>: Sendable where URLInfo: Sendable
{
    /// Requesting `URL`.
    public var url: URL

    /// Additional info that is attached next to requesting `URL`.
    ///
    /// For example, URL page number can be passed as `URLInfo` in ``Crawler/visit(requests:)``
    /// or ``Crawler/init(config:crawl:)``'s `crawl` return value so that next request can be determined by its page number increment.
    public var urlInfo: URLInfo

    public init(url: URL, urlInfo: URLInfo)
    {
        self.url = url
        self.urlInfo = urlInfo
    }

    public init(url: URL) where URLInfo == Void
    {
        self.url = url
        self.urlInfo = ()
    }
}

// MARK: - Request

/// ``UserRequest`` + Acrawler-additions i.e. ``order`` + ``depth``.
@dynamicMemberLookup
public struct Request<URLInfo>: Sendable where URLInfo: Sendable
{
    /// - Note: Accessible via `@dynamicMemberLookup`.
    private var userRequest: UserRequest<URLInfo>

    /// Request order number.
    public let order: UInt64

    /// Request crawling depth.
    public let depth: UInt64

    public init(url: URL, urlInfo: URLInfo, order: UInt64, depth: UInt64)
    {
        self.userRequest = .init(url: url, urlInfo: urlInfo)
        self.order = order
        self.depth = depth
    }

    public init(url: URL, order: UInt64, depth: UInt64) where URLInfo == Void
    {
        self.userRequest = .init(url: url)
        self.order = order
        self.depth = depth
    }

    public subscript<T>(dynamicMember keyPath: WritableKeyPath<UserRequest<URLInfo>, T>) -> T
    {
        get {
            self.userRequest[keyPath: keyPath]
        }
        set {
            self.userRequest[keyPath: keyPath] = newValue
        }
    }
}
