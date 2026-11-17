
import SwiftUI

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var isLoggedIn = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 60))
                .foregroundStyle(.yellow)

            Text("ABUREMAS")
                .font(.largeTitle.bold())

            Text("تسجيل الدخول للمتجر الخاص")
                .foregroundStyle(.secondary)

            TextField("البريد الإلكتروني", text: $email)
                .textContentType(.username)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)

            SecureField("كلمة المرور", text: $password)
                .textContentType(.password)
                .textFieldStyle(.roundedBorder)

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.footnote)
            }

            Button {
                Task { await signIn() }
            } label: {
                if isLoading {
                    ProgressView()
                } else {
                    Text("دخول المتجر")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading || email.isEmpty || password.isEmpty)
        }
        .padding(24)
        .fullScreenCover(isPresented: $isLoggedIn) {
            ContentView()
        }
    }

    private func signIn() async {
        isLoading = true
        errorMessage = ""
        defer { isLoading = false }

        do {
            try await SupabaseManager.shared.client.auth.signIn(
                email: email,
                password: password
            )
            isLoggedIn = true
        } catch {
            errorMessage = "تعذر تسجيل الدخول: \(error.localizedDescription)"
        }
    }
}
