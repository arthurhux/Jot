import AppKit
import Foundation
import Testing
import WebKit
@testable import Jot

@Suite("Swift correctness audit")
@MainActor
struct SwiftAuditTests {
    @Test("WebKit navigation policy is exposed to Objective-C")
    func navigationPolicySelector() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("JotSwiftAudit-\(UUID())", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = NoteStore(directory: directory)
        let controller = EditorController(store: store)
        let coordinator = NativeEditor.Coordinator(controller)
        let selector = NSSelectorFromString("webView:decidePolicyForNavigationAction:decisionHandler:")

        let implemented = coordinator.responds(to: selector)
#if JOT_STRICT_AUDIT
        // Enable this diagnostic with complete concurrency checking. Normal
        // Swift 5 builds must keep asserting that today's callback is exposed.
        let reference = ActorAnnotatedPolicyDelegate()
        if reference.responds(to: selector) {
            withKnownIssue("The production callback lacks the SDK's MainActor handler annotation.") {
                #expect(implemented)
            }
        } else {
            // Older SDKs can expose the unannotated production signature.
            #expect(implemented)
        }
#else
        #expect(implemented)
#endif
    }

    @Test("A failed editor snapshot reports an observable error")
    func snapshotFailureIsVisible() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("JotSwiftAudit-\(UUID())", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = NoteStore(directory: directory)
        let controller = EditorController(store: store)
        let webView = WKWebView(frame: .zero)
        controller.webView = webView
        controller.isReady = true

        // This isolated blank page deliberately has no bundled editor API.
        // First prove that WebKit reports a JavaScript failure for the fixture.
        do {
            _ = try await webView.evaluateJavaScript("window.jot.getSnapshot()")
            Issue.record("The snapshot failure fixture unexpectedly succeeded.")
            return
        } catch {
            #expect((error as NSError).domain == WKErrorDomain)
        }

        await withCheckedContinuation { continuation in
            controller.captureSnapshot { continuation.resume() }
        }
        withKnownIssue("captureSnapshot currently ignores WebKit's error and completes normally.") {
            #expect(controller.failure != nil)
        }
    }
}

#if JOT_STRICT_AUDIT
@MainActor
private final class ActorAnnotatedPolicyDelegate: NSObject, WKNavigationDelegate {
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void
    ) {
        decisionHandler(.cancel)
    }
}
#endif
