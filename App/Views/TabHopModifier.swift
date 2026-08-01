import SwiftUI

#if os(macOS)
  import AppKit

  /// Hops focus between the reply field and the content editor on ⇥/⇧⇥.
  ///
  /// Text views eat Tab before SwiftUI key handling, so this intercepts at the
  /// event-monitor level while the form is visible.
  struct TabHopModifier: ViewModifier {
    let contentFocus: FocusState<Bool>.Binding
    var isEnabled: Bool
    let replyFocus: FocusState<Bool>.Binding

    @State private var monitor: Any?

    func body(content: Content) -> some View {
      content
        .onAppear {
          monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.keyCode == 48, isEnabled else { return event }
            if event.modifierFlags.contains(.shift), contentFocus.wrappedValue {
              replyFocus.wrappedValue = true
              return nil
            }
            if !event.modifierFlags.contains(.shift), replyFocus.wrappedValue {
              contentFocus.wrappedValue = true
              return nil
            }
            return event
          }
        }
        .onDisappear {
          if let monitor {
            NSEvent.removeMonitor(monitor)
          }
          monitor = nil
        }
    }
  }
#endif

extension View {
  /// ⇥/⇧⇥ move between the form's reply field and content editor (macOS).
  func tabHopsBetweenFields(
    contentFocus: FocusState<Bool>.Binding,
    isEnabled: Bool,
    replyFocus: FocusState<Bool>.Binding
  ) -> some View {
    #if os(macOS)
      modifier(TabHopModifier(contentFocus: contentFocus, isEnabled: isEnabled, replyFocus: replyFocus))
    #else
      self
    #endif
  }
}
