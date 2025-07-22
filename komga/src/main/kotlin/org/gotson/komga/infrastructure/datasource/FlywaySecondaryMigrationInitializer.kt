package org.gotson.komga.infrastructure.datasource

import org.flywaydb.core.Flyway
import org.springframework.beans.factory.InitializingBean
import org.springframework.beans.factory.annotation.Qualifier
import org.springframework.stereotype.Component
import javax.sql.DataSource

@Component
class FlywaySecondaryMigrationInitializer(
  @Qualifier("tasksMigrationDataSource")
  private val tasksMigrationDataSource: DataSource,
) : InitializingBean {
  // by default Spring Boot will perform migration only on the @Primary datasource
  // Use a separate datasource for migrations to avoid connection pool conflicts
  override fun afterPropertiesSet() {
    Flyway
      .configure()
      .locations("classpath:tasks/migration/postgresql")
      .dataSource(tasksMigrationDataSource)
      .load()
      .apply {
        migrate()
      }
  }
}
