#!/bin/bash
# Пример запуска
# sh postgres_vacuum.sh 99 2 tcp://localhost:5432
# Преобразуем строку подключения, заменяя tcp:// на postgres://postgres@
CONN=$(echo $3 | sed 's/tcp:\/\//postgres:\/\/postgres@/g')
# Для отладки
#echo $CONN
# Генерируем список баз данных, исключая служебные базы postgres и template
db_list=$(psql -R ' ' -Atc 'SELECT datname FROM pg_catalog.pg_database WHERE datname !~ '"'"'postgres|template'"'"'')
# Устанавливаем значения для переменных av_factor и interval
av_factor=$1
interval="$2 hour"
# Для каждой базы данных из списка выполняем SQL-запрос, чтобы найти таблицы с проблемами вакуумирования
for i in $db_list;do # Конкатенируем результат для каждой таблицы, не прошедшей вакуумирование, в переменную result
        result+=$(psql $i -U postgres -F ', ' -R '## ' -At <<SQL

        SET datestyle = dmy;
        -- Список таблиц, нуждающихся в вакууме

       WITH
                GLOBAL_AV_SCALE_FACTOR AS (
                        -- Получаем глобальную настройку autovacuum_vacuum_scale_factor
                        SELECT
                                SETTING::FLOAT
                        FROM
                                PG_SETTINGS
                        WHERE
                                NAME = 'autovacuum_vacuum_scale_factor'
                ),
                GLOBAL_AV_THRESHOLD AS (
                        -- Получаем глобальную настройку autovacuum_vacuum_threshold
                        SELECT
                                SETTING::BIGINT
                        FROM
                                PG_SETTINGS
                        WHERE
                                NAME = 'autovacuum_vacuum_threshold'
                ),
                TABLE_LIST AS (
                        -- Создаем список таблиц с их именами, идентификаторами (OID) и параметрами autovacuum
                        SELECT
                                RELNAME AS TABLE_NAME,
                                OID,
                                BTRIM(
                                        REGEXP_REPLACE(
                                                REGEXP_MATCH(
                                                        RELOPTIONS::TEXT,
                                                        'autovacuum_vacuum_scale_factor=(?:\d+(?:\.\d*)?|\.\d+)'
                                                )::TEXT,
                                                '\D*',
                                                ''
                                        ),
                                        '{}'
                                ) AS AV_SCALE_FACTOR,
                                BTRIM(
                                        REGEXP_REPLACE(
                                                REGEXP_MATCH(
                                                        RELOPTIONS::TEXT,
                                                        'autovacuum_vacuum_threshold=\d*'
                                                )::TEXT,
                                                '\D*',
                                                ''
                                        ),
                                        '{}'
                                ) AS AV_THRESHOLD
                        FROM
                                PG_CLASS
                        WHERE
                                RELKIND = 'r' -- только обычные таблицы
                ),
                TABLE_LIST_WGS AS -- Список таблиц с глобальными настройками
                (
                        SELECT
                                TABLE_NAME,
                                CASE
                                        -- Используем глобальный AV_SCALE_FACTOR, если не задано индивидуально
                                        WHEN AV_SCALE_FACTOR IS NULL THEN (
                                                SELECT
                                                        SETTING
                                                FROM
                                                        GLOBAL_AV_SCALE_FACTOR
                                        )
                                        ELSE AV_SCALE_FACTOR::FLOAT
                                END AV_SCALE_FACTOR,
                                CASE
                                        -- Используем глобальный AV_THRESHOLD, если не задано индивидуально
                                        WHEN AV_THRESHOLD IS NULL THEN (
                                                SELECT
                                                        SETTING
                                                FROM
                                                        GLOBAL_AV_THRESHOLD
                                        )
                                        ELSE AV_THRESHOLD::BIGINT
                                END AS AV_THRESHOLD,
                                PG_STAT_GET_LIVE_TUPLES (OID) AS LIVE_TUP,
                                PG_STAT_GET_DEAD_TUPLES (OID) AS DEAD_TUP,
                                PG_STAT_GET_LAST_AUTOVACUUM_TIME (OID) AS LAST_AV,
                                PG_STAT_GET_LAST_VACUUM_TIME (OID)  AS LAST_VACUUM
                        FROM
                                TABLE_LIST
                ),
                TABLE_LIST_VF AS -- Список таблиц с вычислением факторов вакуумирования и без пустых строк
                (
                        SELECT
                                TABLE_NAME,
                                AV_SCALE_FACTOR AS AV_SCALE_FACTOR,
                                AV_THRESHOLD,
                                LIVE_TUP,
                                DEAD_TUP,
                                LIVE_TUP + DEAD_TUP AS TOTAL_TUP,
                                ROUND(100 * DEAD_TUP / (DEAD_TUP + LIVE_TUP)) AS DEAD_FACTOR,
                                -- Проверяем, нужно ли вакуумировать таблицу
                                ROUND(
                                        100 * DEAD_TUP / (
                                                ROUND(AV_SCALE_FACTOR * (DEAD_TUP + LIVE_TUP)) + AV_THRESHOLD
                                        )
                                ) AS AV_FACTOR,
                                LAST_AV,
                                LAST_VACUUM
                        FROM
                                TABLE_LIST_WGS
                        WHERE
                                (LIVE_TUP + DEAD_TUP) > 0 -- учитываем только непустые таблицы
                )

                -- Форматируем вывод
        SELECT
                'table not vacuumed: (db=' ||
                 CURRENT_DATABASE() ||
                 ', table_name=' ||
                 TABLE_NAME ||
                ', av_factor=' ||
                 AV_FACTOR ||
                 ', last_av=' ||
                 COALESCE(
                        LAST_AV,
                        '1970-01-01'
                ) ||
                ') ' as table_info
        FROM
                TABLE_LIST_VF
                -- Ищем таблицы, у которых AV_FACTOR больше заданного порога и вакуумирование не запускалось в течение указанного интервала времени
        WHERE
                AV_FACTOR > $av_factor
                AND (
                        LAST_AV <= NOW() - INTERVAL '"$interval"'
                        OR LAST_AV IS NULL
                )
                -- Если ни одна таблица не требует вакуумирования, выводим OK
        UNION ALL
        SELECT
                CURRENT_DATABASE() || ' = OK'
        WHERE
                (
                        SELECT
                                COUNT(1)
                        FROM
                                TABLE_LIST_VF
                        WHERE
                AV_FACTOR > $av_factor
                AND (
                        LAST_AV <= NOW() - INTERVAL '"$interval"'
                        OR LAST_AV IS NULL
                )
                ) < 1;
        -- Добавляем разделитель строк для последующей обработки sed
        SELECT '|| ';

SQL
)
done;
# Выводим результат, заменяя разделители ## и || на символы новой строки для удобочитаемого вывода
echo $result | sed 's/\#\# /\n/g' | sed 's/|| /\n/g' | sed 's/ ||//g' | sed 's/^SET //g'