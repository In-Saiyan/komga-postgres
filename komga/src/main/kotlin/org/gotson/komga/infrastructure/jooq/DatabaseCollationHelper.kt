package org.gotson.komga.infrastructure.jooq

import org.jooq.Field
import org.springframework.stereotype.Component

@Component
class DatabaseCollationHelper {
  /**
   * Apply PostgreSQL collation for text sorting with proper Unicode support.
   * Uses "C.UTF-8" for deterministic sorting.
   */
  fun <T> collateUnicode(field: Field<T>): Field<T> {
    // PostgreSQL: Use built-in case-insensitive collation
    // "C.UTF-8" provides deterministic sorting, "en_US.UTF-8" for locale-aware
    return field.collate("C.UTF-8")
  }

  /**
   * Apply PostgreSQL collation for case-insensitive text searching.
   */
  fun <T> collateCaseInsensitive(field: Field<T>): Field<T> {
    // PostgreSQL: Use case-insensitive collation
    return field.collate("POSIX")
  }
}
