//
//  StudySnapWidgetsBundle.swift
//  StudySnapWidgets
//
//  Created by Shaarav on 3/12/2025.
//

import WidgetKit
import SwiftUI

@main
struct StudySnapWidgetsBundle: WidgetBundle {
    var body: some Widget {
        StudySnapProgressWidget()
        StudySnapStreakWidget()
        StudySnapWidgetsControl()
    }
}
