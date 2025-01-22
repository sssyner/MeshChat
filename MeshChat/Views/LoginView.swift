import SwiftUI
import AuthenticationServices

struct LoginView: View {
    let authService: AuthService
    let onComplete: () -> Void

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var agreedToTerms = false
    @State private var showTerms = false
    @State private var showPrivacy = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text("MeshChat")
                .font(.largeTitle.bold())

            Text("災害時メッシュメッセージング")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            if isLoading {
                ProgressView()
            } else {
                VStack(spacing: 12) {
                    // Terms agreement
                    HStack(alignment: .top, spacing: 8) {
                        Button {
                            agreedToTerms.toggle()
                        } label: {
                            Image(systemName: agreedToTerms ? "checkmark.square.fill" : "square")
                                .foregroundStyle(agreedToTerms ? .blue : .gray)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 0) {
                                Button("利用規約") { showTerms = true }
                                    .font(.subheadline)
                                Text("と")
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                Button("プライバシーポリシー") { showPrivacy = true }
                                    .font(.subheadline)
                                Text("に同意する")
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)

                    // Appleでサインイン
                    SignInWithAppleButton(.signIn) { request in
                        let (appleRequest, _) = authService.prepareAppleSignIn()
                        request.requestedScopes = appleRequest.requestedScopes
                        request.nonce = appleRequest.nonce
                    } onCompletion: { result in
                        Task {
                            isLoading = true
                            defer { isLoading = false }
                            do {
                                switch result {
                                case .success(let authorization):
                                    try await authService.handleAppleSignIn(authorization: authorization)
                                    onComplete()
                                case .failure(let error):
                                    errorMessage = error.localizedDescription
                                }
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        }
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .disabled(!agreedToTerms)
                    .opacity(agreedToTerms ? 1 : 0.5)

                    // Googleでサインイン
                    Button {
                        Task {
                            isLoading = true
                            defer { isLoading = false }
                            do {
                                try await authService.signInWithGoogle()
                                onComplete()
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "g.circle.fill")
                                .font(.title3)
                            Text("Googleでサインイン")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                        )
                    }
                    .disabled(!agreedToTerms)
                    .opacity(agreedToTerms ? 1 : 0.5)

                    // ログインせず続行
                    Button {
                        onComplete()
                    } label: {
                        Text("ログインせずに続ける")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .disabled(!agreedToTerms)
                    .opacity(agreedToTerms ? 1 : 0.5)
                    .padding(.top, 8)
                }
                .padding(.horizontal, 24)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            Spacer().frame(height: 32)
        }
        .background(Color(.systemBackground))
        .sheet(isPresented: $showTerms) {
            TermsSheet()
        }
        .sheet(isPresented: $showPrivacy) {
            PrivacyPolicySheet()
        }
    }
}
