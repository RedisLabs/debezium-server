FROM registry.access.redhat.com/ubi8/openjdk-21@sha256:bba7f720dc3a368e657fa12c99740910e86fd7ef69c62ce7aeda569b9589ffaa AS builder

LABEL maintainer="Redis RDI"

ARG SERVER_DIST_TARBALL
ARG OTEL_ENABLED=true

ENV SERVER_HOME=/debezium \
    OPENTELEMETRY_AGENT_VERSION=2.26.1 \
    OPENTELEMETRY_MD5=ea9cb308a0bc152da43089bd00f216e4

USER root
RUN microdnf -y install gzip && \
    microdnf clean all && \
    mkdir "$SERVER_HOME" && \
    chmod 755 "$SERVER_HOME"

RUN chown -R jboss "$SERVER_HOME" && \
    chgrp -R jboss "$SERVER_HOME"
USER jboss

RUN mkdir "$SERVER_HOME/config" && \
    mkdir "$SERVER_HOME/data"

COPY --chown=jboss:jboss ${SERVER_DIST_TARBALL} /tmp/debezium.tar.gz
RUN tar xzf /tmp/debezium.tar.gz -C "$SERVER_HOME" --strip-components 1 && \
    rm -f /tmp/debezium.tar.gz

RUN if [ "$OTEL_ENABLED" = "true" ]; then \
       mkdir "$SERVER_HOME/otel" \
       && curl -fSL -o "$SERVER_HOME/otel/opentelemetry-javaagent.jar" \
            "https://repo1.maven.org/maven2/io/opentelemetry/javaagent/opentelemetry-javaagent/$OPENTELEMETRY_AGENT_VERSION/opentelemetry-javaagent-$OPENTELEMETRY_AGENT_VERSION.jar" \
       && echo "$OPENTELEMETRY_MD5 $SERVER_HOME/otel/opentelemetry-javaagent.jar" | md5sum -c - \
       && sed -i "/^exec/i JAVA_OPTS=\"\$JAVA_OPTS -javaagent:$SERVER_HOME/otel/opentelemetry-javaagent.jar\"" "$SERVER_HOME/run.sh"; \
    fi

RUN chmod -R g+w,o+w "$SERVER_HOME"

FROM registry.access.redhat.com/ubi8/openjdk-21@sha256:bba7f720dc3a368e657fa12c99740910e86fd7ef69c62ce7aeda569b9589ffaa

LABEL maintainer="Redis RDI"

ENV SERVER_HOME=/debezium \
    OTEL_SDK_DISABLED=true

USER root
RUN microdnf -y update && \
    microdnf clean all

USER jboss

COPY --from=builder "$SERVER_HOME" "$SERVER_HOME"

WORKDIR "$SERVER_HOME"

EXPOSE 8080
VOLUME ["/debezium/config","/debezium/data"]

CMD ["/debezium/run.sh"]
