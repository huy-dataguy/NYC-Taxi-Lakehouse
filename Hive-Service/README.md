# Hive Metastore Service

This directory contains the configuration and setup for the Hive Metastore service, which provides schema management and metadata storage for the NYC Taxi Lakehouse project.

## Overview

The Hive Metastore is a central repository that stores metadata about tables, schemas, partitions, and other database objects. It enables SQL-like access to data stored in HDFS and integrates with Spark SQL for querying Delta Lake tables.

## Architecture

```
         Docker Network: data_network
    ┌────────────────────────────────────────────────────────────┐
    │                                                            │
    │  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐  │
    │  │   Spark Client  │    │  Hive Metastore │    │     MySQL       │  │
    │  │ (quochuy-client)│───▶│   (hive-service)│───▶│    (mysql)      │  │
    │  │                 │    │   Port: 9083    │    │   Port: 3306    │  │
    │  └─────────────────┘    └─────────────────┘    └─────────────────┘  │
    │           │                                                        │
    │           │              ┌─────────────────┐                       │
    │           └─────────────▶│ Trino Connector │                       │
    │                          │ (query engine)  │                       │
    │                          └─────────────────┘                       │
    └────────────────────────────────────────────────────────────────────┘
```

## Components

### 1. Hive Metastore Service
- **Image**: Custom built from Apache Hive 2.3.9
- **Port**: 9083
- **Purpose**: Provides metadata services for table definitions and schema information
- **Dependencies**: MySQL database for storing metadata

### 2. MySQL Database
- **Image**: mysql:8.4.5
- **Port**: 3307 (external), 3306 (internal)
- **Database**: `metastore`
- **Purpose**: Backend storage for Hive metadata

## Files Description

| File | Description |
|------|-------------|
| `compose.yaml` | Docker Compose configuration for Hive Metastore and MySQL |
| `Dockerfile` | Custom image build for Hive Metastore service |
| `hive-site.xml` | Hive configuration for database connection |
| `entrypoint.sh` | Container startup script that initializes schema and starts service |

## Configuration Details

### Database Connection
- **Type**: MySQL 8.4.5
- **Host**: mysql (container name)
- **Port**: 3306
- **Database**: metastore
- **User**: root
- **Password**: root

### Environment Variables
```bash
HIVE_METASTORE_DB_TYPE=mysql
HIVE_METASTORE_DB_HOST=mysql
HIVE_METASTORE_DB_PORT=3306
HIVE_METASTORE_DB_NAME=metastore
HIVE_METASTORE_DB_USER=root
HIVE_METASTORE_DB_PASSWORD=root
```

## Usage

### 1. Start the Services
```bash
# Navigate to the Hive-Service directory
cd Hive-Service

# Start both MySQL and Hive Metastore
docker-compose up -d

# Check service status
docker-compose ps
```

### 2. Verify Connection
```bash
# Check Hive Metastore logs
docker logs hive-service

# Check MySQL logs
docker logs mysql
```

### 3. Connect from Spark Applications
Spark applications connect to the Hive Metastore through the Docker network. The connection is configured in `spark-defaults.conf`:

```properties
# In spark-defaults.conf
spark.sql.catalogImplementation=hive
spark.hadoop.hive.metastore.uris=thrift://hive-service:9083
```

When configuring Spark programmatically:

```python
spark = SparkSession.builder \
    .appName("Your App") \
    .enableHiveSupport() \
    .config("spark.sql.catalogImplementation", "hive") \
    .config("spark.hadoop.hive.metastore.uris", "thrift://hive-service:9083") \
    .getOrCreate()
```

### 4. Test Connection from Spark Container
```bash
# Access the Spark client container
docker exec -it client bash

# Switch to hadoop user and test Spark SQL
su - hadoopquochuy
spark-sql

# In Spark SQL shell, test metastore connection:
# SHOW DATABASES;
# SHOW TABLES IN gold;
```

## Integration with Project

This Hive Metastore service is used by:

1. **Spark Applications**: Connected via `thrift://hive-service:9083` in the `data_network`
   - Spark configuration in `Spark-on-YARN/config/client/config/spark-defaults.conf` 
   - Table registration scripts like `register_delta_tables.py`
   - Data processing pipelines (bronze, silver, gold layers)

2. **Trino Query Engine**: All Trino workers connect via `delta.properties` catalog configuration
   - Coordinator and workers use `hive.metastore.uri=thrift://hive-service:9083`
   - Enables cross-engine querying of the same tables

3. **Data Pipeline Components**:
   - **MinIO/S3**: Storage layer for Delta Lake files (referenced in table locations)
   - **HDFS**: Alternative storage for data files
   - **Airflow**: Orchestrates table registration and maintenance tasks

### Network Communication
All components communicate through the `data_network` Docker bridge network:
- Container hostnames are used as connection addresses
- No external network configuration required
- Services discover each other by container name

## Project Workflow Integration

### Data Pipeline Flow
The Hive Metastore plays a central role in the NYC Taxi Lakehouse project's medallion architecture:

1. **Data Ingestion** (Kafka + Airflow)
   - Raw taxi data is streamed through Kafka topics
   - Airflow orchestrates the ingestion pipeline

2. **Bronze Layer** (Raw Data)
   - Spark Streaming consumers read from Kafka
   - Raw data is stored in MinIO/S3 or HDFS
   - Minimal schema enforcement

3. **Silver Layer** (Cleaned Data)
   - Spark batch jobs process bronze data
   - Data cleaning, validation, and transformation
   - Tables registered in Hive Metastore via `register_delta_tables.py`

4. **Gold Layer** (Business Logic)
   - Aggregated and business-ready datasets
   - Optimized for analytics and reporting
   - All tables accessible through Hive Metastore

### Table Registration Process
```python
# Example from register_delta_tables.py
tables = [
    ("silver", "fhvhv_main", "s3a://deltalake/silver/fhvhv_main"),
    ("gold", "fhvhv_trips", "s3a://deltalake/gold/fhvhv_trips"),
    ("gold", "fhvhv_zones", "s3a://deltalake/gold/fhvhv_zones"),
    # ... more tables
]

for db, tbl, path in tables:
    spark.sql(f"""
        CREATE TABLE IF NOT EXISTS {db}.{tbl}
        USING DELTA
        LOCATION '{path}'
    """)
```

### Cross-Engine Compatibility
Once tables are registered in Hive Metastore:
- **Spark SQL**: Direct SQL queries and DataFrame operations
- **Trino**: High-performance distributed queries
- **Superset**: BI dashboards and visualizations
- **External Tools**: Any Hive-compatible query engine

## Common Operations

### View Registered Tables
```sql
-- Show all databases
SHOW DATABASES;

-- Show tables in a specific database
SHOW TABLES IN silver;
SHOW TABLES IN gold;

-- Describe table structure
DESCRIBE EXTENDED gold.fhvhv_trips;
```

### Troubleshooting

#### Service Won't Start
1. Check if MySQL is running: `docker logs mysql`
2. Verify network connectivity: `docker network ls`
3. Check Hive logs: `docker logs hive-service`

#### Schema Initialization Issues
```bash
# Manually initialize schema
docker exec -it hive-service schematool -dbType mysql -initSchema --verbose

# Or upgrade schema if needed
docker exec -it hive-service schematool -dbType mysql -upgradeSchema
```

#### Connection Issues
- Ensure `data_network` exists: `docker network create data_network`
- Check all services are on the same network: `docker network inspect data_network`
- Verify firewall settings for ports 3307 and 9083
- Check container connectivity: `docker exec -it client ping hive-service`

## Network Configuration

The service uses the `data_network` bridge network, which is shared across all project components:

### Connected Services
- **Spark Cluster**: `client`, `master-huy`, `worker-huy1`, `worker-huy2` containers
- **Trino Query Engine**: `trino-coordinator`, `trino-worker-1`, `trino-worker-2`, `trino-worker-3`
- **MinIO Storage**: `minio1`, `minio2`, `minio3` containers
- **Kafka & Airflow**: `broker`, `zookeeper`, `airflow-webserver`, `airflow-scheduler`
- **Superset**: `superset` container for visualization

### Network Features
- **Service Discovery**: Containers communicate using hostnames (e.g., `hive-service:9083`)
- **External Network**: The `data_network` is marked as external and shared across compose files
- **Port Mapping**: Only necessary ports are exposed to host system
- **Internal Communication**: All inter-service communication happens within the Docker network

### Network Creation
```bash
# Create the shared network (if not exists)
docker network create data_network

# Verify network exists
docker network ls | grep data_network
```

## Data Persistence

- MySQL data is persisted in the `mysql-data` Docker volume
- Metadata survives container restarts and updates
- For production, consider external MySQL with backup strategies

## Security Considerations

⚠️ **Note**: This configuration uses default credentials for development purposes. For production:

1. Change default MySQL root password
2. Create dedicated Hive user with limited privileges
3. Enable SSL/TLS for database connections
4. Implement proper network security

## Maintenance

### Backup Metadata
```bash
# Backup MySQL database
docker exec mysql mysqldump -u root -proot metastore > metastore_backup.sql

# Restore from backup
docker exec -i mysql mysql -u root -proot metastore < metastore_backup.sql
```

### Update Hive Version
1. Modify Dockerfile to use newer Hive version
2. Rebuild image: `docker-compose build`
3. Update services: `docker-compose up -d`