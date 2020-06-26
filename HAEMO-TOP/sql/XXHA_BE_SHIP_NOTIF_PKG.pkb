CREATE OR REPLACE PACKAGE BODY APPS."XXHA_BE_SHIP_NOTIF_PKG" 
  /*******************************************************************************************************
  * Object Name: XXHA_BE_SHIP_NOTIF_PKG
  * Object Type: PACKAGE
  *
  * Description: This Package will be used shipconfirm business event plsql
  *
  * Modification Log:
  * Developer          Version  Date                 Description
  *-----------------   ---------- ---------------   ------------------------------------------------
  * Apps Associates    v1.0         16-JAN-2015      Initial object creation.
  * Apps Associates    v1.1         20-OCT-2015      Changed packslip report name being printed as per change request. Restricted empty CofC file print
  * Apps Associates    v1.2         02-DEC-2015      Included email address of users
  * Apps Associates    v1.3         10-DEC-2015      Included URL in shipping notification
  * Apps Associates    v1.4         22-JAN-2016      Included Directory name changes. Delete temp table change.
  * Apps Associates    v1.5         14-DEC-2016      Handled PDF size increase in packing slip report due to Logo changes 
  *HCL-Anand            v2.0          03-Jan-2020      Removed Hardcoded for Mail Hostname and Fetched from Profile Options
  *Sethu Nathan        v2.1          17-Jan-2020      Delete existing error records from XXHA_BE_SHIP_NOTIF_TAB during reprocessing
  *******************************************************************************************************/

AS
  L_DELIVERY_ID NUMBER;
  L_SEND_DATE   DATE;
  FUNCTION XXHA_BE_SHIP_NOTIF_FUNC(
      P_SUBSCRIPTION_GUID IN RAW,
      P_EVENT             IN OUT NOCOPY WF_EVENT_T )
    RETURN VARCHAR2
  IS
    L_WF_PARAMETER_LIST_T WF_PARAMETER_LIST_T;
    L_PARAMETER_NAME             VARCHAR2(30);
    L_PARAMETER_VALUE            VARCHAR2(4000);
    N_TOTAL_NUMBER_OF_PARAMETERS INTEGER;
    N_CURRENT_PARAMETER_POSITION NUMBER := 1;
    l_ship_from_org              VARCHAR2(20);
    l_orgn_flag                  VARCHAR2(10);
    l_user_id                    NUMBER         := to_number(fnd_profile.value('USER_ID')); ---30035;   --1706;
    l_resp_id                    NUMBER         := NULL;
    l_resp_appl_id               NUMBER         := NULL;
    l_responsibility_name        VARCHAR2 (255) := 'US Order Management Super User OC';
    l_option_return              BOOLEAN;
    ln_request_id                NUMBER;
    --l_countt number;
  BEGIN

    dbms_output.put_line('DELETE');
    XXHA_BE_SHIP_NOTIF_PRC('Entered email body section8');
    XXHA_BE_SHIP_NOTIF_PRC('DELETE');
    dbms_output.put_line('Entered email body section8');
    L_WF_PARAMETER_LIST_T        := P_EVENT.GETPARAMETERLIST();
    N_TOTAL_NUMBER_OF_PARAMETERS := L_WF_PARAMETER_LIST_T.COUNT();
    XXHA_BE_SHIP_NOTIF_PRC('Name of the event is =>' || P_EVENT.GETEVENTNAME());
    XXHA_BE_SHIP_NOTIF_PRC('Key of the event is =>' || P_EVENT.GETEVENTKEY());
    XXHA_BE_SHIP_NOTIF_PRC('Event Data is =>' || P_EVENT.EVENT_DATA);
    XXHA_BE_SHIP_NOTIF_PRC('Total number of parameters passed to event are =>' || N_TOTAL_NUMBER_OF_PARAMETERS);
    dbms_output.put_line('Name of the event is =>' || P_EVENT.GETEVENTNAME());
    dbms_output.put_line('Key of the event is =>' || P_EVENT.GETEVENTKEY());
    dbms_output.put_line('Event Data is =>' || P_EVENT.EVENT_DATA);
    dbms_output.put_line('Total number of parameters passed to event are =>' || N_TOTAL_NUMBER_OF_PARAMETERS);
    WHILE (N_CURRENT_PARAMETER_POSITION <= N_TOTAL_NUMBER_OF_PARAMETERS)
    LOOP
      L_PARAMETER_NAME  := L_WF_PARAMETER_LIST_T(N_CURRENT_PARAMETER_POSITION) .GETNAME();
      L_PARAMETER_VALUE := L_WF_PARAMETER_LIST_T(N_CURRENT_PARAMETER_POSITION) .GETVALUE();
      XXHA_BE_SHIP_NOTIF_PRC('Parameter Name=>' || L_PARAMETER_NAME || ' has value =>' || L_PARAMETER_VALUE);
      dbms_output.put_line('Parameter Name=>' || L_PARAMETER_NAME || ' has value =>' || L_PARAMETER_VALUE);
      IF L_PARAMETER_NAME    = 'DELIVERY_ID' THEN
        L_DELIVERY_ID       := L_WF_PARAMETER_LIST_T(N_CURRENT_PARAMETER_POSITION) .GETVALUE();
      ELSIF L_PARAMETER_NAME = 'SEND_DATE' THEN
        L_SEND_DATE         := L_WF_PARAMETER_LIST_T(N_CURRENT_PARAMETER_POSITION) .GETVALUE();
      END IF;
      N_CURRENT_PARAMETER_POSITION := N_CURRENT_PARAMETER_POSITION + 1;
    END LOOP;
    XXHA_BE_SHIP_NOTIF_PRC('Completed parameter retrieval loop');
    --Assgin delivery_id to global variable g_delivery_id
    g_delivery_id := L_DELIVERY_ID;
    BEGIN
      SELECT DISTINCT mp.organization_code ,
        xxha_wms_org_validation(mp.organization_code)
      INTO l_ship_from_org ,
        l_orgn_flag
      FROM oe_order_lines_all ool,
        wsh_delivery_details wdd,
        wsh_delivery_assignments wda,
        wsh_new_deliveries wnd,
        mtl_parameters mp
      WHERE 1                    =1
      AND ool.header_id          = wdd.source_header_id
      AND ool.line_id            = wdd.source_line_id
      AND wdd.delivery_detail_id = wda.delivery_detail_id
      AND wda.delivery_id        = wnd.delivery_id
      AND ool.ship_from_org_id   = mp.organization_id
      AND wnd.delivery_id        = l_delivery_id;
      XXHA_BE_SHIP_NOTIF_PRC('Completed getting l_ship_from_org, l_orgn_flag'||l_ship_from_org ||','|| l_orgn_flag);
    EXCEPTION
    WHEN OTHERS THEN
      l_orgn_flag := 'N';
      XXHA_BE_SHIP_NOTIF_PRC('Exception occured in getting organization flag'||SQLERRM);
    END;
    /*Call email body section*/
    IF l_orgn_flag ='Y' -- Organization validation to pick only when function returns Y
      THEN
      BEGIN
        XXHA_BE_SHIP_NOTIF_PRC('Before calling email body section'||L_DELIVERY_ID);
        --    XXHA_GET_MAIL_BODY( L_DELIVERY_ID);
        BEGIN
          SELECT frt.application_id,
            frt.responsibility_id
          INTO l_resp_appl_id,
            l_resp_id
          FROM fnd_responsibility_tl frt
          WHERE frt.LANGUAGE          = 'US'
          AND frt.responsibility_name = l_responsibility_name;
        EXCEPTION
        WHEN NO_DATA_FOUND THEN
          l_resp_appl_id := '';
          l_resp_id      := '';
        END;
        fnd_global.apps_initialize (user_id => l_user_id, resp_id => l_resp_id, resp_appl_id => l_resp_appl_id );
        ln_request_id := fnd_request.submit_request ( 'HAEMO' -- Application
        , 'XXHA_WMS_SHIP_NOTIFICATION'                        -- Program
        , NULL                                                -- Description
        , NULL                                                -- Start Time
        , FALSE                                               -- Sub Request
        , L_DELIVERY_ID                                       -- Delivery ID
        );
        --  COMMIT;
        IF ln_request_id = 0 THEN
          DBMS_OUTPUT.PUT_LINE(SQLCODE||' Error :'||SQLERRM);
        END IF;
        XXHA_BE_SHIP_NOTIF_PRC('After calling email body section');
        --XXHA_BE_SHIP_NOTIF_PRC(ln_request_id);
      EXCEPTION
      WHEN OTHERS THEN
        XXHA_BE_SHIP_NOTIF_PRC('Error occured at calling XXHA_GET_MAIL_BODY'||SQLERRM);
      END;
      /*This need to be at last in the fucntion.*/
      RETURN 'SUCCESS';
    ELSE
      RETURN 'SUCCESS';
    END IF;
  EXCEPTION
  WHEN OTHERS THEN
    XXHA_BE_SHIP_NOTIF_PRC('Unhandled Exception=>' || SQLERRM);
  END XXHA_BE_SHIP_NOTIF_FUNC;
  PROCEDURE XXHA_BE_SHIP_NOTIF_PRC(
      P IN CLOB )
  IS
    PRAGMA AUTONOMOUS_TRANSACTION;
    I INTEGER ;
    l_counttt number; --v1.4
  BEGIN
    IF P ='DELETE' THEN
    BEGIN --v1.4 Added being end block to capture exceptions
      DELETE XXHA_BE_SHIP_NOTIF_TAB
        where be_details not like 'Exception occurred while sending email for Delivery:%'; --V1.3 Added to retain exception related to sending email.    
        select count(1) into l_counttt from XXHA_BE_SHIP_NOTIF_TAB;
    dbms_output.put_line('Completed inserting or deleting with record count left: '||l_counttt);
    exception when others then
    dbms_output.put_line('Exception occured while inserting or deleting with error message: '||SQLERRM);
    END;
    END IF ;

    SELECT XXHA_BE_SHIP_NOTIF_S.NEXTVAL INTO I FROM DUAL ;
    INSERT
    INTO XXHA_BE_SHIP_NOTIF_TAB
      (
        BE_DETAILS,
        BE_SEQ ,
        BE_DATE
      )
      VALUES
      (
        P ,
        I ,
        SYSDATE
      ) ;
    COMMIT ;
  END XXHA_BE_SHIP_NOTIF_PRC;
  PROCEDURE XXHA_GET_MAIL_BODY
    (
      P_DELIVERY_ID IN NUMBER
    )
  AS
    CURSOR P_GET_ORDERS
    IS
      (SELECT DISTINCT ooh.order_number,
        wda.delivery_id,
        ooh.header_id order_header_id
      FROM oe_order_headers_all ooh,
        wsh_delivery_details wdd,
        wsh_delivery_assignments wda
      WHERE 1                    =1
      AND OOH.HEADER_ID          = wDD.SOURCE_HEADER_ID
      AND wDD.DELIVERY_DETAIL_ID = wDA.DELIVERY_DETAIL_ID
      AND wda.delivery_id        = P_DELIVERY_ID
      );
    CURSOR P_GET_DATA(L1_ORDER_HEADER_ID NUMBER)
    IS
      SELECT *
      FROM (
        (SELECT header_id,
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
          SUM(shipped_quantity) shipped_quantity,
          shipment_number,
          ship_method,
          ship_to_cust,
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
          country,
          postal_code
        FROM
          (SELECT ooh.header_id,
            ool.line_id,
            upper(ooh.attribute13) cert_flag,
            ooh.attribute9 email,
            ooh.attribute10 fax,
            (SELECT wc.freight_code
            FROM WSH_CARRIERS wc
            WHERE wc.carrier_id = nd.carrier_id
            ) carrier,
          (SELECT NVL(wc.attribute2,nd.attribute6)
          FROM WSH_CARRIER_SERVICES_V wc
          WHERE wc.carrier_id    = nd.carrier_id
          AND wc.ship_method_code=nd.ship_method_code
          ) carrier_url,
          OOH.ORDER_NUMBER,
          OOH.CUST_PO_NUMBER,
          TO_CHAR(OOL.SCHEDULE_SHIP_DATE,'MMDDYY') SCHEDULE_SHIP_DATE,
          nd.waybill TRACKING_NUMBER,
          dd.org_id,
          OOL.LINE_NUMBER
          ||'.'
          ||OOL.SHIPMENT_NUMBER LINE_NUMBER,
          msib.segment1 inventory_item,
          dd.lot_number,
          dd.revision,
          ool.ordered_item,
          MSIB.DESCRIPTION,
          NVL(dd.SHIPPED_QUANTITY,OOL.SHIPPED_QUANTITY) SHIPPED_QUANTITY,
          OU.name
          ||' - '
          ||SHIP_SU.LOCATION SHIP_TO_CUST,
          hp.PARTY_NAME CUSTOMER_NAME,
          HP.PARTY_ID,
          hcasa.cust_account_id,
          hcasa.cust_acct_site_id,
          bill_hcasa.cust_account_id bill_cust_account_id,
          bill_hcasa.cust_acct_site_id bill_cust_acct_site_id,
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
        FROM apps.oe_order_headers_all ooh ,
          apps.oe_order_lines_all ool ,
          FND_LOOKUP_VALUES SHIP_METHOD,
          apps.wsh_delivery_details dd ,
          apps.wsh_delivery_assignments da ,
          APPS.WSH_NEW_DELIVERIES ND ,
          HZ_CUST_SITE_USES_ALL SHIP_SU ,
          hz_cust_acct_sites_all hcasa,
          hz_party_sites hps,
          HZ_PARTIES HP,
          hz_locations hl,
          MTL_SYSTEM_ITEMS_B MSIB,
          MTL_PARAMETERS MP,
          HR_OPERATING_UNITS OU,
          apps.HZ_CUST_SITE_USES_ALL BILL_SU ,
          apps.hz_cust_acct_sites_all bill_hcasa,
          apps.hz_party_sites bill_hps,
          apps.HZ_PARTIES bill_HP
        WHERE 1                      =1
        AND OOH.HEADER_ID            = OOL.HEADER_ID
        AND ool.shipping_method_code = ship_method.lookup_code(+)
        AND SHIP_METHOD.LOOKUP_TYPE  = 'SHIP_METHOD'
        AND SHIP_METHOD.LANGUAGE     = USERENV('LANG')
        AND OOL.HEADER_ID            = DD.SOURCE_HEADER_ID
        AND OOL.LINE_ID              = DD.SOURCE_LINE_ID
        AND OOL.SHIP_FROM_ORG_ID     = mp.organization_id(+)
        AND DD.DELIVERY_DETAIL_ID    = DA.DELIVERY_DETAIL_ID
        AND DA.DELIVERY_ID           = ND.DELIVERY_ID
        AND OOH.SHIP_TO_ORG_ID       = SHIP_SU.SITE_USE_ID(+)
        AND SHIP_SU.SITE_USE_CODE    = 'SHIP_TO'
        AND ship_su.status           = 'A'
        AND dd.source_code           ='OE'
        AND ship_su.cust_acct_site_id=hcasa.cust_acct_site_id
        AND hcasa.party_site_id      =hps.party_site_id
        AND hps.party_id             = hp.party_id
        AND hps.location_id          =hl.location_id
        AND SHIP_SU.org_id           = ou.organization_id(+)
        AND OOH.invoice_TO_ORG_ID    = bill_SU.SITE_USE_ID(+)
        AND BILL_SU.SITE_USE_CODE    = 'BILL_TO'
        AND bill_su.status           = 'A'
        AND bill_su.cust_acct_site_id=bill_hcasa.cust_acct_site_id
        AND bill_hcasa.party_site_id =bill_hps.party_site_id
        AND bill_hps.party_id        = bill_hp.party_id
        AND OOL.INVENTORY_ITEM_ID    = MSIB.INVENTORY_ITEM_ID
        AND ool.ship_from_org_id     = msib.organization_id
        AND DA.DELIVERY_ID           = P_DELIVERY_ID
        AND OOH.HEADER_ID            = L1_ORDER_HEADER_ID
          --   AND DD.LOT_NUMBER           IS NOT NULL -- To avoid process where lot number is null aaa
        AND msib.inventory_item_flag='Y'
          --      ORDER BY ooh.header_id,
          --        OOL.LINE_ID
          )
        GROUP BY header_id,
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
          country,
          postal_code
        ORDER BY header_id,
          line_id
        ) ) ;
      CURSOR P_GET_COC(L2_ORDER_HEADER_ID NUMBER)
      IS
        (SELECT *
        FROM
          (SELECT DISTINCT ooh.header_id,
            upper(ooh.attribute13) cert_flag,
            MSIB.SEGMENT1 INVENTORY_ITEM,
            dd.lot_number
          FROM apps.oe_order_headers_all ooh ,
            apps.oe_order_lines_all ool ,
            apps.wsh_delivery_details dd ,
            apps.wsh_delivery_assignments da ,
            APPS.WSH_NEW_DELIVERIES ND ,
            MTL_SYSTEM_ITEMS_B MSIB
          WHERE 1                   =1
          AND OOH.HEADER_ID         = OOL.HEADER_ID
          AND OOL.HEADER_ID         = DD.SOURCE_HEADER_ID
          AND OOL.LINE_ID           = DD.SOURCE_LINE_ID
          AND DD.DELIVERY_DETAIL_ID = DA.DELIVERY_DETAIL_ID
          AND DA.DELIVERY_ID        = ND.DELIVERY_ID
          AND OOL.INVENTORY_ITEM_ID = MSIB.INVENTORY_ITEM_ID
          AND OOL.SHIP_FROM_ORG_ID  = MSIB.ORGANIZATION_ID
          AND DA.DELIVERY_ID        = P_DELIVERY_ID
          AND OOH.HEADER_ID         = L2_ORDER_HEADER_ID
          AND DD.LOT_NUMBER        IS NOT NULL -- To avoid process where lot number is null aaa
            --   ORDER BY OOL.LINE_NUMBER
          )
        ) ;
        l_po              VARCHAR(123);
        l_order           VARCHAR2(123);
        l_ship_date       VARCHAR2(20);
        l_subject         VARCHAR(1000);
        l_message         VARCHAR2(32767);
        l_temp            VARCHAR2(3000);
        l_track_num       VARCHAR2(30) ;
        l_ship_to_cust    VARCHAR2(1000);
        l_party_id        NUMBER;
        L_EMAIL_ADDR      VARCHAR2(123);
        L_EMAIL_ADDR1     VARCHAR2(123);
        L_FAX_ADDR        VARCHAR2(123);
        l_to_email        VARCHAR2(123);
        l_address1        VARCHAR2(100);
        l_address2        VARCHAR2(100);
        l_address3        VARCHAR2(100);
        l_address4        VARCHAR2(100);
        l_city            VARCHAR2(100);
        l_state           VARCHAR2(100);
        l_COUNTRY         VARCHAR2(100);
        l_POSTAL_CODE     VARCHAR2(100);
        l_customer_name   VARCHAR2(100);
        l_Shipment_Number VARCHAR2(100);
        l_Tracking_Number VARCHAR2(30);
        l_Carrier         VARCHAR2(100);
        l_Carrier_url     VARCHAR2(250);
        l_Service         VARCHAR2(100);
        L_PATH            VARCHAR2(100);
        l_filename        VARCHAR2(100);
        l_directory_name  VARCHAR2(100); --V1.3
        L_PHONE FND_LOOKUP_VALUES.MEANING%TYPE;
        L_EMAIL FND_LOOKUP_VALUES.MEANING%TYPE;
        L_ORG_ID NUMBER;
        to_array array;
        l_smtp_host varchar2(50);
        i NUMBER;
        CURSOR cur_logistics(p_id NUMBER, p_site_id NUMBER)
        IS
          SELECT DISTINCT hprel.EMAIL_ADDRESS EMAIL_ADDR
          FROM HZ_CUST_ACCOUNT_ROLES hcar,
            HZ_PARTIES hpsub,
            HZ_PARTIES hprel,
            HZ_ORG_CONTACTS hoc,
            HZ_RELATIONSHIPS hr,
            HZ_PARTY_SITES hps,
            FND_TERRITORIES_VL ftv
            --FND_LOOKUP_VALUES_VL LOOKUPS
          WHERE 1                                    =1
          AND HCAR.CUST_ACCOUNT_ID                   = p_id      --226383
          AND hcar.CUST_ACCT_SITE_ID                 = p_site_id --84601
          AND hcar.ROLE_TYPE                         = 'CONTACT'
          AND hcar.PARTY_ID                          = hr.PARTY_ID
          AND hr.PARTY_ID                            = hprel.PARTY_ID
          AND hr.SUBJECT_ID                          = hpsub.PARTY_ID
          AND hoc.PARTY_RELATIONSHIP_ID              = hr.RELATIONSHIP_ID
          AND hr.DIRECTIONAL_FLAG                    = 'F'
          AND hps.PARTY_ID(+)                        = hprel.PARTY_ID
          AND NVL(hps.IDENTIFYING_ADDRESS_FLAG, 'Y') = 'Y'
          AND NVL(hps.STATUS, 'A')                   = 'A'
          AND hprel.COUNTRY                          = ftv.TERRITORY_CODE(+)
            --  AND lookups.LOOKUP_TYPE (+)                ='RESPONSIBILITY'
            --AND LOOKUPS.LOOKUP_CODE(+)                 =HOC.JOB_TITLE_CODE
          AND UPPER(HOC.JOB_TITLE)    = UPPER('Logistics')
          AND HCAR.CUST_ACCT_SITE_ID IS NOT NULL
          AND hcar.status             = 'A' ;
        crlf VARCHAR2 (2)            := CHR (13) || CHR (10);
        l_countt number; --V1.4 
      BEGIN
            --Start: V2.1 Delete record from XXHA_BE_SHIP_NOTIF_TAB table for reprocessing
            BEGIN
                DELETE FROM XXHA_BE_SHIP_NOTIF_TAB 
                 WHERE be_details like 'Exception occurred while sending email for Delivery:%' 
                     AND TO_NUMBER (SUBSTR (BE_DETAILS,53,7)) = p_delivery_id;
            EXCEPTION
            WHEN OTHERS THEN
                fnd_file.put_line(fnd_file.log,'Exception occurred when deleting from error table: '||SQLERRM);
            END;
            --End V2.1
            --Start: V1.4 Clear the debug table when executed from concurrent program.
            XXHA_BE_SHIP_NOTIF_PRC('DELETE');
            BEGIN
              select count(1) into l_countt from XXHA_BE_SHIP_NOTIF_TAB;
              dbms_output.put_line('Completed inserting or deleting with record count left: '||l_countt);
            exception when others then
              dbms_output.put_line('Exception occured while inserting or deleting with error message: '||SQLERRM);
            END;
            --End: V1.4 Clear the debug table when executed from concurrent program.

        --   --deleted the existing records to load only new COCs
        --     DELETE from XXHA_COC_BLOB_TAB;
        --deleted the existing records to load only new COCs for delivery. It has to be out of coc proc to avoid deleting of new records.
        DELETE
        FROM XXHA_COC_BLOB_TAB
        WHERE DELIVERY_ID = p_delivery_id
        AND file_name LIKE 'Certificate_Of_Compliance%';
        --validation if g_delivery_id is assigned with delivery_id
        IF g_delivery_id IS NULL THEN
          g_delivery_id  := p_delivery_id;
        END IF;
        DBMS_OUTPUT.PUT_LINE('Entered get email body section');
        XXHA_BE_SHIP_NOTIF_PRC('Entered get email body section');
        FOR P_GET_ORDERS_REC IN P_GET_ORDERS
        LOOP
          BEGIN
            DBMS_OUTPUT.PUT_LINE('Entered P_GET_ORDERS_REC');
            XXHA_BE_SHIP_NOTIF_PRC('Entered P_GET_ORDERS_REC');
            FOR P_GET_COC_REC IN P_GET_COC(P_GET_ORDERS_REC.ORDER_HEADER_ID)
            LOOP
              IF(P_GET_COC_REC.cert_flag = 'Y') THEN
                BEGIN -- callinf COC web method and storing records in custom blob table for each record(item-lot) against delivery id.
                  XXHA_BE_SHIP_NOTIF_PRC('Before calling coc_pdf proc for Item, Lot:' ||P_GET_COC_REC.inventory_item||','||P_GET_COC_REC.lot_number);
                  dbms_output.put_line('Before calling coc_pdf proc for Item, Lot:' ||P_GET_COC_REC.inventory_item||','||P_GET_COC_REC.lot_number);
                  XXHA_COC_PDF_PRC( p_delivery_id, P_GET_COC_REC.header_id,-- Added to process for each order header_id
                  P_GET_COC_REC.inventory_item, P_GET_COC_REC.lot_number, 'mixed'
                  --P_CLOB   OUT CLOB,
                  --P_BLOB   OUT BLOB
                  );
                  XXHA_BE_SHIP_NOTIF_PRC('After calling coc_pdf proc');
                  dbms_output.put_line('After calling coc_pdf proc');
                END;
              ELSE
                XXHA_BE_SHIP_NOTIF_PRC('No COC pdf retrieved as cert flag attribute13 is not Yes');
                dbms_output.put_line('No COC pdf retrieved as cert flag attribute13 is not Yes');
              END IF;
            END LOOP;
            BEGIN
              /*This block calls Packslip report calling procedure and captures generated pdf output file name and directory path*/
              BEGIN
                /*This block is to delete the existing packslip re*/
                DELETE
                FROM XXHA_COC_BLOB_TAB
                WHERE delivery_id   = P_DELIVERY_ID
                AND order_header_id = P_GET_ORDERS_REC.ORDER_HEADER_ID
                AND file_name LIKE 'Packing Slip.pdf%'; --V1.3 Changes as file name is changes to 'Packing Slip.pdf'
                --AND file_name LIKE 'XXHA_WSHRDPAK_US%'; --V1.3
              EXCEPTION
              WHEN OTHERS THEN
                NULL;
              END;
              XXHA_SUBMIT_PACKSLIP_REPORT(P_DELIVERY_ID, L_PATH, L_FILENAME);
              XXHA_BE_SHIP_NOTIF_PRC(L_PATH ||','||L_FILENAME);
              dbms_output.put_line(L_PATH ||','||L_FILENAME);
            EXCEPTION
            WHEN OTHERS THEN
              XXHA_BE_SHIP_NOTIF_PRC('Exception in Packslip report calling procedure - '||SQLERRM);
              dbms_output.put_line('Exception in Packslip report calling procedure - '||SQLERRM);
            END;
            BEGIN
              /*This block calls procedure to capture pdf output file generated in custom table*/
                BEGIN
                /*This block get directory name for pdf output file generated*/ --V1.3
                select DECODE(instr(L_PATH,'_haemt71')
                              ,0 ,'XXHA_CONCPRG_OUTPUT1','XXHA_CONCPRG_OUTPUT') direcotry_name
                 into l_directory_name                       
                from dual;
                  XXHA_BE_SHIP_NOTIF_PRC('l_directory_name - '||l_directory_name);
                  dbms_output.put_line('l_directory_name - '||l_directory_name);                
                EXCEPTION
                WHEN OTHERS THEN
                  XXHA_BE_SHIP_NOTIF_PRC('Exception in Procedure to get directory name - '||SQLERRM);
                  dbms_output.put_line('Exception in Procedure to get directory name - '||SQLERRM);                
                END;

              --XXHA_GET_PACKSLIP_PDF('XXHA_CONCPRG_OUTPUT',L_FILENAME, P_GET_ORDERS_REC.ORDER_HEADER_ID, p_delivery_id); --v1.3
              XXHA_GET_PACKSLIP_PDF(L_DIRECTORY_NAME,L_FILENAME, P_GET_ORDERS_REC.ORDER_HEADER_ID, p_delivery_id); --v1.3
            EXCEPTION
            WHEN OTHERS THEN
              XXHA_BE_SHIP_NOTIF_PRC('Exception in Procedure to capture packslip report pdf file - '||SQLERRM);
              dbms_output.put_line('Exception in Procedure to capture packslip report pdf file - '||SQLERRM);
            END;
            FOR P_GET_DATA_REC IN P_GET_DATA(P_GET_ORDERS_REC.ORDER_HEADER_ID)
            LOOP
              l_party_id   := P_GET_DATA_REC.party_id;
              g_to_email   := P_GET_DATA_REC.email;
              g_to_fax     := P_GET_DATA_REC.fax;
              L_EMAIL_ADDR :=NULL;
              L_EMAIL_ADDR1:=NULL;
              BEGIN
                SELECT DISTINCT hprel.EMAIL_ADDRESS EMAIL_ADDR
                INTO L_EMAIL_ADDR
                FROM HZ_CUST_ACCOUNT_ROLES hcar,
                  HZ_PARTIES hpsub,
                  HZ_PARTIES hprel,
                  HZ_ORG_CONTACTS hoc,
                  HZ_RELATIONSHIPS hr,
                  HZ_PARTY_SITES hps,
                  FND_TERRITORIES_VL ftv
                  --FND_LOOKUP_VALUES_VL LOOKUPS
                WHERE 1                                    =1
                AND HCAR.CUST_ACCOUNT_ID                   = P_GET_DATA_REC.CUST_ACCOUNT_ID   --226383
                AND hcar.CUST_ACCT_SITE_ID                 = P_GET_DATA_REC.cust_acct_site_id --84601
                AND hcar.ROLE_TYPE                         = 'CONTACT'
                AND hcar.PARTY_ID                          = hr.PARTY_ID
                AND hr.PARTY_ID                            = hprel.PARTY_ID
                AND hr.SUBJECT_ID                          = hpsub.PARTY_ID
                AND hoc.PARTY_RELATIONSHIP_ID              = hr.RELATIONSHIP_ID
                AND hr.DIRECTIONAL_FLAG                    = 'F'
                AND hps.PARTY_ID(+)                        = hprel.PARTY_ID
                AND NVL(hps.IDENTIFYING_ADDRESS_FLAG, 'Y') = 'Y'
                AND NVL(hps.STATUS, 'A')                   = 'A'
                AND hprel.COUNTRY                          = ftv.TERRITORY_CODE(+)
                  --  AND lookups.LOOKUP_TYPE (+)                ='RESPONSIBILITY'
                  --AND LOOKUPS.LOOKUP_CODE(+)                 =HOC.JOB_TITLE_CODE
                AND UPPER(HOC.JOB_TITLE)    = UPPER('Logistics')
                AND HCAR.CUST_ACCT_SITE_ID IS NOT NULL
                AND hcar.status             = 'A'
                AND rownum                  =1;
              EXCEPTION
              WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Retrieved email_addr'||L_EMAIL_ADDR||SQLERRM);
                XXHA_BE_SHIP_NOTIF_PRC('Retrieved email_addr'||L_EMAIL_ADDR||SQLERRM);
              END;
              BEGIN
                SELECT DISTINCT hprel.EMAIL_ADDRESS EMAIL_ADDR
                INTO L_EMAIL_ADDR
                FROM HZ_CUST_ACCOUNT_ROLES hcar,
                  HZ_PARTIES hpsub,
                  HZ_PARTIES hprel,
                  HZ_ORG_CONTACTS hoc,
                  HZ_RELATIONSHIPS hr,
                  HZ_PARTY_SITES hps,
                  FND_TERRITORIES_VL ftv
                  --FND_LOOKUP_VALUES_VL LOOKUPS
                WHERE 1                                    =1
                AND HCAR.CUST_ACCOUNT_ID                   = P_GET_DATA_REC.bill_CUST_ACCOUNT_ID   --226383
                AND hcar.CUST_ACCT_SITE_ID                 = P_GET_DATA_REC.bill_cust_acct_site_id --84601
                AND hcar.ROLE_TYPE                         = 'CONTACT'
                AND hcar.PARTY_ID                          = hr.PARTY_ID
                AND hr.PARTY_ID                            = hprel.PARTY_ID
                AND hr.SUBJECT_ID                          = hpsub.PARTY_ID
                AND hoc.PARTY_RELATIONSHIP_ID              = hr.RELATIONSHIP_ID
                AND hr.DIRECTIONAL_FLAG                    = 'F'
                AND hps.PARTY_ID(+)                        = hprel.PARTY_ID
                AND NVL(hps.IDENTIFYING_ADDRESS_FLAG, 'Y') = 'Y'
                AND NVL(hps.STATUS, 'A')                   = 'A'
                AND hprel.COUNTRY                          = ftv.TERRITORY_CODE(+)
                  --  AND lookups.LOOKUP_TYPE (+)                ='RESPONSIBILITY'
                  --AND LOOKUPS.LOOKUP_CODE(+)                 =HOC.JOB_TITLE_CODE
                AND UPPER(HOC.JOB_TITLE)    = UPPER('Logistics')
                AND HCAR.CUST_ACCT_SITE_ID IS NOT NULL
                AND hcar.status             = 'A'
                AND rownum                  =1;
              EXCEPTION
              WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Retrieved email_addr'||L_EMAIL_ADDR||SQLERRM);
                XXHA_BE_SHIP_NOTIF_PRC('Retrieved email_addr'||L_EMAIL_ADDR||SQLERRM);
              END;
              to_array := array();
              to_array.EXTEND(10);
              BEGIN
                IF L_EMAIL_ADDR IS NOT NULL THEN
                  i             :=1;
                  FOR rec_logistics IN cur_logistics(P_GET_DATA_REC.CUST_ACCOUNT_ID,P_GET_DATA_REC.cust_acct_site_id)
                  LOOP
                    to_array(i):=rec_logistics.EMAIL_ADDR;
                    XXHA_BE_SHIP_NOTIF_PRC('Email Address 1'||to_array(i));
                    i :=i+1;
                  END LOOP;
                  FOR rec_logistics IN cur_logistics(P_GET_DATA_REC.bill_CUST_ACCOUNT_ID,P_GET_DATA_REC.bill_cust_acct_site_id)
                  LOOP
                    to_array(i):=rec_logistics.EMAIL_ADDR;
                    XXHA_BE_SHIP_NOTIF_PRC('Email Address 1'||to_array(i));
                    i :=i+1;
                  END LOOP;
                  IF g_to_email IS NOT NULL THEN
                    --   to_array(1) := L_EMAIL_ADDR;
                    to_array(i) := g_to_email;
                    --l_to_email:= L_EMAIL_ADDR || ' , '||g_to_email;
                  ELSif g_to_email IS NULL THEN
                    IF g_to_fax    IS NOT NULL THEN
                      --l_to_email:= L_EMAIL_ADDR || ' , '||g_to_fax||'@efaxsend.com';
                      --    to_array(1) := L_EMAIL_ADDR;
                      to_array(i) := g_to_fax||'@efaxsend.com';
                    END IF;
                  END IF;
                ELSIF L_EMAIL_ADDR IS NULL THEN
                  IF g_to_email    IS NOT NULL THEN
                    --l_to_email:= g_to_email;
                    to_array(1)    := g_to_email;
                  ELSif g_to_email IS NULL THEN
                    IF g_to_fax    IS NOT NULL THEN
                      --l_to_email:= g_to_fax||'@efaxsend.com';
                      to_array(1) := g_to_fax||'@efaxsend.com';
                    END IF;
                  END IF;
                END IF;
                XXHA_BE_SHIP_NOTIF_PRC('Email Address 2'||to_array(2));
              EXCEPTION
              WHEN OTHERS THEN
                XXHA_BE_SHIP_NOTIF_PRC('Exception occured at to_email_addr. Before Entering send email'||SQLERRM);
                dbms_output.put_line('Exception occured at to_email_addr. Before Entering send email'||SQLERRM);
              END;
              dbms_output.put_line('Entered email body section');
              XXHA_BE_SHIP_NOTIF_PRC('Entered email body section');
              l_order        := P_GET_DATA_rec.order_number;
              l_po           := P_GET_DATA_rec.cust_po_number;
              l_ship_date    := P_GET_DATA_rec.SCHEDULE_SHIP_DATE;
              l_ship_to_cust := P_GET_DATA_rec.ship_to_cust;
              l_track_num    := P_GET_DATA_rec.TRACKING_NUMBER;
              l_org_id       := P_GET_DATA_rec.ORG_ID;
              l_subject      := 'SHIPMENT CONFIRMATION OF HAEMONETICS SALES ORDER ' || P_GET_DATA_rec.order_number || ' - THANK YOU FOR YOUR ORDER.';
              XXHA_BE_SHIP_NOTIF_PRC('After getting header details on order, email subject::'||l_subject);
              XXHA_BE_SHIP_NOTIF_PRC( 'Order number:' ||P_GET_DATA_rec.order_number||', PO Number: ' ||P_GET_DATA_rec.cust_po_number ||', Scheduled Ship Date: ' ||P_GET_DATA_rec.SCHEDULE_SHIP_DATE||', Description: ' ||p_get_data_rec.DESCRIPTION||', Ship to Customer: ' ||P_GET_DATA_rec.SHIP_TO_CUST||', Order line# ' ||P_GET_DATA_rec.line_number||', Ordered Item: ' ||P_GET_DATA_rec.ordered_item||', Shipped Quantity: ' ||P_GET_DATA_rec.shipped_quantity);
              dbms_output.put_line('After getting header details on order, email subject::'||l_subject);
              dbms_output.put_line( 'Order number:' ||P_GET_DATA_rec.order_number||', PO Number: ' ||P_GET_DATA_rec.cust_po_number ||', Scheduled Ship Date: ' ||P_GET_DATA_rec.SCHEDULE_SHIP_DATE||', Description: ' ||p_get_data_rec.DESCRIPTION||', Ship to Customer: ' ||P_GET_DATA_rec.SHIP_TO_CUST||', Order line# ' ||P_GET_DATA_rec.line_number||', Ordered Item: ' ||P_GET_DATA_rec.ordered_item||', Shipped Quantity: ' ||P_GET_DATA_rec.shipped_quantity);
              /* l_temp := l_temp
              ||substr(P_GET_DATA_rec.line_number,1,11)|| substr('           ',1,11-length(P_GET_DATA_rec.line_number))
              ||substr(P_GET_DATA_rec.ordered_item,1,28)|| substr('                            ',1,28-length(P_GET_DATA_rec.ordered_item))
              ||substr(p_get_data_rec.DESCRIPTION,1,44)|| substr('                                            ',1,44-length(P_GET_DATA_rec.DESCRIPTION))
              ||P_GET_DATA_rec.shipped_quantity||CHR(13); */
              l_temp := l_temp ||SUBSTR(NVL(TO_CHAR(P_GET_DATA_rec.line_number),' '),1,11)|| SUBSTR('           ',1,11-LENGTH(NVL(TO_CHAR(P_GET_DATA_rec.line_number),' '))) ||'&nbsp&nbsp&nbsp&nbsp'||SUBSTR(NVL(P_GET_DATA_rec.ordered_item,' '),1,28)|| '&nbsp&nbsp&nbsp&nbsp'||SUBSTR('                            ',1,28-LENGTH(NVL(P_GET_DATA_rec.ordered_item,' '))) ||'&nbsp&nbsp&nbsp&nbsp'||SUBSTR(NVL(p_get_data_rec.DESCRIPTION,' '),1,44)||'&nbsp&nbsp&nbsp&nbsp'|| SUBSTR('                                            ',1,44-LENGTH(NVL(P_GET_DATA_rec.DESCRIPTION,' '))) ||'&nbsp&nbsp&nbsp&nbsp'||SUBSTR(NVL(TO_CHAR(P_GET_DATA_rec.shipped_quantity),' '),1,12)||SUBSTR('            ',1,12-LENGTH(NVL(TO_CHAR(P_GET_DATA_rec.shipped_quantity),' '))) ||CHR(13)|| '<BR>';
              --||substr(nvl(to_char(P_GET_DATA_rec.SHIPMENT_NUMBER),' '),1,25)||substr('                         ',1,25-length(nvl(to_char(P_GET_DATA_rec.SHIPMENT_NUMBER),' ')))
              --||substr(nvl(P_GET_DATA_rec.ship_method,' '),1,30)||substr('                              ',1,30-length(nvl(P_GET_DATA_rec.ship_method,' ')))
              --||substr(nvl(P_GET_DATA_rec.TRACKING_NUMBER,' '),1,30)||substr('                              ',1,30-length(nvl(P_GET_DATA_rec.TRACKING_NUMBER,' ')))
              --||CHR(13);
              XXHA_BE_SHIP_NOTIF_PRC('After getting line details on order');
              dbms_output.put_line('After getting line details on order');
              l_address1        := P_GET_DATA_rec.address1;
              l_address2        := P_GET_DATA_rec.address2;
              l_address3        := P_GET_DATA_rec.address3;
              l_address4        := P_GET_DATA_rec.address4;
              l_city            := P_GET_DATA_rec.city;
              l_state           := P_GET_DATA_rec.state;
              l_COUNTRY         := P_GET_DATA_rec.COUNTRY;
              l_POSTAL_CODE     := P_GET_DATA_rec.postal_code;
              l_customer_name   := P_GET_DATA_rec.CUSTOMER_NAME;
              l_Shipment_Number := P_GET_DATA_rec.SHIPMENT_NUMBER;
              l_Tracking_Number := P_GET_DATA_rec.TRACKING_NUMBER;
              l_Carrier         := P_GET_DATA_rec.carrier;
              l_Carrier_url     := P_GET_DATA_rec.carrier_url;
              l_Service         := P_GET_DATA_rec.ship_method;
            END LOOP;
            XXHA_BE_SHIP_NOTIF_PRC('before getting footer details of email');
            dbms_output.put_line('before getting footer details of email');
            l_message := l_message|| '<html>' || '<body>' || '<BR>';
            l_message := l_message|| CHR(13) || 'As a valued customer we thank you for your order.'|| '<BR>'|| '<BR>';
            l_message := l_message|| CHR(13) || 'Sales Order : '||l_order||'<BR>';
            l_message := l_message|| CHR(13) || 'Purchase Order : '||l_po|| '<BR>';
            --l_message := l_message|| CHR(13);
            --l_message := 'Purchase order number '|| l_po || ' under Haemonetics sales order '||l_order ||' has been shipped on '|| l_ship_date ||' via Conway on the following tracking number(s). You can track your shipment by either copying and pasting the URL into your browser or by copying the tracking number into the tracking page of the appropriate transport carrier.'||CHR(13);
            --l_message := l_message|| CHR(13) || l_track_num || CHR(13);
            --l_message :=  l_message ||  CHR(13) || 'Line #     Line Item                   Line Description                            Ship Qty' || CHR(13);
            --l_message ||  CHR(13) || 'Line #     Line Item                   Line Description                            Ship Qty     Shipment Number          ship method                   Tracking Number'|| CHR(13);
            l_message     := l_message|| CHR(13) || 'Customer Name  : '||l_customer_name|| '<BR>';
            l_message     := l_message || CHR(13) ||'Customer Ship to Address  : ';
            IF l_address1 IS NOT NULL THEN
              l_message   := l_message || l_address1 ||', ';
            END IF;
            IF l_address2 IS NOT NULL THEN
              l_message   := l_message || l_address2 ||', ';
            END IF;
            IF l_address3 IS NOT NULL THEN
              l_message   := l_message || l_address3 ||', ';
            END IF;
            IF l_address4 IS NOT NULL THEN
              l_message   := l_message || l_address4 ||', ';
            END IF;
            l_message := l_message || l_city||', '||l_state||', '||l_COUNTRY||', '||l_POSTAL_CODE||CHR(13)|| '<BR>'|| '<BR>';
            l_message := l_message|| CHR(13) || 'Shipment Number  : '||l_Shipment_Number|| '<BR>';
            l_message := l_message|| CHR(13) || 'Tracking Number  : '||l_Tracking_Number|| '<BR>';
            l_message := l_message|| CHR(13) || 'Carrier  : '||l_Carrier|| '<BR>';
            l_message := l_message|| CHR(13) || 'Service  : '||l_Service|| '<BR>';
            l_message := l_message|| CHR(13) || 'URL  : '||l_Carrier_url||CHR(13)|| '<BR>'|| '<BR>';
            l_message := l_message|| CHR(13) || 'Line #&nbsp&nbsp&nbsp&nbsp Line Item #&nbsp&nbsp&nbsp&nbsp Line Description #&nbsp&nbsp&nbsp&nbsp Ship Qty'|| '<BR>';
            l_message := l_message|| CHR(13) || l_temp || CHR(13)|| '<BR>'|| '<BR>';
            l_message := l_message|| CHR(13) || 'Please review the attached shipping documentation and contact Haemonetics Customer Service if you have any questions.'|| '<BR>';
            l_message := l_message|| CHR(13) || 'Included on the Shipping Notification is a link to the Haemonetics Terms and Conditions.'||CHR(13)|| '<BR>'|| '<BR>';
            BEGIN
              SELECT FLV.MEANING
              INTO L_PHONE
              FROM FND_LOOKUP_VALUES FLV,
                HR_OPERATING_UNITS OU
              WHERE 1                =1
              AND ou.organization_id = l_org_id
              AND FLV.LOOKUP_CODE LIKE '%'
                ||OU.ORGANIZATION_ID
                ||'%'
              AND FLV.LOOKUP_TYPE='XXHA_CUST_SERVICE_DET'
              AND FLV.LOOKUP_CODE LIKE '%PHONE'
              AND FLV.LANGUAGE = USERENV('LANG') ;
              SELECT FLV.MEANING
              INTO L_EMAIL
              FROM FND_LOOKUP_VALUES FLV,
                HR_OPERATING_UNITS OU
              WHERE 1                =1
              AND ou.organization_id = l_org_id
              AND FLV.LOOKUP_CODE LIKE '%'
                ||OU.ORGANIZATION_ID
                ||'%'
              AND FLV.LOOKUP_TYPE='XXHA_CUST_SERVICE_DET'
              AND FLV.LOOKUP_CODE LIKE '%EMAIL'
              AND FLV.LANGUAGE = USERENV('LANG') ;
            EXCEPTION
            WHEN OTHERS THEN
              DBMS_OUTPUT.PUT_LINE('Error occured in getting customer service contact details.');
            END;
            BEGIN
              IF (L_PHONE IS NULL OR L_EMAIL IS NULL) THEN
                SELECT FLV.MEANING
                INTO L_PHONE
                FROM FND_LOOKUP_VALUES FLV,
                  HR_OPERATING_UNITS OU
                WHERE 1     =1
                AND ou.NAME = 'Haemonetics Corp US OU'
                AND FLV.LOOKUP_CODE LIKE '%'
                  ||OU.ORGANIZATION_ID
                  ||'%'
                AND FLV.LOOKUP_TYPE='XXHA_CUST_SERVICE_DET'
                AND FLV.LOOKUP_CODE LIKE '%PHONE'
                AND FLV.LANGUAGE = USERENV('LANG') ;
                --end if;
                --IF L_EMAIL is null then
                SELECT FLV.MEANING
                INTO L_EMAIL
                FROM FND_LOOKUP_VALUES FLV,
                  HR_OPERATING_UNITS OU
                WHERE 1     =1
                AND ou.NAME = 'Haemonetics Corp US OU'
                AND FLV.LOOKUP_CODE LIKE '%'
                  ||OU.ORGANIZATION_ID
                  ||'%'
                AND FLV.LOOKUP_TYPE='XXHA_CUST_SERVICE_DET'
                AND FLV.LOOKUP_CODE LIKE '%EMAIL'
                AND FLV.LANGUAGE = USERENV('LANG') ;
              END IF;
            EXCEPTION
            WHEN OTHERS THEN
              DBMS_OUTPUT.PUT_LINE('Error occured in defaulting customer service contact details to US operating Unit.');
            END;
            l_message := l_message|| CHR(13) || '    Customer Service Phone: '||L_PHONE|| '<BR>';
            l_message := l_message|| CHR(13) || '    Customer Service Email: '||L_EMAIL|| CHR(13)|| '<BR>'|| '<BR>';
            l_message := l_message || CHR(13) || 'We look forward to serving you in the future.'|| '<BR>';
            l_message := l_message || CHR(13) || 'Thank you.'|| '<BR>';
            l_message := l_message || CHR(13) || 'Haemonetics Customer Service Team'||CHR(13)||CHR(13)|| '<BR>'|| '<BR>'|| '<BR>';
            l_message := l_message || CHR(13) || 'Information contained in this e-mail is confidential and is intended for the use of the addressee only. Any dissemination, distribution, copying or use of this communication without prior permission of the addressee is strictly prohibited. If you are not the intended addressee, please notify customerservicena@haemonetics.com immediately by reply and then delete this message from your computer system.' ||CHR(13);
            l_message := l_message || 'Compliance Certificate(s) are attached. If you have any questions regarding the attached documents, please contact your customer service representative' ||CHR(13);
            l_message := l_message||'</body>'||'</html>';
            dbms_output.put_line(l_message);   -- added this to check the current message being printed.
            XXHA_BE_SHIP_NOTIF_PRC(l_message); -- added this to check the current message being printed.
            XXHA_BE_SHIP_NOTIF_PRC('after getting footer details of order.');
            /*Block to call send email procedure*/
            BEGIN
              XXHA_BE_SHIP_NOTIF_PRC('Before Entering send email');
               l_smtp_host := XXHA_FND_UTIL_PKG.get_ip_address; --  Fetching SMTP Host from Profile option 03Jan2020
               IF (l_smtp_host is NULL) then
                   fnd_file.put_line(fnd_file.log,'SMTP Host Does not Exist');
             END IF;
              dbms_output.put_line('Before Entering send email');
              -- Added below hardcoded condition for testing. Need to remove after testing.
              --L_EMAIL_ADDR := 'ohmesh.suraj@haemonetics.com'; --aaaa
              --L_EMAIL_ADDR := 'ohmesh.suraj@haemonetics.com';
              dbms_output.put_line('g_to_email L_EMAIL_ADDR VALUE - '||g_to_email||','||L_EMAIL_ADDR);
              xxha_send_mail_attach_pdfs ( p_to => to_array, --'ohmesh.suraj@haemonetics.com',
              p_from => 'ASNNA@Haemonetics.com', p_subject => l_subject, p_text_msg => l_message,
              --p_attach_name IN VARCHAR2 DEFAULT NULL,
              p_attach_mime => 'application/pdf',
              --p_attach_blob IN BLOB DEFAULT NULL,
              --p_smtp_host => 'smtp-bo.haemo.net',
              p_smtp_host => l_smtp_host,
              p_smtp_port => 25, p_order_header_id => P_GET_ORDERS_REC.ORDER_HEADER_ID, p_delivery_id => P_DELIVERY_ID);
              l_message := NULL; -- This is to avoid email body to get appended in other email being sent.
              l_temp    := NULL; -- This is to avoid email body with line contents to get appended in other email being sent.
              XXHA_BE_SHIP_NOTIF_PRC('message data after sending email - '||l_message);
              dbms_output.put_line('message data after sending email - '||l_message);
            EXCEPTION
            WHEN OTHERS THEN
              dbms_output.put_line('Error occured while calling xxha_send_mail_attach_pdfs:: '||SQLERRM);
              XXHA_BE_SHIP_NOTIF_PRC('Error occured while calling xxha_send_mail_attach_pdfs:: '||SQLERRM);
            END;
          EXCEPTION
          WHEN OTHERS THEN
            XXHA_BE_SHIP_NOTIF_PRC('Exception occured in get_orders loop'||SQLERRM);
            dbms_output.put_line('Exception occured in get orders loop'||SQLERRM);
          END;
        END LOOP;
      EXCEPTION
      WHEN OTHERS THEN
        dbms_output.put_line('Error occured IN XXHA_GET_MAIL_BODY:: '||SQLERRM);
        XXHA_BE_SHIP_NOTIF_PRC('Error occured IN XXHA_GET_MAIL_BODY:: '||SQLERRM);
      END XXHA_GET_MAIL_BODY;
      PROCEDURE XXHA_COC_PDF_PRC(
          p_delivery_id     IN NUMBER,
          p_order_header_id IN NUMBER,
          p_item_no         IN VARCHAR2,
          p_lot_no          IN VARCHAR2,
          p_template        IN VARCHAR2 --, P_CLOB OUT CLOB , P_BLOB OUT BLOB
        )
      IS
        reqlength NUMBER;
        eob       BOOLEAN := false;
        l_http_request UTL_HTTP.req;
        l_http_response UTL_HTTP.resp;
        op_status_code NUMBER;
        request_env    VARCHAR2 (32767);
        request_env1   VARCHAR2 (32767);
        request_env2   VARCHAR2 (32767);
        request_env3   VARCHAR2 (32767);
        response_env   VARCHAR2 (32767);
        eof            BOOLEAN;
        buffer RAW(32767);
        buffer1 CLOB;
        l_output    VARCHAR2 (32767);
        l_key_str   NUMBER := 0;
        l_err_count NUMBER;
        l_count     NUMBER;
        l_blob BLOB;
        l_clob CLOB;
        p_blob BLOB;
        p_clob CLOB;
        l_text VARCHAR2(32767);
        l_substr_clob CLOB;
        L_START       NUMBER;
        L_END         NUMBER;
        L_length      NUMBER;
        L_SUBSTR_TEXT VARCHAR2(32767);
        l_max         NUMBER := 32767;
        L_CURRVAL     NUMBER;
        L_FUNC_BLOB BLOB;
        l_func_clob CLOB;
        l_pos PLS_INTEGER := 1;
        l_buffer RAW( 32767 );
        l_buffer64 RAW( 32767 );
        l_lob_len PLS_INTEGER          := DBMS_LOB.getLength( l_func_clob );
        l_request_context VARCHAR2(10) := 'POST';
        --pragma autonomous_transaction;
      BEGIN
        /*
        --deleted the existing records to load only new COCs
        DELETE
        FROM XXHA_COC_BLOB_TAB
        WHERE DELIVERY_ID = G_DELIVERY_ID and order_header_id = p_order_header_id;
        */
        BEGIN -- START send request - get response
          dbms_output.put_line('Entered CoC procedure in ship notif');
          request_env  := '<?xml version="1.0" encoding="utf-8"?><soapenv:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"              
xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:erp="http://bos-tiburon/ERPCertOfCompl.retrieve"><soapenv:Header/><soapenv:Body><erp:CertificateRetrieverByTemplate              
soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><itemNo xsi:type="xsd:string">$STRING1</itemNo><lotNo xsi:type="xsd:string">$STRING2</lotNo><template xsi:type="xsd:string">$STRING3</template></erp:CertificateRetrieverByTemplate></soapenv:Body></soapenv:Envelope>';
          request_env1 := REPLACE (request_env, '$STRING1', p_item_no);
          request_env3 := REPLACE (request_env1, '$STRING2', p_lot_no);
          request_env2 := REPLACE (request_env3, '$STRING3', p_template);
          XXHA_BE_SHIP_NOTIF_PRC('p_item_no:'||p_item_no||','||'p_lot_no:'||p_lot_no||','||'p_template:'||p_template||'.');
          dbms_output.put_line('p_item_no:'||p_item_no||','||'p_lot_no:'||p_lot_no||','||'p_template:'||p_template||'.');
          l_http_request := UTL_HTTP.begin_request ('http://haewebmmt101.haemo.net:5555/soap/rpc', l_request_context, UTL_HTTP.http_version_1_1 );
          UTL_HTTP.set_header (l_http_request, 'Content-Type', 'text/xml; charset=utf-8');
          UTL_HTTP.set_header (l_http_request, 'Content-Length', LENGTH (request_env2));
          UTL_HTTP.set_header (l_http_request, 'SOAPAction', '"http://bos-tiburon/ERPCertOfCompl.retrieve/CertificateRetrieverByTemplate"' );
          UTL_HTTP.write_text (l_http_request, request_env2);
          --delete existing records in custom table  XXHA_COC_CLOB_TAB
          dbms_output.put_line('delete existing records in custom table  XXHA_COC_CLOB_TAB');
          DELETE
          FROM XXHA_COC_CLOB_TAB
          WHERE DELIVERY_ID   = p_delivery_id
          AND order_header_id = p_order_header_id;
          -- Initialize the CLOB.
          DBMS_LOB.createtemporary(l_clob, FALSE);
          l_http_response := UTL_HTTP.get_response (l_http_request);
          -- Copy the response into the CLOB.
          WHILE NOT(eob)
          LOOP
            BEGIN
              UTL_HTTP.read_text(l_http_response, l_text, 32767);
              IF l_text IS NOT NULL AND LENGTH(l_text)>0 THEN
                DBMS_LOB.writeappend (l_clob, LENGTH(l_text), l_text);
              END IF;
            EXCEPTION
            WHEN UTL_HTTP.END_OF_BODY THEN
              eob := true;
            END;
          END LOOP;
          reqlength := dbms_lob.getlength(l_clob);
          XXHA_BE_SHIP_NOTIF_PRC ('reqlength: ' || reqlength);
          dbms_output.put_line ('reqlength: ' || reqlength);
          --Insert the data into the table
          INSERT
          INTO XXHA_COC_CLOB_TAB VALUES
            (
              XXHA_COC_CLOB_S.NEXTVAL,
              p_order_header_id,
              p_delivery_id, --G_DELIVERY_ID,
              l_clob
            );
          SELECT XXHA_COC_CLOB_S.CURRVAL INTO L_CURRVAL FROM DUAL;
          XXHA_BE_SHIP_NOTIF_PRC ('L_CURRVAL: ' || L_CURRVAL);
          dbms_output.put_line ('L_CURRVAL: ' || L_CURRVAL);
          --Load clob value to OUT parameter.
          --P_CLOB := l_clob;
          --commit;
          -- Relase the resources associated with the temporary LOB
          DBMS_LOB.freetemporary(l_clob);
          UTL_HTTP.end_response(l_http_response);
        EXCEPTION
        WHEN UTL_HTTP.TOO_MANY_REQUESTS THEN
          dbms_output.put_line('UTL_HTTP.TOO_MANY_REQUESTS Error occured in calling CoC web method: '||SQLERRM);
          UTL_HTTP.END_RESPONSE(l_http_response);
          UTL_HTTP.DESTROY_REQUEST_CONTEXT(l_request_context);
        WHEN OTHERS THEN
          UTL_HTTP.end_response(l_http_response);
          -- Relase the resources associated with the temporary LOB.
          DBMS_LOB.freetemporary(l_clob);
          UTL_HTTP.DESTROY_REQUEST_CONTEXT(l_request_context);
          --RAISE;
          dbms_output.put_line('Error occured in calling CoC web method: '||SQLERRM);
        END;  -- END send request - get response
        BEGIN -- START substr response CLOB
          -- Initialize the CLOB.
          DBMS_LOB.CREATETEMPORARY(l_substr_clob, false);
          -- Get the substr binary data from response CLOB.
          SELECT DBMS_LOB.INSTR( CLOB_DATA, 'id1">' )+5,
            DBMS_LOB.INSTR( CLOB_DATA, '</byteArray>' )
          INTO L_START,
            L_END
          FROM XXHA_COC_CLOB_TAB
          WHERE SNO       =L_CURRVAL;
          L_LENGTH       := (L_END-L_START);
          WHILE (L_length >0)
          LOOP
            BEGIN
              IF (L_LENGTH < 32767) THEN
                L_MAX     := L_LENGTH;
              END IF;
              XXHA_BE_SHIP_NOTIF_PRC(L_START||','||l_max||','||L_LENGTH);
              dbms_output.put_line(L_START||','||l_max||','||L_LENGTH);
              SELECT SUBSTR(CLOB_DATA, L_START, l_max)
              INTO L_SUBSTR_TEXT
              FROM XXHA_COC_CLOB_TAB
              WHERE SNO         =L_CURRVAL;
              IF L_SUBSTR_TEXT IS NOT NULL AND LENGTH(L_SUBSTR_TEXT)>0 THEN
                DBMS_LOB.WRITEAPPEND (l_substr_clob, LENGTH(L_SUBSTR_TEXT), L_SUBSTR_TEXT);
              END IF;
              L_START    := L_START+L_MAX;
              IF l_length < 32767 THEN
                l_length :=0;
              END IF;
              L_LENGTH := L_LENGTH -L_MAX;
            END;
          END LOOP;
          --insert substr clob into custom table.
          INSERT
          INTO XXHA_COC_CLOB_TAB VALUES
            (
              XXHA_COC_CLOB_S.nextval,
              p_order_header_id,
              p_delivery_id,
              l_substr_clob
            );
          SELECT XXHA_COC_CLOB_S.CURRVAL INTO L_CURRVAL FROM DUAL;
          XXHA_BE_SHIP_NOTIF_PRC ('L_CURRVAL2: ' || L_CURRVAL);
          dbms_output.put_line ('L_CURRVAL2: ' || L_CURRVAL);
          COMMIT;
          P_CLOB := l_substr_clob;
          -- Relase the resources associated with the temporary LOB.
          DBMS_LOB.FREETEMPORARY(l_substr_clob);
        EXCEPTION
        WHEN OTHERS THEN
          XXHA_BE_SHIP_NOTIF_PRC('Error occured:'||SQLERRM);
          dbms_output.put_line('Error occured:'||SQLERRM);
          -- Relase the resources associated with the temporary LOB.
          DBMS_LOB.freetemporary(l_substr_clob);
          RAISE;
        END; -- START substr response CLOB
        BEGIN-- typecasts CLOB to BLOB (binary conversion)
          XXHA_BE_SHIP_NOTIF_PRC('Start calling PDF func and L_CURRVAL:'||L_CURRVAL);
          dbms_output.put_line('Start calling PDF func and L_CURRVAL:'||L_CURRVAL);
          SELECT CLOB_DATA INTO l_func_clob FROM XXHA_COC_CLOB_TAB WHERE SNO=L_CURRVAL;
          XXHA_BE_SHIP_NOTIF_PRC('Step2');
          dbms_output.put_line('Step2');
          L_FUNC_BLOB:= XXHA_BE_SHIP_NOTIF_PKG.xxha_c2b_64(l_func_clob);
          P_BLOB     := L_FUNC_BLOB;
          INSERT
          INTO XXHA_COC_BLOB_TAB VALUES
            (
              XXHA_COC_BLOB_s.nextval,
              p_order_header_id,
              p_delivery_id,
              'Certificate Of Compliance',
              P_BLOB
            );
          SELECT XXHA_COC_BLOB_s.CURRVAL
          INTO L_CURRVAL
          FROM DUAL;
          XXHA_BE_SHIP_NOTIF_PRC ('L_CURRVAL3 blob: ' || L_CURRVAL);
          dbms_output.put_line ('L_CURRVAL3 blob: ' || L_CURRVAL);
          COMMIT;
          XXHA_BE_SHIP_NOTIF_PRC('End calling PDF func');
          dbms_output.put_line('End calling PDF func');
        END;-- typecasts CLOB to BLOB (binary conversion)
      END XXHA_COC_PDF_PRC;
    FUNCTION xxha_c2b_64(
        c IN CLOB )
      RETURN BLOB
      -- typecasts CLOB to BLOB (binary conversion)
    IS
      pos PLS_INTEGER := 1;
      buffer RAW( 32767 );
      buffer64 RAW( 32767 );
      res BLOB;
      lob_len PLS_INTEGER := DBMS_LOB.getLength( c );
    BEGIN
      DBMS_LOB.createTemporary( res, TRUE );
      DBMS_LOB.OPEN( res, DBMS_LOB.LOB_ReadWrite );
      LOOP
        buffer                       := UTL_RAW.cast_to_raw( DBMS_LOB.SUBSTR( c, 78, pos ) );
        buffer64                     := UTL_ENCODE.base64_decode (buffer);
        IF UTL_RAW.LENGTH( buffer64 ) > 0 THEN
          DBMS_LOB.writeAppend( res, UTL_RAW.LENGTH( buffer64 ), buffer64 );
        END IF;
        pos := pos + 78;
        EXIT
      WHEN pos > lob_len;
      END LOOP;
      RETURN RES; -- res is OPEN here
    END xxha_C2B_64;
  PROCEDURE xxha_send_mail_attach_pdfs(
      p_to IN array DEFAULT array(
      ),
      p_from     IN VARCHAR2,
      p_subject  IN VARCHAR2,
      p_text_msg IN VARCHAR2 DEFAULT NULL,
      --p_attach_name IN VARCHAR2 DEFAULT NULL,
      p_attach_mime IN VARCHAR2 DEFAULT NULL,
      --p_attach_blob IN BLOB DEFAULT NULL,
      p_smtp_host       IN VARCHAR2,
      p_smtp_port       IN NUMBER DEFAULT 25,
      p_order_header_id IN NUMBER,
      p_delivery_id     IN NUMBER )
  AS
    p_attach_name VARCHAR2(123);
    p_attach_blob BLOB;
    --    l_mail_conn UTL_SMTP.connection;
    l_boundary VARCHAR2(50) := '----=*#abc1234321cba#*=';
    l_step PLS_INTEGER      := 12000; -- make sure you set a multiple of 3 not higher than 24573
    CURSOR cur(lc_delivery_id NUMBER, lc_order_header_id NUMBER)
    IS
      (SELECT FILE_NAME,
        DELIVERY_ID,
        blob_data file_data,
        LENGTH(blob_data) len_coc
      FROM XXHA_COC_BLOB_TAB
      WHERE DELIVERY_ID     = lc_delivery_id
      AND ORDER_HEADER_ID   = lc_order_header_id
      AND LENGTH(blob_data) > 1000 -- v1.1 Restrict empty CofC file attachment
      ) ;
    crlf         VARCHAR2 (2) := CHR (13) || CHR (10);
    mesg         VARCHAR2 (32767);
    boundary     CONSTANT VARCHAR2 (256) := 'CES.Boundary.DACA587499938898';
    i            NUMBER                  :=0;
    l_prod_flag  VARCHAR2(10);
    l_test_email VARCHAR2(123);
    l_to_list LONG;
    to_array array;
  BEGIN
    l_mail_conn := UTL_SMTP.open_connection(p_smtp_host, p_smtp_port);
    UTL_SMTP.helo(l_mail_conn, p_smtp_host);
    UTL_SMTP.mail(l_mail_conn, p_from);
    BEGIN
      SELECT xxha_prod_db INTO l_prod_flag FROM dual;
      --SELECT XXHA_GET_TEST_EMAIL_ADDRESS INTO l_test_email FROM dual;
     --V2.0Fetching Recepient value from Lookup XXHA_TEST_MAIL on 03jan2020
    SELECT XXHA_FND_UTIL_PKG.get_recipients INTO l_test_email FROM dual;
    EXCEPTION
    WHEN OTHERS THEN
      XXHA_BE_SHIP_NOTIF_PRC('Prod flag capture.'||SQLERRM);
      dbms_output.put_line('Prod flag capture.'||SQLERRM);
    END;
    IF ( l_prod_flag = 'N') THEN
      --UTL_SMTP.rcpt(l_mail_conn, l_to_list);
      --l_to_list  := address_email( 'To: ', p_to );
      --    l_test_email:=l_test_email||', '||'pwheeler@haemonetics.com';
      --    l_to_list   := address_email( 'To: ', array(l_test_email) );
      to_array := array();
      to_array.EXTEND(4);
      to_array(1):= l_test_email;
      -- v2.0 Below Code Commented for SMTP Host name change by Anand on 03Jan2020 
      --to_array(2):= 'pwheeler@haemonetics.com'; -- need to uncomment after testing
      --to_array(3):= 'MBerrada@haemonetics.com';
      --to_array(4):= 'LZimmerman@Haemonetics.com';    
      l_to_list := address_email( 'To: ', to_array );
      dbms_output.put_line('l_to_list NP- '||l_to_list);
    ELSE
      l_to_list := address_email( 'To: ', p_to );
      dbms_output.put_line('l_to_list P- '||l_to_list);
    END IF;
    XXHA_BE_SHIP_NOTIF_PRC('Testing'||l_to_list);
    XXHA_BE_SHIP_NOTIF_PRC('Before utl_smtp open data');
    dbms_output.put_line('Before utl_smtp open data');
    UTL_SMTP.open_data(l_mail_conn);
    --mesg        := 'Date: ' || TO_CHAR (SYSDATE, 'dd Mon yy hh24:mi:ss') || crlf || 'From: ' || P_FROM || crlf || 'Subject: ' || P_subject || crlf || 'To: ' || P_TO || crlf;
    --mesg := mesg || 'Mime-Version: 1.0' || crlf || 'Content-Type: multipart/mixed; boundary="' || boundary || '"' || crlf || crlf || 'This is a Mime message, which your current mail reader may not' || crlf || 'understand. Parts of the message will appear as text. If the remainder' || crlf || 'appears as random characters in the message body, instead of as' || crlf || 'attachments, then you''ll have to extract these parts and decode them' || crlf || 'manually.' || crlf || crlf;
    --UTL_SMTP.write_data (L_MAIL_CONN, mesg);
    UTL_SMTP.write_data(l_mail_conn, 'Date: ' || TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI:SS') || UTL_TCP.crlf);
    XXHA_BE_SHIP_NOTIF_PRC('To email address: l_test_email, p_to'||l_test_email||','||l_to_list);
    dbms_output.put_line('To email address: l_test_email, p_to '||l_test_email||','||l_to_list);
    UTL_SMTP.write_data(l_mail_conn, 'To: ' || l_to_list || UTL_TCP.crlf);
    dbms_output.put_line('l_to_list - '||l_to_list);
    UTL_SMTP.write_data(l_mail_conn, 'From: ' || '"Haemonetics Shipment Notification" <ASNNA@Haemonetics.com>' || UTL_TCP.crlf);
    UTL_SMTP.write_data(l_mail_conn, 'Subject: ' || p_subject || UTL_TCP.crlf);
    UTL_SMTP.write_data(l_mail_conn, 'Reply-To: ' || p_from || UTL_TCP.crlf);
    UTL_SMTP.write_data(l_mail_conn, 'MIME-Version: 1.0' || UTL_TCP.crlf);
    UTL_SMTP.write_data(l_mail_conn, 'Content-Type: multipart/mixed; boundary="' || l_boundary || '"' || UTL_TCP.crlf || UTL_TCP.crlf);
    IF p_text_msg IS NOT NULL THEN
      UTL_SMTP.write_data(l_mail_conn, '--' || l_boundary || UTL_TCP.crlf);
      UTL_SMTP.write_data(l_mail_conn, 'Content-Type: text/html; charset="iso-8859-1"' || UTL_TCP.crlf || UTL_TCP.crlf);
      UTL_SMTP.write_data(l_mail_conn, p_text_msg);
      UTL_SMTP.write_data(l_mail_conn, UTL_TCP.crlf || UTL_TCP.crlf);
    END IF;
    IF p_attach_name IS NOT NULL THEN
      UTL_SMTP.write_data(l_mail_conn, '--' || l_boundary || UTL_TCP.crlf);
      UTL_SMTP.write_data(l_mail_conn, 'Content-Type: ' || p_attach_mime || '; name="' || p_attach_name || '"' || UTL_TCP.crlf);
      UTL_SMTP.write_data(l_mail_conn, 'Content-Transfer-Encoding: base64' || UTL_TCP.crlf);
      UTL_SMTP.write_data(l_mail_conn, 'Content-Disposition: attachment; filename="' || p_attach_name || '"' || UTL_TCP.crlf || UTL_TCP.crlf);
    END IF;
    i := 0;                                          -- to append with COC file name.
    FOR rec IN cur(p_delivery_id, p_order_header_id) --g_delivery_id
    LOOP
      XXHA_BE_SHIP_NOTIF_PRC('Inside COC file name append loop');
      dbms_output.put_line('Inside COC file name append loop');
      i := i+1;
      /*This is to handle PDF file names*/
      IF ( rec.file_name = 'Certificate Of Compliance') THEN
        p_attach_name   := rec.file_name||i||'.pdf';
      ELSE
        p_attach_name := rec.file_name;
      END IF;
      p_attach_blob    := rec.file_data;
      IF p_attach_name IS NOT NULL THEN
        UTL_SMTP.write_data(l_mail_conn, '--' || l_boundary || UTL_TCP.crlf);
        UTL_SMTP.write_data(l_mail_conn, 'Content-Type: ' || p_attach_mime || '; name="' || p_attach_name || '"' || UTL_TCP.crlf);
        UTL_SMTP.write_data(l_mail_conn, 'Content-Transfer-Encoding: base64' || UTL_TCP.crlf);
        UTL_SMTP.write_data(l_mail_conn, 'Content-Disposition: attachment; filename="' || p_attach_name || '"' || UTL_TCP.crlf || UTL_TCP.crlf);
        FOR i IN 0 .. TRUNC((DBMS_LOB.getlength(p_attach_blob) - 1 )/l_step)
        LOOP
          --XXHA_BE_SHIP_NOTIF_PRC('Inside COC pdf attach loop');
          UTL_SMTP.write_data(l_mail_conn, UTL_RAW.cast_to_varchar2(UTL_ENCODE.base64_encode(DBMS_LOB.substr(p_attach_blob, l_step, i * l_step + 1))));
        END LOOP;
        UTL_SMTP.write_data(l_mail_conn, UTL_TCP.crlf || UTL_TCP.crlf);
      END IF;
    END LOOP;
    UTL_SMTP.write_data(l_mail_conn, '--' || l_boundary || '--' || UTL_TCP.crlf);
    UTL_SMTP.close_data(l_mail_conn);
    UTL_SMTP.quit(l_mail_conn);
    XXHA_BE_SHIP_NOTIF_PRC('Completed sending email');
    dbms_output.put_line('Completed sending email');
  EXCEPTION
  WHEN OTHERS THEN
--    XXHA_BE_SHIP_NOTIF_PRC('Exception occured while sending email'||SQLERRM);--v1.3
--    dbms_output.put_line('Exception occured while sending email'||SQLERRM);--v1.3
    XXHA_BE_SHIP_NOTIF_PRC('Exception occurred while sending email for Delivery:'||p_delivery_id||'. Exception message is: '||SQLERRM);--v1.3
    dbms_output.put_line('Exception occurred while sending email for Delivery:'||p_delivery_id||'. Exception message is: '||SQLERRM);--v1.3

  END xxha_send_mail_attach_pdfs;
  PROCEDURE xxha_submit_packslip_report(
      p_delivery_id IN NUMBER,
      p_directory_path OUT VARCHAR2,
      p_file_name OUT VARCHAR2)
  AS
    l_user_id fnd_user.user_id%TYPE;
    l_resp_id fnd_responsibility.responsibility_id%TYPE;
    l_resp_appl_id fnd_application.application_id%TYPE;
    l_set_layout         BOOLEAN;
    l_request_id         NUMBER;
    l_messase            VARCHAR2(2000);
    l_phase              VARCHAR2 (100);
    l_status             VARCHAR2 (100);
    l_dev_phase          VARCHAR2 (100);
    l_dev_status         VARCHAR2 (100);
    l_option_return      BOOLEAN := FALSE;
    l_wait_for_request   BOOLEAN := FALSE;
    l_get_request_status BOOLEAN := FALSE;
    l_directory_path     VARCHAR2 (100);
    l_file_name          VARCHAR2 (100);
    l_orgn_id            NUMBER;
  BEGIN
    l_request_id := NULL;
    BEGIN
      SELECT DISTINCT organization_id
      INTO l_orgn_id
      FROM wsh_delivery_assignments wda,
        wsh_delivery_details wdd
      WHERE wda.delivery_id      = p_delivery_id
      AND wda.delivery_detail_id = wdd.delivery_detail_id;
    EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('Error occured in retrieving organization ID for delivery ID '||p_delivery_id);
      fnd_file.put_line(fnd_file.log, 'Error occured in retrieving organization ID for delivery ID '||p_delivery_id);
    END;
    --
    -- Get the Apps Intilization Variables
    --
    BEGIN
      SELECT fresp.responsibility_id,
        fresp.application_id
      INTO l_resp_id,
        l_resp_appl_id
      FROM fnd_responsibility_tl fresp
      WHERE 1                       =1
      AND fresp.responsibility_name = 'US Order Management Super User OC'
      AND fresp.language            = userenv('LANG');
    EXCEPTION
    WHEN OTHERS THEN
      l_resp_id      :=NULL;
      l_resp_appl_id := NULL;
    END;
    --Initialize the Apps Variables
    l_user_id := to_number(fnd_profile.value('USER_ID'));--fnd_global.user_id;--WEBMETHODS userid
    fnd_global.APPS_INITIALIZE (user_id => l_user_id, resp_id => l_resp_id, resp_appl_id => l_resp_appl_id);
    -- set noprint option.
    l_option_return := fnd_request.set_print_options (printer => 'noprint', style => 'Portrait', copies => 0 );
    IF l_option_return THEN
      -- Set the Layout  for BI Publisher Report
      l_set_layout := fnd_request.add_layout (template_appl_name => 'HAEMO', template_code => 'XXHA_WSHRDPAK_US',
      --Data Template Code
      template_language => 'en', template_territory => 'US', output_format => 'PDF');
      IF l_set_layout THEN
        -- Submit the Request
        l_request_id := fnd_request.submit_request ( 'HAEMO' -- Application
        , 'XXHA_WSHRDPAK_US'                                 -- Program (i.e. 'XXHA_WSHRDPAK_BCD_US_PTO')
        , NULL                                               -- Description
        , NULL                                               -- Start Time
        , FALSE                                              -- Sub Request
        , l_orgn_id , p_delivery_id , 'N' , 'D' , 'DRAFT' , 'BOTH' , 'INV' , NULL , NULL , NULL , 3 , 'Y' , NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL , NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL , NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL , NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL , NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL , NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL , NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL , NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL , NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL );
        COMMIT;
        XXHA_BE_SHIP_NOTIF_PRC('XXHA Packing Slip Report US submitted with request ID '||l_request_id);
        dbms_output.put_line('XXHA Packing Slip Report US submitted with request ID '||l_request_id);
        IF l_request_id > 0 THEN
          --waits for the request completion
          l_wait_for_request := fnd_concurrent.wait_for_request (request_id => l_request_id, interval => 60, max_wait => 0, phase => l_phase, status => l_status, dev_phase => l_dev_phase, dev_status => l_dev_status, MESSAGE => l_messase);
          COMMIT;
          -- Get the Request Completion Status.
          l_get_request_status := fnd_concurrent.get_request_status ( request_id => l_request_id, appl_shortname => NULL, program => NULL, phase => l_phase, status => l_status, dev_phase => l_dev_phase, dev_status => l_dev_status, MESSAGE => l_messase );
          dbms_output.put_line('XXHA Packing Slip Report US is '||l_dev_phase || ' with status '||l_dev_status );
          XXHA_BE_SHIP_NOTIF_PRC('XXHA Packing Slip Report US is '||l_dev_phase || ' with status '||l_dev_status );
        ELSE
          XXHA_BE_SHIP_NOTIF_PRC('XXHA Packing Slip Report US. Error in wait for request.' );
          dbms_output.put_line('XXHA Packing Slip Report US. Error in wait for request.' );
        END IF;
      ELSE
        XXHA_BE_SHIP_NOTIF_PRC('XXHA Packing Slip Report US. Error in assigning layout' );
        dbms_output.put_line('XXHA Packing Slip Report US. Error in assigning layout' );
      END IF;
    ELSE
      XXHA_BE_SHIP_NOTIF_PRC('XXHA Packing Slip Report US. Error while setting printer' );
      dbms_output.put_line('XXHA Packing Slip Report US. Error while setting printer' );
    END IF;
    BEGIN
      SELECT SUBSTR(FILE_NAME, 1, INSTR(FILE_NAME,'XXHA_WSHRDPAK_US')         -1) DIRECTORY_PATH,
        SUBSTR(FILE_NAME,INSTR(FILE_NAME,'XXHA_WSHRDPAK_US'),LENGTH(FILE_NAME)-INSTR(FILE_NAME,'XXHA_WSHRDPAK_US')+1 )FILE_NAME
      INTO l_directory_path,
        l_file_name
      FROM FND_CONC_REQ_OUTPUTS o
      WHERE concurrent_request_id = l_request_id;
      XXHA_BE_SHIP_NOTIF_PRC('Directory path'||l_directory_path||' and file name '||l_file_name);
      dbms_output.put_line('Directory path'||l_directory_path||' and file name '||l_file_name);
      p_directory_path := l_directory_path;
      p_file_name      := l_file_name;
    EXCEPTION
    WHEN OTHERS THEN
      XXHA_BE_SHIP_NOTIF_PRC('Error occured while getting directory patrh and file name for pack slip'||SQLERRM);
      dbms_output.put_line('Error occured while getting directory patrh and file name for pack slip'||SQLERRM);
    END;
  EXCEPTION
  WHEN OTHERS THEN
    XXHA_BE_SHIP_NOTIF_PRC ('ERROR:' ||SQLERRM);
    dbms_output.put_line ('ERROR:' ||SQLERRM);
  END;
  PROCEDURE xxha_get_packslip_pdf(
      p_directory       VARCHAR2,
      p_file_name       VARCHAR2,
      p_order_header_id NUMBER,
      p_delivery_id     NUMBER)
  IS
    l_infile utl_file.file_type;
    l_packslip_pdf BLOB;
    L_SRC_FILE bfile := BFILENAME(p_directory, p_file_name);
    L_LENGTH_FILE BINARY_INTEGER;
    L_DEST_FILE blob;

  BEGIN
  -- Start v1.5
    XXHA_BE_SHIP_NOTIF_PRC('Started xxha_get_packslip_pdf');
    dbms_output.put_line('Started xxha_get_packslip_pdf');
    INSERT
    INTO XXHA_COC_BLOB_TAB VALUES
      (
        XXHA_COC_BLOB_s.nextval,
        p_order_header_id,
        g_delivery_id,
        'Packing Slip.pdf', --p_file_name, -- v1.1 Packing Slip report output filename changed to 'Packing Slip'
        EMPTY_BLOB ()
      )
    RETURNING BLOB_DATA
    INTO l_DeST_FILE;
    DBMS_LOB.open(L_SRC_FILE, DBMS_LOB.FILE_READONLY);
    L_LENGTH_FILE := DBMS_LOB.GETLENGTH(L_SRC_FILE);
    DBMS_LOB.LOADFROMFILE(L_DEST_FILE, L_SRC_FILE, L_LENGTH_FILE);
    DBMS_LOB.close(L_SRC_FILE);
    COMMIT;
    XXHA_BE_SHIP_NOTIF_PRC('Completed xxha_get_packslip_pdf');
    dbms_output.put_line('Completed xxha_get_packslip_pdf');

/*    XXHA_BE_SHIP_NOTIF_PRC('Started xxha_get_packslip_pdf');
    dbms_output.put_line('Started xxha_get_packslip_pdf');
    -- open a file to read
    l_infile := utl_file.fopen( p_directory, p_file_name, 'RB');
    XXHA_BE_SHIP_NOTIF_PRC('Opened the file - '||p_file_name);
    dbms_output.put_line('Opened the file - '||p_file_name);
    -- check file is opened
    IF utl_file.is_open(l_infile) THEN
      BEGIN
        utl_file.GET_RAW(l_infile, l_packslip_pdf);
      EXCEPTION
      WHEN NO_DATA_FOUND THEN
        XXHA_BE_SHIP_NOTIF_PRC('Exception in file reading:'|| SQLERRM);
        dbms_output.put_line('Exception in file reading:'|| SQLERRM);
      END;
      BEGIN
        INSERT
        INTO XXHA_COC_BLOB_TAB VALUES
          (
            XXHA_COC_BLOB_s.nextval,
            p_order_header_id,
            g_delivery_id,
            'Packing Slip.pdf', --p_file_name, -- v1.1 Packing Slip report output filename changed to 'Packing Slip'
            l_packslip_pdf
          );
        COMMIT;
      EXCEPTION
      WHEN OTHERS THEN
        XXHA_BE_SHIP_NOTIF_PRC('Exception in insert command'|| SQLERRM);
        dbms_output.put_line('Exception in insert command'|| SQLERRM);
      END;
    END IF;
    utl_file.fclose(l_infile);
    XXHA_BE_SHIP_NOTIF_PRC('Completed xxha_get_packslip_pdf');
    dbms_output.put_line('Completed xxha_get_packslip_pdf');
  */
  -- End v1.5

EXCEPTION
  WHEN OTHERS THEN
    XXHA_BE_SHIP_NOTIF_PRC('Exception in proc :'|| SQLERRM);
    dbms_output.put_line('Exception in proc :'|| SQLERRM);
  END xxha_get_packslip_pdf;
  FUNCTION address_email
    (
      p_string     IN VARCHAR2,
      p_recipients IN array
    )
    RETURN VARCHAR2
  IS
    l_recipients LONG;
  BEGIN
    FOR i IN 1 .. p_recipients.count
    LOOP
      dbms_output.put_line
      (
        'inside address function - email'||i||':'||p_recipients(i)
      )
      ;
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
END XXHA_BE_SHIP_NOTIF_PKG;
/

