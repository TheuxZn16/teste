# -----------------------------------------------------------------------------
# Estágio 1: Build com Maven
# -----------------------------------------------------------------------------
FROM maven:3.9-eclipse-temurin-25 AS builder

WORKDIR /app

# Copia o pom.xml primeiro para aproveitar o cache das dependências
COPY pom.xml .
RUN mvn dependency:go-offline -q

# Copia o código-fonte e compila o JAR de produção
COPY src ./src
RUN mvn clean package -DskipTests -q

# -----------------------------------------------------------------------------
# Estágio 2: Runtime com JDK 25 slim
# -----------------------------------------------------------------------------
FROM eclipse-temurin:25-jre-alpine

WORKDIR /app

# Cria usuário não-root para segurança
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Copia o JAR do estágio de build
COPY --from=builder /app/target/*.jar app.jar

USER appuser

EXPOSE 8080

# Configurações de JVM para containers
ENV JAVA_OPTS="-Xms256m -Xmx512m -XX:+UseG1GC -XX:MaxGCPauseMillis=200"

# CMD permite sobrescrever os argumentos (ex: --spring.profiles.active=render)
CMD ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
