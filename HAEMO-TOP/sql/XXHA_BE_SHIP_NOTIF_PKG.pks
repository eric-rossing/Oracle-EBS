CREATE OR REPLACE PACKAGE APPS."XXHA_BE_SHIP_NOTIF_PKG"
  /*******************************************************************************************************
  * Object Name: XXHA_BE_SHIP_NOTIF_PKG
  * Object Type: PACKAGE
  *
  * Description: This Package will be used in shipconfirm business event plsql
  *
  * Modification Log:
  * Developer          Date                 Description
  *-----------------   ------------------   ------------------------------------------------
  * Apps Associates    16-JAN-2015          Initial object creation.
  *
  *
  *******************************************************************************************************/
AS
g_delivery_id number;
g_to_email varchar2(123);
g_to_fax varchar2(123);
type array is table of varchar2(1000);
--to_array array;
l_mail_conn UTL_SMTP.connection;
FUNCTION XXHA_BE_SHIP_NOTIF_FUNC(
    P_SUBSCRIPTION_GUID IN RAW,
    P_EVENT             IN OUT NOCOPY WF_EVENT_T )
  RETURN VARCHAR2;

PROCEDURE XXHA_BE_SHIP_NOTIF_PRC(
    P IN CLOB );

PROCEDURE XXHA_GET_MAIL_BODY(
    P_DELIVERY_ID IN NUMBER );

procedure XXHA_COC_PDF_PRC(
	p_delivery_id IN number,
	p_order_header_id IN NUMBER,
	p_item_no 	in varchar2,
	p_lot_no 	in varchar2,
	p_template 	in varchar2 --'mixed'
	--P_CLOB 		OUT CLOB,
	--P_BLOB 		OUT BLOB
	);

FUNCTION xxha_c2b_64(
	c IN CLOB )
   RETURN BLOB;


procedure xxha_send_mail_attach_pdfs (p_to          in array default array(),
                                       p_from        IN VARCHAR2,
                                       p_subject     IN VARCHAR2,
                                       p_text_msg    IN VARCHAR2 DEFAULT NULL,
--                                       p_attach_name IN VARCHAR2 DEFAULT NULL,
                                       p_attach_mime IN VARCHAR2 DEFAULT NULL,
--                                       p_attach_blob IN BLOB DEFAULT NULL,
                                       p_smtp_host   IN VARCHAR2,
                                       p_smtp_port   IN NUMBER DEFAULT 25,
									   p_order_header_id IN NUMBER,
									   p_delivery_id IN NUMBER);


PROCEDURE xxha_submit_packslip_report (p_delivery_id in number, p_directory_path out varchar2, p_file_name out varchar2);

PROCEDURE xxha_get_packslip_pdf( p_directory VARCHAR2, p_file_name VARCHAR2, p_order_header_id number, p_delivery_id number);

 function address_email( p_string in varchar2,
                            p_recipients in array ) return varchar2;

END XXHA_BE_SHIP_NOTIF_PKG;
/

