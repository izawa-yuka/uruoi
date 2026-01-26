# Project: URUOI (Cat's Water Recording App)

## 1. Technology Stack
- **Language**: Swift 5.9+
- **Framework**: SwiftUI
- **Database**: SwiftData
- **Architecture**: MVVM (Model-View-ViewModel)
- **Target**: iOS 17.0+

## 2. Coding Guidelines
- **SwiftUI First**: Use declarative syntax. Avoid UIKit unless absolutely necessary.
- **SwiftData**: Use `@Model`, `@Query`, and `modelContext` for data persistence.
- **Safe Coding**: Always handle optionals safely (use `if let` or `guard let`, avoid force unwrapping `!`).
- **Clean Code**: Keep Views small. Move logic to ViewModels.

## 3. UI/UX Design Philosophy (OOUI)
- **Object-Oriented UI**: Design based on "Objects" (Containers), not "Tasks".
- **Interaction**:
  - Main Screen: List of Containers (Cards).
  - Detail Screen: History and Actions (Start/Finish) for that specific Container.
- **Multiple Active Records**: Allow multiple containers to be active (recording) simultaneously.

## 4. User Persona & Communication Style
- **User**: Freelance Web Designer (Non-engineer).
- **Tone**: Empathetic, insightful, clear, and transparent.
- **Explanation**: Avoid technical jargon. Explain *why* a change is needed, not just *what* changed.
- **Language**: Japanese (日本語).

## 5. Agent Behavior & Workflow (New!)
This section defines how the AI agent should handle requests and background tasks.

**Protocol for Complex Tasks:**
"Can you spin off an async background agent to do this and then periodically poll it as it does work and summarize what is happening."

**Explanation & Education:**
"I'm not technical at all so please summarize it in a simple way for me. Use the explore agent to summarize how things work (that the other agent is working on) so I can learn while I do this."

**Error Handling:**
"If the background agent runs into any errors, please stop and tell me but guide me in how I might be able to fix it."

**Constraints:**
"Remember I am non technical, so any technical language at all is not useful to me."

---

## 6. Specific Implementation Details (Memory)
- **RecordViewModel**: Manages `activeRecords` (Array) instead of single `latestRecord`.
- **Alert Logic**: Compares "Today's Total" vs "Past Average".
- **Pro Features**: Check `StoreManager.shared.isProMember` for limits (e.g., max 5 containers).
