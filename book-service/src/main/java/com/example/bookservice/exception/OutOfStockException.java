package com.example.bookservice.exception;

public class OutOfStockException extends RuntimeException {

    public OutOfStockException(String message) {
        super(message);
    }

    public OutOfStockException(Long bookId) {
        super("Book with ID " + bookId + " is out of stock");
    }
}
