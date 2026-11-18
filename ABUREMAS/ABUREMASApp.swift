
import SwiftUI
import Supabase

// MARK: - Main Application

@main
struct ABUREMASApp: App {

    @State private var isPasswordRecovery = false
    @State private var isHandlingLink = false
    @State private var recoveryError: String?

    var body: some Scene {
        WindowGroup {
            ZStack {
                if isPasswordRecovery {
                    PasswordRecoveryView {
                        isPasswordRecovery = false
                        recoveryError = nil
                    }
                } else {
                    LoginView()
                }

                if isHandlingLink {
                    Color.black.opacity(0.65)
                        .ignoresSafeArea()

                    ProgressView(
                        "جاري التحقق من رابط الاستعادة..."
                    )
                    .tint(.yellow)
                    .padding(24)
                }
            }
            .preferredColorScheme(.dark)
            .onOpenURL { url in
                Task {
                    await handleRecoveryURL(url)
                }
            }
            .alert(
                "تعذر فتح رابط الاستعادة",
                isPresented: Binding(
                    get: { recoveryError != nil },
                    set: {
                        if !$0 {
                            recoveryError = nil
                        }
                    }
                )
            ) {
                Button("حسنًا", role: .cancel) {
                    recoveryError = nil
                }
            } message: {
                Text(recoveryError ?? "")
            }
        }
    }

    // MARK: - Handle Recovery Deep Link

    @MainActor
    private func handleRecoveryURL(_ url: URL) async {

        guard url.scheme == "aburemas",
              url.host == "auth",
              url.path == "/callback" else {
            return
        }

        guard !isHandlingLink else {
            return
        }

        isHandlingLink = true
        recoveryError = nil

        defer {
            isHandlingLink = false
        }

        do {
            let client = SupabaseManager.shared.client

            _ = try await client.auth.session(from: url)

            isPasswordRecovery = true

        } catch {
            recoveryError =
                "الرابط غير صالح أو انتهت صلاحيته. " +
                "اطلب رابط استعادة جديدًا من المتجر. " +
                error.localizedDescription
        }
    }
}

// MARK: - Password Recovery Screen

struct PasswordRecoveryView: View {

    let onComplete: () -> Void

    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showPassword = false
    @State private var isCompleted = false

    private let gold = Color(
        red: 0.91,
        green: 0.73,
        blue: 0.35
    )

    private let backgroundColor = Color(
        red: 0.04,
        green: 0.07,
        blue: 0.13
    )

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {

                Spacer(minLength: 55)

                Image(systemName: "lock.rotation")
                    .font(.system(size: 66))
                    .foregroundStyle(gold)

                Text("ABUREMAS")
                    .font(
                        .system(
                            size: 34,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(gold)

                Text("تعيين كلمة مرور جديدة")
                    .font(.title2.bold())

                Text(
                    "تم التحقق من رابط الاستعادة. " +
                    "أدخل كلمة المرور الجديدة لحسابك."
                )
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

                VStack(spacing: 16) {

                    if showPassword {
                        TextField(
                            "كلمة المرور الجديدة",
                            text: $newPassword
                        )

                        TextField(
                            "تأكيد كلمة المرور",
                            text: $confirmPassword
                        )
                    } else {
                        SecureField(
                            "كلمة المرور الجديدة",
                            text: $newPassword
                        )
                        .textContentType(.newPassword)

                        SecureField(
                            "تأكيد كلمة المرور",
                            text: $confirmPassword
                        )
                        .textContentType(.newPassword)
                    }

                    Toggle(
                        "إظهار كلمة المرور",
                        isOn: $showPassword
                    )
                    .tint(gold)

                    Text(
                        "استخدم كلمة مرور قوية " +
                        "لا تقل عن 8 أحرف."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        Task {
                            await updatePassword()
                        }
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(.black)
                            } else {
                                Image(
                                    systemName: "checkmark.shield.fill"
                                )

                                Text("حفظ كلمة المرور الجديدة")
                            }
                        }
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(gold)
                    .disabled(
                        isLoading ||
                        newPassword.isEmpty ||
                        confirmPassword.isEmpty
                    )
                }
                .textFieldStyle(.roundedBorder)
                .padding(.top, 12)

                Spacer(minLength: 40)
            }
            .frame(maxWidth: 460)
            .frame(maxWidth: .infinity)
            .padding(24)
        }
        .background(backgroundColor)
        .alert(
            "تم تغيير كلمة المرور",
            isPresented: $isCompleted
        ) {
            Button("تسجيل الدخول") {
                onComplete()
            }
        } message: {
            Text(
                "تم تحديث كلمة المرور بنجاح. " +
                "يمكنك الآن تسجيل الدخول باستخدامها."
            )
        }
    }

    // MARK: - Update Password

    @MainActor
    private func updatePassword() async {

        guard !isLoading else {
            return
        }

        errorMessage = ""

        guard newPassword.count >= 8 else {
            errorMessage =
                "كلمة المرور يجب أن تكون 8 أحرف على الأقل."
            return
        }

        guard newPassword == confirmPassword else {
            errorMessage =
                "كلمتا المرور غير متطابقتين."
            return
        }

        isLoading = true

        defer {
            isLoading = false
        }

        let client = SupabaseManager.shared.client

        do {
            try await client.auth.update(
                user: UserAttributes(
                    password: newPassword
                )
            )

            try await client.auth.signOut()

            newPassword = ""
            confirmPassword = ""

            isCompleted = true

        } catch {
            errorMessage =
                "تعذر تغيير كلمة المرور: " +
                error.localizedDescription
        }
    }
}

// MARK: - Store Main View

struct ContentView: View {

    @State private var selectedTab = 0
    @State private var apps: [StoreApp] = []
    @State private var isLoadingApps = false
    @State private var appsError: String?

    // Admin authorization
    @State private var isAdmin = false

    private let gold = Color(
        red: 0.91,
        green: 0.73,
        blue: 0.35
    )

    private let backgroundColor = Color(
        red: 0.04,
        green: 0.07,
        blue: 0.13
    )

    var body: some View {
        TabView(selection: $selectedTab) {

            // Home
            NavigationStack {
                homeView
                    .navigationTitle("ABUREMAS")
            }
            .tabItem {
                Label(
                    "الرئيسية",
                    systemImage: "house.fill"
                )
            }
            .tag(0)

            // Categories
            NavigationStack {
                categoriesView
                    .navigationTitle("التصنيفات")
            }
            .tabItem {
                Label(
                    "التصنيفات",
                    systemImage: "square.grid.2x2.fill"
                )
            }
            .tag(1)

            // Account
            NavigationStack {
                accountView
                    .navigationTitle("حسابي")
            }
            .tabItem {
                Label(
                    "حسابي",
                    systemImage: "person.crop.circle"
                )
            }
            .tag(2)

            // Admin Dashboard
            if isAdmin {
                AdminDashboardView()
                    .tabItem {
                        Label(
                            "الإدارة",
                            systemImage: "shield.lefthalf.filled"
                        )
                    }
                    .tag(3)
            }
        }
        .tint(gold)
        .task {
            await loadApps()
            await checkAdminRole()
        }
    }

    // MARK: - Home

    private var homeView: some View {
        ScrollView {
            VStack(spacing: 24) {

                Image(
                    systemName: "square.stack.3d.up.fill"
                )
                .font(.system(size: 72))
                .foregroundStyle(gold)

                Text("ABUREMAS")
                    .font(
                        .system(
                            size: 34,
                            weight: .bold
                        )
                    )

                Text("متجر أبو ريماس")
                    .font(.title2)

                Text("Your Private IPA Store")
                    .foregroundStyle(.secondary)

                Divider()

                appsSection
            }
            .frame(maxWidth: .infinity)
            .padding(24)
        }
        .background(backgroundColor)
        .refreshable {
            await loadApps()
        }
    }

    // MARK: - Apps Section

    private var appsSection: some View {
        Group {

            if isLoadingApps && apps.isEmpty {

                ProgressView(
                    "جاري تحميل التطبيقات..."
                )
                .padding()

            } else if let appsError {

                VStack(spacing: 12) {

                    Image(
                        systemName: "wifi.exclamationmark"
                    )
                    .font(.system(size: 40))
                    .foregroundStyle(.orange)

                    Text("تعذر تحميل التطبيقات")
                        .font(.headline)

                    Text(appsError)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button("إعادة المحاولة") {
                        Task {
                            await loadApps()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(gold)
                }
                .padding()

            } else if apps.isEmpty {

                ContentUnavailableView(
                    "لا توجد تطبيقات حاليًا",
                    systemImage: "square.stack.3d.up",
                    description: Text(
                        "ستظهر تطبيقاتك هنا بعد إضافتها إلى المتجر"
                    )
                )

            } else {

                LazyVStack(spacing: 12) {
                    ForEach(apps) { app in
                        appRow(app)
                    }
                }
            }
        }
    }

    // MARK: - App Row

    private func appRow(_ app: StoreApp) -> some View {
        HStack(spacing: 14) {

            Image(systemName: "app.fill")
                .font(.system(size: 36))
                .foregroundStyle(gold)
                .frame(width: 52, height: 52)

            VStack(
                alignment: .leading,
                spacing: 6
            ) {

                Text(app.name)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("الإصدار \(app.version)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let description = app.description,
                   !description.isEmpty {

                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()
        }
        .padding(14)
        .background(
            Color.white.opacity(0.07)
        )
        .clipShape(
            RoundedRectangle(cornerRadius: 16)
        )
    }

    // MARK: - Categories

    private var categoriesView: some View {
        ContentUnavailableView(
            "التصنيفات",
            systemImage: "square.grid.2x2",
            description: Text(
                "سيتم تحميل التصنيفات من Supabase"
            )
        )
    }

    // MARK: - Account

    private var accountView: some View {
        ContentUnavailableView(
            "حسابي",
            systemImage: "person.crop.circle",
            description: Text(
                "سيتم إضافة إدارة الحساب وتسجيل الخروج"
            )
        )
    }

    // MARK: - Fetch Apps

    @MainActor
    private func loadApps() async {

        guard !isLoadingApps else {
            return
        }

        isLoadingApps = true
        appsError = nil

        defer {
            isLoadingApps = false
        }

        do {
            apps = try await AppService.shared.fetchApps()
        } catch {
            appsError = error.localizedDescription
        }
    }

    // MARK: - Check Admin Role

    private struct AdminProfile: Decodable {
        let role: String
    }

    @MainActor
    private func checkAdminRole() async {

        isAdmin = false

        do {
            let client = SupabaseManager.shared.client

            let session = try await client.auth.session

            let profile: AdminProfile = try await client
                .from("profiles")
                .select("role")
                .eq(
                    "id",
                    value: session.user.id.uuidString
                )
                .single()
                .execute()
                .value

            isAdmin = profile.role == "admin"

        } catch {
            isAdmin = false
        }
    }
}
