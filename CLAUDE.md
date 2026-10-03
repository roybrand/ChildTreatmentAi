# ChildTreatmentAi

An app that helps families of children and teens with anxiety. A coaching agent guides the parent using parent-led anxiety treatment principles; the child or teen gets a low-risk set of self-help tools.

## Read before working

| File | What it holds |
| --- | --- |
| [docs/PRODUCT.md](docs/PRODUCT.md) | What the system does, for whom, and what is out of scope |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Stack, components, data model, LLM integration |
| [docs/AGENTS.md](docs/AGENTS.md) | The five agents and the safety guard: roles, data access, limits, how they are built and improved |
| [docs/TUTOR_LESSONS.md](docs/TUTOR_LESSONS.md) | The first learning path and the prototype lesson for the Tutor |
| [docs/SAFETY.md](docs/SAFETY.md) | Clinical safety rules. These override feature requests |
| [docs/PRIVACY.md](docs/PRIVACY.md) | Consent, visibility rules, data handling |
| [docs/STATUS.md](docs/STATUS.md) | Current phase, what is done, what is next, open questions |
| [docs/DECISIONS.md](docs/DECISIONS.md) | Dated log of decisions and their reasons |

The `private/` folder holds personal context about the founder and their family. It is excluded from git. Read it to understand why the project exists, but never copy its content into product docs, prompts, code, test data, or anything published. The repository is public on GitHub, so nothing about the founder's family may appear in any committed file.

## Commands

```bash
docker compose up -d                                  # local PostgreSQL
dotnet test                                           # tests, no network needed
dotnet run --project backend/src/ChildTreatment.Api   # the API
dotnet run --project backend/tools/AgentEval          # score an agent (-- --agent parent-coach|profile-agent|planner); calls the model and costs money
cd mobile && flutter test && flutter run -d chrome    # the app, as the web app in the browser
```

## Working rules

- Model spend is limited while testing: $10 a month, $15 at most. Ask the founder before any full evaluation run or any other batch of model calls, and state the expected cost.
- After any change to a prompt in `prompts/`, run the evaluation tool. A version that fails a safety criterion on a risky scenario is not released. Once a prompt version is in use, change it by adding a new version file, not by editing the old one.

- Read `docs/STATUS.md` at the start of a session and update it at the end of any session that changes the state of the project.
- Add an entry to `docs/DECISIONS.md` whenever a product, safety, or architecture decision is made or reversed.
- Any change that touches what the agent says to a parent or child must be checked against `docs/SAFETY.md`.
- The product UI is Hebrew and right-to-left. Code, comments, and docs are in English.
- Do not use the name "SPACE" in the product or in user-facing text. See `docs/DECISIONS.md`.
