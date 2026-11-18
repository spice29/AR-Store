
import SwiftUI
import Supabase

private struct AdminApp: Identifiable, Decodable {
    let id: UUID
    let name: String
    let bundleID: String
    let version: String
    let published: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, version, published
        case bundleID = "bundle_id"
    }
}

private struct NewStoreApp: Encodable {
    let name: String
    let bundleID: String
    let version: String
    let description: String?
    let ipaPath: String?
    let published: Bool

    enum CodingKeys: String, CodingKey {
        case name, version, description, published
        case bundleID = "bundle_id"
        case ipaPath = "ipa_path"
    }
}

struct AdminDashboardView: View {
    @State private var apps: [AdminApp] = []
    @State private var loading = false
    @State private var errorMessage = ""
    @State private var showAdd = false

    private let gold = Color(
        red: 0.91, green: 0.73, blue: 0.35
    )

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 54))
                        .foregroundStyle(gold)

                    Text("لوحة إدارة ABUREMAS")
                        .font(.title2.bold())

                    HStack(spacing: 12) {
                        stat("التطبيقات", apps.count)
                        stat(
                            "المنشورة",
                            apps.filter(\.published).count
                        )
                        stat(
                            "المسودات",
                            apps.filter { !$0.published }.count
                        )
                    }

                    Button {
                        showAdd = true
                    } label: {
                        Label(
                            "إضافة تطبيق جديد",
                            systemImage: "plus.circle.fill"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(gold)

                    if loading {
                        ProgressView("جاري تحميل التطبيقات...")
                    }

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }

                    ForEach(apps) { app in
                        HStack {
                            Image(systemName: "app.fill")
                                .foregroundStyle(gold)

                            VStack(alignment: .leading) {
                                Text(app.name)
                                    .font(.headline)
                                Text(app.bundleID)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("الإصدار \(app.version)")
                                    .font(.caption)
                            }

                            Spacer()

                            Text(
                                app.published
                                ? "منشور" : "مسودة"
                            )
                            .font(.caption)
                            .foregroundStyle(
                                app.published ? .green : .orange
                            )
                        }
                        .padding()
                        .background(.white.opacity(0.06))
                        .clipShape(
                            RoundedRectangle(cornerRadius: 14)
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("الإدارة")
            .toolbar {
                Button {
                    Task { await loadApps() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .task {
                await loadApps()
            }
            .sheet(isPresented: $showAdd, onDismiss: {
                Task { await loadApps() }
            }) {
                AddStoreAppView()
            }
        }
    }

    private func stat(_ title: String, _ value: Int) -> some View {
        VStack(spacing: 8) {
            Text("\(value)")
                .font(.title.bold())
                .foregroundStyle(gold)
            Text(title)
                .font(.caption)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @MainActor
    private func loadApps() async {
        guard !loading else { return }
        loading = true
        errorMessage = ""
        defer { loading = false }

        do {
            apps = try await SupabaseManager.shared.client
                .from("apps")
                .select(
                    "id,name,bundle_id,version,published"
                )
                .order("created_at", ascending: false)
                .execute()
                .value
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct AddStoreAppView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var bundleID = ""
    @State private var version = ""
    @State private var appDescription = ""
    @State private var ipaURL = ""
    @State private var saving = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("بيانات التطبيق") {
                    TextField("اسم التطبيق", text: $name)
                    TextField("Bundle ID", text: $bundleID)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("الإصدار", text: $version)
                    TextField(
                        "الوصف",
                        text: $appDescription,
                        axis: .vertical
                    )
                }

                Section("ملف التطبيق") {
                    TextField(
                        "رابط IPA - HTTPS",
                        text: $ipaURL
                    )
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                }

                Section {
                    Text(
                        "سيُحفظ التطبيق كمسودة غير منشورة."
                    )
                    .foregroundStyle(.secondary)
                }

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }

                Button {
                    Task { await save() }
                } label: {
                    if saving {
                        ProgressView()
                    } else {
                        Text("حفظ التطبيق")
                    }
                }
                .disabled(
                    saving ||
                    name.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ).isEmpty ||
                    bundleID.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ).isEmpty ||
                    version.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ).isEmpty
                )
            }
            .navigationTitle("إضافة تطبيق")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("إلغاء") {
                        dismiss()
                    }
                }
            }
        }
    }

    @MainActor
    private func save() async {
        guard !saving else { return }

        let link = ipaURL.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        if !link.isEmpty {
            guard let url = URL(string: link),
                  url.scheme?.lowercased() == "https",
                  url.host != nil else {
                errorMessage = "أدخل رابط HTTPS صالحًا."
                return
            }
        }

        saving = true
        errorMessage = ""
        defer { saving = false }

        let newApp = NewStoreApp(
            name: name.trimmingCharacters(
                in: .whitespacesAndNewlines
            ),
            bundleID: bundleID.trimmingCharacters(
                in: .whitespacesAndNewlines
            ),
            version: version.trimmingCharacters(
                in: .whitespacesAndNewlines
            ),
            description: appDescription.isEmpty
                ? nil : appDescription,
            ipaPath: link.isEmpty ? nil : link,
            published: false
        )

        do {
            try await SupabaseManager.shared.client
                .from("apps")
                .insert(newApp)
                .execute()

            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
