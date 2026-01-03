//
//  LearnHubWidgetsBundle.swift
//  LearnHubWidgets
//
//  Created by Shaarav on 3/12/2025.
//

import WidgetKit
import SwiftUI

@main
struct LearnHubWidgetsBundle: WidgetBundle {
    var body: some Widget {
        LearnHubProgressWidget()
        LearnHubStatsWidget()
        FlashcardWidget()
        LearnHubWidgetsControl()
    }
}
