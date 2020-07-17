create or replace PACKAGE XXHA_REG_COUNTRY_DATA_PKG
 AS 
 /*
|=============================================================================================+
|                 HEMONETICS																  |
|=============================================================================================|
    * Developer      :Praduman Singh
    * Client/Project :HEMONETICS
    * Database       :
    * Date           :27-Jan-2020
    * Description    : This package contains the logic for bulk upload for Regulatory
					   Header And Lines custom tables
    * Issue          :
    * Version Control:
    * Author        Version             Date               Change
    * -------       -------            --------          -------
    * Praduman        0.0              09-Mar-2020         Initail Veriosn
|=============================================================================================*/

/* GLOBAL Variable*/
g_batch_id  number;
g_user_id number := FND_GLOBAL.USER_ID;
G_LOGIN_ID number := FND_GLOBAL.LOGIN_ID;
g_conq_prog_id number := FND_GLOBAL.conc_program_id;

type  g_tab_rec_data  IS TABLE OF xxha_reg_country_control_stg%ROWTYPE
							INDEX BY PLS_INTEGER;

type  g_tab_iteminc_data  IS TABLE OF xxha_item_registration_stg%ROWTYPE
							INDEX BY PLS_INTEGER;
PROCEDURE main_proc (
	p_user_id      IN    NUMBER,
	p_request_id   IN    NUMBER,
	p_file_name    IN    VARCHAR2,
	p_source       IN    VARCHAR2,
	p_batch_id     IN    NUMBER
);
PROCEDURE Inclusion_main_proc(
	p_user_id      IN    NUMBER,
	p_request_id   IN    NUMBER,
	p_file_name    IN    VARCHAR2,
	p_source       IN    VARCHAR2,
	p_batch_id     IN    NUMBER,
  p_country_code     IN   VARCHAR2     --praduman
);
PROCEDURE Inclusion_main_proc_country(
	p_user_id      IN    NUMBER,
	p_request_id   IN    NUMBER,
	p_file_name    IN    VARCHAR2,
	p_source       IN    VARCHAR2,
	p_batch_id     IN    NUMBER
);
PROCEDURE validate_data(p_batch_id  IN NUMBER);
PROCEDURE validate_Item_inclusion_data(p_batch_id  IN NUMBER,
                                      p_country_code IN VARCHAR2);    --praduman
PROCEDURE xxha_log_display (
        p_batch_id IN varchar2
    ); 
PROCEDURE XXHA_LOG_DISPLAY_INCLUSION(p_batch_id IN varchar2);
END;