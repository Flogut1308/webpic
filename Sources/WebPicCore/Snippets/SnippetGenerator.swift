import Foundation

public struct SnippetInput: Sendable {
    public let baseName: String
    public let formats: [ImageFormat]
    public let width: Int
    public let height: Int
    public let lazy: Bool
    public let responsive: Bool
    public let breakpoints: [Int]
    public init(baseName: String, formats: [ImageFormat], width: Int, height: Int,
                lazy: Bool, responsive: Bool, breakpoints: [Int]) {
        self.baseName = baseName; self.formats = formats; self.width = width; self.height = height
        self.lazy = lazy; self.responsive = responsive; self.breakpoints = breakpoints
    }
}

public enum SnippetGenerator {
    static func sourceFormats(_ formats: [ImageFormat]) -> [ImageFormat] {
        [.avif, .webp].filter { formats.contains($0) }
    }
    static func fallback(_ formats: [ImageFormat]) -> String {
        formats.contains(.png) ? "png" : "jpg"
    }
    static func ext(_ f: ImageFormat) -> String {
        switch f { case .jpeg: return "jpg"; case .png: return "png"; case .avif: return "avif"; case .webp: return "webp" }
    }

    public static func code(framework: SnippetFramework, input i: SnippetInput) -> String {
        let base = i.baseName
        let fb = fallback(i.formats)
        let sources = sourceFormats(i.formats)
        let lz = i.lazy ? " loading=\"lazy\"" : ""
        switch framework {
        case .html:
            var l = ["<picture>"]
            for f in sources { l.append("  <source srcset=\"/img/\(base).\(ext(f))\" type=\"image/\(ext(f))\">") }
            l.append("  <img src=\"/img/\(base).\(fb)\" alt=\"\" width=\"\(i.width)\" height=\"\(i.height)\"\(lz) decoding=\"async\">")
            l.append("</picture>")
            return l.joined(separator: "\n")
        case .react:
            var l = ["export function ProductImage() {", "  return (", "    <picture>"]
            for f in sources { l.append("      <source srcSet=\"/img/\(base).\(ext(f))\" type=\"image/\(ext(f))\" />") }
            l.append("      <img src=\"/img/\(base).\(fb)\" alt=\"\" width={\(i.width)} height={\(i.height)}\(lz) decoding=\"async\" />")
            l.append("    </picture>"); l.append("  );"); l.append("}")
            return l.joined(separator: "\n")
        case .next:
            let src = i.formats.contains(.webp) ? "webp" : fb
            var l = ["import Image from \"next/image\";", "", "export default function Hero() {", "  return (", "    <Image",
                     "      src=\"/img/\(base).\(src)\"", "      alt=\"\"", "      width={\(i.width)}", "      height={\(i.height)}"]
            if i.lazy { l.append("      loading=\"lazy\"") }
            l.append("    />"); l.append("  );"); l.append("}")
            return l.joined(separator: "\n")
        case .vue:
            var l = ["<template>", "  <picture>"]
            for f in sources { l.append("    <source srcset=\"/img/\(base).\(ext(f))\" type=\"image/\(ext(f))\" />") }
            l.append("    <img src=\"/img/\(base).\(fb)\" alt=\"\" width=\"\(i.width)\" height=\"\(i.height)\"\(lz) decoding=\"async\" />")
            l.append("  </picture>"); l.append("</template>")
            return l.joined(separator: "\n")
        }
    }
}
