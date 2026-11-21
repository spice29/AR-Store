
import Foundation
import Supabase

final class AppService {
    static let shared = AppService()

    private init() {}

    func fetchApps() async throws -> [StoreApp] {
        let client = SupabaseManager.shared.client

        let apps: [StoreApp] = try await client
            .from("apps")
            .select("""
                id,
                name,
                bundle_id,
                version,
                description,
                icon_path,
                ipa_path,
                size_bytes,
                published
            """)
            .eq("published", value: true)
            .order("created_at", ascending: false)
            .execute()
            .value

        return apps
    }
}
