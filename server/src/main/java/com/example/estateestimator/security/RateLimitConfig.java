package com.example.estateestimator.security;

import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.Ordered;

import tools.jackson.databind.ObjectMapper;

@Configuration
public class RateLimitConfig {

    /** Регистрируем явно (а не @Component), чтобы фильтр не был зарегистрирован дважды. */
    @Bean
    FilterRegistrationBean<RateLimitFilter> rateLimitFilter(RateLimitProperties props, ObjectMapper objectMapper) {
        FilterRegistrationBean<RateLimitFilter> registration =
                new FilterRegistrationBean<>(new RateLimitFilter(props, objectMapper));
        registration.setOrder(Ordered.HIGHEST_PRECEDENCE);
        registration.addUrlPatterns("/api/v1/auth/*");
        return registration;
    }
}
