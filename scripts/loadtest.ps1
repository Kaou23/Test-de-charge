#############################################################
# Load Test Script for Book Service - PowerShell Version
# Tests concurrent borrowing to verify pessimistic locking
#############################################################

param(
    [string]$BaseUrl = "http://localhost",
    [int]$ConcurrentRequests = 15,
    [int]$InitialStock = 10
)

# Service ports (3 instances)
$Ports = @(8081, 8083, 8084)

# Colors
$Colors = @{
    Red = "Red"
    Green = "Green"
    Yellow = "Yellow"
    Blue = "Cyan"
}

function Write-ColorOutput($message, $color) {
    Write-Host $message -ForegroundColor $color
}

function Get-RandomPort {
    return $Ports | Get-Random
}

Write-ColorOutput "========================================" $Colors.Blue
Write-ColorOutput "  Load Test - Pessimistic Locking TP27 " $Colors.Blue
Write-ColorOutput "========================================" $Colors.Blue
Write-Host ""

# Step 1: Create a test book with initial stock
Write-ColorOutput "Step 1: Creating test book with stock = $InitialStock" $Colors.Yellow

$Port = $Ports[0]
$BookData = @{
    title = "Load Test Book"
    author = "Test Author"
    stock = $InitialStock
    price = 29.99
} | ConvertTo-Json

try {
    $CreateResponse = Invoke-RestMethod -Uri "$BaseUrl`:$Port/api/books" `
        -Method POST `
        -ContentType "application/json" `
        -Body $BookData
    
    $BookId = $CreateResponse.id
    Write-ColorOutput "Created book with ID: $BookId" $Colors.Green
    Write-Host "Response: $($CreateResponse | ConvertTo-Json -Compress)"
} catch {
    Write-ColorOutput "Failed to create book: $_" $Colors.Red
    exit 1
}

Write-Host ""

# Step 2: Verify initial stock
Write-ColorOutput "Step 2: Verifying initial stock" $Colors.Yellow
$BookInfo = Invoke-RestMethod -Uri "$BaseUrl`:$Port/api/books/$BookId" -Method GET
Write-Host "Book info: $($BookInfo | ConvertTo-Json -Compress)"
Write-Host ""

# Step 3: Launch concurrent borrow requests
Write-ColorOutput "Step 3: Launching $ConcurrentRequests concurrent borrow requests" $Colors.Yellow
Write-ColorOutput "Distributing requests across ports: $($Ports -join ', ')" $Colors.Yellow
Write-Host ""

# Create jobs for concurrent requests
$Jobs = @()
for ($i = 1; $i -le $ConcurrentRequests; $i++) {
    $SelectedPort = Get-RandomPort
    
    $Job = Start-Job -ScriptBlock {
        param($Url, $BookId, $Port, $RequestNum)
        
        try {
            $Response = Invoke-RestMethod -Uri "$Url`:$Port/api/books/$BookId/borrow" `
                -Method POST `
                -ContentType "application/json" `
                -ErrorAction Stop
            
            return @{
                RequestNum = $RequestNum
                Port = $Port
                Success = $true
                Stock = $Response.stock
                HttpCode = 200
            }
        } catch {
            $HttpCode = 500
            if ($_.Exception.Response) {
                $HttpCode = [int]$_.Exception.Response.StatusCode
            }
            return @{
                RequestNum = $RequestNum
                Port = $Port
                Success = $false
                Error = $_.Exception.Message
                HttpCode = $HttpCode
            }
        }
    } -ArgumentList $BaseUrl, $BookId, $SelectedPort, $i
    
    $Jobs += @{ Job = $Job; Port = $SelectedPort; RequestNum = $i }
    Write-Host "  Request $i sent to port $SelectedPort (Job: $($Job.Id))"
}

Write-Host ""
Write-ColorOutput "Waiting for all requests to complete..." $Colors.Yellow

# Wait for all jobs and collect results
$Results = @()
foreach ($JobInfo in $Jobs) {
    $Result = $JobInfo.Job | Wait-Job | Receive-Job
    $Results += $Result
    Remove-Job -Job $JobInfo.Job
}

Write-ColorOutput "All requests completed!" $Colors.Green
Write-Host ""

# Step 4: Analyze results
Write-ColorOutput "Step 4: Analyzing results" $Colors.Yellow
Write-Host ""

$SuccessCount = 0
$FailureCount = 0

foreach ($Result in $Results | Sort-Object RequestNum) {
    if ($Result.Success) {
        Write-Host "  Request $($Result.RequestNum) (Port $($Result.Port)): " -NoNewline
        Write-ColorOutput "SUCCESS" $Colors.Green
        Write-Host " (HTTP $($Result.HttpCode), Stock: $($Result.Stock))"
        $SuccessCount++
    } else {
        Write-Host "  Request $($Result.RequestNum) (Port $($Result.Port)): " -NoNewline
        Write-ColorOutput "FAILED" $Colors.Red
        Write-Host " (HTTP $($Result.HttpCode))"
        $FailureCount++
    }
}

Write-Host ""
Write-ColorOutput "========================================" $Colors.Blue
Write-ColorOutput "              RESULTS                   " $Colors.Blue
Write-ColorOutput "========================================" $Colors.Blue
Write-Host "  Initial Stock:     $InitialStock"
Write-Host "  Total Requests:    $ConcurrentRequests"
Write-Host "  " -NoNewline; Write-ColorOutput "Successful:        $SuccessCount" $Colors.Green
Write-Host "  " -NoNewline; Write-ColorOutput "Failed (OOS):      $FailureCount" $Colors.Red
Write-Host ""

# Step 5: Verify final stock
Write-ColorOutput "Step 5: Verifying final stock" $Colors.Yellow
$FinalBook = Invoke-RestMethod -Uri "$BaseUrl`:$($Ports[0])/api/books/$BookId" -Method GET
$FinalStock = $FinalBook.stock

Write-Host "Final book state: $($FinalBook | ConvertTo-Json -Compress)"
Write-Host ""

# Validation
Write-ColorOutput "========================================" $Colors.Blue
Write-ColorOutput "            VALIDATION                  " $Colors.Blue
Write-ColorOutput "========================================" $Colors.Blue

$ExpectedSuccess = $InitialStock

if ($FinalStock -ge 0) {
    Write-ColorOutput "✓ Stock is non-negative: $FinalStock" $Colors.Green
} else {
    Write-ColorOutput "✗ CRITICAL: Stock went negative: $FinalStock" $Colors.Red
}

if ($SuccessCount -eq $ExpectedSuccess) {
    Write-ColorOutput "✓ Successful borrows ($SuccessCount) equals initial stock ($ExpectedSuccess)" $Colors.Green
} else {
    Write-ColorOutput "! Successful borrows ($SuccessCount) differs from initial stock ($ExpectedSuccess)" $Colors.Yellow
}

$ExpectedFailures = $ConcurrentRequests - $InitialStock
if ($FailureCount -eq $ExpectedFailures) {
    Write-ColorOutput "✓ Failed requests ($FailureCount) as expected ($ExpectedFailures)" $Colors.Green
} else {
    Write-ColorOutput "! Failed requests ($FailureCount) differs from expected ($ExpectedFailures)" $Colors.Yellow
}

Write-Host ""
Write-ColorOutput "Load test completed!" $Colors.Green
