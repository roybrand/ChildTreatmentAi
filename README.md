# ChildTreatmentAi

An app that helps families of children and teens with anxiety. Start with [CLAUDE.md](CLAUDE.md), which points to the project documents in [docs/](docs/).

## What is in the repository

| Folder | Contents |
| --- | --- |
| `docs/` | Product, architecture, agents, safety, privacy, status, decisions |
| `prompts/` | Agent prompts, each agent's scenario set and scoring guide, the crisis rules |
| `backend/src/ChildTreatment.Api/` | The ASP.NET Core API |
| `backend/tests/` | Tests. They use a fake model and need no network |
| `backend/tools/AgentEval/` | Runs an agent against its scenario set and scores the replies |
| `mobile/` | The Flutter app for iOS, Android, and the browser |

## Requirements

- .NET 10 SDK
- Docker, for the local PostgreSQL database
- A model API key, either as `Llm:ApiKey` in `appsettings.Development.json` (git ignores that file) or as `ANTHROPIC_API_KEY` in the environment. Never put it in `appsettings.json`

## Run it locally

```bash
cp backend/src/ChildTreatment.Api/appsettings.Development.example.json backend/src/ChildTreatment.Api/appsettings.Development.json
# then put a new 32-byte base64 key in Encryption:Key, and the model API key in Llm:ApiKey
docker compose up -d                 # PostgreSQL on port 5433
dotnet tool restore                  # the EF Core command-line tool
dotnet run --project backend/src/ChildTreatment.Api
```

In development the API applies database migrations on start.

The API listens on http://localhost:5080.

## Run the app

Requires Flutter. For an Android phone it also requires a JDK and the Android SDK.

```bash
cd mobile
flutter run -d chrome            # the web app
```

Resize the browser window to see the phone layout and the wide layout. In the browser, closing the tab signs you out, and so do 15 minutes without activity.

On an Android phone, with the API running on this computer:

1. On the phone, turn on Developer options and USB debugging, and connect it by USB.
2. Let the phone reach the API on this computer, then start the app:

```bash
adb reverse tcp:5080 tcp:5080
flutter run
```

To point the app at another server, add `--dart-define=API_BASE_URL=https://...`.

## Test

```bash
dotnet test                      # backend
cd mobile && flutter test        # app
```

## Evaluate an agent

```bash
dotnet run --project backend/tools/AgentEval                            # the Parent Coach, every scenario, on the cheaper testing models
dotnet run --project backend/tools/AgentEval -- --agent profile-agent   # or planner
dotnet run --project backend/tools/AgentEval -- --group risky           # one group
dotnet run --project backend/tools/AgentEval -- --id risk-01-medication
dotnet run --project backend/tools/AgentEval -- --agent planner --list  # show the scenarios without running them; free
```

Stop the API first if it is running: both build into the same folder.

Each scenario makes up to three model calls, so a run costs real money; the tool prints an estimate when it finishes. To check a prompt before release, run it on the production models:

```bash
dotnet run --project backend/tools/AgentEval -- --model claude-opus-5-5 --effort medium --review-model claude-opus-5-5 --review-effort medium
```
 Reports are written to `eval-results/`. Run the full set after any change to a prompt, and do not release a prompt version that fails a safety criterion on a risky scenario.

## Change the database

```bash
dotnet ef migrations add <Name> -o Data/Migrations --project backend/src/ChildTreatment.Api
```
