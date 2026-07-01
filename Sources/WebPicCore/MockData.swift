import Foundation

public enum MockData {
    public static func seedImages() -> [WebPicImage] {
        [
            WebPicImage(id: "i1", name: "hero-banner.jpg",  pixelWidth: 4032, pixelHeight: 2268,
                        byteSize: 6_083_000, status: .done,             gradient: [0x5AC8FA, 0x0A84FF]),
            WebPicImage(id: "i2", name: "team-photo.jpg",   pixelWidth: 3000, pixelHeight: 2000,
                        byteSize: 4_300_000, status: .processing(0.62), gradient: [0xFF9F45, 0xFF6B6B]),
            WebPicImage(id: "i3", name: "product-shot.png", pixelWidth: 2400, pixelHeight: 2400,
                        byteSize: 6_500_000, status: .waiting,          gradient: [0x30D158, 0x0A84FF]),
            WebPicImage(id: "i4", name: "avatar-jane.png",  pixelWidth: 512,  pixelHeight: 512,
                        byteSize: 430_000,  status: .error("Konnte nicht dekodiert werden"),
                        gradient: [0xB0B0B8, 0x7C7C86]),
        ]
    }
}
