package com.example.estateestimator;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;

@SpringBootApplication
@ConfigurationPropertiesScan
public class EstateEstimatorApplication {
    public static void main(String[] args) {
        SpringApplication.run(EstateEstimatorApplication.class, args);
    }
}
