CREATE OR REPLACE PROCEDURE APPS.xxha_cust_cleanup_loading_prc(err_buf OUT VARCHAR2,ret_code OUT VARCHAR2,p_file_id IN NUMBER)
IS
-- +=====================================================================+
-- | |
-- | $Id$ |
-- | FILENAME : APPS.XXHA_CUST_CLEANUP_LOADING_PRC.prc |
-- | PPROCEDURE NAME : XXHA_CUST_CLEANUP_LOADING_PRC |
-- |Description : Script to insert data required for generating customer open transaction count report |
-- | |
-- |Change History: |
-- |--------------- |
-- |Version Date Author Remarks |
-- +------- ----------- -------------- ---------------------------------+
-- |1.0      12-Jun-2020        Sethu Nathan              Initial Version.
-- +=====================================================================+
    l_file_name BLOB;
    l_clob CLOB;
    l_file_conv  VARCHAR2(32767);
    l_number   NUMBER;    
    l_len  NUMBER;
    l_rec_cnt NUMBER;
    l_start NUMBER := 1;
    l_buffer NUMBER := 32767;
    l_cust_number VARCHAR2(100);
    l_cust_account_id VARCHAR2(100);    
    l_party_id  VARCHAR2(100);
    l_cust_acct_site_id VARCHAR2(100);
    l_party_site_id  VARCHAR2(100);
    l_party_site_number  VARCHAR2(100);
    l_site_use_id  VARCHAR2(100);
    l_site_use_code  VARCHAR2(240);
    l_req_id    NUMBER;
    l_layout BOOLEAN;

BEGIN

    DELETE FROM xxha_cust_cleanup_loading;     

    SELECT file_data
       INTO l_file_name
      FROM fnd_lobs
    WHERE file_id = p_file_id;
     
    --9152890
    
    DBMS_LOB.CREATETEMPORARY(l_clob, TRUE);
    
    FOR i IN 1..CEIL(DBMS_LOB.GETLENGTH(l_file_name) / l_buffer)
    LOOP
    
        l_file_conv := UTL_RAW.CAST_TO_VARCHAR2(DBMS_LOB.SUBSTR(l_file_name, l_buffer, l_start));
        DBMS_LOB.WRITEAPPEND(l_clob, LENGTH(l_file_conv), l_file_conv);
        l_start := l_start + l_buffer;
    
    END LOOP;
--            dbms_output.put_line(l_clob);

    l_rec_cnt := 0;
    LOOP            
        l_cust_number := SUBSTR(l_clob,1,instr(l_clob,',',1)-1);
        l_cust_account_id := SUBSTR(l_clob,(instr(l_clob,',',1,1)+1),(instr(l_clob,',',1,2)-1 - instr(l_clob,',',1,1)));
        l_party_id := SUBSTR(l_clob,(instr(l_clob,',',1,2)+1),(instr(l_clob,',',1,3)-1 - instr(l_clob,',',1,2)));
        l_cust_acct_site_id := SUBSTR(l_clob,(instr(l_clob,',',1,3)+1),(instr(l_clob,',',1,4)-1 - instr(l_clob,',',1,3)));
        l_party_site_id := SUBSTR(l_clob,(instr(l_clob,',',1,4)+1),(instr(l_clob,',',1,5)-1 - instr(l_clob,',',1,4)));
        l_party_site_number := SUBSTR(l_clob,(instr(l_clob,',',1,5)+1),(instr(l_clob,',',1,6)-1 - instr(l_clob,',',1,5)));
        l_site_use_id := SUBSTR(l_clob,(instr(l_clob,',',1,6)+1),(instr(l_clob,',',1,7)-1 - instr(l_clob,',',1,6)));
        l_site_use_code := SUBSTR(l_clob,instr(l_clob,',',1,7)+1,instr(l_clob,CHR(10))-instr(l_clob,',',1,7));
        l_number := instr(l_clob,CHR(10))+1;
        l_clob := SUBSTR(l_clob,l_number);  
        l_len := NVL(LENGTH(l_clob),0);
        IF l_rec_cnt > 0 THEN
            BEGIN
                INSERT INTO xxha_cust_cleanup_loading VALUES(TO_NUMBER(l_cust_number),TO_NUMBER(l_cust_account_id),TO_NUMBER(l_party_id),TO_NUMBER(l_cust_acct_site_id),TO_NUMBER(l_party_site_id),
                                                                                        TO_NUMBER(l_party_site_number),TO_NUMBER(l_site_use_id),l_site_use_code,SYSDATE,fnd_global.user_id);
            EXCEPTION
            WHEN OTHERS THEN
                fnd_file.put_line(fnd_file.log,'Insert Exception : '||l_site_use_id||' , '||SQLERRM);
            END;        
        END IF;
                l_rec_cnt  :=  l_rec_cnt +1;        
        EXIT WHEN  l_len = 0;
    END LOOP;           
        
    FND_GLOBAL.Apps_Initialize(FND_GLOBAL.USER_ID, FND_GLOBAL.RESP_ID, FND_GLOBAL.RESP_APPL_ID);
    
    l_layout := FND_REQUEST.ADD_LAYOUT('HAEMO'
                                                                ,'XXHADUPCUSEXT'
                                                                ,'en'
                                                                ,'US'
                                                                ,'EXCEL');
    
    l_req_id:=   FND_REQUEST.SUBMIT_REQUEST(
                                            'HAEMO',
                                            'XXHADUPCUSEXT',
                                            '',
                                            '',
                                            FALSE);

    COMMIT;
EXCEPTION
WHEN OTHERS THEN
    fnd_file.put_line(fnd_file.log,'Exception : '||SQLERRM);   
END;
/

