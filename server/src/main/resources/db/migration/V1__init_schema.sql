-- V1: схема БД в соответствии с утверждённой ERD
-- 1. РАСШИРЕНИЯ И ФУНКЦИИ
-- PostGIS для геопространственных данных (BR-03)
CREATE EXTENSION IF NOT EXISTS postgis;
-- Функция для автоматического обновления updated_at
CREATE OR REPLACE FUNCTION trg_set_updated_at() 
RETURNS trigger AS $$
BEGIN 
    NEW.updated_at = now(); 
    RETURN NEW; 
END;
$$ LANGUAGE plpgsql;

-- 2. ПОЛЬЗОВАТЕЛИ И РОЛИ (BR-01, NFR-01, NFR-09, NFR-16)
CREATE TABLE roles (
    id          INT PRIMARY KEY,
    code        VARCHAR(20) NOT NULL UNIQUE,
    name        VARCHAR(50) NOT NULL
);

CREATE TABLE users (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email         VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    first_name    VARCHAR(100) NOT NULL,
    last_name     VARCHAR(100) NOT NULL,
    gender        VARCHAR(10) CHECK (gender IS NULL OR gender IN ('male', 'female')),
    avatar_url    TEXT,
    is_blocked    BOOLEAN NOT NULL DEFAULT false,
    created_at    TIMESTAMP NOT NULL DEFAULT now(),
    updated_at    TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TRIGGER trg_users_updated_at 
    BEFORE UPDATE ON users 
    FOR EACH ROW EXECUTE FUNCTION trg_set_updated_at();

CREATE TABLE user_roles (
    user_id UUID NOT NULL,
    role_id INT NOT NULL,
    PRIMARY KEY (user_id, role_id),
    CONSTRAINT fk_user_roles_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_user_roles_role FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE RESTRICT
);

-- 3. ОБЪЯВЛЕНИЯ И ГЕОДАННЫЕ (BR-02, BR-03, NFR-11, NFR-17, NFR-30)
CREATE TABLE properties (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id      UUID NOT NULL,
    title         VARCHAR(255) NOT NULL,
    description   TEXT,
    price         DECIMAL(15,2) NOT NULL CHECK (price > 0),
    currency      VARCHAR(3) NOT NULL CHECK (currency IN ('USD', 'EUR', 'GBP')),
    property_type VARCHAR(20) NOT NULL CHECK (property_type IN ('apartment', 'house')),
    area          DECIMAL(8,2) NOT NULL CHECK (area > 0),
    rooms         INT NOT NULL CHECK (rooms > 0),
    bedrooms      INT NOT NULL CHECK (bedrooms BETWEEN 1 AND 4),
    status        VARCHAR(20) NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'published', 'archived')),
    created_at    TIMESTAMP NOT NULL DEFAULT now(),
    updated_at    TIMESTAMP NOT NULL DEFAULT now(),
    CONSTRAINT fk_properties_owner FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE RESTRICT
);

CREATE INDEX idx_properties_status ON properties(status);
CREATE INDEX idx_properties_owner ON properties(owner_id);

CREATE TRIGGER trg_properties_updated_at 
    BEFORE UPDATE ON properties 
    FOR EACH ROW EXECUTE FUNCTION trg_set_updated_at();

CREATE TABLE locations (
    property_id         UUID PRIMARY KEY,
    zip_code            VARCHAR(20) NOT NULL,
    country             VARCHAR(2) NOT NULL CHECK (country IN ('US', 'GB', 'FR')),
    region              VARCHAR(100),
    city                VARCHAR(100) NOT NULL,
    street              VARCHAR(255),
    house_number        VARCHAR(20),
    latitude            DECIMAL(10,8) NOT NULL,
    longitude           DECIMAL(11,8) NOT NULL,
    is_manually_entered BOOLEAN NOT NULL DEFAULT false,
    geocoded_at         TIMESTAMP,
    CONSTRAINT fk_locations_property FOREIGN KEY (property_id) REFERENCES properties(id) ON DELETE CASCADE
);

CREATE INDEX idx_locations_zip ON locations(zip_code);

CREATE TABLE photos (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    property_id UUID NOT NULL,
    file_url    VARCHAR(2048) NOT NULL,
    sort_order  INT NOT NULL DEFAULT 0,
    created_at  TIMESTAMP NOT NULL DEFAULT now(),
    CONSTRAINT fk_photos_property FOREIGN KEY (property_id) REFERENCES properties(id) ON DELETE CASCADE
);

-- 4. АНАЛИТИКА (BR-05, BR-07, BR-11, NFR-33, NFR-39, NFR-40, NFR-41, NFR-42)
CREATE TABLE data_sources (
    id             SERIAL PRIMARY KEY,
    code           VARCHAR(50) NOT NULL UNIQUE,
    name           VARCHAR(100) NOT NULL,
    license        VARCHAR(50),
    last_loaded_at TIMESTAMP,
    status         VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'error', 'disabled'))
);

CREATE TABLE hud_market_data (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    zip_code     VARCHAR(20) NOT NULL,
    bedrooms     INT NOT NULL CHECK (bedrooms BETWEEN 1 AND 4),
    median_rent  DECIMAL(10,2) NOT NULL,
    fiscal_year  INT NOT NULL,
    source_id    INT NOT NULL,
    loaded_at    TIMESTAMP NOT NULL DEFAULT now(),
    CONSTRAINT fk_hud_source FOREIGN KEY (source_id) REFERENCES data_sources(id) ON DELETE RESTRICT,
    CONSTRAINT uq_hud_zip_bedrooms_year UNIQUE (zip_code, bedrooms, fiscal_year)
);

CREATE TABLE market_history (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    territory_level VARCHAR(20) NOT NULL CHECK (territory_level IN ('state', 'metro', 'county', 'zip')),
    zip_code        VARCHAR(20) NOT NULL DEFAULT '',
    region_code     VARCHAR(20) NOT NULL DEFAULT '',
    metric_name     VARCHAR(100) NOT NULL,
    period_date     DATE NOT NULL,
    value           DECIMAL(12,4) NOT NULL,
    source_id       INT NOT NULL,
    loaded_at       TIMESTAMP NOT NULL DEFAULT now(),
    CONSTRAINT fk_history_source FOREIGN KEY (source_id) REFERENCES data_sources(id) ON DELETE RESTRICT,
    CONSTRAINT uq_market_history UNIQUE (territory_level, zip_code, region_code, metric_name, period_date)
);

-- 5. ЧАТЫ (BR-09, NFR-10, NFR-15, NFR-48)
CREATE TABLE chats (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    property_id UUID NOT NULL,
    buyer_id    UUID NOT NULL,
    owner_id    UUID NOT NULL,
    created_at  TIMESTAMP NOT NULL DEFAULT now(),
    CONSTRAINT fk_chats_property FOREIGN KEY (property_id) REFERENCES properties(id) ON DELETE CASCADE,
    CONSTRAINT fk_chats_buyer FOREIGN KEY (buyer_id) REFERENCES users(id) ON DELETE RESTRICT,
    CONSTRAINT fk_chats_owner FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE RESTRICT,
    CONSTRAINT chk_chats_not_self CHECK (buyer_id <> owner_id),
    CONSTRAINT uq_chat_combination UNIQUE (property_id, buyer_id, owner_id)
);

CREATE TABLE messages (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    chat_id    UUID NOT NULL,
    sender_id  UUID NOT NULL,
    text       TEXT NOT NULL,
    is_read    BOOLEAN NOT NULL DEFAULT false,
    read_at    TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    CONSTRAINT fk_messages_chat FOREIGN KEY (chat_id) REFERENCES chats(id) ON DELETE CASCADE,
    CONSTRAINT fk_messages_sender FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE RESTRICT
);

CREATE INDEX idx_messages_chat ON messages(chat_id, created_at);

-- 6. ЗАЯВКИ (BR-08, NFR-12, NFR-13, NFR-14, NFR-43)
CREATE TABLE applications (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    property_id UUID NOT NULL,
    buyer_id    UUID NOT NULL,
    owner_id    UUID NOT NULL,
    chat_id     UUID NOT NULL,
    message     TEXT NOT NULL,
    status      VARCHAR(20) NOT NULL DEFAULT 'new' CHECK (status IN ('new', 'in_progress', 'closed', 'rejected', 'cancelled')),
    created_at  TIMESTAMP NOT NULL DEFAULT now(),
    updated_at  TIMESTAMP NOT NULL DEFAULT now(),
    CONSTRAINT fk_app_property FOREIGN KEY (property_id) REFERENCES properties(id) ON DELETE CASCADE,
    CONSTRAINT fk_app_buyer FOREIGN KEY (buyer_id) REFERENCES users(id) ON DELETE RESTRICT,
    CONSTRAINT fk_app_owner FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE RESTRICT,
    CONSTRAINT fk_app_chat FOREIGN KEY (chat_id) REFERENCES chats(id) ON DELETE CASCADE,
    CONSTRAINT chk_app_not_self CHECK (buyer_id <> owner_id)
);

-- Partial Unique Index: запрет дублей только для активных заявок (NFR-14)
CREATE UNIQUE INDEX uq_applications_active 
    ON applications (property_id, buyer_id) 
    WHERE status IN ('new', 'in_progress');

CREATE INDEX idx_applications_owner_status ON applications(owner_id, status);

CREATE TRIGGER trg_applications_updated_at 
    BEFORE UPDATE ON applications 
    FOR EACH ROW EXECUTE FUNCTION trg_set_updated_at();
