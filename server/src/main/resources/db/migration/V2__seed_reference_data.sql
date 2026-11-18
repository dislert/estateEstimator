-- V2: справочники (роли и источники данных)
INSERT INTO roles (id, code, name) VALUES
    (1, 'buyer', 'Покупатель'),
    (2, 'owner', 'Владелец'),
    (3, 'admin', 'Админ');

INSERT INTO data_sources (id, code, name, license) VALUES
    (1, 'HUD_FMR', 'HUD Fair Market Rents', 'public domain'),
    (2, 'FHFA_HPI', 'FHFA House Price Index', 'public domain'),
    (3, 'ZILLOW_ZHVI', 'Zillow ZHVI', 'free for public use'),
    (4, 'ZILLOW_ZORI', 'Zillow ZORI', 'free for public use')
ON CONFLICT DO NOTHING;

-- id вставлены явно, поэтому двигаем SERIAL-последовательность,
-- иначе следующий INSERT без id упадёт на дубле первичного ключа
SELECT setval(pg_get_serial_sequence('data_sources', 'id'), (SELECT max(id) FROM data_sources));
