FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /build
COPY pom.xml .
RUN mvn -q dependency:go-offline
COPY src ./src
RUN mvn -q clean package -DskipTests

FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=build /build/target/soc-backend-1.0.0.jar app.jar
EXPOSE 8080
# Keep the JVM within Render's 512 MB free-instance memory limit.
ENTRYPOINT ["sh", "-c", "java -Xms48m -Xmx256m -XX:+UseSerialGC -XX:MaxMetaspaceSize=96m -XX:ReservedCodeCacheSize=32m -Xss512k -Djava.security.egd=file:/dev/./urandom -jar app.jar"]
