import Foundation

/// Mirrors the reference `fmt()`: B / KB (0 decimals) / MB (1 decimal, comma).
public func formatBytes(_ b: Int) -> String {
    if b < 1000 { return "\(b) B" }
    if b < 1024 * 1024 { return "\(Int((Double(b) / 1024).rounded())) KB" }
    let mb = (Double(b) / 1_000_000)
    return String(format: "%.1f", mb).replacingOccurrences(of: ".", with: ",") + " MB"
}
