create table haemo.xxha_material_cert_map_bkup
as select * from HAEMO.XXHA_MATERIAL_CERT_MAPPING;


update HAEMO.XXHA_MATERIAL_CERT_MAPPING set doc_revision = 'AB'  where cert_number = 'SOPFORM2487_14' and collection_plan = 'CERT_TJP_SOPFORM2487_14';
--23 records updated

commit;