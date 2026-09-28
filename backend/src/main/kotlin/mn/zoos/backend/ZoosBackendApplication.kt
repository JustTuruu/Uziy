package mn.zoos.backend

import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.runApplication

@SpringBootApplication
class ZoosBackendApplication

fun main(args: Array<String>) {
	runApplication<ZoosBackendApplication>(*args)
}
