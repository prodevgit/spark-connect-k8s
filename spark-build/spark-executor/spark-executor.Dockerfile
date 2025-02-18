#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
ARG java_image_tag=17-jre
FROM maven:3.8.4-openjdk-11 as builder
 
# Copy your project's pom.xml and source files (if needed)
COPY pom.xml /build/pom.xml
# If you need to copy source code:
# COPY src /build/src
 
WORKDIR /build
 
# Ensuring that dependencies are downloaded
RUN mvn -B dependency:resolve dependency:resolve-plugins
 
# Copying dependencies to the target/dependency directory
RUN mvn dependency:copy-dependencies -DoutputDirectory=target/dependency


FROM eclipse-temurin:${java_image_tag}

ARG DEBIAN_FRONTEND=noninteractive

# Wh1isper: Add UID and GID defined here
ARG EXECUTOR_UID=9999
ARG EXECUTOR_GID=9999
RUN addgroup --system --gid ${EXECUTOR_GID} executor && \
    adduser --system --gid ${EXECUTOR_GID} --home /home/executor --uid ${EXECUTOR_UID} --disabled-password executor

ARG spark_uid=$EXECUTOR_UID


# Before building the docker image, first build and make a Spark distribution following
# the instructions in http://spark.apache.org/docs/latest/building-spark.html.
# If this docker file is being used in the context of building your images from a Spark
# distribution, the docker build command should be invoked from the top level directory
# of the Spark distribution. E.g.:
# docker build -t spark:latest -f kubernetes/dockerfiles/spark/Dockerfile .

RUN set -ex && \
    apt-get update && \
    ln -s /lib /lib64 && \
    apt install -y bash tini libc6 libpam-modules krb5-user libnss3 procps net-tools python3 python3-pip&& \
    mkdir -p /opt/spark && \
    mkdir -p /opt/spark/examples && \
    mkdir -p /opt/spark/work-dir && \
    touch /opt/spark/RELEASE && \
    rm /bin/sh && \
    ln -sv /bin/bash /bin/sh && \
    echo "auth required pam_wheel.so use_uid" >> /etc/pam.d/su && \
    chgrp root /etc/passwd && chmod ug+rw /etc/passwd && \
    rm -rf /var/cache/apt/* && rm -rf /var/lib/apt/lists/*


COPY jars /opt/spark/jars
COPY bin /opt/spark/bin
COPY sbin /opt/spark/sbin
COPY kubernetes/dockerfiles/spark/entrypoint.sh /opt/
COPY kubernetes/dockerfiles/spark/decom.sh /opt/
COPY examples /opt/spark/examples
COPY kubernetes/tests /opt/spark/tests
COPY data /opt/spark/data

ENV SPARK_HOME /opt/spark

WORKDIR /opt/spark/work-dir

COPY --from=builder /build/target/dependency /opt/spark/jars

COPY spark-defaults.conf /opt/spark/conf/spark-defaults.conf
# Wh1isper: user executor should have work-dir's permission.
RUN chown executor:executor /opt/spark/work-dir
RUN chmod a+x /opt/decom.sh
# Wh1isper: Config default log dir
RUN mkdir -p /opt/spark/logs && chmod 777 /opt/spark/logs
# Wh1isper: Config python and pyspark
RUN ln -sv /usr/bin/python3 /usr/local/bin/python3
COPY python /opt/spark/python
ENTRYPOINT [ "/opt/entrypoint.sh" ]

# Specify the User that the actual main process will run as
USER ${spark_uid}
# Wh1isper:include user's local bin for pip install
ENV PATH=/home/executor/.local/bin:$PATH
