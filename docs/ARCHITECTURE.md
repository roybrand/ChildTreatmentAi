# Architecture

Status: the backend for the first slice of phase 1 is built. The app has the phase 1 screens, on a phone and in a browser. Items marked **(open)** are not decided.

## Stack

| Layer | Choice |
| --- | --- |
| Backend | ASP.NET Core Web API on .NET 10 |
| Database | PostgreSQL with EF Core |
| App | Flutter (Dart), one codebase for iOS, Android, and the browser |
| LLM | Claude API, called only from the backend |
| Notifications | Firebase Cloud Messaging, which delivers to both iOS and Android |
| Background work | Hosted worker inside the API process to start with |
| Hosting | **(open)** |
| Auth | ASP.NET Core Identity with bearer tokens |

## Components

```
Flutter app (iOS, Android, and browser; Hebrew RTL)
   |  HTTPS, JSON
   v
ASP.NET Core API
   |-- Accounts & families     sign-up, consent, parent/young-person links, roles
   |-- Parent coaching         accommodation map, plans, daily log, coaching sessions
   |-- Brave ladder            ladders, steps, attempts
   |-- Young person tools      check-ins, calming tools, brave steps
   |-- Learning                lessons, practice, mastery records
   |-- Skills programme        modules, exercises
   |-- Planner                 adapts the plan, proposes changes
   |-- Agent orchestration     decides which agent runs; code, not LLM
   |-- Safety monitor          decline detection, alerts, crisis screen
   |-- LLM gateway             the only code that calls the LLM
   |-- Summary worker          weekly summaries, scheduled
   v
PostgreSQL
```

## Agents

The LLM plays five roles, each with its own prompt, data access, and limits: Parent Coach, Skills Guide, Tutor, Profile Agent, and Planner. They are defined in [AGENTS.md](AGENTS.md). Server code decides which agent runs and when. Agents exchange information only through three stores in the database: the profile, the plan, and the event log.

## LLM gateway

Every LLM call goes through one module. It is responsible for:

- Holding all prompts as versioned files in the `prompts/` folder, not strings scattered through the code.
- Removing identifying details before a call. Names are replaced with placeholders and restored in the response. See [PRIVACY.md](PRIVACY.md).
- Applying the rules in [SAFETY.md](SAFETY.md) to every prompt, and checking responses before they reach a user.
- Recording which prompt version produced which output, so a bad response can be traced.

As built: production settings use `claude-opus-5-5` for the coach and the review. Development settings use cheaper models to keep testing costs down. Every call logs its model and token counts. A coach reply takes about 20 seconds because the reply and its safety review are two calls made one after the other, without streaming. When the model declines a request, the parent sees a safe fallback text; automatic fallback to another model is not enabled.

Three agents are built the same way: `ParentCoachAgent`, `ProfileAgent`, and `WeeklySummaryAgent`. Each is a class with no database access, so the API and the evaluation tool run the same code. Each has a service beside it that loads what the agent may see, hides names, and stores the result. The Profile Agent and the Planner return structured output against a JSON schema; code drops anything outside the schema's limits before it is stored.

The app never calls the LLM directly, and no API key is ever shipped inside the app.

## App

- One Flutter codebase builds the iOS app, the Android app, and the web app.
- Layouts are responsive. Below 840 pixels wide the tabs sit along the bottom; from 840 up they sit down the side, and content stays in a centred column. New screens are built this way from the start.
- In a browser the sign-in tokens are kept in the tab's session storage, and the parent is signed out after 15 minutes without activity. See [PRIVACY.md](PRIVACY.md).
- The server accepts browser requests only from the origins listed in the `Cors:AllowedOrigins` setting. In development any local port is accepted.
- The app holds no business rules and no prompts. It shows screens, collects input, and calls the API. Safety checks run on the server, where they cannot be bypassed or go stale in an old app version.
- Calming tools (breathing, grounding) work offline. Everything else needs a connection.
- Notifications reach the phone app only. The web app has none.
- Sensitive data cached on the phone is kept in the platform's secure storage, and the app can be locked with the phone's biometrics.
- Building the iOS app needs a Mac or a cloud build service, since development is on Windows. Publishing needs an Apple developer account and a Google Play developer account.
- App store review is stricter for apps that involve children and health. Allow time for it and expect questions about the claims the app makes.

As built: the app is in `mobile/`. One class, `ApiClient`, makes every server call. `AppState` decides which stage the parent is at: signed out, needs consent, needs a child, or ready. All user-facing text is in `lib/strings.dart`. The crisis contacts are built into the app so that screen works offline.

## Safety monitor

As built: the crisis phrase list is `prompts/safety/crisis-rules.json`, matched in code against every coach message and log entry. A reply that the review does not clearly pass is withheld and replaced with a fixed fallback text.

Decline detection is rule-based code, not an LLM judgement. It reads check-in scores and flags a sharp drop or a sustained low. The LLM may add context to an alert, but it cannot suppress one. Crisis keywords in any free text trigger the crisis screen immediately, before any LLM call.

## Data model (draft)

| Entity | Purpose |
| --- | --- |
| `Family` | The subscription unit |
| `User` | A login. Role is parent or young person |
| `ChildProfile` | Age, mode (child or teen), triggers, what calms them, interests |
| `Consent` | Who consented to what, and when |
| `Accommodation` | One thing the family does because of the anxiety, with status |
| `AccommodationPlan` | The chosen accommodation, the planned change, the announcement text |
| `ParentLogEntry` | Daily log: what happened, child's reaction, parent's response |
| `CoachingMessage` | Agent and parent turns in a coaching session |
| `BraveLadder`, `BraveStep`, `StepAttempt` | The ladder, its steps, and each try |
| `CheckIn` | Young person's mood entry, with optional private note |
| `InterviewMessage` | Parent and Profile Agent turns in the onboarding interview |
| `ProfileItem` | One fact about the child, by section, confirmed by the parent or waiting for them |
| `WeeklySummary` | Generated summary, the numbers counted from the log, and the prompt version that produced it |
| `Alert` | Safety monitor output and whether the parent has seen it |
| `AuditLog` | Who read or changed sensitive data |

Free-text fields that hold sensitive content (log entries, private notes, coaching messages) are encrypted at field level, on top of database encryption at rest.

## Multi-family and multi-child

Every query is scoped to a `Family`. A family may have more than one child, each with their own profile, ladder, and plan. Cross-family access must be impossible by construction, enforced in the data access layer and not left to each endpoint.

As built: every family-owned row carries the family id, one query filter in the database context limits every query to the signed-in family, and saving a row for another family throws.

## Language

All user-facing strings live in resource files. Hebrew is the first language; the layout is right-to-left by default. LLM prompts are written in English and instruct the model to answer in Hebrew.

## Not yet designed

- Data model for lessons, skills modules, the plan, and the event log
- Payments
- iOS build pipeline
- Hosting for the web app
- Account recovery for a young person's login
