"""
Delta Lake Demo - Spark Minio Delta Lakehouse on Kubernetes

This script demonstrates basic Delta Lake operations using Apache Spark
connected to MinIO (S3A) object storage and Hive Metastore.

Run via spark-submit:
  spark-submit \\
    --master spark://spark-master.lakehouse.svc.cluster.local:7077 \\
    --conf spark.sql.extensions=io.delta.sql.DeltaSparkSessionExtension \\
    --conf spark.sql.catalog.spark_catalog=org.apache.spark.sql.delta.catalog.DeltaCatalog \\
    delta_lake_demo.py
"""

from pyspark.sql import SparkSession
from pyspark.sql.types import StructType, StructField, StringType, IntegerType, DoubleType

# ---------------------------------------------------------------------------
# 1. Create Spark session (config already embedded in spark-defaults.conf)
# ---------------------------------------------------------------------------
spark = (
    SparkSession.builder
    .appName("DeltaLakeDemo")
    .enableHiveSupport()
    .getOrCreate()
)
spark.sparkContext.setLogLevel("WARN")

print("Spark version:", spark.version)
print("Spark master:", spark.conf.get("spark.master"))

# ---------------------------------------------------------------------------
# 2. Create sample data
# ---------------------------------------------------------------------------
schema = StructType([
    StructField("id", IntegerType(), False),
    StructField("name", StringType(), True),
    StructField("department", StringType(), True),
    StructField("salary", DoubleType(), True),
])

data = [
    (1, "Alice", "Engineering", 95000.0),
    (2, "Bob",   "Marketing",   72000.0),
    (3, "Carol", "Engineering", 105000.0),
    (4, "Dave",  "HR",          65000.0),
    (5, "Eve",   "Engineering", 98000.0),
]

df = spark.createDataFrame(data, schema)
df.show()

# ---------------------------------------------------------------------------
# 3. Write as Delta table to MinIO warehouse bucket
# ---------------------------------------------------------------------------
DELTA_PATH = "s3a://warehouse/employees"

print(f"\nWriting Delta table to: {DELTA_PATH}")
(
    df.write
    .format("delta")
    .mode("overwrite")
    .save(DELTA_PATH)
)
print("Write completed.")

# ---------------------------------------------------------------------------
# 4. Read the Delta table back
# ---------------------------------------------------------------------------
print("\nReading Delta table:")
df_read = spark.read.format("delta").load(DELTA_PATH)
df_read.show()

# ---------------------------------------------------------------------------
# 5. Upsert (MERGE) - update salary for Engineering department
# ---------------------------------------------------------------------------
from delta.tables import DeltaTable

updates = spark.createDataFrame([
    (1, "Alice", "Engineering", 100000.0),
    (3, "Carol", "Engineering", 110000.0),
], schema)

delta_table = DeltaTable.forPath(spark, DELTA_PATH)

(
    delta_table.alias("target")
    .merge(updates.alias("source"), "target.id = source.id")
    .whenMatchedUpdateAll()
    .whenNotMatchedInsertAll()
    .execute()
)

print("\nAfter MERGE (Engineering salary update):")
spark.read.format("delta").load(DELTA_PATH).show()

# ---------------------------------------------------------------------------
# 6. Time travel - read version 0 (original data)
# ---------------------------------------------------------------------------
print("\nTime travel to version 0:")
spark.read.format("delta").option("versionAsOf", 0).load(DELTA_PATH).show()

# ---------------------------------------------------------------------------
# 7. Create Hive external table pointing to Delta
# ---------------------------------------------------------------------------
spark.sql("CREATE DATABASE IF NOT EXISTS demo")
spark.sql(f"""
    CREATE TABLE IF NOT EXISTS demo.employees
    USING delta
    LOCATION '{DELTA_PATH}'
""")

print("\nHive table demo.employees:")
spark.sql("SELECT * FROM demo.employees").show()

spark.stop()
print("\nDemo completed successfully.")
