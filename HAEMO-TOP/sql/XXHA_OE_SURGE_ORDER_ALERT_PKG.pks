CREATE OR REPLACE PACKAGE APPS.xxha_oe_surge_order_alert_pkg
IS

  /*****************************************************************************************
  * Name/Purpose : XXHA_OE_SURGE_ORDER_ALERT_PKG                                            *
  * Description  : creates                                                                 *
  *                package body XXHA_OE_SURGE_ORDER_ALERT_PKG                                   *
  *                for sending emails for surge order requirement                 *
  * Date            Author               Description                                       *
  * -----------     -----------------    ---------------                                   *
  * 29-APR-2020     Sethu Nathan       Initial Creation                                 *
  ***************************************************************************************/
  
type array is table of varchar2(1000);
l_mail_conn UTL_SMTP.connection;

  PROCEDURE process_orders( x_err_buf           OUT VARCHAR2,
                                             x_ret_code          OUT VARCHAR2);
  PROCEDURE send_mail_html( P_MAIL_HOST IN VARCHAR2,
                                                      P_FROM      IN VARCHAR2,
                                                      P_TO        IN VARCHAR2,
                                                      P_SUBJECT   IN VARCHAR2,
                                                      P_MESSAGE   IN VARCHAR2 );
  FUNCTION mul_email( p_string in varchar2,
                                        p_recipients in array )
                         return varchar2;                                  
  PROCEDURE delete_temp_table;                                   
END;
/

