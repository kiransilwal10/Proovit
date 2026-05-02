//
//  EditProfileSheet.swift
//  Proovit
//
//  Renames the user's display name. Lives in its own file because
//  it's the only sheet that mutates UserProfile.displayName, and
//  there are several future entry points (avatar tap, settings menu)
//  that may want to present it.
//

import SwiftUI

struct EditProfileSheet: View {

    @Bindable var profile: UserProfile

    @Environment(\.dismiss) private var dismiss

    @State private var name: String

    init(profile: UserProfile) {
        self.profile = profile
        _name = State(initialValue: profile.displayName)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Your name", text: $name)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .onSubmit {
                            if canSave { save() }
                        }
                } header: {
                    Text("DISPLAY NAME")
                        .foregroundStyle(Theme.textSecondary)
                } footer: {
                    Text("Shown on the Home screen and in the Profile tab. Stays on this device.")
                        .foregroundStyle(Theme.textTertiary)
                }
                .listRowBackground(Theme.surface)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        guard canSave else { return }
        profile.displayName = trimmedName
        dismiss()
    }
}
