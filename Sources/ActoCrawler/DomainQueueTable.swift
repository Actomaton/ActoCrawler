import Foundation
@preconcurrency import Collections

/// Domain-to-Queue mapping table where `maxConcurrency` and random `delay` are configurable per `domain`.
/// - Note: `domain` can use regular expressions.
///
/// For example:
///
/// ```swift
/// let domainQueueTable: DomainQueueTable = [
///     ".*google.*": .init(maxConcurrency: 5, delay: 0.1) // fixed delay
///     ".*wikipedia.*": .init(maxConcurrency: 3, delay: 0.1 ... 0.3) // random delay in range
///     ".*": .default
/// ]
/// let config = CrawlerConfig(..., domainQueueTable: domainQueueTable)
/// ```
public struct DomainQueueTable: Hashable, Sendable
{
    let dictionary: OrderedDictionary<Key, Value>

    func buildQueue(url: URL) -> CrawlQueue
    {
        guard let host = url.host else { return .default }

        for (pattern, values) in self.dictionary {
            guard isRegexMatched(host, pattern: pattern) else { continue }

            return CrawlQueue(
                domain: pattern,
                maxConcurrency: values.maxConcurrency,
                delay: .random(values.delay)
            )
        }

        return .default
    }

    // MARK: Key/Value

    public typealias Key = Domain

    public struct Value: Hashable, Sendable
    {
        let maxConcurrency: Int
        let delay: ClosedRange<TimeInterval>

        public init(maxConcurrency: Int, delay: ClosedRange<TimeInterval>)
        {
            self.maxConcurrency = maxConcurrency
            self.delay = delay
        }

        public init(maxConcurrency: Int, delay: TimeInterval)
        {
            self.maxConcurrency = maxConcurrency
            self.delay = delay ... delay
        }
    }
}

extension DomainQueueTable: ExpressibleByDictionaryLiteral
{
    public init(dictionaryLiteral elements: (Key, Value)...)
    {
        self.dictionary = .init(uniqueKeysWithValues: elements)
    }
}

extension DomainQueueTable: Sequence
{
    public func makeIterator() -> AnyIterator<(key: Key, value: Value)>
    {
        return AnyIterator(dictionary.makeIterator())
    }
}
