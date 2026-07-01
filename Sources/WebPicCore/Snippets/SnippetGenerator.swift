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
    static func srcset(base: String, format: ImageFormat, breakpoints: [Int]) -> String {
        breakpoints.sorted().map { "/img/\(base)-\($0).\(ext(format)) \($0)w" }.joined(separator: ", ")
    }
    static func largestWidth(_ breakpoints: [Int], fallback: Int) -> Int {
        breakpoints.max() ?? fallback
    }

    public static func code(framework: SnippetFramework, input i: SnippetInput) -> String {
        let base = i.baseName
        let fb = fallback(i.formats)
        let sources = sourceFormats(i.formats)
        let lz = i.lazy ? " loading=\"lazy\"" : ""
        let isResponsive = i.responsive && !i.breakpoints.isEmpty
        switch framework {
        case .html:
            if isResponsive {
                let largest = largestWidth(i.breakpoints, fallback: i.width)
                var l = ["<picture>"]
                for f in sources {
                    l.append("  <source srcset=\"\(srcset(base: base, format: f, breakpoints: i.breakpoints))\" sizes=\"100vw\" type=\"image/\(ext(f))\">")
                }
                l.append("  <img src=\"/img/\(base)-\(largest).\(fb)\" alt=\"\" width=\"\(i.width)\" height=\"\(i.height)\"\(lz) decoding=\"async\">")
                l.append("</picture>")
                return l.joined(separator: "\n")
            }
            var l = ["<picture>"]
            for f in sources { l.append("  <source srcset=\"/img/\(base).\(ext(f))\" type=\"image/\(ext(f))\">") }
            l.append("  <img src=\"/img/\(base).\(fb)\" alt=\"\" width=\"\(i.width)\" height=\"\(i.height)\"\(lz) decoding=\"async\">")
            l.append("</picture>")
            return l.joined(separator: "\n")
        case .react:
            if isResponsive {
                let largest = largestWidth(i.breakpoints, fallback: i.width)
                var l = ["export function ProductImage() {", "  return (", "    <picture>"]
                for f in sources {
                    l.append("      <source srcSet=\"\(srcset(base: base, format: f, breakpoints: i.breakpoints))\" sizes=\"100vw\" type=\"image/\(ext(f))\" />")
                }
                l.append("      <img src=\"/img/\(base)-\(largest).\(fb)\" alt=\"\" width={\(i.width)} height={\(i.height)}\(lz) decoding=\"async\" />")
                l.append("    </picture>"); l.append("  );"); l.append("}")
                return l.joined(separator: "\n")
            }
            var l = ["export function ProductImage() {", "  return (", "    <picture>"]
            for f in sources { l.append("      <source srcSet=\"/img/\(base).\(ext(f))\" type=\"image/\(ext(f))\" />") }
            l.append("      <img src=\"/img/\(base).\(fb)\" alt=\"\" width={\(i.width)} height={\(i.height)}\(lz) decoding=\"async\" />")
            l.append("    </picture>"); l.append("  );"); l.append("}")
            return l.joined(separator: "\n")
        case .next:
            let largest = isResponsive ? largestWidth(i.breakpoints, fallback: i.width) : nil
            let src: String
            if isResponsive {
                let lw = largest!
                src = i.formats.contains(.webp) ? "/img/\(base)-\(lw).webp" : "/img/\(base)-\(lw).\(fb)"
            } else {
                let ext2 = i.formats.contains(.webp) ? "webp" : fb
                src = "/img/\(base).\(ext2)"
            }
            var l = ["import Image from \"next/image\";", "", "export default function Hero() {", "  return (", "    <Image",
                     "      src=\"\(src)\"", "      alt=\"\"", "      width={\(i.width)}", "      height={\(i.height)}"]
            if isResponsive { l.append("      sizes=\"100vw\"") }
            if i.lazy { l.append("      loading=\"lazy\"") }
            l.append("    />"); l.append("  );"); l.append("}")
            return l.joined(separator: "\n")
        case .vue:
            if isResponsive {
                let largest = largestWidth(i.breakpoints, fallback: i.width)
                var l = ["<template>", "  <picture>"]
                for f in sources {
                    l.append("    <source srcset=\"\(srcset(base: base, format: f, breakpoints: i.breakpoints))\" sizes=\"100vw\" type=\"image/\(ext(f))\" />")
                }
                l.append("    <img src=\"/img/\(base)-\(largest).\(fb)\" alt=\"\" width=\"\(i.width)\" height=\"\(i.height)\"\(lz) decoding=\"async\" />")
                l.append("  </picture>"); l.append("</template>")
                return l.joined(separator: "\n")
            }
            var l = ["<template>", "  <picture>"]
            for f in sources { l.append("    <source srcset=\"/img/\(base).\(ext(f))\" type=\"image/\(ext(f))\" />") }
            l.append("    <img src=\"/img/\(base).\(fb)\" alt=\"\" width=\"\(i.width)\" height=\"\(i.height)\"\(lz) decoding=\"async\" />")
            l.append("  </picture>"); l.append("</template>")
            return l.joined(separator: "\n")
        }
    }
}
