@preconcurrency import Foundation

/// HTTP Response  for ``Request`` with `URLSession`'s results and additional `URLInfo`.
@dynamicMemberLookup
public struct Response<Data, URLInfo>: Sendable
    where Data: Sendable, URLInfo: Sendable
{
    /// - Note: Accessible via `@dynamicMemberLookup`.
    private var request: Request<URLInfo>

    // URLSession response.
    public var data: Data
    public var httpResponse: HTTPURLResponse

    public init(
        request: Request<URLInfo>,
        data: Data,
        httpResponse: HTTPURLResponse
    )
    {
        self.request = request
        self.data = data
        self.httpResponse = httpResponse
    }

    public subscript<T>(dynamicMember keyPath: WritableKeyPath<Request<URLInfo>, T>) -> T
    {
        get {
            self.request[keyPath: keyPath]
        }
        set {
            self.request[keyPath: keyPath] = newValue
        }
    }
}
