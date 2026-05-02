//
//  TabPlaceholderView.swift
//  Proovit
//
//  A neutral "screen not built yet" view used by RootTabView for the
//  Calendar, Compare, and Profile tabs in the early steps. Each tab
//  gets its real implementation in a later step (8, 9, 10) and this
//  placeholder goes away.
//

import SwiftUI

struct TabPlaceholderView: View {
    let title: String
    let comingInStep: Int

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: Theme.Spacing.md) {
                Text(title)
                    .font(.largeTitle.bold())
                    .foregroundStyle(Theme.textPrimary)

                Text("Coming in Step \(comingInStep)")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
            }
        }
    }
}

#Preview {
    TabPlaceholderView(title: "Calendar", comingInStep: 8)
}
