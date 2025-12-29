#############################################################
# Circuit Breaker Test Script - PowerShell
# Tests Resilience4j Circuit Breaker behavior
#############################################################

param(
    [string]$BaseUrl = "http://localhost",
    [int]$Port = 8081
)

function Write-ColorOutput($message, $color) {
    Write-Host $message -ForegroundColor $color
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Circuit Breaker Test - TP27          " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check Circuit Breaker initial state
Write-Host "Step 1: Checking Circuit Breaker initial state" -ForegroundColor Yellow
try {
    $CBState = Invoke-RestMethod -Uri "$BaseUrl`:$Port/actuator/circuitbreakers" -Method GET
    Write-Host "Circuit Breaker state: $($CBState | ConvertTo-Json -Depth 5)"
} catch {
    Write-Host "Could not retrieve circuit breaker state: $_" -ForegroundColor Red
}
Write-Host ""

# Step 2: Create a test book
Write-Host "Step 2: Creating test book" -ForegroundColor Yellow
$BookData = @{
    title = "Circuit Breaker Test Book"
    author = "Test Author"
    stock = 100
    price = 19.99
} | ConvertTo-Json

try {
    $Book = Invoke-RestMethod -Uri "$BaseUrl`:$Port/api/books" `
        -Method POST `
        -ContentType "application/json" `
        -Body $BookData
    $BookId = $Book.id
    Write-ColorOutput "Created book with ID: $BookId" Green
} catch {
    Write-ColorOutput "Failed to create book: $_" Red
    exit 1
}
Write-Host ""

# Step 3: Test pricing endpoint (pricing-service should be UP)
Write-Host "Step 3: Testing pricing endpoint (pricing-service UP)" -ForegroundColor Yellow
try {
    $PriceResponse = Invoke-RestMethod -Uri "$BaseUrl`:$Port/api/books/$BookId/pricing" -Method GET
    Write-ColorOutput "Price retrieved: $($PriceResponse.price)" Green
} catch {
    Write-ColorOutput "Pricing call failed (expected if pricing-service is down): $_" Yellow
}
Write-Host ""

# Step 4: Instructions for manual test
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  MANUAL TEST INSTRUCTIONS             " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "To test the Circuit Breaker fallback:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Stop the pricing-service:" -ForegroundColor White
Write-Host "   docker-compose stop pricing-service" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Make multiple requests to the pricing endpoint:" -ForegroundColor White
Write-Host "   Invoke-RestMethod -Uri '$BaseUrl`:$Port/api/books/$BookId/pricing'" -ForegroundColor Gray
Write-Host ""
Write-Host "3. After 5 failures, the circuit will OPEN" -ForegroundColor White
Write-Host "   Fallback should return price = 0.0" -ForegroundColor White
Write-Host ""
Write-Host "4. Check circuit breaker state:" -ForegroundColor White
Write-Host "   Invoke-RestMethod -Uri '$BaseUrl`:$Port/actuator/circuitbreakers'" -ForegroundColor Gray
Write-Host ""
Write-Host "5. Restart pricing-service:" -ForegroundColor White
Write-Host "   docker-compose start pricing-service" -ForegroundColor Gray
Write-Host ""
Write-Host "6. Wait 10 seconds (waitDurationInOpenState)" -ForegroundColor White
Write-Host "   Circuit will transition to HALF_OPEN" -ForegroundColor White
Write-Host ""
Write-Host "7. Make requests again - circuit should CLOSE" -ForegroundColor White
Write-Host ""

# Step 5: Check actuator endpoints
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  USEFUL ACTUATOR ENDPOINTS            " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Health:          $BaseUrl`:$Port/actuator/health" -ForegroundColor White
Write-Host "Metrics:         $BaseUrl`:$Port/actuator/metrics" -ForegroundColor White
Write-Host "Circuit Breakers: $BaseUrl`:$Port/actuator/circuitbreakers" -ForegroundColor White
Write-Host "CB Events:       $BaseUrl`:$Port/actuator/circuitbreakerevents" -ForegroundColor White
Write-Host "Retries:         $BaseUrl`:$Port/actuator/retries" -ForegroundColor White
Write-Host "Retry Events:    $BaseUrl`:$Port/actuator/retryevents" -ForegroundColor White
Write-Host ""
