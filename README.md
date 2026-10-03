# ChildTreatmentAi

An app that helps families of children and teens with anxiety. Start with [CLAUDE.md](CLAUDE.md), which points to the project documents in [docs/](docs/).

## What is in the repository

| Folder | Contents |
| --- | --- |
| `docs/` | Product, architecture, agents, safety, privacy, status, decisions |
| `prompts/` | Agent prompts, the Parent Coach scenario set and scoring guide, the crisis rules |
| `backend/src/ChildTreatment.Api/` | The ASP.NET Core API |
| `backend/tests/` | Tests. They use a fake model and need no network |
| `backend/tools/AgentEval/` | Runs an agent against its scenario set and scores the replies |
| `mobile/` | The Flutter app for iOS and Android |

## Requirements

- .NET 10 SDK
- Docker, for the local PostgreSQL database
- `ANTHROPIC_API_KEY` set in the environment

## Run it locally

```bash
cp backend/src/ChildTreatment.Api/appsettings.Development.example.json backend/src/ChildTreatment.Api/appsettings.Development.json
# then put a new 32-byte base64 key in Encryption:Key
docker compose up -d                 # PostgreSQL on port 5433
dotnet tool restore                  # the EF Core command-line tool
dotnet run --project backend/src/ChildTreatment.Api
```

In development the API applies database migrations on start.

## Test

```bash
dotnet test
```

## Evaluate the Parent Coach

```bash
dotnet run --project backend/tools/AgentEval                     # every scenario, on the cheaper testing models
dotnet run --project backend/tools/AgentEval -- --group risky    # one group
dotnet run --project backend/tools/AgentEval -- --id risk-01-medication
```

Each scenario makes up to three model calls, so a run costs real money; the tool prints an estimate when it finishes. To check a prompt before release, run it on the production models:

```bash
dotnet run --project backend/tools/AgentEval -- --model claude-opus-5-5 --effort medium --review-model claude-opus-5-5 --review-effort medium
```
 Reports are written to `eval-results/`. Run the full set after any change to a prompt, and do not release a prompt version that fails a safety criterion on a risky scenario.

## Change the database

```bash
dotnet ef migrations add <Name> -o Data/Migrations --project backend/src/ChildTreatment.Api
```
