//
// Created by Александр Цикин on 21.11.2019.
// Copyright (c) 2019 PrivateRouter. All rights reserved.
//

import Foundation
import UIKit
import SwiftTheme

enum ThemeName: String {
    case light = "Light"
    case dark = "Dark"
}

enum ThemeColorName: String {
    case surface = "SurfaceColor"
    case onSurfaceMajorText = "OnSurfaceMajorTextColor"
    case onSurfaceMinorText = "OnSurfaceMinorTextColor"
    case onAccent = "OnAccentColor"
    case accent = "AccentColor"
    case accentFavorite = "AccentFavoriteColor"
    case primary = "PrimaryColor"
    case primaryDark = "PrimaryDarkColor"
    case onPrimary = "OnPrimaryColor"
    case secondarySurface = "SecondarySurfaceColor"
    case onSurfaceSeparator = "OnSurfaceSeparatorColor"
}

extension ThemeColorPicker {
    
    convenience init(_ color: ThemeColorName) {
        self.init(keyPath: color.rawValue)
    }
    
    static var surface: ThemeColorPicker {
        ThemeColorPicker(.surface)
    }
    
    static var onSurfaceMajorText: ThemeColorPicker {
        ThemeColorPicker(.onSurfaceMajorText)
    }
    
    static var onSurfaceMinorText: ThemeColorPicker {
        ThemeColorPicker(.onSurfaceMinorText)
    }
    
    static var onAccent: ThemeColorPicker {
        ThemeColorPicker(.onAccent)
    }
    
    static var accent: ThemeColorPicker {
        ThemeColorPicker(.accent)
    }
    
    static var accentFavorite: ThemeColorPicker {
        ThemeColorPicker(.accentFavorite)
    }
    
    static var primary: ThemeColorPicker {
        ThemeColorPicker(.primary)
    }
    
    static var primaryDark: ThemeColorPicker {
        ThemeColorPicker(.primaryDark)
    }
    
    static var onPrimary: ThemeColorPicker {
        ThemeColorPicker(.onPrimary)
    }
    
    static var secondarySurface: ThemeColorPicker {
        ThemeColorPicker(.secondarySurface)
    }
    
    static var onSurfaceSeparator: ThemeColorPicker {
        ThemeColorPicker(.onSurfaceSeparator)
    }
    
}

extension ThemeActivityIndicatorViewStylePicker {
    
    static var onSurface: ThemeActivityIndicatorViewStylePicker {
        ThemeActivityIndicatorViewStylePicker(keyPath: "OnSurfaceActivityIndicatorStyle")
    }
    
}

extension ThemeManager {
    
    static func setTheme(_ theme: ThemeName) {
        ThemeManager.setTheme(plistName: theme.rawValue, path: .mainBundle)
    }
    
    static func color(_ name: ThemeColorName) -> UIColor {
        ThemeManager.color(for: name.rawValue)!
    }
    
}

struct Themer {
    
    static func themeTableViewSectionHeader(_ view: UIView) {
        guard let view = view as? UITableViewHeaderFooterView else {
            return
        }
        
        view.contentView.theme_backgroundColor = .secondarySurface
        view.backgroundView?.theme_backgroundColor = .secondarySurface
        view.textLabel?.theme_textColor = .onSurfaceMajorText
        view.detailTextLabel?.theme_textColor = .onSurfaceMinorText
    }
    
}

extension Notification.Name {
    
    static var themeUpdate: Notification.Name {
        Notification.Name(rawValue: ThemeUpdateNotification)
    }
    
}