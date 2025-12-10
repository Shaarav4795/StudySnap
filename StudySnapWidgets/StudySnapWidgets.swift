//
//  StudySnapWidgets.swift
//  StudySnapWidgets
//
//  Created by Shaarav on 3/12/2025.
//

import WidgetKit
import SwiftUI

// MARK: - Shared Data Model for Widgets

struct WidgetData: Codable {
    var level: Int
    var totalXP: Int
    var xpProgress: Double
    var xpToNextLevel: Int
    var currentStreak: Int
    var coins: Int
    
    static let placeholder = WidgetData(
        level: 1,
        totalXP: 0,
        xpProgress: 0.0,
        xpToNextLevel: 100,
        currentStreak: 0,
        coins: 100
    )
    
    static func load() -> WidgetData {
        guard let userDefaults = UserDefaults(suiteName: "group.com.shaarav.StudySnap"),
              let data = userDefaults.data(forKey: "widgetData"),
              let widgetData = try? JSONDecoder().decode(WidgetData.self, from: data) else {
            return .placeholder
        }
        return widgetData
    }
}

// MARK: - Timeline Entry

struct StudySnapEntry: TimelineEntry {
    let date: Date
    let widgetData: WidgetData
}

// MARK: - Progress Widget Provider (Medium)

struct ProgressWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> StudySnapEntry {
        StudySnapEntry(date: Date(), widgetData: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (StudySnapEntry) -> ()) {
        let entry = StudySnapEntry(date: Date(), widgetData: WidgetData.load())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StudySnapEntry>) -> ()) {
        let currentDate = Date()
        let entry = StudySnapEntry(date: currentDate, widgetData: WidgetData.load())
        
        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Streak Widget Provider (Small)

struct StreakWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> StudySnapEntry {
        StudySnapEntry(date: Date(), widgetData: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (StudySnapEntry) -> ()) {
        let entry = StudySnapEntry(date: Date(), widgetData: WidgetData.load())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StudySnapEntry>) -> ()) {
        let currentDate = Date()
        let entry = StudySnapEntry(date: currentDate, widgetData: WidgetData.load())
        
        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Progress Widget View (Medium)

struct ProgressWidgetEntryView: View {
    var entry: ProgressWidgetProvider.Entry
    @Environment(\.widgetFamily) var widgetFamily

    var body: some View {
        HStack(spacing: 16) {
            // Level & XP Section
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(.body)
                        .foregroundColor(.yellow)
                    Text("Level \(entry.widgetData.level)")
                        .font(.headline.bold())
                        .foregroundColor(.primary)
                }
                
                // XP Progress Bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 12)
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .cyan],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(0, geometry.size.width * entry.widgetData.xpProgress), height: 12)
                    }
                }
                .frame(height: 12)
                
                Text("\(entry.widgetData.xpToNextLevel) XP to next")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Divider
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 1, height: 55)
            
            // Streak Section
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.title2)
                        .foregroundColor(entry.widgetData.currentStreak > 0 ? .orange : .gray)
                    Text("\(entry.widgetData.currentStreak)")
                        .font(.title2.bold())
                        .foregroundColor(.primary)
                }
                Text("Streak")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Divider
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 1, height: 55)
            
            // Coins Section
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.title2)
                        .foregroundColor(.yellow)
                    Text("\(entry.widgetData.coins)")
                        .font(.title2.bold())
                        .foregroundColor(.primary)
                }
                Text("Coins")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Streak Widget View (Small)

struct StreakWidgetEntryView: View {
    var entry: StreakWidgetProvider.Entry

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "flame.fill")
                .font(.system(size: 40))
                .foregroundColor(entry.widgetData.currentStreak > 0 ? .orange : .gray)
                .shadow(color: entry.widgetData.currentStreak > 0 ? .orange.opacity(0.5) : .clear, radius: 8, x: 0, y: 4)
            
            Text("\(entry.widgetData.currentStreak)")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text(entry.widgetData.currentStreak == 1 ? "Day Streak" : "Day Streak")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Progress Widget (Medium)

struct StudySnapProgressWidget: Widget {
    let kind: String = "StudySnapProgressWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ProgressWidgetProvider()) { entry in
            if #available(iOS 17.0, *) {
                ProgressWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                ProgressWidgetEntryView(entry: entry)
                    .padding()
                    .background(Color(uiColor: .systemBackground))
            }
        }
        .configurationDisplayName("Study Progress")
        .description("View your level, XP progress, streak, and coins at a glance.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Streak Widget (Small)

struct StudySnapStreakWidget: Widget {
    let kind: String = "StudySnapStreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakWidgetProvider()) { entry in
            if #available(iOS 17.0, *) {
                StreakWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                StreakWidgetEntryView(entry: entry)
                    .padding()
                    .background(Color(uiColor: .systemBackground))
            }
        }
        .configurationDisplayName("Study Streak")
        .description("Keep track of your daily study streak.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Previews

#Preview("Progress Widget", as: .systemMedium) {
    StudySnapProgressWidget()
} timeline: {
    StudySnapEntry(date: .now, widgetData: WidgetData(level: 5, totalXP: 450, xpProgress: 0.6, xpToNextLevel: 80, currentStreak: 7, coins: 250))
    StudySnapEntry(date: .now, widgetData: WidgetData(level: 10, totalXP: 1200, xpProgress: 0.3, xpToNextLevel: 150, currentStreak: 14, coins: 500))
}

#Preview("Streak Widget", as: .systemSmall) {
    StudySnapStreakWidget()
} timeline: {
    StudySnapEntry(date: .now, widgetData: WidgetData(level: 5, totalXP: 450, xpProgress: 0.6, xpToNextLevel: 80, currentStreak: 7, coins: 250))
    StudySnapEntry(date: .now, widgetData: WidgetData(level: 1, totalXP: 0, xpProgress: 0.0, xpToNextLevel: 100, currentStreak: 0, coins: 100))
}
