import SwiftUI
import Supabase
import UniformTypeIdentifiers

private extension UTType {
    static let ipaArchive = UTType(importedAs: "com.apple.itunes.ipa", conformingTo: .data)
}

private struct AdminApp: Identifiable, Decodable {
    let id: UUID
    let name: String
    let bundleID: String
    let version: String
    let description: String?
    let ipaPath: String?
    let sizeBytes: Int64?
    let published: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, version, description, published
        case sizeBytes = "size_bytes"
        case bundleID = "bundle_id"
        case ipaPath = "ipa_path"
    }
}

private struct AppPayload: Encodable {
    let name: String
    let bundleID: String
    let version: String
    let description: String?
    let ipaPath: String?
    let sizeBytes: Int64?
    let published: Bool

    enum CodingKeys: String, CodingKey {
        case name, version, description, published
        case sizeBytes = "size_bytes"
        case bundleID = "bundle_id"
        case ipaPath = "ipa_path"
    }
}

struct AdminDashboardView: View {
    @State private var apps: [AdminApp] = []
    @State private var loading = false
    @State private var errorMessage = ""
    @State private var showingEditor = false
    @State private var editingApp: AdminApp?

    private let gold = Color(red: 0.91, green: 0.73, blue: 0.35)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 42))
                        .foregroundStyle(gold)

                    Text("لوحة إدارة ABUREMAS")
                        .font(.title3.bold())
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.75)

                    HStack(spacing: 8) {
                        stat("الكل", apps.count)
                        stat("منشور", apps.filter(\.published).count)
                        stat("مسودة", apps.filter { !$0.published }.count)
                    }

                    Button {
                        editingApp = nil
                        showingEditor = true
                    } label: {
                        Label("إضافة تطبيق جديد", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(gold)

                    if loading {
                        ProgressView("جاري تحميل التطبيقات...")
                    }

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    ForEach(apps) { app in
                        Button {
                            editingApp = app
                            showingEditor = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "app.fill")
                                    .font(.title2)
                                    .foregroundStyle(gold)
                                    .frame(width: 38)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(app.name)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text(app.bundleID)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                    Text("الإصدار \(app.version)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if let bytes = app.sizeBytes, bytes > 0 {
                                    Text(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 4)
                                VStack(alignment: .trailing, spacing: 6) {
                                    Text(app.published ? "منشور" : "مسودة")
                                        .font(.caption.bold())
                                        .foregroundStyle(app.published ? .green : .orange)
                                    Image(systemName: "pencil.circle")
                                        .foregroundStyle(gold)
                                }
                            }
                            .padding(14)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 120)
            }
            .navigationTitle("الإدارة")
            .toolbar {
                Button {
                    Task { await loadApps() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .task { await loadApps() }
            .refreshable { await loadApps() }
            .sheet(isPresented: $showingEditor, onDismiss: {
                Task { await loadApps() }
            }) {
                AppEditorView(app: editingApp)
            }
        }
    }

    private func stat(_ title: String, _ value: Int) -> some View {
        VStack(spacing: 5) {
            Text("\(value)")
                .font(.title2.bold())
                .foregroundStyle(gold)
            Text(title)
                .font(.caption.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
                .select("id,name,bundle_id,version,description,ipa_path,size_bytes,published")
                .order("created_at", ascending: false)
                .execute()
                .value
        } catch {
            errorMessage = "تعذر تحميل التطبيقات: \(error.localizedDescription)"
        }
    }
}

private struct AppEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let app: AdminApp?

    @State private var name: String
    @State private var bundleID: String
    @State private var version: String
    @State private var appDescription: String
    @State private var ipaURL: String
    @State private var useFile = false
    @State private var selectedIPA: Data?
    @State private var selectedSize: Int64 = 0
    @State private var manualSizeMB = ""
    @State private var selectedFilename = ""
    @State private var showingImporter = false
    @State private var published: Bool
    @State private var saving = false
    @State private var errorMessage = ""
    @State private var saveStatus = ""

    private let gold = Color(red: 0.91, green: 0.73, blue: 0.35)

    init(app: AdminApp?) {
        self.app = app
        _name = State(initialValue: app?.name ?? "")
        _bundleID = State(initialValue: app?.bundleID ?? "")
        _version = State(initialValue: app?.version ?? "1.0")
        _appDescription = State(initialValue: app?.description ?? "")
        _ipaURL = State(initialValue: app?.ipaPath?.hasPrefix("https://") == true ? app!.ipaPath! : "")
        _published = State(initialValue: app?.published ?? false)
        _manualSizeMB = State(initialValue: app?.sizeBytes.map { String(format: "%.2f", Double($0) / 1_048_576) } ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("بيانات التطبيق") {
                    TextField("اسم التطبيق", text: $name)
                    TextField("Bundle ID", text: $bundleID)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("الإصدار", text: $version)
                    TextField("الحجم بالميجابايت (للرابط الخارجي)", text: $manualSizeMB)
                        .keyboardType(.decimalPad)
                    TextField("الوصف", text: $appDescription, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section("مصدر ملف IPA") {
                    Picker("المصدر", selection: $useFile) {
                        Text("رابط خارجي").tag(false)
                        Text("من الملفات").tag(true)
                    }
                    .pickerStyle(.segmented)

                    if useFile {
                        Button {
                            showingImporter = true
                        } label: {
                            Label("اختيار IPA من الملفات", systemImage: "folder")
                        }
                        if !selectedFilename.isEmpty {
                            Label(selectedFilename, systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                            Text(ByteCountFormatter.string(fromByteCount: selectedSize, countStyle: .file))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Text("بعد اختيار ملف IPA سيظهر اسمه هنا. اضغط حفظ التعديلات لبدء الرفع إلى التخزين الخاص.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        TextField("رابط تنزيل IPA مباشر (HTTPS)", text: $ipaURL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }

                    if let oldPath = app?.ipaPath, !oldPath.isEmpty {
                        Text("الملف الحالي: \(oldPath)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Section("النشر") {
                    Toggle("منشور في المتجر", isOn: $published)
                        .tint(gold)
                    Text("احفظ التطبيق كمسودة حتى يصبح ملف IPA جاهزًا. النشر لا يعني أن التثبيت المباشر مفعّل بعد.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if saving && !saveStatus.isEmpty {
                    Section { Text(saveStatus).font(.footnote).foregroundStyle(.secondary) }
                }
                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        Task { await save() }
                    } label: {
                        HStack {
                            Spacer()
                            if saving { ProgressView() }
                            else { Text(app == nil ? "حفظ التطبيق" : "حفظ التعديلات").bold() }
                            Spacer()
                        }
                    }
                    .disabled(saving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              bundleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle(app == nil ? "إضافة تطبيق" : "تعديل تطبيق")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("إلغاء") { dismiss() }
                }
            }
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.item, .content, .data, .archive, .ipaArchive]) { result in
                do {
                    let url = try result.get()
                    guard url.pathExtension.lowercased() == "ipa" else {
                        errorMessage = "اختر ملف IPA نفسه بامتداد .ipa وليس ملف ZIP."
                        return
                    }
                    let granted = url.startAccessingSecurityScopedResource()
                    defer { if granted { url.stopAccessingSecurityScopedResource() } }
                    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                    let fileSize = (attributes[.size] as? NSNumber)?.int64Value ?? 0
                    guard fileSize > 0 && fileSize <= 150 * 1024 * 1024 else {
                        errorMessage = "حجم ملف IPA أكبر من 150 ميجابايت، وهذا الحد الحالي للرفع المباشر."
                        return
                    }
                    let data = try Data(contentsOf: url, options: [.mappedIfSafe])
                    guard !data.isEmpty else {
                        errorMessage = "الملف المختار فارغ."
                        return
                    }
                    selectedIPA = data
                    selectedSize = fileSize
                    selectedFilename = url.lastPathComponent
                    errorMessage = ""
                } catch {
                    errorMessage = "تعذر قراءة الملف: \(error.localizedDescription)"
                }
            }
        }
    }

    @MainActor
    private func save() async {
        guard !saving else { return }
        saving = true
        errorMessage = ""
        saveStatus = "جاري تجهيز التطبيق..."
        defer { saving = false }

        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanBundle = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanVersion = version.trimmingCharacters(in: .whitespacesAndNewlines)
        var finalPath = app?.ipaPath

        do {
            if useFile && selectedIPA == nil && (finalPath == nil || finalPath?.isEmpty == true) {
                errorMessage = "اختر ملف IPA من الملفات أولًا، أو انتقل إلى خيار الرابط الخارجي."
                return
            }
            if useFile, let data = selectedIPA {
                saveStatus = "جاري رفع IPA..."
                let storagePath = "apps/\(UUID().uuidString).ipa"
                try await SupabaseManager.shared.client.storage
                    .from("ipa-files")
                    .upload(
                        path: storagePath,
                        file: data,
                        options: FileOptions(contentType: "application/octet-stream")
                    )
                finalPath = storagePath
            } else if !useFile {
                let link = ipaURL.trimmingCharacters(in: .whitespacesAndNewlines)
                if !link.isEmpty {
                    guard let url = URL(string: link),
                          url.scheme?.lowercased() == "https",
                          url.host != nil else {
                        errorMessage = "الرابط الخارجي يجب أن يبدأ بـ HTTPS."
                        return
                    }
                    finalPath = link
                }
            }

            if published && (finalPath == nil || finalPath?.isEmpty == true) {
                errorMessage = "أضف ملف IPA أو رابطًا مباشرًا قبل النشر."
                return
            }

            saveStatus = "جاري حفظ بيانات التطبيق..."
            let payload = AppPayload(
                name: cleanName,
                bundleID: cleanBundle,
                version: cleanVersion,
                description: appDescription.isEmpty ? nil : appDescription,
                ipaPath: finalPath,
                sizeBytes: useFile && selectedIPA != nil ? selectedSize : (Double(manualSizeMB.replacingOccurrences(of: ",", with: ".")).map { Int64(max(0, $0) * 1_048_576) } ?? app?.sizeBytes),
                published: published
            )
            let table = SupabaseManager.shared.client.from("apps")
            if let app {
                try await table
                    .update(payload)
                    .eq("id", value: app.id.uuidString)
                    .execute()
            } else {
                try await table.insert(payload).execute()
            }
            dismiss()
        } catch {
            errorMessage = "تعذر حفظ التطبيق: \(error.localizedDescription)"
        }
    }
}
