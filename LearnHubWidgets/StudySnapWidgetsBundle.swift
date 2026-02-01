// Widget bundle entry point for LearnHub widgets.

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
