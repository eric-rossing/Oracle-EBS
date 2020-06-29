CREATE OR REPLACE VIEW XXHA_WM_MACHINE_MOVEMENT_VW AS
    SELECT
        wmtc.web_transaction_id,
        wmtc.transaction_type                                                                  document_type,
        decode((wmtc.transaction_status), 0, 'UPDATE', 1, 'INSERT', 2, 'DELETE')               document_status,
        mtrh.header_id,
        mtrh.request_number,
        mtrl.line_number,
        org.organization_code,
        msib.segment1                                                                          item_number,
        mtrl.revision,
        mtrl.uom_code,
        mtrl.serial_number_start,
        mtrl.serial_number_end,
        mtrh.from_subinventory_code,
        mtrh.to_subinventory_code,
        mtrh.status_date,
        mtrl.quantity,
        mtrh.header_status,
        mtrh.description,
        cii.location_type_code,
        cii.location_id,
        cii_hist.old_location_type_code,
        cii_hist.old_location_id,
        hl.address1,
        hl.address2,
        hl.address3,
        hl.address4,
        hl.city,
        hl.state,
        hl.postal_code,
        hl.country
    FROM
        inv.mtl_txn_request_headers          mtrh,
        inv.mtl_txn_request_lines            mtrl,
        inv.mtl_system_items_b               msib,
        apps.org_organization_definitions    org,
        csi.csi_item_instances               cii,
        (
            SELECT
                *
            FROM
                (
                    SELECT
                        instance_id,
                        old_location_type_code,
                        old_location_id,
                        ROW_NUMBER() OVER(PARTITION BY instance_id
                            ORDER BY
                                last_update_date DESC
                        ) hist_row_num
                    FROM
                        csi.csi_item_instances_h
                )
            WHERE
                hist_row_num = 1
        ) cii_hist,
        ar.hz_party_sites                    hps,
        ar.hz_locations                      hl,
        apps.wm_track_changes_vw             wmtc
    WHERE
            mtrh.header_id = wmtc.transaction_id
        AND wmtc.transaction_type = 'HAEMO_MACHINEMOVE'
        AND mtrh.header_id = mtrl.header_id
        AND mtrl.inventory_item_id = msib.inventory_item_id
        AND mtrl.organization_id = msib.organization_id
        AND mtrl.organization_id = org.organization_id
        AND mtrh.description = cii.instance_number (+)
        AND cii.instance_id = cii_hist.instance_id (+)
        AND cii_hist.old_location_id = hps.party_site_id (+)
        AND hps.location_id = hl.location_id (+)
        AND mtrh.move_order_type = 1
        AND mtrl.organization_id = 5077
        AND mtrh.header_status = 3
        AND mtrl.serial_number_start IS NOT NULL
        AND mtrh.description IS NOT NULL;