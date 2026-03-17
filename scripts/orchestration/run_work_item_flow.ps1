param(
  [string]$BaseUrl = "http://127.0.0.1:8001",
  [string]$ApiKey = "",
  [string]$Title = "User Story Implementation",
  [Parameter(Mandatory = $true)]
  [string]$Story,
  [string]$Model = "gpt-oss:20b",
  [string]$ProjectDir = "C:\Users\narendra\Downloads\sf\sfAgent008\NATTQA-ENV",
  [string]$TargetOrgAlias = "nattqa",
  [switch]$Analyze,
  [switch]$Generate,
  [switch]$ApproveGeneration,
  [switch]$LoginCli,
  [switch]$Retrieve,
  [switch]$Deploy,
  [switch]$RunTests,
  [string]$GenerateMode = "apply",
  [string]$GenerateInstructions = "",
  [int]$GenerateMaxTargets = 12,
  [switch]$GenerateRunOrgValidation,
  [string]$GenerateOrgValidationTestLevel = "",
  [string]$ApproveExecutionId = "",
  [switch]$ApproveRunOrgValidation,
  [string]$ApproveOrgValidationTestLevel = "",
  [string]$LoginUrl = "",
  [string]$ClientId = "",
  [string]$ClientSecret = "",
  [string]$AuthMode = "oauth_client_credentials",
  [string[]]$RetrieveMetadata = @(),
  [string[]]$RetrieveSourceDirs = @(),
  [string]$RetrieveManifest = "",
  [int]$RetrieveWaitMinutes = 20,
  [string[]]$DeployMetadata = @(),
  [string[]]$DeploySourceDirs = @(),
  [string]$DeployManifest = "",
  [int]$DeployWaitMinutes = 30,
  [string]$DeployTestLevel = "RunLocalTests",
  [string[]]$DeployTests = @(),
  [switch]$DeployIgnoreConflicts,
  [switch]$DeployDryRun,
  [int]$TestWaitMinutes = 30,
  [string]$TestLevel = "RunLocalTests",
  [string[]]$TestNames = @(),
  [string[]]$TestClassNames = @(),
  [string[]]$TestSuiteNames = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function New-Headers {
  $headers = @{
    "Content-Type" = "application/json"
  }
  if ($ApiKey) {
    $headers["X-API-Key"] = $ApiKey
  }
  return $headers
}

function Invoke-JsonApi {
  param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("GET", "POST")]
    [string]$Method,
    [Parameter(Mandatory = $true)]
    [string]$Url,
    [object]$Body
  )

  $headers = New-Headers
  if ($Method -eq "GET") {
    return Invoke-RestMethod -Method Get -Uri $Url -Headers $headers
  }

  if ($null -eq $Body) {
    return Invoke-RestMethod -Method Post -Uri $Url -Headers $headers
  }

  $json = $Body | ConvertTo-Json -Depth 10
  return Invoke-RestMethod -Method Post -Uri $Url -Headers $headers -Body $json
}

function Write-Step {
  param([string]$Message)
  Write-Host ""
  Write-Host "==> $Message" -ForegroundColor Cyan
}

function Add-IfValue {
  param(
    [hashtable]$Target,
    [string]$Key,
    [object]$Value
  )
  if ($null -eq $Value) { return }
  if ($Value -is [string] -and [string]::IsNullOrWhiteSpace($Value)) { return }
  if ($Value -is [System.Array] -and $Value.Count -eq 0) { return }
  $Target[$Key] = $Value
}

Write-Step "Health check"
$health = Invoke-JsonApi -Method GET -Url "$BaseUrl/sf-repo-ai/health"
$health | ConvertTo-Json -Depth 5

Write-Step "Create work item"
$workItemBody = @{
  title = $Title
  story = $Story
  model = $Model
  metadata_project_dir = $ProjectDir
  target_org_alias = $TargetOrgAlias
}
$workItem = Invoke-JsonApi -Method POST -Url "$BaseUrl/sf-repo-ai/work-items" -Body $workItemBody
$workItemId = $workItem.work_item_id
$workItem | ConvertTo-Json -Depth 10

if ($Analyze) {
  Write-Step "Analyze work item"
  $analysisBody = @{
    model = $Model
    k = 12
    hybrid = $true
  }
  $analysis = Invoke-JsonApi -Method POST -Url "$BaseUrl/sf-repo-ai/work-items/$workItemId/analyze" -Body $analysisBody
  $analysis | ConvertTo-Json -Depth 10
}

if ($Generate) {
  Write-Step "Generate or update components"
  $generateBody = @{
    model = $Model
    mode = $GenerateMode
    create_missing_components = $true
    run_local_validation = $true
    run_org_validation = [bool]$GenerateRunOrgValidation
    write_changes = ($GenerateMode -ne "plan_only")
    max_targets = $GenerateMaxTargets
  }
  Add-IfValue -Target $generateBody -Key "instructions" -Value $GenerateInstructions
  Add-IfValue -Target $generateBody -Key "org_validation_test_level" -Value $GenerateOrgValidationTestLevel

  $generateResult = Invoke-JsonApi -Method POST -Url "$BaseUrl/sf-repo-ai/work-items/$workItemId/generate-or-update-components" -Body $generateBody
  $generateResult | ConvertTo-Json -Depth 10
}

if ($ApproveGeneration) {
  Write-Step "Approve generation plan"
  $approveBody = @{
    run_local_validation = $true
    run_org_validation = [bool]$ApproveRunOrgValidation
  }
  Add-IfValue -Target $approveBody -Key "execution_id" -Value $ApproveExecutionId
  Add-IfValue -Target $approveBody -Key "org_validation_test_level" -Value $ApproveOrgValidationTestLevel

  $approveResult = Invoke-JsonApi -Method POST -Url "$BaseUrl/sf-repo-ai/work-items/$workItemId/approve-generation" -Body $approveBody
  $approveResult | ConvertTo-Json -Depth 10
}

if ($LoginCli) {
  Write-Step "Login Salesforce CLI alias"
  if (-not $LoginUrl -or -not $ClientId -or -not $ClientSecret) {
    throw "LoginCli requires -LoginUrl, -ClientId, and -ClientSecret."
  }

  $loginBody = @{
    alias = $TargetOrgAlias
    set_default = $true
    login_url = $LoginUrl
    client_id = $ClientId
    client_secret = $ClientSecret
    auth_mode = $AuthMode
  }
  $loginResult = Invoke-JsonApi -Method POST -Url "$BaseUrl/sf-repo-ai/sf-cli/login" -Body $loginBody
  $loginResult | ConvertTo-Json -Depth 10
}

if ($Retrieve) {
  Write-Step "Retrieve metadata"
  $retrieveBody = @{
    work_item_id = $workItemId
    target_org = $TargetOrgAlias
    project_dir = $ProjectDir
    wait_minutes = $RetrieveWaitMinutes
    ignore_conflicts = $true
  }
  Add-IfValue -Target $retrieveBody -Key "metadata" -Value $RetrieveMetadata
  Add-IfValue -Target $retrieveBody -Key "source_dirs" -Value $RetrieveSourceDirs
  Add-IfValue -Target $retrieveBody -Key "manifest" -Value $RetrieveManifest

  $retrieveResult = Invoke-JsonApi -Method POST -Url "$BaseUrl/sf-repo-ai/sf-cli/retrieve" -Body $retrieveBody
  $retrieveResult | ConvertTo-Json -Depth 10
}

if ($Deploy) {
  Write-Step "Deploy metadata"
  $deployBody = @{
    work_item_id = $workItemId
    target_org = $TargetOrgAlias
    project_dir = $ProjectDir
    wait_minutes = $DeployWaitMinutes
    test_level = $DeployTestLevel
    ignore_conflicts = [bool]$DeployIgnoreConflicts
    dry_run = [bool]$DeployDryRun
  }
  Add-IfValue -Target $deployBody -Key "metadata" -Value $DeployMetadata
  Add-IfValue -Target $deployBody -Key "source_dirs" -Value $DeploySourceDirs
  Add-IfValue -Target $deployBody -Key "manifest" -Value $DeployManifest
  Add-IfValue -Target $deployBody -Key "tests" -Value $DeployTests

  $deployResult = Invoke-JsonApi -Method POST -Url "$BaseUrl/sf-repo-ai/sf-cli/deploy" -Body $deployBody
  $deployResult | ConvertTo-Json -Depth 10
}

if ($RunTests) {
  Write-Step "Run Apex tests"
  $testBody = @{
    work_item_id = $workItemId
    target_org = $TargetOrgAlias
    project_dir = $ProjectDir
    wait_minutes = $TestWaitMinutes
    test_level = $TestLevel
    code_coverage = $true
  }
  Add-IfValue -Target $testBody -Key "tests" -Value $TestNames
  Add-IfValue -Target $testBody -Key "class_names" -Value $TestClassNames
  Add-IfValue -Target $testBody -Key "suite_names" -Value $TestSuiteNames

  $testResult = Invoke-JsonApi -Method POST -Url "$BaseUrl/sf-repo-ai/sf-cli/test" -Body $testBody
  $testResult | ConvertTo-Json -Depth 10
}

Write-Step "Final work item status"
$finalWorkItem = Invoke-JsonApi -Method GET -Url "$BaseUrl/sf-repo-ai/work-items/$workItemId"
$finalWorkItem | ConvertTo-Json -Depth 10

Write-Step "Execution history"
$executions = Invoke-JsonApi -Method GET -Url "$BaseUrl/sf-repo-ai/work-items/$workItemId/executions"
$executions | ConvertTo-Json -Depth 10

Write-Step "Summary"
[pscustomobject]@{
  work_item_id = $workItemId
  status = $finalWorkItem.status
  target_org_alias = $TargetOrgAlias
  metadata_project_dir = $ProjectDir
} | ConvertTo-Json -Depth 5
