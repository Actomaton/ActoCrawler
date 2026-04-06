import Dispatch
import Darwin

/// Minimal GIL (Global Interpreter Lock) and thread management for calling
/// Python from Swift Concurrency.
///
/// Python's GIL is a mutex that protects access to Python objects, preventing
/// multiple threads from executing Python bytecode simultaneously. Any thread
/// that calls the Python C API must hold the GIL; failing to do so causes
/// crashes or data corruption. PythonKit does not manage the GIL on its own,
/// so this helper bridges the gap when Swift Concurrency dispatches work
/// across different OS threads.
///
/// All Python work is dispatched to a single serial queue, ensuring:
/// 1. GIL is held for every Python call (``PyGILState_Ensure`` / ``PyGILState_Release``)
/// 2. The same OS thread is reused, so ``asyncio.get_event_loop()`` returns
///    a consistent event loop across calls.
///
/// Call ``activate()`` once after ``Py_Initialize`` has run and all synchronous
/// ``Python.import`` calls are done.
public enum PythonGIL
{
    /// Serial queue for all Python work after activation.
    public static let queue = DispatchQueue(label: "PythonGIL.serial")

    nonisolated(unsafe) private static var _gilEnsure: (@convention(c) () -> Int32)?
    nonisolated(unsafe) private static var _gilRelease: (@convention(c) (Int32) -> Void)?

    /// Resolve GIL symbols and release the initial GIL held by ``Py_Initialize``.
    ///
    /// Must be called exactly once, after all synchronous ``Python.import``
    /// calls are done and before any ``asPyAsync()`` usage.
    public static func activate()
    {
        let handle = dlopen(nil, RTLD_LAZY)

        guard let ensureSym = dlsym(handle, "PyGILState_Ensure"),
              let releaseSym = dlsym(handle, "PyGILState_Release"),
              let saveThreadSym = dlsym(handle, "PyEval_SaveThread")
        else {
            fatalError("Failed to load Python GIL symbols. Is the Python library loaded?")
        }

        _gilEnsure = unsafeBitCast(ensureSym, to: (@convention(c) () -> Int32).self)
        _gilRelease = unsafeBitCast(releaseSym, to: (@convention(c) (Int32) -> Void).self)

        // Release the GIL that Py_Initialize acquired on this thread.
        let saveThread = unsafeBitCast(
            saveThreadSym,
            to: (@convention(c) () -> UnsafeMutableRawPointer?).self
        )
        _ = saveThread()
    }

    /// Execute `body` synchronously with the GIL held.
    ///
    /// If ``activate()`` has not been called yet, `body` runs without
    /// GIL management (assumes GIL is already held from ``Py_Initialize``).
    @discardableResult
    public static func withGIL<T>(_ body: () throws -> T) rethrows -> T
    {
        guard let ensure = _gilEnsure, let release = _gilRelease else {
            return try body()
        }
        let state = ensure()
        defer { release(state) }
        return try body()
    }

    /// Dispatch a block to the serial Python queue with GIL held.
    ///
    /// Used by ``PythonObject/asPyAsync()`` to ensure all Python async work
    /// runs on the same OS thread (consistent asyncio event loop).
    ///
    /// The closure is stored in a ``SendableBox`` and nil-ed inside
    /// ``withGIL`` so that any captured ``PythonObject``s are released
    /// while the GIL is still held.
    internal static func dispatchWithGIL(_ body: @escaping @Sendable () -> Void)
    {
        let box = SendableBox(body)
        queue.async {
            withGIL {
                box.take()?()
            }
        }
    }
}

/// Thread-safe box that holds a value and allows one-shot retrieval.
///
/// Used to move a closure into a dispatch block and release it
/// at a controlled point (e.g. while the GIL is held).
private final class SendableBox<T>: @unchecked Sendable
{
    private var value: T?

    init(_ value: T) { self.value = value }

    /// Returns the stored value and clears the box.
    func take() -> T?
    {
        defer { value = nil }
        return value
    }
}
