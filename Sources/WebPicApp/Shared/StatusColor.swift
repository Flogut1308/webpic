import SwiftUI
import WebPicCore

func statusColor(_ status: ImageStatus, _ p: WPPalette) -> Color {
    switch status {
    case .done:       return p.statusDone
    case .processing: return p.statusProc
    case .waiting:    return p.statusWait
    case .error:      return p.statusError
    }
}
