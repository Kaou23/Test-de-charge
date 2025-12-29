# TP 27: Load Testing, Concurrency & Observability Lab

A complete Spring Boot microservices lab demonstrating:
- **Pessimistic Locking** (`@Lock(PESSIMISTIC_WRITE)`) for concurrency control
- **Resilience4j** (CircuitBreaker + Retry) for fault tolerance
- **Actuator** for observability and metrics

## Architecture

```
┌─────────────────┐     ┌─────────────────┐
│ pricing-service │◄────│  book-service   │
│   (port 8080)   │     │ (8081,8083,8084)│
└─────────────────┘     └────────┬────────┘
                                 │
                        ┌────────▼────────┐
                        │      MySQL      │
                        │   (port 3306)   │
                        └─────────────────┘
```

## Quick Start

### 1. Build and Start Services

```bash
# Start all services with Docker Compose
docker-compose up --build -d

# Check service health
docker-compose ps
```

### 2. Verify Services

```bash
# Check health endpoints
curl http://localhost:8081/actuator/health
curl http://localhost:8083/actuator/health
curl http://localhost:8084/actuator/health
curl http://localhost:8080/actuator/health
```

### 3. Create a Test Book

```bash
curl -X POST http://localhost:8081/api/books \
  -H "Content-Type: application/json" \
  -d '{"title":"Test Book","author":"Author","stock":10,"price":29.99}'
```

### 4. Test Borrow Endpoint

```bash
curl -X POST http://localhost:8081/api/books/1/borrow
```

## Load Testing (Concurrency)

### Bash

```bash
cd scripts
chmod +x loadtest.sh
./loadtest.sh
```

### PowerShell

```powershell
cd scripts
.\loadtest.ps1
```

The load test will:
1. Create a book with stock = 10
2. Send 15 concurrent borrow requests
3. Verify that exactly 10 succeed and 5 fail
4. Confirm stock never goes negative

## Circuit Breaker Testing

### 1. Check Circuit Breaker State

```bash
curl http://localhost:8081/actuator/circuitbreakers
```

### 2. Test Fallback (Stop pricing-service)

```bash
# Stop pricing-service
docker-compose stop pricing-service

# Make requests - should get fallback price (0.0)
curl http://localhost:8081/api/books/1/pricing

# Check circuit breaker state change
curl http://localhost:8081/actuator/circuitbreakers

# Restart pricing-service
docker-compose start pricing-service
```

## Actuator Endpoints

| Endpoint | Description |
|----------|-------------|
| `/actuator/health` | Health status |
| `/actuator/metrics` | All metrics |
| `/actuator/circuitbreakers` | Circuit breaker states |
| `/actuator/circuitbreakerevents` | CB events history |
| `/actuator/retries` | Retry states |
| `/actuator/retryevents` | Retry events history |

## Project Structure

```
├── book-service/
│   ├── src/main/java/com/example/bookservice/
│   │   ├── entity/Book.java
│   │   ├── repository/BookRepository.java  # @Lock(PESSIMISTIC_WRITE)
│   │   ├── service/BookService.java        # @CircuitBreaker, @Retry
│   │   ├── controller/BookController.java
│   │   └── exception/
│   ├── src/main/resources/application.yml
│   ├── Dockerfile
│   └── pom.xml
├── pricing-service/
│   ├── src/main/java/com/example/pricingservice/
│   │   └── controller/PricingController.java
│   ├── src/main/resources/application.yml
│   ├── Dockerfile
│   └── pom.xml
├── scripts/
│   ├── loadtest.sh
│   ├── loadtest.ps1
│   └── test-circuitbreaker.ps1
├── docker-compose.yml
└── README.md
```

## Key Technical Details

### Pessimistic Locking

```java
@Lock(LockModeType.PESSIMISTIC_WRITE)
@Query("SELECT b FROM Book b WHERE b.id = :id")
Optional<Book> findByIdForUpdate(@Param("id") Long id);
```

This generates `SELECT ... FOR UPDATE` SQL, preventing concurrent modifications.

### Resilience4j Configuration

- **Circuit Breaker**: Opens after 50% failure rate (min 5 calls)
- **Retry**: 3 attempts with exponential backoff
- **Fallback**: Returns `0.0` when pricing-service is down

## Stop Services

```bash
docker-compose down -v
```
