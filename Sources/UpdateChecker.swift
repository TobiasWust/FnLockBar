import Foundation

/// Asks GitHub for the latest release; no auto-install, just tells the user.
final class UpdateChecker {
    struct Release: Decodable {
        let tag_name: String
        let html_url: URL
        var version: String { tag_name.hasPrefix("v") ? String(tag_name.dropFirst()) : tag_name }
    }

    static let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    private let endpoint = URL(string: "https://api.github.com/repos/TobiasWust/FnLockBar/releases/latest")!

    /// The newer release, if one was found on the last check.
    private(set) var available: Release?

    func check(completion: @escaping (Result<Release?, Error>) -> Void = { _ in }) {
        var request = URLRequest(url: endpoint)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            let result: Result<Release?, Error> = Result {
                if let error { throw error }
                let release = try JSONDecoder().decode(Release.self, from: data ?? Data())
                return UpdateChecker.isNewer(release.version, than: UpdateChecker.currentVersion) ? release : nil
            }
            DispatchQueue.main.async {
                if case .success(let release) = result { self?.available = release }
                completion(result)
            }
        }.resume()
    }

    /// Numeric compare of dotted versions: 1.10.0 > 1.9.2, 1.1 == 1.1.0.
    static func isNewer(_ a: String, than b: String) -> Bool {
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }
        let pb = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0, y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
