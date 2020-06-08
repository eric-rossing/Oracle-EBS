CREATE OR REPLACE PACKAGE body xxha_inv_move_order_txfr_pkg
AS

  /*******************************************************************************************************************
  * Object Name: APPS.xxha_inv_move_order_txfr_pkg                                                                 *
  * Object Type: PACKAGE                                                                                                  *
  *                                                                                                                       *
  * Description: This PACKAGE used for creating Move Order using webadi
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
  
  PROCEDURE xxha_inv_move_order_insert_prc(
      p_itemno         VARCHAR2,
      p_revision       VARCHAR2,
      p_desc           VARCHAR2,
      p_source_inv     VARCHAR2,
      P_dest_inv       VARCHAR2,
      p_organ          VARCHAR2,
      p_qty            NUMBER,
      p_from_serial_no VARCHAR2)
  AS 
  
  l_organization_id org_organization_definitions.organization_id%TYPE;
  l_inventorty_item_id mtl_system_items_b.inventory_item_id%TYPE;
  l_description mtl_system_items_b.description%TYPE;
  l_primary_uom_code mtl_system_items_b.primary_uom_code%TYPE;
  l_serial_number    mtl_serial_numbers.serial_number%TYPE;
  l_rev_cnt NUMBER;
  l_source_subinvcnt NUMBER;
  l_destin_subinvcnt NUMBER;
  
BEGIN
BEGIN

      DELETE FROM xxha_inv_move_order_txfr_tbl WHERE process_flag <> 'V';
      --where created_by = nvl(fnd_global.user_id,-1);
    EXCEPTION
    WHEN OTHERS THEN
      NULL;
    END ;

  BEGIN
    SELECT organization_id
    INTO l_organization_id
    FROM org_organization_definitions
    WHERE organization_code =p_organ;
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
        primary_uom_code
      INTO l_inventorty_item_id,
        l_primary_uom_code
      FROM mtl_system_items_b
      WHERE segment1      = p_itemno
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
        INTO l_rev_cnt
        FROM mtl_item_revisions
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
        INTO l_source_subinvcnt
        FROM mtl_secondary_inventories
        WHERE secondary_inventory_name =p_source_inv
        AND organization_id            =l_organization_id;
      EXCEPTION
      WHEN NO_DATA_FOUND THEN
        l_source_subinvcnt:=0;
      WHEN OTHERS THEN
        l_source_subinvcnt:=0;
      END;
      IF l_source_subinvcnt = 0 THEN
        RAISE_APPLICATION_ERROR (-20003, 'Source Sub Inventory  is Invalid');
      END IF;
      BEGIN
        SELECT COUNT(1)
        INTO l_destin_subinvcnt
        FROM mtl_secondary_inventories
        WHERE secondary_inventory_name =P_dest_inv
        AND organization_id            =l_organization_id;
      EXCEPTION
      WHEN NO_DATA_FOUND THEN
        l_destin_subinvcnt:=0;
      WHEN OTHERS THEN
        l_destin_subinvcnt:=0;
      END;
      IF l_destin_subinvcnt = 0 THEN
        RAISE_APPLICATION_ERROR (-20003, 'Destination Sub Inventory  is Invalid');
      END IF;
      IF p_qty <>1 THEN
        RAISE_APPLICATION_ERROR (-20004, 'Quantity should be 1');
      END IF;
	  
	  BEGIN 
	  
	  SELECT DISTINCT msn.serial_number
	         INTO 	l_serial_number
      FROM apps.mtl_onhand_quantities moq,
        apps.mtl_system_items_b mtl ,
        apps.mtl_serial_numbers msn
      WHERE moq.organization_id        =l_organization_id
      AND moq.inventory_item_id        =l_inventorty_item_id
      AND moq.organization_iD          =mtl.organization_id
      AND moq.inventory_item_id        =mtl.inventory_item_id
      AND msn.current_organization_id  =mtl.organization_id
      AND moq.subinventory_code        =msn.current_subinventory_code
      AND msn.current_subinventory_code=p_source_inv
      AND msn.current_status           =3
      AND mtl.inventory_item_id        =msn.inventory_item_id
      AND msn.serial_number            =p_from_serial_no;
	  
	   EXCEPTION
      WHEN NO_DATA_FOUND THEN
        l_serial_number:=NULL;
      WHEN OTHERS THEN
        l_serial_number:=NULL;
      END;
	  
	  IF l_serial_number is null THEN
        RAISE_APPLICATION_ERROR (-20004, 'Serial Number is Invalid as there is no onhand quantity for that serial number in Source Subinventory');
      END IF;
	  
	  
	 
	  
	  
      INSERT
      INTO xxha_inv_move_order_txfr_tbl
        (
          Reference_id,
          Item_no,
          Inventory_item_id,
          description,
          organization_code,
          Organization_id,
          Revision,
          source_sub_inv,
          destination_sub_inv,
          transaction_type_id,
          move_order_type_id,
          quantity,
          uom,
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
          xxha_inv_move_order_txfr_s.nextval,
          p_itemno,
          l_inventorty_item_id,
          p_desc,
          p_organ,
          l_organization_id,
          p_revision,
          p_source_inv,
          P_dest_inv,
          NULL,
          NULL,
          p_qty,
          l_primary_uom_code,
          p_from_serial_no,
          p_from_serial_no,
          NULL,
          'V',
          sysdate,
          NVL(fnd_global.user_id,-1),
          NVL(fnd_global.user_id,-1),
          sysdate,
          NVL(fnd_global.user_id,-1)
        );
    END IF;
  END IF;
EXCEPTION
WHEN OTHERS THEN
  RAISE_APPLICATION_ERROR (-20000, SQLCODE || ':' || SQLERRM);
END;

PROCEDURE xxha_inv_move_order_import_prc
  (
   x_errbuf OUT VARCHAR2 ,
   x_retcode OUT VARCHAR2,
   p_transaction_type VARCHAR2
   )
   AS 
   
  CURSOR c_move_transfer is 
  SELECT 
  reference_id,       
  item_no ,           
  inventory_item_id,  
  revision 	,		
  description , 		
  source_sub_inv ,		
  destination_sub_inv,
  organization_code ,	
  organization_id ,	
  Transaction_type ,	
  transaction_type_id,
  move_order_type ,	
  move_order_type_id ,
  uom 	,			
  quantity ,			
  from_serial_no ,		
  to_serial_no, 		
  move_order_no ,		
  process_flag, 		
  error_flag ,			
  error_msg ,			
  reference_text     
  FROM xxha_inv_move_order_txfr_tbl
  WHERE process_flag ='V';
  
   l_transaction_type_id mtl_transaction_types.transaction_type_id%TYPE;
  
    l_debug      	VARCHAR2(5):='Y';
    l_error_flag 	VARCHAR2(2):='N';
    l_error_msg		VARCHAR2(1000);
    l_user_id      	NUMBER := fnd_global.user_id;
    l_resp_id      	NUMBER := fnd_global.resp_id;
    l_resp_appl_id 	NUMBER := fnd_global.resp_appl_id;
	l_api_version		   NUMBER := 1.0; 
        l_init_msg_list		 VARCHAR2(2) := FND_API.G_TRUE; 
        l_return_values    VARCHAR2(2) :=  FND_API.G_FALSE; 
        l_commit		       VARCHAR2(2) := FND_API.G_FALSE; 
        x_return_status		 VARCHAR2(2);
        x_msg_count		     NUMBER := 0;
        x_msg_data         VARCHAR2(1000);
		
		l_msg_data varchar2(4500);
		
		v_msg_index_out NUMBER;
        
        -- API specific declarations
        l_header_id              NUMBER := 0;
        l_trohdr_rec             inv_move_order_pub.trohdr_rec_type;
        l_trohdr_val_rec         inv_move_order_pub.trohdr_val_rec_type;
		l_trolin_rec             inv_move_order_pub.trolin_rec_type;
        l_trolin_tbl             inv_move_order_pub.trolin_tbl_type;
        l_trolin_val_tbl         inv_move_order_pub.trolin_val_tbl_type;
        x_trolin_tbl             inv_move_order_pub.trolin_tbl_type;
        x_trolin_val_tbl         inv_move_order_pub.trolin_val_tbl_type;
        x_trohdr_rec             inv_move_order_pub.trohdr_rec_type;
        x_trohdr_val_rec         inv_move_order_pub.trohdr_val_rec_type;
		l_trohdr_rec1             inv_move_order_pub.trohdr_rec_type;
		l_trolin_tbl1            inv_move_order_pub.trolin_tbl_type;
		x_trolin_tbl1            inv_move_order_pub.trolin_tbl_type;
		x_trohdr_rec1            inv_move_order_pub.trohdr_rec_type;
		l_row_cnt number:=1;
	
      
    
   
   BEGIN 
   
    xxha_inv_move_prt_prc(l_debug ,'XXHA_INV_MOVE_ORDER_IMPORT_PRC');
    xxha_inv_move_prt_prc(l_debug ,'user=>'||l_user_id||'l_resp_id=>'||l_resp_id||'l_resp_appl_id=>'||l_resp_appl_id);
	FND_GLOBAL.APPS_INITIALIZE(l_user_id, l_resp_id, l_resp_appl_id);
	
   FOR r_move_transfer in c_move_transfer LOOP
   
   l_trolin_tbl.delete;
   x_trolin_tbl.delete;
   xxha_inv_move_prt_prc(l_debug ,'/*=======================================================*/');
   xxha_inv_move_prt_prc(l_debug ,'Reference_id=>'||r_move_transfer.reference_id);
   xxha_inv_move_prt_prc(l_debug ,'ItemNO=>'||r_move_transfer.Item_no);
   xxha_inv_move_prt_prc(l_debug ,'SerialNUmber=>'||r_move_transfer.from_serial_no);
   xxha_inv_move_prt_prc(l_debug ,'Source Sub Inv=>'||r_move_transfer.source_sub_inv);
   xxha_inv_move_prt_prc(l_debug ,'Destination Sub Inv=>'||r_move_transfer.destination_sub_inv);
   
    BEGIN
        SELECT transaction_type_id
        INTO l_transaction_type_id
        FROM mtl_transaction_types
        WHERE transaction_type_name = p_transaction_type;--'Move order Transfer';
        xxha_inv_move_prt_prc(l_debug ,'Transaction Type Name=> '||p_transaction_type || ' '||'Transaction Type id=>'||l_transaction_type_id);
      EXCEPTION
      WHEN NO_DATA_FOUND THEN
        l_error_msg:=l_error_msg||' PROCEDURE:XXHA_INV_MOVE_ORDER_IMPORT_PRC: Error: transaction_type_name '||SQLERRM;
        xxha_inv_move_prt_prc(l_debug ,l_error_msg);
        l_error_flag:= 'Y';
      WHEN OTHERS THEN
        l_transaction_type_id:=0;
        l_error_flag         := 'Y';
      END;
	  
	  IF l_error_flag<>'Y' THEN
	 
	 	 BEGIN
  
	  
	  -- Initialize the move order header
		  l_trohdr_rec.description                :=   r_move_transfer.description;
          l_trohdr_rec.date_required              :=   sysdate ;
          l_trohdr_rec.organization_id            :=   r_move_transfer.organization_id;	
          l_trohdr_rec.from_subinventory_code     :=   r_move_transfer.source_sub_inv;
          l_trohdr_rec.to_subinventory_code       :=   r_move_transfer.destination_sub_inv;
          l_trohdr_rec.status_date                :=   sysdate;
          l_trohdr_rec.header_status     	      :=   INV_Globals.G_TO_STATUS_INCOMPLETE;  
          l_trohdr_rec.transaction_type_id        :=   l_transaction_type_id;---INV_GLOBALS.G_TYPE_TRANSFER_ORDER_SUBXFR; 
          l_trohdr_rec.move_order_type	          :=   INV_GLOBALS.G_MOVE_ORDER_REQUISITION; 
          l_trohdr_rec.db_flag                    :=   FND_API.G_TRUE;
          l_trohdr_rec.operation                  :=   INV_GLOBALS.G_OPR_CREATE;    
  
          -- Who columns       
          l_trohdr_rec.created_by                 :=  l_user_id;
          l_trohdr_rec.creation_date              :=  sysdate;
          l_trohdr_rec.last_updated_by            :=  l_user_id;
          l_trohdr_rec.last_update_date           :=  sysdate;

          -- create  line  for the  header created above                        
          l_trolin_tbl(l_row_cnt).date_required		  :=  sysdate;                                     
          l_trolin_tbl(l_row_cnt).organization_id 	:=  r_move_transfer.organization_id;        
          l_trolin_tbl(l_row_cnt).inventory_item_id	:=   r_move_transfer.inventory_item_id; --2477; 
          l_trolin_tbl(l_row_cnt).REVISION          :=    r_move_transfer.revision;    		 --02005-110-EP    
          l_trolin_tbl(l_row_cnt).from_subinventory_code :=  r_move_transfer.source_sub_inv;                                        
          l_trolin_tbl(l_row_cnt).to_subinventory_code	:=  r_move_transfer.destination_sub_inv;    
          l_trolin_tbl(l_row_cnt).quantity		          :=  r_move_transfer.quantity;                                          
          l_trolin_tbl(l_row_cnt).status_date		        :=  sysdate;                                      
          l_trolin_tbl(l_row_cnt).uom_code	          	:=  r_move_transfer.UOM;  
          l_trolin_tbl(l_row_cnt).line_id                   := fnd_api.g_miss_num;		  
          l_trolin_tbl(l_row_cnt).line_number	        	:= l_row_cnt;                                   
          l_trolin_tbl(l_row_cnt).line_status		        :=INV_Globals.G_TO_STATUS_INCOMPLETE;          
          l_trolin_tbl(l_row_cnt).db_flag		            := FND_API.G_TRUE;                               
          l_trolin_tbl(l_row_cnt).operation		          := INV_GLOBALS.G_OPR_CREATE; 
          l_trolin_tbl(l_row_cnt).serial_number_start		:=r_move_transfer.from_serial_no;
          l_trolin_tbl(l_row_cnt).serial_number_end		:=    r_move_transfer.to_serial_no;
  
          -- Who columns
          l_trolin_tbl(l_row_cnt).created_by		    := l_user_id;                           
          l_trolin_tbl(l_row_cnt).creation_date	  	:= sysdate;                                      
          l_trolin_tbl(l_row_cnt).last_updated_by	  := l_user_id;                           
          l_trolin_tbl(l_row_cnt).last_update_date	:= sysdate;                                      
          l_trolin_tbl(l_row_cnt).last_update_login	:= FND_GLOBAL.login_id; 

           -- call API to create move order header
          xxha_inv_move_prt_prc(l_debug ,'=======================================================');
          xxha_inv_move_prt_prc(l_debug ,'Calling INV_MOVE_ORDER_PUB.Process_Move_Order API');        
  
         INV_MOVE_ORDER_PUB.Process_Move_Order( 
                   P_API_VERSION_NUMBER   => l_api_version
                ,  P_INIT_MSG_LIST        => l_init_msg_list
                ,  P_RETURN_VALUES        => l_return_values
                ,  P_COMMIT               => l_commit
                ,  X_RETURN_STATUS        => x_return_status
                ,  X_MSG_COUNT            => x_msg_count
                ,  X_MSG_DATA             => x_msg_data
                ,  P_TROHDR_REC           => l_trohdr_rec
                ,  P_TROHDR_VAL_REC       => l_trohdr_val_rec
                ,  P_TROLIN_TBL           => l_trolin_tbl
                ,  P_TROLIN_VAL_TBL	      => l_trolin_val_tbl
                ,  X_TROHDR_REC	          => x_trohdr_rec
                ,  X_TROHDR_VAL_REC       => x_trohdr_val_rec
                ,  X_TROLIN_TBL	          => x_trolin_tbl
                ,  X_TROLIN_VAL_TBL       => x_trolin_val_tbl          
        ); 
 
          xxha_inv_move_prt_prc(l_debug ,'=======================================================');
          xxha_inv_move_prt_prc(l_debug ,'Return Status: '||x_return_status);
  
         IF (x_return_status <> FND_API.G_RET_STS_SUCCESS) THEN
            FOR v_index IN 1 .. x_msg_count
         LOOP
            fnd_msg_pub.get (p_msg_index => v_index, p_encoded => 'F', p_data => x_msg_data,p_msg_index_out => v_msg_index_out);
            x_msg_data := SUBSTR (x_msg_data, 1, 200);
			--l_msg_data:=l_msg_data||' '||x_msg_data;
             xxha_inv_move_prt_prc(l_debug ,l_msg_data);
             xxha_inv_move_prt_prc(l_debug ,'/*============================================================*/');
         END LOOP;
		 BEGIN 
		 
		 UPDATE xxha_inv_move_order_txfr_tbl
		 SET Transaction_type=p_transaction_type,
		     transaction_type_id=l_transaction_type_id,
			 move_order_type='REQUISITION',
			 move_order_type_id =INV_GLOBALS.G_MOVE_ORDER_REQUISITION,
			 process_flag='E',
			 error_msg=x_msg_data		 
		 WHERE reference_id        = r_move_transfer.reference_id
              AND process_flag          ='V';
              COMMIT;
		 
		 
		 EXCEPTION 
     when others then 
		 l_error_msg:='PROCEDURE:XXHA_INV_MOVE_ORDER_IMPORT_PRC:UPDATING ERROR FAILED'||SQLERRM;
              xxha_inv_move_prt_prc(L_DEBUG ,l_error_msg);
		 
		 
		 END;
		 
		 
         END IF;
         
         IF (x_return_status = FND_API.G_RET_STS_SUCCESS) THEN
		 commit;
             xxha_inv_move_prt_prc(l_debug ,'Move Order Created Successfully for '||x_trolin_tbl(l_row_cnt).header_id);
			 xxha_inv_move_prt_prc(l_debug ,'Move Order line Created Successfully for '||x_trolin_tbl(l_row_cnt).line_id);
		xxha_inv_move_prt_prc(l_debug ,'Approved');
		Inv_trohdr_Util.Update_Row_Status(x_trolin_tbl(l_row_cnt).header_id,Inv_Globals.G_TO_STATUS_APPROVED);  
	    for i in (select line_id from mtl_txn_request_lines where header_id = x_trolin_tbl(l_row_cnt).header_id ) loop
                 Inv_trolin_Util.Update_Row_Status(i.line_id ,
                                             INV_Globals.G_TO_STATUS_APPROVED);
         end loop;
		 
		 xxha_inv_move_prt_prc(l_debug ,'/*=======================================================*/');
		 
		  BEGIN 
		 
		 UPDATE xxha_inv_move_order_txfr_tbl
		 SET Transaction_type=p_transaction_type,
		     transaction_type_id=l_transaction_type_id,
			 move_order_type='REQUISITION',
			 move_order_type_id =INV_GLOBALS.G_MOVE_ORDER_REQUISITION,
			 move_order_no=x_trolin_tbl(l_row_cnt).header_id,
			 process_flag='S'				 
		 WHERE reference_id        = r_move_transfer.reference_id
              AND process_flag          ='V';
              COMMIT;
		 
		 
		 EXCEPTION 
       when others then 
		 l_error_msg:='PROCEDURE:XXHA_INV_MOVE_ORDER_IMPORT_PRC:UPDATING SUCESS FAILED'||SQLERRM;
         xxha_inv_move_prt_prc(L_DEBUG ,l_error_msg);
		 
		 
		 END;
		 
		 
					  
         END IF ;
   EXCEPTION 
   WHEN OTHERS THEN
          l_error_msg:='PROCEDURE:XXHA_INV_MOVE_ORDER_IMPORT_PRC: Error: Transaction API calling=>'||SQLERRM;
          xxha_inv_move_prt_prc(L_DEBUG ,l_error_msg);
   
   END;
  
   END IF;
   
   END LOOP;
   xxha_inv_move_out_prnt;
   END xxha_inv_move_order_import_prc;
   
   PROCEDURE xxha_inv_move_prt_prc
   (
   p_debug VARCHAR2,
   p_msg   VARCHAR2)
   AS
   BEGIN
   IF (p_debug = 'Y') THEN
      dbms_output.put_line(p_msg);
      fnd_file.put_line(fnd_file.log,p_msg);
    END IF;
  EXCEPTION
  WHEN OTHERS THEN
    fnd_file.put_line(fnd_file.log,'Error while writing the '||P_MSG||' to the log file. Error is '||SQLERRM);
  END xxha_inv_move_prt_prc;
  
   PROCEDURE xxha_inv_move_out_prnt
   AS
    l_total_count   NUMBER;
    l_fail_count    NUMBER;
    l_success_count NUMBER;
	CURSOR cur_success
    IS
      SELECT * FROM xxha_inv_move_order_txfr_tbl WHERE 1=1 AND process_flag = 'S';
    CURSOR cur_fail
    IS
      SELECT *
      FROM xxha_inv_move_order_txfr_tbl
      WHERE 1                     =1
      AND NVL (process_flag, 'E') = 'E';
   BEGIN
    BEGIN
      SELECT COUNT (*) INTO l_total_count FROM xxha_inv_move_order_txfr_tbl;
      -- WHERE created_by = fnd_global.user_id;
    EXCEPTION
    WHEN OTHERS THEN
      l_total_count := 0;
    END;
    BEGIN
      SELECT COUNT (*)
      INTO l_success_count
      FROM xxha_inv_move_order_txfr_tbl
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
      FROM xxha_inv_move_order_txfr_tbl
      WHERE 1                     = 1
      AND NVL (process_flag, 'E') = 'E';
      -- AND created_by = fnd_global.user_id;
    EXCEPTION
    WHEN OTHERS THEN
      l_fail_count := 0;
    END;
	IF l_total_count > 0 THEN
      fnd_file. put_line (fnd_file.OUTPUT, '***************MOVE ORDER TRANSACTION SUMMARY*****************');
      IF l_success_count > 0 THEN
        fnd_file. put_line ( fnd_file.OUTPUT, 'Total Records Succeed ' || ' ' || l_success_count || ' ' || 'of' || ' ' || l_total_count);
        fnd_file.put_line ( fnd_file.OUTPUT,RPAD ('New Move Order  ', 25) ||RPAD ('Organization Code ', 25) || RPAD ('Item', 25) || RPAD ('Revision', 15) ||RPAD ('Description', 35)|| RPAD (' Source SubInventory', 25)||RPAD ('Destination SubInventory', 25)  || RPAD ('Quantity', 25) || RPAD ('Serial number ', 25)  );
        FOR i IN cur_success
        LOOP
          fnd_file. put_line ( fnd_file.OUTPUT,RPAD (i.move_order_no, 25)|| RPAD (i.organization_code, 25) || RPAD (i.item_no, 25) || RPAD (i.revision, 15)||RPAD (i.description, 35) || RPAD (i.source_sub_inv, 25) || RPAD (i.destination_sub_inv, 25)|| RPAD (i.quantity, 25) || RPAD (i.from_serial_no, 25) );
        END LOOP;
      END IF;
	   IF l_fail_count > 0 THEN
        fnd_file. put_line ( fnd_file.OUTPUT, 'Total Records Failed ' || ' ' || l_fail_count || ' ' || 'of' || ' ' || l_total_count);
        fnd_file.put_line (fnd_file.OUTPUT, '');
        fnd_file. put_line (fnd_file.OUTPUT, '***************Exception Report*****************');
        fnd_file.put_line ( fnd_file.OUTPUT, RPAD ('Organization Code ', 25) || RPAD ('Item', 25) || RPAD ('Revision', 15)||RPAD ('Description', 35) || RPAD ('Source SubInventory', 25)||RPAD ('Destination SubInventory', 25) ||RPAD ('Quantity', 25)|| RPAD ('Serial number ', 25) || RPAD ('Error Explanation', 25) );
        FOR rec_err IN cur_fail        
        LOOP
          fnd_file. put_line ( fnd_file.OUTPUT,RPAD (rec_err.organization_code, 25)|| RPAD (rec_err.item_no, 25)  || RPAD (rec_err.revision, 15)||RPAD (rec_err.Description, 25) || RPAD (rec_err.source_sub_inv, 25)||RPAD (rec_err.destination_sub_inv, 25)||RPAD (rec_err.quantity, 25)|| RPAD (rec_err.from_serial_no,25) || RPAD (rec_err.error_msg, 250));
        END LOOP;
      ELSE
        fnd_file.put_line (fnd_file.OUTPUT, 'All records are succesfully processed');
      END IF;
    END IF;
  
   END xxha_inv_move_out_prnt;
   
   

END xxha_inv_move_order_txfr_pkg; 