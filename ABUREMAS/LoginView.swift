
import SwiftUI
import Supabase

struct LoginView: View {
    @State private var email = ""
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
            VStack(spacing: 22) {
                Spacer(minLength: 50)

                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(gold)

                Text("ABUREMAS")
                    .font(.system(size: 36, weight: .bold))

                Text("متجر أبو ريماس الخاص")
                    .foregroundStyle(.secondary)

                if showRecovery {
                    recoveryForm
                } else {
                    loginForm
                }

                Spacer(minLength: 40)
            }
            .frame(maxWidth: 460)
            .frame(maxWidth: .infinity)
            .padding(24)
        }
        .fullScreenCover(isPresented: $isLoggedIn) {
            ContentView()
        }
    }

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
                Task { await signIn() }
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

    private var recoveryForm: some View {
        VStack(spacing: 16) {
            Text("استعادة كلمة المرور")
                .font(.title3.bold())

            if recoveryStep == 0 {
                Text("أدخل بريدك لإرسال رمز الاستعادة")
                    .foregroundStyle(.secondary)

                emailField

                Button("إرسال رمز الاستعادة") {
                    Task { await sendRecovery() }
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
                Text("أدخل الرمز المرسل إلى بريدك")
                    .foregroundStyle(.secondary)

                TextField(
                    "رمز التحقق",
                    text: $recoveryCode
                )
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .textFieldStyle(.roundedBorder)

                SecureField(
                    "كلمة المرور الجديدة",
                    text: $newPassword
                )
                .textContentType(.newPassword)
                .textFieldStyle(.roundedBorder)

                SecureField(
                    "تأكيد كلمة المرور",
                    text: $confirmPassword
                )
                .textContentType(.newPassword)
                .textFieldStyle(.roundedBorder)

                Button("تغيير كلمة المرور") {
                    Task { await resetPassword() }
                }
                .buttonStyle(.borderedProminent)
                .tint(gold)
                .disabled(
                    isLoading ||
                    recoveryCode.isEmpty ||
                    newPassword.isEmpty ||
                    confirmPassword.isEmpty
                )

                Button("إعادة إرسال الرمز") {
                    Task { await sendRecovery() }
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

    @ViewBuilder
    private var errorView: some View {
        if !errorMessage.isEmpty {
            Text(errorMessage)
                .foregroundStyle(.red)
                .font(.footnote)
                .multilineTextAlignment(.center)
        }
    }

    private struct StoreProfile: Decodable {
        let role: String
    }

    @MainActor
    private func signIn() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = ""
        defer { isLoading = false }

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
                errorMessage = "هذا الحساب غير مصرح له."
                return
            }

            password = ""
            isLoggedIn = true

        } catch {
            errorMessage =
                "تعذر تسجيل الدخول: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func sendRecovery() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = ""
        recoveryMessage = ""
        defer { isLoading = false }

        do {
            try await SupabaseManager.shared.client.auth
                .resetPasswordForEmail(
                    email.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                )

            recoveryStep = 1
            recoveryMessage =
                "إذا كان البريد مسجلًا، ستصلك رسالة الاستعادة."

        } catch {
            errorMessage =
                "تعذر إرسال الرمز: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func resetPassword() async {
        guard !isLoading else { return }

        guard newPassword.count >= 8 else {
            errorMessage =
                "كلمة المرور يجب أن تكون 8 أحرف على الأقل."
            return
        }

        guard newPassword == confirmPassword else {
            errorMessage = "كلمتا المرور غير متطابقتين."
            return
        }

        isLoading = true
        errorMessage = ""
        recoveryMessage = ""
        defer { isLoading = false }

        let client = SupabaseManager.shared.client

        do {
            try await client.auth.verifyOTP(
                email: email.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ),
                token: recoveryCode.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ),
                type: .recovery
            )

            try await client.auth.update(
                user: UserAttributes(
                    password: newPassword
                )
            )

            try await client.auth.signOut()

            password = ""
            newPassword = ""
            confirmPassword = ""
            recoveryCode = ""
            recoveryStep = 0
            showRecovery = false

            recoveryMessage = ""
            errorMessage = ""

        } catch {
            errorMessage =
                "فشلت الاستعادة: \(error.localizedDescription)"
        }
    }
}
