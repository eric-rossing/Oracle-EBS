create or replace PACKAGE BODY      "XXHA_CHINA_REG_ALERT_PKG"
  /*****************************************************************************************
  * Name/Purpose : XXHA_CHINA_REG_ALERT_PKG                                                *
  * Description  : creates                                                                 *
  *                package body XXHA_CHINA_REG_ALERT_PKG                                   *
  *                for sending emails for expiring Item and customer                       *
  *                registration details.
  * Date            Author               Description                                       *
  * -----------     -----------------    ---------------                                   *
  * 12-APR-2017     Apps Associates       Initial Creation                                 *
  * 08-MAY-2017     Vijay Medikonda       Added additional email address to dist list      *
  * 20-JUN-2017     Vijay Medikonda       Modified to exclude expired items, customers     ;*
  * 07-JAN-2019     Sethu Nathan          Modified to send expiring alert for multiple countries.Incident INC0126046 *
  * 03-JAN-2020		  Praduman Singh		    Modified smtp IP logic
  * 20-JUN-2020     Praduman Singh        Modified to Regulatory Compience project         *
  ***************************************************************************************/
AS
  PROCEDURE item_cust_reg_detail(
      Ret_Code OUT NUMBER,
      Err_Buf OUT VARCHAR2)
  IS
    CURSOR country_ctrl_cur
    IS
     SELECT country_control_id,country_code,country,
            expiring_notification_date    
       FROM APPS.XXHA_REG_COUNTRY_CONTROL
     WHERE enabled_flag ='Yes'
     AND  expiring_notification_date IS NOT NULL;   ---   Added to Regulatory Compience project 

    CURSOR item_reg_cur(p_country_control_id NUMBER,p_expiring_days NUMBER)
    IS
      SELECT A.COUNTRY_CODE,
        B.ITEM_NUMBER,
        B.ITEM_DESCRIPTION,
        B.REGISTRATION_NUM,
        B.ITEM_REG_START_DATE,
        B.ITEM_REG_END_DATE
      FROM apps.XXHA_REG_COUNTRY_CONTROL a,
        apps.XXHA_ITEM_REGISTRATION b
      WHERE a.country_control_id = b.country_control_id
      AND A.COUNTRY_CONTROL_ID   = p_country_control_id --1000
     -- AND B.ITEM_REG_END_DATE    < SYSDATE + 180p          Commented by Praduman Singh
      AND B.ITEM_REG_END_DATE    < SYSDATE + p_expiring_days  --Added by praduman Singh
      AND B.ITEM_REG_END_DATE    > SYSDATE
      AND NOT EXISTS
        (SELECT 1
        FROM APPS.XXHA_REG_COUNTRY_CONTROL AA,
          APPS.XXHA_ITEM_REGISTRATION BB
        WHERE AA.COUNTRY_CONTROL_ID = BB.COUNTRY_CONTROL_ID
        AND AA.COUNTRY_CONTROL_ID   = p_country_control_id --1000
        AND BB.ITEM_NUMBER          = B.ITEM_NUMBER
          --  and bb.item_description = b.item_description
        AND bb.registration_num    = b.registration_num
        AND BB.ITEM_REG_START_DATE > B.ITEM_REG_END_DATE
       -- AND (BB.ITEM_REG_END_DATE  > SYSDATE + 180    Commented by Praduman Singh
        AND (BB.ITEM_REG_END_DATE  > SYSDATE + p_expiring_days  --Added by praduman Singh
        OR BB.ITEM_REG_END_DATE   IS NULL)
        )
    AND B.ITEM_REG_END_DATE IN
      (SELECT MAX(B1.ITEM_REG_END_DATE)
      FROM APPS.XXHA_REG_COUNTRY_CONTROL A1,
        APPS.XXHA_ITEM_REGISTRATION B1
      WHERE A1.COUNTRY_CONTROL_ID = B1.COUNTRY_CONTROL_ID
      AND A1.COUNTRY_CONTROL_ID   = p_country_control_id --1000
      AND B1.ITEM_NUMBER          = B.ITEM_NUMBER
      AND b1.registration_num     = b.registration_num
     -- AND B1.ITEM_REG_END_DATE    < SYSDATE + 180    Commented by Praduman Singh
     AND B1.ITEM_REG_END_DATE    < SYSDATE + p_expiring_days  --Added by praduman Singh
      GROUP BY B1.ITEM_NUMBER
      );

    CURSOR cust_reg_cur(p_country_control_id NUMBER,p_expiring_days NUMBER)
    IS
      SELECT A.COUNTRY_CODE,
        B.ACCOUNT_NUMBER,
        B.ACCOUNT_NAME,
        B.CONTROL_TYPE,
        B.LICENSE_NO,
        B.CUST_REG_START_DATE,
        B.CUST_REG_END_DATE
      FROM apps.XXHA_REG_COUNTRY_CONTROL a,
        apps.XXHA_CUSTOMER_REG_CONTROL b
      WHERE a.country_control_id = b.country_control_id
      AND B.COUNTRY_CONTROL_ID   = p_country_control_id --1000
     -- AND B.CUST_REG_END_DATE    < SYSDATE + 180     Commented by praduman singh 
      AND B.CUST_REG_END_DATE    < SYSDATE + p_expiring_days   --Added by praduman singh 
      AND b.cust_reg_end_date    > sysdate
        --and B.ACCOUNT_NUMBER = 23528
      AND NOT EXISTS
        (SELECT 1
        FROM APPS.XXHA_REG_COUNTRY_CONTROL AA,
          APPS.XXHA_CUSTOMER_REG_CONTROL BB
        WHERE AA.COUNTRY_CONTROL_ID = BB.COUNTRY_CONTROL_ID
        AND BB.COUNTRY_CONTROL_ID   = p_country_control_id --1000
        AND BB.ACCOUNT_NUMBER       = B.ACCOUNT_NUMBER
        AND BB.CONTROL_TYPE         = B.CONTROL_TYPE
          --AND BB.CUST_REG_START_DATE > B.CUST_REG_END_DATE
        --AND (BB.CUST_REG_END_DATE > SYSDATE + 180     Commented by praduman singh 
        AND (BB.CUST_REG_END_DATE    > SYSDATE + p_expiring_days   --Added by praduman singh  
        OR BB.CUST_REG_END_DATE  IS NULL)
        )
    AND B.CUST_REG_END_DATE IN
      (SELECT MAX(B1.CUST_REG_END_DATE)
      FROM APPS.XXHA_REG_COUNTRY_CONTROL A1,
        APPS.XXHA_CUSTOMER_REG_CONTROL B1
      WHERE A1.COUNTRY_CONTROL_ID = B1.COUNTRY_CONTROL_ID
      AND B1.COUNTRY_CONTROL_ID   = p_country_control_id--1000
      AND B1.ACCOUNT_NUMBER       = B.ACCOUNT_NUMBER
      AND b1.CONTROL_TYPE         = B.CONTROL_TYPE
      --AND B1.CUST_REG_END_DATE    < SYSDATE + 180   Commented by praduman singh 
      AND B1.CUST_REG_END_DATE    < SYSDATE + p_expiring_days   --Added by praduman singh  
      GROUP BY B1.ACCOUNT_NUMBER
      )
    ORDER BY b.account_number ;
    l_count    NUMBER         := 0;
    l_count1   NUMBER         := 0;
    l_to_email VARCHAR2(1000) := NULL;--'ChinaCommercialTeam@Haemonetics.com,Complaint.CHINA@haemonetics.com,gina.cheah@haemonetics.com,stacey.kong@haemonetics.com,ff.khaw@haemonetics.com,thomas.mchugh@haemonetics.com,sisi.wang@haemonetics.com,CNO.Logistics@Haemonetics.com';
    l_message LONG            := NULL;
    l_message1 LONG           := NULL;
    l_msg LONG                := NULL;
    L_MSG1 LONG               := NULL;
    L_SUBJECT   VARCHAR2(2000);
    l_exception VARCHAR2(2000);
	l_smtp_host    VARCHAR2(100);  --Added by Praduman
  BEGIN
    FOR ccid IN country_ctrl_cur
    LOOP
        l_count := 0;
        l_message1 := NULL;
        l_count1 := 0;
        l_msg1 := NULL;
        l_subject := NULL;
        l_message := NULL;
        l_msg := NULL;

        FOR rec IN item_reg_cur(ccid.country_control_id,ccid.expiring_notification_date)   /*Added  ccid.expiring_notification_date by Praduman Start  */
        LOOP
          DBMS_OUTPUT.put_line('l_count: '||l_count);
          l_count    := l_count+1;
          l_message1 := l_message1||chr(13)||'<tr align="right"><td>'||rec.COUNTRY_CODE||'</td><td>'||rec.ITEM_NUMBER||'</td><td>'||rec.ITEM_DESCRIPTION||'</td><td>'||rec.REGISTRATION_NUM||'</td><td>'||rec.ITEM_REG_START_DATE||'</td><td>'||rec.ITEM_REG_END_DATE||'</td></tr>'||chr(13);
        END LOOP;
        FOR rec1 IN cust_reg_cur(ccid.country_control_id,ccid.expiring_notification_date)   /*Added  ccid.expiring_notification_date by Praduman Start  */
        LOOP
          DBMS_OUTPUT.put_line('l_count1: '||l_count1);
          l_count1 := l_count1+1;
          l_msg1   := l_msg1||chr(13)||'<tr align="right"><td>'||rec1.COUNTRY_CODE||'</td><td>'||rec1.account_number||'</td><td>'||rec1.account_name||'</td><td>'||rec1.control_type||'</td><td>'||rec1.license_no||'</td><td>'||rec1.cust_reg_start_date||'</td><td>'||rec1.cust_reg_end_date||'</td></tr>'||chr(13);
        END LOOP;   
    FND_FILE.PUT_LINE(FND_FILE.LOG, 'l_count - '||l_count);
    FND_FILE.PUT_LINE(FND_FILE.LOG, 'l_count1 - '||l_count1);
    IF l_count > 0 and ccid.expiring_notification_date IS NOT NULL THEN
      l_to_email := NULL;
      FOR mail IN   (SELECT fll.description
                              FROM fnd_lookup_values fll
                             WHERE     fll.lookup_type = 'XXHA_REGULATORY_MAIL_ID'
                                  AND fll.language = 'US' 
                                  AND fll.tag = ccid.country_code
                                  AND TRUNC(SYSDATE) BETWEEN fll.start_date_active AND NVL(fll.end_date_active,'01-JAN-4879')
								  AND fll.enabled_flag = 'Y')
      LOOP
        l_to_email := mail.description||','||l_to_email;
      END LOOP;                            

      BEGIN
	      /*Added  below code by Praduman Start  */
      BEGIN
         SELECT xxha_fnd_util_pkg.get_ip_address
           INTO l_smtp_host
           FROM dual;           
      EXCEPTION
      WHEN OTHERS THEN
          fnd_file.put_line (fnd_file.LOG,'Exception while getting ip Address:'|| SQLERRM);
      END;
	   /*Added code by Praduman End  */
        --  Sending email if there are item registration details to be expired within 6 months;
        l_subject := ccid.country||' Regulatory Expiring Item Registration Alert';
       -- l_message := l_message || 'Below are the Item Registration details expiring within 6 months: '||chr(13)||chr(13);  --Commented by Praduman Singh
        l_message := l_message || 'Below are the Item Registration details expiring within '||ccid.expiring_notification_date||' days'||chr(13)||chr(13); 
        l_message := l_message || '          '||chr(13);
        l_message := l_message || '<table border="1"><tr align="right"><th>CountryCode#</th>'||'<th>Item#</th>'||'<th>Item Description</th>'||'<th>Registration Number</th>'||'<th>Start Date</th>'||'<th>End Date</th></tr>'||chr(13);
        l_message := l_message || l_message1||'</table>'||chr(13);
        l_message := l_message || '          '||chr(13);
        l_message := l_message || '          '||chr(13)||chr(13)||chr(13);
        l_message := l_message || 'Thank you.';
        XXHA_SEND_MAIL_HTML(P_MAIL_HOST => l_smtp_host --'smtp-bo.haemo.net'  --Modified by Praduman
		, p_from => 'ebsmailer-haeprd@haemonetics.com', p_to => l_to_email, P_SUBJECT => l_subject, p_message => l_message);
      EXCEPTION
      WHEN OTHERS THEN
        l_exception := NULL ;
        l_exception := sqlerrm;
      END;
    END IF;
    IF l_count1 > 0 AND ccid.expiring_notification_date IS NOT NULL THEN
      l_to_email := NULL;
      FOR mail IN   (SELECT fll.description
                              FROM fnd_lookup_values fll
                             WHERE     fll.lookup_type = 'XXHA_REGULATORY_MAIL_ID'
                                  AND fll.language = 'US' 
                                  AND fll.tag = ccid.country_code
                                  AND TRUNC(SYSDATE) BETWEEN fll.start_date_active AND NVL(fll.end_date_active,'01-JAN-4879')
								  AND fll.enabled_flag = 'Y')
      LOOP
        l_to_email := mail.description||','||l_to_email;
      END LOOP;              

      BEGIN
        --  Sending email if there are item registration details to be expired within 6 months;
        l_subject := ccid.country||' Regulatory Expiring Customer Registration Alert';
        l_msg     := l_msg || 'Below are the Customer Registration details expiring within 6 months'||chr(13)||chr(13);    --Commented by Praduman Singh
       -- l_msg     := l_msg || 'Below are the Customer Registration details expiring within'||ccid.expiring_notification_date||'days'||chr(13)||chr(13);
        l_msg     := l_msg || '          '||chr(13);
        l_msg     := l_msg || '<table border="1"><tr align="right"><th>CountryCode#</th>'||'<th>Account Number</th>'||'<th>Account Name</th>'||'<th>Control Type</th>'||'<th>License Number</th>'||'<th>Start Date</th>'||'<th>End Date</th></tr>'||chr(13);
        l_msg     := l_msg || l_msg1||'</table>'||chr(13);
        l_msg     := l_msg || '          '||chr(13);
        l_msg     := l_msg || '          '||chr(13)||chr(13)||chr(13);
        l_msg     := l_msg || 'Thank you.';
        XXHA_SEND_MAIL_HTML(P_MAIL_HOST => l_smtp_host --'smtp-bo.haemo.net' --Modified by Praduman
		, p_from => 'ebsmailer-haeprd@haemonetics.com', p_to => l_to_email, P_SUBJECT => l_subject, p_message => l_msg);
      EXCEPTION
      WHEN OTHERS THEN
        l_exception := NULL ;
        l_exception := sqlerrm;
      END;
    END IF;
    END LOOP;    
  END;
  PROCEDURE XXHA_SEND_MAIL_HTML(
      P_MAIL_HOST IN VARCHAR2,
      P_FROM      IN VARCHAR2,
      P_TO        IN VARCHAR2,
      P_SUBJECT   IN VARCHAR2,
      P_MESSAGE   IN VARCHAR2 )
    /*******************************************************************************************************
    * Object Name: XXHA_SEND_MAIL_HTML
    * Object Type: PROCEDURE
    *
    * Description: This Procedure used to send email
    *
    * Modification Log:
    * Developer          Date                 Description
    *-----------------   ------------------   ------------------------------------------------
    * Ohmesh Suraj       15-FEB-2017     TEXT/ HTML Body
    *
    *******************************************************************************************************/
  AS
    --This is a simple procedure to send email from plsql. Currently it is not working when invoked from DEV
    --Need to check with DBA, if all mail setups are in place.
    --L_MAIL_CONN UTL_SMTP.CONNECTION;
    crlf              VARCHAR2 (2) := CHR (13) || CHR (10);
    mesg              VARCHAR2 (32767);
    boundary          CONSTANT VARCHAR2 (256) := 'CES.Boundary.DACA587499938898';
    l_boundary        VARCHAR2(50)            := '----=*#abc1234321cba#*=';
    l_prod_flag       VARCHAR2(100);
    l_test_email_addr VARCHAR2(100);
    l_concat_to       VARCHAR2(2000);
    l_concat_rows     NUMBER;
    l_to LONG;
    to_array array;
    raw_data RAW (32767);
  BEGIN
    L_MAIL_CONN := UTL_SMTP.OPEN_CONNECTION(P_MAIL_HOST, 25);
    UTL_SMTP.HELO(L_MAIL_CONN, P_MAIL_HOST);
    UTL_SMTP.MAIL(L_MAIL_CONN, P_FROM);
    SELECT XXHA_PROD_DB,
      --XXHA_GET_TEST_EMAIL_ADDRESS Modified by Praduman
	    XXHA_FND_UTIL_PKG.get_recipients  -- Added by Praduman
    INTO l_prod_flag,
      l_test_email_addr
    FROM DUAL;
    IF ( l_prod_flag = 'N') THEN
      l_concat_to   := l_test_email_addr||',eBSMailer-Test@Haemonetics.com';
    ELSE
      DBMS_OUTPUT.PUT_LINE('Prod Flag:'||l_prod_flag);
      l_concat_to := P_TO;
    END IF;
    SELECT REGEXP_COUNT(l_concat_to, ',',1, 'i')+1
    INTO l_concat_rows
    FROM DUAL;
    to_array := array();
    to_array.EXTEND(l_concat_rows);
    BEGIN
      FOR rec_to IN
      (SELECT level                                 AS row_no,
        REGEXP_SUBSTR(CONCAT_EMAIL,'[^,]+',1,LEVEL) AS email_to
      FROM
        (SELECT l_concat_to AS CONCAT_EMAIL FROM DUAL
        )
        CONNECT BY regexp_substr(concat_email,'[^,]+',1,level) IS NOT NULL
      )
      LOOP
        to_array(rec_to.row_no) := rec_to.email_to;
        DBMS_OUTPUT.PUT_LINE('rec_to:'||rec_to.row_no||'. VAL:'||rec_to.email_to);
      END LOOP;
      l_to := xxha_mul_email( 'To: ', to_array );
    END;
    --UTL_SMTP.RCPT(L_MAIL_CONN, l_to);--test
    UTL_SMTP.OPEN_DATA(L_MAIL_CONN);
    --  mesg        := 'Date: ' || TO_CHAR (SYSDATE, 'dd Mon yy hh24:mi:ss') || crlf || 'From: ' || P_FROM || crlf || 'Subject: ' || P_subject || crlf || 'To: ' || P_TO || crlf;
    --  mesg := mesg || 'Mime-Version: 1.0' || crlf || 'Content-Type: multipart/mixed; boundary="' || l_boundary || '"' || crlf || crlf ;--|| 'This is a Mime message, which your current mail reader may not' || crlf || 'understand. Parts of the message will appear as text. If the remainder' || crlf || 'appears as random characters in the message body, instead of as' || crlf || 'attachments, then you''ll have to extract these parts and decode them' || crlf || 'manually.' || crlf || crlf;
    --  UTL_SMTP.write_data (L_MAIL_CONN, mesg);
    UTL_SMTP.write_data(l_mail_conn, 'Date: ' || TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI:SS') || UTL_TCP.crlf);
    UTL_SMTP.write_data(l_mail_conn, 'To: ' || l_to || UTL_TCP.crlf);
    UTL_SMTP.write_data(l_mail_conn, 'From: ' || p_from || UTL_TCP.crlf);
    UTL_SMTP.write_data(l_mail_conn, 'Subject: ' || p_subject || UTL_TCP.crlf);
    --UTL_SMTP.write_data(l_mail_conn, 'Reply-To: ' || p_from || UTL_TCP.crlf);
    UTL_SMTP.write_data(l_mail_conn, 'MIME-Version: 1.0' || UTL_TCP.crlf);
    UTL_SMTP.write_data(l_mail_conn, 'Content-Type: multipart/alternative; boundary="' || l_boundary || '"' || UTL_TCP.crlf || UTL_TCP.crlf);
    UTL_SMTP.write_data(l_mail_conn, '--' || l_boundary || UTL_TCP.crlf);
    UTL_SMTP.write_data(l_mail_conn, 'Content-Type: text/html; charset="utf-8"' || UTL_TCP.crlf || UTL_TCP.crlf);
    --  UTL_SMTP.WRITE_DATA(L_MAIL_CONN, 'Date: ' || TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI:SS') || CHR(13));
    --  UTL_SMTP.WRITE_DATA(L_MAIL_CONN, 'From: ' || P_FROM || CHR(13));
    --  UTL_SMTP.WRITE_DATA(L_MAIL_CONN, 'Subject: ' || P_SUBJECT || CHR(13));
    --  UTL_SMTP.WRITE_DATA(L_MAIL_CONN, 'To: ' || P_TO || CHR(13));
    UTL_SMTP.WRITE_DATA(L_MAIL_CONN, '' || CHR(13));
    raw_data := UTL_RAW.cast_to_raw (P_MESSAGE);
    UTL_SMTP.write_raw_data (L_MAIL_CONN, raw_data);
    -- UTL_SMTP.WRITE_DATA(L_MAIL_CONN, P_MESSAGE || CHR(13));
    UTL_SMTP.CLOSE_DATA(L_MAIL_CONN);
    UTL_SMTP.QUIT(L_MAIL_CONN);
    dbms_output.put_line('Completed normally');
  EXCEPTION
  WHEN OTHERS THEN
    dbms_output.put_line('Error occured while sending email'||SQLERRM);
  END XXHA_SEND_MAIL_HTML;
  FUNCTION xxha_mul_email(
      p_string     IN VARCHAR2,
      p_recipients IN array )
    RETURN VARCHAR2
  IS
    l_recipients LONG;
  BEGIN
    FOR i IN 1 .. p_recipients.count
    LOOP
      dbms_output.put_line ( 'inside address function - email'||i||':'||p_recipients(i) ) ;
      IF p_recipients(i) IS NOT NULL THEN
        utl_smtp.rcpt(l_mail_conn, p_recipients(i));
      END IF;
      IF ( l_recipients IS NULL ) THEN
        l_recipients    := p_string || p_recipients(i) ;
      ELSE
        l_recipients := l_recipients || ', ' || p_recipients(i);
      END IF;
    END LOOP;
    RETURN l_recipients;
  END;
END ;