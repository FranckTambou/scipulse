# Image Spark SciPulse (master + worker)
# Pourquoi pas bitnami/spark ? Le catalogue Bitnami gratuit a été retiré en 2025.
# Pourquoi pas apache/spark ? Son Python (3.10) diffère de celui d'Airflow (3.11) :
# PySpark exige la même version mineure côté driver et executors.
# -> Spark installé via le wheel PySpark officiel (même version qu'Airflow).
FROM python:3.11-slim-bookworm

RUN apt-get update \
 && apt-get install -y --no-install-recommends default-jre-headless curl procps tini \
 && rm -rf /var/lib/apt/lists/*
ENV JAVA_HOME=/usr/lib/jvm/default-java

RUN pip install --no-cache-dir pyspark==3.5.4 numpy==1.26.4 pandas==2.1.4 pyarrow==16.1.0

ENV SPARK_HOME=/usr/local/lib/python3.11/site-packages/pyspark
ENV PATH="${SPARK_HOME}/bin:${SPARK_HOME}/sbin:${PATH}" \
    PYSPARK_PYTHON=python3

ARG HADOOP_AWS_VERSION=3.3.4
ARG AWS_SDK_VERSION=1.12.262
ARG ES_HADOOP_VERSION=8.19.0
RUN curl -fsSL -o ${SPARK_HOME}/jars/hadoop-aws.jar https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/${HADOOP_AWS_VERSION}/hadoop-aws-${HADOOP_AWS_VERSION}.jar \
 && curl -fsSL -o ${SPARK_HOME}/jars/aws-java-sdk-bundle.jar https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/${AWS_SDK_VERSION}/aws-java-sdk-bundle-${AWS_SDK_VERSION}.jar \
 && curl -fsSL -o ${SPARK_HOME}/jars/elasticsearch-spark.jar https://repo1.maven.org/maven2/org/elasticsearch/elasticsearch-spark-30_2.12/${ES_HADOOP_VERSION}/elasticsearch-spark-30_2.12-${ES_HADOOP_VERSION}.jar

ENV SPARK_NO_DAEMONIZE=true
WORKDIR /opt/spark-work
ENTRYPOINT ["/usr/bin/tini", "--"]
