#!/bin/bash
pg_user=khodus
for i in $(psql -U $pg_user -d postgres -c "\l" | grep UTF8 | egrep -v 'postgres|template' | awk '{print $1}')
    do  
        psql -U $pg_user -d $i -c "create extension pg_stat_statements; create extension pgstattuple"
    done