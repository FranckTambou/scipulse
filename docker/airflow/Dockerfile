# Image Airflow SciPulse
#  - Airflow 2.10.5 / Python 3.11 (même version Python que les workers Spark :
#    obligatoire, sinon PySpark refuse d'exécuter les UDF Python)
#  - Java 17 : le driver Spark tourne dans le scheduler (mode client)
#  - Jars S3A (MinIO) + elasticsearch-hadoop ajoutés à PySpark
FROM apache/airflow:2.10.5-python3.11

USER root
RUN apt-get update \
 && apt-get install -y --no-install-recommends default-jre-headless curl procps \
 && rm -rf /var/lib/apt/lists/*
ENV JAVA_HOME=/usr/lib/jvm/default-java

ARG HADOOP_AWS_VERSION=3.3.4
ARG AWS_SDK_VERSION=1.12.262
ARG ES_HADOOP_VERSION=8.19.0
RUN mkdir -p /opt/spark-jars \
 && curl -fsSL -o /opt/spark-jars/hadoop-aws.jar https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/${HADOOP_AWS_VERSION}/hadoop-aws-${HADOOP_AWS_VERSION}.jar \
 && curl -fsSL -o /opt/spark-jars/aws-java-sdk-bundle.jar https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/${AWS_SDK_VERSION}/aws-java-sdk-bundle-${AWS_SDK_VERSION}.jar \
 && curl -fsSL -o /opt/spark-jars/elasticsearch-spark.jar https://repo1.maven.org/maven2/org/elasticsearch/elasticsearch-spark-30_2.12/${ES_HADOOP_VERSION}/elasticsearch-spark-30_2.12-${ES_HADOOP_VERSION}.jar \
 && chmod -R a+r /opt/spark-jars

USER airflow
# requirements.lock = résolution figée (uv pip compile) des dépendances
# contre le fichier de contraintes officiel d'Airflow 2.10.5 / py3.11
COPY requirements.lock /tmp/requirements.lock
RUN pip install --no-cache-dir -r /tmp/requirements.lock \
 && cp /opt/spark-jars/*.jar "$(python -c 'import pyspark,os;print(os.path.dirname(pyspark.__file__))')/jars/"

ENV SPARK_HOME=/home/airflow/.local/lib/python3.11/site-packages/pyspark \
    PYSPARK_PYTHON=python3 \
    PYSPARK_DRIVER_PYTHON=python3
