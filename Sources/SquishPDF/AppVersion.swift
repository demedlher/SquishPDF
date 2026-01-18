import Foundation

/// App version information
/// Updated automatically by build_app.sh before each installer build
struct AppVersion {
    /// Marketing version (shown prominently)
    static let version = "3.0"

    /// Build number (patch version, incremented with each installer build)
    static let build = 11

    /// Git commit hash (short)
    static let commit = "2a70fd7"

    /// Full version string for display
    static var fullVersion: String {
        "\(version).\(build)"
    }

    /// Version with build info for About panel
    static var versionWithBuild: String {
        "\(version).\(build) build \(commit)"
    }
}
