import Foundation
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import AuthenticationServices
import CryptoKit
import GoogleSignIn

@Observable
final class AuthService {
    var currentUserID: String?
    var displayName: String = "ユーザー"
    var isSignedIn: Bool { currentUserID != nil }
    var isAnonymous: Bool {
        guard FirebaseApp.app() != nil else { return true }
        return Auth.auth().currentUser?.isAnonymous ?? true
    }

    private var currentNonce: String?

    init() {}

    func restoreSession() {
        if let user = Auth.auth().currentUser {
            currentUserID = user.uid
            displayName = UserDefaults.standard.string(forKey: "meshchat_display_name") ?? "ユーザー"
        }
    }

    func signInAnonymously() async throws {
        let result = try await Auth.auth().signInAnonymously()
        currentUserID = result.user.uid
        displayName = "ユーザー"
        MeshLogger.sync.info("Signed in anonymously: \(result.user.uid)")
    }

    func setLocalFallback() {
        let localID = UUID().uuidString
        currentUserID = localID
        displayName = "ユーザー"
        MeshLogger.general.info("Using local fallback ID: \(localID)")
    }

    // MARK: - Google Sign-In

    @MainActor
    func signInWithGoogle() async throws {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            throw AuthError.noRootVC
        }

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)

        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthError.missingToken
        }

        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )

        let authResult = try await Auth.auth().signIn(with: credential)
        currentUserID = authResult.user.uid
        displayName = "ユーザー"
        MeshLogger.sync.info("Google sign-in: \(authResult.user.uid)")
    }

    // MARK: - Apple Sign-In

    func prepareAppleSignIn() -> (ASAuthorizationAppleIDRequest, String) {
        let nonce = randomNonceString()
        currentNonce = nonce
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        return (request, nonce)
    }

    func handleAppleSignIn(authorization: ASAuthorization) async throws {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8),
              let nonce = currentNonce else {
            throw AuthError.missingToken
        }

        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )

        let authResult = try await Auth.auth().signIn(with: credential)
        currentUserID = authResult.user.uid
        displayName = "ユーザー"
        MeshLogger.sync.info("Apple sign-in: \(authResult.user.uid)")
    }

    // MARK: - Sign Out

    func signOut() throws {
        try Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
        currentUserID = nil
        displayName = "ユーザー"
    }

    // MARK: - Delete Account

    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else { return }
        let uid = user.uid

        // Delete user's messages from Firestore
        do {
            let db = Firestore.firestore()
            let snapshot = try await db.collection(MeshConfig.firestoreCollection)
                .whereField("senderID", isEqualTo: uid)
                .getDocuments()
            if !snapshot.documents.isEmpty {
                let batch = db.batch()
                for doc in snapshot.documents {
                    batch.deleteDocument(doc.reference)
                }
                try await batch.commit()
                MeshLogger.general.info("Deleted \(snapshot.documents.count) messages from Firestore")
            }
        } catch {
            MeshLogger.general.error("Failed to delete Firestore data: \(error.localizedDescription)")
        }

        // Delete user's reports
        do {
            let db = Firestore.firestore()
            let snapshot = try await db.collection("reports")
                .whereField("reporterID", isEqualTo: uid)
                .getDocuments()
            if !snapshot.documents.isEmpty {
                let batch = db.batch()
                for doc in snapshot.documents {
                    batch.deleteDocument(doc.reference)
                }
                try await batch.commit()
            }
        } catch {
            MeshLogger.general.error("Failed to delete reports: \(error.localizedDescription)")
        }

        try await user.delete()
        currentUserID = nil
        displayName = "ユーザー"
        UserDefaults.standard.removeObject(forKey: "meshchat_display_name")
        UserDefaults.standard.removeObject(forKey: "meshchat_blocked_users")
        MeshLogger.general.info("Account deleted")
    }

    // MARK: - Update Display Name

    func updateDisplayName(_ name: String) async throws {
        guard let user = Auth.auth().currentUser else { return }
        let changeRequest = user.createProfileChangeRequest()
        changeRequest.displayName = name
        try await changeRequest.commitChanges()
        displayName = name
        UserDefaults.standard.set(name, forKey: "meshchat_display_name")
    }

    // MARK: - Helpers

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }

    enum AuthError: LocalizedError {
        case noRootVC
        case missingToken

        var errorDescription: String? {
            switch self {
            case .noRootVC: return "画面が見つかりません"
            case .missingToken: return "認証トークンがありません"
            }
        }
    }
}
