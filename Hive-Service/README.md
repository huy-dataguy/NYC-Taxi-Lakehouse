# Hive Metastore Service

This directory contains the configuration and setup for the Hive Metastore service, which provides schema management and metadata storage for the NYC Taxi Lakehouse project.

## Overview

The Hive Metastore is a central repository that stores metadata about tables, schemas, partitions, and other database objects. It enables SQL-like access to data stored in HDFS and integrates with Spark SQL for querying Delta Lake tables.

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Spark SQL     │    │  Hive Metastore │    │     MySQL       │
│   (Client)      │───▶│    Service      │───▶│   (Backend)     │
│                 │    │   Port: 9083    │    │   Port: 3306    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
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

# Test connection from Spark (example)
docker exec -it spark-client spark-sql \
  --conf spark.sql.hive.metastore.uris=thrift://hive-service:9083
```

### 3. Connect from Spark Applications
When configuring Spark to use this Hive Metastore:

```python
spark = SparkSession.builder \
    .appName("Your App") \
    .enableHiveSupport() \
    .config("hive.metastore.uris", "thrift://hive-service:9083") \
    .getOrCreate()
```

## Integration with Project

This Hive Metastore service is used by:

1. **Spark Applications**: For registering and querying Delta tables
2. **Table Registration Scripts**: Like `register_delta_tables.py` in the Spark-on-YARN module
3. **BI Tools**: For schema discovery and SQL querying

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
- Check port conflicts: `netstat -an | grep 3307`
- Verify firewall settings for ports 3307 and 9083

## Network Configuration

The service uses the `data_network` bridge network, which should be shared with other components:
- Spark cluster (for metadata access)
- Any BI tools or query engines
- Data processing applications

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