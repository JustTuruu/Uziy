package mn.uziy.backend.notification;

import java.util.concurrent.ThreadPoolExecutor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.task.TaskExecutor;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;

/** Small bounded executor so pushes never run on, or pile up behind, request threads. */
@Configuration
@EnableAsync
public class AsyncConfig {

    public static final String PUSH_EXECUTOR = "pushExecutor";

    private static final Logger LOG = LoggerFactory.getLogger(AsyncConfig.class);
    private static final int CORE_THREADS = 1;
    private static final int MAX_THREADS = 2;
    private static final int QUEUE_CAPACITY = 100;

    @Bean(PUSH_EXECUTOR)
    public TaskExecutor pushExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setThreadNamePrefix("push-");
        executor.setCorePoolSize(CORE_THREADS);
        executor.setMaxPoolSize(MAX_THREADS);
        executor.setQueueCapacity(QUEUE_CAPACITY);
        // A full queue drops the notification (logged) instead of failing the caller's commit.
        executor.setRejectedExecutionHandler((task, pool) ->
                LOG.warn("push queue full, dropping a notification job"));
        return executor;
    }
}
