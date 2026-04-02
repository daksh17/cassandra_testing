FROM eclipse-temurin:11-jdk AS build
WORKDIR /app
COPY mvnw .
COPY .mvn .mvn
COPY pom.xml .
COPY src src
RUN ./mvnw install -DskipTests

FROM eclipse-temurin:11-jre
ENV CASSANDRA_CONTACT_HOST=127.0.0.1
ENV CASSANDRA_CONTACT_PORT=9042
WORKDIR /app
COPY --from=build /app/target/reservation-service-1.0.0.jar /app
COPY wait-for-it.sh wait-for-it.sh
CMD ./wait-for-it.sh -s -t 30 ${CASSANDRA_CONTACT_HOST}:${CASSANDRA_CONTACT_PORT} -- java -Dcassandra.contactPoint=${CASSANDRA_CONTACT_HOST} -jar /app/reservation-service-1.0.0.jar
