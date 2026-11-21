# syntax=docker/dockerfile:1

# ---- Build stage ----
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /build

# Сначала только pom.xml: слой с зависимостями переиспользуется, пока зависимости не меняются
COPY pom.xml .
RUN mvn -B -q dependency:go-offline

COPY src ./src
RUN mvn -B -q -DskipTests package

# ---- Runtime stage ----
FROM eclipse-temurin:21-jre
WORKDIR /app

# Запуск не от root
RUN useradd --system --create-home --uid 1001 app
USER app

COPY --from=build /build/target/*.jar /app/app.jar

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
