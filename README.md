# StudySnap

**The Ultimate AI-Powered Study Companion for iOS**

StudySnap is an intelligent study aid built with **SwiftUI** and **SwiftData** for iOS 26+. It leverages advanced AI to transform your study materials into interactive learning tools.

**Key Capabilities:**
- **AI Summaries:** Instantly condense long notes and PDFs.
- **Quiz Generator:** Create multiple-choice questions automatically.
- **Flashcards:** Generate study decks from any text or document.
- **Gamification:** Earn XP, track streaks, and unlock achievements.
- **Local AI** Choose the Apple Intelligence AI model for a fully local, offline experience.

Perfect for students looking to optimize their revision with **AI study tools**, **automated flashcards**, and **smart quizzes**.

Generate summaries, quizzes, and flashcards from your notes (paste, scan, or import a PDF), track progress with gamification, and keep learning with widgets and notifications.

## Features
- Create study sets from pasted text, scanned pages (VisionKit), or uploaded PDFs
- Two modes: generate from your content or ask the AI to teach you a new topic
- AI summaries, multiple-choice questions, and flashcards via OpenRouter
- Quiz and flashcard practice flows, plus math rendering (SwiftMath)
- Gamification: levels, XP, streaks, achievements, theming, and guide overlays
- Widgets and notifications to keep study streaks alive
- Choose your model - Apple Intelligence or OpenRouter

## Screenshots

<table>
   <tr>
      <td align="center">
         <p><strong>Home</strong></p>
         <img src="Media/Home%20Screen.png" alt="Home Screen" width="180" />
      </td>
      <td align="center">
         <p><strong>Achievements</strong></p>
         <img src="Media/Achievements%20View.png" alt="Achievements View" width="180" />
      </td>
      <td align="center">
         <p><strong>Flashcards</strong></p>
         <img src="Media/Flashcards%20View.png" alt="Flashcards View" width="180" />
      </td>
   </tr>
   <tr>
      <td align="center">
         <p><strong>Profile</strong></p>
         <img src="Media/Profile%20View.png" alt="Profile View" width="180" />
      </td>
      <td align="center">
         <p><strong>Quiz</strong></p>
         <img src="Media/Quiz%20View.png" alt="Quiz View" width="180" />
      </td>
      <td align="center">
         <p><strong>Summary</strong></p>
         <img src="Media/Summary%20View.png" alt="Summary View" width="180" />
      </td>
   </tr>
   <tr>
      <td align="center">
         <p><strong>Widgets &amp; Icon</strong></p>
         <img src="Media/Widgets%20and%20App%20Icon.png" alt="Widgets and App Icon" width="180" />
      </td>
      <td align="center">
         <p><strong>Model Settings</strong></p>
         <img src="Media/Model%20Selection.png" alt="Model Selection"
         width="180" />
      </td>
      <td></td>
   </tr>
</table>

## Requirements
- macOS with Xcode 16 (or newer) and the latest iOS SDK
- iOS 26.0+ simulator or device
- OpenRouter API key (free/paid), and network access for AI features

## Quick start
```bash
# 1) Clone
git clone https://github.com/Shaarav4795/StudySnap.git
cd StudySnap

# 2) Open in Xcode
xed .
```

In Xcode, select the `StudySnap` scheme and press **Cmd+R** to run on a simulator or device. The widget target (`StudySnapWidgets`) builds alongside the app.

## Configure OpenRouter (required for live AI, completely free)
1. Get a key: sign up at https://openrouter.ai, create an API key, and copy it.
2. Input your key in the app's settings menu.

## Using the app
1. Launch and allow notifications if you want streak reminders.
2. Choose your preferred AI model in the app's settings menu
2. Tap **+** on Home to create a study set.
   - **From Content:** paste notes, scan with the camera, or upload a PDF; set counts for questions/flashcards and generate.
   - **Learn Topic:** describe the topic; the AI generates a guided summary, quiz, and flashcards.
3. Open a study set to view tabs:
   - **Summary/Guide:** AI-written overview in paragraph or bullet form.
   - **Questions:** multiple-choice with explanations (and Quiz practice flow).
   - **Flashcards:** swipe through concise Q/A cards.
4. Track progress with levels, XP, streaks, achievements, and theme switching from the profile.
5. Add the StudySnap widget from the Home Screen to keep studying top of mind.

## Development and testing
- Dependencies: SwiftPM only (SwiftMath).
- Run tests: select `StudySnap` and press **Cmd+U**.
- Reset badge counts and notifications are handled in-app; no extra setup needed.

## Repository hygiene
- Standard Xcode/macOS build outputs are ignored via `.gitignore`.
- Licensed under MIT (see `LICENSE`).

## Project structure (high level)
- `StudySnap/` — main app sources (SwiftUI views, AI integration, data models, guides, theming)
- `StudySnapWidgets/` — widget extension
- `StudySnapTests/`, `StudySnapUITests/` — unit and UI tests
