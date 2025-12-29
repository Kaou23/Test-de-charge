package com.example.bookservice.service;

import com.example.bookservice.entity.Book;
import com.example.bookservice.exception.BookNotFoundException;
import com.example.bookservice.exception.OutOfStockException;
import com.example.bookservice.repository.BookRepository;
import io.github.resilience4j.circuitbreaker.annotation.CircuitBreaker;
import io.github.resilience4j.retry.annotation.Retry;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.client.RestTemplate;

import java.util.List;

@Service
@RequiredArgsConstructor
@Slf4j
public class BookService {

    private final BookRepository bookRepository;
    private final RestTemplate restTemplate;

    @Value("${pricing.service.url:http://pricing-service:8080}")
    private String pricingServiceUrl;

    /**
     * Create a new book.
     */
    public Book createBook(Book book) {
        log.info("Creating book: {}", book.getTitle());
        return bookRepository.save(book);
    }

    /**
     * Get all books.
     */
    public List<Book> getAllBooks() {
        return bookRepository.findAll();
    }

    /**
     * Get a book by ID.
     */
    public Book getBookById(Long id) {
        return bookRepository.findById(id)
                .orElseThrow(() -> new BookNotFoundException(id));
    }

    /**
     * Borrow a book - decrements stock using PESSIMISTIC_WRITE lock.
     * This method is transactional and uses the findByIdForUpdate method
     * to acquire a database-level lock preventing race conditions.
     *
     * @param id the book ID
     * @return the updated book
     * @throws BookNotFoundException if book doesn't exist
     * @throws OutOfStockException if stock is 0 or less
     */
    @Transactional
    public Book borrow(Long id) {
        log.info("Attempting to borrow book with ID: {}", id);
        
        // Use pessimistic lock to prevent concurrent modifications
        Book book = bookRepository.findByIdForUpdate(id)
                .orElseThrow(() -> new BookNotFoundException(id));
        
        // Check stock AFTER acquiring the lock
        if (book.getStock() <= 0) {
            log.warn("Book {} is out of stock", id);
            throw new OutOfStockException(id);
        }
        
        // Decrement stock
        book.setStock(book.getStock() - 1);
        Book updatedBook = bookRepository.save(book);
        
        log.info("Book {} borrowed successfully. Remaining stock: {}", id, updatedBook.getStock());
        return updatedBook;
    }

    /**
     * Get price from pricing-service with Circuit Breaker and Retry.
     * If pricing-service is down, fallback returns 0.0.
     *
     * @param bookId the book ID
     * @return the price from pricing-service
     */
    @CircuitBreaker(name = "pricingService", fallbackMethod = "getPriceFallback")
    @Retry(name = "pricingService", fallbackMethod = "getPriceFallback")
    public Double getPriceFromPricingService(Long bookId) {
        log.info("Calling pricing-service for book ID: {}", bookId);
        String url = pricingServiceUrl + "/api/prices/" + bookId;
        Double price = restTemplate.getForObject(url, Double.class);
        log.info("Received price {} for book ID: {}", price, bookId);
        return price;
    }

    /**
     * Fallback method when pricing-service is unavailable.
     * Returns 0.0 as specified in requirements.
     *
     * @param bookId the book ID
     * @param ex the exception that triggered the fallback
     * @return 0.0 as fallback price
     */
    public Double getPriceFallback(Long bookId, Exception ex) {
        log.warn("Pricing-service unavailable for book {}. Using fallback price 0.0. Error: {}", 
                bookId, ex.getMessage());
        return 0.0;
    }

    /**
     * Get book with dynamic price from pricing-service.
     */
    @Transactional(readOnly = true)
    public Book getBookWithDynamicPrice(Long id) {
        Book book = getBookById(id);
        Double dynamicPrice = getPriceFromPricingService(id);
        book.setPrice(dynamicPrice);
        return book;
    }
}
