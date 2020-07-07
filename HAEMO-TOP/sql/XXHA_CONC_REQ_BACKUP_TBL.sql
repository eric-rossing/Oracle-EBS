CREATE TABLE HAEMO.XXHA_FND_CONC_REQ_BACKUP_TBL
(
  CONCURRENT_PROGRAM_NAME  VARCHAR2(250 BYTE),
  ACTUAL_COMPLETION_DATE   DATE,
  NO_OF_REQUESTS           NUMBER,
  CREATED_BY               NUMBER,
  CREATION_DATE            DATE,
  LAST_UPDATED_BY          NUMBER,
  LAST_UPDATE_DATE         DATE,
  REQUEST_ID               NUMBER
);

create or replace synonym xxha_fnd_conc_req_backup_tbl for haemo.xxha_fnd_conc_req_backup_tbl;