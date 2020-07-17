--+============================================================================+
--|                                                                            |
--|    File Name  : XXHA_REG_ITEM_INC_FILE.ctl                                   |
--|                                                                            |
--|    Description: Control file for REG file Item additional                  |
--|                 upload                                          		   |
--|                                                                            |
--|    Revision History:                                                        |
--|                                                                            |
--|  Ver  Date       Name            Revision Description                      |
--|  ===  =========  =============   ======================================    |
--|  1.0  16-MAR-20  Praduman         Created the program                      |
--|                                                                            |
--|                                                                            |
--|   Usage : sqlldr apps/<appspwd> control=XXHA_REG_ITEM_INC_FILE.ctl data=<>   |
--|============================================================================+

OPTIONS (BINDSIZE=100000,SKIP=1,ROWS=1, ERRORS=100000, SILENT=FEEDBACK)
LOAD DATA INFILE 'PRADUMAN_XXHA_REG_ITEM_INC_FLAT_FILE.csv' 
APPEND INTO TABLE XXHA_ITEM_REGISTRATION_STG
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' TRAILING NULLCOLS
( 
	ROW_NUMBER ,
	COUNTRY_CODE  ,  
	ITEM_NUMBER, 
    ITEM_DESCRIPTION   , 
    REGULATORY_AGENCY  , 
    REGISTRATION_NUM    , 
    ITEM_REG_START_DATE  ,          
    ITEM_REG_END_DATE   ,                 
    REGISTERED_LEGAL_ENTITY  , 
    MANUFACTURING_SITE    , 
    ITEM_NAME_LOCAL_LANGUAGE   , 
    PACKING_STD_EQUIP_MODEL   , 
    CATEGORY_CODE     ,  
    INSERT_ALLOWED 	  	 
,   created_by                           "fnd_global.user_id"
,   creation_date                        sysdate
,   last_updated_by                      "fnd_global.user_id"
,   last_update_date                     sysdate
,   process_flag                         CONSTANT "N"
,   batch_source                         CONSTANT "REG"
,   file_name  CONSTANT "XXHA_REG_ITEMINC_FLAT_FILE" )