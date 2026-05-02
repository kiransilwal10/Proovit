//
//  CustomTabBar.swift
//  Proovit
//
//  The 5-slot bottom bar: Home, Calendar, [Camera FAB], Compare, Profile.
//
//  Why custom and not SwiftUI's TabView: we need a center button that is
//  visually elevated above the bar (the camera FAB) and doesn't behave
//  like a tab — tapping it presents the camera modally rather than
//  switching tabs. TabView can't express that without fighting it.
//

import SwiftUI

/// The four "real" tabs. The camera button is not part of this enum
/// because it doesn't represent a piece of persistent screen content —
/// it presents the camera modally instead.
enum AppTab: Hashable {
    case home
    case calendar
    case compare
    case profile
}

struct CustomTabBar: View {
    @Binding var selection: AppTab

    /// Fired when the user taps the center camera FAB.
    /// Step 4 hands this an empty closure — Step 6 wires it to present
    /// `CameraView` as a full-screen cover.
    let onCameraTap: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            tabButton(.home,     label: "Home",     icon: "house")
            tabButton(.calendar, label: "Calendar", icon: "calendar")
            cameraFAB
            tabButton(.compare,  label: "Compare",  icon: "rectangle.split.2x1")
            tabButton(.profile,  label: "Profile",  icon: "person")
        }
        .padding(.top, Theme.Spacing.sm)
        .padding(.horizontal, Theme.Spacing.md)
        .background(Theme.surface)
        .overlay(alignment: .top) {
            // 1pt hairline above the bar — the only chrome that
            // separates the bar from content.
            Rectangle()
                .fill(Theme.divider)
                .frame(height: 0.5)
        }
    }

    // MARK: - AppTab button

    private func tabButton(_ tab: AppTab, label: String, icon: String) -> some View {
        let isSelected = selection == tab
        return Button {
            selection = tab
        } label: {
            VStack(spacing: Theme.Spacing.xxs) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(isSelected ? Theme.accent : Theme.textTertiary)

                Text(label)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.xs)
            // 💡 Learn: contentShape makes the whole label tappable, not
            // just the glyph and text. Without it, gaps between the icon
            // and label are dead zones.
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Camera FAB

    private var cameraFAB: some View {
        Button {
            onCameraTap()
        } label: {
            ZStack {
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 56, height: 56)
                    // DESIGN.md: subtle FAB shadow (y=4, blur=12, opacity 0.12).
                    .shadow(color: .black.opacity(0.12), radius: 12, y: 4)

                Image(systemName: "camera.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 80)
        // Lift the FAB so it sits above the bar's top edge.
        .offset(y: -16)
        .buttonStyle(.plain)
    }
}

#Preview {
    @Previewable @State var selection: AppTab = .home
    return VStack {
        Spacer()
        Text("Selected: \(String(describing: selection))")
            .font(.caption)
            .foregroundStyle(Theme.textSecondary)
        Spacer()
        CustomTabBar(selection: $selection, onCameraTap: {})
    }
    .background(Theme.background)
}
