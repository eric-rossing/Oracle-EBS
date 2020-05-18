CREATE OR REPLACE PACKAGE BODY XXHA_INV_ACC_RECEIPT_PKG
AS
  /* **********************************************************************************************************************
  * Object Name: APPS.xxha_inv_acc_receipt_pkg                                                                   *
  * Object Type: PACKAGE                                                                                                  *
  *                                                                                                                       *
  * Description: This PACKAGE used for increasing on hand quantity using account alias receipt Transaction type
  *
  *                                                                                                                       *
  *                                                                                                                       *
  * Change History                                                                                                        *
  *                                                                                                                       *
  * Ver        Date            Author               Description                                                           *
  * ------     -----------     -----------------    ---------------                                                       *
  * 1.0        05-may-2020     Venkat             Initial PACKAGE creation.                                             *
  *                                                                                                                       *
  ************************************************************************************************************************/
  PROCEDURE XXHA_INV_ACC_TAB_INSERT_PRC(
      p_item_no              VARCHAR2,
      p_organization_code    VARCHAR2,
      p_subinv               VARCHAR2,
      p_revision             VARCHAR2,
      p_transaction_quantity NUMBER,
      p_from_serial_no       VARCHAR2,
      p_reference            VARCHAR2 )
  AS
    l_cnt NUMBER;
    l_inventorty_item_id mtl_system_items_b.inventory_item_id%TYPE;
    l_description mtl_system_items_b.description%TYPE;
    l_primary_uom_code mtl_system_items_b.primary_uom_code%TYPE;
    ---
    l_transaction_type_id mtl_transaction_types.transaction_type_id%TYPE;
    --
    l_organization_id org_organization_definitions.organization_id%TYPE;
    l_transaction_source_id mtl_generic_dispositions.disposition_id%TYPE;
    l_distribution_account_id mtl_generic_dispositions.distribution_account%TYPE;
    l_serial_status mtl_serial_numbers.current_status%TYPE;
    l_group_mark_id mtl_serial_numbers.group_mark_id%TYPE;
    l_line_mark_id mtl_serial_numbers.line_mark_id%TYPE;
    l_lot_line_mark_id mtl_serial_numbers.lot_line_mark_id%TYPE;
    l_current_status NUMBER;
    l_rev_cnt        NUMBER;
    l_subinvcnt      NUMBER;
    l_valid_cnt      NUMBER;
    l_error_cnt      NUMBER;
    l_rec_cnt        NUMBER;
    l_locator_type   NUMBER;
    l_row_count      NUMBER;
  BEGIN
    BEGIN
      DELETE FROM xxha_inv_acc_receipt_tbl WHERE process_flag <> 'V';
      --where created_by = nvl(fnd_global.user_id,-1);
    EXCEPTION
    WHEN OTHERS THEN
      NULL;
    END ;
    BEGIN
      SELECT COUNT(1)
      INTO l_row_count
      FROM XXHA_INV_ACC_RECEIPT_TBL
      WHERE item_no        =p_item_no
      AND organization_code=p_organization_code
      AND revision         =p_revision
      AND subinventory_code=p_subinv
      AND p_from_serial_no = from_serial_no;
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
      l_row_count:=0;
    WHEN OTHERS THEN
      l_row_count:=0;
    END;
    IF l_row_count > 0 THEN
      RAISE_APPLICATION_ERROR (-20001, 'Record has duplicate ');
    END IF;
    BEGIN
      SELECT organization_id
      INTO l_organization_id
      FROM ORG_ORGANIZATION_DEFINITIONS
      WHERE organization_code =p_organization_code;
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
      l_organization_id:=0;
    WHEN OTHERS THEN
      l_organization_id:=0;
    END;
    IF l_organization_id =0 THEN
      RAISE_APPLICATION_ERROR (-20001, 'Organization Code is Invalid');
    END IF;
    IF l_organization_id IS NOT NULL THEN
      BEGIN
        SELECT inventory_item_id,
          description ,--added uom also
          primary_uom_code
        INTO l_inventorty_item_id,
          l_description,
          l_primary_uom_code
        FROM MTL_SYSTEM_ITEMS_B
        WHERE segment1      = p_item_no
        AND organization_id = l_organization_id;
        --XXHA_INV_LOG_PRNT(L_DEBUG ,'INVENTORY_ITEM_ID:'||L_INVENTORTY_ITEM_ID);
      EXCEPTION
      WHEN NO_DATA_FOUND THEN
        l_inventorty_item_id:=0;
      WHEN OTHERS THEN
        l_inventorty_item_id:=0;
      END;
      IF l_inventorty_item_id =0 THEN
        RAISE_APPLICATION_ERROR (-20002, 'Item no is Invalid');
      END IF;
      IF l_inventorty_item_id IS NOT NULL THEN
        BEGIN
          SELECT COUNT(1)
          INTO L_REV_CNT
          FROM MTL_ITEM_REVISIONS
          WHERE inventory_item_id = l_inventorty_item_id
          AND organization_id     = l_organization_id
          AND revision            = p_revision;
        EXCEPTION
        WHEN NO_DATA_FOUND THEN
          l_rev_cnt:=0;
        WHEN OTHERS THEN
          l_rev_cnt:=0;
        END;
        IF l_rev_cnt = 0 THEN
          RAISE_APPLICATION_ERROR (-20002, 'Item Revision is Invalid');
        END IF;
        BEGIN
          SELECT COUNT(1)
          INTO l_subinvcnt
          FROM mtl_secondary_inventories
          WHERE secondary_inventory_name =p_subinv
          AND organization_id            =l_organization_id;
        EXCEPTION
        WHEN NO_DATA_FOUND THEN
          l_subinvcnt:=0;
        WHEN OTHERS THEN
          l_subinvcnt:=0;
        END;
        IF l_subinvcnt = 0 THEN
          RAISE_APPLICATION_ERROR (-20003, 'Sub Inventory  is Invalid');
        END IF;
        BEGIN
          SELECT locator_type
          INTO l_locator_type
          FROM mtl_secondary_inventories
          WHERE secondary_inventory_name =p_subinv
          AND organization_id            =l_organization_id;
        EXCEPTION
        WHEN NO_DATA_FOUND THEN
          l_subinvcnt:=0;
        WHEN OTHERS THEN
          l_subinvcnt:=0;
        END;
        IF l_locator_type<>1 THEN
          RAISE_APPLICATION_ERROR (-20005, 'Locator has been definied at Subinventory or Organiation level');
        END IF;
        IF p_transaction_quantity <>1 THEN
          RAISE_APPLICATION_ERROR (-20004, 'Quantity should be 1');
        END IF;
        BEGIN
          SELECT SUBSTR(DECODE(current_status,1,'Defined but not used', 3,'Resides in Stores', 4, 'Out of Stores',5,'Intransit', 6,'Invalid',NULL,'Verify Serial Number',current_status),1, 25) "Status",
            SUBSTR( group_mark_id,1,15) "Group Mark Id",
            SUBSTR(line_mark_id,1,15) "Line Mark Id",
            SUBSTR(lot_line_mark_id,1,15) "Lot Line Mark Id",
			current_status
          INTO l_serial_status,
            l_group_mark_id,
            l_line_mark_id,
            l_lot_line_mark_id,
            l_current_status
          FROM mtl_serial_numbers
          WHERE inventory_item_id     = l_inventorty_item_id
          AND   serial_number           = p_from_serial_no
          AND   current_organization_id = l_organization_id;
        EXCEPTION
        WHEN NO_DATA_FOUND THEN
          l_subinvcnt:=0;
        WHEN OTHERS THEN
          l_subinvcnt:=0;
        END;
        -- new chnage 11-5-2020
        IF (l_current_status IN ( 3,5,6) OR (l_group_mark_id is not null)OR (l_line_mark_id is not null) OR (l_lot_line_mark_id is not null) ) THEN --11-MAY-2020
          --IF (l_serial_status IN ( 3,5,6) ) then
          RAISE_APPLICATION_ERROR (-20005, 'Serial number is Invalid');
          --END IF;
        END IF;
        INSERT
        INTO xxha_inv_acc_receipt_tbl
          (
            Reference_id,
            Item_no,
            Inventory_item_id,
            description,
            Organization_code,
            Organization_id,
            Revision,
            subinventory_code,
            -- Transaction_type,
            transaction_type_id,
            -- transaction_source_name,
            transaction_source_id,
            distribution_account_id,
            transaction_date,
            Transaction_quantity,
            uom,
            -- Locator,
            from_serial_no,
            to_serial_no,
            reference_text,
            process_flag,
            creation_date,
            created_by,
            last_updated_by,
            last_update_date,
            last_update_login
          )
          VALUES
          (
            xxha_inv_acc_rec_s.nextval,
            p_item_no,
            l_inventorty_item_id,
            l_description,
            p_organization_code,
            l_organization_id,
            p_revision,
            p_subinv,
            --  'Account alias receipt',--p_Transaction_type,
            l_transaction_type_id,
            --  'inventory adj', --p_transaction_source_name,
            l_transaction_source_id,
            l_distribution_account_id,
            sysdate,-- p_transaction_date,
            p_transaction_quantity,
            l_primary_uom_code,
            -- p_locator,
            p_from_serial_no,
            p_from_serial_no,---p_to_serial_no,
            p_reference,
            'V',
            sysdate,
            NVL(fnd_global.user_id,-1),
            NVL(fnd_global.user_id,-1),
            sysdate,
            NVL(fnd_global.user_id,-1)
          );
      END IF;-- INEVNTORY
    END IF;
  EXCEPTION
  WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR (-20000, SQLCODE || ':' || SQLERRM);
  END ;
  PROCEDURE XXHA_INV_ACC_REC_IMPORT_PRC
    (
      errbuf OUT VARCHAR2 ,
      retcode OUT VARCHAR2,
      p_Transaction_type IN VARCHAR2,
      p_source           IN VARCHAR2,
      p_transaction_date IN VARCHAR2
    )
  AS
    CURSOR C_ACC_REC
    IS
      SELECT reference_id,
        Item_no,
        Inventory_item_id,
        Organization_code,
        Organization_id,
        Revision,
        subinventory_code,
        Transaction_type,
        transaction_type_id,
        transaction_source_name,
        transaction_source_id,
        DISTRIBUTION_ACCOUNT_ID,
        transaction_date,
        Transaction_quantity,
        UOM,
        Locator,
        locator_id,
        from_serial_no,
        To_serial_no,
        Reference_Text
      FROM xxha_inv_acc_receipt_tbl
      WHERE process_flag = 'V';
    l_transaction_type_id mtl_transaction_types.transaction_type_id%TYPE;
    --
    l_organization_id org_organization_definitions.organization_id%TYPE;
    l_transaction_source_id mtl_generic_dispositions.disposition_id%TYPE;
    l_distribution_account_id mtl_generic_dispositions.distribution_account%TYPE;
    l_error_msg         VARCHAR2(2000);
    l_rec_cnt           NUMBER;
    L_ret_status        VARCHAR2(100);
    L_msg_cnt           NUMBER;
    L_msg_data          VARCHAR2(2000);
    L_ret_value         NUMBER;
    L_trans_count       NUMBER;
    l_trasaction_header NUMBER;
    l_interface_seq     NUMBER;
    ---
    l_debug      VARCHAR2(5):='Y';
    l_error_flag VARCHAR2(2):='N';
    --
    l_user_id      NUMBER := fnd_global.user_id;
    l_resp_id      NUMBER := fnd_global.resp_id;
    l_resp_appl_id NUMBER := fnd_global.resp_appl_id;
  BEGIN
    XXHA_INV_LOG_PRNT(l_debug ,'XXHA_INV_ACC_REC_IMPORT_PRC');
    XXHA_INV_LOG_PRNT(l_debug ,'user=>'||l_user_id||'l_resp_id=>'||l_resp_id||'l_resp_appl_id=>'||l_resp_appl_id);
    l_rec_cnt:=0;
    FOR r_acc_rec IN c_acc_rec
    LOOP
      XXHA_INV_LOG_PRNT(l_debug ,'Reference_id'||r_acc_rec.reference_id);
      l_rec_cnt:=l_rec_cnt+1;
      BEGIN
        SELECT transaction_type_id
        INTO l_transaction_type_id
        FROM mtl_transaction_types
        WHERE transaction_type_name = p_transaction_type;--'Account alias receipt';
        XXHA_INV_LOG_PRNT(l_debug ,'Transaction Type Name=> '||p_transaction_type || ' '||'Transaction Type id=>'||l_transaction_type_id);
      EXCEPTION
      WHEN NO_DATA_FOUND THEN
        l_error_msg:=l_error_msg||' PROCEDURE:XXHA_INV_ACC_REC_IMPORT_PRC: Error: transaction_type_name '||SQLERRM;
        XXHA_INV_LOG_PRNT(l_debug ,l_error_msg);
        l_error_flag:= 'Y';
      WHEN OTHERS THEN
        l_transaction_type_id:=0;
        l_error_flag         := 'Y';
      END;
      BEGIN
        SELECT disposition_id,
          distribution_account
        INTO l_transaction_source_id,
          l_distribution_account_id
        FROM mtl_generic_dispositions
        WHERE organization_id = r_acc_rec.organization_id
        AND segment1          = p_source;--'INVENTORY ADJ';
        XXHA_INV_LOG_PRNT(l_debug ,'Transaction Source Name=> '||p_source || ' '||'Transaction Source id =>'||l_transaction_source_id ||' DISTRIBUTION_ACCOUNT_ID=>'||l_distribution_account_id );
      EXCEPTION
      WHEN NO_DATA_FOUND THEN
        l_error_msg:=l_error_msg||' PROCEDURE:XXHA_INV_ACC_REC_IMPORT_PRC: Error: transaction_source_name '||SQLERRM;
        XXHA_INV_LOG_PRNT(l_debug ,l_error_msg);
        L_ERROR_FLAG:= 'Y';
      WHEN OTHERS THEN
        l_error_msg:=l_error_msg||' PROCEDURE:XXHA_INV_ACC_REC_IMPORT_PRC: Error: transaction_source_name '||SQLERRM;
        XXHA_INV_LOG_PRNT(l_debug ,l_error_msg);
        L_ERROR_FLAG:= 'Y';
      END;
      XXHA_INV_LOG_PRNT(l_debug ,'XXHA_INV_ACC_REC_IMPORT_PRC:TRANSACTION INSERT STARTING....');
      XXHA_INV_LOG_PRNT(l_debug ,'L_ERROR_FLAG'||l_error_flag);
      IF l_error_flag<>'Y' THEN
        BEGIN
          l_interface_seq :=mtl_material_transactions_s.NEXTVAL;
          XXHA_INV_LOG_PRNT(l_debug ,'Transaction_Interface_id=>'||l_interface_seq);
          l_trasaction_header:=xxha_inv_Trans_header_s.nextval;
          XXHA_INV_LOG_PRNT(l_debug ,'Transaction_Interface_id=>'||l_trasaction_header);
          INSERT
          INTO mtl_transactions_interface
            (
              transaction_uom,
              transaction_date,
              source_code,
              source_line_id,
              source_header_id,
              process_flag ,
              transaction_mode ,
              lock_flag ,
              last_update_date ,
              last_updated_by ,
              creation_date ,
              created_by ,
              inventory_item_id ,
              revision,
              subinventory_code,
              organization_id,
              transaction_source_id,
              transaction_quantity ,
              primary_quantity ,
              transaction_type_id ,
              distribution_account_id,
              transaction_interface_id,
              transaction_header_id,
              transaction_reference
            )
            VALUES
            (
              r_acc_rec.uom,                                       --transaction uom
              to_date(p_transaction_date,'YYYY-MM-DD HH24:MI:SS'), --transaction date
              'Alias Receipt',                                     --source code
              99,                                                  --source line id
              99,                                                  --source header id
              1,                                                   --process flag
              3 ,                                                  --transaction mode
              2 ,                                                  --lock flag
              --138911 , --locator id
              SYSDATE ,                    --last update date
              NVL(fnd_global.user_id,-1),  --last updated by
              SYSDATE ,                    --creation date
              NVL(fnd_global.user_id,-1),  --created by
              r_acc_rec.inventory_item_id, --inventory item id
              r_acc_rec.revision,
              r_acc_rec.subinventory_code,    --From subinventory code
              r_acc_rec.organization_id,      --organization id
              l_transaction_source_id,        --transaction source id ---Blood Bank Inventory Adjustment
              r_acc_rec.transaction_quantity, --transaction quantity
              r_acc_rec.transaction_quantity, --Primary quantity
              l_transaction_type_id ,         --transaction type id
              l_distribution_account_id,      --code_combination
              l_interface_seq,                --transaction interface id
              l_trasaction_header,
              r_acc_rec.reference_text
            );
          COMMIT;
        EXCEPTION
        WHEN OTHERS THEN
          l_error_msg:='PROCEDURE:XXHA_INV_ACC_REC_IMPORT_PRC: Error: INSERTING TRANASCATION  '||SQLERRM;
          XXHA_INV_LOG_PRNT(l_debug ,l_error_msg);
          l_error_flag:= 'Y';
        END;
      END IF;
      XXHA_INV_LOG_PRNT(l_debug ,'XXHA_INV_ACC_REC_IMPORT_PRC: Serial numberINSERT STARTING....');
      BEGIN
        XXHA_INV_LOG_PRNT(l_debug ,'XXHA_INV_ACC_REC_IMPORT_PRC: Serial number=> '||r_acc_rec.from_serial_no );
        IF l_error_flag <>'Y' THEN
          INSERT
          INTO mtl_serial_numbers_interface
            (
              transaction_interface_id,
              fm_serial_number,
              to_serial_number,
              last_update_date,
              last_updated_by,
              creation_date,
              created_by
            )
            VALUES
            (
              l_interface_seq,            --transaction interface_id
              r_acc_rec.from_serial_no,   --from serial number
              r_acc_rec.to_serial_no,     --to serial number
              SYSDATE,                    --last update date
              NVL(fnd_global.user_id,-1), --last updated by
              SYSDATE,                    --creation date
              NVL(fnd_global.user_id,-1)  --created by
            );
          COMMIT;
        END IF ;
      EXCEPTION
      WHEN OTHERS THEN
        l_error_msg:='PROCEDURE:XXHA_INV_ACC_REC_IMPORT_PRC: Error: INSERTING Serial number '||SQLERRM;
        XXHA_INV_LOG_PRNT(l_debug ,l_error_msg);
      END;
      XXHA_INV_LOG_PRNT(l_debug ,'XXHA_INV_ACC_REC_IMPORT_PRC: Transaction API calling....');
      IF L_ERROR_FLAG <>'Y' THEN
        BEGIN
          XXHA_INV_LOG_PRNT(l_debug ,'Step-1');
          XXHA_INV_LOG_PRNT(l_debug ,'tranasction header:'||l_trasaction_header);
          fnd_global.APPS_INITIALIZE(l_user_id,l_resp_id, l_resp_appl_id);
          l_ret_value := INV_TXN_MANAGER_PUB.process_Transactions( p_api_version => 1.0, p_init_msg_list => 'T', p_commit => 'T', p_validation_level => 100, x_return_status => l_ret_status, x_msg_count => l_msg_cnt, x_msg_data => l_msg_data, x_trans_count => l_trans_count, p_table => 1, p_header_id => l_trasaction_header);
          XXHA_INV_LOG_PRNT(l_debug ,'Step-2');
          IF L_ret_status = 'S' THEN
            BEGIN
              XXHA_INV_LOG_PRNT(l_debug ,'Step-3');
              UPDATE xxha_inv_acc_receipt_tbl
              SET Interface_Trans_id=l_interface_seq,
                trasaction_header_id=l_trasaction_header,
                -- Organization_id=L_ORGANIZATION_ID,
                transaction_type_id     =l_transaction_type_id,
                transaction_source_id   =l_transaction_source_id,
                distribution_account_id =l_distribution_account_id,
                process_flag            ='S'
              WHERE reference_id        = r_acc_rec.Reference_id
              AND process_flag          ='V';
              COMMIT;
            EXCEPTION
            WHEN OTHERS THEN
              l_error_msg:='PROCEDURE:XXHA_INV_ACC_REC_IMPORT_PRC:UPDATING ERROR SUCESS'||SQLERRM;
              XXHA_INV_LOG_PRNT(l_debug ,l_error_msg);
            END;
          ELSE
            BEGIN
              UPDATE xxha_inv_acc_receipt_tbl
              SET Interface_Trans_id=l_interface_seq,
                trasaction_header_id=l_trasaction_header,
                -- Organization_id=L_ORGANIZATION_ID,
                transaction_type_id     =l_transaction_type_id,
                transaction_source_id   =l_transaction_source_id,
                distribution_account_id =l_distribution_account_id,
                process_flag            ='E'
              WHERE reference_id        = r_acc_rec.reference_id
              AND process_flag          ='V';
              COMMIT;
            EXCEPTION
            WHEN OTHERS THEN
              l_error_msg:='PROCEDURE:XXHA_INV_ACC_REC_IMPORT_PRC:UPDATING ERROR FAILED'||SQLERRM;
              XXHA_INV_LOG_PRNT(L_DEBUG ,l_error_msg);
            END;
          END IF;
        EXCEPTION
        WHEN OTHERS THEN
          l_error_msg:='PROCEDURE:XXHA_INV_ACC_REC_IMPORT_PRC: Error: Transaction API calling=>'||SQLERRM;
          XXHA_INV_LOG_PRNT(L_DEBUG ,l_error_msg);
        END ;
      END IF;
    END LOOP;
    XXHA_INV_OUT_PRNT;
  END ;
  PROCEDURE XXHA_INV_LOG_PRNT(
      p_debug VARCHAR2,
      p_msg   VARCHAR2)
  IS
  BEGIN
    --Logging the messages
    IF (p_debug = 'Y') THEN
      dbms_output.put_line(p_msg);
      fnd_file.put_line(fnd_file.log,p_msg);
    END IF;
  EXCEPTION
  WHEN OTHERS THEN
    fnd_file.put_line(fnd_file.log,'Error while writing the '||P_MSG||' to the log file. Error is '||SQLERRM);
  END XXHA_INV_LOG_PRNT;
  PROCEDURE XXHA_INV_OUT_PRNT
  IS
    l_total_count   NUMBER;
    l_fail_count    NUMBER;
    l_success_count NUMBER;
    CURSOR cur_success
    IS
      SELECT * FROM xxha_inv_acc_receipt_tbl WHERE 1=1 AND process_flag = 'S';
    CURSOR cur_fail
    IS
      SELECT *
      FROM xxha_inv_acc_receipt_tbl
      WHERE 1                     =1
      AND NVL (process_flag, 'E') = 'E';
  BEGIN
    BEGIN
      SELECT COUNT (*) INTO l_total_count FROM xxha_inv_acc_receipt_tbl;
      -- WHERE created_by = fnd_global.user_id;
    EXCEPTION
    WHEN OTHERS THEN
      l_total_count := 0;
    END;
    BEGIN
      SELECT COUNT (*)
      INTO l_success_count
      FROM xxha_inv_acc_receipt_tbl
      WHERE 1          = 1
      AND process_flag = 'S';
      --AND created_by = fnd_global.user_id;
    EXCEPTION
    WHEN OTHERS THEN
      l_success_count := 0;
    END;
    BEGIN
      SELECT COUNT (*)
      INTO l_fail_count
      FROM xxha_inv_acc_receipt_tbl
      WHERE 1                     = 1
      AND NVL (process_flag, 'E') = 'E';
      -- AND created_by = fnd_global.user_id;
    EXCEPTION
    WHEN OTHERS THEN
      l_fail_count := 0;
    END;
    IF l_total_count > 0 THEN
      fnd_file. put_line (fnd_file.OUTPUT, '***************TRANSACTION SUMMARY*****************');
      IF l_success_count > 0 THEN
        fnd_file. put_line ( fnd_file.OUTPUT, 'Total Records Succeed ' || ' ' || l_success_count || ' ' || 'of' || ' ' || l_total_count);
        fnd_file.put_line ( fnd_file.OUTPUT, RPAD ('Organization Code ', 25) || RPAD ('Item', 25) || RPAD ('Revision', 25) || RPAD ('SubInventory', 25) || RPAD ('Quantity', 25) || RPAD ('Serial number ', 25) || RPAD ('Reference', 25) );
        FOR i IN cur_success
        LOOP
          fnd_file. put_line ( fnd_file.OUTPUT, RPAD (i.organization_code, 25) || RPAD (i.item_no, 25) || RPAD (i.revision, 25) || RPAD (i.subinventory_code, 25) || RPAD (i.transaction_quantity, 25) || RPAD (i.from_serial_no, 25) || RPAD (i.reference_text, 25));
        END LOOP;
      END IF;
      IF l_fail_count > 0 THEN
        fnd_file. put_line ( fnd_file.OUTPUT, 'Total Records Failed ' || ' ' || l_fail_count || ' ' || 'of' || ' ' || l_total_count);
        fnd_file.put_line (fnd_file.OUTPUT, '');
        fnd_file. put_line (fnd_file.OUTPUT, '***************Exception Report*****************');
        fnd_file.put_line ( fnd_file.OUTPUT, RPAD ('Organization Code ', 25) || RPAD ('Item', 25) || RPAD ('Revision', 25) || RPAD ('SubInventory', 25) || RPAD ('Serial number ', 25) || RPAD ('Reference', 25) || RPAD ('Error Code', 25) || RPAD ('Error Explanation', 25) );
        FOR rec_err IN
        (SELECT xia.item_no,
          xia.organization_code,
          xia.revision,
          xia.subinventory_code,
          xia.from_serial_no,
		  xia.reference_text,
          mti.error_code,
          mti.error_explanation
        FROM mtl_transactions_interface mti,
          xxha_inv_acc_receipt_tbl xia
        WHERE mti.transaction_interface_id = xia.interface_trans_id
        AND mti.transaction_reference      =xia.reference_text
        AND xia.process_flag               ='E'
        )
        LOOP
          fnd_file. put_line ( fnd_file.OUTPUT, RPAD (rec_err.item_no, 25) || RPAD (rec_err.organization_code, 25) || RPAD (rec_err.revision, 25) || RPAD (rec_err.subinventory_code, 25)|| RPAD (rec_err.from_serial_no,25)||RPAD (rec_err.reference_text,25) || RPAD (rec_err.error_code, 25) || RPAD (rec_err.error_explanation, 250));
        END LOOP;
      ELSE
        fnd_file.put_line (fnd_file.OUTPUT, 'All records are succesfully processed');
      END IF;
    END IF;
  EXCEPTION
  WHEN OTHERS THEN
    fnd_file.put_line (fnd_file.LOG, 'Error in XXHA_INV_OUT_PRNT Procedure');
  END XXHA_INV_OUT_PRNT;--*/
END;