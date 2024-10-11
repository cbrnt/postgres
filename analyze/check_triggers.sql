SELECT  event_object_table AS table_name ,trigger_name         FROM information_schema.triggers  
WHERE event_object_table ='your_table_name' 
GROUP BY table_name , trigger_name 
ORDER BY table_name ,trigger_name
