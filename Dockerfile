# Build
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN mvn -B -DskipTests package

# Runtime
FROM amazoncorretto:17-alpine
WORKDIR /app
COPY --from=build /app/target/paymybuddy.jar paymybuddy.jar

ENV SPRING_DATASOURCE_URL=jdbc:mysql://paymybuddydb:3306/db_paymybuddy
ENV SPRING_DATASOURCE_USERNAME=root
ENV SPRING_DATASOURCE_PASSWORD=password

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "paymybuddy.jar"]
