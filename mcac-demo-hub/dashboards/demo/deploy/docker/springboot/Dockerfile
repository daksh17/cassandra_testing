#stage 1 build the springboot application
FROM amazoncorretto:17-alpine-jdk as builder
LABEL maintainer="Dash"
RUN mkdir -p /app/springboot
WORKDIR /app/springboot
COPY ./ /app/springboot
RUN chmod +x mvnw && ./mvnw -B package -DskipTests 
#/ && mv target/demo-hub-springboot.jar app.jar
#EXPOSE 8090
#ENTRYPOINT ["java", "-jar", "/app/springboot/app.jar"]


#stage 2 run the springboot application
FROM amazoncorretto:17-alpine-jdk
LABEL maintainer="Dash"
WORKDIR /app/springboot
COPY --from=builder /app/springboot/target/demo-hub-springboot.jar app.jar
EXPOSE 8090
ENTRYPOINT ["java", "-jar", "/app/springboot/app.jar"]
