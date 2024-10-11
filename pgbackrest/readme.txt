Собрал в кучу все наработки по pgbackrest:
1. Ansible-роль для установки и настроки pgbackrest, а так же создания скриптов бэкапов полных и инкрементальных
2. Сделал инструкцию в формате MD, инструкция предполагалась для восстановления на резервный кластер, соответственно все переменные в ней вырезаны, если будет практика с резервным кластером, то можно прям команды полностью проставить, чтобы инструкцию мог запустить любой админ

Для окончательной работы pgbackrest после установки надо убедиться, что в конфигурации patroni правильная archive_command:
archive_command: pgbackrest --stanza=cluster_name archive-push %p

stanza - некая сущность в pgbackrest для отделения кластеров друг от друга, по сути название папки в s3. Соответственно cluster_name надо заменить на реальное имя кластера

Ниже переменные для pgbackrest, возможно в роли используются другие переменные типа название кластера
#pgbackrest 
pgbackrest_tool: "yes"
stanza_name: sp-pg01-prod

#pgbackrest crontab schedule
pgbackrest_full_run_days: "0-6"    
pgbackrest_incr_run_days: "0-6"
pgbackrest_full_run_hour: "1"
pgbackrest_full_run_minute: "0"
pgbackrest_incr_run_hour: "8,16,23"
pgbackrest_incr_run_minute: "0"


Вот еще могли использоваться такие переменные в роли
#Postgresql settings
pg_user: postgres
pg_group: postgres
pg_data_dest: /var/lib/pgsql/11/data
pg_setup_path: /usr/pgsql-11/bin
default_backend: postgres-patroni
replication_user: repuser
#S3 backup cred 
s3_dbbucket_access_key: "{{ s3_dbbucket_access_key_vault }}"
s3_dbbucket_secret_key: "{{ s3_dbbucket_secret_key_vault }}"
pgbackrest_cipher_password: "{{ pgbackrest_cipher_password_vault }}"
