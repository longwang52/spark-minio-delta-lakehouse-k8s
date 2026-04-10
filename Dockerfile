FROM apache/spark-py:latest

# Install any additional dependencies here
RUN pip install pyspark[sql] delta-spark
