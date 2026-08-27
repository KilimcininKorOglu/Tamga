import SwiftUI

/// Tab bar containing all open tabs
struct TabBarView: View {
    @ObservedObject var tabManager: TabManager

    @State private var draggedTabId: UUID?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(tabManager.tabs) { tab in
                        TabItemView(
                            tab: tab,
                            isSelected: tabManager.activeTabId == tab.id,
                            onSelect: {
                                tabManager.selectTab(id: tab.id)
                            },
                            onClose: {
                                tabManager.closeTab(id: tab.id)
                            }
                        )
                        .id(tab.id)
                        .onDrag {
                            draggedTabId = tab.id
                            return NSItemProvider(object: tab.id.uuidString as NSString)
                        }
                        .onDrop(
                            of: [.text],
                            delegate: TabDropDelegate(
                                tabId: tab.id,
                                draggedTabId: $draggedTabId,
                                tabManager: tabManager
                            ))
                    }

                    // New tab button
                    Button(action: {
                        tabManager.createNewTab()
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .help(String(localized: "new.tab"))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(MouseWheelHorizontalScroller())
            }
            .onChange(of: tabManager.activeTabId) { newValue in
                if let id = newValue {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
        .frame(height: 36)
        .background(Color(nsColor: .windowBackgroundColor))
        .onReceive(NotificationCenter.default.publisher(for: .closeOtherTabs)) { notification in
            if let tabId = notification.object as? UUID {
                tabManager.closeOtherTabs(except: tabId)
            }
        }
    }
}

// MARK: - Mouse Wheel Horizontal Scrolling

/// Lets a plain mouse wheel scroll the horizontal tab bar.
///
/// A horizontal SwiftUI `ScrollView` on macOS only reacts to horizontal scroll deltas,
/// which a mouse without a tilt wheel never produces, so off-screen tabs stay
/// unreachable by mouse. This view finds the enclosing `NSScrollView` and installs a
/// local event monitor that turns vertical wheel deltas into horizontal offset while the
/// pointer sits over the tab bar. Events outside the tab bar pass through untouched.
struct MouseWheelHorizontalScroller: NSViewRepresentable {
    /// Reports the moment it joins a window, when `enclosingScrollView` first resolves.
    final class ScrollViewProbe: NSView {
        var onAttach: ((NSView) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard window != nil else { return }
            onAttach?(self)
        }

        /// Stays out of the responder chain so tab clicks and drags behave as before.
        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }
    }

    func makeNSView(context: Context) -> ScrollViewProbe {
        let view = ScrollViewProbe(frame: .zero)
        view.onAttach = { [weak coordinator = context.coordinator] probe in
            coordinator?.attach(to: probe)
        }
        return view
    }

    func updateNSView(_ nsView: ScrollViewProbe, context: Context) {
        // Covers the case where the probe entered the hierarchy before the scroll view existed.
        context.coordinator.attach(to: nsView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    static func dismantleNSView(_ nsView: ScrollViewProbe, coordinator: Coordinator) {
        nsView.onAttach = nil
        coordinator.detach()
    }

    @MainActor
    final class Coordinator {
        /// Points scrolled per wheel line for coarse (non-trackpad) wheels.
        private let lineScrollDistance: CGFloat = 24

        private weak var scrollView: NSScrollView?
        private var monitor: Any?

        func attach(to view: NSView) {
            guard monitor == nil, let enclosing = view.enclosingScrollView else { return }
            scrollView = enclosing
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                self?.handle(event) ?? event
            }
        }

        func detach() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
            monitor = nil
            scrollView = nil
        }

        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }

        /// Returns nil to consume the event once it has been applied as horizontal
        /// scrolling, or the original event when it does not belong to the tab bar.
        private func handle(_ event: NSEvent) -> NSEvent? {
            guard let scrollView,
                event.window === scrollView.window,
                event.scrollingDeltaX == 0,
                event.scrollingDeltaY != 0,
                isPointerOverTabBar(event, in: scrollView),
                let maximumOffset = maximumHorizontalOffset(of: scrollView)
            else {
                return event
            }

            let distance =
                event.hasPreciseScrollingDeltas
                ? event.scrollingDeltaY
                : event.scrollingDeltaY * lineScrollDistance

            var origin = scrollView.contentView.bounds.origin
            origin.x = min(max(0, origin.x - distance), maximumOffset)
            scrollView.contentView.setBoundsOrigin(origin)
            scrollView.reflectScrolledClipView(scrollView.contentView)
            return nil
        }

        private func isPointerOverTabBar(_ event: NSEvent, in scrollView: NSScrollView) -> Bool {
            let point = scrollView.convert(event.locationInWindow, from: nil)
            return scrollView.bounds.contains(point)
        }

        /// Maximum scrollable x offset, or nil when every tab already fits on screen.
        private func maximumHorizontalOffset(of scrollView: NSScrollView) -> CGFloat? {
            guard let documentView = scrollView.documentView else { return nil }
            let overflow = documentView.frame.width - scrollView.contentView.bounds.width
            return overflow > 0 ? overflow : nil
        }
    }
}

// MARK: - Tab Drop Delegate

struct TabDropDelegate: DropDelegate {
    let tabId: UUID
    @Binding var draggedTabId: UUID?
    let tabManager: TabManager

    func performDrop(info: DropInfo) -> Bool {
        draggedTabId = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggedId = draggedTabId,
            draggedId != tabId,
            let fromIndex = tabManager.tabs.firstIndex(where: { $0.id == draggedId }),
            let toIndex = tabManager.tabs.firstIndex(where: { $0.id == tabId })
        else {
            return
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            tabManager.moveTab(from: fromIndex, to: toIndex)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

#Preview {
    let tabManager = TabManager()
    tabManager.createNewTab()
    tabManager.createNewTab()

    return TabBarView(tabManager: tabManager)
}
