SELECT pg_terminate_backend(psa.pid) FROM pg_stat_activity psa WHERE psa.datname = 'template1';