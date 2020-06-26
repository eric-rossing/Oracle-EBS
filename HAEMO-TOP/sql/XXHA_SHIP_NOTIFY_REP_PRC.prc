CREATE OR REPLACE PROCEDURE XXHA_SHIP_NOTIFY_REP_PRC (ERRBUF IN OUT VARCHAR2,
 RETCODE IN OUT VARCHAR,
 P_FROM_DATE IN VARCHAR2,
 P_TO_DATE IN VARCHAR2)
IS
 /*******************************************************************************************************
 * Object Name: APPS.XXHA_SHIP_NOTIFY_REP_PRC
 * Object Type: PROCEDURE
 *
 * Description: This procedure will be used to reprocess SMTP error from ASN Program.
 *
 * Modification Log:
 * Developer Version Date                 Description
  *----------------   -------     -------------        ------------------------------------------------
  * Sethu Nathan        1.0        19-JUN-2020         Created reprocessing program to reprocess SMTP error records in ASN program. Incident INC0298313
  *******************************************************************************************************/
  

   l_message              VARCHAR2 (2000);
   l_phase                VARCHAR2 (100);
   l_status               VARCHAR2 (100);
   l_dev_phase            VARCHAR2 (100);
   l_dev_status           VARCHAR2 (100);
   l_option_return        BOOLEAN := FALSE;
   l_wait_for_request     BOOLEAN := FALSE;
   l_get_request_status   BOOLEAN := FALSE;
   l_request_id           NUMBER;
   l_orgn_id              NUMBER;
   l_user_id              fnd_user.user_id%TYPE;
   l_resp_id              fnd_responsibility.responsibility_id%TYPE;
   l_resp_appl_id         fnd_application.application_id%TYPE;
BEGIN

   FOR rc IN (SELECT DISTINCT delivery_id
                FROM (  SELECT DISTINCT
                               ORDER_NUMBER,
                               delivery_id,
                               TO_CHAR (sent_date, 'DD-Mon-YY HH:MI AM')
                                  sent_date,
                               NVL (a.status, 'Successfully Sent') Status,
                               error_message,
                               email order_dff_email,
                               fax order_dff_fax,
                               customer_name,
                               bill_to_cust,
                               (SELECT DISTINCT hprel.EMAIL_ADDRESS EMAIL_ADDR
                                  FROM apps.HZ_CUST_ACCOUNT_ROLES hcar,
                                       apps.HZ_PARTIES hpsub,
                                       apps.HZ_PARTIES hprel,
                                       apps.HZ_ORG_CONTACTS hoc,
                                       apps.HZ_RELATIONSHIPS hr,
                                       apps.HZ_PARTY_SITES hps,
                                       apps.FND_TERRITORIES_VL ftv
                                 WHERE 1 = 1
                                       AND HCAR.CUST_ACCOUNT_ID =
                                              a.bill_cust_account_id
                                       AND hcar.CUST_ACCT_SITE_ID =
                                              a.bill_cust_acct_site_id
                                       AND hcar.ROLE_TYPE = 'CONTACT'
                                       AND hcar.PARTY_ID = hr.PARTY_ID
                                       AND hr.PARTY_ID = hprel.PARTY_ID
                                       AND hr.SUBJECT_ID = hpsub.PARTY_ID
                                       AND hoc.PARTY_RELATIONSHIP_ID =
                                              hr.RELATIONSHIP_ID
                                       AND hr.DIRECTIONAL_FLAG = 'F'
                                       AND hps.PARTY_ID(+) = hprel.PARTY_ID
                                       AND NVL (hps.IDENTIFYING_ADDRESS_FLAG,
                                                'Y') = 'Y'
                                       AND NVL (hps.STATUS, 'A') = 'A'
                                       AND hprel.COUNTRY =
                                              ftv.TERRITORY_CODE(+)
                                       AND UPPER (HOC.JOB_TITLE) =
                                              UPPER ('Logistics')
                                       AND HCAR.CUST_ACCT_SITE_ID IS NOT NULL
                                       AND HCAR.STATUS = 'A'
                                       AND ROWNUM = 1)
                                  BILL_TO_EMAIL,
                               SHIP_TO_CUST,
                               (SELECT RTRIM (
                                          XMLAGG (
                                             XMLELEMENT (
                                                col,
                                                hprel.EMAIL_ADDRESS || ', ')).
                                           EXTRACT ('//text()'),
                                          ', ')
                                          EMAIL_ADDR
                                  --DISTINCT hprel.EMAIL_ADDRESS EMAIL_ADDR
                                  FROM apps.HZ_CUST_ACCOUNT_ROLES hcar,
                                       apps.HZ_PARTIES hpsub,
                                       apps.HZ_PARTIES hprel,
                                       apps.HZ_ORG_CONTACTS hoc,
                                       apps.HZ_RELATIONSHIPS hr,
                                       apps.HZ_PARTY_SITES hps,
                                       apps.FND_TERRITORIES_VL ftv
                                 WHERE 1 = 1
                                       AND HCAR.CUST_ACCOUNT_ID =
                                              a.cust_account_id
                                       AND hcar.CUST_ACCT_SITE_ID =
                                              a.cust_acct_site_id
                                       AND hcar.ROLE_TYPE = 'CONTACT'
                                       AND hcar.PARTY_ID = hr.PARTY_ID
                                       AND hr.PARTY_ID = hprel.PARTY_ID
                                       AND hr.SUBJECT_ID = hpsub.PARTY_ID
                                       AND hoc.PARTY_RELATIONSHIP_ID =
                                              hr.RELATIONSHIP_ID
                                       AND hr.DIRECTIONAL_FLAG = 'F'
                                       AND hps.PARTY_ID(+) = hprel.PARTY_ID
                                       AND NVL (hps.IDENTIFYING_ADDRESS_FLAG,
                                                'Y') = 'Y'
                                       AND NVL (hps.STATUS, 'A') = 'A'
                                       AND hprel.COUNTRY =
                                              ftv.TERRITORY_CODE(+)
                                       AND UPPER (HOC.JOB_TITLE) =
                                              UPPER ('Logistics')
                                       AND HCAR.CUST_ACCT_SITE_ID IS NOT NULL
                                       AND hcar.status = 'A')
                                  ship_to_email
                          FROM (  SELECT sent_date,
                                         NVL (status, 'Successfully Sent') Status,
                                         error_message,
                                         DELIVERY_ID,
                                         header_id,
                                         line_id,
                                         cert_flag,
                                         email,
                                         fax,
                                         carrier,
                                         carrier_url,
                                         order_number,
                                         cust_po_number,
                                         schedule_ship_date,
                                         tracking_number,
                                         org_id,
                                         line_number,
                                         inventory_item,
                                         revision,
                                         lot_number,
                                         ordered_item,
                                         description,
                                         SUM (shipped_quantity) shipped_quantity,
                                         shipment_number,
                                         ship_method,
                                         ship_to_cust,
                                         bill_to_cust,
                                         customer_name,
                                         party_id,
                                         cust_account_id,
                                         cust_acct_site_id,
                                         bill_cust_account_id,
                                         bill_cust_acct_site_id,
                                         address1,
                                         address2,
                                         address3,
                                         address4,
                                         city,
                                         state,
                                         COUNTRY,
                                         postal_code
                                    FROM (SELECT c.be_date sent_date,
                                                 NVL (c.status,
                                                      'Successfully Sent')
                                                    Status,
                                                 c.error_message,
                                                 DA.DELIVERY_ID,
                                                 ooh.header_id,
                                                 ool.line_id,
                                                 UPPER (ooh.attribute13)
                                                    cert_flag,
                                                 ooh.attribute9 email,
                                                 ooh.attribute10 fax,
                                                 (SELECT wc.freight_code
                                                    FROM apps.WSH_CARRIERS wc
                                                   WHERE wc.carrier_id =
                                                            nd.carrier_id)
                                                    carrier,
                                                 (SELECT NVL (wc.attribute2,
                                                              nd.attribute6)
                                                    FROM apps.
                                                          WSH_CARRIER_SERVICES_V wc
                                                   WHERE wc.carrier_id =
                                                            nd.carrier_id
                                                         AND wc.ship_method_code =
                                                                nd.
                                                                 ship_method_code)
                                                    carrier_url,
                                                 OOH.ORDER_NUMBER,
                                                 OOH.CUST_PO_NUMBER,
                                                 TO_CHAR (OOL.SCHEDULE_SHIP_DATE,
                                                          'MMDDYY')
                                                    SCHEDULE_SHIP_DATE,
                                                 nd.waybill TRACKING_NUMBER,
                                                 dd.org_id,
                                                    OOL.LINE_NUMBER
                                                 || '.'
                                                 || OOL.SHIPMENT_NUMBER
                                                    LINE_NUMBER,
                                                 msib.segment1 inventory_item,
                                                 dd.lot_number,
                                                 dd.revision,
                                                 ool.ordered_item,
                                                 MSIB.DESCRIPTION,
                                                 NVL (dd.SHIPPED_QUANTITY,
                                                      OOL.SHIPPED_QUANTITY)
                                                    SHIPPED_QUANTITY,
                                                 SHIP_SU.LOCATION SHIP_TO_CUST,
                                                 BILL_SU.location bill_to_cust,
                                                 hp.PARTY_NAME CUSTOMER_NAME,
                                                 HP.PARTY_ID,
                                                 hcasa.cust_account_id,
                                                 hcasa.cust_acct_site_id,
                                                 bill_hcasa.cust_account_id
                                                    bill_cust_account_id,
                                                 bill_hcasa.cust_acct_site_id
                                                    bill_cust_acct_site_id,
                                                 hl.address1,
                                                 hl.address2,
                                                 hl.address3,
                                                 hl.address4,
                                                 hl.city,
                                                 hl.state,
                                                 HL.COUNTRY,
                                                 HL.POSTAL_CODE,
                                                 ND.NAME SHIPMENT_NUMBER,
                                                 SHIP_METHOD.meaning ship_method
                                            FROM apps.oe_order_headers_all ooh,
                                                 apps.oe_order_lines_all ool,
                                                 apps.FND_LOOKUP_VALUES SHIP_METHOD,
                                                 apps.wsh_delivery_details dd,
                                                 apps.wsh_delivery_assignments da,
                                                 APPS.WSH_NEW_DELIVERIES ND,
                                                 apps.HZ_CUST_SITE_USES_ALL SHIP_SU,
                                                 apps.hz_cust_acct_sites_all hcasa,
                                                 apps.hz_party_sites hps,
                                                 apps.HZ_PARTIES HP,
                                                 apps.hz_locations hl,
                                                 apps.MTL_SYSTEM_ITEMS_B MSIB,
                                                 apps.MTL_PARAMETERS MP,
                                                 apps.HR_OPERATING_UNITS OU,
                                                 apps.HZ_CUST_SITE_USES_ALL BILL_SU,
                                                 apps.hz_cust_acct_sites_all bill_hcasa,
                                                 apps.hz_party_sites bill_hps,
                                                 apps.HZ_PARTIES bill_HP,
                                                /* (SELECT DISTINCT
                                                         request_date sent_date,
                                                         prg.
                                                          USER_CONCURRENT_PROGRAM_NAME,
                                                         TO_NUMBER (
                                                            req.argument1)
                                                            delivery_id
                                                    FROM APPS.
                                                          FND_CONCURRENT_PROGRAMS_TL PRG,
                                                         APPS.
                                                          FND_CONCURRENT_REQUESTS REQ
                                                   WHERE PRG.
                                                          CONCURRENT_PROGRAM_ID =
                                                            REQ.
                                                             CONCURRENT_PROGRAM_ID
                                                         AND PRG.LANGUAGE = 'US'
                                                         AND PRG.
                                                              USER_CONCURRENT_PROGRAM_NAME =
                                                                'XXHA WMS Shipping Notification Program') B,*/
                                                 (  SELECT *
                                                      FROM (SELECT 'Sending Failed'
                                                                      STATUS,
                                                                   TO_CHAR (
                                                                      BE_DETAILS)
                                                                      ERROR_MESSAGE,
                                                                   TO_NUMBER (
                                                                      SUBSTR (
                                                                         BE_DETAILS,
                                                                         53,
                                                                         7))
                                                                      DELIVERY_ID,
                                                                   be_date
                                                              FROM XXHA_BE_SHIP_NOTIF_TAB
                                                             WHERE BE_DETAILS LIKE
                                                                      'Exception occurred while sending email for Delivery:%')
                                                  GROUP BY error_message,
                                                           delivery_id,
                                                           Status,
                                                           be_date) c
                                           WHERE 1 = 1
                                                 AND  trunc(c.be_date) BETWEEN TO_DATE(p_from_date,'YYYY/MM/DD HH24:MI:SS') AND TO_DATE(p_to_date,'YYYY/MM/DD HH24:MI:SS')
--                                                 AND DA.DELIVERY_ID =
--                                                        B.DELIVERY_ID
                                                 AND DA.DELIVERY_ID =
                                                        c.delivery_id
                                               --  AND c.delivery_id = 7224315
                                                 AND OOH.HEADER_ID =
                                                        OOL.HEADER_ID
                                                 AND ool.shipping_method_code =
                                                        ship_method.lookup_code(+)
                                                 AND SHIP_METHOD.LOOKUP_TYPE =
                                                        'SHIP_METHOD'
                                                 AND SHIP_METHOD.LANGUAGE =
                                                        USERENV ('LANG')
                                                 AND OOL.HEADER_ID =
                                                        DD.SOURCE_HEADER_ID
                                                 AND OOL.LINE_ID =
                                                        DD.SOURCE_LINE_ID
                                                 AND OOL.SHIP_FROM_ORG_ID =
                                                        mp.organization_id(+)
                                                 AND DD.DELIVERY_DETAIL_ID =
                                                        DA.DELIVERY_DETAIL_ID
                                                 AND DA.DELIVERY_ID =
                                                        ND.DELIVERY_ID
                                                 AND OOH.SHIP_TO_ORG_ID =
                                                        SHIP_SU.SITE_USE_ID(+)
                                                 AND SHIP_SU.SITE_USE_CODE =
                                                        'SHIP_TO'
                                                 AND ship_su.status = 'A'
                                                 AND dd.source_code = 'OE'
                                                 AND ship_su.cust_acct_site_id =
                                                        hcasa.cust_acct_site_id
                                                 AND hcasa.party_site_id =
                                                        hps.party_site_id
                                                 AND hps.party_id = hp.party_id
                                                 AND hps.location_id =
                                                        hl.location_id
                                                 AND SHIP_SU.org_id =
                                                        ou.organization_id(+)
                                                 AND OOH.invoice_TO_ORG_ID =
                                                        bill_SU.SITE_USE_ID(+)
                                                 AND BILL_SU.SITE_USE_CODE =
                                                        'BILL_TO'
                                                 AND bill_su.status = 'A'
                                                 AND bill_su.cust_acct_site_id =
                                                        bill_hcasa.
                                                         cust_acct_site_id
                                                 AND bill_hcasa.party_site_id =
                                                        bill_hps.party_site_id
                                                 AND bill_hps.party_id =
                                                        bill_hp.party_id
                                                 AND OOL.INVENTORY_ITEM_ID =
                                                        MSIB.INVENTORY_ITEM_ID
                                                 AND OOL.SHIP_FROM_ORG_ID =
                                                        MSIB.ORGANIZATION_ID
                                                 --    AND DA.DELIVERY_ID          IN (6552708)
                                                 AND MSIB.INVENTORY_ITEM_FLAG =
                                                        'Y') AA
                                GROUP BY sent_date,
                                         Status,
                                         error_message,
                                         DELIVERY_ID,
                                         header_id,
                                         line_id,
                                         cert_flag,
                                         email,
                                         fax,
                                         carrier,
                                         carrier_url,
                                         order_number,
                                         cust_po_number,
                                         schedule_ship_date,
                                         tracking_number,
                                         org_id,
                                         line_number,
                                         inventory_item,
                                         revision,
                                         lot_number,
                                         ordered_item,
                                         description,
                                         shipment_number,
                                         ship_method,
                                         ship_to_cust,
                                         bill_to_cust,
                                         customer_name,
                                         party_id,
                                         cust_account_id,
                                         cust_acct_site_id,
                                         bill_cust_account_id,
                                         bill_cust_acct_site_id,
                                         address1,
                                         address2,
                                         address3,
                                         address4,
                                         city,
                                         state,
                                         COUNTRY,
                                         POSTAL_CODE) A
                         WHERE 1 = 1
                      ORDER BY sent_date))
   LOOP
      -- XXHA_BE_SHIP_NOTIF_PKG.XXHA_GET_MAIL_BODY (rc.delivery_id);
      l_request_id := NULL;

      BEGIN
         SELECT DISTINCT organization_id
           INTO l_orgn_id
           FROM wsh_delivery_assignments wda, wsh_delivery_details wdd
          WHERE wda.delivery_id = rc.delivery_id
                AND wda.delivery_detail_id = wdd.delivery_detail_id;
      EXCEPTION
         WHEN OTHERS
         THEN
            DBMS_OUTPUT.
             PUT_LINE (
               'Error occured in retrieving organization ID for delivery ID '
               || rc.delivery_id);
            fnd_file.
             put_line (
               fnd_file.LOG,
               'Error occured in retrieving organization ID for delivery ID '
               || rc.delivery_id);
      END;

      --
      -- Get the Apps Intilization Variables
      --
      BEGIN
         SELECT fresp.responsibility_id, fresp.application_id
           INTO l_resp_id, l_resp_appl_id
           FROM fnd_responsibility_tl fresp
          WHERE 1 = 1
                AND fresp.responsibility_name =
                       'US Order Management Super User OC'
                AND fresp.language = USERENV ('LANG');
      EXCEPTION
         WHEN OTHERS
         THEN
            l_resp_id := NULL;
            l_resp_appl_id := NULL;
      END;

      --Initialize the Apps Variables
      --   l_user_id := TO_NUMBER (fnd_profile.VALUE ('USER_ID')); --fnd_global.user_id;--WEBMETHODS userid
      fnd_global.
       APPS_INITIALIZE (user_id        => l_user_id,
                        resp_id        => l_resp_id,
                        resp_appl_id   => l_resp_appl_id);

      -- Submit the Request
      l_request_id :=
         fnd_request.submit_request ('HAEMO',                    -- Application                                            
                                                     'XXHA_WMS_SHIP_NOTIFICATION', -- Program (i.e. 'XXHA_WSHRDPAK_BCD_US_PTO')
                                                     NULL,                       -- Description
                                                     NULL,                        -- Start Time
                                                     FALSE,                      -- Sub Request
                                                     rc.delivery_id);
      COMMIT;

      fnd_file.put_line(fnd_file.log,'XXHA WMS Shipping Notification Program submitted with request ID '
         || l_request_id);

      IF l_request_id > 0
      THEN
         --waits for the request completion
         l_wait_for_request :=
            fnd_concurrent.wait_for_request (request_id   => l_request_id,
                                             interval     => 60,
                                             max_wait     => 0,
                                             phase        => l_phase,
                                             status       => l_status,
                                             dev_phase    => l_dev_phase,
                                             dev_status   => l_dev_status,
                                             MESSAGE      => l_message);
         COMMIT;
         -- Get the Request Completion Status.
         l_get_request_status :=
            fnd_concurrent.
             get_request_status (request_id       => l_request_id,
                                 appl_shortname   => NULL,
                                 program          => NULL,
                                 phase            => l_phase,
                                 status           => l_status,
                                 dev_phase        => l_dev_phase,
                                 dev_status       => l_dev_status,
                                 MESSAGE          => l_message);
         fnd_file.put_line(fnd_file.log, 'XXHA WMS Shipping Notification Program is '
                                                    || l_dev_phase
                                                    || ' with status '
                                                    || l_dev_status);
      ELSE
         fnd_file.put_line(fnd_file.log, 'XXHA WMS Shipping Notification Program. Error in wait for request.');
      END IF;
   END LOOP;
END;
/

