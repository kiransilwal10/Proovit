//
//  ProgressReelMode.swift
//  Proovit
//
//  The Compare → Progress Reel branch. State machine:
//
//      .idle ─generate─▶ .generating ─done─▶ .ready ─share─▶ system sheet
//                                  └err──▶ .failed ─retry─▶ .idle
//
//  Generation runs through `VideoComposer.compose`. Playback uses
//  SwiftUI's built-in `VideoPlayer` (AVKit) — no UIKit bridge needed.
//

import AVKit
import SwiftUI

struct ProgressReelMode: View {
    let tracker: Tracker?
    let entries: [ProgressEntry]

    @State private var state: ReelState = .idle

    enum ReelState {
        case idle
        case generating
        case ready(URL)
        case failed(String)
    }

    var body: some View {
        Group {
            switch state {
            case .idle:                idleCard
            case .generating:          generatingCard
            case .ready(let url):      readyCard(url: url)
            case .failed(let message): failedCard(message: message)
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
    }

    // MARK: - Idle

    private var idleCard: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Theme.accent)

            Text("Generate Progress Reel")
                .font(.title3.bold())
                .foregroundStyle(Theme.textPrimary)

            Text(idleSubtitle)
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                Task { await generate() }
            } label: {
                Text("Generate")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(canGenerate ? Theme.accent : Theme.accent.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium))
            }
            .disabled(!canGenerate)
            .padding(.top, Theme.Spacing.sm)
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium))
    }

    private var idleSubtitle: String {
        if entries.isEmpty {
            return "Capture some photos for this tracker first."
        }
        let count = entries.count
        return "Combine your \(count) photo\(count == 1 ? "" : "s") into a shareable timelapse."
    }

    private var canGenerate: Bool {
        !entries.isEmpty && tracker != nil
    }

    // MARK: - Generating

    private var generatingCard: some View {
        VStack(spacing: Theme.Spacing.md) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(Theme.accent)
            Text("Generating reel…")
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
            Text("This can take a few seconds for long histories.")
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(Theme.Spacing.xxl)
        .frame(maxWidth: .infinity)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium))
    }

    // MARK: - Ready

    private func readyCard(url: URL) -> some View {
        VStack(spacing: Theme.Spacing.md) {
            // 💡 Learn: SwiftUI's VideoPlayer (AVKit) wraps an AVPlayer
            // internally, so we don't need a UIViewRepresentable. Pass
            // a fresh AVPlayer so each generation gets its own playback.
            VideoPlayer(player: AVPlayer(url: url))
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium))

            ShareLink(item: url) {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share progress reel")
                        .font(.body.weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.md)
                .background(Theme.accent)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium))
            }
            .buttonStyle(.plain)

            Button {
                state = .idle
            } label: {
                Text("Regenerate")
                    .font(.body)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    // MARK: - Failed

    private func failedCard(message: String) -> some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Theme.danger)

            Text("Couldn't generate reel")
                .font(.title3.bold())
                .foregroundStyle(Theme.textPrimary)

            Text(message)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)

            Button("Try again") {
                state = .idle
            }
            .foregroundStyle(Theme.accent)
            .padding(.top, Theme.Spacing.sm)
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.medium))
    }

    // MARK: - Generation

    private func generate() async {
        state = .generating

        guard let store = try? PhotoStore() else {
            state = .failed("Couldn't access photo storage.")
            return
        }

        do {
            let url = try await VideoComposer.compose(
                entries: entries,
                photoStore: store
            )
            state = .ready(url)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
