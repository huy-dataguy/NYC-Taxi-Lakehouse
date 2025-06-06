#!/bin/bash

spark-sql \
  --packages io.delta:delta-core_2.13:2.4.0,org.apache.hadoop:hadoop-aws:3.3.4,software.amazon.awssdk:bundle:2.26.19 \
  --conf "spark.sql.extensions=io.delta.sql.DeltaSparkSessionExtension" \
  --conf "spark.sql.catalog.spark_catalog=org.apache.spark.sql.delta.catalog.DeltaCatalog" \
  --conf "spark.delta.logStore.class=org.apache.spark.sql.delta.storage.S3SingleDriverLogStore" \
  --conf "spark.hadoop.fs.s3a.endpoint=http://minio1:9000" \
  --conf "spark.hadoop.fs.s3a.access.key=minio" \
  --conf "spark.hadoop.fs.s3a.secret.key=mypassword" \
  --conf "spark.hadoop.fs.s3a.impl=org.apache.hadoop.fs.s3a.S3AFileSystem" \
  --conf "spark.hadoop.fs.s3a.path.style.access=true" \
  --conf "spark.hadoop.fs.s3a.connection.ssl.enabled=false" \
  --conf "spark.hadoop.fs.s3a.aws.credentials.provider=org.apache.hadoop.fs.s3a.SimpleAWSCredentialsProvider"
