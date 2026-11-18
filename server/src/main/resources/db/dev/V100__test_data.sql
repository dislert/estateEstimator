
-- DML: Тестовые данные для MVP (пилотная территория — Вирджиния, США)
-- Пароль для всех тестовых пользователей: "Password123!"
-- 1. ПОЛЬЗОВАТЕЛИ И РОЛИ
-- Покупатель-инвестор
INSERT INTO users (id, email, password_hash, first_name, last_name, gender, is_blocked) VALUES
('11111111-1111-1111-1111-111111111111', 'buyer1@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj/R5Gm4z.5u', 'John', 'Smith', 'male', false);

-- Владелец недвижимости
INSERT INTO users (id, email, password_hash, first_name, last_name, gender, is_blocked) VALUES
('22222222-2222-2222-2222-222222222222', 'owner1@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj/R5Gm4z.5u', 'Alice', 'Johnson', 'female', false);

-- Администратор
INSERT INTO users (id, email, password_hash, first_name, last_name, is_blocked) VALUES
('33333333-3333-3333-3333-333333333333', 'admin@example.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj/R5Gm4z.5u', 'Admin', 'System', false);

-- Назначаем роли (BP-25: один аккаунт может иметь несколько ролей)
INSERT INTO user_roles (user_id, role_id) VALUES
('11111111-1111-1111-1111-111111111111', 1), -- buyer1 -> buyer
('22222222-2222-2222-2222-222222222222', 2), -- owner1 -> owner
('33333333-3333-3333-3333-333333333333', 3); -- admin  -> admin

-- 2. ОБЪЯВЛЕНИЯ И ГЕОДАННЫЕ (BR-02, BR-03)
-- Объект 1: Квартира в Ричмонде (23220)
INSERT INTO properties (id, owner_id, title, description, price, currency, property_type, area, rooms, bedrooms, status) VALUES
('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '22222222-2222-2222-2222-222222222222', 'Cozy 2BR Apartment in Richmond', 'Nice apartment near VCU campus.', 250000.00, 'USD', 'apartment', 85.00, 4, 2, 'published');

INSERT INTO locations (property_id, zip_code, country, region, city, street, house_number, latitude, longitude, is_manually_entered) VALUES
('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '23220', 'US', 'VA', 'Richmond', 'W Grace St', '100', 37.5481, -77.4538, false);

INSERT INTO photos (property_id, file_url, sort_order) VALUES
('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'https://s3.amazonaws.com/mock-bucket/photo1.jpg', 0),
('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'https://s3.amazonaws.com/mock-bucket/photo2.jpg', 1);

-- Объект 2: Дом в Ричмонде (23220)
INSERT INTO properties (id, owner_id, title, description, price, currency, property_type, area, rooms, bedrooms, status) VALUES
('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '22222222-2222-2222-2222-222222222222', 'Spacious 3BR House', 'Family house with backyard.', 380000.00, 'USD', 'house', 150.00, 6, 3, 'published');

INSERT INTO locations (property_id, zip_code, country, region, city, street, house_number, latitude, longitude, is_manually_entered) VALUES
('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '23220', 'US', 'VA', 'Richmond', 'Monument Ave', '2500', 37.5580, -77.4700, false);

-- Объект 3: Черновик (draft)
INSERT INTO properties (id, owner_id, title, description, price, currency, property_type, area, rooms, bedrooms, status) VALUES
('cccccccc-cccc-cccc-cccc-cccccccccccc', '22222222-2222-2222-2222-222222222222', 'Draft 1BR', 'Work in progress.', 150000.00, 'USD', 'apartment', 50.00, 2, 1, 'draft');

INSERT INTO locations (property_id, zip_code, country, region, city, latitude, longitude) VALUES
('cccccccc-cccc-cccc-cccc-cccccccccccc', '23220', 'US', 'VA', 'Richmond', 37.5400, -77.4400);

-- 3. АНАЛИТИКА (BR-05, BR-07, BR-11, NFR-33, NFR-39, NFR-40, NFR-41)
-- HUD Fair Market Rents для ZIP 23220
INSERT INTO hud_market_data (zip_code, bedrooms, median_rent, fiscal_year, source_id) VALUES
('23220', 1, 1050.00, 2026, 1),
('23220', 2, 1250.00, 2026, 1),
('23220', 3, 1600.00, 2026, 1),
('23220', 4, 1900.00, 2026, 1)
ON CONFLICT (zip_code, bedrooms, fiscal_year) DO UPDATE SET 
    median_rent = EXCLUDED.median_rent,
    loaded_at = now();

-- FHFA HPI на уровне штата VA (territory_level = 'state')
INSERT INTO market_history (territory_level, zip_code, region_code, metric_name, period_date, value, source_id) VALUES
('state', '', 'VA', 'FHFA_HPI', '2022-01-01', 400.12, 2),
('state', '', 'VA', 'FHFA_HPI', '2023-01-01', 410.50, 2),
('state', '', 'VA', 'FHFA_HPI', '2024-01-01', 420.00, 2),
('state', '', 'VA', 'FHFA_HPI', '2025-01-01', 426.12, 2),
('state', '', 'VA', 'FHFA_HPI', '2026-01-01', 439.04, 2)
ON CONFLICT DO NOTHING;

-- Zillow ZHVI на уровне ZIP
INSERT INTO market_history (territory_level, zip_code, region_code, metric_name, period_date, value, source_id) VALUES
('zip', '23220', '', 'ZILLOW_ZHVI', '2024-01-01', 245000.00, 3),
('zip', '23220', '', 'ZILLOW_ZHVI', '2025-01-01', 252000.00, 3),
('zip', '23220', '', 'ZILLOW_ZHVI', '2026-01-01', 260000.00, 3)
ON CONFLICT DO NOTHING;

-- Обновляем дату последней загрузки источников
UPDATE data_sources SET last_loaded_at = now() WHERE code IN ('HUD_FMR', 'FHFA_HPI', 'ZILLOW_ZHVI');

-- 4. ЧАТЫ И ЗАЯВКИ (BR-08, BR-09, NFR-14, NFR-15)
-- Чат создается по тройке (объект, покупатель, владелец)
INSERT INTO chats (id, property_id, buyer_id, owner_id) VALUES
('dddddddd-dddd-dddd-dddd-dddddddddddd', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222');

-- Заявка на объект
INSERT INTO applications (id, property_id, buyer_id, owner_id, chat_id, message, status) VALUES
('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222', 'dddddddd-dddd-dddd-dddd-dddddddddddd', 'Hello, I am interested in this apartment. Is the price negotiable?', 'new');

-- Сообщения в чате (NFR-51: история переписки)
INSERT INTO messages (chat_id, sender_id, text, is_read, created_at) VALUES
('dddddddd-dddd-dddd-dddd-dddddddddddd', '11111111-1111-1111-1111-111111111111', 'Hello, I am interested in this apartment. Is the price negotiable?', true, now() - interval '2 hours'),
('dddddddd-dddd-dddd-dddd-dddddddddddd', '22222222-2222-2222-2222-222222222222', 'Hi! Yes, we can discuss it. What is your offer?', false, now() - interval '1 hour');

-- 5. СНЯТИЕ ОБЪЯВЛЕНИЯ С ПУБЛИКАЦИИ (BP-14, BP-15, NFR-48)
-- Меняем статус объекта 2 на archived для теста
UPDATE properties SET status = 'archived' WHERE id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';