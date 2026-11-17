
import SwiftUI

@main
struct ABUREMASApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}

struct ContentView: View {
    @State private var selectedTab = 0

    private let gold = Color(
        red: 0.91,
        green: 0.73,
        blue: 0.35
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
    }

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

                ContentUnavailableView(
                    "التطبيقات",
                    systemImage: "square.stack.3d.up",
                    description: Text(
                        "ستظهر تطبيقاتك هنا بعد ربط Supabase"
                    )
                )
            }
            .frame(maxWidth: .infinity)
            .padding(24)
        }
        .background(Color(red: 0.04, green: 0.07, blue: 0.13))
    }

    private var categoriesView: some View {
        ContentUnavailableView(
            "التصنيفات",
            systemImage: "square.grid.2x2",
            description: Text(
                "سيتم تحميل التصنيفات من Supabase"
            )
        )
    }

    private var accountView: some View {
        ContentUnavailableView(
            "حسابي",
            systemImage: "person.crop.circle",
            description: Text(
                "سيتم إضافة تسجيل الدخول وإدارة الحساب"
            )
        )
    }
}
