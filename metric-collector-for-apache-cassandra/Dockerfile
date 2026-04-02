FROM maven:3.6.3-jdk-8-slim as builder

WORKDIR /build

COPY . ./
RUN mvn -ff package -DskipTests

# Stage puts agent in /agent so the mcac_data volume mount at /mcac doesn't hide it at run time
RUN mkdir -p /agent/lib
RUN cp /build/target/datastax-mcac-agent-*.jar /agent/lib
RUN cp -r /build/target/collectd /agent/lib

# Populate /mcac (mounted volume) from /agent and exit; avoids running Maven with no goal
WORKDIR /mcac
CMD ["sh", "-c", "mkdir -p /mcac/lib && cp -r /agent/lib/. /mcac/lib/ && exit 0"]
