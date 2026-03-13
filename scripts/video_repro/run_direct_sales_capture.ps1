param(
  [Parameter(Mandatory = $true)][string]$OrgAlias,
  [Parameter(Mandatory = $true)][string]$LoginUrl,
  [Parameter(Mandatory = $true)][string]$Username,
  [Parameter(Mandatory = $true)][string]$Password,
  [Parameter(Mandatory = $true)][string]$Token,
  [Parameter(Mandatory = $true)][string]$TraceUser,
  [string]$TargetQuoteNumber = "Q-25088",
  [int]$Minutes = 45,
  [switch]$SkipApprovalScript
)

$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..\\..")

Write-Host "Starting capture for direct_sales..."
$startJson = .\.venv\Scripts\python.exe scripts\process_capture.py start `
  --login-url $LoginUrl `
  --username $Username `
  --password $Password `
  --token $Token `
  --user $TraceUser `
  --minutes $Minutes `
  --tail-seconds 180

$start = $startJson | ConvertFrom-Json
$captureId = $start.capture_id
Write-Host "Capture ID: $captureId"

$tempDir = Join-Path "data\\tmp" ("direct_sales_" + $captureId)
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
$stop = $null

try {
  Write-Host "Recording UI entry event..."
  .\.venv\Scripts\python.exe scripts\process_capture.py ui-event `
    --capture-id $captureId `
    --event-type "LWC_CONNECTED" `
    --component-name "c:createNattOppLwc" `
    --action-name "connectedCallback" `
    --element-label "Create Opportunity page"

  Write-Host "Recording account creation click..."
  .\.venv\Scripts\python.exe scripts\process_capture.py ui-event `
    --capture-id $captureId `
    --event-type "BUTTON_CLICK" `
    --component-name "c:createNattOppLwc" `
    --action-name "Create Account" `
    --element-label "Create Account"

  Write-Host "Running seed script..."
  $seedScript = Get-Content -Path "scripts\\video_repro\\direct_sales_seed.apex" -Raw
  $seedScript = $seedScript.Replace("__CAPTURE_ID__", $captureId)
  $seedScriptPath = Join-Path $tempDir "direct_sales_seed.runtime.apex"
  $seedScript | Out-File -FilePath $seedScriptPath -Encoding utf8
  sf apex run --target-org $OrgAlias --file $seedScriptPath

  if (-not $SkipApprovalScript) {
    Write-Host "Recording quote page navigation..."
    .\.venv\Scripts\python.exe scripts\process_capture.py ui-event `
      --capture-id $captureId `
      --event-type "NAVIGATE" `
      --component-name "c:createNattQuoteLwc" `
      --action-name "Open Quote" `
      --element-label "Quote wizard"

    Write-Host "Recording approval submit click..."
    .\.venv\Scripts\python.exe scripts\process_capture.py ui-event `
      --capture-id $captureId `
      --event-type "BUTTON_CLICK" `
      --component-name "c:createNattQuoteLwc" `
      --action-name "Submit for Approval" `
      --element-label "Submit"

    Write-Host "Running submit/approve helper..."
    $approvalScript = Get-Content -Path "scripts\\video_repro\\quote_submit_and_approve.apex" -Raw
    $approvalScript = $approvalScript.Replace("__CAPTURE_ID__", $captureId)
    $approvalScript = $approvalScript.Replace("__TARGET_QUOTE_NUMBER__", $TargetQuoteNumber)
    $approvalScriptPath = Join-Path $tempDir "quote_submit_and_approve.runtime.apex"
    $approvalScript | Out-File -FilePath $approvalScriptPath -Encoding utf8
    sf apex run --target-org $OrgAlias --file $approvalScriptPath
  }
}
finally {
  Write-Host "Stopping capture and analyzing logs..."
  $stopJson = .\.venv\Scripts\python.exe scripts\process_capture.py stop `
    --login-url $LoginUrl `
    --username $Username `
    --password $Password `
    --token $Token `
    --capture-id $captureId `
    --analyze
  $stop = $stopJson | ConvertFrom-Json

  if (Test-Path $tempDir) {
    Remove-Item -Path $tempDir -Recurse -Force
  }
}

Write-Host "Saving process definition as direct_sales..."
.\.venv\Scripts\python.exe scripts\process_capture.py save `
  --capture-id $captureId `
  --name direct_sales `
  --description "Direct sales process captured from scripted replay and debug logs."

Write-Host "Extracting sequential component report..."
.\.venv\Scripts\python.exe scripts\video_repro\extract_sequential_processes.py `
  --process-name direct_sales `
  --capture-id $captureId

$runDir = "data\\artifacts\\$captureId"
$summary = [ordered]@{
  process_name = "direct_sales"
  capture_id = $captureId
  started = $start
  stopped = $stop
  artifacts_dir = $runDir
  generated_at = (Get-Date).ToString("s")
}

$summaryPath = "data\\processes\\direct_sales\\latest_run.json"
New-Item -Path (Split-Path $summaryPath) -ItemType Directory -Force | Out-Null
$summary | ConvertTo-Json -Depth 8 | Out-File -FilePath $summaryPath -Encoding utf8

Write-Host "Done."
Write-Host "Summary file: $summaryPath"
Write-Host "Artifacts dir: $runDir"
