plugins {
	java
	id("org.springframework.boot") version "4.1.1"
	id("io.spring.dependency-management") version "1.1.7"
}

group = "mn.uziy"
version = "0.0.1-SNAPSHOT"

java {
	toolchain {
		languageVersion = JavaLanguageVersion.of(17)
	}
}

repositories {
	mavenCentral()
}

dependencies {
	implementation("org.springframework.boot:spring-boot-starter-actuator")
	implementation("org.springframework.boot:spring-boot-starter-data-jpa")
	implementation("org.springframework.boot:spring-boot-starter-flyway")
	implementation("org.springframework.boot:spring-boot-starter-security")
	implementation("org.springframework.boot:spring-boot-starter-validation")
	implementation("org.springframework.boot:spring-boot-starter-webmvc")
	implementation("org.flywaydb:flyway-database-postgresql")
	// JWT
	implementation("io.jsonwebtoken:jjwt-api:0.12.6")
	runtimeOnly("io.jsonwebtoken:jjwt-impl:0.12.6")
	runtimeOnly("io.jsonwebtoken:jjwt-jackson:0.12.6")
	// Push notifications (FCM covers Android + iOS)
	implementation("com.google.firebase:firebase-admin:9.11.0")
	developmentOnly("org.springframework.boot:spring-boot-devtools")
	runtimeOnly("org.postgresql:postgresql")
	testImplementation("org.springframework.boot:spring-boot-starter-actuator-test")
	testImplementation("org.springframework.boot:spring-boot-starter-data-jpa-test")
	testImplementation("org.springframework.boot:spring-boot-starter-flyway-test")
	testImplementation("org.springframework.boot:spring-boot-starter-security-test")
	testImplementation("org.springframework.boot:spring-boot-starter-validation-test")
	testImplementation("org.springframework.boot:spring-boot-starter-webmvc-test")
	testImplementation("org.testcontainers:junit-jupiter:1.20.4")
	testImplementation("org.testcontainers:postgresql:1.20.4")
	testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}

tasks.withType<JavaCompile> {
	// Keeps @PathVariable/@RequestParam/constructor-binding names available.
	options.compilerArgs.add("-parameters")
}

tasks.withType<Test> {
	useJUnitPlatform()
}

springBoot {
	// We now ship extra main() methods (HashCli, MakeAdminCli) as Gradle
	// tasks — pin the Spring Boot entry point so bootRun/bootJar don't get
	// confused about which class starts the app.
	mainClass.set("mn.uziy.backend.UziyBackendApplication")
}

// --- Bootstrap CLI tasks ---------------------------------------------------
// ./gradlew hash --args="password"
// ./gradlew makeAdmin --args="99990000 mypass"
tasks.register<JavaExec>("hash") {
	group = "bootstrap"
	description = "Print a BCrypt hash for the given plaintext: --args=\"<password>\""
	mainClass.set("mn.uziy.backend.tools.HashCli")
	classpath = sourceSets["main"].runtimeClasspath
}
tasks.register<JavaExec>("makeAdmin") {
	group = "bootstrap"
	description = "Insert or promote an ADMIN user: --args=\"<phone8digits> <password>\""
	mainClass.set("mn.uziy.backend.tools.MakeAdminCli")
	classpath = sourceSets["main"].runtimeClasspath
}
