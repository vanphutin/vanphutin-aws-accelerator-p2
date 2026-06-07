package demo;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import java.util.Map;

@SpringBootApplication
public class App {
  public static void main(String[] args) { SpringApplication.run(App.class, args); }
}

@RestController
class HealthController {
  private final JdbcTemplate jdbc;
  HealthController(JdbcTemplate jdbc) { this.jdbc = jdbc; }
  @GetMapping("/")
  Map<String, Object> home() {
    Integer value = jdbc.queryForObject("select 1", Integer.class);
    return Map.of("service", "spring-mysql", "database", value);
  }
}
