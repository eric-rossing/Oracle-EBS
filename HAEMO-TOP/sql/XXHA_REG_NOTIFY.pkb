create or replace PACKAGE BODY      xxha_reg_Notify
AS
/*************************************************************************************
**  FILE NAME    :
**  PROGRAM NAME : XXHA_REG_NOTIFY
**  PROGRAM TYPE : PACKAGE BODY
**  CALLS        : N/A
**  CALLED BY    :
**  PARAMETERS   :
**  PURPOSE
**  =========
**  The package is used to send notification for regulatory holds apply or release
**
**  MODIFICATION HISTORY
**  ====================
**  REF #    CREATED BY      CREATION DATE          MODIFICATION
**  =======  ==========      =============          ============
**     1.0   Naveen Reddy                            INITIAL CREATION
**     2.0   Sethu Nathan     17-Jun-2019            Modified  main procedure to add hold_id = 2021 in sub query fetching MAX(ORDER_HOLD_ID). Incident INC0231719     
**     3.0	 Praduman Singh   03-JAN-2020       	   Modified smtp IP logic
**     
********************************************************************************************/
/* ************************************************************************* */
   PROCEDURE xxha_reg_hold_notify (p_country_control_id   IN NUMBER,
                                   P_header_id               NUMBER)
   AS
      l_order_number      oe_order_headers_all.order_number%TYPE;
      l_hold_flag         VARCHAR2 (10);
      l_org_name          VARCHAR2 (200);
      l_cust_po_number    VARCHAR2 (200);
      p_created_by        NUMBER;
      l_org_id            NUMBER;
      l_resp_id           NUMBER;
      l_user_id           NUMBER;
      l_resp_appl_id      NUMBER;
      l_count             NUMBER := 0;
      l_nodata            VARCHAR2 (1) DEFAULT 'n';
      l_customer          VARCHAR2 (1000);
      l_cust_number       VARCHAR2 (500);
      l_cust_acct_id      NUMBER;
      l_price_list        VARCHAR2 (1000);
      l_cust_price        NUMBER;
      l_item_price        NUMBER;
      l_bill_to_site      NUMBER;
      l_ship_to_site      NUMBER;
      l_bill_to_site_id   NUMBER;
      l_to_email          VARCHAR2 (500);
      v_hold_id           NUMBER;
      l_exception         VARCHAR2 (2000);
      l_message           VARCHAR2 (32000 BYTE) := NULL;
      l_message1          VARCHAR2 (32000 BYTE) := NULL;
      l_order_source      VARCHAR2 (500);
      l_subject           VARCHAR2 (2000);
      to_email            VARCHAR2 (500);
      l_hold_email        VARCHAR2 (2000);
      l_Country           VARCHAR2 (2000);
      l_smtp_host    VARCHAR2(100);  --Added by Praduman

      CURSOR c_ord_hold
      IS
         SELECT DISTINCT
                ooh.header_id,
                ool.line_id,
                ooh.order_number,
                (SELECT segment1
                   FROM mtl_system_items_b
                  WHERE inventory_item_id = ool.inventory_item_id
                        AND organization_id = 103)
                   ordered_item,
                hs.hold_comment
           FROM oe_order_headers_all ooh,
                oe_order_lines_all ool,
                oe_order_holds_all h,
                oe_hold_sources_all hs
          WHERE     1 = 1
                AND ooh.header_id = ool.header_id
                AND ooh.flow_status_code = 'BOOKED'
                AND ool.line_category_code = 'ORDER'
                AND ool.shippable_flag = 'Y'
                AND ool.schedule_ship_date IS NOT NULL
                AND ool.booked_flag = 'Y'
                AND ool.flow_status_code IN ('BOOKED', 'AWAITING_SHIPPING') --
                AND h.hold_source_id = hs.hold_source_id
                AND hs.hold_id = 2021                       -- Regulatory Hold
                AND h.header_id = ooh.header_id
                AND h.line_id = ool.line_id
                AND h.released_flag = 'N'
                AND ooh.header_id = p_header_id
                AND ool.line_id NOT IN
                       (SELECT line_id
                          FROM HAEMO.XXHA_REG_NOTIFY_TB
                         WHERE header_id = ooh.header_id
                               AND Flag_status = 'H');
   BEGIN
      l_hold_flag := NULL;

      BEGIN
         SELECT COUNTRY,
                   REGULATORY_NOTIFICATION
                || ','
                || CUSTOMER_SERVICE_NOTIFICATION
           INTO l_Country, l_hold_email
           FROM xxha_reg_country_control
          WHERE COUNTRY_CONTROL_ID = p_COUNTRY_CONTROL_ID;

         FND_FILE.
          PUT_LINE (
            FND_FILE.LOG,
               'Header id : '
            || P_header_id
            || 'Regulatory hold mail sent to : '
            || l_hold_email);
      EXCEPTION
         WHEN OTHERS
         THEN
            l_hold_email := NULL;
            FND_FILE.
             PUT_LINE (
               FND_FILE.LOG,
               'Mail configuration setup is not done for sending regulatory Hold');
      -- l_rele_email  := Null;
      END;


      FOR rec IN c_ord_hold
      LOOP
         l_count := l_count + 1;

         BEGIN
            SELECT order_number,
                   hou.name,
                   cust_po_number,
                   oos.name
              INTO l_order_number,
                   l_org_name,
                   l_cust_po_number,
                   l_order_source
              FROM oe_order_headers_all ooh,
                   oe_order_sources oos,
                   hr_operating_units hou
             WHERE     ooh.header_id = rec.header_id
                   AND ooh.order_source_id = oos.order_source_id
                   AND ooh.org_id = hou.organization_id;
         EXCEPTION
            WHEN OTHERS
            THEN
               l_exception := NULL;
               l_exception := SQLERRM;
         END;

         l_message1 :=
               l_message1
            || CHR (13)
            || '<tr align="right"><td>'
            || rec.order_number
            || '</td><td>'
            || rec.ordered_item
            || '</td><td>'
            || l_Country
            || '</td><td>'
            || rec.hold_comment
            || '</td></tr>'
            || CHR (13);

         INSERT INTO haemo.xxha_reg_notify_tb (country_control_id,
                                               header_id,
                                               line_id,
                                               Flag_status,
                                               msg,
                                               creation_date,
                                               last_update_date)
              VALUES (p_country_control_id,
                      rec.header_id,
                      rec.line_id,
                      'H',
                      'Sucessfully Sent',
                      SYSDATE,
                      SYSDATE);

         UPDATE xxha_reg_notify_tb
            SET Flag_status = 'C', LAST_UPDATE_DATE = SYSDATE
          WHERE     header_id = rec.header_id
                AND COUNTRY_CONTROL_ID = p_country_control_id
                AND line_id = rec.line_id
                AND Flag_status = 'R';
      END LOOP;

      COMMIT;

      IF l_count > 0
      THEN
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
           /* End  */
            l_subject :=
                  'Hold applied for order#'
               || l_order_number
               || ' OU #'
               || l_org_name;
            l_message := 'Dear Regulatory,' || '<p></p>';
            l_message := l_message || '<p></p>' || '          ' || CHR (13);
            l_message :=
               l_message || '<p></p>'
               || 'The following items have been placed on order hold. Please review and determine if hold can be released. Please contact Customer Service for any questions, or to confirm that item cannot ship and order should be cancelled.';
            l_message := l_message || '<p></p>' || '          ' || CHR (13);
            l_message :=
                  l_message
               || '<table border="1"><tr align="right"><th>SO #</th>'
               || '<th>Item#</th>'
               || '<th>Country</th>'
               || '<th>Hold Comment</th>'
               || CHR (13);
            l_message := l_message || l_message1 || '</table>' || CHR (13);
            l_message := l_message || '          ' || CHR (13);
            l_message := l_message || '<p></p>' || '          ' || CHR (13);
            l_message := l_message || '<p> </p>' || 'Thank you,';
            l_message := l_message || '<p> </p>' || 'Customer Service';
            DBMS_OUTPUT.put_line ('test log file:' || l_message);


            xxha_om_pricing_control_pkg.
             xxha_send_mail_html (
               p_mail_host   =>  l_smtp_host,--'smtp-bo.haemo.net',    --Modified by Praduman
               p_from        => 'customerservice@haemonetics.com',
               p_to          => l_hold_email,
               p_subject     => l_subject,
               p_message     => l_message);
         EXCEPTION
            WHEN OTHERS
            THEN
               l_exception := NULL;
               l_exception := SQLERRM;

               FOR rec1 IN c_ord_hold
               LOOP
                  UPDATE haemo.xxha_reg_notify_tb
                     SET Flag_status = 'E',
                         msg = 'Error',
                         last_update_date = SYSDATE
                   WHERE     country_control_id = p_country_control_id
                         AND header_id = rec1.header_id
                         AND line_id = rec1.line_id;

                  COMMIT;
               END LOOP;
         END;
      END IF;
   END;

   PROCEDURE xxha_reg_Release_notify (p_country_control_id   IN NUMBER,
                                      P_header_id               NUMBER)
   AS
      l_order_number      oe_order_headers_all.order_number%TYPE;
      l_hold_flag         VARCHAR2 (10);
      l_org_name          VARCHAR2 (200);
      l_cust_po_number    VARCHAR2 (200);
      p_created_by        NUMBER;
      l_org_id            NUMBER;
      l_resp_id           NUMBER;
      l_user_id           NUMBER;
      l_resp_appl_id      NUMBER;
      l_count             NUMBER := 0;
      l_nodata            VARCHAR2 (1) DEFAULT 'n';
      l_customer          VARCHAR2 (1000);
      l_cust_number       VARCHAR2 (500);
      l_cust_acct_id      NUMBER;
      l_price_list        VARCHAR2 (1000);
      l_cust_price        NUMBER;
      l_item_price        NUMBER;
      l_bill_to_site      NUMBER;
      l_ship_to_site      NUMBER;
      l_bill_to_site_id   NUMBER;
      l_to_email          VARCHAR2 (500);
      v_hold_id           NUMBER;
      l_exception         VARCHAR2 (2000);
      l_message           VARCHAR2 (32000 BYTE) := NULL;
      l_message1          VARCHAR2 (32000 BYTE) := NULL;
      l_order_source      VARCHAR2 (500);
      l_subject           VARCHAR2 (2000);
      to_email            VARCHAR2 (500);
      l_rele_email        VARCHAR2 (2000);
      l_Ctry              VARCHAR2 (2000);
      l_smtp_host         VARCHAR2 (100);  --Added by Praduman

      CURSOR C_Ord_rel
      IS
         SELECT DISTINCT
                ooh.header_id,
                ool.line_id,
                ooh.order_number,
                (SELECT segment1
                   FROM mtl_system_items_b
                  WHERE inventory_item_id = ool.inventory_item_id
                        AND organization_id = 103)
                   ordered_item,
                hs.hold_comment
           FROM oe_order_headers_all ooh,
                oe_order_lines_all ool,
                oe_order_holds_all h,
                oe_hold_sources_all hs,
                HAEMO.XXHA_REG_NOTIFY_TB XRNT
          WHERE     1 = 1
                AND ooh.header_id = ool.header_id
                AND ooh.flow_status_code = 'BOOKED'
                AND ool.line_category_code = 'ORDER'
                AND ool.shippable_flag = 'Y'
                AND ool.schedule_ship_date IS NOT NULL
                AND ool.booked_flag = 'Y'
                AND ool.flow_status_code IN ('BOOKED', 'AWAITING_SHIPPING') --
                AND h.hold_source_id = hs.hold_source_id
                AND hs.hold_id = 2021                       -- Regulatory Hold
                AND h.header_id = ooh.header_id
                AND h.line_id = ool.line_id
                AND h.released_flag = 'Y'
                AND h.HOLD_RELEASE_ID IS NOT NULL
                AND h.order_hold_id =
                       (SELECT MAX (order_hold_id)
                          FROM oe_order_holds_all h1
                         WHERE     h1.header_id = h.header_id
                               AND h1.line_id = h.line_id
                               AND h1.released_flag = 'Y')
                AND ooh.header_id = p_header_id
                AND ooh.header_id = XRNT.header_id
                AND ool.line_id = XRNT.line_id
                AND XRNT.Flag_status = 'H'
                AND ool.line_id NOT IN
                       (SELECT line_id
                          FROM HAEMO.XXHA_REG_NOTIFY_TB
                         WHERE header_id = ooh.header_id
                               AND Flag_status = 'R');
   -- and ooh.order_number in ('1032537');
   BEGIN
      l_hold_flag := NULL;

      BEGIN
         SELECT COUNTRY, CUSTOMER_SERVICE_NOTIFICATION
           INTO l_Ctry, l_rele_email
           FROM xxha_reg_country_control
          WHERE COUNTRY_CONTROL_ID = p_COUNTRY_CONTROL_ID;

         FND_FILE.
          PUT_LINE (
            FND_FILE.LOG,
               'Header id : '
            || P_header_id
            || ' Regulatory hold  Release mail sent to : '
            || l_rele_email);
      EXCEPTION
         WHEN OTHERS
         THEN
            -- l_hold_email  := Null;
            l_rele_email := NULL;

            FND_FILE.
             PUT_LINE (
               FND_FILE.LOG,
               'Mail configuration setup is not done for sending release regulatory Hold');
      END;


      FOR rec IN C_Ord_rel
      LOOP
         l_count := l_count + 1;

         BEGIN
            SELECT order_number,
                   hou.NAME,
                   cust_po_number,
                   oos.NAME
              INTO l_order_number,
                   l_org_name,
                   l_cust_po_number,
                   l_order_source
              FROM oe_order_headers_all ooh,
                   oe_order_sources oos,
                   hr_operating_units hou
             WHERE     ooh.header_id = rec.header_id
                   AND ooh.order_source_id = oos.order_source_id
                   AND ooh.org_id = hou.organization_id;
         EXCEPTION
            WHEN OTHERS
            THEN
               l_exception := NULL;
               l_exception := SQLERRM;
         END;

         l_message1 :=
               l_message1
            || CHR (13)
            || '<tr align="right"><td>'
            || rec.order_number
            || '</td><td>'
            || rec.ordered_item
            || '</td><td>'
            || l_Ctry
            || '</td><td>'
            || rec.hold_comment
            || '</td></tr>'
            || CHR (13);


         UPDATE haemo.xxha_reg_notify_tb
            SET Flag_status = 'R',
                msg = 'Succesfully Sent',
                last_update_date = SYSDATE
          WHERE     country_control_id = p_country_control_id
                AND header_id = rec.header_id
                AND line_id = rec.line_id;
      END LOOP;

      COMMIT;

      IF l_count > 0
      THEN
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
             /* End  */
            l_subject :=
                  'Hold Released for order#'
               || l_order_number
               || ' OU #'
               || l_org_name;
            l_message := 'Dear Customer Service,' || '<p></p>';
            l_message := l_message || '<p></p>' || '          ' || CHR (13);
            l_message :=
               l_message || '<p></p>'
               || 'The following items have been released on order hold. Please review the same.';
            l_message := l_message || '<p></p>' || '          ' || CHR (13);
            l_message :=
                  l_message
               || '<table border="1"><tr align="right"><th>SO #</th>'
               || '<th>Item#</th>'
               || '<th>Country</th>'
               || '<th>Hold Comment</th>'
               || CHR (13);
            l_message := l_message || l_message1 || '</table>' || CHR (13);
            l_message := l_message || '          ' || CHR (13);
            l_message := l_message || '<p></p>' || '          ' || CHR (13);
            l_message := l_message || '<p> </p>' || 'Thank you.';
            -- l_message := l_message || '<p> </p>' || 'Customer Service';
            DBMS_OUTPUT.put_line ('test log file:' || l_message);


            xxha_om_pricing_control_pkg.
             xxha_send_mail_html (
               p_mail_host   =>  l_smtp_host, --'smtp-bo.haemo.net',   --Modified by Praduman
               p_from        => 'customerservice@haemonetics.com',
               p_to          => l_rele_email,
               p_subject     => l_subject,
               p_message     => l_message);
         EXCEPTION
            WHEN OTHERS
            THEN
               l_exception := NULL;
               l_exception := SQLERRM;

               FOR rec1 IN C_Ord_rel
               LOOP
                  UPDATE haemo.xxha_reg_notify_tb
                     SET Flag_status = 'E',
                         msg = 'Error',
                         last_update_date = SYSDATE
                   WHERE     country_control_id = p_country_control_id
                         AND header_id = rec1.header_id
                         AND line_id = rec1.line_id;

                  COMMIT;
               END LOOP;
         END;
      END IF;
   END xxha_reg_Release_notify;

   PROCEDURE XXHA_REG_NOTIFY_MAIN (errbuf                    OUT VARCHAR2,
                                   retcode                   OUT NUMBER)
                                 --  P_COUNTRY_CONTROL_ID   IN     NUMBER)   Commented by praduman for regulatory Project
   AS
      l_Count   NUMBER := 0;
   BEGIN
      FOR V_rc
         IN (SELECT ooha.header_id, --ooha.order_number,ooha.flow_status_code "STATUS",hcsua1.LOCATION,hl.country "Bill To Country",hl1.country "SHIP Country",
                                    NVL (h.RELEASED_FLAG, 'N') RELEASED_FLAG,
                                     xrcc.country_control_id   --  Added by praduman for regulatory Project
               FROM oe_order_headers_all ooha,
                    oe_order_lines_all ool,
                    hz_cust_accounts hca,
                    hz_parties hp,
                    hz_parties hp1,
                    hz_locations hl,
                    hz_locations hl1,
                    hz_cust_acct_sites_all hcasa,
                    hz_cust_acct_sites_all hcasa1,
                    hz_cust_site_uses_all hcsua,
                    hz_cust_site_uses_all hcsua1,
                    hz_party_sites hps,
                    hz_party_sites hps1,
                    OE_ORDER_HOLDS_ALL H,
                    OE_HOLD_SOURCES_ALL HS,
                    xxha_reg_country_control xrcc,
                    fnd_lookup_values flv
              WHERE     1 = 1
                    --AND ooha.order_number = 1236749
                    AND H.HOLD_SOURCE_ID = HS.HOLD_SOURCE_ID
                    AND HS.HOLD_ID = 2021
                    AND ooha.header_id = h.header_id
                    AND ooha.header_id = ool.header_id
                    AND ool.line_id = h.line_id
                    AND ooha.org_id = h.org_id
                    AND ooha.flow_status_code = 'BOOKED'
                    AND ool.line_category_code = 'ORDER'
                    AND ool.shippable_flag = 'Y'
                    AND ool.schedule_ship_date IS NOT NULL
                    AND ool.booked_flag = 'Y'
                    AND ool.flow_status_code IN
                           ('BOOKED', 'AWAITING_SHIPPING')
                    AND flv.lookup_type = 'XXHA_REG_RESTRICT_NOTIFY'
                    AND hs.org_id != flv.LOOKUP_CODE
                    AND flv.language = 'US'
                    AND flv.enabled_flag = 'Y'
                    AND ooha.sold_to_org_id = hca.cust_account_id
                    AND hca.party_id = hp.party_id
                    AND hca.party_id = hp1.party_id
                    AND ooha.invoice_to_org_id = hcsua.site_use_id(+)
                    AND hcsua.cust_acct_site_id = hcasa.cust_acct_site_id(+)
                    AND hcasa.party_site_id = hps.party_site_id(+)
                    AND hl.location_id(+) = hps.location_id
                    AND ooha.ship_to_org_id = hcsua1.site_use_id(+)
                    AND hcsua1.cust_acct_site_id =
                           hcasa1.cust_acct_site_id(+)
                    AND hcasa1.party_site_id = hps1.party_site_id(+)
                    AND hl1.location_id(+) = hps1.location_id
                    AND h.order_hold_id = (SELECT MAX (order_hold_id)          --Modified for INC0231719
                                                         FROM oe_order_holds_all h1,oe_hold_sources_all ohs1
                                                        WHERE h1.header_id = h.header_id
                                                            AND h1.hold_source_id = ohs1.hold_source_id
                                                            AND ohs1.hold_id = 2021)
                    AND DECODE (xrcc.SITE_CONTROL_TYPE,
                                'Ship To', hl1.country,
                                'Bill To', hl.country) = xrcc.COUNTRY_CODE
                    AND xrcc.enabled_flag = 'Yes'
                  --  AND xrcc.COUNTRY_CONTROL_ID = P_COUNTRY_CONTROL_ID commented by praduman for regulatory Project
                    AND TRUNC (SYSDATE) BETWEEN TRUNC (flv.START_DATE_ACTIVE)
                                            AND TRUNC (
                                                   NVL (flv.END_DATE_ACTIVE,
                                                        SYSDATE))
--                    AND h.order_hold_id = (SELECT MAX (order_hold_id)     --Commented for INC0231719
--                                             FROM oe_order_holds_all h1
--                                            WHERE h1.header_id = h.header_id)
                    AND h.LAST_UPDATE_DATE >=
                           NVL (
                              (SELECT MAX (REQUEST_DATE) - (1 / 24)
                                 FROM fnd_concurrent_programs FCp,
                                      FND_concurrent_requests fcr
                                WHERE fcp.CONCURRENT_PROGRAM_ID =
                                         fcr.CONCURRENT_PROGRAM_ID
                                      AND fcp.concurrent_program_name =
                                             'XXHA_REG_NOTIFY_CP'
                                      AND PHASE_CODE = 'C'
                                      AND STATUS_CODE = 'C'),
                              SYSDATE - 1)
                              )
      LOOP
         l_Count := l_Count + 1;

         IF V_rc.RELEASED_FLAG != 'Y'
         THEN
            --xxha_reg_hold_notify (p_country_control_id, V_rc.Header_id);
             xxha_reg_hold_notify (V_rc.country_control_id, V_rc.Header_id);   --changes done by praduman singh for Regulatory Project
         ELSIF V_rc.RELEASED_FLAG = 'Y'
         THEN
           xxha_reg_Release_notify (V_rc.country_control_id, V_rc.Header_id);  --changes done by praduman singh for  Regulatory Project 
          --  xxha_reg_Release_notify (p_country_control_id, V_rc.Header_id);
         END IF;
      END LOOP;

      IF l_Count = 0
      THEN
         FND_FILE.
          PUT_LINE (FND_FILE.OUTPUT, 'Orders are not available since 1 hour');
      END IF;
   END XXHA_REG_NOTIFY_MAIN;
END xxha_reg_Notify;