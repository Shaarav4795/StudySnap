# StudySnap

**The Ultimate AI-Powered Study Companion for iOS**

StudySnap is an intelligent study aid built with **SwiftUI** and **SwiftData** for iOS 18+. It leverages advanced AI to transform your study materials into interactive learning tools.

**Key Capabilities:**
- **AI Summaries:** Instantly condense long notes and PDFs.
- **Quiz Generator:** Create multiple-choice questions automatically.
- **Flashcards:** Generate study decks from any text or document.
- **Gamification:** Earn XP, track streaks, and unlock achievements.

Perfect for students looking to optimize their revision with **AI study tools**, **automated flashcards**, and **smart quizzes**.

Generate summaries, quizzes, and flashcards from your notes (paste, scan, or import a PDF), track progress with gamification, and keep learning with widgets and notifications.

## Features
- Create study sets from pasted text, scanned pages (VisionKit), or uploaded PDFs
- Two modes: generate from your content or ask the AI to teach you a new topic
- AI summaries, multiple-choice questions, and flashcards via OpenRouter
- Quiz and flashcard practice flows, plus math rendering (SwiftMath)
- Gamification: levels, XP, streaks, achievements, theming, and guide overlays
- Widgets and notifications to keep study streaks alive

## Screenshots
- **Home Screen**  
   ![Home Screen](Media/Home%20Screen.png)

- **Achievements**  
   ![Achievements View](Media/Achievements%20View.png)

- **Flashcards**  
   ![Flashcards View](Media/Flashcards%20View.png)

- **Profile**  
   ![Profile View](Media/Profile%20View.png)

- **Quiz**  
   ![Quiz View](Media/Quiz%20View.png)

- **Summary**  
   ![Summary View](Media/Summary%20View.png)

- **Widgets & App Icon**  
   ![Widgets and App Icon](Media/Widgets%20and%20App%20Icon.png)

## Requirements
- macOS with Xcode 16 (or newer) and the latest iOS SDK
- iOS 18.0+ simulator or device
- OpenRouter API key (free/paid), and network access for AI features

## Quick start
```bash
# 1) Clone
git clone https://github.com/Shaarav4795/StudySnap.git
cd StudySnap

# 2) Create your secrets file (stays local)
cp StudySnap/Secrets.plist.example StudySnap/Secrets.plist

# 3) Open in Xcode
xed .
```

In Xcode, select the `StudySnap` scheme and press **Cmd+R** to run on a simulator or device. The widget target (`StudySnapWidgets`) builds alongside the app.

## Configure OpenRouter (required for live AI, completely free)
1. Get a key: sign up at https://openrouter.ai, create an API key, and copy it.
2. Copy the sample secrets (one-time):
   ```bash
   cp StudySnap/Secrets.plist.example StudySnap/Secrets.plist
   ```
3. Edit `StudySnap/Secrets.plist` and set:
   - `OPENROUTER_API_KEY`: your key
   - `OPENROUTER_MODEL`: model id (defaults to `openai/gpt-oss-20b:free` if unset)
4. Add the file to the app target so it ships in the bundle: drag `StudySnap/Secrets.plist` into Xcode and ensure the **StudySnap** target is checked.

If the key is missing, the app fails fast with a clear error instead of making network calls.

## Using the app
1. Launch and allow notifications if you want streak reminders.
2. Tap **+** on Home to create a study set.
   - **From Content:** paste notes, scan with the camera, or upload a PDF; set counts for questions/flashcards and generate.
   - **Learn Topic:** describe the topic; the AI generates a guided summary, quiz, and flashcards.
3. Open a study set to view tabs:
   - **Summary/Guide:** AI-written overview in paragraph or bullet form.
   - **Questions:** multiple-choice with explanations (and Quiz practice flow).
   - **Flashcards:** swipe through concise Q/A cards.
4. Track progress with levels, XP, streaks, achievements, and theme switching from the profile.
5. Add the StudySnap widget from the Home/Lock Screen to keep studying top of mind.

## Development and testing
- Dependencies: SwiftPM only (SwiftMath).
- Run tests: select `StudySnap` and press **Cmd+U**.
- Reset badge counts and notifications are handled in-app; no extra setup needed.

## Repository hygiene
- Secrets are gitignored (`StudySnap/Secrets.plist`). Keep your API keys local.
- Standard Xcode/macOS build outputs are ignored via `.gitignore`.
- Licensed under MIT (see `LICENSE`).

## Project structure (high level)
- `StudySnap/` — main app sources (SwiftUI views, AI integration, data models, guides, theming)
- `StudySnapWidgets/` — widget extension
- `StudySnapTests/`, `StudySnapUITests/` — unit and UI tests
