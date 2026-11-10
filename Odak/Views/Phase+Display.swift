import SwiftUI

extension FocusTimer.Phase {
    var title: LocalizedStringKey {
        switch self {
        case .focus: "Focus"
        case .shortBreak: "Short Break"
        case .longBreak: "Long Break"
        }
    }

    var symbolName: String {
        isBreak ? "cup.and.saucer.fill" : "scope"
    }
}
