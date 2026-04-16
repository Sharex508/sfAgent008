# Managed Repo Template

This project is a neutral Salesforce delivery template.

## Intended workflow

1. Clone this template repo.
2. Register the real Salesforce SFDX repo URL.
3. Activate that repo as the active working context.
4. Build indexes from the active repo.
5. Log into the target org with the alias you want to deploy to.
6. Run plan -> implement -> deploy against that repo and org alias.
7. Use `sync-due` for daily repo refresh.

## Bootstrap command

```bash
python scripts/bootstrap_managed_repo.py \
  --clone-url "https://bitbucket.org/<workspace>/<repo>.git" \
  --branch main \
  --provider bitbucket \
  --name my-salesforce-project \
  --activate
```

## Important rule

This template should not ship with one customer repo or one org alias baked into source control.
