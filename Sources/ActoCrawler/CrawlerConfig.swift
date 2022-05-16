import Foundation

/// ``Crawler`` configuration.
public struct CrawlerConfig: Hashable, Sendable
{
    /// Maximum depth of crawling.
    public let maxDepths: UInt64

    /// Maximum total requests for crawling.
    public let maxTotalRequests: UInt64

    /// Per request timeout (in seconds).
    public let timeoutPerRequest: TimeInterval

    /// User-Agent attached to request header.
    public let userAgent: String

    /// Domain filtering policy.
    public let domainFilteringPolicy: DomainFilteringPolicy

    /// Domain-to-Queue mapping table where `maxConcurrency` and `delay` are configurable per `domain`.
    public let domainQueueTable: DomainQueueTable

    // TODO:
    // public let respectsRobotsTxt: Bool

    public init(
        maxDepths: UInt64 = .max,
        maxTotalRequests: UInt64 = .max,
        timeoutPerRequest: TimeInterval = .greatestFiniteMagnitude,
        userAgent: String = "ActoCrawler",
        domainFilteringPolicy: DomainFilteringPolicy = .allDomains,
        domainQueueTable: DomainQueueTable = [:]
        // respectsRobotsTxt: Bool = true
    )
    {
        self.maxDepths = maxDepths
        self.maxTotalRequests = maxTotalRequests
        self.timeoutPerRequest = timeoutPerRequest
        self.userAgent = userAgent
        self.domainQueueTable = domainQueueTable
        self.domainFilteringPolicy = domainFilteringPolicy
        // self.respectsRobotsTxt = respectsRobotsTxt
    }
}

// MARK: - DomainFilteringPolicy

public enum DomainFilteringPolicy: Hashable, Sendable
{
    /// All domains policy.
    case allDomains

    /// Allowed domains only policy.
    case allowedDomains(Set<Domain>)

    /// Ignores disallowed domains policy.
    case disallowedDomains(Set<Domain>)

    func isDomainAllowed(for domain: Domain) -> Bool
    {
        switch self {
        case .allDomains:
            return true

        case let .allowedDomains(domains):
            return domains.contains(where: { isRegexMatched(domain, pattern: $0) })

        case let .disallowedDomains(domains):
            return !domains.contains(where: { isRegexMatched(domain, pattern: $0) })
        }
    }
}
