
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

private struct StoreProfile: Decodable {
    let role: String
}

private func signIn() async {
    isLoading = true
    errorMessage = ""
    defer { isLoading = false }

    do {
        let client = SupabaseManager.shared.client

        let response = try await client.auth.signIn(
            email: email,
            password: password
        )

        let profile: StoreProfile = try await client
            .from("profiles")
            .select("role")
            .eq("id", value: response.user.id.uuidString)
            .single()
            .execute()
            .value

        guard ["admin", "user"].contains(profile.role) else {
            try await client.auth.signOut()
            errorMessage = "هذا الحساب غير مصرح له بدخول المتجر."
            return
        }

        isLoggedIn = true
    } catch {
        errorMessage = "تعذر تسجيل الدخول: \(error.localizedDescription)"
    }
}


}
