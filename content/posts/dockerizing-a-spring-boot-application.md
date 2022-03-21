---
title: "Dockerizing a Spring Boot Application"
date: 2022-03-21
tags:
- spring boot
- docker
- java
- gradle
---

A guide to running a Spring Boot Application as a Docker container.
<!--more-->

{{< image classes="nocaption fig-50 clear" src="/images/content/spring-boot-docker.png" title="Spring Boot and Docker" >}}

In this post, I will show how we can dockerize a Spring Boot Application.

## What is Docker?

Docker is popular in the engineering community for its portability when containerizing applications, it
provides a consistent environment across different machines that all configuration and code can be deployed to
without any problems.

Docker is great in a microservices architecture because it is lightweight and fast. There is a huge community of
maintainers providing well known technologies (proxies, servers, and databases) as Docker containers.

Docker can be installed on many OSs. In this post, I am using [Docker for Mac](https://docs.docker.com/desktop/mac/install/).

## A simple Dockerized Spring Boot Application

I will use [Spring Boot](https://spring.io/projects/spring-boot), which comes with an embedded web server,
and write a simple API to demonstrate how to access a service running in Docker.

Using [Spring Initializr](https://start.spring.io/), I will create a Gradle project and choose Spring Web
as a dependency, which comes with Apache Tomcat as the default embedded container.

{{< codeblock "build.gradle" >}}
plugins {
    id 'org.springframework.boot' version '2.6.4'
    id 'io.spring.dependency-management' version '1.0.11.RELEASE'
    id 'java'
}

group = 'com.github.mdanilakis'
version = '0.0.1-SNAPSHOT'
sourceCompatibility = '11'

configurations {
    compileOnly {
        extendsFrom annotationProcessor
    }
}

repositories {
    mavenCentral()
}

dependencies {
    implementation 'org.springframework.boot:spring-boot-starter-web'
    implementation 'org.springframework.boot:spring-boot-starter-actuator'
    compileOnly 'org.projectlombok:lombok'
    annotationProcessor 'org.projectlombok:lombok'
    testImplementation 'org.springframework.boot:spring-boot-starter-test'
}

bootJar {
    archiveFileName = "app.jar"
}

tasks.named('test') {
    useJUnitPlatform()
}
{{< /codeblock >}}

I will create a simple GET mapping `/hello` which responds with `Hello, world!`.

```java
@RestController
public class HelloController {

	@GetMapping("/hello")
	public String hello() {
		return "Hello, world!";
	}
}
```

Spring Boot comes with a Gradle wrapper, so we don't need to install anything.

We can now bundle our sources and make an executable jar.

```
./gradlew clean test bootJar
```

This will create an executable jar in the `build` directory. We can now write a simple Dockerfile,
which is a set of instructions to write your own Docker images, and copy the jar in the image.

{{< codeblock "Dockerfile" >}}
FROM amazoncorretto:11-alpine-jdk
MAINTAINER michalisdaniilakis.com
COPY build/libs/app.jar app.jar
ENTRYPOINT ["java", "-jar", "/app.jar"]
{{< /codeblock >}}

The `FROM` keyword tells Docker to use a base image. We will use a distribution of OpenJDK 11,
and `COPY` the jar. The `ENTRYPOINT` instruction is used to set executables that will always run when
the container is initiated.

In this case, we are running our executable jar using java.

We've seen how we can create an executable jar, we finally need to build our Docker image.
Let's put everything together in one command:

```
./gradlew clean test bootJar && docker build -t spring-boot-docker .
```

Spring Boot runs on port `8080` by default. To run the container, we map to the same port on the host machine
so that we can access our service on `localhost`:

```
docker run -p 8080:8080 spring-boot-docker
```

### Test using cURL

```
curl -i http://localhost:8080/hello
```

Result:
```text
HTTP/1.1 200
Content-Type: text/plain;charset=UTF-8
Content-Length: 13
Date: Sun, 13 Mar 2022 20:30:00 GMT

Hello, world!
```

You can find the complete source of this guide [in GitHub](https://github.com/mdanilakis/spring-boot-docker).

eof.
