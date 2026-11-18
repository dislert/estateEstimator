package com.example.estateestimator.storage;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.stereotype.Component;

import com.example.estateestimator.config.S3Properties;

import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.CreateBucketRequest;
import software.amazon.awssdk.services.s3.model.HeadBucketRequest;
import software.amazon.awssdk.services.s3.model.NoSuchBucketException;

/** При старте проверяет наличие бакета; в dev/test может создать его (app.s3.create-bucket-if-missing). */
@Component
public class BucketInitializer implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(BucketInitializer.class);

    private final S3Client s3;
    private final S3Properties props;

    public BucketInitializer(S3Client s3, S3Properties props) {
        this.s3 = s3;
        this.props = props;
    }

    @Override
    public void run(ApplicationArguments args) {
        String bucket = props.bucket();
        try {
            s3.headBucket(HeadBucketRequest.builder().bucket(bucket).build());
            log.info("S3 bucket '{}' exists", bucket);
        } catch (NoSuchBucketException e) {
            if (!props.createBucketIfMissing()) {
                throw new IllegalStateException("S3 bucket '" + bucket + "' does not exist", e);
            }
            s3.createBucket(CreateBucketRequest.builder().bucket(bucket).build());
            log.info("S3 bucket '{}' created", bucket);
        }
    }
}
