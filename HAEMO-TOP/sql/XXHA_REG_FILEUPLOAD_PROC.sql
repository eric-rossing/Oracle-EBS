create or replace PROCEDURE XXHA_REG_FILEUPLOAD_PROC
   (
    p_file_id IN NUMBER,
    p_file_dir IN VARCHAR2,
    o_filename OUT VARCHAR2 ,
    o_error_msg OUT VARCHAR2 
    )
IS
  l_file UTL_FILE.FILE_TYPE;
  l_buffer RAW(32767);
  l_amount BINARY_INTEGER := 32767;
  l_pos INTEGER           := 1;
  L_BLOB BLOB ;
  L_CLOB CLOB;
  L_BLOB_LEN  INTEGER;
  l_file_dir  VARCHAR2(100);
  l_file_name VARCHAR2(1000);
  V1 VARCHAR2(32767);
BEGIN
  l_file_dir := p_file_dir;
  SELECT file_data,
    file_name
  INTO l_blob,
    l_file_name
  FROM fnd_lobs
  WHERE file_id = p_file_id;
  l_blob_len   := DBMS_LOB.getlength(l_blob);
  BEGIN
    dbms_output.put_line('START'); 
    l_file := UTL_FILE.fopen ('XXHA_REG_COUNTRY_INBOUND',l_file_name,'W',32767);
   -- l_file := UTL_FILE.fopen (l_file_dir,l_file_name,'W',32767);
   -- UTL_FILE.GET_LINE(l_file,V1,32767);
      dbms_output.put_line('EXIST');
  EXCEPTION
  WHEN UTL_FILE.INVALID_PATH THEN
    dbms_output.put_line('File Open :Invalid utl file path');
    UTL_FILE.FCLOSE_ALL;
  WHEN UTL_FILE.INVALID_MODE THEN
    dbms_output.put_line('File Open :Invalid utl file mode');
    UTL_FILE.FCLOSE_ALL;
  WHEN UTL_FILE.INVALID_FILEHANDLE THEN
    dbms_output.put_line('File Open :Invalid utl file handle');
    UTL_FILE.FCLOSE_ALL;
  WHEN UTL_FILE.INVALID_OPERATION THEN
    dbms_output.put_line('File Open :Invalid utl file Operation');
    UTL_FILE.FCLOSE_ALL;
  WHEN UTL_FILE.INTERNAL_ERROR THEN
    dbms_output.put_line('File Open :Int error');
    UTL_FILE.FCLOSE_ALL;
  WHEN UTL_FILE.WRITE_ERROR THEN
    dbms_output.put_line('File Open :WRITE_ERROR');
    UTL_FILE.FCLOSE_ALL;
  WHEN OTHERS THEN
    dbms_output.put_line('File Open :Other, Error in opening the file : ||l_file_name');
    UTL_FILE.FCLOSE_ALL;
  END;
  WHILE l_pos <l_blob_len
  LOOP
    DBMS_LOB.READ(l_blob,l_amount,l_pos,l_buffer);
    UTL_FILE.put(l_file,REPLACE(utl_raw.cast_to_varchar2(l_buffer),CHR(13),NULL));
    UTL_FILE.fflush(l_file);
    l_pos := l_pos+l_amount;
  END LOOP;
  --close the file
  UTL_FILE.fclose(l_file);
  o_filename  := l_file_name;
  o_error_msg := NULL;
   dbms_output.put_line('l_file_name1'||l_file_name);
EXCEPTION
WHEN OTHERS THEN
  IF UTL_FILE.is_open(l_file) THEN
    UTL_FILE.fclose(l_file);
  END IF;
  dbms_output.put_line('l_file_name'||l_file_name);
  o_filename  := NULL;
  o_error_msg := SQLERRM;
  RAISE;
END ;