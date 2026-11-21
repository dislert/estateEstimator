package com.example.estateestimator.security;

import java.io.IOException;
import java.time.Instant;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.web.filter.OncePerRequestFilter;

import com.example.estateestimator.common.ApiError;
import tools.jackson.databind.ObjectMapper;

/**
 * In-memory rate limiter (окно 1 минута) для эндпоинтов /api/v1/auth/login и /register.
 * Защищает от подбора учётных данных: при превышении лимита возвращает 429.
 * Ключ — IP клиента (с учётом X-Forwarded-For за прокси) + тип эндпоинта.
 */
public class RateLimitFilter extends OncePerRequestFilter {

    private static final long WINDOW_MILLIS = 60_000;
    private static final int MAX_TRACKED_KEYS = 10_000;

    private final RateLimitProperties props;
    private final ObjectMapper objectMapper;
    private final Map<String, WindowCounter> counters = new ConcurrentHashMap<>();

    public RateLimitFilter(RateLimitProperties props, ObjectMapper objectMapper) {
        this.props = props;
        this.objectMapper = objectMapper;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        if (!"POST".equalsIgnoreCase(request.getMethod())) {
            chain.doFilter(request, response);
            return;
        }
        String path = request.getRequestURI();
        int limit;
        String kind;
        if (path.equals("/api/v1/auth/login")) {
            limit = props.loginPerMinute();
            kind = "login";
        } else if (path.equals("/api/v1/auth/register")) {
            limit = props.registerPerMinute();
            kind = "register";
        } else {
            chain.doFilter(request, response);
            return;
        }

        if (counters.size() > MAX_TRACKED_KEYS) {
            counters.entrySet().removeIf(e -> e.getValue().isExpired());
        }

        String key = kind + '|' + clientIp(request);
        WindowCounter counter = counters.computeIfAbsent(key, k -> new WindowCounter());
        long retryAfterSeconds;
        synchronized (counter) {
            if (!counter.tryConsume(limit)) {
                retryAfterSeconds = counter.retryAfterSeconds();
                response.setStatus(HttpStatus.TOO_MANY_REQUESTS.value());
                response.setHeader("Retry-After", String.valueOf(retryAfterSeconds));
                response.setContentType(MediaType.APPLICATION_JSON_VALUE);
                response.setCharacterEncoding("UTF-8");
                objectMapper.writeValue(response.getWriter(), ApiError.of(
                        HttpStatus.TOO_MANY_REQUESTS.value(), "too_many_requests",
                        "Превышен лимит запросов, повторите через " + retryAfterSeconds + " с", path));
                return;
            }
        }
        chain.doFilter(request, response);
    }

    private static String clientIp(HttpServletRequest request) {
        String xff = request.getHeader("X-Forwarded-For");
        if (xff != null && !xff.isBlank()) {
            return xff.split(",", 2)[0].trim();
        }
        return request.getRemoteAddr();
    }

    /** Счётчик запросов в текущем минутном окне. */
    private static final class WindowCounter {
        private long windowStartMillis = System.currentTimeMillis();
        private int count;

        synchronized boolean tryConsume(int limit) {
            rollWindow();
            if (count >= limit) {
                return false;
            }
            count++;
            return true;
        }

        synchronized long retryAfterSeconds() {
            long elapsed = System.currentTimeMillis() - windowStartMillis;
            return Math.max(1, (WINDOW_MILLIS - elapsed) / 1000);
        }

        boolean isExpired() {
            return System.currentTimeMillis() - windowStartMillis > 2 * WINDOW_MILLIS;
        }

        private void rollWindow() {
            long now = System.currentTimeMillis();
            if (now - windowStartMillis >= WINDOW_MILLIS) {
                windowStartMillis = now;
                count = 0;
            }
        }
    }
}
