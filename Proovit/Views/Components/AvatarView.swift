//
//  AvatarView.swift
//  Proovit
//
//  Circular initials avatar. Used in two places: small (~36pt) on the
//  Home top-right, and large (~72pt) on the Profile screen. The size
//  is a parameter so we don't ship two near-duplicate views.
//

import SwiftUI

struct AvatarView: View {
    let initials: String
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.surface)
                .overlay(
                    Circle().stroke(Theme.divider, lineWidth: 1)
                )

            // 💡 Learn: Sizing the font as a fraction of the bounding circle
            // means the initials scale with `size` automatically — no
            // separate font ramp to maintain.
            Text(initials)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    HStack(spacing: Theme.Spacing.lg) {
        AvatarView(initials: "K", size: 36)
        AvatarView(initials: "KS", size: 56)
        AvatarView(initials: "?", size: 72)
    }
    .padding(Theme.Spacing.xl)
    .background(Theme.background)
}
