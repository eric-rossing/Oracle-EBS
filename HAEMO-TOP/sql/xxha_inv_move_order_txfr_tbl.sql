CREATE TABLE haemo.xxha_inv_move_order_txfr_tbl
(
reference_id                NUMBER,
item_no                    	VARCHAR2(240),
inventory_item_id           NUMBER,
revision 					VARCHAR2(20),
description  				VARCHAR2(240),
source_sub_inv 				VARCHAR2(240),
destination_sub_inv 		VARCHAR2(240),
organization_code 			VARCHAR2(240),
organization_id 			NUMBER,
Transaction_type 			VARCHAR2(240),  
transaction_type_id 		NUMBER,
move_order_type 			VARCHAR2(240),
move_order_type_id 			NUMBER,
uom 						VARCHAR2(3),
quantity 					NUMBER,
from_serial_no 				VARCHAR2(240),
to_serial_no 				VARCHAR2(240),
move_order_no 				NUMBER,
process_flag 				VARCHAR2(3),
error_flag 					VARCHAR2(240),
error_msg 					VARCHAR2(1000),
reference_text          	VARCHAR2(1000),
creation_date        		DATE,
last_update_date        	DATE,
created_by              	VARCHAR2(50 BYTE),
last_updated_by         	VARCHAR2(50 BYTE),
last_update_login       	NUMBER);
	
	/
	
    
CREATE SYNONYM xxha_inv_move_order_txfr_tbl FOR  haemo.xxha_inv_move_order_txfr_tbl