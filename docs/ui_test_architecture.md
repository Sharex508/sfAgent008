# UI Test Capture And Replay

This extension adds a reusable UI testing layer to `sfAgent008` so the backend can:

- store named Salesforce UI test flows
- infer related repo components from saved steps
- replay those steps later with Playwright
- persist artifacts such as screenshots, trace files, and video

## Storage Model

The data is stored in the existing `data/index.sqlite` file through `orchestration/store.py`.

Tables added:

- `ui_feature_definitions`
  - durable saved feature/test definitions
- `ui_feature_component_refs`
  - Apex/Flow/LWC/object references linked to the feature
- `ui_feature_runs`
  - execution history for each replay
- `ui_feature_step_results`
  - per-step pass/fail evidence

## API Surface

New endpoints in `server/app.py`:

- `POST /sf-repo-ai/ui-features`
  - create a reusable UI feature
- `GET /sf-repo-ai/ui-features`
  - list saved features
- `GET /sf-repo-ai/ui-features/{feature_id}`
  - get one feature
- `PUT /sf-repo-ai/ui-features/{feature_id}`
  - update feature metadata or steps
- `GET /sf-repo-ai/ui-features/{feature_id}/runs`
  - list replay runs
- `GET /sf-repo-ai/ui-features/{feature_id}/runs/{run_id}`
  - fetch one replay run with step results
- `GET /sf-repo-ai/ui-features/{feature_id}/runs/{run_id}/artifacts`
  - list artifact paths for screenshots, trace, video, and summary
- `POST /sf-repo-ai/ui-features/{feature_id}/run`
  - execute the saved steps with Playwright

## Runner

The runner lives in `orchestration/ui_features.py`.

Supported step actions in the initial version:

- `goto`
- `click`
- `fill`
- `press`
- `select`
- `wait_for`
- `expect_visible`
- `expect_text`
- `screenshot`

Artifacts are written under:

- `data/ui_features/<feature_id>/runs/<run_id>/`

Current outputs:

- `summary.json`
- `screenshots/`
- `trace/<run_id>.zip` when tracing is enabled
- `video/*.webm` when video recording is enabled

If `base_url` is omitted from the run request, the backend now attempts to resolve it from the saved or requested Salesforce org alias by calling the local Salesforce CLI.

If the saved feature uses `login_mode = cli_access_token`, the backend also tries to build a Salesforce `frontdoor.jsp` login URL from the CLI session so Playwright can launch an authenticated Lightning session without a hand-maintained storage state file.

## Dependencies

The backend now declares:

- `playwright>=1.52.0`

To execute UI features on a machine, install:

```bash
pip install -r requirements.txt
playwright install chromium
```

## Current Scope

The template now includes:

- reusable backend APIs
- a generic Salesforce LWC console bundle in `template_repo/force-app/main/default/lwc/agentFeatureConsole`
- a matching Apex controller in `template_repo/force-app/main/default/classes/AgentFeatureController.cls`
- CLI-session-backed browser login for Playwright runs when the org alias is already authenticated locally

Still not included:

- document-to-step parsing
- component extraction from logs after a UI run
- project-specific flow capture UX on top of the generic console

Those can be layered on top of this API rather than mixed into the runner itself.
