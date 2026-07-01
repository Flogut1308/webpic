import SwiftUI

public struct WPPalette: Sendable {
    public let accent, accentHover, accentPress, accentTint, accentTint2: Color
    public let window, grouped, card: Color
    public let t1, t2, t3, sep, sep2: Color
    public let ctrl, ctrlBorder, seg, segSel, hover, field: Color
    public let statusDone, statusProc, statusWait, statusError: Color

    public static let light = WPPalette(
        accent: Color(hex: 0x0A84FF), accentHover: Color(hex: 0x2A94FF),
        accentPress: Color(hex: 0x0069D0), accentTint: Color(hex: 0xE8F1FE),
        accentTint2: Color(hex: 0xD6E7FD),
        window: Color(hex: 0xFFFFFF), grouped: Color(hex: 0xF1F1F4), card: Color(hex: 0xFFFFFF),
        t1: Color(hex: 0x1D1D1F), t2: Color(hex: 0x605F65), t3: Color(hex: 0x8E8E93),
        sep: Color(hex: 0x000000, alpha: 0.09), sep2: Color(hex: 0x000000, alpha: 0.14),
        ctrl: Color(hex: 0xFFFFFF), ctrlBorder: Color(hex: 0x000000, alpha: 0.13),
        seg: Color(hex: 0xE7E7EA), segSel: Color(hex: 0xFFFFFF),
        hover: Color(hex: 0x000000, alpha: 0.045), field: Color(hex: 0xFFFFFF),
        statusDone: Color(hex: 0x1E9E5A), statusProc: Color(hex: 0x0A84FF),
        statusWait: Color(hex: 0x8E8E93), statusError: Color(hex: 0xE5484D)
    )

    public static let dark = WPPalette(
        accent: Color(hex: 0x0A84FF), accentHover: Color(hex: 0x3A9CFF),
        accentPress: Color(hex: 0x0A6FD0), accentTint: Color(hex: 0x0A84FF, alpha: 0.20),
        accentTint2: Color(hex: 0x0A84FF, alpha: 0.30),
        window: Color(hex: 0x1E1E1F), grouped: Color(hex: 0x161617), card: Color(hex: 0x2A2A2C),
        t1: Color(hex: 0xF5F5F7), t2: Color(hex: 0xA6A6AC), t3: Color(hex: 0x6E6E76),
        sep: Color(hex: 0xFFFFFF, alpha: 0.09), sep2: Color(hex: 0xFFFFFF, alpha: 0.15),
        ctrl: Color(hex: 0x3A3A3D), ctrlBorder: Color(hex: 0xFFFFFF, alpha: 0.14),
        seg: Color(hex: 0x3A3A3D), segSel: Color(hex: 0x636367),
        hover: Color(hex: 0xFFFFFF, alpha: 0.06), field: Color(hex: 0x1B1B1D),
        statusDone: Color(hex: 0x30D158), statusProc: Color(hex: 0x0A84FF),
        statusWait: Color(hex: 0x98989F), statusError: Color(hex: 0xFF453A)
    )
}
