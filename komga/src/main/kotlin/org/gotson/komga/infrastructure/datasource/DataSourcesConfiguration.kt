package org.gotson.komga.infrastructure.datasource

import com.zaxxer.hikari.HikariConfig
import com.zaxxer.hikari.HikariDataSource
import org.gotson.komga.infrastructure.configuration.KomgaProperties
import org.springframework.boot.jdbc.DataSourceBuilder
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.context.annotation.Primary
import javax.sql.DataSource

@Configuration
class DataSourcesConfiguration(
  private val komgaProperties: KomgaProperties,
) {
  @Bean("mainDataSource")
  @Primary
  fun mainDataSource(): DataSource = buildDataSource("MainPool", komgaProperties.database)

  @Bean("tasksDataSource")
  fun tasksDataSource(): DataSource =
    buildDataSource("TasksPool", komgaProperties.tasksDb)
      .apply {
        // force pool size to 1 for tasks datasource
        this.maximumPoolSize = 1
      }

  @Bean("tasksMigrationDataSource")
  fun tasksMigrationDataSource(): DataSource =
    // Create a separate datasource for Flyway migrations to avoid connection pool conflicts
    createDataSource(komgaProperties.tasksDb)

  private fun buildDataSource(
    poolName: String,
    databaseProps: KomgaProperties.Database,
  ): HikariDataSource {
    val dataSource = createDataSource(databaseProps)

    val poolSize = calculatePoolSize(databaseProps)

    return HikariDataSource(
      HikariConfig().apply {
        this.dataSource = dataSource
        this.poolName = poolName
        this.maximumPoolSize = poolSize
      },
    )
  }

  private fun createDataSource(databaseProps: KomgaProperties.Database): DataSource {
    return DataSourceBuilder
      .create()
      .driverClassName(databaseProps.driverClassName ?: "org.postgresql.Driver")
      .url(databaseProps.url ?: throw IllegalArgumentException("Database URL must be specified"))
      .username(databaseProps.username)
      .password(databaseProps.password)
      .build()
  }

  private fun calculatePoolSize(databaseProps: KomgaProperties.Database): Int {
    return when {
      // Use explicit pool size if specified
      databaseProps.poolSize != null -> databaseProps.poolSize!!
      // Default calculation based on CPU cores
      else -> Runtime.getRuntime().availableProcessors().coerceAtMost(databaseProps.maxPoolSize)
    }
  }
}
