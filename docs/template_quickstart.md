# Template Quickstart

## Goal

Use `sf_repo_ai` as a reusable project starter.

## First-time setup

```bash
python3.11 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Register a Salesforce repo

```bash
python scripts/bootstrap_managed_repo.py \
  --clone-url "https://bitbucket.org/<workspace>/<repo>.git" \
  --branch main \
  --provider bitbucket \
  --name my-salesforce-project \
  --activate
```

## Log into Salesforce

```bash
sf org login web --alias my-sandbox
```

## Start the API

```bash
python -m uvicorn server.app:app --host 0.0.0.0 --port 8001 --reload
```

## Daily sync

```bash
python scripts/sync_repos.py sync-due
```
