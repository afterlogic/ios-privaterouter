//
// Created by Александр Цикин on 21.11.2019.
// Copyright (c) 2019 PrivateRouter. All rights reserved.
//

import Foundation
import UIKit
import SwiftTheme

extension ThemeColorPicker {
    
    static var surface: ThemeColorPicker {
        ThemeColorPicker("SurfaceColor")
    }
    
    static var onSurfaceMajorText: ThemeColorPicker {
        ThemeColorPicker("OnSurfaceMajorTextColor")
    }
    
    static var onSurfaceMinorText: ThemeColorPicker {
        ThemeColorPicker("OnSurfaceMinorTextColor")
    }
    
    static var onAccent: ThemeColorPicker {
        ThemeColorPicker("OnAccentColor")
    }
    
    static var accent: ThemeColorPicker {
        ThemeColorPicker("AccentColor")
    }
    
    static var accentFavorite: ThemeColorPicker {
        ThemeColorPicker("AccentFavoriteColor")
    }
    
    static var primary: ThemeColorPicker {
        ThemeColorPicker("PrimaryColor")
    }
    
    static var primaryDark: ThemeColorPicker {
        ThemeColorPicker("PrimaryDarkColor")
    }
    
    static var onPrimary: ThemeColorPicker {
        ThemeColorPicker("OnPrimaryColor")
    }
    
    static var secondarySurface: ThemeColorPicker {
        ThemeColorPicker("SecondarySurfaceColor")
    }
    
    static var onSurfaceSeparator: ThemeColorPicker {
        ThemeColorPicker("OnSurfaceSeparatorColor")
    }
    
}