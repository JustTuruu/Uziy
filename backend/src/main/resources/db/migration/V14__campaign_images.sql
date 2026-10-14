CREATE TABLE campaign_images (
    campaign_id BIGINT PRIMARY KEY REFERENCES campaigns(id) ON DELETE CASCADE,
    content BYTEA NOT NULL,
    content_type VARCHAR(32) NOT NULL
);
