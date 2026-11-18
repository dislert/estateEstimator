-- Контрольные запросы: проверяют, что схема, справочники и ограничения физически есть в БД.
-- Всё выполняется в транзакции и откатывается, данные не остаются.
-- Ручной запуск:  psql -v ON_ERROR_STOP=1 -f verify.sql  "postgresql://user:pass@localhost:5432/db"
-- Любая ошибка = проверка не пройдена.

BEGIN;

-- Хелпер: запрос ОБЯЗАН упасть именно с указанным SQLSTATE
CREATE FUNCTION pg_temp.expect_fail(stmt text, expected_state text) RETURNS void
LANGUAGE plpgsql AS $$
DECLARE failed boolean := false;
BEGIN
    BEGIN
        EXECUTE stmt;
    EXCEPTION WHEN OTHERS THEN
        failed := true;
        IF SQLSTATE <> expected_state THEN
            RAISE EXCEPTION 'Ожидали SQLSTATE %, получили % (%) для: %', expected_state, SQLSTATE, SQLERRM, stmt;
        END IF;
    END;
    IF NOT failed THEN
        RAISE EXCEPTION 'Ограничение не сработало, запрос выполнился: %', stmt;
    END IF;
END $$;

-- 1. Структура: таблицы, триггеры, индексы, констрейнты
DO $$
DECLARE
    missing text;
    n int;
BEGIN
    SELECT string_agg(t, ', ') INTO missing
    FROM unnest(ARRAY['roles','users','user_roles','properties','locations','photos',
                      'data_sources','hud_market_data','market_history','chats','messages','applications']) AS t
    WHERE to_regclass('public.' || t) IS NULL;
    IF missing IS NOT NULL THEN
        RAISE EXCEPTION 'Нет таблиц: %', missing;
    END IF;

    SELECT count(*) INTO n
    FROM pg_class c
             JOIN pg_namespace ns ON ns.oid = c.relnamespace
    WHERE ns.nspname = 'public'
      AND c.relkind IN ('r', 'p')
      AND c.relname <> 'flyway_schema_history'
      AND NOT EXISTS (SELECT 1 FROM pg_depend d
                      WHERE d.classid = 'pg_class'::regclass
        AND d.objid = c.oid
        AND d.deptype = 'e');   -- принадлежит расширению (spatial_ref_sys и т.п.)

    SELECT count(*) INTO n FROM pg_trigger
    WHERE NOT tgisinternal
      AND tgname IN ('trg_users_updated_at', 'trg_properties_updated_at', 'trg_applications_updated_at');
    IF n <> 3 THEN
        RAISE EXCEPTION 'Ожидали 3 триггера updated_at, найдено %', n;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_indexes
                   WHERE schemaname = 'public' AND indexname = 'uq_applications_active'
                     AND indexdef ILIKE '%UNIQUE%' AND indexdef ILIKE '%WHERE%') THEN
        RAISE EXCEPTION 'Нет частичного уникального индекса uq_applications_active';
    END IF;

    SELECT string_agg(c, ', ') INTO missing
    FROM unnest(ARRAY['chk_chats_not_self', 'chk_app_not_self', 'uq_chat_combination',
                      'uq_hud_zip_bedrooms_year', 'uq_market_history']) AS c
    WHERE NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = c);
    IF missing IS NOT NULL THEN
        RAISE EXCEPTION 'Нет констрейнтов: %', missing;
    END IF;
END $$;

-- 2. Справочники
DO $$
BEGIN
    IF (SELECT array_agg(code ORDER BY id) FROM roles) <> ARRAY['buyer','owner','admin']::varchar[] THEN
        RAISE EXCEPTION 'Справочник roles заполнен неверно';
    END IF;
    IF (SELECT count(*) FROM data_sources WHERE code IN ('HUD_FMR','FHFA_HPI','ZILLOW_ZHVI','ZILLOW_ZORI')) <> 4 THEN
        RAISE EXCEPTION 'Справочник data_sources заполнен неверно';
    END IF;
    -- последовательность сдвинута: вставка без id работает
    INSERT INTO data_sources (code, name) VALUES ('VERIFY_SRC', 'verify');
END $$;

-- 3. Поведение ограничений на тестовых данных
DO $$
DECLARE
    v_buyer uuid := gen_random_uuid();
    v_owner uuid := gen_random_uuid();
    v_prop  uuid := gen_random_uuid();
    v_chat  uuid := gen_random_uuid();
    v_app   uuid := gen_random_uuid();
    v_ts    timestamp;
BEGIN
    INSERT INTO users (id, email, password_hash, first_name, last_name) VALUES
        (v_buyer, 'verify-buyer-' || v_buyer || '@test.local', 'x', 'B', 'B'),
        (v_owner, 'verify-owner-' || v_owner || '@test.local', 'x', 'O', 'O');

    INSERT INTO properties (id, owner_id, title, price, currency, property_type, area, rooms, bedrooms)
    VALUES (v_prop, v_owner, 'verify', 100, 'USD', 'apartment', 50, 2, 1);

    INSERT INTO chats (id, property_id, buyer_id, owner_id) VALUES (v_chat, v_prop, v_buyer, v_owner);

    INSERT INTO applications (id, property_id, buyer_id, owner_id, chat_id, message)
    VALUES (v_app, v_prop, v_buyer, v_owner, v_chat, 'first');

    -- users
    PERFORM pg_temp.expect_fail(format(
        'INSERT INTO users (email, password_hash, first_name, last_name, gender) VALUES (%L, %L, %L, %L, %L)',
        'verify-g-' || v_buyer || '@test.local', 'x', 'a', 'b', 'other'), '23514');
    PERFORM pg_temp.expect_fail(format(
        'INSERT INTO users (email, password_hash, first_name, last_name) VALUES (%L, %L, %L, %L)',
        'verify-buyer-' || v_buyer || '@test.local', 'x', 'a', 'b'), '23505');

    -- properties: CHECK
    PERFORM pg_temp.expect_fail(format(
        'INSERT INTO properties (owner_id, title, price, currency, property_type, area, rooms, bedrooms) VALUES (%L,%L,%s,%L,%L,%s,%s,%s)',
        v_owner, 't', 0, 'USD', 'house', 50, 2, 1), '23514');      -- price > 0
    PERFORM pg_temp.expect_fail(format(
        'INSERT INTO properties (owner_id, title, price, currency, property_type, area, rooms, bedrooms) VALUES (%L,%L,%s,%L,%L,%s,%s,%s)',
        v_owner, 't', 10, 'JPY', 'house', 50, 2, 1), '23514');     -- currency
    PERFORM pg_temp.expect_fail(format(
        'INSERT INTO properties (owner_id, title, price, currency, property_type, area, rooms, bedrooms) VALUES (%L,%L,%s,%L,%L,%s,%s,%s)',
        v_owner, 't', 10, 'USD', 'villa', 50, 2, 1), '23514');     -- property_type
    PERFORM pg_temp.expect_fail(format(
        'INSERT INTO properties (owner_id, title, price, currency, property_type, area, rooms, bedrooms) VALUES (%L,%L,%s,%L,%L,%s,%s,%s)',
        v_owner, 't', 10, 'USD', 'house', 50, 2, 5), '23514');     -- bedrooms 1..4
    PERFORM pg_temp.expect_fail(format(
        'INSERT INTO properties (owner_id, title, price, currency, property_type, area, rooms, bedrooms, status) VALUES (%L,%L,%s,%L,%L,%s,%s,%s,%L)',
        v_owner, 't', 10, 'USD', 'house', 50, 2, 1, 'sold'), '23514'); -- status

    -- locations / аналитика: CHECK и UNIQUE
    PERFORM pg_temp.expect_fail(format(
        'INSERT INTO locations (property_id, zip_code, country, city, latitude, longitude) VALUES (%L,%L,%L,%L,%s,%s)',
        v_prop, '23220', 'DE', 'X', 1, 1), '23514');
    PERFORM pg_temp.expect_fail(
        'INSERT INTO hud_market_data (zip_code, bedrooms, median_rent, fiscal_year, source_id) VALUES (''99999'', 5, 1, 2026, 1)', '23514');
    INSERT INTO hud_market_data (zip_code, bedrooms, median_rent, fiscal_year, source_id) VALUES ('99999', 1, 1, 2026, 1);
    PERFORM pg_temp.expect_fail(
        'INSERT INTO hud_market_data (zip_code, bedrooms, median_rent, fiscal_year, source_id) VALUES (''99999'', 1, 2, 2026, 1)', '23505');
    PERFORM pg_temp.expect_fail(
        'INSERT INTO market_history (territory_level, metric_name, period_date, value, source_id) VALUES (''planet'', ''m'', ''2026-01-01'', 1, 1)', '23514');

    -- чаты: не сам с собой + уникальность диалога
    PERFORM pg_temp.expect_fail(format(
        'INSERT INTO chats (property_id, buyer_id, owner_id) VALUES (%L,%L,%L)', v_prop, v_owner, v_owner), '23514');
    PERFORM pg_temp.expect_fail(format(
        'INSERT INTO chats (property_id, buyer_id, owner_id) VALUES (%L,%L,%L)', v_prop, v_buyer, v_owner), '23505');

    -- заявки: не сам себе
    PERFORM pg_temp.expect_fail(format(
        'INSERT INTO applications (property_id, buyer_id, owner_id, chat_id, message) VALUES (%L,%L,%L,%L,%L)',
        v_prop, v_owner, v_owner, v_chat, 'self'), '23514');

    -- заявки: частичный уникальный индекс (дубль активной запрещён, после закрытия — можно)
    PERFORM pg_temp.expect_fail(format(
        'INSERT INTO applications (property_id, buyer_id, owner_id, chat_id, message) VALUES (%L,%L,%L,%L,%L)',
        v_prop, v_buyer, v_owner, v_chat, 'dup'), '23505');
    UPDATE applications SET status = 'in_progress' WHERE id = v_app;
    PERFORM pg_temp.expect_fail(format(
        'INSERT INTO applications (property_id, buyer_id, owner_id, chat_id, message) VALUES (%L,%L,%L,%L,%L)',
        v_prop, v_buyer, v_owner, v_chat, 'dup2'), '23505');
    UPDATE applications SET status = 'closed' WHERE id = v_app;
    INSERT INTO applications (property_id, buyer_id, owner_id, chat_id, message)
    VALUES (v_prop, v_buyer, v_owner, v_chat, 'after close');

    -- FK RESTRICT: нельзя удалить владельца объекта
    PERFORM pg_temp.expect_fail(format('DELETE FROM users WHERE id = %L', v_owner), '23503');

    -- триггеры updated_at
    UPDATE users SET updated_at = '2000-01-01' WHERE id = v_buyer;
    SELECT updated_at INTO v_ts FROM users WHERE id = v_buyer;
    IF v_ts <= '2000-01-01' THEN RAISE EXCEPTION 'trg_users_updated_at не сработал'; END IF;

    UPDATE properties SET updated_at = '2000-01-01' WHERE id = v_prop;
    SELECT updated_at INTO v_ts FROM properties WHERE id = v_prop;
    IF v_ts <= '2000-01-01' THEN RAISE EXCEPTION 'trg_properties_updated_at не сработал'; END IF;

    UPDATE applications SET updated_at = '2000-01-01' WHERE id = v_app;
    SELECT updated_at INTO v_ts FROM applications WHERE id = v_app;
    IF v_ts <= '2000-01-01' THEN RAISE EXCEPTION 'trg_applications_updated_at не сработал'; END IF;

    -- каскад: удаление объекта чистит чаты, заявки, сообщения
    INSERT INTO messages (chat_id, sender_id, text) VALUES (v_chat, v_buyer, 'hi');
    DELETE FROM properties WHERE id = v_prop;
    IF EXISTS (SELECT 1 FROM chats WHERE id = v_chat)
       OR EXISTS (SELECT 1 FROM applications WHERE property_id = v_prop)
       OR EXISTS (SELECT 1 FROM messages WHERE chat_id = v_chat) THEN
        RAISE EXCEPTION 'ON DELETE CASCADE от properties не отработал';
    END IF;

    RAISE NOTICE 'verify.sql: все проверки пройдены';
END $$;

ROLLBACK;
