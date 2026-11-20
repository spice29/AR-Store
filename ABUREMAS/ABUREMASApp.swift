
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
    @State private var searchText = ""
    @State private var isSigningOut = false
    @State private var signOutError: String?
    @State private var downloadError: String?
    @State private var apps: [StoreApp] = []
    @State private var isLoadingApps = false
    @State private var appsError: String?

    // Admin authorization
    @State private var isAdmin = false
    @State private var adminStatus = "جاري التحقق من الصلاحية..."

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
        .alert("تعذر فتح الملف", isPresented: Binding(
            get: { downloadError != nil },
            set: { if !$0 { downloadError = nil } }
        )) {
            Button("حسنًا", role: .cancel) { downloadError = nil }
        } message: {
            Text(downloadError ?? "")
        }
        .onChange(of: selectedTab) { _, newTab in
            if newTab == 0 { Task { await loadApps() } }
        }
        .task {
            await checkAdminRole()
            await loadApps()
        }
    }

    // MARK: - Home

    private var homeView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 14) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 29))
                        .foregroundStyle(gold)
                        .frame(width: 56, height: 56)
                        .background(gold.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ABUREMAS").font(.title2.bold())
                        Text("متجر أبو ريماس الخاص")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(16)
                .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 20))

                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("التطبيقات المتاحة")
                            .font(.headline)
                        Text("تطبيقاتك المنشورة في المتجر")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(apps.count)")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(gold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(gold.opacity(0.12), in: Capsule())
                }
                TextField("ابحث عن تطبيق أو Bundle ID", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                appsSection
            }
            .frame(maxWidth: 650)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 110)
        }
        .background(backgroundColor)
        .refreshable { await loadApps() }
    }

    private var filteredApps: [StoreApp] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return apps }
        return apps.filter { $0.name.localizedCaseInsensitiveContains(query) || $0.bundleID.localizedCaseInsensitiveContains(query) || ($0.description?.localizedCaseInsensitiveContains(query) ?? false) }
    }

    private var appsSection: some View {
        Group {
            if isLoadingApps && apps.isEmpty {
                ProgressView("جاري تحميل التطبيقات...")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else if let appsError {
                VStack(spacing: 12) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text("تعذر تحميل التطبيقات").font(.headline)
                    Text(appsError)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("إعادة المحاولة") { Task { await loadApps() } }
                        .buttonStyle(.borderedProminent)
                        .tint(gold)
                }
                .frame(maxWidth: .infinity)
                .padding(22)
            } else if filteredApps.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "لا توجد تطبيقات منشورة" : "لا توجد نتائج",
                    systemImage: searchText.isEmpty ? "square.stack.3d.up" : "magnifyingglass",
                    description: Text(searchText.isEmpty ? "يمكن لمدير المتجر نشر التطبيقات من لوحة الإدارة" : "جرّب البحث باسم آخر")
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(filteredApps) { app in
                        appRow(app)
                    }
                }
            }
        }
    }

    private func appRow(_ app: StoreApp) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "app.fill")
                .font(.system(size: 29))
                .foregroundStyle(gold)
                .frame(width: 58, height: 58)
                .background(gold.opacity(0.1), in: RoundedRectangle(cornerRadius: 15))
            VStack(alignment: .leading, spacing: 5) {
                Text(app.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("الإصدار \(app.version)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let description = app.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
            if let path = app.ipaPath, !path.isEmpty {
                Button {
                    Task { await installApp(app) }
                } label: {
                    Label("تثبيت", systemImage: "square.and.arrow.down.fill")
                        .font(.subheadline.bold())
                }
                .buttonStyle(.borderedProminent)
                .tint(gold)
                .accessibilityLabel("تثبيت \(app.name)")
            } else {
                Image(systemName: "lock.shield")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 18))
    }

    private var categoriesView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("تطبيقات المتجر")
                    .font(.title3.bold())
                Text("كل التطبيقات المنشورة حاليًا")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("ابحث في التطبيقات", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                appsSection
            }
            .padding(16)
            .padding(.bottom, 100)
        }
        .background(backgroundColor)
        .refreshable { await loadApps() }
    }

    private var accountView: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 62))
                    .foregroundStyle(gold)
                Text("حسابي")
                    .font(.title2.bold())
                Label(adminStatus, systemImage: "checkmark.shield")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button(role: .destructive) {
                    Task { await signOut() }
                } label: {
                    Label("تسجيل الخروج", systemImage: "rectangle.portrait.and.arrow.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isSigningOut)
                if let signOutError {
                    Text(signOutError).font(.footnote).foregroundStyle(.red)
                }
                Text("ABUREMAS • متجر خاص")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))
            .padding(16)
        }
        .background(backgroundColor)
    }

    private struct InstallResponse: Decodable {
        let installUrl: String
    }

    @MainActor
    private func installApp(_ app: StoreApp) async {
        do {
            let session = try await SupabaseManager.shared.client.auth.session
            let endpoint = SupabaseConfig.projectURL.appending(path: "functions/v1/ota-install")
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue(SupabaseConfig.publishableKey, forHTTPHeaderField: "apikey")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: ["appId": app.id.uuidString])
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw URLError(.cannotLoadFromNetwork)
            }
            let payload = try JSONDecoder().decode(InstallResponse.self, from: data)
            guard let url = URL(string: payload.installUrl), url.scheme == "itms-services" else {
                throw URLError(.badURL)
            }
            await UIApplication.shared.open(url)
        } catch {
            downloadError = "تعذر بدء التثبيت. تحقق من نشر خدمة ota-install وصلاحيات الحساب وتوقيع Ad Hoc: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func openAppFile(_ path: String) async {
        do {
            let url: URL
            if path.hasPrefix("https://") {
                guard let external = URL(string: path), external.scheme == "https",
                      external.host != nil else {
                    throw URLError(.badURL)
                }
                url = external
            } else {
                guard path.hasPrefix("apps/"), path.lowercased().hasSuffix(".ipa"),
                      !path.contains("..") else {
                    throw URLError(.badURL)
                }
                url = try await SupabaseManager.shared.client.storage
                    .from("ipa-files")
                    .createSignedURL(path: path, expiresIn: 300)
            }
            // The signed link grants temporary file access, not automatic iOS installation.
            await UIApplication.shared.open(url)
        } catch {
            downloadError = "تعذر تجهيز رابط التنزيل: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func signOut() async {
        guard !isSigningOut else { return }
        isSigningOut = true
        signOutError = nil
        defer { isSigningOut = false }
        do {
            try await SupabaseManager.shared.client.auth.signOut()
            NotificationCenter.default.post(name: .aburemasDidSignOut, object: nil)
        } catch {
            signOutError = error.localizedDescription
        }
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
            adminStatus = isAdmin ? "تم التحقق: مدير المتجر" : "صلاحية الحساب: \(profile.role)"

        } catch {
            isAdmin = false
            adminStatus = "خطأ في قراءة صلاحية الحساب: \(error.localizedDescription)"
        }
    }
}
