create table haemo.xxha_oe_surge_order_tbl(reference_id NUMBER,item_id NUMBER,trigger_qty NUMBER,notify_mail_addr_lkp VARCHAR2(240),exclude_customer_lkp VARCHAR2(240),
                                            created_by NUMBER,creation_date DATE,last_updated_by NUMBER,last_update_date DATE,last_update_login NUMBER);

create or replace synonym  xxha_oe_surge_order_tbl for haemo.xxha_oe_surge_order_tbl;

CREATE TABLE haemo.xxha_oe_surge_order_temp(cust_account_id NUMBER,site_use_id NUMBER,item_id NUMBER,process_date DATE,request_id NUMBER);

create or replace synonym  xxha_oe_surge_order_temp for haemo.xxha_oe_surge_order_temp;