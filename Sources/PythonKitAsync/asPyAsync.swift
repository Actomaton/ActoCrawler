import PythonKit

// Using `var` + explicit `preparePythonKitAsync()` instead of
// `private let pythonKitAsync = Python.import(...)` because `let` would
// trigger `dispatch_once` initialization on first access, which may happen
// on a thread that does not hold the GIL — causing a crash in `PyImport_Import`.
nonisolated(unsafe) private var pythonKitAsync: PythonObject!

/// Pre-import the helper module while the GIL is still held (Phase 1 of init).
/// Must be called before ``PythonObject/asPyAsync()`` is used.
public func preparePythonKitAsync()
{
    pythonKitAsync = Python.import("pythonkit-async")
}

extension PythonObject
{
    /// Converts `self` as Python's coroutine (`async def`) object into Swift async function.
    /// - Important: `self` must be Python coroutine object to run properly. Otherwise, async-returned value will be `self`.
    @discardableResult
    public func asPyAsync() async -> PythonObject
    {
        let coroutine = self
        let pyObj: PythonObject = await withCheckedContinuation { continuation in
            // Dispatch to PythonGIL's serial queue so all Python async work
            // runs on the same OS thread (consistent asyncio event loop).
            PythonGIL.dispatchWithGIL {
                pythonKitAsync.coroutine_to_callback(coroutine, PythonFunction { (arg: PythonObject) in
                    continuation.resume(returning: arg)
                    return 0
                })
            }
        }

        // NOTE: Required to run other concurrent coroutines.
        await Task.yield()

        return pyObj
    }
}
