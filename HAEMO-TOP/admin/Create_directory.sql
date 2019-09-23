DECLARE
lv_statement varchar2(1000);
lv_database varchar2(50);
lv_path varchar2(500);
BEGIN
   BEGIN
      SELECT NAME INTO lv_database FROM v$database;
   EXCEPTION
   WHEN NO_DATA_FOUND THEN
      dbms_output.put_line('NO Values for database found');
   WHEN OTHERS THEN
       dbms_output.put_line('Problem in fetching database name');
   END;
   dbms_output.put_line('Database Name : '||lv_database);
   lv_path :='/interface/'||lv_database||'/fin/LA';
   IF lv_database IS NOT NULL THEN
      lv_statement := q'[CREATE OR REPLACE DIRECTORY XXHA_LA_INTERFACE AS ']'||lv_path||q'[;']';
      dbms_output.put_line (lv_statement);
      execute immediate lv_statement;
   ELSE
       dbms_output.put_line('Directory is not created');
   END IF;
EXCEPTION
WHEN OTHERS THEN 
    dbms_output.put_line('Error in anonymous block'||SQLCODE||' -ERROR- '||SQLERRM);
END;