import SwiftUI

/// Project colours for the week review. Slots are handed out in a fixed order and never cycled;
/// projects beyond the last slot share the neutral "other" tone.
enum ReviewPalette {
    static let series = [
        OdakPalette.dynamic(light: 0x2A78D6, dark: 0x3987E5),
        OdakPalette.dynamic(light: 0xEB6834, dark: 0xD95926),
        OdakPalette.dynamic(light: 0x1BAF7A, dark: 0x199E70),
        OdakPalette.dynamic(light: 0xEDA100, dark: 0xC98500),
        OdakPalette.dynamic(light: 0xE87BA4, dark: 0xD55181),
        OdakPalette.dynamic(light: 0x6250D6, dark: 0x9085E9),
    ]
    static let other = OdakPalette.dynamic(light: 0xA8A294, dark: 0x5E626B)

    /// Colours for the busiest projects. Assigned alphabetically, so a project's colour does not
    /// change when it overtakes another during the week.
    static func colors(for rankedProjects: [String]) -> [String: Color] {
        let coloured = rankedProjects.prefix(series.count).sorted()
        return Dictionary(uniqueKeysWithValues: zip(coloured, series))
    }
}
