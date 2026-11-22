
import SwiftUI
import Supabase

struct LoginView: View {
    @AppStorage("aburemas.lastLoginEmail") private var email = ""
    @State private var isCheckingSession = true
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var isLoggedIn = false

    @State private var showRecovery = false
    @State private var recoveryStep = 0
    @State private var recoveryCode = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var recoveryMessage = ""

    private let gold = Color(
        red: 0.91,
        green: 0.73,
        blue: 0.35
    )

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {

                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(gold)

                Text("ABUREMAS")
                    .font(.system(size: 24, weight: .bold))

                Text("متجر أبو ريماس الخاص")
                    .foregroundStyle(.secondary)

                if isCheckingSession {
                    ProgressView("جاري استعادة جلسة الدخول...").tint(gold).padding(.vertical, 20)
                } else if showRecovery {
                    recoveryForm
                } else {
                    loginForm
                }

            }
            .frame(maxWidth: 380)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(red: 0.04, green: 0.07, blue: 0.13).ignoresSafeArea())
        .fullScreenCover(isPresented: $isLoggedIn) {
            ContentView()
        }
        .task { await restoreSession() }
        .onReceive(NotificationCenter.default.publisher(for: .aburemasDidSignOut)) { _ in
            isLoggedIn = false
            password = ""
        }
    }

    // MARK: - Login

    private var loginForm: some View {
        VStack(spacing: 16) {
            emailField

            SecureField(
                "كلمة المرور",
                text: $password
            )
            .textContentType(.password)
            .textFieldStyle(.roundedBorder)

            errorView

            Button {
                Task {
                    await signIn()
                }
            } label: {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("دخول المتجر")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(gold)
            .disabled(
                isLoading ||
                email.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).isEmpty ||
                password.isEmpty
            )

            Button("نسيت كلمة المرور؟") {
                errorMessage = ""
                recoveryMessage = ""
                recoveryStep = 0
                showRecovery = true
            }
            .foregroundStyle(gold)
        }
    }

    // MARK: - Password Recovery

    private var recoveryForm: some View {
        VStack(spacing: 16) {
            Text("استعادة كلمة المرور")
                .font(.title3.bold())

            if recoveryStep == 0 {
                Text("أدخل بريدك لإرسال رابط الاستعادة")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                emailField

                Button("إرسال رابط الاستعادة") {
                    Task {
                        await sendRecovery()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(gold)
                .disabled(
                    isLoading ||
                    email.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ).isEmpty
                )

            } else {
                Text(
                    "تم طلب رابط الاستعادة. افتح بريدك الإلكتروني واضغط على رابط Reset password."
                )
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

                Button("إعادة إرسال الرابط") {
                    Task {
                        await sendRecovery()
                    }
                }
                .disabled(isLoading)
            }

            if isLoading {
                ProgressView()
            }

            if !recoveryMessage.isEmpty {
                Text(recoveryMessage)
                    .foregroundStyle(.green)
                    .multilineTextAlignment(.center)
            }

            errorView

            Button("العودة لتسجيل الدخول") {
                showRecovery = false
                recoveryMessage = ""
                errorMessage = ""
                recoveryCode = ""
                newPassword = ""
                confirmPassword = ""
            }
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Email Field

    private var emailField: some View {
        TextField(
            "البريد الإلكتروني",
            text: $email
        )
        .textContentType(.emailAddress)
        .keyboardType(.emailAddress)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .textFieldStyle(.roundedBorder)
    }

    // MARK: - Error View

    @ViewBuilder
    private var errorView: some View {
        if !errorMessage.isEmpty {
            Text(errorMessage)
                .foregroundStyle(.red)
                .font(.footnote)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Profile

    private struct StoreProfile: Decodable {
        let role: String
    }

    @MainActor
    private func restoreSession() async {
        isCheckingSession = true
        defer { isCheckingSession = false }
        let client = SupabaseManager.shared.client
        do {
            let session = try await client.auth.session
            let profile: StoreProfile = try await client
                .from("profiles")
                .select("role")
                .eq("id", value: session.user.id.uuidString)
                .single()
                .execute()
                .value
            guard ["admin", "user"].contains(profile.role) else {
                try? await client.auth.signOut()
                return
            }
            email = session.user.email ?? email
            password = ""
            isLoggedIn = true
        } catch {
            isLoggedIn = false
        }
    }

    // MARK: - Sign In

    @MainActor
    private func signIn() async {
        guard !isLoading else {
            return
        }

        isLoading = true
        errorMessage = ""

        defer {
            isLoading = false
        }

        let client = SupabaseManager.shared.client

        do {
            let response = try await client.auth.signIn(
                email: email.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ),
                password: password
            )

            let profile: StoreProfile = try await client
                .from("profiles")
                .select("role")
                .eq(
                    "id",
                    value: response.user.id.uuidString
                )
                .single()
                .execute()
                .value

            guard ["admin", "user"].contains(profile.role) else {
                try await client.auth.signOut()

                errorMessage =
                    "هذا الحساب غير مصرح له بدخول المتجر."

                return
            }

            password = ""
            isLoggedIn = true

        } catch {
            errorMessage =
                "تعذر تسجيل الدخول: \(error.localizedDescription)"
        }
    }

    // MARK: - Send Recovery Link

    @MainActor
    private func sendRecovery() async {
        guard !isLoading else {
            return
        }

        isLoading = true
        errorMessage = ""
        recoveryMessage = ""

        defer {
            isLoading = false
        }

        do {
            try await SupabaseManager.shared.client.auth
                .resetPasswordForEmail(
                    email.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ),
                    redirectTo: URL(
                        string: "aburemas://auth/callback"
                    )!
                )

            recoveryStep = 1

            recoveryMessage =
                "إذا كان البريد مسجلًا، ستصلك رسالة تحتوي على رابط استعادة كلمة المرور."

        } catch {
            errorMessage =
                "تعذر إرسال رابط الاستعادة: \(error.localizedDescription)"
        }
    }
}


extension Notification.Name {
    static let aburemasDidSignOut = Notification.Name("aburemasDidSignOut")
}
