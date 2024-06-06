#!/usr/bin/env bash
rm ${SPARK_HOME}/logs/*
cp -f ./spark-defaults.conf ${SPARK_HOME}/spark-defaults.conf
cp -f ./pom.xml ${SPARK_HOME}/pom.xml
cp -f ./spark-executor.Dockerfile ${SPARK_HOME}/Dockerfile.executor
SPARK_VERSION="${SPARK_VERSION:=unknown-version}"
pushd ${SPARK_HOME}
docker buildx build -t prodevonline/spark-executor:${SPARK_VERSION} --platform linux/amd64,linux/arm64/v8 -f Dockerfile.executor --push .
popd
