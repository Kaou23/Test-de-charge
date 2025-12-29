package com.example.pricingservice.controller;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.Random;

@RestController
@RequestMapping("/api/prices")
@Slf4j
public class PricingController {

    private final Random random = new Random();

    @Value("${pricing.simulate-delay:false}")
    private boolean simulateDelay;

    @Value("${pricing.delay-ms:0}")
    private int delayMs;

    @Value("${pricing.simulate-failure:false}")
    private boolean simulateFailure;

    @Value("${pricing.failure-rate:0}")
    private int failureRate;

    /**
     * Get price for a book.
     * Returns a mock price based on book ID.
     * Can simulate delays and failures for testing resilience.
     */
    @GetMapping("/{bookId}")
    public ResponseEntity<Double> getPrice(@PathVariable Long bookId) {
        log.info("Received price request for book ID: {}", bookId);

        // Simulate delay if configured
        if (simulateDelay && delayMs > 0) {
            try {
                Thread.sleep(delayMs);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        }

        // Simulate failure if configured
        if (simulateFailure && random.nextInt(100) < failureRate) {
            log.warn("Simulating failure for book ID: {}", bookId);
            return ResponseEntity.internalServerError().build();
        }

        // Generate mock price based on book ID
        double basePrice = 9.99 + (bookId % 10) * 5.0;
        double price = Math.round(basePrice * 100.0) / 100.0;

        log.info("Returning price {} for book ID: {}", price, bookId);
        return ResponseEntity.ok(price);
    }

    /**
     * Get all pricing info.
     */
    @GetMapping
    public ResponseEntity<Map<String, Object>> getPricingInfo() {
        return ResponseEntity.ok(Map.of(
                "service", "pricing-service",
                "status", "UP",
                "simulateDelay", simulateDelay,
                "delayMs", delayMs,
                "simulateFailure", simulateFailure,
                "failureRate", failureRate));
    }

    /**
     * Health check endpoint.
     */
    @GetMapping("/health")
    public ResponseEntity<Map<String, String>> health() {
        return ResponseEntity.ok(Map.of("status", "UP"));
    }
}
