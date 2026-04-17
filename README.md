# sf_repo_ai

Reusable Salesforce repo intelligence and delivery template.

This project is meant to be cloned once per Salesforce initiative. After cloning the template, the team registers the actual Salesforce SFDX repo URL, activates it, indexes it, and runs planning, implementation, and deployment workflows against the selected org alias.

## What This Template Does

- Clones and manages Salesforce repos from Git, Bitbucket, GitHub, GitLab, or a local path.
- Keeps one active repo context for indexing, Q&A, planning, development, and deployment.
- Indexes Salesforce metadata from the repo, not live business records from the org.
- Supports API-driven plan -> implement -> deploy workflows.
- Supports scheduled repo sync for daily refresh.

## What Is Indexed

The system indexes repository metadata such as:

- objects and fields
- flows
- Apex classes and triggers
- layouts and flexipages
- validation rules
- permission sets and profiles
- approval processes and sharing rules
- other metadata present under the SFDX source tree

It does not bulk-store live Account, Opportunity, Lead, or customer transaction rows from Salesforce unless a caller explicitly sends runtime evidence to an API endpoint.

## Quick Start

### 1. Clone this template

```bash
git clone <your-template-repo-url> sf_repo_ai
cd sf_repo_ai
python3.11 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### 2. Register the actual Salesforce repo

```bash
python scripts/bootstrap_managed_repo.py \
  --clone-url "https://bitbucket.org/<workspace>/<repo>.git" \
  --branch main \
  --provider bitbucket \
  --name my-salesforce-project \
  --activate
```

This will:

1. clone the target repo under `data/repos/<provider>/<name>`
2. validate the repo structure
3. activate it as the current working repo
4. build local metadata indexes

### 3. Log into the target Salesforce org

```bash
sf org login web --alias my-sandbox
```

### 4. Start the API

```bash
python -m uvicorn server.app:app --host 0.0.0.0 --port 8001 --reload
```

## Repo Setup API

The backend now exposes setup-oriented repo onboarding endpoints for UI-driven flows:

### Bitbucket OAuth Configuration

For full Bitbucket SSO/OAuth repo onboarding, configure these backend environment variables:

- `BITBUCKET_CLIENT_ID`
- `BITBUCKET_CLIENT_SECRET`
- `BITBUCKET_REDIRECT_URI`

Recommended callback path:

- `/sf-repo-ai/repos/connect/bitbucket/callback`

Optional alternatives:

- `BITBUCKET_CONNECT_URL`
  Use this when you already have an external OAuth/connect page and only want the backend to expose that URL to the Salesforce UI.
- `BITBUCKET_ACCESS_TOKEN`
- `BITBUCKET_USERNAME` + `BITBUCKET_APP_PASSWORD`

When OAuth is configured, the backend now:
- generates a Bitbucket authorize URL
- validates callback state
- exchanges the code for tokens
- persists the session in `data/bitbucket_auth.json`
- reuses that token during Bitbucket `git clone` / `git pull` without storing credentials in the repo registry

- `GET /sf-repo-ai/repos/connect/bitbucket/status`
  Returns whether backend Bitbucket credentials/session are available.
- `POST /sf-repo-ai/repos/connect/bitbucket/start`
  Returns the configured Bitbucket connect URL or auth status for the UI connect button.
- `POST /sf-repo-ai/repos/initialize`
  Validates missing inputs, checks Bitbucket connection readiness, then registers/syncs/activates the repo when ready.
- `GET /sf-repo-ai/repos/active`
  Returns the active repo summary for the current backend runtime.

Current limitation:
- Salesforce UI is now wired for repo onboarding, but users still need the backend server to be reachable publicly for the Bitbucket OAuth callback when using ngrok or another public URL.

## Managed Repo Commands

```bash
python scripts/bootstrap_managed_repo.py \
  --clone-url "https://bitbucket.org/<workspace>/<repo>.git" \
  --branch main \
  --provider bitbucket \
  --name my-salesforce-project \
  --activate

python scripts/sync_repos.py list
python scripts/sync_repos.py sync-due
python scripts/sync_repos.py activate <source_id>
python scripts/sync_repos.py cleanup --max-age-days 30 --delete-local
```

## API Families

Current API families exposed by `server/app.py` include:

- `/sf-repo-ai/repos`
- `/sf-repo-ai/repos/active`
- `/sf-repo-ai/repos/connect/bitbucket/status`
- `/sf-repo-ai/repos/connect/bitbucket/start`
- `/sf-repo-ai/repos/connect/bitbucket/callback`
- `/sf-repo-ai/repos/initialize`
- `/sf-repo-ai/repos/register`
- `/sf-repo-ai/repos/register/bitbucket`
- `/sf-repo-ai/repos/{source_id}/activate`
- `/sf-repo-ai/repos/{source_id}/sync`
- `/sf-repo-ai/repos/sync-due`
- `/sf-repo-ai/ask`
- `/sf-repo-ai/feature-explain`
- `/sf-repo-ai/user-story-analyze`
- `/sf-repo-ai/debug-analyze`
- `/sf-repo-ai/development/analyze`
- `/sf-repo-ai/development/plan`
- `/sf-repo-ai/development/run`
- `/sf-repo-ai/work-items/*`
- `/sf-repo-ai/sf-cli/orgs`
- `/sf-repo-ai/sf-cli/deploy`
- `/sf-repo-ai/sf-cli/retrieve`
- `/sf-repo-ai/sf-cli/test`

## CLI Examples

```bash
python -m sf_repo_ai.cli index --repo "/path/to/your-sfdx-repo"
python -m sf_repo_ai.cli graph-build --repo "/path/to/your-sfdx-repo"
python -m sf_repo_ai.cli where-used --field "Account.My_Field__c"
python -m sf_repo_ai.cli validation-rules --object "Case" --contains "Status"
python -m sf_repo_ai.cli explain-object --object "Account"
python -m sf_repo_ai.cli deps --flow "Some_Flow"
python -m sf_repo_ai.cli deps --class "SomeClass"
python -m sf_repo_ai.cli blast-radius --from HEAD~1 --to HEAD --depth 2 --out data/blast_radius.json
python -m sf_repo_ai.cli impact --target "Account"
python -m sf_repo_ai.cli techdebt --out "data/tech_debt.json"
python -m sf_repo_ai.cli ask --question "Which flows update Opportunity Stage?"
```

## Config

Copy `config.yaml.example` to `config.yaml` if you want explicit local defaults. The active managed repo will still be selected from the repo registry unless you override it.

## Notes

- `template_repo/` is only a neutral fallback so the template starts clean.
- project-specific cloned repos and generated indexes are intentionally ignored by `.gitignore`.
- `target_org_alias` is intentionally user-supplied per work item or deploy action; it is not hardcoded to one org.
