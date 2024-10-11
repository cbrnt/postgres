-- Пользователь с полными правами на базу (создаем под пользователем postgres):
create database mydb;
create user myuser password 'pass';
-- Даем все права на базу для пользователя
grant all on database mydb to myuser;
-- Подключаемся под новым пользователем и под ним создаем схему, чтобы он был владельцем
\c myuser mydb
create schema myschema
-- По хорошему, надо создавать всегда отдельную схему (можно назвать так же, как и базу и не использовать public вообще)

-- Можно дополнительно в БД убрать у всех доступ к схеме public
REVOKE ALL ON SCHEMA public FROM public;
-- И можно убрать привелегию вообще на коннект к базе у всех пользователей
REVOKE CONNECT ON DATABASE postgres FROM PUBLIC;
REVOKE CONNECT ON DATABASE mydb FROM PUBLIC; 

-- Для пользователя Read Only:
-- Создаем группу на чтение
CREATE ROLE "MYGORUP_RO";
GRANT CONNECT ON DATABASE mydb TO "MYGORUP_RO";
GRANT USAGE ON SCHEMA myschema TO "MYGORUP_RO";
-- Даём доступ на чтение таблиц для группы
GRANT SELECT ON TABLE "myschema"."table1" TO "MYGORUP_RO";
GRANT SELECT ON TABLE "myschema"."table2" TO "MYGORUP_RO";
-- или
GRANT SELECT ON ALL TABLES IN SCHEMA myschema TO "MYGORUP_RO";
-- Добавляем пользователя в группу
CREATE USER myuser WITH PASSWORD 'pass';
GRANT "MYGORUP_RO" TO myuser;
-- Если хотим, чтобы все последующие объекты были доступны на чтение, меняем привелегии по умолчанию для этой роли:
ALTER DEFAULT PRIVILEGES IN SCHEMA myschema GRANT SELECT ON TABLES TO MYGORUP_RO;
