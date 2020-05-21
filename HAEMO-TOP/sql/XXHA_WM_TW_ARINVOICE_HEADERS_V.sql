
  CREATE OR REPLACE FORCE VIEW "APPS"."XXHA_WM_TW_ARINVOICE_HEADERS_V" ("WEB_TRANSACTION_ID", "DOCUMENT_TYPE", "DOCUMENT_STATUS", "CUSTOMER_TRX_ID", "TRX_NUMBER", "TRX_DATE", "INVOICE_CURRENCY_CODE", "TRX_TYPE", "TW_INVOICE_TYPE", "PREVIOUS_TRX_NUMBER", "TERMS_NAME", "TERMS_DESCRIPTION", "TERMS_DUE_DAYS", "HEADER_ATTRIBUTE_CATEGORY", "ORDER_NUMBER", "ORDER_TYPE", "ORIG_SYS_DOCUMENT_REF", "CUST_PO_NUMBER", "ORDERED_DATE", "DELIVERY_NAME", "OU_ORGANIZATION_NAME", "OU_ORGANIZATION_ID", "OU_CODE", "SENDER_ID", "SENDER_NAME", "INVOICING_TYPE", "INVOICE_DUE_DATE", "BILL_TO_SITE_NUMBER", "BILL_TO_ACCOUNT_NUMBER", "BILL_TO_CUSTOMER_NAME", "BILL_TO_TAX_ID", "BILL_TO_ADDRESS1", "BILL_TO_ADDRESS2", "BILL_TO_ADDRESS3", "BILL_TO_ADDRESS4", "BILL_TO_CITY", "BILL_TO_REGION", "BILL_TO_POSTAL_CODE", "BILL_TO_COUNTRY", "SHIP_TO_SITE_NUMBER", "SHIP_TO_ACCOUNT_NUMBER", "SHIP_TO_CUSTOMER_NAME", "SHIP_TO_ADDRESS1", "SHIP_TO_ADDRESS2", "SHIP_TO_ADDRESS3", "SHIP_TO_ADDRESS4", "SHIP_TO_CITY", "SHIP_TO_REGION", "SHIP_TO_POSTAL_CODE", "SHIP_TO_COUNTRY", "HAEMO_TAX_ID", "REMIT_TO_ADDRESS1", "REMIT_TO_ADDRESS2", "REMIT_TO_ADDRESS3", "REMIT_TO_CITY", "REMIT_TO_REGION", "REMIT_TO_POSTAL_CODE", "REMIT_TO_COUNTRY", "CHECK_DIGIT") AS 
  SELECT wmtc.web_transaction_id,
    wmtc.transaction_type document_type,
    DECODE((wmtc.transaction_status), 0, 'UPDATE', 1, 'INSERT', 2, 'DELETE') document_status,
    ct.customer_trx_id,
    ct.trx_number,
    ct.trx_date,
    ct.invoice_currency_code,
    cty.name,
    --case cty.name when 'TW31-TRI-COMP-GUI' THEN '01' when 'TW32-DUP-CASH-GUI' THEN '02' ELSE null end tw_invoice_type,
    '07' tw_invoice_type,
    prev_ct.trx_number previous_trx_number,
    terms.term_name,
    terms.description term_description,
    terms.due_days term_due_days,
    ct.interface_header_context    AS header_attribute_category,
    ct.ct_reference AS order_number,
    case when ct.interface_header_context = 'ORDER ENTRY' then ct.interface_header_attribute2 else null end AS order_type,
    oh.orig_sys_document_ref,
    ct.purchase_order,
    oh.ordered_date,
    case when ct.interface_header_context = 'ORDER ENTRY' then nvl(ct.interface_header_attribute3, ct.waybill_number) else ct.waybill_number end delivery_name,
    org.name ou_organization_name,
    org.organization_id ou_organization_id,
    org.short_code ou_code,
    CASE org.short_code 
        WHEN 'TW' then '16082695' 
        else NULL 
    end sender_id,
    CASE org.short_code
        WHEN 'TW' then 'TBD'
        else null
    end sender_name,
    cas.attribute1 invoicing_type,
    nvl((SELECT MIN(ps2.due_date) FROM ar_payment_schedules_all ps2 where ps2.customer_trx_id = CT.CUSTOMER_TRX_ID), arpt_sql_func_util.get_first_due_date(CT.TERM_ID, nvl(ct.billing_date, CT.TRX_DATE))) invoice_due_date,
    hps.party_site_number bill_to_site_number,
    hca.account_number bill_to_account_number,
    hp.party_name bill_to_customer_name,
    csu.tax_reference,
    hl.address1 bill_to_Address1,
    hl.address2 bill_to_address2,
    hl.address3 bill_to_address3,
    hl.address4 bill_to_address4,
    hl.city bill_to_city,
    nvl(hl.state, hl.province) bill_to_region,
    hl.POSTAL_CODE bill_to_postal_code,
    hl.country bill_to_country,
    ship_hps.party_site_number ship_to_site_number,
    ship_hca.account_number ship_to_account_number,
    ship_hca.account_name ship_to_customer_name,
    ship_hl.address1 ship_to_Address1,
    ship_hl.address2 ship_to_address2,
    ship_hl.address3 ship_to_address3,
    ship_hl.address4 ship_to_address4,
    ship_hl.city ship_to_city,
    nvl(ship_hl.state, ship_hl.province) ship_to_region,
    ship_hl.POSTAL_CODE ship_to_postal_code,
    ship_hl.country ship_to_country,
    CASE org.short_code
        WHEN 'GB' THEN 'GB224345486'
        WHEN 'DE' THEN 'DE129366843'
        WHEN 'FR' THEN 'FR57311852396'
        WHEN 'IT' THEN 'IT10923790157'
    END HAEMO_TAX_ID,
    RAA_REMIT_LOC.ADDRESS1 ,
    RAA_REMIT_LOC.ADDRESS2 ,
    RAA_REMIT_LOC.ADDRESS3 ,
    RAA_REMIT_LOC.CITY ,
    NVL(RAA_REMIT_LOC.STATE , RAA_REMIT_LOC.PROVINCE),
    RAA_REMIT_LOC.POSTAL_CODE ,
    RAA_REMIT_LOC.COUNTRY,
    XXHA_TW_INV_CHECK_DIGIT.PROCESS_DATA(LPAD(SUBSTR(ct.trx_number,3,8),8,'0')) CHECK_DIGIT
  FROM ra_customer_trx_all ct,
    ra_cust_trx_types_all cty,
    oe_order_headers_all oh,
    oe_order_sources os,
    hr_operating_units org,
    oe_transaction_types_tl ot,
    --,wm_track_changes_vw wmtc
    (select /*+ no_merge */ * from apps.wm_track_changes_vw where transaction_type = 'ARTRANSACTION' and transaction_status=1) wmtc, -- Eric Rossing - 7/2/2015 - Added to improve query performance
    hz_cust_site_uses_all csu,
    hz_cust_acct_sites_all cas,
    hz_party_sites hps,
    hz_cust_accounts hca,
    hz_parties hp,
    hz_locations hl,
    hz_cust_site_uses_all ship_csu,
    hz_cust_acct_sites_all ship_cas,
    hz_party_sites ship_hps,
    hz_cust_accounts ship_hca,
    hz_locations ship_hl,
    HZ_CUST_ACCT_SITES_ALL RAA_REMIT,
    HZ_PARTY_SITES RAA_REMIT_PS,
    HZ_LOCATIONS RAA_REMIT_LOC,
    ra_customer_trx_all prev_ct,
    (select rt.term_id
      , rtt.name as term_name -- 40 - Basic payment term code
      , rtt.description -- 307 - Basic payment term text
      , rtl.due_days -- 337 - Basic payment term net days due
     from
      apps.ra_terms_b rt
      , apps.ra_terms_tl rtt
      , apps.ra_terms_lines rtl
     where
      rt.term_id = rtt.term_id
      and rtt.language = 'US' -- in the future this may be customer language or OU language
      and rt.term_id = rtl.term_id(+)
    ) terms
  WHERE ct.cust_trx_type_id = cty.cust_trx_type_id(+)
  AND ct.org_id             = cty.org_id(+)
--  AND ct.interface_header_context    = 'ORDER ENTRY'
  AND ct.org_id                      = org.organization_id(+)
  AND ct.org_id                      = oh.org_id(+)
  AND ct.interface_header_attribute1 = TO_CHAR(oh.order_number(+))
  AND oh.order_type_id               = ot.transaction_type_id(+)
  AND ot.LANGUAGE(+)                 = userenv('LANG')
  --AND ct.interface_header_attribute2 = ot.name
  AND oh.order_source_id             = os.order_source_id(+)
  AND ct.customer_trx_id           = wmtc.transaction_id
  AND transaction_status          <= 2
  AND wmtc.transaction_type        = 'ARTRANSACTION'
  AND ct.complete_flag             = 'Y'
  AND ct.bill_to_site_use_id       = csu.site_use_id(+)
  AND csu.cust_acct_site_id        = cas.cust_acct_site_id(+)
  AND cas.party_site_id            = hps.party_site_id(+)
  and cas.cust_account_id          = hca.cust_account_id(+)
  and hps.LOCATION_ID              = hl.location_id(+)
  AND hps.party_id                 = hp.party_id(+)
  AND ct.ship_to_site_use_id       = ship_csu.site_use_id(+)
  AND ship_csu.cust_acct_site_id   = ship_cas.cust_acct_site_id(+)
  AND ship_cas.party_site_id       = ship_hps.party_site_id(+)
  and ship_cas.cust_account_id     = ship_hca.cust_account_id(+)
  and ship_hps.LOCATION_ID         = ship_hl.location_id(+)
  AND CT.REMIT_TO_ADDRESS_ID       = RAA_REMIT.CUST_ACCT_SITE_ID(+)
  AND RAA_REMIT.PARTY_SITE_ID      = RAA_REMIT_PS.PARTY_SITE_ID(+)
  AND RAA_REMIT_LOC.LOCATION_ID(+) = RAA_REMIT_PS.LOCATION_ID
  AND ct.previous_customer_trx_id  = prev_ct.customer_trx_id(+)
  and ct.TERM_ID                   = terms.term_id(+)
  AND org.short_code='TW'
  AND cty.name in ('TW31-TRI-COMP-GUI','TW32-DUP-CASH-GUI','TW Credit Memo')
  AND ct.invoice_currency_code='TWD'
  ORDER BY wmtc.web_transaction_id;
