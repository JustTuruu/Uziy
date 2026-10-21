# syntax=docker/dockerfile:1
# Uziy backend (Spring Boot 4, Java 17). Built by the root docker-compose.yml:
#   docker compose up -d --build
# Tests are not run here (they need Testcontainers); run ./gradlew test on the host.

FROM eclipse-temurin:17-jdk AS build
WORKDIR /src
# Gradle wrapper + build files first, so dependencies are cached until they change.
COPY gradlew settings.gradle.kts build.gradle.kts ./
COPY gradle gradle
RUN --mount=type=cache,target=/root/.gradle \
    chmod +x gradlew && ./gradlew --no-daemon -q dependencies > /dev/null
COPY src src
RUN --mount=type=cache,target=/root/.gradle \
    ./gradlew --no-daemon -q bootJar -x test \
 && find build/libs -name '*.jar' ! -name '*-plain.jar' -exec cp {} /app.jar \;

FROM eclipse-temurin:17-jre
WORKDIR /app
RUN useradd --system --uid 10001 uziy
COPY --from=build /app.jar app.jar
USER uziy
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
