CREATE TABLE "APPS"."XXHA_ITEM_REGISTRATION_STG" 
   (	"ROW_NUMBER" NUMBER, 
	"COUNTRY_CODE" VARCHAR2(10 BYTE), 
	"ITEM_NUMBER" VARCHAR2(200 BYTE) NOT NULL ENABLE, 
	"REGULATORY_AGENCY" VARCHAR2(200 BYTE), 
	"REGISTRATION_NUM" VARCHAR2(200 BYTE) NOT NULL ENABLE, 
	"ITEM_REG_START_DATE" DATE NOT NULL ENABLE, 
	"ITEM_REG_END_DATE" DATE, 
	"REGISTERED_LEGAL_ENTITY" VARCHAR2(300 BYTE), 
	"MANUFACTURING_SITE" VARCHAR2(300 BYTE), 
	"ITEM_NAME_LOCAL_LANGUAGE" VARCHAR2(300 BYTE), 
	"PACKING_STD_EQUIP_MODEL" VARCHAR2(300 BYTE), 
	"CATEGORY_CODE" VARCHAR2(300 BYTE), 
	"INSERT_ALLOWED" VARCHAR2(2 BYTE), 
	"CREATION_DATE" DATE NOT NULL ENABLE, 
	"CREATED_BY" NUMBER NOT NULL ENABLE, 
	"LAST_UPDATE_DATE" DATE NOT NULL ENABLE, 
	"LAST_UPDATED_BY" NUMBER NOT NULL ENABLE, 
	"REQUEST_ID" NUMBER, 
	"FILE_NAME" VARCHAR2(50 BYTE), 
	"BATCH_ID" NUMBER, 
	"BATCH_SOURCE" VARCHAR2(50 BYTE), 
	"PROCESS_FLAG" VARCHAR2(1 BYTE), 
	"ERROR_MESSAGE" VARCHAR2(500 BYTE), 
	"ITEM_DESCRIPTION" VARCHAR2(250 BYTE), 
	"COUNTRY_CONTROL_ID" NUMBER, 
	"ACTIVE_FLAG" VARCHAR2(5 BYTE)
   )