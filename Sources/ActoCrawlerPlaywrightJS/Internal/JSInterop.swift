import Foundation
import JavaScriptEventLoop
@preconcurrency import JavaScriptKit

internal enum PlaywrightJSBootstrapError: Error, Sendable
{
    case missingGlobal(String)
    case expectedObject(String)
    case expectedFunction(String)
    case expectedPromise(String)
    case expectedString(String)
    case expectedArrayLike(String)
}

extension PlaywrightJSBootstrapError: LocalizedError
{
    var errorDescription: String?
    {
        switch self {
        case let .missingGlobal(label):
            return "Missing JavaScript global: \(label)"
        case let .expectedObject(label):
            return "Expected JavaScript object: \(label)"
        case let .expectedFunction(label):
            return "Expected JavaScript function: \(label)"
        case let .expectedPromise(label):
            return "Expected JavaScript Promise: \(label)"
        case let .expectedString(label):
            return "Expected JavaScript string: \(label)"
        case let .expectedArrayLike(label):
            return "Expected JavaScript array-like object: \(label)"
        }
    }
}

internal func resolvePlaywrightModule() async throws -> JSObject
{
    let container = try jsObjectProperty(
        JSObject.global,
        "__actoCrawlerPlaywright",
        label: "globalThis.__actoCrawlerPlaywright"
    )
    return try jsObjectProperty(
        container,
        "playwright",
        label: "globalThis.__actoCrawlerPlaywright.playwright"
    )
}

internal func awaitJSValue(_ value: JSValue, label: String) async throws -> JSValue
{
    guard let object = value.object, let promise = JSPromise(object) else {
        throw PlaywrightJSBootstrapError.expectedPromise(label)
    }
    return try await promise.value
}

internal func awaitJSObject(_ value: JSValue, label: String) async throws -> JSObject
{
    let awaitedValue = try await awaitJSValue(value, label: label)
    guard let object = awaitedValue.object else {
        throw PlaywrightJSBootstrapError.expectedObject(label)
    }
    return object
}

internal func makeJSObject(_ configure: (JSObject) -> Void) -> JSObject
{
    let object = JSObject()
    configure(object)
    return object
}

internal func jsObjectProperty(_ receiver: JSObject, _ property: String, label: String) throws -> JSObject
{
    let value = receiver[property]
    if value.isUndefined {
        throw PlaywrightJSBootstrapError.missingGlobal(label)
    }
    guard let object = value.object else {
        throw PlaywrightJSBootstrapError.expectedObject(label)
    }
    return object
}

internal func jsFunctionProperty(_ receiver: JSObject, _ property: String, label: String) throws -> JSObject
{
    let value = receiver[property]
    if value.isUndefined {
        throw PlaywrightJSBootstrapError.missingGlobal(label)
    }
    guard let function = value.object else {
        throw PlaywrightJSBootstrapError.expectedFunction(label)
    }
    return function
}

internal func callJSMethod(
    _ receiver: JSObject,
    method: String,
    arguments: [ConvertibleToJSValue] = [],
    label: String
) throws -> JSValue
{
    let function = try jsFunctionProperty(receiver, method, label: label)
    return function.callAsFunction(this: receiver, arguments: arguments)
}

internal func callJSMethodValue(
    _ receiver: JSObject,
    method: String,
    arguments: [ConvertibleToJSValue] = [],
    label: String
) async throws -> JSValue
{
    try await awaitJSValue(
        try callJSMethod(receiver, method: method, arguments: arguments, label: label),
        label: label
    )
}

internal func callJSMethodObject(
    _ receiver: JSObject,
    method: String,
    arguments: [ConvertibleToJSValue] = [],
    label: String
) async throws -> JSObject
{
    try await awaitJSObject(
        try callJSMethod(receiver, method: method, arguments: arguments, label: label),
        label: label
    )
}

internal func jsStringArray(from object: JSObject, label: String) throws -> [String]
{
    guard let length = object["length"].number else {
        throw PlaywrightJSBootstrapError.expectedArrayLike("\(label).length")
    }

    return try (0 ..< Int(length)).map { index in
        guard let string = object[index].string else {
            throw PlaywrightJSBootstrapError.expectedString("\(label)[\(index)]")
        }
        return string
    }
}
