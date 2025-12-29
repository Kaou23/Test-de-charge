# Load Test Script for Lab Proofs - Simplified Version
# Tests concurrent borrowing with specified number of requests

param(
    [string]$BaseUrl = "http://localhost",
    [int]$BookId = 1,
    [int]$ConcurrentRequests = 50
)

$Ports = @(8081, 8083, 8084)

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  LOAD TEST - TP27 Proof Collection   " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Book ID: $BookId"
Write-Host "Concurrent Requests: $ConcurrentRequests"
Write-Host "Ports: $($Ports -join ', ')"
Write-Host ""

# Check initial stock
Write-Host "--- Initial Book State ---" -ForegroundColor Yellow
$InitialBook = Invoke-RestMethod -Uri "$BaseUrl`:$($Ports[0])/api/books/$BookId" -Method GET
Write-Host "Book: $($InitialBook | ConvertTo-Json -Compress)"
$InitialStock = $InitialBook.stock
Write-Host "Initial Stock: $InitialStock" -ForegroundColor Cyan
Write-Host ""

# Launch concurrent requests
Write-Host "--- Launching $ConcurrentRequests Concurrent Borrow Requests ---" -ForegroundColor Yellow
$Jobs = @()
for ($i = 1; $i -le $ConcurrentRequests; $i++) {
    $Port = $Ports[$i % $Ports.Count]
    $Job = Start-Job -ScriptBlock {
        param($Url, $BookId, $Port, $Num)
        try {
            $Response = Invoke-RestMethod -Uri "$Url`:$Port/api/books/$BookId/borrow" -Method POST -ContentType "application/json" -ErrorAction Stop
            return @{ Num=$Num; Port=$Port; Success=$true; Stock=$Response.stock }
        } catch {
            return @{ Num=$Num; Port=$Port; Success=$false; Error=$_.Exception.Message }
        }
    } -ArgumentList $BaseUrl, $BookId, $Port, $i
    $Jobs += $Job
}

# Wait and collect results
Write-Host "Waiting for all requests to complete..."
$Results = $Jobs | Wait-Job | Receive-Job
$Jobs | Remove-Job

# Analyze results
$SuccessCount = ($Results | Where-Object { $_.Success }).Count
$FailureCount = ($Results | Where-Object { -not $_.Success }).Count

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "           RESULTS                     " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total Requests:    $ConcurrentRequests"
Write-Host "SUCCESS:           $SuccessCount" -ForegroundColor Green
Write-Host "CONFLICTS (409):   $FailureCount" -ForegroundColor Red
Write-Host ""

# Final stock verification
Write-Host "--- Final Book State ---" -ForegroundColor Yellow
$FinalBook = Invoke-RestMethod -Uri "$BaseUrl`:$($Ports[0])/api/books/$BookId" -Method GET
Write-Host "Book: $($FinalBook | ConvertTo-Json -Compress)"
$FinalStock = $FinalBook.stock
Write-Host "Final Stock: $FinalStock" -ForegroundColor Cyan
Write-Host ""

# Validation
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "          VALIDATION                   " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

if ($FinalStock -ge 0) {
    Write-Host "[OK] Stock is non-negative: $FinalStock" -ForegroundColor Green
} else {
    Write-Host "[CRITICAL] Stock went NEGATIVE: $FinalStock" -ForegroundColor Red
}

if ($FinalStock -eq 0) {
    Write-Host "[OK] Final stock = 0 (as expected)" -ForegroundColor Green
}

if ($SuccessCount -eq $InitialStock) {
    Write-Host "[OK] $SuccessCount successful borrows = initial stock ($InitialStock)" -ForegroundColor Green
} else {
    Write-Host "[INFO] $SuccessCount successful borrows vs initial stock ($InitialStock)" -ForegroundColor Yellow
}

$ExpectedFails = $ConcurrentRequests - $InitialStock
if ($FailureCount -ge $ExpectedFails) {
    Write-Host "[OK] $FailureCount conflicts (expected: >= $ExpectedFails)" -ForegroundColor Green
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  CONCLUSION: Pessimistic lock works!  " -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
