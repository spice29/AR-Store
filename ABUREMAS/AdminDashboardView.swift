import SwiftUI
import Supabase
import UniformTypeIdentifiers
import UIKit

private extension UTType {
    static let ipaArchive = UTType(importedAs: "com.apple.itunes.ipa", conformingTo: .data)
}

/// Uses UIKit's import-mode document picker to avoid SwiftUI fileImporter
/// filtering IPA files that iOS Files providers expose with unexpected UTIs.
private struct IPAFilePicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void
    let onError: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            documentTypes: ["public.item", "public.data", "public.content",
                            "public.archive", "com.apple.itunes.ipa"],
            in: .import
        )
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: IPAFilePicker
        init(_ parent: IPAFilePicker) { self.parent = parent }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else {
                parent.onError("لم يتم تحديد ملف.")
                return
            }
            parent.onPick(url)
        }
    }
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
    @State private var appToDelete: AdminApp?

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
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "app.fill")
                                    .font(.title2)
                                    .foregroundStyle(gold)
                                    .frame(width: 38, height: 44)

                                VStack(alignment: .leading, spacing: 5) {
                                    Text(app.name)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                        .lineLimit(2)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text(app.bundleID)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Text("الإصدار \(app.version)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if let bytes = app.sizeBytes, bytes > 0 {
                                        Text(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                Text(app.published ? "منشور" : "مسودة")
                                    .font(.caption.bold())
                                    .foregroundStyle(app.published ? .green : .orange)
                                    .fixedSize()
                            }

                            HStack(spacing: 12) {
                                Button {
                                    editingApp = app
                                    showingEditor = true
                                } label: {
                                    Label("تعديل", systemImage: "pencil")
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.bordered)
                                .tint(gold)

                                Button(role: .destructive) {
                                    appToDelete = app
                                } label: {
                                    Label("حذف", systemImage: "trash")
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.bordered)
                                .tint(.red)
                            }
                            .labelStyle(.titleAndIcon)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
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
            .confirmationDialog("حذف التطبيق من المتجر؟", isPresented: Binding(
                get: { appToDelete != nil },
                set: { if !$0 { appToDelete = nil } }
            )) {
                Button("حذف التطبيق", role: .destructive) {
                    if let target = appToDelete {
                        appToDelete = nil
                        Task { await deleteApp(target) }
                    }
                }
                Button("إلغاء", role: .cancel) { appToDelete = nil }
            } message: {
                Text("سيحذف سجل التطبيق من المتجر دون حذف ملف IPA المخزن.")
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
    private func deleteApp(_ app: AdminApp) async {
        do {
            try await SupabaseManager.shared.client
                .from("apps")
                .delete()
                .eq("id", value: app.id.uuidString)
                .execute()
            await loadApps()
            if apps.contains(where: { $0.id == app.id }) {
                errorMessage = "لم يتم حذف التطبيق؛ تحقق من صلاحيات الحذف."
            }
        } catch {
            errorMessage = "تعذر حذف التطبيق: \(error.localizedDescription)"
        }
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
            .sheet(isPresented: $showingImporter) {
                IPAFilePicker(
                    onPick: { url in
                        showingImporter = false
                        readSelectedIPA(url)
                    },
                    onError: { message in
                        showingImporter = false
                        errorMessage = message
                    }
                )
            }
        }
    }

    private func readSelectedIPA(_ url: URL) {
                do {
                    guard url.pathExtension.lowercased() == "ipa" else {
                        errorMessage = "اختر ملف IPA نفسه بامتداد .ipa وليس ملف ZIP."
                        return
                    }
                    let granted = url.startAccessingSecurityScopedResource()
                    defer { if granted { url.stopAccessingSecurityScopedResource() } }
                    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                    let fileSize = (attributes[.size] as? NSNumber)?.int64Value ?? 0
                    guard fileSize > 0 && fileSize <= 300 * 1024 * 1024 else {
                        errorMessage = "حجم ملف IPA أكبر من 300 ميجابايت، وهذا الحد الحالي للرفع المباشر."
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
                try await IPAResumableUploader.upload(data: data, path: storagePath) { progress in
                    Task { @MainActor in
                        saveStatus = "جاري رفع IPA... \(Int(progress * 100))%"
                    }
                }
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


private enum IPAResumableUploader {
    enum UploadError: LocalizedError {
        case badResponse(Int, String)
        case missingLocation
        case invalidOffset
        var errorDescription: String? {
            switch self {
            case .badResponse(let code, let message):
                return "فشل رفع IPA (HTTP \(code)): \(message)"
            case .missingLocation:
                return "لم يرجع الخادم رابط متابعة الرفع."
            case .invalidOffset:
                return "تعذر التحقق من موضع استكمال الرفع."
            }
        }
    }

    static func upload(data: Data, path: String, onProgress: @escaping (Double) -> Void) async throws {
        let token = try await SupabaseManager.shared.client.auth.session.accessToken
        let base = SupabaseConfig.projectURL
        let host = base.host!.replacingOccurrences(of: ".supabase.co", with: ".storage.supabase.co")
        let endpoint = URL(string: "https://\(host)/storage/v1/upload/resumable")!
        let metadata: [(String, String)] = [
            ("bucketName", "ipa-files"), ("objectName", path),
            ("contentType", "application/octet-stream")
        ]
        let metaHeader = metadata.map { key, value in
            "\(key) \(Data(value.utf8).base64EncodedString())"
        }.joined(separator: ",")

        func request(_ url: URL, _ method: String) -> URLRequest {
            var req = URLRequest(url: url)
            req.httpMethod = method
            req.timeoutInterval = 120
            req.setValue("1.0.0", forHTTPHeaderField: "Tus-Resumable")
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue(SupabaseConfig.publishableKey, forHTTPHeaderField: "apikey")
            return req
        }

        func checked(_ response: URLResponse, _ body: Data, expected: [Int]) throws -> HTTPURLResponse {
            guard let http = response as? HTTPURLResponse else {
                throw UploadError.invalidOffset
            }
            guard expected.contains(http.statusCode) else {
                throw UploadError.badResponse(http.statusCode, String(data: body, encoding: .utf8) ?? "")
            }
            return http
        }

        var create = request(endpoint, "POST")
        create.setValue(String(data.count), forHTTPHeaderField: "Upload-Length")
        create.setValue(metaHeader, forHTTPHeaderField: "Upload-Metadata")
        create.setValue("false", forHTTPHeaderField: "x-upsert")
        let (createdBody, createdResponse) = try await URLSession.shared.data(for: create)
        let created = try checked(createdResponse, createdBody, expected: [201])
        guard let location = created.value(forHTTPHeaderField: "Location"),
              let uploadURL = URL(string: location, relativeTo: endpoint)?.absoluteURL else {
            throw UploadError.missingLocation
        }

        let chunkSize = 6 * 1024 * 1024
        var offset = 0
        var failures = 0
        while offset < data.count {
            let end = min(offset + chunkSize, data.count)
            var patch = request(uploadURL, "PATCH")
            patch.setValue(String(offset), forHTTPHeaderField: "Upload-Offset")
            patch.setValue("application/offset+octet-stream", forHTTPHeaderField: "Content-Type")
            patch.httpBody = data.subdata(in: offset..<end)
            do {
                let (body, response) = try await URLSession.shared.data(for: patch)
                let http = try checked(response, body, expected: [204])
                guard let newOffset = http.value(forHTTPHeaderField: "Upload-Offset").flatMap(Int.init),
                      newOffset > offset, newOffset <= data.count else {
                    throw UploadError.invalidOffset
                }
                offset = newOffset
                failures = 0
                onProgress(Double(offset) / Double(data.count))
            } catch {
                failures += 1
                if failures > 5 { throw error }
                try await Task.sleep(for: .seconds(min(20, failures * 3)))
                var head = request(uploadURL, "HEAD")
                head.timeoutInterval = 30
                do {
                    let (body, response) = try await URLSession.shared.data(for: head)
                    let http = try checked(response, body, expected: [200, 204])
                    guard let serverOffset = http.value(forHTTPHeaderField: "Upload-Offset").flatMap(Int.init),
                          serverOffset >= 0, serverOffset <= data.count else {
                        throw UploadError.invalidOffset
                    }
                    offset = serverOffset
                    onProgress(Double(offset) / Double(data.count))
                } catch {
                    // Retry HEAD on the next pass instead of assuming a failed PATCH wrote nothing.
                    if failures >= 5 { throw error }
                }
            }
        }
    }
}
