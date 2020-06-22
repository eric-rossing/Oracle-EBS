CREATE OR REPLACE TRIGGER APPS.XXHA_WM_VOIDDELDET_TRG
  /*******************************************************************************************************
  * Object Name: XXHA_WM_VOIDDELDET_TRG
  * Object Type: TRIGGER
  *
  * Description: This TRIGGER will be used in void xml process
  *
  * Modification Log:
  * Developer         Version     Date                 Description
  *----------------   -------     -------------        ------------------------------------------------
  * Apps Associates     v1.0          16-JAN-2015          Initial object creation.
  * Apps Associates     v1.1          16-OCT-2015          As per change request modified shipping hold to 
  * Apps Associates     v1.2          02-DEC-2015          Included email address WMSShippingHoldUSW@Haemonetics.com
  * Apps Associates     v1.3          02-FEB-2016          Included organization_id condition
  * Apps Associates     v1.4          25-APR-2016          Modified logic of to_email based on prod/ non prod using lookup type XXHA_WMS_ORGS
  * Sethu Nathan        v1.5          09-JAN-2020           Removed hardcoding of SMTP hostname and fetched it from profile. Incident INC0321180
  *******************************************************************************************************/
  
  AFTER
  INSERT OR
  UPDATE ON "WSH"."WSH_DELIVERY_ASSIGNMENTS" FOR EACH ROW
DECLARE p_rec_wm_trackChange wm_trackchanges%ROWTYPE;
  c_transaction_type   VARCHAR2(100):='VOID';
  p_delivery_id        NUMBER;
  p_delivery_detail_id NUMBER;
  l_tc_exist           NUMBER;
  l_exception          VARCHAR2(2000);
  l_assign_type        VARCHAR2(20);
  l_subject            VARCHAR2(2000);
  l_message            VARCHAR2(3000);
  l_order_number oe_order_headers_all.order_number%type;
  l_header_id NUMBER;
  l_line_id   NUMBER;
  l_line_number oe_order_lines_all.line_number%type;
  l_ordered_item oe_order_lines_all.ordered_item%type;
  l_nodata        VARCHAR2(1) DEFAULT 'N';
  v_return_status VARCHAR2(30);
  v_msg_data      VARCHAR2(4000);
  v_msg_count     NUMBER;
  v_hold_source_rec OE_HOLDS_PVT.HOLD_SOURCE_REC_TYPE;
  v_hold_id          NUMBER;  --DEFAULT 1001;                                  --v1.1 commented default of hold id for shipping hold
  v_hold_entity_code VARCHAR2(10) DEFAULT 'O';
  V_HEADER_ID        NUMBER;
  V_line_id          NUMBER;
  l_orgn_id          NUMBER;    -- v1.3
  l_prod_flag           VARCHAR2(10);  --v1.4
  l_test_email_addr    VARCHAR2(100); --v1.4
  l_send_email_addr    VARCHAR2(100); --v1.4
  l_host_name   VARCHAR2(300); --v1.5
  CURSOR oe_lines(p_header_id IN NUMBER, p_orgn_id IN NUMBER) --v1.3
  IS
    SELECT line_id,
      header_id
    FROM oe_order_lines_all ool,
      wsh_delivery_details wdd
    WHERE ool.header_id      = p_header_id
    AND ool.ship_from_org_id = p_orgn_id                    --v1.3
    AND ool.header_id        = wdd.source_header_id
    AND ool.line_id          = wdd.source_line_id
    AND wdd.released_status <> 'C'; -- C -- shipped
  v_msg_index_out NUMBER;
BEGIN
  IF (:OLD.delivery_id IS NOT NULL AND :NEW.delivery_id IS NULL) OR (:OLD.delivery_id IS NULL AND :NEW.delivery_id IS NOT NULL) THEN
    BEGIN --v1.1 Added to get hold_ID of hold 'WMS Void Shipping Hold'
      SELECT hold_id into v_hold_id 
      FROM OE_HOLD_DEFINITIONS 
      WHERE name = 'WMS Void Shipping Hold';
    EXCEPTION
    WHEN OTHERS THEN
      l_exception := NULL;
      l_exception := SQLERRM;
      l_tc_exist  := 0;
    END;
    
    BEGIN
      SELECT 1,
        NVL(:old.delivery_id, :new.delivery_id),
        :new.delivery_detail_id
      INTO l_tc_exist,
        p_delivery_id,
        p_delivery_detail_id
      FROM WM_TRACKCHANGES tc
      WHERE 1                 =1
      AND tc.TRANSACTION_TYPE ='SHIPSHIPMENT'
      AND tc.transaction_id   = NVL(:OLD.delivery_id, :NEW.delivery_id);
    EXCEPTION
    WHEN OTHERS THEN
      l_exception := NULL;
      l_exception := SQLERRM;
      l_tc_exist  := 0;
    END;
    
    IF (:OLD.delivery_id IS NOT NULL AND :NEW.delivery_id IS NULL) THEN
      l_assign_type      := 'Unassign';
    ELSE
      l_assign_type := 'Assign';
    END IF;
    IF (l_tc_exist = 1) THEN
      BEGIN
        SELECT OOH.ORDER_NUMBER,
          ool.line_number,
          ool.ordered_item,
          ool.header_id,
          ool.line_id,
          ool.ship_from_org_id --v1.3
        INTO l_order_number,
          l_line_number,
          l_ordered_item,
          l_header_id,
          l_line_id,
          l_orgn_id --v1.3
        FROM OE_ORDER_HEADERS_ALL OOH,
          OE_ORDER_LINES_ALL OOL,
          WSH_DELIVERY_DETAILS WDD,
          mtl_system_items_b msi
        WHERE 1                    =1
        AND OOH.HEADER_ID          = OOL.HEADER_ID
        AND OOL.HEADER_ID          = WDD.SOURCE_HEADER_ID
        AND OOL.LINE_ID            = WDD.SOURCE_LINE_ID
        AND ool.inventory_item_id  =msi.inventory_item_id
        AND ool.ship_from_org_id   =msi.ORGANIZATION_ID
        AND msi.inventory_item_flag='Y'
        AND WDD.DELIVERY_DETAIL_ID = :new.DELIVERY_DETAIL_ID --8360712
          ;
      EXCEPTION
      WHEN NO_DATA_FOUND THEN
        l_nodata    := 'Y';
        l_exception := NULL ;
        l_exception := sqlerrm;
      WHEN OTHERS THEN
        l_exception := NULL ;
        l_exception := sqlerrm;
      END;
      IF (l_nodata ='N') THEN
        BEGIN
          p_rec_wm_trackChange.transaction_type   := c_transaction_type;
          p_rec_wm_trackChange.date_created       := SYSDATE;
          p_rec_wm_trackChange.processed_flag     := 'N';
          p_rec_wm_trackChange.transaction_id     :=p_delivery_id;
          p_rec_wm_trackChange.comments           :='ORDER DELIVERY DETAIL ID INSERT FOR (UN)ASSIGNED '|| p_delivery_detail_id;
          p_rec_wm_trackChange.transaction_status := 1;
          -- Call Procedure to Insert into wm_track_changes
          wm_track_changes_pkg.web_transaction(p_rec_wm_trackChange);
        EXCEPTION
        WHEN OTHERS THEN
          l_exception := NULL ;
          l_exception := sqlerrm;
        END;
    
        BEGIN --v1.4
            select XXHA_PROD_DB, 
                    --XXHA_GET_TEST_EMAIL_ADDRESS --v1.5
                    XXHA_FND_UTIL_PKG.get_recipients  --v1.5 
            INTO l_prod_flag, l_test_email_addr from DUAL;        
           if l_prod_flag = 'N' then
            l_send_email_addr := l_test_email_addr;
          else
            select flv.description into l_send_email_addr
            from wsh_delivery_details wdd, mtl_parameters mp, FND_LOOKUP_VALUES flv 
            where 1=1 and wdd.organization_id=mp.organization_id
            and mp.organization_code = flv.lookup_code    
            AND flv.LOOKUP_TYPE = 'XXHA_WMS_ORGS' and LANGUAGE = USERENV ('LANG')
            AND WDD.DELIVERY_DETAIL_ID = :new.DELIVERY_DETAIL_ID; 
          end if;
        EXCEPTION WHEN OTHERS THEN
         NULL;
        END; --v1.4
        --Calling procedure to send email notification
        BEGIN
          l_subject := 'Order Number '||l_order_number ||' '||' Delivery Details Changed.';
          l_message := 'Delivery Detail ID has been '|| l_assign_type ||'ed,for which delivery already sent to Precision.'||chr(13)||chr(13);
          l_message := l_message || 'A VOID is being sent to Precision.'||chr(13);
          l_message := l_message || 'Destroy shipping labels and shipping documents for the delivery below.'||chr(13);
          l_message := l_message || 'RESEND a new VERIFICATION for the delivery below to obtain new shipping labels and shipping documents.'||chr(13);
          l_message := l_message || 'Additionally the SO line has been placed on Shipping Hold.  The hold will need to be released prior to trailer load and ship confirm.'||chr(13);
          l_message := l_message ||chr(13)|| 'Below are details:'||chr(13);
          l_message := l_message || '  Order Number: '||l_order_number||chr(13);
          l_message := l_message || '  Line Number: '||l_line_number||chr(13);
          l_message := l_message || '  Ordered Item: '||l_ordered_item||chr(13);
          l_message := l_message || '  Delivery Detail ID: '||p_delivery_detail_id||chr(13)||CHR(13);
          l_message := l_message || 'Thank you.';
          --v1.5
          l_host_name := XXHA_FND_UTIL_PKG.get_ip_address;
           
           IF l_host_name IS NULL THEN
            fnd_file.put_line (fnd_file.LOG, 'SMTP host does not exist');
           END IF;      
           --v1.5      
--          XXHA_SEND_MAIL(P_MAIL_HOST => 'smtp-bo.haemo.net', p_from => 'Workflow_Mailer@haemonetics.com', p_to => l_send_email_addr, P_SUBJECT => l_subject, p_message => l_message); --v1.4  --Commented v1.5
          XXHA_SEND_MAIL(P_MAIL_HOST => l_host_name, p_from => 'Workflow_Mailer@haemonetics.com', p_to => l_send_email_addr, P_SUBJECT => l_subject, p_message => l_message); --v1.5
        EXCEPTION
        WHEN OTHERS THEN
          l_exception := NULL ;
          l_exception := sqlerrm;
        END;
        FOR rec IN oe_lines(l_header_id, l_orgn_id) --v1.3
        LOOP
          v_header_id                        := rec.header_id;
          v_line_id                          := rec.line_id;
          v_hold_source_rec                  := OE_HOLDS_PVT.G_MISS_HOLD_SOURCE_REC;
          v_hold_source_rec.hold_id          := v_hold_id;
          v_hold_source_rec.hold_entity_code := v_hold_entity_code;
          v_hold_source_rec.hold_entity_id   := v_header_id;
          V_HOLD_SOURCE_REC.HEADER_ID        := V_HEADER_ID;
          V_HOLD_SOURCE_REC.line_id          := V_line_id;
          V_HOLD_SOURCE_REC.hold_comment     := 'WMS Void Shipping Hold applied in Void Del Det trg'; --v1.1
          v_return_status                    := NULL;
          v_msg_data                         := NULL;
          v_msg_count                        := NULL;
          --Policy Context
          mo_global.set_policy_context ('S', 102);
          OE_HOLDS_PUB.APPLY_HOLDS ( p_api_version => 1.0, p_init_msg_list => FND_API.G_TRUE, p_commit => FND_API.G_FALSE, p_hold_source_rec => v_hold_source_rec, x_return_status => v_return_status, x_msg_count => v_msg_count, x_msg_data => v_msg_data );
          /*   IF v_return_status = FND_API.G_RET_STS_SUCCESS THEN
          INSERT INTO aatest2 VALUES(9,'success:');
          ELSIF v_return_status IS NULL THEN
          INSERT INTO aatest2 VALUES(10,'Status is null');
          ELSE
          INSERT INTO aatest2 VALUES(11,'failure:'|| v_msg_data );
          FOR i IN 1 .. v_msg_count
          LOOP
          v_msg_data := oe_msg_pub.get( p_msg_index => i, p_encoded => 'F');
          INSERT INTO aatest2 VALUES(12, i|| ') '|| v_msg_data);
          END LOOP;
          END IF;
          */
        END LOOP;
      END IF;
    END IF;
  END IF;
END XXHA_WM_VOIDDELDET_TRG;