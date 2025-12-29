#!/bin/bash

#############################################################
# Load Test Script for Book Service - Bash Version
# Tests concurrent borrowing to verify pessimistic locking
#############################################################

# Configuration
BASE_URL=${BASE_URL:-"http://localhost"}
BOOK_ID=${BOOK_ID:-1}
CONCURRENT_REQUESTS=${CONCURRENT_REQUESTS:-15}
INITIAL_STOCK=${INITIAL_STOCK:-10}

# Service ports (3 instances)
PORTS=(8081 8083 8084)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Load Test - Pessimistic Locking TP27 ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to get a random port from the list
get_random_port() {
    echo ${PORTS[$RANDOM % ${#PORTS[@]}]}
}

# Step 1: Create a test book with initial stock
echo -e "${YELLOW}Step 1: Creating test book with stock = ${INITIAL_STOCK}${NC}"
PORT=${PORTS[0]}
CREATE_RESPONSE=$(curl -s -X POST "${BASE_URL}:${PORT}/api/books" \
    -H "Content-Type: application/json" \
    -d "{\"title\":\"Load Test Book\",\"author\":\"Test Author\",\"stock\":${INITIAL_STOCK},\"price\":29.99}")

echo "Response: $CREATE_RESPONSE"
BOOK_ID=$(echo $CREATE_RESPONSE | grep -o '"id":[0-9]*' | grep -o '[0-9]*')

if [ -z "$BOOK_ID" ]; then
    echo -e "${RED}Failed to create book. Exiting.${NC}"
    exit 1
fi

echo -e "${GREEN}Created book with ID: ${BOOK_ID}${NC}"
echo ""

# Step 2: Verify initial stock
echo -e "${YELLOW}Step 2: Verifying initial stock${NC}"
BOOK_INFO=$(curl -s "${BASE_URL}:${PORT}/api/books/${BOOK_ID}")
echo "Book info: $BOOK_INFO"
echo ""

# Step 3: Launch concurrent borrow requests
echo -e "${YELLOW}Step 3: Launching ${CONCURRENT_REQUESTS} concurrent borrow requests${NC}"
echo -e "${YELLOW}Distributing requests across ports: ${PORTS[*]}${NC}"
echo ""

# Arrays to store PIDs and results
declare -a PIDS
declare -a RESULTS

# Temporary directory for results
TEMP_DIR=$(mktemp -d)

# Launch concurrent requests
for i in $(seq 1 $CONCURRENT_REQUESTS); do
    PORT=$(get_random_port)
    (
        RESULT=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}:${PORT}/api/books/${BOOK_ID}/borrow")
        HTTP_CODE=$(echo "$RESULT" | tail -n1)
        BODY=$(echo "$RESULT" | sed '$d')
        echo "${HTTP_CODE}|${PORT}|${BODY}" > "${TEMP_DIR}/result_${i}.txt"
    ) &
    PIDS+=($!)
    echo -e "  Request ${i} sent to port ${PORT} (PID: ${PIDS[-1]})"
done

# Wait for all requests to complete
echo ""
echo -e "${YELLOW}Waiting for all requests to complete...${NC}"
for PID in "${PIDS[@]}"; do
    wait $PID
done

echo -e "${GREEN}All requests completed!${NC}"
echo ""

# Step 4: Analyze results
echo -e "${YELLOW}Step 4: Analyzing results${NC}"
echo ""

SUCCESS_COUNT=0
FAILURE_COUNT=0

for i in $(seq 1 $CONCURRENT_REQUESTS); do
    if [ -f "${TEMP_DIR}/result_${i}.txt" ]; then
        RESULT=$(cat "${TEMP_DIR}/result_${i}.txt")
        HTTP_CODE=$(echo $RESULT | cut -d'|' -f1)
        PORT=$(echo $RESULT | cut -d'|' -f2)
        
        if [ "$HTTP_CODE" = "200" ]; then
            echo -e "  Request ${i} (Port ${PORT}): ${GREEN}SUCCESS${NC} (HTTP ${HTTP_CODE})"
            ((SUCCESS_COUNT++))
        else
            echo -e "  Request ${i} (Port ${PORT}): ${RED}FAILED${NC} (HTTP ${HTTP_CODE})"
            ((FAILURE_COUNT++))
        fi
    fi
done

# Cleanup temp directory
rm -rf "$TEMP_DIR"

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}              RESULTS                   ${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "  Initial Stock:     ${INITIAL_STOCK}"
echo -e "  Total Requests:    ${CONCURRENT_REQUESTS}"
echo -e "  ${GREEN}Successful:        ${SUCCESS_COUNT}${NC}"
echo -e "  ${RED}Failed (OOS):      ${FAILURE_COUNT}${NC}"
echo ""

# Step 5: Verify final stock
echo -e "${YELLOW}Step 5: Verifying final stock${NC}"
FINAL_BOOK=$(curl -s "${BASE_URL}:${PORTS[0]}/api/books/${BOOK_ID}")
FINAL_STOCK=$(echo $FINAL_BOOK | grep -o '"stock":[0-9]*' | grep -o '[0-9]*')

echo "Final book state: $FINAL_BOOK"
echo ""

# Validation
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}            VALIDATION                  ${NC}"
echo -e "${BLUE}========================================${NC}"

EXPECTED_SUCCESS=$INITIAL_STOCK
if [ "$FINAL_STOCK" -ge 0 ]; then
    echo -e "${GREEN}✓ Stock is non-negative: ${FINAL_STOCK}${NC}"
else
    echo -e "${RED}✗ CRITICAL: Stock went negative: ${FINAL_STOCK}${NC}"
fi

if [ "$SUCCESS_COUNT" -eq "$EXPECTED_SUCCESS" ]; then
    echo -e "${GREEN}✓ Successful borrows (${SUCCESS_COUNT}) equals initial stock (${EXPECTED_SUCCESS})${NC}"
else
    echo -e "${YELLOW}! Successful borrows (${SUCCESS_COUNT}) differs from initial stock (${EXPECTED_SUCCESS})${NC}"
fi

EXPECTED_FAILURES=$((CONCURRENT_REQUESTS - INITIAL_STOCK))
if [ "$FAILURE_COUNT" -eq "$EXPECTED_FAILURES" ]; then
    echo -e "${GREEN}✓ Failed requests (${FAILURE_COUNT}) as expected (${EXPECTED_FAILURES})${NC}"
else
    echo -e "${YELLOW}! Failed requests (${FAILURE_COUNT}) differs from expected (${EXPECTED_FAILURES})${NC}"
fi

echo ""
echo -e "${GREEN}Load test completed!${NC}"
