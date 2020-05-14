CREATE OR REPLACE PACKAGE BODY xxha_oe_surge_order_alert_pkg
IS

 /*****************************************************************************************
 * Name/Purpose : APPS.XXHA_OE_SURGE_ORDER_ALERT_PKG                                            *
  * Description  : creates                                                                 *
  *                package body XXHA_OE_SURGE_ORDER_ALERT_PKG                                   *
  *                for sending emails for surge order requirement                 *
  * Date            Author               Description                                       *
  * -----------     -----------------    ---------------                                   *
  * 29-APR-2020     Sethu Nathan       Initial Creation                                 *
  ***************************************************************************************/

PROCEDURE process_orders( x_err_buf           OUT VARCHAR2,
                                           x_ret_code          OUT VARCHAR2)
IS

   l_item_id      MTL_SYSTEM_ITEMS_B.INVENTORY_ITEM_ID%TYPE;   
   l_cust_account_id HZ_CUST_ACCOUNTS.CUST_ACCOUNT_ID%TYPE;
   l_cust_number  HZ_CUST_ACCOUNTS.ACCOUNT_NUMBER%TYPE;
   l_site_use_loc   HZ_CUST_SITE_USES_ALL.LOCATION%TYPE;
   l_ou_name    HR_OPERATING_UNITS.NAME%TYPE;
   l_party_name HZ_PARTIES.PARTY_NAME%TYPE;
   l_address1     HZ_LOCATIONS.ADDRESS1%TYPE;
   l_address2     HZ_LOCATIONS.ADDRESS2%TYPE;
   l_address3     HZ_LOCATIONS.ADDRESS3%TYPE;
   l_state           HZ_LOCATIONS.STATE%TYPE;
   l_country        HZ_LOCATIONS.COUNTRY%TYPE;
   l_cust_po_number OE_ORDER_HEADERS_ALL.CUST_PO_NUMBER%TYPE;   
   l_item MTL_SYSTEM_ITEMS_B.SEGMENT1%TYPE;
   l_item_desc  MTL_SYSTEM_ITEMS_B.DESCRIPTION%TYPE;
   l_site_use_location  HZ_CUST_SITE_USES_ALL.LOCATION%TYPE;
   l_ship_to_contact   HZ_PARTIES.PARTY_NAME%TYPE;
   l_contact_email  HZ_CONTACT_POINTS.EMAIL_ADDRESS%TYPE;
   l_request_id   NUMBER := FND_GLOBAL.CONC_REQUEST_ID;
   l_excl_count NUMBER := 0;
   l_process_count  NUMBER := 0;
   l_smtp_host  VARCHAR2(240);
   l_subject VARCHAR2(240);
   l_message   VARCHAR2(10000);
   l_message1   VARCHAR2(10000);
   l_mail_addr  VARCHAR2(3000);   
   l_prod_flag	VARCHAR2(5);
   l_from		VARCHAR2(100);

BEGIN
    IF TO_NUMBER(TO_CHAR(SYSDATE,'HH')) = 10 THEN  --Delete history records from temp table
        delete_temp_table;
    END IF;

    FOR rec_val IN (SELECT * FROM xxha_oe_surge_order_tbl)
    LOOP
        FOR   rec_txn_type IN (SELECT ffv.flex_value hdr_txn
                                              FROM fnd_flex_value_sets ffvs,fnd_flex_values_vl ffv
                                            WHERE ffvs.flex_value_set_id = ffv.flex_value_set_id
                                                 AND ffvs.flex_value_set_name = 'XXHA_OE_SHORT_WATCH_TXN_TYPE_HDR'
                                                 AND ffv.enabled_flag = 'Y')
        LOOP
            FOR rec_order IN (SELECT ool.sold_to_org_id,ool.ship_to_org_id,ool.inventory_item_id,ool.ordered_item,
                                                    SUM(apps.inv_convert.inv_um_convert (ool.inventory_item_id,  --Inventory Item Id
                                                                                                            NULL,                   --Precision
                                                                                                            ool.ordered_quantity,     --Quantity
                                                                                                            ool.order_quantity_uom,           --From UOM
                                                                                                            'Ca',                --To UOM
                                                                                                            NULL,               --From UOM Name
                                                                                                            NULL                 -- To UOM Name
                                                                                                           )
                                                       ) sum_qty
                                           FROM oe_order_headers_all ooh,
                                                    oe_order_lines_all ool,
                                                    oe_transaction_types_tl ott,
                                                    oe_transaction_types_tl ott_line
                                         WHERE ooh.header_id = ool.header_id
                                              AND ooh.order_type_id = ott.transaction_type_id
                                              AND ott.language = 'US'
                                              AND ott.name = rec_txn_type.hdr_txn
                                              AND ool.inventory_item_id = rec_val.item_id
                                              AND ool.line_type_id = ott_line.transaction_type_id
                                              AND ott_line.language = 'US'
                                              AND TRUNC(ool.creation_date) = TRUNC(SYSDATE)
                                              AND ooh.flow_status_code = 'BOOKED'
                                              AND ott_line.name IN
                                                                             (SELECT ffv.flex_value
                                                                              FROM fnd_flex_value_sets ffvs,fnd_flex_values_vl ffv
                                                                            WHERE ffvs.flex_value_set_id = ffv.flex_value_set_id
                                                                                 AND ffvs.flex_value_set_name = 'XXHA_OE_SHORT_WATCH_TXN_TYPE_LINE'
                                                                                 AND ffv.parent_flex_value_low = rec_txn_type.hdr_txn
                                                                                 AND ffv.enabled_flag = 'Y')                                                     
                                         GROUP BY ool.sold_to_org_id,ool.ship_to_org_id,inventory_item_id,ool.ordered_item)
                      LOOP
                                l_excl_count := 0;
                               FOR rec_excl_cus IN   (SELECT ac.customer_id
                                                                   FROM fnd_lookup_values flv,ar_customers ac
                                                                 WHERE flv.meaning = ac.customer_number
                                                                     AND flv.lookup_type = rec_val.exclude_customer_lkp
                                                                     AND flv.language = 'US'
                                                                     AND enabled_flag = 'Y' 
                                                                     AND TRUNC(SYSDATE) BETWEEN start_date_active AND NVL(end_date_active,TO_DATE('31-DEC-4712')))
                              LOOP
                                    IF rec_excl_cus.customer_id = rec_order.sold_to_org_id THEN
                                        l_excl_count := 1;
                                    END IF;
                              END LOOP;            
                              
                              BEGIN
                                SELECT COUNT(1)
                                   INTO l_process_count
                                  FROM xxha_oe_surge_order_temp xsqv
                                WHERE xsqv.site_use_id = rec_order.ship_to_org_id
                                     AND xsqv.item_id = rec_order.inventory_item_id
                                     AND xsqv.process_date = TRUNC(SYSDATE);
                              EXCEPTION
                              WHEN OTHERS THEN
                                    l_process_count := -1;
                              END;                                                 
                              
                              IF l_process_count = 0 THEN
                                  IF l_excl_count = 0 THEN                           
                                         IF rec_order.sum_qty > rec_val.trigger_qty THEN                                    
                                            l_message1 := NULL;
                                            l_message   := NULL;
                                            l_subject     := NULL;
                                            l_mail_addr := NULL;
                                            FOR rec_mail IN (SELECT ooh.cust_po_number,ool.org_id,ooh.order_number,ool.ship_to_org_id,ool.inventory_item_id,ool.ordered_item,ool.order_quantity_uom,
                                                                                  ool.schedule_ship_date,ool.shipment_priority_code,ool.shipping_method_code,
                                                                                  ool.ordered_quantity,ool.ship_to_contact_id
                                                                       FROM oe_order_headers_all ooh,
                                                                                oe_order_lines_all ool,
                                                                                oe_transaction_types_tl ott,
                                                                                oe_transaction_types_tl ott_line
                                                                     WHERE ooh.header_id = ool.header_id
                                                                          AND ooh.order_type_id = ott.transaction_type_id
                                                                          AND ott.language = 'US'
                                                                          AND ott.name = rec_txn_type.hdr_txn
                                                                          AND ool.inventory_item_id = rec_order.inventory_item_id
                                                                          AND ool.ship_to_org_id = rec_order.ship_to_org_id
                                                                          AND ool.line_type_id = ott_line.transaction_type_id
                                                                          AND ott_line.language = 'US'
                                                                          AND TRUNC(ool.creation_date) = TRUNC(SYSDATE)
                                                                          AND ooh.flow_status_code = 'BOOKED'
                                                                          AND ott_line.name IN
                                                                                                         (SELECT ffv.flex_value
                                                                                                          FROM fnd_flex_value_sets ffvs,fnd_flex_values_vl ffv
                                                                                                        WHERE ffvs.flex_value_set_id = ffv.flex_value_set_id
                                                                                                             AND ffvs.flex_value_set_name = 'XXHA_OE_SHORT_WATCH_TXN_TYPE_LINE'
                                                                                                             AND ffv.parent_flex_value_low = rec_txn_type.hdr_txn
                                                                                                             AND ffv.enabled_flag = 'Y'))
                                              LOOP                                                                    
                                                    BEGIN                              
                                                         SELECT hca.cust_account_id,account_number,hcsu.location,hp.party_name,hl.address1,hl.address2,hl.address3,hl.state,hl.country
                                                            INTO l_cust_account_id,l_cust_number,l_site_use_loc,l_party_name,l_address1,l_address2,l_address3,l_state,l_country
                                                          FROM hz_cust_accounts hca,
                                                                    hz_cust_acct_sites_all hcas,
                                                                    hz_cust_site_uses_all hcsu,
                                                                    hz_parties hp,
                                                                    hz_party_sites hps,
                                                                    hz_locations hl
                                                         WHERE hca.cust_account_id = hcas.cust_account_id
                                                              AND hcas.cust_acct_site_id = hcsu.cust_acct_site_id
                                                              AND hcas.party_site_id = hps.party_site_id
                                                              AND hps.location_id = hl.location_id 
                                                              AND hcsu.site_use_id = rec_mail.ship_to_org_id
                                                              AND hca.party_id = hp.party_id;
                                                    EXCEPTION
                                                    WHEN OTHERS THEN
                                                        fnd_file.put_line (fnd_file.LOG,'Exception in Customer address detail : '||SQLERRM);
                                                    END;      
                                                    
                                                    BEGIN      
                                                        SELECT description
                                                            INTO l_item_desc
                                                           FROM mtl_system_items_b
                                                         WHERE inventory_item_id = rec_mail.inventory_item_id
                                                             AND organization_id = 103;
                                                      EXCEPTION
                                                    WHEN OTHERS THEN
                                                        fnd_file.put_line (fnd_file.LOG,'Exception in Item description : '||SQLERRM);
                                                    END;                    
                                                         
                                                    BEGIN
                                                         SELECT name
                                                             INTO l_ou_name
                                                            FROM hr_operating_units
                                                          WHERE organization_id = rec_mail.org_id;
                                                    EXCEPTION
                                                    WHEN OTHERS THEN
                                                        fnd_file.put_line (fnd_file.LOG,'Exception in Operating Unit : '||SQLERRM);
                                                    END;    
                                                      
                                                       BEGIN
                                                          SELECT hp1.party_name
                                                              INTO l_ship_to_contact
                                                             FROM hz_cust_account_roles hcar,hz_parties hp1
                                                           WHERE hcar.party_id = hp1.party_id
                                                                AND hcar.cust_account_role_id = rec_mail.ship_to_contact_id;
                                                       EXCEPTION
                                                       WHEN OTHERS THEN
                                                        l_ship_to_contact := NULL;
                                                       END;      
                                                       
                                                       BEGIN 
                                                           SELECT cont_point.email_address
                                                               INTO l_Contact_email                 
                                                           FROM hz_cust_account_roles acct_role, 
                                                                    hz_relationships rel , 
                                                                    hz_parties party,
                                                                    hz_parties rel_party,
                                                                    hz_contact_points    cont_point
                                                           WHERE acct_role.cust_account_role_id = rec_mail.ship_to_contact_id
                                                               AND acct_role.party_id                   = rel.party_id
                                                               AND   acct_role.role_type                        = 'CONTACT'
                                                               AND   rel.subject_id                                  = party.party_id
                                                               AND   rel_party.party_id                           = rel.party_id
                                                               AND   cont_point.owner_table_id(+)        = rel_party.party_id
                                                               AND   cont_point.contact_point_type(+)   IN ( 'EMAIL')
                                                               AND  cont_point.primary_flag(+)            = 'Y'
                                                               AND ROWNUM =1;

                                                       EXCEPTION 
                                                       WHEN OTHERS THEN 
                                                           fnd_file.put_line (fnd_file.LOG,'Exception in the customer Contact email : '||SQLERRM);
                                                       END;
                                                      
                                                      fnd_file.put_line (fnd_file.LOG,'Sales Order : '||rec_mail.order_number);
                                                      fnd_file.put_line (fnd_file.LOG,'Ship To Location : '||l_site_use_loc);
                                                      fnd_file.put_line (fnd_file.LOG,'Order Item : '||rec_mail.ordered_item);
                                                      fnd_file.put_line (fnd_file.LOG,'Order Quantity : '||rec_mail.ordered_quantity);
                                                      fnd_file.put_line (fnd_file.LOG,'Order Quantity UOM : '||rec_mail.order_quantity_uom);
                                                      fnd_file.put_line (fnd_file.LOG,' ');                                                                                                                                                                                                                            
                                              
                                                     l_message1 := l_message1
                                                                            || CHR (13)
                                                                            || '<tr align="right"><td>'
                                                                            || l_ou_name
                                                                            || '</td><td>'
                                                                            || rec_mail.order_number
                                                                            || '</td><td>'
                                                                            || rec_mail.cust_po_number
                                                                            || '</td><td>'
                                                                            || l_cust_number
                                                                            || '</td><td>'
                                                                            || l_party_name
                                                                            || '</td><td>'
                                                                            || l_address1||';'||l_address2||';'||l_address3||';'||l_state||';'||l_country
                                                                            || '</td><td>'                                                                        
                                                                            || rec_mail.ordered_item
                                                                            || '</td><td>'                                                                        
                                                                            || l_item_desc
                                                                            || '</td><td>'
                                                                            || rec_mail.ordered_quantity
                                                                            || '</td><td>'
                                                                            || rec_mail.order_quantity_uom 
                                                                            || '</td><td>'
                                                                            || rec_mail.shipment_priority_code 
                                                                            || '</td><td>'
                                                                            || rec_mail.shipping_method_code 
                                                                            || '</td><td>'
                                                                            || rec_mail.schedule_ship_date
                                                                            || '</td><td>'
                                                                            || l_ship_to_contact
                                                                            || '</td><td>'
                                                                            || l_contact_email 
                                                                            || '</td></tr>'
                                                                            || CHR (13);
                                              END LOOP; 
                                              
                                              BEGIN
                                              SELECT location
                                                  INTO l_site_use_location
                                                 FROM hz_cust_site_uses_all
                                               WHERE site_use_id = rec_order.ship_to_org_id;
                                              EXCEPTION
                                              WHEN OTHERS THEN
                                                     fnd_file.put_line (fnd_file.LOG,'Exception in the Customer location : '||SQLERRM);
                                              END;  
                                              
                                              l_subject :=
                                                  'Order Qty Alert -'
                                               ||l_party_name
                                               ||','||l_site_use_location
                                               ||','|| rec_order.ordered_item
                                               ||','|| rec_order.sum_qty;
                                               
        --                                    l_message := 'Dear Regulatory,' || '<p></p>';
        --                                    l_message := l_message || '<p></p>' || '          ' || CHR (13);
                                            l_message :=
                                               l_message || '<p></p>'
                                               || 'An alert has been triggered due to the Qty Ordered - please see Alert Triggers to understand why are receiving this notification';
                                            l_message := l_message || '<p></p>' || '          ' || CHR (13);   
                                            l_message :=
                                               l_message || '<p></p>'
                                               || 'Alert Triggers:';
                                            l_message := l_message || '<p></p>' || '          ' || CHR (13);
                                            l_message := l_message || '<p></p>' || '          ' || CHR (13);   
                                            l_message :=
                                               l_message || '<p></p>'
                                               || '1. If a customer places multiple orders in a single day, for the same ship to address, and the total combined quantity is greater than trigger quantity';   
                                            l_message := l_message || '<p></p>' || '          ' || CHR (13);  
                                            l_message :=
                                               l_message || '<p></p>'
                                               || '2. If a customer places a single order, and the total line combined quantity is greater than trigger quantity'; 
                                            l_message := l_message || '<p></p>' || '          ' || CHR (13);
                                            l_message := l_message ||'Alert Trigger : '||rec_val.trigger_qty|| '; UOM : Ca';   
                                            l_message := l_message || '<p></p>' || '          ' || CHR (13);
                                            l_message :=
                                                  l_message
                                               || '<table border="1"><tr align="right">'
                                               || '<th>Operating Unit</th>'
                                               || '<th>Sales Order#</th>'
                                               || '<th>Purchase Order#</th>'
                                               || '<th>Customer Number</th>'
                                               || '<th>Customer Name</th>'
                                               || '<th>Ship-To Address</th>'
                                               || '<th>Internal Item</th>'
                                               || '<th>Item Description</th>'
                                               || '<th>Order Quantity</th>'
                                               || '<th>Order UOM</th>'
                                               || '<th>Shipment Priority</th>'
                                               || '<th>Ship Method</th>'
                                               || '<th>Schedule Ship Date</th>'
                                               || '<th>Ship To Contact</th>'
                                               || '<th>Ship To Mail Address</th>'
                                               || CHR (13);
                                            l_message := l_message || l_message1 || '</table>' || CHR (13);
                                            l_message := l_message || '          ' || CHR (13);
                                            l_message := l_message || '<p></p>' || '          ' || CHR (13);
                                            l_message := l_message || '<p> </p>' || 'Thank you,';
        --                                    l_message := l_message || '<p> </p>' || 'Customer Service';
                                              
                                              BEGIN
                                                 SELECT xxha_fnd_util_pkg.get_ip_address
                                                   INTO l_smtp_host
                                                   FROM dual;           
                                              EXCEPTION
                                               WHEN OTHERS THEN
                                                  fnd_file.put_line (fnd_file.LOG,'Exception while getting ip Address:'|| SQLERRM);
                                              END;
                                              
                                              FOR rec_mail IN (SELECT meaning
                                                                           FROM fnd_lookup_values 
                                                                         WHERE lookup_type = rec_val.notify_mail_addr_lkp
                                                                             AND language = 'US'
                                                                             AND enabled_flag = 'Y' 
                                                                             AND TRUNC(SYSDATE) BETWEEN TRUNC(start_date_active) AND NVL(TRUNC(end_date_active),TO_DATE('31-DEC-4712')))
                                               LOOP
                                                    l_mail_addr := rec_mail.meaning||','||l_mail_addr; 
                                               END LOOP;
											   
											   SELECT XXHA_PROD_DB
												 INTO l_prod_flag
												 FROM DUAL;
												 
											  IF l_prod_flag = 'N' THEN
												l_from := 'ebsmailer-haetst@haemonetics.com';
											  ELSE
												l_from := 'ebsmailer-haeprd@haemonetics.com';
											  END IF;
                                              
                                              send_mail_html (p_mail_host   =>  l_smtp_host,
                                                                               p_from        => l_from,
                                                                               p_to          => l_mail_addr,
                                                                               p_subject     => l_subject,
                                                                               p_message     => l_message);                
                                                             
                                              INSERT INTO xxha_oe_surge_order_temp VALUES(rec_order.sold_to_org_id,rec_order.ship_to_org_id,rec_order.inventory_item_id,TRUNC(SYSDATE),l_request_id);                                                         
                                              COMMIT;
                                         END IF;
                                  END IF;
                              END IF;          
                      END LOOP;          
        END LOOP;                                                 
    END LOOP;  
END process_orders;                                           
PROCEDURE SEND_MAIL_HTML(P_MAIL_HOST IN VARCHAR2,
                                                        P_FROM      IN VARCHAR2,
                                                        P_TO        IN VARCHAR2,
                                                        P_SUBJECT   IN VARCHAR2,
                                                        P_MESSAGE   IN VARCHAR2 )
AS

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
        XXHA_GET_TEST_EMAIL_ADDRESS
      INTO l_prod_flag,
        l_test_email_addr
      FROM DUAL;
      IF ( l_prod_flag = 'N') THEN
      --SMTP host and test email id hardcoding resolution; commented the below line for test email id hardcoding and added next line
       -- l_concat_to   := l_test_email_addr||',eBSMailer-Test@Haemonetics.com';
       l_concat_to:= XXHA_FND_UTIL_PKG.get_recipients;		
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
        l_to := mul_email( 'To: ', to_array );
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
      -- UTL_SMTP.WRITE_DATA(L_MAIL_CONN, P_MESSAGE || CHR(13));
      raw_data := UTL_RAW.cast_to_raw (P_MESSAGE);
      UTL_SMTP.write_raw_data (L_MAIL_CONN, raw_data);
      UTL_SMTP.CLOSE_DATA(L_MAIL_CONN);
      UTL_SMTP.QUIT(L_MAIL_CONN);
      fnd_file.put_line (fnd_file.LOG,'Mail sent successfully');
EXCEPTION
WHEN OTHERS THEN
  fnd_file.put_line (fnd_file.LOG,'Error occured while sending email'||SQLERRM);
END SEND_MAIL_HTML;
FUNCTION mul_email(
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
END mul_email;                                        
PROCEDURE delete_temp_table
IS

BEGIN
    DELETE FROM xxha_oe_surge_order_temp WHERE process_date < TRUNC(SYSDATE)-7;
    COMMIT;
END delete_temp_table;   
END;
/

