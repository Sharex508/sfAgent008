# Copado Direct Sales Flow - Execution Scripts (Records + Debug Logs)

This document gives execution-ready steps to reproduce the flow from the video with:
1. Data setup scripts
2. Debug log / trace setup
3. Approval submission script hooks

## 1) Files generated for execution

1. Seed data Apex:
- `scripts/video_repro/direct_sales_seed.apex`

2. Quote submit/approve Apex:
- `scripts/video_repro/quote_submit_and_approve.apex`

## 2) Prerequisites

1. Salesforce CLI authenticated to target sandbox (`sf` command).
2. Local API server running (`uvicorn`) if using trace endpoints.
3. User(s) with permission to:
- create Opportunity, Opportunity Product, custom ship-date object records
- submit approvals
- manage trace flags/debug logs

## 3) Enable debug trace (Option A: API endpoint)

Run in PowerShell:

```powershell
$base = "http://127.0.0.1:8001"
$headers = @{ "Content-Type" = "application/json" }   # add X-API-Key if AGENT_API_KEY is enabled

$traceBody = @{
  login_url = "https://test.salesforce.com"
  username  = "<SF_USERNAME>"
  password  = "<SF_PASSWORD>"
  token     = "<SF_SECURITY_TOKEN>"
  user      = "<SF_USERNAME_OR_005_USER_ID>"
  minutes   = 45
} | ConvertTo-Json

Invoke-RestMethod -Uri "$base/sf-repo-ai/logs/trace/enable" -Method Post -Headers $headers -Body $traceBody
```

## 4) Seed records

Run:

```powershell
sf apex run --target-org <ORG_ALIAS> --file scripts/video_repro/direct_sales_seed.apex
```

What this script does:
1. Locates (or creates) `Test Direct Sales Account`.
2. Creates a new opportunity in that account.
3. Sets stage to `Quoting`.
4. Adds opportunity product `Vector 8600 - System 16` (qty=5) if pricebook entry exists.
5. Creates one `Opportunity_Scheduled_Pick_Date__c` record (if object/fields exist).
6. Emits `PROCESS_CAPTURE_ID=...` marker in debug logs.

## 5) Quote submission / approval helper

Open `scripts/video_repro/quote_submit_and_approve.apex` and set:
1. `TARGET_QUOTE_NUMBER` (example: `Q-25088` or clone quote number)

Then run:

```powershell
sf apex run --target-org <ORG_ALIAS> --file scripts/video_repro/quote_submit_and_approve.apex
```

Notes:
1. Script submits quote for approval using `Approval.ProcessSubmitRequest`.
2. Script also attempts approval of current user's pending work items.
3. If work item is assigned to another user, run as that approver user context.

## 6) Disable trace (after run)

```powershell
$disableBody = @{
  login_url = "https://test.salesforce.com"
  username  = "<SF_USERNAME>"
  password  = "<SF_PASSWORD>"
  token     = "<SF_SECURITY_TOKEN>"
  user      = "<SF_USERNAME_OR_005_USER_ID>"
} | ConvertTo-Json

Invoke-RestMethod -Uri "$base/sf-repo-ai/logs/trace/disable" -Method Post -Headers $headers -Body $disableBody
```

## 7) Expected verification checkpoints

1. Opportunity stage is `Quoting`.
2. Opportunity has product lines (including `Vector 8600 - System 16`).
3. Opportunity has `Opportunity Requested Ship Date` child records.
4. Quote exists and enters `Pending Approval` then `Approved` depending on approver actions.
5. Debug logs contain `PROCESS_CAPTURE_ID=` marker from the scripts.

