## Overview

**NYC Taxi Lakehouse** is a Big Data Streaming Project designed to ingest, process, analyze real-time taxi trip data from New York City (NYC). Project fake streaming by push Parquet file **High Volume For-Hire Vehicle (FHVHV) Trips** data into Kafka topics for real-time analyze customer behavior, peak hours, high demand zones, driver performance, and shared a ride. It use modern big data technologies to build an end-to-end data pipeline from ingestion to visualization.

### Objectives

1. **Analyze Peak Hours and High Demand Zones**:
    - Identify peak and off-peak hours by analyze trip frequency across hours and days.
    - Determine high demand zones by check pickup (PULocationID) and dropoff (DOLocationID) locations.
    - Consider average trip and value (total fare) per region.
2. **Evaluate Driver Performance**:
    - Compare driver earnings across companies (Uber, Lyft,..) using the `hvfhs_license_num`.
    - Analyze relationship between trip speed and earnings (fare, tips).
    - Evaluate driver productivity by calculate average trips per working hour.
3. **Analyze Shared Ride Behavior**:
    - Calculate ratio of shared rides (`shared_request_flag`) per region.
    - Compare trip duration and cost (`total_amount`) between shared and non-shared rides.
    - Determine peak hours for shared ride requests.

### Data
- **Primary Data**: `fhvhv_tripdata_2019-04.parquet` New York City Taxi and Limousine Commission with detail info like timestamps, locations, fares, and tips.
- **Lookup Data**: `taxi_zone_lookup.csv`, used to map location IDs (PULocationID, DOLocationID) to geographical names for regional analysis.

### Architecture
![lakehouse](https://github.com/user-attachments/assets/f1b84e70-00ff-47f1-a56c-104f046a3097)


The system follow a modern data lakehouse architecture is Medallion Architecture. This architecture structure data in multi layer approach (Bronze, Silver, Gold) for data processing and storage. Pipeline is organized as follows:

- **Parquet Files**: Data source ingested for streaming.
- **Apache Airflow**: Workflow, automating data ingestion into Kafka.
- **Apache Kafka**: Stream data from producers to consumers in real-time.
- **Apache Spark**: Process streaming data using Spark Structured Streaming and writes to Delta Lake.
- **Delta Lake**: Stores data in a layer structure (Bronze, Silver, Gold) with ACID transaction support.
- **MinIO**: Provides distributed object storage for the Delta Lake layers.
- **Hive Metastore**: Manages metadata for Delta Lake tables, enable Spark and Trino to access schemas.
- **Trino**: Execute distributed SQL queries on Delta Lake via Hive Metastore.
- **Apache Superset**: Visualize and analyze data through interactive dashboards.



## Setup

### 1. Create Docker Network

Create network for compose services to communicate:

```bash
docker network create --driver bridge data_network
```

### 2. Build and Run Spark Cluster on YARN

- Navigate to the `Spark-on-YARN/` directory.
- Build the Spark image and run containers:

```bash
./scripts/build_image
chmod +x scripts/resize-number-worker.sh
./scripts/run_container 6
```

### 3. Set Up Kafka and Airflow

- Navigate to the `Kafka-Airflow/` directory.
- Build and start the containers:

```bash
docker compose build
docker compose up -d
```

### 4. Set Up MinIO

- Navigate to the `MinIO-Lakehouse/` directory.
- Start MinIO:

```bash
docker compose up -d
```

### 5. Set Up Hive Metastore for Delta Lake

- Navigate to the `Hive-Service/` directory.
- Build and start the Hive service:

```bash
docker compose build
docker compose up -d
```

### 6. Set Up Trino

- Navigate to the `Trino-Query-Engine/` directory.
- Start Trino:

```bash
docker compose up -d
```

### 7. Set Up Superset

- Navigate to the `Superset-Visualization/` directory.
- Start Superset and configure it:

```bash
docker compose up -d
./setup_superset.sh
```

## Usage

### 1. Create Kafka Topic

```bash
docker exec -it broker bash
```

- Create a topic for streaming NYC taxi data:

```bash
kafka-topics --create --bootstrap-server localhost:9092 --replication-factor 1 --partitions 3 --topic nyc_taxi_stream
```

- Download the dataset and place it in the `Kafka-Airflow/data/` directory:

```
https://d37ci6vzurychx.cloudfront.net/trip-data/fhvhv_tripdata_2019-04.parquet
```
- You can also download another data set here.
```
https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page
```
### 2. Ingest Data Using Airflow
- Log in with username: `airflow`, password: `airflow`.
- Trigger the DAG to ingest data into Kafka.
- Use Confluent UI to monitor data streaming into Kafka.

### 3. Process Data with Spark

- Access the Spark master container and start HDFS and YARN.
- Create a `deltalake` bucket in MinIO for the three-layer storage (Bronze, Silver, Gold).
- Create a `data` bucket in MinIO and upload `taxi_zone_lookup.csv` for the Bronze layer.
- Stream data from Kafka to the Bronze layer:

```bash
spark-submit /home/hadoopquochuy/scripts/medal-layer/spark_stream_taxi_to_minio.py
```

- Ingest `taxi_zone_lookup.csv` into the Bronze layer:

```bash
spark-submit /home/hadoopquochuy/scripts/medal-layer/ingest_zone_map_csv.py
```

- Transform data from Bronze to Silver:

```bash
spark-submit /home/hadoopquochuy/scripts/medal-layer/bronze_to_silver.py
```

- Transform data from Silver to Gold:

```bash
spark-submit /home/hadoopquochuy/scripts/medal-layer/silver_to_gold.py
```

- Register Gold and Silver tables in Hive Metastore for Trino querying:

```bash
spark-submit /home/hadoopquochuy/scripts/medal-layer/register_delta_tables.py
```

### 4. Query Data with Trino

- Access the Trino coordinator container:

```bash
docker exec -it trino-coordinator trino
```

- Verify catalogs, schemas, and tables:

```sql
show catalogs;
use delta.default;
show schemas;
use gold;
show tables;
select * from fhvhv_trips limit 10;
```

### 5. Visualize Data with Superset

- Access Superset at http://localhost:8088.
- Log in with username: `admin`, password: `AdminPassword123!`.
- SQLAlchemy URI: trino://admin@trino-coordinator:8080
- Import dashboard ZIP files to visualize the data.
  
### 6. Dashboard Preview
- List of dashboards built to visualize data from Trino.
- These dashboards can be imported from `.zip` files in the `dashboards/` to the Superset.
![image](https://github.com/user-attachments/assets/50723c1c-0eae-4c9e-8172-4f40fac9b002)
![image](https://github.com/user-attachments/assets/afeb23a7-67a3-4e56-bf7d-4f7c7c697f49)
![image](https://github.com/user-attachments/assets/d137480d-ad2b-4adc-9fa6-62264d56aa1f)

## Contact
- Email: quochuy.working@gmail.com
- Feel free to contribute and improve this project!

