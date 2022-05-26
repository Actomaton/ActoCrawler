import Foundation

/// Path to `pythonkit-async.py`
public let bundleResourcePath: String = {
    BundleToken.bundle.resourcePath!
}()

// MARK: - Private

private final class BundleToken
{
    static let bundle: Bundle = {
#if SWIFT_PACKAGE
        return Bundle.module
#else
        return Bundle(for: BundleToken.self)
#endif
    }()
}
