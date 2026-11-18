
import SwiftUI

@main
struct ABUREMASApp: App {
    var body: some Scene {
        WindowGroup {
            LoginView()
                .preferredColorScheme(.dark)
        }
    }
}

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var apps: [StoreApp] = []
    @State private var isLoadingApps = false
    @State private var appsError: String?

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
            NavigationStack {
                homeView
                    .navigationTitle("ABUREMAS")
            }
            .tabItem {
                Label("الرئيسية", systemImage: "house.fill")
            }
            .tag(0)

            NavigationStack {
                categoriesView
                    .navigationTitle("التصنيفات")
            }
            .tabItem {
                Label("التصنيفات", systemImage: "square.grid.2x2.fill")
            }
            .tag(1)

            NavigationStack {
                accountView
                    .navigationTitle("حسابي")
            }
            .tabItem {
                Label("حسابي", systemImage: "person.crop.circle")
            }
            .tag(2)
        }
        .tint(gold)
        .task {
            await loadApps()
        }
    }

    // MARK: - Home

    private var homeView: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(gold)

                Text("ABUREMAS")
                    .font(.system(size: 34, weight: .bold))

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

    // MARK: - Apps

    private var appsSection: some View {
        Group {
            if isLoadingApps && apps.isEmpty {
                ProgressView("جاري تحميل التطبيقات...")
                    .padding()

            } else if let appsError {
                VStack(spacing: 12) {
                    Image(systemName: "wifi.exclamationmark")
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

            VStack(alignment: .leading, spacing: 6) {
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
        .background(Color.white.opacity(0.07))
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

    // MARK: - Supabase

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
}
