create or replace PACKAGE BODY IBY_FD_EXTRACT_EXT_PUB
/*******************************************************************************************************
  * Object Name: IBY_FD_EXTRACT_EXT_PUB
  * Object Type: PACKAGE
  *
  * Description: This Package is used to provide custom code for AP Payment processing
  *
  * Modification Log:
  * Developer          Date                 Description
  *-----------------   ------------------   ------------------------------------------------
  * Eric Rossing       07-DEC-2015          Modified HSBC payment file section to include corporate address in file
  * Eric Rossing       27-SEP-2018          INC0129727 - Add Check Payments to JP Morgan interface
  * Eric Rossing       28-SEP-2018          INC0139357 - Invoice Due Date on JPM payment files
  * Eric Rossing       04-DEC-2018          INC0174251 - Include Discount Dates in Invoice Due Date calculation
  * Eric Rossing       21-DEC-2018          INC0172289 - Update discount date logic to use >= instead of >
  * Eric Rossing       05-MAR-2019          INC0188852 - Fix for Payments with no payment date, improved date logging
  * Eric Rossing       31-JUL-2019          PRJTASK0017153 - Fix control totals in Get_Ins_Ext_Agg
  * Eric Rossing       19-NOV-2019          PRJTASK0017153 - Add SUA payment type
  *******************************************************************************************************/AS
  /* $Header: ibyfdxeb.pls 120.2 2006/09/20 18:52:12 frzhang noship $ */
  --
  -- This API is called once only for the payment instruction.
  -- Implementor should construct the extract extension elements
  -- at the payment instruction level as a SQLX XML Aggregate
  -- and return the aggregate.
  --
  -- Below is an example implementation:
  /*
  FUNCTION Get_Ins_Ext_Agg(p_payment_instruction_id IN NUMBER)
  RETURN XMLTYPE
  IS
  l_ins_ext_agg XMLTYPE;
  CURSOR l_ins_ext_csr (p_payment_instruction_id IN NUMBER) IS
  SELECT XMLConcat(
  XMLElement("Extend",
  XMLElement("Name", ext_table.attr_name1),
  XMLElement("Value", ext_table.attr_value1)),
  XMLElement("Extend",
  XMLElement("Name", ext_table.attr_name2),
  XMLElement("Value", ext_table.attr_value2))
  )
  FROM your_pay_instruction_lvl_table ext_table
  WHERE ext_table.payment_instruction_id = p_payment_instruction_id;
  BEGIN
  OPEN l_ins_ext_csr (p_payment_instruction_id);
  FETCH l_ins_ext_csr INTO l_ins_ext_agg;
  CLOSE l_ins_ext_csr;
  RETURN l_ins_ext_agg;
  END Get_Ins_Ext_Agg;
  */
FUNCTION Get_Ins_Ext_Agg(
        p_payment_instruction_id IN NUMBER)
    RETURN XMLTYPE
IS
    v_negot_payment_count NUMBER;
    v_payment_total       NUMBER;
    v_checkrun_name       VARCHAR2(150);
    v_payment_type2       xmltype;
    v_pay_cnt             NUMBER;
BEGIN
    SELECT count(payment_id)
    into v_pay_cnt
    FROM IBY_PAYMENTS_ALL
    where payment_instruction_id = p_payment_instruction_id;
    if v_pay_cnt > 1 then
        SELECT iba.payment_process_request_name ,
            COUNT(iba.payment_id) ,
            sum(iba.payment_amount)
        INTO v_checkrun_name,
            v_negot_payment_count,
            v_payment_total
        FROM iby_payments_all iba
        WHERE 1                      =1
            AND iba.payment_instruction_id = p_payment_instruction_id
        GROUP BY payment_process_request_name;
    else
        SELECT iba.payment_process_request_name ,
            COUNT(iba.payment_id) ,
            iba.payment_amount
        INTO v_checkrun_name,
            v_negot_payment_count,
            v_payment_total
        FROM iby_payments_all iba,
            iby_docs_payable_all idpa
        WHERE 1                      =1
            AND iba.payment_id = idpa.payment_id
            AND iba.payment_instruction_id = p_payment_instruction_id
        GROUP BY payment_process_request_name,iba.payment_amount;
    end if;
    SELECT XMLConcat( xmlelement("Extend1",
                xmlelement("xx_payment_batch", v_checkrun_name),
                xmlelement("xx_negot_payment_count", v_negot_payment_count),
                xmlelement("xx_payment_total", v_payment_total)
            )) INTO v_payment_type2
    FROM DUAL;
    RETURN v_payment_type2;
END Get_Ins_Ext_Agg;
--
-- This API is called once per payment.
-- Implementor should construct the extract extension elements
-- at the payment level as a SQLX XML Aggregate
-- and return the aggregate.
--
FUNCTION Get_Pmt_Ext_Agg(
    p_payment_id IN NUMBER)
  RETURN XMLTYPE
IS
-- Eric Rossing - INC0139357 - Invoice Due Date on JPM payment files
    v_us_payment_date varchar2(50);
    v_xml_extend xmltype;
-- Eric Rossing - INC0174251 - Include Discount Dates in Invoice Due Date calculation
    v_payment_date date;
    v_due_date date;
    v_first_disc_date date;
    v_second_disc_date date;
    v_third_disc_date date;
    v_us_pay_date date;   
    v_payment_reference_number iby_payments_all.payment_reference_number%type;
    v_payment_document_number iby_payments_all.paper_document_number%type;
    v_invoice_nums varchar(2048) := '';
    v_org_id iby_payments_all.org_id%type;
    v_org_short_code varchar(5);
    CURSOR c_payment_invoices IS
        select distinct aia.invoice_num
        from iby_payments_all ipa,
            iby_docs_payable_all idpa,
            ap_invoices_all aia
        where ipa.payment_id=idpa.payment_id
            and to_number(idpa.calling_app_doc_unique_ref2)=aia.invoice_id
            and ipa.payment_id = p_payment_id;
BEGIN
--    select distinct
--    to_char(greatest(iba.payment_date, nvl(iba.payment_due_date, iba.payment_date)),'YYYY-MM-DD')
--  into v_us_payment_date
--  FROM iby_payments_all iba
--  WHERE 1                      = 1
--  AND iba.payment_id           = p_payment_id;
    FND_FILE.PUT_LINE(FND_FILE.LOG, '===Finding Payment Requested Execution Date==='  );
    FND_FILE.PUT_LINE(FND_FILE.LOG, 'Payment ID: ' || p_payment_id);

  select distinct
    iba.payment_date, iba.payment_due_date, iba.paper_document_number, iba.payment_reference_number, iba.org_id
  into v_payment_date, v_due_date, v_payment_document_number, v_payment_reference_number, v_org_id
  FROM iby_payments_all iba
  WHERE 1                      = 1
  AND iba.payment_id           = p_payment_id;

FND_FILE.PUT_LINE(FND_FILE.LOG, 'Payment Reference Number: ' || v_payment_reference_number);
FND_FILE.PUT_LINE(FND_FILE.LOG, 'Paper Document Number: ' || v_payment_document_number);
    FND_FILE.PUT(FND_FILE.LOG, 'Invoice(s): ');
    FOR rec IN c_payment_invoices LOOP
        v_invoice_nums := v_invoice_nums || rec.invoice_num || ', ';
    END LOOP;
    v_invoice_nums := RTRIM(v_invoice_nums, ', ');
    FND_FILE.PUT_LINE(FND_FILE.LOG, v_invoice_nums);

FND_FILE.PUT_LINE(FND_FILE.LOG, 'Payment Date(v_payment_date): ' || v_payment_date);
FND_FILE.PUT_LINE(FND_FILE.LOG, 'Invoice Due Date(v_due_date): ' || v_due_date);

  if v_due_date is null then
    v_us_pay_date := v_payment_date;
  else
    select distinct 
        case when apsa.discount_date>=ipa.payment_date then apsa.discount_date else null end discount_date, 
        case when apsa.second_discount_date>=ipa.payment_date then apsa.second_discount_date else null end second_discount_date, 
        case when apsa.third_discount_date>=ipa.payment_date then apsa.third_discount_date else null end third_discount_date
    into v_first_disc_date, v_second_disc_date, v_third_disc_date
    from apps.iby_payments_all ipa,
        apps.iby_docs_payable_all idpa,
        apps.ap_payment_schedules_all apsa
    where ipa.payment_id=idpa.payment_id
        and to_number(idpa.calling_app_doc_unique_ref2)=apsa.invoice_id
        and ipa.payment_id = p_payment_id;
FND_FILE.PUT_LINE(FND_FILE.LOG, 'First Discount Date(v_first_disc_date): ' || v_first_disc_date);
FND_FILE.PUT_LINE(FND_FILE.LOG, 'Second Discount Date(v_second_disc_date): ' || v_second_disc_date);
FND_FILE.PUT_LINE(FND_FILE.LOG, 'Third Discount Date(v_third_disc_date): ' || v_third_disc_date);
    if nvl(v_first_disc_date,'01-JAN-2000')>=v_payment_date then
        v_us_pay_date := v_first_disc_date;
    elsif nvl(v_second_disc_date,'01-JAN-2000')>=v_payment_date then
        v_us_pay_date := v_second_disc_date;
    elsif nvl(v_third_disc_date,'01-JAN-2000')>=v_payment_date then
        v_us_pay_date := v_third_disc_date;
    elsif v_due_date>=v_payment_date then
        v_us_pay_date := v_due_date;
    else
        v_us_pay_date := v_payment_date;
    end if;
  end if;
  v_us_payment_date := to_char(v_us_pay_date, 'YYYY-MM-DD');
FND_FILE.PUT_LINE(FND_FILE.LOG, 'JPM Requested Execution Date(v_us_payment_date): ' || v_us_payment_date);

select hou.short_code
into v_org_short_code
from hr_operating_units hou
where hou.organization_id = v_org_id;
FND_FILE.PUT_LINE(FND_FILE.LOG, 'Payment OU Short Code: ' || v_org_short_code);
FND_FILE.PUT_LINE(FND_FILE.LOG, '==============================================');
-- Eric Rossing - INC0174251 - Include Discount Dates in Invoice Due Date calculation ends  
 SELECT XMLConcat( xmlelement("Extend",
                   xmlelement("xx_us_payment_date", v_us_payment_date),
                   xmlelement("xx_org_short_code", v_org_short_code)
                   )) INTO v_xml_extend
         FROM DUAL;
  RETURN v_xml_extend;  
-- Eric Rossing - INC0139357 - Invoice Due Date on JPM payment files ends

END Get_Pmt_Ext_Agg;
--
-- This API is called once per document payable.
-- Implementor should construct the extract extension elements
-- at the document level as a SQLX XML Aggregate
-- and return the aggregate.
--
FUNCTION Get_Doc_Ext_Agg(
    p_document_payable_id IN NUMBER)
  RETURN XMLTYPE
IS
BEGIN
  RETURN NULL;
END Get_Doc_Ext_Agg;
--
-- This API is called once per document payable line.
-- Implementor should construct the extract extension elements
-- at the doc line level as a SQLX XML Aggregate
-- and return the aggregate.
--
-- Parameters:
--   p_document_payable_id: primary key of IBY iby_docs_payable_all table
--   p_line_number: calling app doc line number. For AP this is
--   ap_invoice_lines_all.line_number.
--
-- The combination of p_document_payable_id and p_line_number
-- can uniquely locate a document line.
-- For example if the calling product of a doc is AP
-- p_document_payable_id can locate
-- iby_docs_payable_all/ap_documents_payable.calling_app_doc_unique_ref2,
-- which is ap_invoice_all.invoice_id. The combination of invoice_id and
-- p_line_number will uniquely identify the doc line.
--
FUNCTION Get_Docline_Ext_Agg(
    p_document_payable_id IN NUMBER,
    p_line_number         IN NUMBER)
  RETURN XMLTYPE
IS
  v_payment_type VARCHAR(120):=NULL;
  v_payment_type1 xmltype;
  v_hae_us_bank_name        VARCHAR(50) :='JPMorgan Chase'; -- TODO - get correct bank name
  V_SEPA                    VARCHAR2(1) := 'N';
  v_xx_sepa                 VARCHAR2(1) := 'N';
  p_hae_bank_acct_country   ce_bank_branches_v.country%type;
  p_hae_bank_acct_curr_code ce_bank_accounts.currency_code%type;
  p_supp_bank_acct_country  iby_ext_bank_branches_v.COUNTRY%type;
  p_payment_currency_code   iby_payments_all.payment_currency_code%type;
  p_supp_bank_name          iby_ext_banks_v.bank_name%type;
  p_supp_pay_group          ap_supplier_sites_all.pay_group_lookup_code%type;
  p_payment_method          iby_payments_all.payment_method_code%type;
  p_payment_batch           VARCHAR2(150);
  p_hae_bank_acct_id        NUMBER;
  p_supp_bank_acct_id       NUMBER;
  p_supp_remit_num          VARCHAR2(500);
  v_hae_location_id hr_locations.location_id%type;
  v_hae_corp_name hr_locations.address_line_1%type;
  v_hae_address_line_2 hr_locations.address_line_2%type;
  v_hae_address_line_3 hr_locations.address_line_3%type;
  v_hae_town_or_city hr_locations.town_or_city%type;
  v_hae_country hr_locations.country%type;
  v_hae_postal_code hr_locations.postal_code%type;
  v_ou_name hr_operating_units.name%type;
  v_hae_location_id1 hr_locations.location_id%type;
  v_hae_corp_name1 hr_locations.address_line_1%type;
  v_hae_corp_name2 hr_locations.address_line_1%type;
  v_hae_address_line_21 hr_locations.address_line_2%type;
  v_hae_address_line_31 hr_locations.address_line_3%type;
  v_hae_town_or_city1 hr_locations.town_or_city%type;
  v_hae_country1 hr_locations.country%type;
  v_hae_postal_code1 hr_locations.postal_code%type;
  v_ou_name1 hr_operating_units.name%type;
  v_us_payment_date1 varchar2(50);
  v_us_payment_date2 varchar2(50);
  v_eu_payment_date1 varchar2(50);
  v_eu_payment_date2 varchar2(50);
  v_rownum number;
  v_rownum1 number;
  V_PAYMENT_ID_NUMBER NUMBER;
  V_CHECK_WIRE  VARCHAR2(50);
  V_BANK_STR    VARCHAR2(100);
  v_supp_bank_name varchar2(100);
  v_supp_bank_branch_name varchar2(150);
  v_supp_bank_account_name varchar2(150);
  V_CURRENCY_CODE  VARCHAR2(50);
  v_name VARCHAR2(100);
  v_field_size NUMBER;
  v_pos NUMBER;
  v_field_count number;
  v_en_field_size NUMBER := 35;
  v_cn_field_size NUMBER := 11;
  --v_fields1 varchar2(100);      -- Removed by Eric Rossing 12/7/15 to include corporate address in file
  --v_fields2 varchar2(100);      -- Removed by Eric Rossing 12/7/15 to include corporate address in file
  v_fields3 varchar2(100);
  v_fields4 varchar2(100);
  v_fields5 varchar2(100);
  V_FIELDS6 VARCHAR2(100);
  V_FIELDS7 VARCHAR2(100);
  V_FIELDS8 VARCHAR2(100);
  v_org_id1 VARCHAr2(10);
  V_FIELDS XXHA_SPLIT_FIELDS;
  v_hsbc_first_party_name varchar2(100);      -- Added by Eric Rossing 12/7/15 to include corporate address in file
  v_hsbc_first_party_info_1 varchar2(100);      -- Added by Eric Rossing 12/7/15 to include corporate address in file
  v_hsbc_first_party_info_2 varchar2(100);      -- Added by Eric Rossing 12/7/15 to include corporate address in file
  v_hsbc_first_party_info_3 varchar2(100);      -- Added by Eric Rossing 12/7/15 to include corporate address in file

BEGIN
FND_FILE.PUT_LINE(FND_FILE.LOG, 'Came into the function '  );
FND_FILE.PUT_LINE(FND_FILE.LOG, 'org_id  '||TO_CHAR(V_ORG_ID)  );
  SELECT SUBSTR(IPA.INT_BANK_NAME,1,8) ,IDPA.PAYMENT_METHOD_CODE,IDPA.PAYMENT_CURRENCY_CODE,idpa.org_id
  INTO V_BANK_STR,V_CHECK_WIRE,V_CURRENCY_CODE,V_ORG_ID
  FROM IBY_DOCS_PAYABLE_ALL IDPA ,IBY_PAYMENTS_ALL IPA WHERE IDPA.DOCUMENT_PAYABLE_ID = P_DOCUMENT_PAYABLE_ID
AND IDPA.PAYMENT_ID = IPA.PAYMENT_ID;
FND_FILE.PUT_LINE(FND_FILE.LOG, 'org_id1  '||TO_CHAR(V_ORG_ID)  );
FND_FILE.PUT_LINE(FND_FILE.LOG, 'bank string  '||V_BANK_STR  );
--INC0129727 - Eric Rossing - JP Morgan Check Payment transmission
FND_FILE.PUT_LINE(FND_FILE.LOG, 'document payable id '||P_DOCUMENT_PAYABLE_ID);
FND_FILE.PUT_LINE(FND_FILE.LOG, 'line number '||P_LINE_number);
--IF V_CHECK_WIRE <> 'CHECK' THEN
IF V_CHECK_WIRE <> 'CHECK' OR V_BANK_STR='JPMorgan' THEN
--INC0129727 - Eric Rossing - JP Morgan Check Payment transmission ends
  SELECT DISTINCT abb_hae.country,
    aba_hae.currency_code,
    iebb.COUNTRY,
    iba.payment_currency_code,
    iba.ext_bank_name,
    ass.pay_group_lookup_code,
    idpa.payment_method_code ,
    iba.payment_process_request_name,
    idpa.internal_bank_account_id,
    idpa.external_bank_account_id,
    iba.payment_process_request_name,
    iba.ext_bank_account_name,
    iba.ext_bank_branch_name,
    aba_hae.attribute2,      -- Added by Eric Rossing 12/7/15 to include corporate address in file
    aba_hae.attribute3,      -- Added by Eric Rossing 12/7/15 to include corporate address in file
    aba_hae.attribute4,      -- Added by Eric Rossing 12/7/15 to include corporate address in file
    aba_hae.attribute5      -- Added by Eric Rossing 12/7/15 to include corporate address in file
  INTO p_hae_bank_acct_country ,
    p_hae_bank_acct_curr_code ,
    p_supp_bank_acct_country ,
    p_payment_currency_code ,
    p_supp_bank_name ,
    p_supp_pay_group ,
    p_payment_method ,
    p_payment_batch ,
    p_hae_bank_acct_id ,
    p_supp_bank_acct_id,
    p_payment_batch,
    v_supp_bank_account_name,
    v_supp_bank_branch_name,
    v_hsbc_first_party_name,      -- Added by Eric Rossing 12/7/15 to include corporate address in file
    v_hsbc_first_party_info_1,      -- Added by Eric Rossing 12/7/15 to include corporate address in file
    v_hsbc_first_party_info_2,      -- Added by Eric Rossing 12/7/15 to include corporate address in file
    v_hsbc_first_party_info_3      -- Added by Eric Rossing 12/7/15 to include corporate address in file
  FROM ap_document_lines_v apdl,
    iby_payments_all iba,
    iby_docs_payable_all idpa,
    ap_supplier_sites_all ass,
    iby_pay_service_requests ibypsr,
    ce_bank_accounts aba_hae,
    ce_bank_branches_v abb_hae,
    iby_ext_bank_accounts ieb,
    iby_ext_bank_branches_v iebb
  WHERE 1                      = 1
  AND idpa.document_payable_id = p_document_payable_id
  AND apdl.line_number         = p_line_number
  AND iba.payment_id           = idpa.payment_id
  AND idpa.supplier_site_id    = ass.vendor_site_id
  AND apdl.CALLING_APP_DOC_UNIQUE_REF2 = idpa.CALLING_APP_DOC_UNIQUE_REF2
  AND idpa.CALLING_APP_ID              = APDL.CALLING_APP_ID
  AND idpa.payment_service_request_id  = ibypsr.payment_service_request_id
  AND aba_hae.bank_branch_id           = abb_hae.branch_party_id
  AND aba_hae.bank_account_id          = iba.internal_bank_account_id
  AND iba.external_bank_account_id     = ieb.ext_bank_account_id (+)
--INC0129727 - Eric Rossing - JP Morgan Check Payment transmission
--  AND IEB.BRANCH_ID                    = IEBB.BRANCH_PARTY_ID;
  AND IEB.BRANCH_ID                    = IEBB.BRANCH_PARTY_ID (+);
--INC0129727 - Eric Rossing - JP Morgan Check Payment transmission ends

FND_FILE.PUT_LINE(FND_FILE.LOG,'1.5'||P_DOCUMENT_PAYABLE_ID||'-'||P_LINE_number||'-'||to_char(v_org_id));

  SELECT DISTINCT jii.jgzz_invoice_info1
  INTO p_supp_remit_num
  FROM ap_document_lines_v apdl,
    iby_payments_all iba,
    iby_docs_payable_all idpa,
    ap_invoices_all ai,
    ap_payment_schedules_all apsa,
    jg_zz_invoice_info jii
  WHERE 1                                          = 1
  AND idpa.document_payable_id                     = p_document_payable_id
  AND apdl.line_number                             = p_line_number
  AND apdl.calling_app_doc_unique_ref2             = idpa.calling_app_doc_unique_ref2
  AND idpa.CALLING_APP_ID                          = APDL.CALLING_APP_ID
  AND iba.payment_id                               = idpa.payment_id
  AND to_number (idpa.calling_app_doc_unique_ref2) = ai.invoice_id
  AND ai.invoice_id                                = jii.invoice_id (+)
  AND ai.invoice_id                                = apsa.invoice_id
  AND IBA.ORG_ID                                   = V_ORG_ID
  AND AI.ORG_ID                                    = V_ORG_ID;
  FND_FILE.PUT_LINE(FND_FILE.LOG,'1.75'||P_DOCUMENT_PAYABLE_ID||'-'||P_LINE_NUMBER);
  IF (V_BANK_STR = 'HK and S' OR V_CURRENCY_CODE = 'HKD' or V_BANK_STR ='HSBC Ban') THEN
  FND_FILE.PUT_LINE(FND_FILE.log,'ven1');
  if v_hsbc_first_party_name is null then
    select   hl.address_line_1 hae_corp_name
      INTO
         v_hae_corp_name2
      from   hr_operating_units hou
      , 	   hr_all_organization_units haou
      ,	   hr_locations hl
      where  hou.organization_id = v_org_id
      and    hou.organization_id = haou.organization_id
      and	   haou.location_id = hl.location_id
      ;
    FND_FILE.PUT_LINE(FND_FILE.log,'ven2');
    begin
      v_name := replace(replace(v_hae_corp_name2,'?','??'),',','?,');
      v_field_count := 0;
      v_pos := 1;
      v_fields := XXHA_SPLIT_FIELDS('','','','');
      IF ASCII(SUBSTR(v_name,1,1)) > 255 THEN
        v_field_size := v_cn_field_size;
      ELSE
        v_field_size := v_en_field_size;
      END IF;

      WHILE v_pos <= LENGTH(v_name) AND v_field_count < 4 LOOP
        v_field_count := v_field_count + 1;
        v_fields(v_field_count) := SUBSTR(v_name, v_pos, v_field_size);
        v_pos := v_pos + v_field_size;
      END LOOP;
--      v_fields1 := v_fields(1);      -- Removed by Eric Rossing 12/7/15 to include corporate address in file
--      v_fields2 := v_fields(2);      -- Removed by Eric Rossing 12/7/15 to include corporate address in file
      v_hsbc_first_party_name := v_fields(1);      -- Added by Eric Rossing 12/7/15 to include corporate address in file
      v_hsbc_first_party_info_1 := v_fields(2);      -- Added by Eric Rossing 12/7/15 to include corporate address in file
      v_hsbc_first_party_info_2 := v_fields(3);      -- Added by Eric Rossing 12/7/15 to include corporate address in file
      v_hsbc_first_party_info_3 := v_fields(4);      -- Added by Eric Rossing 12/7/15 to include corporate address in file
    end;
  end if;
  FND_FILE.PUT_LINE(FND_FILE.log,'ven3');

    begin
    v_name := replace(replace(v_supp_bank_account_name,'?','??'),',','?,');
    v_field_count := 0;
    v_pos := 1;
    v_fields := XXHA_SPLIT_FIELDS('','','','');
    IF ASCII(SUBSTR(v_name,1,1)) > 255 THEN
		v_field_size := v_cn_field_size;
	ELSE
		v_field_size := v_en_field_size;
	END IF;

	WHILE v_pos <= LENGTH(v_name) AND v_field_count < 4 LOOP
		v_field_count := v_field_count + 1;
		v_fields(v_field_count) := SUBSTR(v_name, v_pos, v_field_size);
		v_pos := v_pos + v_field_size;
	END LOOP;
    v_fields3 := v_fields(1);
    v_fields4 := v_fields(2);
    v_fields5 := v_fields(3);
    v_fields6 := v_fields(4);
    end;
       FND_FILE.PUT_LINE(FND_FILE.log,'ven4');
    begin
    v_name := p_supp_bank_name || v_supp_bank_branch_name;
    v_field_count := 0;
    v_pos := 1;
    v_fields := XXHA_SPLIT_FIELDS('','','','');
    IF ASCII(SUBSTR(v_name,1,1)) > 255 THEN
		v_field_size := v_cn_field_size;
	ELSE
		v_field_size := v_en_field_size;
	END IF;

	WHILE v_pos <= LENGTH(v_name) AND v_field_count < 4 LOOP
		v_field_count := v_field_count + 1;
		v_fields(v_field_count) := SUBSTR(v_name, v_pos, v_field_size);
		v_pos := v_pos + v_field_size;
	END LOOP;
    v_fields7 := v_fields(1);
    v_fields8 := v_fields(2);
    end;
    FND_FILE.PUT_LINE(FND_FILE.log,'ven5');
  END IF;
  FND_FILE.PUT_LINE(FND_FILE.log,'ven6');
  If V_BANK_STR = 'JPMorgan' THEN
  --IF p_payment_currency_code NOT                  IN ('CHF','TWD') THEN-- not in (243,158)
  FND_FILE.PUT_LINE(FND_FILE.log,'2');
    SELECT hl.location_id ,
      hl.address_line_1 ,
      hl.address_line_2 ,
      NVL(hl.address_line_3, 'NA') -- value required (atleast 1 character) if XML elemented listed
      ,
      hl.TOWN_OR_CITY ,
      hl.COUNTRY ,
      hl.postal_code ,
      hou.name
    INTO v_hae_location_id ,
      v_hae_corp_name ,
      v_hae_address_line_2 ,
      v_hae_address_line_3 ,
      v_hae_TOWN_OR_CITY ,
      v_hae_COUNTRY ,
      v_hae_postal_code ,
      v_ou_name
    FROM hr_operating_units hou ,
      hr_all_organization_units haou ,
      hr_locations hl
    WHERE hou.organization_id = v_org_id
    AND hou.organization_id   = haou.organization_id
    AND haou.location_id      = hl.location_id ;
    FND_FILE.PUT_LINE(FND_FILE.log,'ven7');
    select rownum
    INTO v_rownum
    FROM iby_payments_all iba,
      iby_docs_payable_all idpa
    WHERE 1                      =1
    AND idpa.document_payable_id = p_document_payable_id
    and iba.payment_id = idpa.payment_id;
    FND_FILE.PUT_LINE(FND_FILE.log,'ven8');
    SELECT HAE_US_PAYMENT_ID_SEQ.NEXTVAL
    INTO V_PAYMENT_ID_NUMBER
    FROM DUAL;
    select distinct
    to_char(iba.payment_date,'YYYY-MM-DD'),
    to_char(iba.payment_date,'YYYY-MM-DD HH12:MI:SS')
  into v_us_payment_date1,
       v_us_payment_date2
  FROM ap_document_lines_v apdl,
    iby_payments_all iba,
    iby_docs_payable_all idpa,
    ap_supplier_sites_all ass,
    iby_pay_service_requests ibypsr,
    ce_bank_accounts aba_hae,
    ce_bank_branches_v abb_hae,
    iby_ext_bank_accounts ieb,
    iby_ext_bank_branches_v iebb
  WHERE 1                      = 1
  AND idpa.document_payable_id = p_document_payable_id
  AND apdl.line_number         = p_line_number
  AND iba.payment_id           = idpa.payment_id
  AND idpa.supplier_site_id    = ass.vendor_site_id
  AND apdl.CALLING_APP_DOC_UNIQUE_REF2 = idpa.CALLING_APP_DOC_UNIQUE_REF2
  AND idpa.CALLING_APP_ID              = APDL.CALLING_APP_ID
  AND idpa.payment_service_request_id  = ibypsr.payment_service_request_id
  AND aba_hae.bank_branch_id           = abb_hae.branch_party_id
  AND aba_hae.bank_account_id          = iba.internal_bank_account_id
  and iba.external_bank_account_id     = ieb.ext_bank_account_id (+)
--INC0129727 - Eric Rossing - JP Morgan Check Payment transmission
--  and ieb.branch_id                    = iebb.branch_party_id;
  and ieb.branch_id                    = iebb.branch_party_id (+);
  FND_FILE.PUT_LINE(FND_FILE.LOG,'p_payment_method='||p_payment_method);
  IF p_payment_method = 'CHECK' THEN
    v_payment_type := 'US Check';
--PRJTASK0017153 - Eric Rossing - Add SUA payment type
  ELSIF p_payment_method = 'XXHA JPM SUA' THEN
    v_payment_type := 'US SUA';
--PRJTASK0017153 - Eric Rossing - Add SUA payment type ends
  ELSE
--INC0129727 - Eric Rossing - JP Morgan Check Payment transmission ends
    FND_FILE.PUT_LINE(FND_FILE.log,'p_hae_bank_acct_country='||p_hae_bank_acct_country);
    CASE p_hae_bank_acct_country
    WHEN 'US' THEN
    FND_FILE.PUT_LINE(FND_FILE.log, 'HAe Bank account country: ' || p_hae_bank_acct_country );
      -- 2012-06-05 Eric Rossing Modify payment type code so Supplier Banks in "PR" are treated the same as those in "US".
      IF p_supp_bank_acct_country IN ('US','PR') THEN
      FND_FILE.PUT_LINE(FND_FILE.log, 'supp Bank account country: ' || p_supp_bank_acct_country );
        IF P_PAYMENT_CURRENCY_CODE = 'USD' THEN
        FND_FILE.PUT_LINE(FND_FILE.log, 'HAe currency: ' || P_PAYMENT_CURRENCY_CODE );
          IF P_SUPP_BANK_NAME      = V_HAE_US_BANK_NAME THEN
          FND_FILE.PUT_LINE(FND_FILE.log, 'HAe payment method: ' || P_PAYMENT_METHOD );
            IF P_PAYMENT_METHOD    = 'WIRE' THEN
            FND_FILE.PUT_LINE(FND_FILE.log, 'HAe payment method: ' || P_PAYMENT_METHOD );
              v_payment_type      :='Book Transfer (Wire)'; -- Arthur's Matrix, row 9
            END IF;
          ELSE
            IF p_supp_pay_group  IN ('CONSULTANT','EMPLOYEE') THEN
            FND_FILE.PUT_LINE(FND_FILE.log, 'p_supp_pay_group:'||p_supp_pay_group);
              IF p_payment_method = 'EFT' THEN
              FND_FILE.PUT_LINE(FND_FILE.log, 'p_payment_method:'||p_payment_method);
                v_payment_type   :='ACH PPD'; -- Arthur's Matrix, row 7
              END IF;
            elsif p_payment_method = 'WIRE' THEN
            FND_FILE.PUT_LINE(FND_FILE.log, 'p_payment_method1:'||p_payment_method);
              v_payment_type      :='Domestic Wire'; -- Arthur's Matrix, row 8
            elsif p_payment_method = 'EFT' THEN
            FND_FILE.PUT_LINE(FND_FILE.log, 'p_payment_method2:'||p_payment_method);
              v_payment_type      :='ACH CCD'; -- Arthur's Matrix, row 6
            END IF;
          END IF;
        elsif p_payment_method = 'WIRE' THEN      -- Hae bank = US, Payee bank = US, Payment currency <> USD
        FND_FILE.PUT_LINE(FND_FILE.log, 'p_payment_method3:'||p_payment_method);
          v_payment_type      :='US Wire AutoFX'; -- Arthur's Matrix, row 11, 15
        END IF;
      elsif p_payment_method       = 'WIRE' THEN -- Hae bank = US, Payee bank = non-US
      FND_FILE.PUT_LINE(FND_FILE.log, 'p_payment_method4:'||p_payment_method);
        IF p_payment_currency_code = 'USD' THEN
        FND_FILE.PUT_LINE(FND_FILE.log, 'p_payment_currency_code:'||p_payment_currency_code);
          v_payment_type          :='CHIPS'; -- Arthur's Matrix, rows 10, 13
        ELSE                                 -- Hae bank = US, Payee bank = non-US, Currency = non-USD
          v_payment_type:='US Wire AutoFX';  -- Arthur's Matrix, row 12, 14
          FND_FILE.PUT_LINE(FND_FILE.log, 'v_payment_type:'||v_payment_type);
        END IF;
        FND_FILE.PUT_LINE(FND_FILE.log,'v_payment_type='||v_payment_type);
      END IF;
    WHEN 'CA' THEN
    FND_FILE.PUT_LINE(FND_FILE.log,'4CA');
      IF p_hae_bank_acct_curr_code  = 'CAD' AND p_supp_bank_acct_country = 'CA' AND p_payment_currency_code = 'CAD' AND p_supp_bank_name = v_hae_us_bank_name THEN
        v_payment_type             :='Canada Wire (Book)';                           -- Arthur's Matrix, row 23
      elsif p_payment_method        = 'EFT' AND p_supp_bank_acct_country = 'CA' THEN -- country check excludes rows 20, 26, 32, 38 -- GACH only allowed to banks in Canada
        v_payment_type             :='GACH-CA';                                      -- Arthur's Matrix, rows 17,24, 30, 37,
      elsif p_payment_method        = 'WIRE' THEN
        IF p_supp_bank_acct_country = 'CA' THEN
          v_payment_type           :='Canada Wire'; -- Arthur's Matrix, rows 18, 21, 27, 29, 33, 35, 39
        ELSE
          v_payment_type:='Canada Wire Intl'; -- Arthur's Matrix, rows 19, 22. 25, 28, 31, 34, 36, 40
        END IF;
      END IF;
    WHEN 'UK' THEN
    FND_FILE.PUT_LINE(FND_FILE.log,'5UK');
      IF p_hae_bank_acct_curr_code = 'EUR' THEN
        IF p_payment_method        = 'EFT' THEN
          BEGIN ------
            IF p_payment_currency_code = 'EUR' AND p_payment_method = 'EFT' AND p_hae_bank_acct_curr_code = 'EUR' THEN
              -- R12 Upgrade Modified on 09/25/2012 by Venkatesh Sarangam, Rolta
              SELECT NVL(MAX(1), 0)
              INTO vExist
              FROM dual
              WHERE EXISTS
                (SELECT 'To see if Debtor(HAE) bank a/c exists in Listed Countries'
                FROM iby_payments_all iba,
                  ce_bank_accounts cba,
                  ce_bank_branches_v cbb
                WHERE iba.payment_process_request_name = p_payment_batch
                AND cba.bank_account_id                = p_hae_bank_acct_id
                AND iba.org_id                         = v_org_id
                AND iba.internal_bank_account_id = cba.bank_account_id
                AND cba.iban_number             IS NOT NULL ------------------- Mandatory for SEPA
                AND cba.bank_branch_id           = cbb.branch_party_id
                AND cbb.eft_swift_code          IS NOT NULL --------------- Mandatory for SEPA
                AND EXISTS
                  (SELECT 'Country matching with Attribute2'
                  FROM FND_LOOKUP_VALUES_VL flvt
                  WHERE flvt.lookup_type      = 'HAE_BANK_COUNTRIES'
                  AND flvt.attribute_category = 'HAE_BANK_COUNTRIES'
                  AND flvt.enabled_flag       = 'Y'
                  AND TRUNC(SYSDATE) BETWEEN TRUNC(flvt.START_DATE_ACTIVE) AND NVL(TRUNC(flvt.END_DATE_ACTIVE), TRUNC(SYSDATE)+1)
                  AND flvt.lookup_code = cbb.country
                  AND flvt.attribute2  = 'Y'
                  )
                )
              AND EXISTS
                (SELECT 'To see if Creditor(Supp) bank a/c exists in SEPA Enabled Listed Countries'
                FROM iby_ext_bank_accounts iba ,
                  iby_ext_bank_branches_v iebb
                WHERE iba.ext_bank_account_id = p_supp_bank_acct_id
                AND iba.branch_id             = iebb.branch_party_id
                AND iba.iban                 IS NOT NULL ------------------- Mandatory for SEPA
                AND iebb.eft_swift_code      IS NOT NULL                  -- ------------- Mandatory for SEPA
                AND EXISTS
                  (SELECT 'Supp Country matching with Attribute1 SEPA Enabled'
                  FROM FND_LOOKUP_VALUES_VL flvt
                  WHERE flvt.lookup_type      = 'HAE_BANK_COUNTRIES'
                  AND flvt.attribute_category = 'HAE_BANK_COUNTRIES'
                  AND flvt.enabled_flag       = 'Y'
                  AND TRUNC(SYSDATE) BETWEEN TRUNC(flvt.START_DATE_ACTIVE) AND NVL(TRUNC(flvt.end_date_active), TRUNC(sysdate)+1)
                  AND flvt.lookup_code = iebb.country
                  AND flvt.attribute1  = 'Y'
                  )
                ) ;
              IF vExist = 1 THEN
                v_sepa := 'Y';
              END IF;
            END IF;
          EXCEPTION
          WHEN OTHERS THEN
            FND_FILE.PUT_LINE(FND_FILE.LOG, 'err Other Errors in SEPA Func: ' || SQLERRM );
            FND_FILE.PUT_LINE(FND_FILE.LOG, 'err Other Errors in SEPA Func: ' || SQLERRM );
          END;
          IF v_sepa        = 'Y' THEN
            v_payment_type:='SEPA'; -- Arthur's Matrix, rows 43, 45
          ELSE
            v_payment_type:='GACH'; -- Arthur's Matrix, rows 44, 46-48
          END IF;
        elsif p_payment_method = 'WIRE' THEN
          IF p_supp_bank_name  = v_hae_us_bank_name THEN
            v_payment_type    :='Book Wire'; -- Arthur's Matrix, rows 52, 53, 55
            FND_FILE.PUT_LINE(FND_FILE.log,'v_hae_us_bank_name='||v_hae_us_bank_name);
          ELSE
            v_payment_type:='UK Wire'; -- Arthur's Matrix, rows 50, 51, 54 -- JPM's sheet says "Canada Wire", which seems wrong -- doublechecking
            FND_FILE.PUT_LINE(FND_FILE.log,'6else6');
          END IF;
        END IF;
      elsif p_hae_bank_acct_curr_code IN ('CAD', 'JPY', 'GBP') THEN
        IF p_payment_method            = 'EFT' THEN
          v_payment_type              :='GACH'; -- Arthur's Matrix, rows 57, 58, 65, 66, 72-75, 82-85
        elsif p_payment_method         = 'WIRE' THEN
          IF p_supp_bank_acct_country  = 'UK' AND p_supp_bank_name = v_hae_us_bank_name THEN
                      FND_FILE.PUT_LINE(FND_FILE.log,'77');
            v_payment_type            :='Book Wire'; -- Arthur's Matrix, row 61, 69, 79
          ELSE
            v_payment_type:='UK Wire'; -- Arthur's Matrix, rows 60, 63, 64, 68, 70, 71, 78, 80, 81 -- JPM's sheet says "Canada Wire" for 60, which seems wrong -- doublechecking
          END IF;
          FND_FILE.PUT_LINE(FND_FILE.log,'78');
        END IF;
        FND_FILE.PUT_LINE(FND_FILE.log,'79');
      END IF;
      FND_FILE.PUT_LINE(FND_FILE.LOG, '1st if payment_currency_code' ||P_PAYMENT_CURRENCY_CODE||'   p_payment_method   '||P_PAYMENT_METHOD||'     p_hae_bank_acct_curr_code    '||P_HAE_BANK_ACCT_CURR_CODE );
      FND_FILE.PUT_LINE(FND_FILE.log,'v_payment_type='||v_payment_type);
    END CASE;
--INC0129727 - Eric Rossing - JP Morgan Check Payment transmission
  END IF;
--INC0129727 - Eric Rossing - JP Morgan Check Payment transmission ends
    FND_FILE.PUT_LINE(FND_FILE.LOG, '1st if payment_currency_code' ||P_PAYMENT_CURRENCY_CODE||'   p_payment_method   '||P_PAYMENT_METHOD||'     p_hae_bank_acct_curr_code    '||P_HAE_BANK_ACCT_CURR_CODE );
    FND_FILE.PUT_LINE(FND_FILE.log,'v_payment_type='||v_payment_type);
    FND_FILE.PUT_LINE(FND_FILE.log,'80');
    --end if;
    elsif  (V_BANK_STR = 'Deutsche' or V_BANK_STR ='Danske B' )THEN
    FND_FILE.PUT_LINE(FND_FILE.log, 'else payment_currency_code' ||p_payment_currency_code||'   p_payment_method   '||p_payment_method||'     p_hae_bank_acct_curr_code    '||p_hae_bank_acct_curr_code );
    BEGIN                                                                                                                                                                                                           ------
        FND_FILE.PUT_LINE(FND_FILE.log, 'inside else payment_currency_code' ||p_payment_currency_code||'   p_payment_method   '||p_payment_method||'     p_hae_bank_acct_curr_code    '||p_hae_bank_acct_curr_code );
        -- R12 Upgrade Modified on 09/25/2012 by Venkatesh Sarangam, Rolta

        SELECT hl.location_id ,
          hl.address_line_1 ,
          hl.address_line_2 ,
          NVL(hl.address_line_3, 'NA') -- value required (atleast 1 character) if XML elemented listed
          ,
          hl.TOWN_OR_CITY ,
          hl.COUNTRY ,
          hl.postal_code
        INTO v_hae_location_id1 ,
          v_hae_corp_name1 ,
          v_hae_address_line_21 ,
          v_hae_address_line_31 ,
          v_hae_town_or_city1 ,
          v_hae_country1 ,
          v_hae_postal_code1
        FROM hr_operating_units hou ,
          hr_all_organization_units haou ,
          hr_locations hl
        WHERE hou.organization_id = v_org_id
        AND hou.organization_id   = haou.organization_id
        AND haou.location_id      = hl.location_id ;
        SELECT
          rownum
        INTO
          v_rownum1
        FROM iby_payments_all iba,
          iby_docs_payable_all idpa
        WHERE 1                      =1
        AND idpa.document_payable_id = p_document_payable_id
        AND iba.payment_id = idpa.payment_id;
        select distinct
    to_char(iba.payment_date,'YYYY-MM-DD'),
    to_char(iba.payment_date,'YYYY-MM-DD HH12:MI:SS')
  into v_eu_payment_date1,
       v_eu_payment_date2
  FROM ap_document_lines_v apdl,
    iby_payments_all iba,
    iby_docs_payable_all idpa,
    ap_supplier_sites_all ass,
    iby_pay_service_requests ibypsr,
    ce_bank_accounts aba_hae,
    ce_bank_branches_v abb_hae,
    iby_ext_bank_accounts ieb,
    iby_ext_bank_branches_v iebb
  WHERE 1                      = 1
  AND idpa.document_payable_id = p_document_payable_id
  AND apdl.line_number         = p_line_number
  AND iba.payment_id           = idpa.payment_id
  AND idpa.supplier_site_id    = ass.vendor_site_id
  AND apdl.CALLING_APP_DOC_UNIQUE_REF2 = idpa.CALLING_APP_DOC_UNIQUE_REF2
  AND idpa.CALLING_APP_ID              = APDL.CALLING_APP_ID
  AND idpa.payment_service_request_id  = ibypsr.payment_service_request_id
  AND aba_hae.bank_branch_id           = abb_hae.branch_party_id
  AND aba_hae.bank_account_id          = iba.internal_bank_account_id
  and iba.external_bank_account_id     = ieb.ext_bank_account_id (+)
  and ieb.branch_id                    = iebb.branch_party_id;
        fnd_file.put_line(fnd_file.log,'Before select stmt'|| 'payment_batch' ||p_payment_batch||'  p_hae_bank_acct_id    '||p_hae_bank_acct_id||' p_supp_bank_acct_id '||p_supp_bank_acct_id);
        fnd_file.put_line(fnd_file.log,'Before select stmt'|| 'else vExist' ||vexist||'  v_xx_sepa    '||v_xx_sepa);

   if p_payment_currency_code = 'EUR' and p_payment_method = 'EFT' and p_hae_bank_acct_curr_code = 'EUR'  -- 2010-04-23	Added p_hae_bank_acct_curr_code expression to include Haemo account currency code = EUR as a criterion for SEPA payments
THEN

        SELECT NVL(MAX(1),0)
        INTO vExist
        FROM dual
        WHERE EXISTS
          (SELECT 'To see if Debtor(HAE) bank a/c exists in Listed Countries'
          FROM iby_payments_all iba,
            ce_bank_accounts cba,
            ce_bank_branches_v cbb
          WHERE iba.payment_process_request_name = p_payment_batch     -- 'HRB3'
          AND cba.bank_account_id                = p_hae_bank_acct_id ---
          AND iba.org_id                         = v_org_id
          AND iba.internal_bank_account_id       = cba.bank_account_id
          AND cba.iban_number                   IS NOT NULL ------------------- Mandatory for SEPA
          AND cba.bank_branch_id                 = cbb.branch_party_id
          AND cbb.eft_swift_code                IS NOT NULL --------------- Mandatory for SEPA
          AND EXISTS
            (SELECT 'Country matching with Attribute2'
            FROM FND_LOOKUP_VALUES_VL flvt
            WHERE flvt.lookup_type      = 'HAE_BANK_COUNTRIES'
            AND flvt.attribute_category = 'HAE_BANK_COUNTRIES'
            AND flvt.enabled_flag       = 'Y'
            AND TRUNC(SYSDATE) BETWEEN TRUNC(flvt.START_DATE_ACTIVE) AND NVL(TRUNC(flvt.END_DATE_ACTIVE), TRUNC(SYSDATE)+1)
            AND flvt.lookup_code = cbb.country
            AND flvt.attribute2  = 'Y'
            )
          )
        AND EXISTS
          (SELECT 'To see if Creditor(Supp) bank a/c exists in SEPA Enabled Listed Countries'
          FROM iby_ext_bank_accounts iba ,
            iby_ext_bank_branches_v iebb
          WHERE iba.ext_bank_account_id = p_supp_bank_acct_id
          AND iba.branch_id             = iebb.branch_party_id
          AND iba.iban                 IS NOT NULL ------------------- Mandatory for SEPA
          AND iebb.eft_swift_code      IS NOT NULL                  -- ------------- Mandatory for SEPA
          AND EXISTS
            (SELECT 'Supp Country matching with Attribute1 SEPA Enabled'
            FROM FND_LOOKUP_VALUES_VL flvt
            WHERE flvt.lookup_type      = 'HAE_BANK_COUNTRIES'
            AND flvt.attribute_category = 'HAE_BANK_COUNTRIES'
            AND flvt.enabled_flag       = 'Y'
            AND TRUNC(SYSDATE) BETWEEN TRUNC(flvt.START_DATE_ACTIVE) AND NVL(TRUNC(flvt.end_date_active), TRUNC(sysdate)+1)
            AND flvt.lookup_code = iebb.country
            AND flvt.attribute1  = 'Y'
            )
          ) ;
end if;
        FND_FILE.PUT_LINE(FND_FILE.log, 'else vExist' ||vExist||'  v_xx_sepa    '||v_xx_sepa);
        IF vExist    = 1 THEN
          v_xx_sepa := 'Y';
        END IF;
      FND_FILE.PUT_LINE(FND_FILE.LOG, 'else vExist' ||VEXIST||'  v_xx_sepa    '||V_XX_SEPA);
    EXCEPTION
    WHEN OTHERS THEN
      FND_FILE.PUT_LINE(FND_FILE.LOG, 'err Other Errors in SEPA Func: ' || SQLERRM );
      FND_FILE.PUT_LINE(FND_FILE.LOG, 'err Other Errors in SEPA Func: ' || SQLERRM );
    END;
  END IF;
-- xx_sepa for US Payments
  SELECT XMLConcat( xmlelement("Extend",
     xmlelement("xx_payment_type", v_payment_type),
     xmlelement("xx_sepa", v_sepa),
     xmlelement("xx_us_location_id", v_hae_location_id),
     xmlelement("xx_us_hae_corp_name", v_hae_corp_name),
     xmlelement("xx_us_hae_Adress_line2", v_hae_address_line_2),
     xmlelement("xx_us_hae_address_line3", v_hae_address_line_3),
     xmlelement("xx_us_hae_TOWN_OR_CITY", v_hae_TOWN_OR_CITY),
     xmlelement("xx_us_hae_COUNTRY", v_hae_COUNTRY),
     xmlelement("xx_us_hae_postal_code", v_hae_postal_code),
     xmlelement("xx_us_ou_name", v_ou_name),
    xmlelement("xx_us_payment_date", v_us_payment_date1),
    xmlelement("xx_us_payment_date_time", v_us_payment_date2),
    xmlelement("xx_us_rownum", v_rownum),
    xmlelement("xx_us_payment_id", v_payment_id_number),
    xmlelement("xx_us_user_id", v_user_id),
--    xmlelement("xx_hk_hae_corp_name1", v_fields1),      -- Removed by Eric Rossing 12/7/15 to include corporate address in file
--    xmlelement("xx_hk_hae_corp_name2", v_fields2),      -- Removed by Eric Rossing 12/7/15 to include corporate address in file
    xmlelement("xx_hk_hae_corp_name1", v_hsbc_first_party_name),      -- Added by Eric Rossing 12/7/15 to include corporate address in file
    xmlelement("xx_hk_hae_corp_name2", v_hsbc_first_party_info_1),      -- Added by Eric Rossing 12/7/15 to include corporate address in file
    xmlelement("xx_hk_hae_corp_name3", v_hsbc_first_party_info_2),      -- Added by Eric Rossing 12/7/15 to include corporate address in file
    xmlelement("xx_hk_hae_corp_name4", v_hsbc_first_party_info_3),      -- Added by Eric Rossing 12/7/15 to include corporate address in file
    xmlelement("xx_hk_supp_bank_account_name1", v_fields3),
    xmlelement("xx_hk_supp_bank_account_name2", v_fields4),
    xmlelement("xx_hk_supp_bank_account_name3", v_fields5),
    xmlelement("xx_hk_supp_bank_account_name4", v_fields6),
    xmlelement("xx_hk_supp_bank_branch_name1", v_fields7),
    xmlelement("xx_hk_supp_bank_branch_name2", v_fields8)
    --xmlelement("xx_us_invoice_batch_name", v_invoice_batch_name)
    ),
    XMLELEMENT("Extend",
    xmlelement("xx_eu_sepa", v_xx_sepa),
    xmlelement("xx_eu_supp_remit_num", p_supp_remit_num),
    xmlelement("xx_eu_location_id", v_hae_location_id1),
    xmlelement("xx_eu_hae_corp_name", v_hae_corp_name1),
    xmlelement("xx_eu_hae_Adress_line2", v_hae_address_line_21),
    xmlelement("xx_eu_hae_address_line3", v_hae_address_line_31),
    xmlelement("xx_eu_hae_TOWN_OR_CITY", v_hae_town_or_city1),
    xmlelement("xx_eu_hae_COUNTRY", v_hae_country1),
    xmlelement("xx_eu_hae_postal_code", v_hae_postal_code1),
    xmlelement("xx_eu_payment_date", v_eu_payment_date1),
    xmlelement("xx_eu_payment_date_time", v_eu_payment_date2),
    XMLELEMENT("xx_eu_rownum", V_ROWNUM1),
    xmlelement("xx_eu_user_id", v_user_id1)
    --xmlelement("xx_eu_invoice_batch_name", v_invoice_batch_name)
    ) )
  INTO v_payment_type1
  FROM DUAL;

END IF;
  return v_payment_type1;

EXCEPTION
WHEN OTHERS THEN
  FND_FILE.PUT_LINE(FND_FILE.LOG, 'err Other Errors : ' || SQLERRM );
END Get_Docline_Ext_Agg;
--
-- This API is called once only for the payment process request.
-- Implementor should construct the extract extension elements
-- at the payment request level as a SQLX XML Aggregate
-- and return the aggregate.
--
FUNCTION Get_Ppr_Ext_Agg(
    p_payment_service_request_id IN NUMBER)
  RETURN XMLTYPE
IS
BEGIN
  RETURN NULL;
end get_ppr_ext_agg;
end iby_fd_extract_ext_pub;