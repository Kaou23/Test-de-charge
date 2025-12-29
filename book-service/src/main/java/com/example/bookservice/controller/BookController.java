package com.example.bookservice.controller;

import com.example.bookservice.entity.Book;
import com.example.bookservice.service.BookService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/books")
@RequiredArgsConstructor
@Slf4j
public class BookController {

    private final BookService bookService;

    /**
     * Create a new book.
     * POST /api/books
     */
    @PostMapping
    public ResponseEntity<Book> createBook(@RequestBody Book book) {
        log.info("POST /api/books - Creating book: {}", book.getTitle());
        Book createdBook = bookService.createBook(book);
        return new ResponseEntity<>(createdBook, HttpStatus.CREATED);
    }

    /**
     * Get all books.
     * GET /api/books
     */
    @GetMapping
    public ResponseEntity<List<Book>> getAllBooks() {
        log.info("GET /api/books - Fetching all books");
        return ResponseEntity.ok(bookService.getAllBooks());
    }

    /**
     * Get a book by ID.
     * GET /api/books/{id}
     */
    @GetMapping("/{id}")
    public ResponseEntity<Book> getBookById(@PathVariable Long id) {
        log.info("GET /api/books/{} - Fetching book", id);
        return ResponseEntity.ok(bookService.getBookById(id));
    }

    /**
     * Borrow a book - decrements stock.
     * POST /api/books/{id}/borrow
     */
    @PostMapping("/{id}/borrow")
    public ResponseEntity<Book> borrowBook(@PathVariable Long id) {
        log.info("POST /api/books/{}/borrow - Borrowing book", id);
        Book book = bookService.borrow(id);
        return ResponseEntity.ok(book);
    }

    /**
     * Get book with dynamic price from pricing-service.
     * GET /api/books/{id}/price
     */
    @GetMapping("/{id}/price")
    public ResponseEntity<Book> getBookWithPrice(@PathVariable Long id) {
        log.info("GET /api/books/{}/price - Fetching book with dynamic price", id);
        return ResponseEntity.ok(bookService.getBookWithDynamicPrice(id));
    }

    /**
     * Get price directly from pricing-service.
     * GET /api/books/{id}/pricing
     */
    @GetMapping("/{id}/pricing")
    public ResponseEntity<Map<String, Object>> getPricing(@PathVariable Long id) {
        log.info("GET /api/books/{}/pricing - Fetching price from pricing-service", id);
        Double price = bookService.getPriceFromPricingService(id);
        return ResponseEntity.ok(Map.of(
                "bookId", id,
                "price", price
        ));
    }

    /**
     * Health check endpoint.
     * GET /api/books/health
     */
    @GetMapping("/health")
    public ResponseEntity<Map<String, String>> health() {
        return ResponseEntity.ok(Map.of("status", "UP"));
    }
}
