# Generate Or Update Components API

## Purpose

This is the next orchestration step after:

1. `work item created`
2. `story analyzed`
3. `impacted components identified`

The goal is to let `gpt-oss:20b` produce concrete code or metadata changes while deterministic services handle file writes, validation, deployment, and persistence.

## Outcome

The API should:

- take a `work_item_id`
- load the story analysis and impacted components
- ask `gpt-oss:20b` to propose precise component changes
- write those changes into the repo in a controlled way
- persist the generated plan and changed files
- optionally trigger validation

## Recommended endpoint

- `POST /sf-repo-ai/work-items/{work_item_id}/generate-or-update-components`

## Request body

```json
{
  "model": "gpt-oss:20b",
  "mode": "apply",
  "target_components": [
    {
      "kind": "ApexClass",
      "name": "MyController"
    },
    {
      "kind": "LightningComponentBundle",
      "name": "myComponent"
    }
  ],
  "instructions": "Add validation and error handling for quote submission.",
  "create_missing_components": true,
  "run_local_validation": true,
  "write_changes": true
}
```

## Request fields

- `model`: LLM to use. Default `gpt-oss:20b`.
- `mode`: `plan_only` or `apply`.
- `target_components`: optional narrowed component list. If omitted, use impacted components from work item analysis.
- `instructions`: extra user direction.
- `create_missing_components`: allow new files if the story requires them.
- `run_local_validation`: run lint or syntax validation after write.
- `write_changes`: when `false`, produce a patch plan only.

## Response body

```json
{
  "work_item_id": "uuid",
  "status": "GENERATED",
  "model": "gpt-oss:20b",
  "generation_summary": "Updated one Apex class and one LWC bundle.",
  "changed_components": [
    {
      "kind": "ApexClass",
      "name": "MyController",
      "path": "force-app/main/default/classes/MyController.cls",
      "action": "updated"
    },
    {
      "kind": "LightningComponentBundle",
      "name": "myComponent",
      "path": "force-app/main/default/lwc/myComponent",
      "action": "updated"
    }
  ],
  "artifacts": {
    "generation_plan_path": "data/work_items/<id>/generation_plan.json",
    "patch_summary_path": "data/work_items/<id>/patch_summary.md"
  },
  "validation": {
    "status": "SUCCEEDED",
    "checks": [
      {
        "name": "python_compile",
        "status": "SUCCEEDED"
      }
    ]
  }
}
```

## Internal flow

### 1. Load work item context

Inputs:

- story
- analysis
- impacted components
- metadata project directory

If any of these are missing, return `400`.

### 2. Resolve component context

For each impacted component:

- locate source file or bundle
- extract current content
- attach a compact snippet to the model prompt

This should use deterministic file loading, not free-form model search.

### 3. Ask the model for a structured change plan

The prompt should force structured output like:

```json
{
  "summary": "...",
  "changes": [
    {
      "kind": "ApexClass",
      "name": "MyController",
      "path": "force-app/main/default/classes/MyController.cls",
      "action": "update",
      "reason": "..."
    }
  ]
}
```

This keeps the model in the planner role first.

### 4. Generate file content

For each approved change:

- send focused prompts with existing file content
- request full replacement content or targeted patch blocks
- validate file type expectations

Examples:

- Apex: valid `.cls`
- LWC: `.js`, `.html`, `.js-meta.xml`
- Flow metadata: valid XML

### 5. Write files deterministically

The service should:

- create backups or write artifact snapshots
- apply writes locally
- record every changed file in persistence

### 6. Run local validation

Examples:

- Python compile checks for backend changes
- optional `eslint` or `prettier` for LWC if available
- XML parse check for metadata XML

### 7. Persist results

Store in `orchestration_work_items`:

- `changed_components_json`
- `final_summary`
- `status = GENERATED`

Store an execution record in `orchestration_executions`:

- `operation_type = generate_or_update_components`
- request
- result

## Suggested persistence additions

Current table already has:

- `changed_components_json`
- `final_summary`

That is enough for a first version.

Optional later additions:

- `generation_plan_json`
- `validation_result_json`
- `artifact_root_path`

## Suggested status model

- `NEW`
- `ANALYZED`
- `GENERATING`
- `GENERATED`
- `GENERATION_FAILED`
- `DEPLOYED`
- `DEPLOY_FAILED`
- `TESTED`
- `TEST_FAILED`
- `COMPLETED`

## Approval gate

Recommended optional field:

```json
{
  "requires_approval": true
}
```

Flow:

1. generate plan
2. user reviews impacted files
3. apply writes only after approval

For now, `mode = plan_only` can serve as the approval checkpoint.

## Minimal first implementation

Version 1 should support:

- Apex classes
- LWC bundles
- simple metadata XML updates

Version 1 should not yet attempt:

- complex flow XML authoring
- destructive metadata deletes
- profile-wide rewrites

## Recommended next code modules

- `orchestration/generator.py`
- `orchestration/context_loader.py`
- `orchestration/validators.py`

## Recommended companion endpoints

- `POST /sf-repo-ai/work-items/{work_item_id}/generate-or-update-components`
- `GET /sf-repo-ai/work-items/{work_item_id}/generated-files`
- `POST /sf-repo-ai/work-items/{work_item_id}/approve-generation`

## Practical usage flow

1. `POST /work-items`
2. `POST /work-items/{id}/analyze`
3. `POST /work-items/{id}/generate-or-update-components`
4. `POST /sf-cli/deploy`
5. `POST /sf-cli/test`
6. `GET /work-items/{id}`

This gives a clean path from user story to generated code to deployed validation.
