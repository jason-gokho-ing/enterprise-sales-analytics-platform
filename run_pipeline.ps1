<#
Simple usage
--------------
This script runs the ETL pipeline (Bronze → Silver → Gold) using `sqlcmd`.
It detects whether the target database is already set up and chooses between two modes:
- First-time setup: runs all steps including DDL to create tables and views. Use this mode for the initial run.
- Refresh: runs only the data loading and transformation steps
#>

param(
        [string]$ServerName = ".\SQLEXPRESS",
        [string]$DatabaseName = "DWH"
)

# Basic path setup
$scriptLocation = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$sqlFolder = Join-Path $scriptLocation "sql"
$startTime = Get-Date

# Returns $true if the target database already exists.
function Test-DatabaseExists {
    param(
        [string]$ServerName,
        [string]$DatabaseName
    )

    $escapedDatabaseName = $DatabaseName.Replace("'", "''")
    $query = "SET NOCOUNT ON; IF DB_ID(N'$escapedDatabaseName') IS NULL SELECT 0 ELSE SELECT 1"
    $probe = & sqlcmd -S $ServerName -d master -E -h -1 -W -Q $query 2>$null

    return ($LASTEXITCODE -eq 0 -and ($probe -match '1'))
}

# Returns $true only when refresh prerequisites are present.
# This prevents "refresh" mode from running against a half-built database.
function Test-RefreshReady {
    param(
        [string]$ServerName,
        [string]$DatabaseName
    )

    # Refresh mode requires these core medallion objects to exist already.
    $query = @"
SET NOCOUNT ON;
IF OBJECT_ID('bronze.crm_cust_info', 'U') IS NULL SELECT 0
ELSE IF OBJECT_ID('bronze.crm_prd_info', 'U') IS NULL SELECT 0
ELSE IF OBJECT_ID('bronze.crm_sales_details', 'U') IS NULL SELECT 0
ELSE IF OBJECT_ID('silver.dim_customer', 'U') IS NULL SELECT 0
ELSE IF OBJECT_ID('silver.dim_product', 'U') IS NULL SELECT 0
ELSE IF OBJECT_ID('silver.fact_orders', 'U') IS NULL SELECT 0
ELSE IF OBJECT_ID('gold.dim_customer_info', 'V') IS NULL SELECT 0
ELSE IF OBJECT_ID('gold.dim_product_info', 'V') IS NULL SELECT 0
ELSE IF OBJECT_ID('gold.sales_analytics', 'V') IS NULL SELECT 0
ELSE SELECT 1;
"@

    $probe = & sqlcmd -S $ServerName -d $DatabaseName -E -h -1 -W -Q $query 2>$null
    return ($LASTEXITCODE -eq 0 -and ($probe -match '1'))
}

# Runs one SQL file and fails fast if sqlcmd reports an error.
function Invoke-SqlFile {
    param(
        [string]$FilePath,
        [string]$Database,
        [int]$StepNumber,
        [int]$TotalSteps
    )

    $fullPath = Join-Path $sqlFolder $FilePath
    $sqlToRun = $fullPath

    if (-not (Test-Path $fullPath)) {
        throw "File not found: $fullPath"
    }

    if ((Get-Content $fullPath -Raw) -match '\$\(RepoRoot\)') {
        $tempFile = Join-Path $env:TEMP ([System.IO.Path]::GetRandomFileName() + '.sql')
        $repoRootEscaped = $scriptLocation.Replace('\\', '\\\\')
        $sqlText = Get-Content $fullPath -Raw
        $sqlText = $sqlText -replace '\$\(RepoRoot\)', $repoRootEscaped
        Set-Content -Path $tempFile -Value $sqlText -Encoding UTF8
        $sqlToRun = $tempFile
    }

    Write-Host "[$StepNumber/$TotalSteps] Running: $FilePath (DB: $Database)" -ForegroundColor Yellow
    & sqlcmd -S $ServerName -d $Database -E -b -r 1 -i $sqlToRun

    if ($LASTEXITCODE -ne 0) {
        throw "sqlcmd failed for $FilePath with exit code $LASTEXITCODE"
    }

    if ($sqlToRun -ne $fullPath -and (Test-Path $sqlToRun)) {
        Remove-Item $sqlToRun -Force
    }

    Write-Host "Done" -ForegroundColor Green
}

Write-Host "Enterprise Sales Analytics pipeline" -ForegroundColor Green
Write-Host "Server: $ServerName"
Write-Host "Database: $DatabaseName"

# 1) Decide mode (first-time setup vs refresh)
$dbExists = Test-DatabaseExists -ServerName $ServerName -DatabaseName $DatabaseName
$refreshReady = $dbExists -and (Test-RefreshReady -ServerName $ServerName -DatabaseName $DatabaseName)
$runFirstTimeSetup = (-not $dbExists) -or (-not $refreshReady)

# 2) Build SQL step list for selected mode
$filesToRun = @()

if ($runFirstTimeSetup) {
    if ($dbExists -and -not $refreshReady) {
        Write-Host "Detected partial database setup. Running first-time setup to rebuild missing objects." -ForegroundColor DarkYellow
    }

    Write-Host "Mode: first-time setup" -ForegroundColor Cyan
    $filesToRun = @(
        @{ Path = "00_init\01_init_dwh.sql"; Database = "master" },
        @{ Path = "01_bronze\bronze_create_tables.sql"; Database = $DatabaseName },
        @{ Path = "01_bronze\load_all_direct.sql"; Database = $DatabaseName },
        @{ Path = "02_silver\silver_create_tables.sql"; Database = $DatabaseName },
        @{ Path = "02_silver\transform_data.sql"; Database = $DatabaseName },
        @{ Path = "03_gold\gold_views.sql"; Database = $DatabaseName }
    )
}
else {
    Write-Host "Mode: refresh" -ForegroundColor Cyan
    $filesToRun = @(
        @{ Path = "01_bronze\load_all_direct.sql"; Database = $DatabaseName },
        @{ Path = "02_silver\transform_data.sql"; Database = $DatabaseName },
        @{ Path = "03_gold\gold_views.sql"; Database = $DatabaseName }
    )
}

$failedAtStep = $null
$currentStepNumber = 0
$totalSteps = $filesToRun.Count

# 3) Execute steps in order and stop on first error
foreach ($file in $filesToRun) {
    $currentStepNumber++
    try {
        Invoke-SqlFile -FilePath $file.Path -Database $file.Database -StepNumber $currentStepNumber -TotalSteps $totalSteps
    }
    catch {
        $failedAtStep = $file.Path
        $failedFilePath = Join-Path $sqlFolder $file.Path
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host "Tip: run only the failed file to debug quickly:" -ForegroundColor DarkYellow
        Write-Host ('sqlcmd -S {0} -d {1} -E -b -r 1 -i "{2}"' -f $ServerName, $file.Database, $failedFilePath) -ForegroundColor DarkYellow
        break
    }
}

$totalTime = (Get-Date) - $startTime
Write-Host ""
Write-Host "Total time: $([Math]::Round($totalTime.TotalSeconds)) sec"

if ($failedAtStep) {
    Write-Host "Pipeline failed at: $failedAtStep" -ForegroundColor Red
    exit 1
}

Write-Host "Pipeline complete" -ForegroundColor Green
exit 0
