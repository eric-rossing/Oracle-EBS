CREATE OR REPLACE VIEW xxha_wm_machine_movement_q_vw (WEB_TRANSACTION_ID, DOCUMENT_TYPE, DOCUMENT_STATUS, HEADER_ID, REQUEST_NUMBER, LINE_ID, LINE_NUMBER, ORGANIZATION_CODE, ITEM_NUMBER, REVISION, UOM_CODE,
SERIAL_NUMBER_START, SERIAL_NUMBER_END, FROM_SUBINVENTORY_CODE, TO_SUBINVENTORY_CODE, STATUS_DATE, QUANTITY, HEADER_STATUS, DESCRIPTION, LOCATION_TYPE_CODE, LOCATION_ID, OLD_LOCATION_TYPE_CODE, OLD_LOCATION_ID,
VENDOR_NUMBER, SITE_NUMBER, ADDRESS1, ADDRESS2, ADDRESS3, ADDRESS4, CITY, STATE, POSTAL_CODE, COUNTRY, ACTION, LINK_ID) AS
    SELECT
        NULL             web_transaction_id,
        NULL             document_type,
        NULL             document_status,
        mtrh.header_id,
        mtrh.request_number,
        mtrl.line_id,
        mtrl.line_number,
        org.organization_code,
        msib.segment1    item_number,
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
        NULL,
        hps.party_site_number,
        hl.address1,
        hl.address2,
        hl.address3,
        hl.address4,
        hl.city,
        hl.state,
        hl.postal_code,
        hl.country,
        'PickupRequest',
        'PickupRequest-' || TO_CHAR(CII_HIST.OLD_LOCATION_ID)
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
        ar.hz_locations                      hl
    WHERE
            mtrh.header_id = mtrl.header_id
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
        AND mtrh.description IS NOT NULL        
        AND cii.instance_id is not null

UNION

    SELECT
        NULL             web_transaction_id,
        NULL             document_type,
        NULL             document_status,
        mtrh.header_id,
        mtrh.request_number,
        mtrl.line_id,
        mtrl.line_number,
        org.organization_code,
        msib.segment1    item_number,
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
        NULL,
        NULL,
        NULL,
        NULL,
        pv.segment1 vendor_number,
        pvsa.vendor_site_code,
        PV.VENDOR_NAME,
        pvsa.address_line1,
        pvsa.address_line2,
        pvsa.address_line3,
        pvsa.city,
        pvsa.state,
        pvsa.zip,
        pvsa.country,
        'ShipOutGoods',
        'ShipOutGoods-' || TO_CHAR(PV.VENDOR_ID)
    FROM
        inv.mtl_txn_request_headers          mtrh,
        inv.mtl_txn_request_lines            mtrl,
        inv.mtl_system_items_b               msib,
        apps.org_organization_definitions    org,
        po_vendors pv,
        po_vendor_sites_all pvsa
    WHERE
            mtrh.header_id = mtrl.header_id
        AND mtrl.inventory_item_id = msib.inventory_item_id
        AND mtrl.organization_id = msib.organization_id
        AND mtrl.organization_id = org.organization_id
        AND mtrh.description = 'Deliver to ' || pv.segment1 (+)
        and pv.vendor_id = pvsa.vendor_id (+)
        AND mtrh.move_order_type = 1
        AND mtrl.organization_id = 5077
        AND mtrh.header_status = 3
        AND mtrl.serial_number_start IS NOT NULL
        AND mtrh.description LIKE ('Deliver to %')
        
UNION

    SELECT
        NULL             web_transaction_id,
        NULL             document_type,
        NULL             document_status,
        mtrh.header_id,
        mtrh.request_number,
        mtrl.line_id,
        mtrl.line_number,
        org.organization_code,
        msib.segment1    item_number,
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
        NULL,
        NULL,
        NULL,
        NULL,
        pv.segment1 vendor_number,
        pvsa.vendor_site_code,
        PV.VENDOR_NAME,
        pvsa.address_line1,
        pvsa.address_line2,
        pvsa.address_line3,
        pvsa.city,
        pvsa.state,
        pvsa.zip,
        pvsa.country,
        'ShipOutGoods',
        'Scrap-' || TO_CHAR(PV.VENDOR_ID)
    FROM
        inv.mtl_txn_request_headers          mtrh,
        inv.mtl_txn_request_lines            mtrl,
        inv.mtl_system_items_b               msib,
        apps.org_organization_definitions    org,
        po_vendors pv,
        po_vendor_sites_all pvsa
    WHERE
            mtrh.header_id = mtrl.header_id
        AND mtrl.inventory_item_id = msib.inventory_item_id
        AND mtrl.organization_id = msib.organization_id
        AND mtrl.organization_id = org.organization_id
        AND pv.segment1 = '22145'
        and pv.vendor_id = pvsa.vendor_id (+)
        AND mtrh.move_order_type = 1
        AND mtrl.organization_id = 5077
        AND mtrh.header_status = 3
        AND mtrl.serial_number_start IS NOT NULL
        AND mtrh.description LIKE ('SCRAP')
        
UNION

    SELECT
        NULL             web_transaction_id,
        NULL             document_type,
        NULL             document_status,
        mtrh.header_id,
        mtrh.request_number,
        mtrl.line_id,
        mtrl.line_number,
        org.organization_code,
        msib.segment1    item_number,
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
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        'TransferGoods',
        'TransferGoods-' || mtrh.from_subinventory_code || '-' || mtrh.to_subinventory_code
    FROM
        inv.mtl_txn_request_headers          mtrh,
        inv.mtl_txn_request_lines            mtrl,
        inv.mtl_system_items_b               msib,
        apps.org_organization_definitions    org
    WHERE
            mtrh.header_id = mtrl.header_id
        AND mtrl.inventory_item_id = msib.inventory_item_id
        AND mtrl.organization_id = msib.organization_id
        AND mtrl.organization_id = org.organization_id
        AND mtrh.move_order_type = 1
        AND mtrl.organization_id = 5077
        AND mtrh.header_status = 3
        AND mtrl.serial_number_start IS NOT NULL
        AND mtrh.description LIKE ('Internal Sub Inventory%')

;