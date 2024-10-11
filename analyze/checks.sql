Матвьюхи
SELECT * FROM pg_matviews;

Внешние таблицы
SELECT t.foreign_table_schema, t.foreign_table_name, t.foreign_server_name,
    s.foreign_data_wrapper_name AS fdw,
    so.fdw_options
FROM information_schema.foreign_tables t
LEFT JOIN information_schema.foreign_servers s 
    ON s.foreign_server_name = t.foreign_server_name
LEFT JOIN (SELECT so.foreign_server_name,
                    array_agg(so.option_name || ':' || so.option_value ORDER BY so.option_name) AS fdw_options
            FROM information_schema.foreign_server_options so
            GROUP BY so.foreign_server_name
            ) so ON s.foreign_server_name = so.foreign_server_name;

вьюхи
\dv *.* 
матвьюхи
\dm *.*
функции (процедуры тоже должен вывести)
\df
триггеры отдельно
\dft
расширения
\dx
роли
\du