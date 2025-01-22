import SwiftUI

struct ProfileView: View {
    let authService: AuthService
    let onSignOut: () -> Void

    @State private var editingName = ""
    @State private var isEditing = false
    @State private var showDeleteConfirm = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 4) {
                            if isEditing {
                                TextField("表示名", text: $editingName)
                                    .textFieldStyle(.roundedBorder)
                            } else {
                                Text(authService.displayName)
                                    .font(.title3.bold())
                            }
                            Text(authService.currentUserID?.prefix(12).description ?? "")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("表示名") {
                    if isEditing {
                        Button("保存") {
                            Task {
                                let name = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !name.isEmpty else { return }
                                do {
                                    try await authService.updateDisplayName(name)
                                    isEditing = false
                                } catch {
                                    errorMessage = error.localizedDescription
                                }
                            }
                        }
                        Button("キャンセル") {
                            isEditing = false
                        }
                        .foregroundStyle(.secondary)
                    } else {
                        Button("表示名を変更") {
                            editingName = authService.displayName
                            isEditing = true
                        }
                    }
                }

                Section {
                    Button("ログアウト") {
                        do {
                            try authService.signOut()
                            onSignOut()
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                    .foregroundStyle(.orange)
                }

                Section {
                    Button("アカウントを削除") {
                        showDeleteConfirm = true
                    }
                    .foregroundStyle(.red)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("プロフィール")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
            .alert("アカウントを削除しますか？", isPresented: $showDeleteConfirm) {
                Button("削除", role: .destructive) {
                    Task {
                        do {
                            try await authService.deleteAccount()
                            onSignOut()
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("この操作は取り消せません")
            }
        }
    }
}
