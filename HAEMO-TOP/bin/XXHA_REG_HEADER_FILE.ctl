--+============================================================================+
--|                                                                            |
--|    File Name  : XXHA_REG_HEADER_FILE.ctl                                   |
--|                                                                            |
--|    Description: Control file for REG file Item additional                  |
--|                 upload                                          		   |
--|                                                                            |
--|    Revision History:                                                        |
--|                                                                            |
--|  Ver  Date       Name            Revision Description                      |
--|  ===  =========  =============   ======================================    |
--|  1.0  25-FEB-20  Praduman         Created the program                      |
--|                                                                            |
--|                                                                            |
--|   Usage : sqlldr apps/<appspwd> control=XXHA_REG_HEADER_FILE.ctl data=<>   |
--|============================================================================+

OPTIONS (BINDSIZE=100000,SKIP=1,ROWS=1, ERRORS=100000, SILENT=FEEDBACK)
LOAD DATA INFILE 'PRADUMAN_XXHA_REG_HEADER_FLAT_FILE.csv' 
APPEND INTO TABLE XXHA_REG_COUNTRY_CONTROL_STG
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' TRAILING NULLCOLS
( 
	COUNTRY_CONTROL_ID ,
	COUNTRY_CODE  ,  
	COUNTRY      ,
	STATE       ,
	PROVINCE    , 
	SITE_CONTROL_TYPE    ,  
	ITEM_CONTROL_TYPE        ,  
	BUSINESS_LICENSE_REQUIRED   , 
	REGULATORY_LICENSE_REQUIRED  , 
	APPROVED_PRODUCT_LIST       , 
	REGULATORY_NOTIFICATION     ,
	CUSTOMER_SERVICE_NOTIFICATION ,
	REGULATORY_REGISTRATION_REQ   , 
	ENABLED_FLAG,
	INSERT_ALLOWED,
	EXPIRING_NOTIFICATION_DATE,  	 
,   created_by                           "fnd_global.user_id"
,   creation_date                        sysdate
,   last_updated_by                      "fnd_global.user_id"
,   last_update_date                     sysdate
,   process_flag                         CONSTANT "N"
,   batch_source                         CONSTANT "REG"
,   file_name  CONSTANT "XXHA_REG_HEADER_FLAT_FILE" )