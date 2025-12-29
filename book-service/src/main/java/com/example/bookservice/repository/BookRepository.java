package com.example.bookservice.repository;

import com.example.bookservice.entity.Book;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface BookRepository extends JpaRepository<Book, Long> {

    /**
     * Find a book by ID with PESSIMISTIC_WRITE lock.
     * This prevents concurrent modifications and race conditions
     * when updating stock (SELECT ... FOR UPDATE in SQL).
     *
     * @param id the book ID
     * @return the book wrapped in Optional
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT b FROM Book b WHERE b.id = :id")
    Optional<Book> findByIdForUpdate(@Param("id") Long id);
}
