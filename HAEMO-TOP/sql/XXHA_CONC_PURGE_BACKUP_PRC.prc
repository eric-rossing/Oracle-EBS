CREATE OR REPLACE PROCEDURE APPS.XXHA_FND_CONC_PURGE_BACKUP_PRC(x_errbuf OUT VARCHAR,x_retcode OUT VARCHAR2)
IS

-- +=====================================================================+
-- | |
-- | $Id$ |
-- | FILENAME : XXHA_FND_CONC_PURGE_BACKUP_PRC.pkb |
-- | PACKAGE NAME : APPS.XXHA_FND_CONC_PURGE_BACKUP_PRC |
-- |Description : Script to create procedure to take backup of Concurrent Request before purging |
-- | |
-- |Change History: |
-- |--------------- |
-- |Version Date         Author           Remarks |
-- +------- ----       --------------  ----------------------------------------+
-- |1.0     06-Jul-2020 Sethu Nathan    Initial Version.
-- +=====================================================================+
BEGIN
        INSERT INTO xxha_fnd_conc_req_backup_tbl        
        SELECT fcp.user_concurrent_program_name ,MAX(fcr.actual_completion_date) actual_completion_date,COUNT(1) no_of_requests,fnd_global.user_id,SYSDATE,fnd_global.user_id,SYSDATE,FND_GLOBAL.CONC_REQUEST_ID
           FROM fnd_concurrent_requests fcr,fnd_concurrent_programs_tl fcp
         WHERE fcr.concurrent_program_id = fcp.concurrent_program_id
             AND fcp.language = 'US'
             AND (UPPER(fcp.user_concurrent_program_name) LIKE 'XX%' OR UPPER(fcp.user_concurrent_program_name) LIKE 'HAE%')
             AND fcr.actual_completion_date <= SYSDATE-30
        GROUP BY fcp.user_concurrent_program_name
        ORDER BY user_concurrent_program_name;
        
        COMMIT;
END;
/

