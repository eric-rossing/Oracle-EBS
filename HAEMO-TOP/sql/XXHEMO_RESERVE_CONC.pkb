CREATE OR REPLACE PACKAGE BODY APPS."XXHEMO_RESERVE_CONC" 
    /* ******************************************************************************************************
    * Object Name: XXHEMO_RESERVE_CONC
    * Object Type: PACKAGE
    *
    * Description: This Package is for reserve order based on outbound exception items
    *
    * Modification Log:
    * Developer          Date                 Description
    *-----------------   ------------------   ------------------------------------------------
    * Apps Associates    27-JAN-2015          Initial object creation.
    * Ohmesh Suraj     29-JAN-2016          Modified validation for custom table. And defaulting of email if to xxha_get_test_email_address
    * Ohmesh Suraj       11-FEB-2016          Added valiation for ship to customer site id             
    * Sethu Nathan		 22-Jun-2020		  Modified code to remove hardcoding of SMTP server. Incident INC0321180
    *******************************************************************************************************/
AS
  /* $Header: OEXCRSVB.pls 120.17.12010000.7 2012/02/15 12:15:45 kshashan ship $ */
  --  Global constant holding the package name
  G_PKG_NAME               CONSTANT VARCHAR2(30) := 'XXHEMO_RESERVE_CONC';
  G_SET_ID                 NUMBER;
  G_PROGRAM_APPLICATION_ID NUMBER;
  G_PROGRAM_ID             NUMBER;
  G_RESERVATION_MODE       VARCHAR2(30);
  G_TOTAL_CONSUMED         NUMBER :=0;
  G_CONSUMED_FOR_LOT       NUMBER :=0;
  G_TOTAL_CONSUMED2        NUMBER :=0;  -- INVCONV
  G_CONSUMED_FOR_LOT2      NUMBER :=0;  -- INVCONV
  G_ORDERED_QUANTITY       NUMBER :=0; ---AppsAssociates
  G_subinventory           VARCHAR2(100);
  PROCEDURE Query_Qty_Tree(
      p_ship_from_org_id  IN NUMBER,
      p_subinventory_code IN VARCHAR2,
      p_inventory_item_id IN NUMBER,
      x_on_hand_qty OUT NOCOPY       NUMBER,
      x_avail_to_reserve OUT NOCOPY  NUMBER,
      x_on_hand_qty2 OUT NOCOPY      NUMBER, -- INVCONV
      x_avail_to_reserve2 OUT NOCOPY NUMBER  -- INVCONV
    );
    /*
    NAME :
    Validate_Derived_Quantities
    BRIEF DESCRIPTION  :
    This API will be called to validate the derived_reserved_quantity
    and process the primary and secondary quantities based on the result
    of the INV_decimals_pub. validate_quantity API.
    CALLER :
    1. Derive_reservation_qty
    2. Calculate_Partial_Quantity
    BUG # :
    13657322
    PARAMETERS :
    p_x_rsv_rec  Reservation record to be processed.
    */
    PROCEDURE Validate_Derived_Quantities(
        p_x_rsv_rec IN OUT NOCOPY XXHEMO_RESERVE_CONC.Res_Rec_Type)
    IS
      l_validated_quantity NUMBER;
      l_primary_quantity   NUMBER;
      l_qty_return_status  VARCHAR2(1);
      --
      l_debug_level CONSTANT NUMBER := oe_debug_pub.g_debug_level;
      --
    BEGIN
      -- Moving call to validate_quantity in this API so that derived_reserved_quantity
      -- is checked for item indivisibility for all modes. If primary is truncated for a
      -- dual UoM controlled item, we will convert secondary from primary to handle
      -- deviation limits
      IF l_debug_level > 0 THEN
        OE_DEBUG_PUB.Add('Entering Validate_Derived_Quantities',1);
        OE_DEBUG_PUB.Add('Before Calling  validate_quantity ' ,1);
      END IF;
      inv_decimals_pub.validate_quantity( p_item_id => p_x_rsv_rec.inventory_item_id, p_organization_id => OE_Sys_Parameters.VALUE('MASTER_ORGANIZATION_ID',p_x_rsv_rec.org_id), -- 4759251
      p_input_quantity => p_x_rsv_rec.derived_reserved_qty, p_uom_code => p_x_rsv_rec.ordered_qty_uom, x_output_quantity => l_validated_quantity, x_primary_quantity => l_primary_quantity, x_return_status => l_qty_return_status);
      IF l_debug_level > 0 THEN
        OE_DEBUG_PUB.Add('After Calling  validate_quantity: '||l_qty_return_status ,1);
      END IF;
      IF l_qty_return_status = 'W' OR l_qty_return_status = 'E' THEN
        IF l_debug_level     > 0 THEN
          OE_DEBUG_PUB.Add('Validate_quantity returns Error/Warning: truncating the quantity');
        END IF;
        p_x_rsv_rec.derived_reserved_qty := TRUNC(l_validated_quantity);
        -- Convert secondary from primary as primary is truncated
        IF NVL(p_x_rsv_rec.ordered_qty2,0) > 0 THEN
          IF l_debug_level                 > 0 THEN
            OE_DEBUG_PUB.Add('Converting secondary from primary.');
          END IF;
          p_x_rsv_rec.derived_reserved_qty2 := inv_convert.inv_um_convert( item_id => p_x_rsv_rec.inventory_item_id , lot_number => NULL , organization_id => p_x_rsv_rec.ship_from_org_id , PRECISION => 5 , from_quantity => p_x_rsv_rec.derived_reserved_qty , from_unit => p_x_rsv_rec.ordered_qty_uom , to_unit => p_x_rsv_rec.ordered_qty_uom2 , from_name => NULL , to_name => NULL );
        END IF;
      END IF;
      IF l_debug_level > 0 THEN
        OE_DEBUG_PUB.Add('Exiting Validate_Derived_Quantities');
      END IF;
    EXCEPTION
    WHEN OTHERS THEN
      RAISE;
    END Validate_Derived_Quantities;
  /*------------------------------------------------------
  Procedure Name : Reservable_Quantity
  Description    : This api will call get the primary UOM code of the item and
  quantity available for reservation.
  --------------------------------------------------------------------- */
  PROCEDURE Reservable_Quantity(
      p_inventory_item_id IN NUMBER,
      p_ship_from_org_id  IN NUMBER,
      p_subinventory      IN VARCHAR2,
      p_org_id            IN NUMBER, -- 4759251
      x_primary_uom OUT NOCOPY    VARCHAR2,
      x_available_qty OUT NOCOPY  NUMBER,
      x_available_qty2 OUT NOCOPY NUMBER -- INVCONV
    )
  IS
    l_primary_uom  VARCHAR2(3);
    l_total_supply NUMBER :=0;
    l_on_hand_qty  NUMBER;
    -- INVCONV
    l_total_supply2 NUMBER :=0;
    l_on_hand_qty2  NUMBER;
    --
    l_debug_level CONSTANT NUMBER := oe_debug_pub.g_debug_level;
    --
  BEGIN
    IF l_debug_level > 0 THEN
      oe_debug_pub.add( ' ENTERING RESERVABLE_QUANTITY' , 1 ) ;
    END IF;
    -- Getting the Primary UOM of the item
    BEGIN
      SELECT primary_uom_code
      INTO l_primary_uom
      FROM mtl_system_items_b
      WHERE inventory_item_id = p_inventory_item_id
      AND organization_id     = NVL(p_ship_from_org_id, OE_Sys_Parameters.VALUE_WNPS('MASTER_ORGANIZATION_ID',p_org_id)); --4759251
    EXCEPTION
    WHEN OTHERS THEN
      IF l_debug_level > 0 THEN
        OE_DEBUG_PUB.Add('Error in selecting Primary UOM code',1);
      END IF;
      IF OE_MSG_PUB.Check_Msg_Level(OE_MSG_PUB.G_MSG_LVL_UNEXP_ERROR) THEN
        OE_MSG_PUB.Add_Exc_Msg ( G_PKG_NAME, 'Reservable_Quantity');
      END IF;
      RAISE FND_API.G_EXC_UNEXPECTED_ERROR;
    END;
    -- Getting reservable quantity
    Query_Qty_Tree(p_ship_from_org_id => p_ship_from_org_id, p_subinventory_code => p_subinventory, p_inventory_item_id => p_inventory_item_id, x_on_hand_qty => l_on_hand_qty, x_avail_to_reserve => l_total_supply, x_on_hand_qty2 => l_on_hand_qty2, -- INVCONV
    x_avail_to_reserve2 => l_total_supply2                                                                                                                                                                                                              -- INVCONV
    );
    l_total_supply  := l_total_supply - g_total_consumed;
    x_primary_uom   := l_primary_uom;
    x_available_qty := l_total_supply;
    -- INVCONV
    l_total_supply2  := l_total_supply2 - g_total_consumed2;
    x_available_qty2 := l_total_supply2;
    IF l_debug_level  > 0 THEN
      oe_debug_pub.add( ' EXITING RESERVABLE_QUANTITY' , 1 ) ;
    END IF;
  EXCEPTION
  WHEN OTHERS THEN
    IF OE_MSG_PUB.Check_Msg_Level(OE_MSG_PUB.G_MSG_LVL_UNEXP_ERROR) THEN
      OE_MSG_PUB.Add_Exc_Msg ( G_PKG_NAME, 'Reservable_Quantity');
    END IF;
    RAISE FND_API.G_EXC_UNEXPECTED_ERROR;
  END Reservable_Quantity;
/*------------------------------------------------------
Procedure Name : Commit_Reservation
Description    : This api will call Do_Check_for_Commit api to check
reservation status before commitng the work and will
save errors if occured during reservation.
--------------------------------------------------------------------- */
  PROCEDURE Commit_Reservation(
      p_request_id IN NUMBER,
      x_return_status OUT NOCOPY VARCHAR2)
  IS
    l_return_status VARCHAR2(1) := FND_API.G_RET_STS_SUCCESS;
    l_msg_count     NUMBER;
    l_msg_data      VARCHAR2(1000);
    l_failed_rsv_temp_tbl INV_RESERVATION_GLOBAL.mtl_failed_rsv_tbl_type;
    --
    l_debug_level CONSTANT NUMBER := oe_debug_pub.g_debug_level;
    --
  BEGIN
    IF l_debug_level > 0 THEN
      oe_debug_pub.add( ' BEFORE CALLING DO_CHECK_FOR_COMMIT' , 1 ) ;
    END IF;
    INV_RESERVATION_PVT.Do_Check_For_Commit (p_api_version_number => 1.0 ,p_init_msg_lst => FND_API.G_FALSE ,x_return_status => l_return_status ,x_msg_count => l_msg_count ,x_msg_data => l_msg_data ,x_failed_rsv_temp_tbl => l_failed_rsv_temp_tbl);
    IF l_debug_level > 0 THEN
      oe_debug_pub.add( ' AFTER CALLING DO_CHECK_FOR_COMMIT:'||l_return_status , 1 ) ;
    END IF;
    -- Error Handling Start
    IF l_return_status = FND_API.G_RET_STS_UNEXP_ERROR THEN
      IF l_debug_level > 0 THEN
        oe_debug_pub.add( 'INSIDE UNEXPECTED ERROR' , 1 ) ;
      END IF;
      OE_MSG_PUB.Transfer_Msg_Stack;
      l_msg_count := OE_MSG_PUB.COUNT_MSG;
      FOR I IN 1..l_msg_count
      LOOP
        l_msg_data      := OE_MSG_PUB.Get(I,'F');
        IF l_debug_level > 0 THEN
          oe_debug_pub.add( L_MSG_DATA , 1 ) ;
        END IF;
      END LOOP;
      RAISE FND_API.G_EXC_UNEXPECTED_ERROR;
    ELSIF l_return_status = FND_API.G_RET_STS_ERROR THEN
      IF l_debug_level    > 0 THEN
        oe_debug_pub.add( ' INSIDE EXPECTED ERROR' , 1 ) ;
      END IF;
      OE_MSG_PUB.Save_Messages(p_request_id => p_request_id);
      RAISE FND_API.G_EXC_ERROR;
    END IF;
    x_return_status := l_return_status;
  EXCEPTION
  WHEN FND_API.G_EXC_ERROR THEN
    IF l_debug_level > 0 THEN
      OE_DEBUG_PUB.Add('In Expected Error...in Proc Commit_Reservation for rsv_tbl',1);
    END IF;
    x_return_status := FND_API.G_RET_STS_ERROR;
  WHEN FND_API.G_EXC_UNEXPECTED_ERROR THEN
    IF l_debug_level > 0 THEN
      OE_DEBUG_PUB.Add('In Unexpected Error...in Proc Commit_Reservation ',1 );
    END IF;
    -- x_return_status := FND_API.G_RET_STS_UNEXP_ERROR;
    RAISE FND_API.G_EXC_UNEXPECTED_ERROR;
  WHEN OTHERS THEN
    IF l_debug_level > 0 THEN
      OE_DEBUG_PUB.Add('In others error...in Proc Commit_Reservation ',1);
    END IF;
    --x_return_status := FND_API.G_RET_STS_UNEXP_ERROR;
    RAISE FND_API.G_EXC_UNEXPECTED_ERROR;
  END Commit_Reservation;
/*------------------------------------------------------
Procedure Name : Validate_and_Reserve_for_Set
Description    : This api will fetch corrected quantity of each line
and will call create_reservation with the
lines having corrected quantity > 0
--------------------------------------------------------------------- */
  PROCEDURE Validate_and_Reserve_for_Set(
      p_x_rsv_tbl          IN OUT NOCOPY XXHEMO_RESERVE_CONC.rsv_tbl_type,
      p_reservation_set_id IN NUMBER,
      x_return_status OUT NOCOPY
      /* file.sql.39 change */
      VARCHAR2)
  IS
    CURSOR rsv_set_line(p_line_id NUMBER)
    IS
      SELECT inventory_item_id,
        ordered_qty,
        ordered_qty2, --INVCONV
        ship_from_org_id,
        subinventory,
        corrected_qty,
        corrected_qty2 -- INVCONV
      FROM oe_rsv_set_details
      WHERE reservation_set_id = p_reservation_set_id
      AND line_id              = p_line_id;
  TYPE Rsv_set_rec_type
IS
  RECORD
  (
    inventory_item_id NUMBER ,
    ordered_qty       NUMBER ,
    ordered_qty2      NUMBER -- INVCONV
    ,
    ship_from_org_id NUMBER ,
    subinventory     VARCHAR2(10) ,
    corrected_qty    NUMBER ,
    corrected_qty2   NUMBER -- INVCONV
  );
  l_rsv_set_rec Rsv_set_rec_type;
  l_rsv_tbl XXHEMO_RESERVE_CONC.rsv_tbl_type;
  l_return_status     VARCHAR2(1);
  l_line_reserve_qty  NUMBER :=0;
  l_line_reserve_qty2 NUMBER :=0; -- INVCONV
  l_sales_order_id    NUMBER;
  l_count_header      NUMBER :=0;
  --
  l_debug_level CONSTANT NUMBER := oe_debug_pub.g_debug_level;
  --
BEGIN
  IF l_debug_level > 0 THEN
    oe_debug_pub.add( 'ENTERING VALIDATE_AND_RESERVE_FOR_SET ' , 1 ) ;
  END IF;
FOR I IN 1..p_x_rsv_tbl.COUNT
LOOP
  l_count_header   := l_count_header + 1;
  IF l_count_header = 1 THEN
    -- Set Message Context
    OE_MSG_PUB.set_msg_context( p_entity_code => 'LINE' ,p_entity_id => p_x_rsv_tbl(I).line_id ,p_header_id => p_x_rsv_tbl(I).header_id ,p_line_id => p_x_rsv_tbl(I).line_id ,p_order_source_id => p_x_rsv_tbl(I).order_source_id ,p_orig_sys_document_ref => p_x_rsv_tbl(I).orig_sys_document_ref ,p_orig_sys_document_line_ref => p_x_rsv_tbl(I).orig_sys_line_ref ,p_orig_sys_shipment_ref => p_x_rsv_tbl(I).orig_sys_shipment_ref ,p_change_sequence => p_x_rsv_tbl(I).change_sequence ,p_source_document_type_id => p_x_rsv_tbl(I).source_document_type_id ,p_source_document_id => p_x_rsv_tbl(I).source_document_id ,p_source_document_line_id => p_x_rsv_tbl(I).source_document_line_id );
  ELSIF l_count_header > 1 THEN
    -- Update Message Context
    OE_MSG_PUB.update_msg_context( p_entity_code => 'LINE' ,p_entity_id => p_x_rsv_tbl(I).line_id ,p_header_id => p_x_rsv_tbl(I).header_id ,p_line_id => p_x_rsv_tbl(I).line_id ,p_orig_sys_document_ref => p_x_rsv_tbl(I).orig_sys_document_ref ,p_orig_sys_document_line_ref => p_x_rsv_tbl(I).orig_sys_line_ref ,p_change_sequence => p_x_rsv_tbl(I).change_sequence ,p_source_document_id => p_x_rsv_tbl(I).source_document_id ,p_source_document_line_id => p_x_rsv_tbl(I).source_document_line_id ,p_order_source_id => p_x_rsv_tbl(I).order_source_id ,p_source_document_type_id => p_x_rsv_tbl(I).source_document_type_id );
  END IF;
-- Getting set record information
OPEN rsv_set_line(p_x_rsv_tbl(I).line_id);
FETCH rsv_set_line INTO l_rsv_set_rec;
CLOSE rsv_set_line;
-- comparing item information
IF NOT OE_GLOBALS.EQUAL(p_x_rsv_tbl(I).inventory_item_id, l_rsv_set_rec.inventory_item_id) OR NOT OE_GLOBALS.EQUAL(p_x_rsv_tbl(I).ordered_qty, l_rsv_set_rec.ordered_qty) OR NOT OE_GLOBALS.EQUAL(p_x_rsv_tbl(I).ship_from_org_id, l_rsv_set_rec.ship_from_org_id) OR NOT OE_GLOBALS.EQUAL(p_x_rsv_tbl(I).subinventory, l_rsv_set_rec.subinventory) OR NOT OE_GLOBALS.EQUAL(p_x_rsv_tbl(I).ordered_qty2, l_rsv_set_rec.ordered_qty2) -- INVCONV from code review by AK
  OR NVL(p_x_rsv_tbl(I).shipped_quantity,0)> 0 THEN
  -- Save error message
  fnd_message.set_name('ONT', 'OE_SCH_ITEM_NOT_RESERVABLE');
  OE_MSG_PUB.Add;
  FND_FILE.Put_Line(FND_FILE.LOG,'Item can not reserved: Simulation information differ from line information');
ELSE
  IF NVL(l_rsv_set_rec.corrected_qty,0)     > 0 THEN
    p_x_rsv_tbl(I).Derived_Reserved_Qty    := l_rsv_set_rec.corrected_qty;
    p_x_rsv_tbl(I).Derived_Reserved_Qty2   := l_rsv_set_rec.corrected_qty2; -- INVCONV
    p_x_rsv_tbl(I).corrected_reserved_qty  := l_rsv_set_rec.corrected_qty;
    p_x_rsv_tbl(I).corrected_reserved_qty2 := l_rsv_set_rec.corrected_qty2; -- INVCONV
    -- Getting reserved quantity if any
    l_sales_order_id                                                           := OE_SCHEDULE_UTIL.Get_mtl_sales_order_id(p_x_rsv_tbl(I).HEADER_ID);
    l_line_reserve_qty                                                         := OE_LINE_UTIL.Get_Reserved_Quantity (p_header_id => l_sales_order_id, p_line_id => p_x_rsv_tbl(I).line_id, p_org_id => p_x_rsv_tbl(I).ship_from_org_id);
    IF (NVL(p_x_rsv_tbl(I).Derived_Reserved_Qty,0)+ NVL(l_line_reserve_qty,0)) <= p_x_rsv_tbl(I).ordered_qty AND NVL(p_x_rsv_tbl(I).Derived_Reserved_Qty,0) > 0 THEN
      -- Partial Reservation
      --Reservation exists for the line. Set the flag
      IF l_line_reserve_qty                > 0 THEN
        p_x_rsv_tbl(I).reservation_exists := 'Y';
      END IF;
      l_rsv_tbl(l_rsv_tbl.COUNT+1) := p_x_rsv_tbl(I);
    ELSE
      -- Save error message
      fnd_message.set_name('ONT', 'OE_SCH_ITEM_NOT_RESERVABLE');
      OE_MSG_PUB.Add;
      FND_FILE.Put_Line(FND_FILE.LOG,'Item can not reserved: Simulation is greater than the remaining reservable quantity');
    END IF;
  END IF;
END IF;
END LOOP;
oe_debug_pub.add('Before calling Create Reservation: ' || l_rsv_tbl.count,1);
create_reservation(p_x_rsv_tbl => l_rsv_tbl ,p_partial_reservation => FND_API.G_FALSE ,x_return_status => l_return_status);
x_return_status := l_return_status;
IF l_debug_level > 0 THEN
  oe_debug_pub.add( 'EXITING VALIDATE_AND_RESERVE_FOR_SET: '||l_return_status , 1 ) ;
END IF;
EXCEPTION
WHEN FND_API.G_EXC_UNEXPECTED_ERROR THEN
  IF l_debug_level > 0 THEN
    OE_DEBUG_PUB.Add('In Unexpected Error...in Proc Validate_and_Reserve_for_Set ',1 );
  END IF;
  --x_return_status := FND_API.G_RET_STS_UNEXP_ERROR;
  RAISE FND_API.G_EXC_UNEXPECTED_ERROR;
WHEN OTHERS THEN
  IF l_debug_level > 0 THEN
    OE_DEBUG_PUB.Add('In others error...in Proc Validate_and_Reserve_for_Set ',1);
  END IF;
  --x_return_status := FND_API.G_RET_STS_UNEXP_ERROR;
  RAISE FND_API.G_EXC_UNEXPECTED_ERROR;
END Validate_and_Reserve_for_Set;
/*------------------------------------------------------
Procedure Name : Update_Reservation_Set
Description    : To update the process_flag of the processed set
--------------------------------------------------------------------- */
PROCEDURE Update_Reservation_Set(
    p_reservation_set_id IN NUMBER,
    x_return_status OUT NOCOPY VARCHAR2)
IS
  l_request_id NUMBER;
  --
  l_debug_level CONSTANT NUMBER := oe_debug_pub.g_debug_level;
  --
BEGIN
  IF l_debug_level > 0 THEN
    oe_debug_pub.add( 'ENTERING UPDATE_RESERVATION_SET ' , 1 ) ;
  END IF;
  FND_PROFILE.Get('CONC_REQUEST_ID', l_request_id);
  UPDATE oe_reservation_sets
  SET process_flag         = 'Y',
    reservation_request_id = l_request_id,
    program_update_date    = sysdate,
    last_update_login      = FND_GLOBAL.CONC_LOGIN_ID,
    last_updated_by        = FND_GLOBAL.USER_ID,
    last_update_date       = sysdate
  WHERE reservation_set_id = p_reservation_set_id;
  IF (SQL%NOTFOUND) THEN
    x_return_status := FND_API.G_RET_STS_ERROR;
  ELSE
    x_return_status := FND_API.G_RET_STS_SUCCESS;
  END IF;
  IF l_debug_level > 0 THEN
    oe_debug_pub.add( 'EXITING UPDATE_RESERVATION_SET ' , 1 ) ;
  END IF;
EXCEPTION
WHEN OTHERS THEN
  IF l_debug_level > 0 THEN
    OE_DEBUG_PUB.Add('In others error...in Proc Update_Reservation_Set for rsv set tbl',1);
  END IF;
  --x_return_status := FND_API.G_RET_STS_UNEXP_ERROR;
  RAISE FND_API.G_EXC_UNEXPECTED_ERROR;
END Update_Reservation_Set;
/*------------------------------------------------------
Procedure Name : Create_Reservation_Set
Description    : Inserts simulated or reserved records
into oe_reservation_sets and oe_rsv_set_details table.
--------------------------------------------------------------------- */
PROCEDURE Create_Reservation_Set(
    p_rsv_tbl               IN XXHEMO_RESERVE_CONC.Rsv_Tbl_Type,
    p_reserve_set_name      IN VARCHAR2,
    p_rsv_request_id        IN NUMBER DEFAULT NULL,
    p_simulation_request_id IN NUMBER DEFAULT NULL,
    x_return_status OUT NOCOPY VARCHAR2)
IS
  l_set_id        NUMBER;
  l_delete_set_id NUMBER;
  l_process_flag  VARCHAR2(1) :='N';
  l_line_count    NUMBER      :=0;
  --
  l_debug_level CONSTANT NUMBER := oe_debug_pub.g_debug_level;
  --
BEGIN
  IF l_debug_level > 0 THEN
    oe_debug_pub.add( 'ENTERING CREATE_RESERVATION_SET ' , 1 ) ;
  END IF;
  IF g_set_id                IS NULL THEN
    g_program_application_id := Fnd_global.PROG_APPL_ID;
    g_program_id             := Fnd_Global.Conc_Program_Id;
    -- Deleting records from table for the given set name.
    BEGIN
      SELECT reservation_set_id
      INTO l_set_id
      FROM oe_reservation_sets
      WHERE reservation_set_name = P_reserve_set_name;
      g_set_id                  := l_set_id;
      -- Deleting the existing records.
      DELETE oe_rsv_set_details
      WHERE reservation_set_id = l_set_id;
      DELETE oe_reservation_sets WHERE reservation_set_id = l_set_id;
    EXCEPTION
    WHEN OTHERS THEN
      NULL;
    END;
    IF g_set_id IS NULL THEN
      SELECT oe_reservation_sets_s.nextval INTO g_set_id FROM dual;
    END IF;
    IF p_rsv_request_id IS NOT NULL THEN
      l_process_flag    := 'Y';
    END IF;
    IF l_debug_level > 0 THEN
      oe_debug_pub.add( 'Reservation_Set_Id:  '||g_set_id , 1 ) ;
    END IF;
    -- Insert Header information
    INSERT
    INTO oe_reservation_sets
      (
        Reservation_Set_Id ,
        Reservation_Set_Name ,
        Reservation_request_id ,
        process_Flag ,
        Simulation_Request_id ,
        Creation_date ,
        created_by ,
        program_update_date ,
        program_application_id ,
        program_id ,
        last_update_login ,
        last_updated_by ,
        last_update_date
      )
      VALUES
      (
        g_set_id ,
        P_reserve_set_name ,
        p_rsv_request_id ,
        l_process_flag ,
        p_simulation_request_id ,
        sysdate ,
        FND_GLOBAL.USER_ID ,
        sysdate ,
        g_program_application_id ,
        g_program_id ,
        FND_GLOBAL.CONC_LOGIN_ID ,
        FND_GLOBAL.USER_ID ,
        sysdate
      );
  END IF;
  -- Insert Detail Information
  FOR I IN 1..p_rsv_tbl.COUNT
  LOOP
    l_line_count := l_line_count + 1;
    INSERT
    INTO oe_rsv_set_details
      (
        Reservation_set_id ,
        Line_id ,
        header_id ,
        inventory_item_id ,
        ordered_qty ,
        ordered_qty2 -- INVCONV
        ,
        ordered_qty_uom ,
        ordered_qty_uom2 -- INVCONV
        ,
        derived_qty ,
        derived_qty2 -- INVCONV
        ,
        derived_qty_uom ,
        corrected_qty ,
        corrected_qty2 -- INVCONV
        ,
        ship_from_org_id ,
        subinventory ,
        creation_date ,
        created_by ,
        last_update_date ,
        last_updated_by ,
        last_update_login ,
        program_application_id ,
        program_id ,
        program_update_date
      )
      VALUES
      (
        g_set_id ,
        p_rsv_tbl(I).line_id ,
        p_rsv_tbl(I).header_id ,
        p_rsv_tbl(I).inventory_item_id ,
        p_rsv_tbl(I).ordered_qty ,
        p_rsv_tbl(I).ordered_qty2 -- INVCONV
        ,
        p_rsv_tbl(I).ordered_qty_uom ,
        p_rsv_tbl(I).ordered_qty_uom2 -- INVCONV
        ,
        p_rsv_tbl(I).derived_reserved_qty ,
        p_rsv_tbl(I).derived_reserved_qty2 -- INVCONV
        ,
        p_rsv_tbl(I).reserved_qty_UOM ,
        NVL(p_rsv_tbl(I).corrected_reserved_qty,p_rsv_tbl(I).derived_reserved_qty) ,
        NVL(p_rsv_tbl(I).corrected_reserved_qty2,p_rsv_tbl(I).derived_reserved_qty2) -- INVCONV
        ,
        p_rsv_tbl(I).ship_from_org_id ,
        p_rsv_tbl(I).subinventory ,
        sysdate ,
        FND_GLOBAL.USER_ID ,
        sysdate ,
        FND_GLOBAL.USER_ID ,
        FND_GLOBAL.CONC_LOGIN_ID ,
        g_program_application_id ,
        g_program_id ,
        sysdate
      );
    IF l_line_count = 500 THEN
      COMMIT;
      l_line_count := 0;
    END IF;
  END LOOP;
  IF l_debug_level > 0 THEN
    oe_debug_pub.add( 'EXITING CREATE_RESERVATION_SET ' , 1 ) ;
  END IF;
  x_return_status := FND_API.G_RET_STS_SUCCESS;
EXCEPTION
WHEN OTHERS THEN
  IF l_debug_level > 0 THEN
    OE_DEBUG_PUB.Add('In others error...in Proc Create_Reservation_Set ',1);
  END IF;
  --x_return_status := FND_API.G_RET_STS_UNEXP_ERROR;
  RAISE FND_API.G_EXC_UNEXPECTED_ERROR;
END Create_Reservation_Set;
/*------------------------------------------------------
Procedure Name : Calculate_Partial_Quantity
Description    : calculate quantity to be reserved based on reservation mode.
If mode is "Only unreserved lines" then derived quantity
will be the ordered quantity, otherwise it will be difference
of ordered quantity and quantity already reserved
--------------------------------------------------------------------- */
PROCEDURE Calculate_Partial_Quantity
  (
    p_x_rsv_tbl        IN OUT NOCOPY rsv_tbl_type,
    p_reservation_mode IN VARCHAR2,
    x_return_status OUT NOCOPY VARCHAR2
  )
IS
  l_sales_order_id     NUMBER;
  l_return_status      VARCHAR2(1);
  l_reserved_quantity  NUMBER :=0;
  l_reserved_quantity2 NUMBER :=0; -- INVCONV
  l_primary_uom        VARCHAR2(3);
  l_total_supply       NUMBER:=0;
  l_total_supply2      NUMBER:=0; -- INVCONV
  --4695715
  l_total_conv_supply  NUMBER:=0;
  l_total_conv_supply2 NUMBER:=0; -- INVCONV
  l_temp               NUMBER:=0;
  --
  l_debug_level CONSTANT NUMBER := oe_debug_pub.g_debug_level;
  --
BEGIN
  IF l_debug_level > 0 THEN
    oe_debug_pub.add( 'ENTERING CALCULATE_PARTIAL_QUANTITY ' , 1 ) ;
  END IF;
  Reservable_Quantity(p_inventory_item_id => p_x_rsv_tbl(1).inventory_item_id, p_ship_from_org_id => p_x_rsv_tbl(1).ship_from_org_id, p_subinventory => p_x_rsv_tbl(1).subinventory, p_org_id => p_x_rsv_tbl(1).org_id, -- 4759251
  x_primary_uom => l_primary_uom, x_available_qty => l_total_supply, x_available_qty2 => l_total_supply2                                                                                                                -- INVCONV
  );
  FOR I IN 1..p_x_rsv_tbl.COUNT
  LOOP
    -- 4695715 : Start
    l_temp :=0;
    IF NOT OE_GLOBALS.Equal(p_x_rsv_tbl(I).ordered_qty_UOM, l_primary_uom) THEN
      IF l_debug_level > 0 THEN
        oe_debug_pub.add( 'Before UOM convertion :' || l_total_supply || '/' || l_primary_uom, 1 ) ;
      END IF;
      l_total_conv_supply := INV_CONVERT.INV_UM_CONVERT( item_id => p_x_rsv_tbl(I).inventory_item_id, PRECISION => 5, from_quantity => l_total_supply, from_unit => l_primary_uom, to_unit => p_x_rsv_tbl(I).ordered_qty_uom, from_name => NULL, to_name => NULL );
      IF l_debug_level     > 0 THEN
        oe_debug_pub.add( 'After UOM convertion :' || l_total_conv_supply || '/' || p_x_rsv_tbl(I).ordered_qty_uom, 1 ) ;
        oe_debug_pub.add( 'Total Supply2 :' || l_total_conv_supply2 || '/' || p_x_rsv_tbl(I).ordered_qty_uom2, 1 ) ;
      END IF;
    ELSE
      l_total_conv_supply := l_total_supply;
    END IF;
    --9135803
    l_total_conv_supply2 := l_total_supply2;
    IF l_debug_level      > 0 THEN
      oe_debug_pub.add( 'Total Supply2 :' || l_total_conv_supply2 || '/' || p_x_rsv_tbl(I).ordered_qty_uom2, 1 ) ;
    END IF;
    -- 4695715 : End
    IF p_reservation_mode                   = 'PARTIAL_ONLY_UNRESERVED' THEN
      p_x_rsv_tbl(I).derived_reserved_qty  := p_x_rsv_tbl(I).ordered_qty;
      p_x_rsv_tbl(I).derived_reserved_qty2 := -- INVCONV
      NVL(p_x_rsv_tbl(I).ordered_qty2,0);
      IF l_total_conv_supply                 > 0 AND p_x_rsv_tbl(I).derived_reserved_qty > l_total_conv_supply THEN
        p_x_rsv_tbl(I).derived_reserved_qty := l_total_conv_supply;
      END IF;
      IF l_total_conv_supply2                 > 0 AND p_x_rsv_tbl(I).derived_reserved_qty2 > l_total_conv_supply2 THEN --INVCONV
        p_x_rsv_tbl(I).derived_reserved_qty2 := l_total_conv_supply2;
      END IF;
      --l_total_supply := l_total_supply - p_x_rsv_tbl(I).derived_reserved_qty;
      -- 4695715 : Start
      IF OE_GLOBALS.Equal(l_primary_uom ,p_x_rsv_tbl(I).ordered_qty_uom) THEN
        g_consumed_for_lot := g_consumed_for_lot + p_x_rsv_tbl(I).derived_reserved_qty;
        l_total_supply     := l_total_supply     - p_x_rsv_tbl(I).derived_reserved_qty;
      ELSE
        l_temp             := INV_CONVERT.INV_UM_CONVERT( item_id => p_x_rsv_tbl(I).inventory_item_id, PRECISION => 5, from_quantity => p_x_rsv_tbl(I).derived_reserved_qty, from_unit => p_x_rsv_tbl(I).ordered_qty_uom, to_unit => l_primary_uom, from_name => NULL, to_name => NULL );
        g_consumed_for_lot := g_consumed_for_lot + l_temp;
        l_total_supply     := l_total_supply     - l_temp;
      END IF;
      -- 4695715 : End
      p_x_rsv_tbl(I).reserved_qty_UOM := p_x_rsv_tbl(I).ordered_qty_UOM;
      -- 4695715 : Start
      --l_total_supply2 := l_total_supply2 - nvl(p_x_rsv_tbl(I).derived_reserved_qty2,0); -- INVCONV
      l_temp :=0;
      --9135803
      IF NVL(p_x_rsv_tbl(I).derived_reserved_qty2,0) <= 0 THEN
        p_x_rsv_tbl(I).derived_reserved_qty2         := 0;
      END IF;
      g_consumed_for_lot2 := g_consumed_for_lot2 + NVL(p_x_rsv_tbl(I).derived_reserved_qty2,0); -- INVCONV
      l_total_supply2     := l_total_supply2     - NVL(p_x_rsv_tbl(I).derived_reserved_qty2,0); -- INVCONV
      -- 4695715 : End
    ELSE
      /* -- 6814153 : moved to procedure Reserve
      l_reserved_quantity :=0;
      l_reserved_quantity2 :=0; -- INVCONV
      l_sales_order_id :=
      Oe_Schedule_Util.Get_mtl_sales_order_id(p_x_rsv_tbl(I).HEADER_ID);
      -- INVCONV - MERGED CALLS  FOR OE_LINE_UTIL.Get_Reserved_Quantity and OE_LINE_UTIL.Get_Reserved_Quantity2
      OE_LINE_UTIL.Get_Reserved_Quantities(p_header_id => l_sales_order_id
      ,p_line_id   => p_x_rsv_tbl(I).line_id
      ,p_org_id    => p_x_rsv_tbl(I).ship_from_org_id
      ,x_reserved_quantity =>  l_reserved_quantity
      ,x_reserved_quantity2 => l_reserved_quantity2
      );
      l_reserved_quantity := OE_LINE_UTIL.Get_Reserved_Quantity
      (p_header_id   => l_sales_order_id,
      p_line_id     => p_x_rsv_tbl(I).line_id,
      p_org_id      => p_x_rsv_tbl(I).ship_from_org_id);
      l_reserved_quantity2 := OE_LINE_UTIL.Get_Reserved_Quantity2   -- INVCONV
      (p_header_id   => l_sales_order_id,
      p_line_id     => p_x_rsv_tbl(I).line_id,
      p_org_id      => p_x_rsv_tbl(I).ship_from_org_id);
      -- Derive the quantity to be reserved
      p_x_rsv_tbl(I).derived_reserved_qty
      := p_x_rsv_tbl(I).ordered_qty - NVL(l_reserved_quantity,0);
      p_x_rsv_tbl(I).derived_reserved_qty2 -- INVCONV
      := p_x_rsv_tbl(I).ordered_qty2 - NVL(l_reserved_quantity2,0);
      IF l_debug_level  > 0 THEN
      oe_debug_pub.add(  'Derived Reserved Qty: '||p_x_rsv_tbl(I).derived_reserved_qty , 1 ) ;
      END IF;
      -- Partial Reservation
      -- Reservation exists for the line. Set the flag
      IF l_reserved_quantity > 0 THEN
      p_x_rsv_tbl(I).reservation_exists := 'Y';
      END IF;
      */
      IF l_total_conv_supply                 > 0 AND p_x_rsv_tbl(I).derived_reserved_qty > l_total_conv_supply THEN
        p_x_rsv_tbl(I).derived_reserved_qty := l_total_conv_supply;
      ELSIF l_total_conv_supply             <=0 THEN ---6814153
        p_x_rsv_tbl(I).derived_reserved_qty := 0;
      END IF;
      IF l_total_conv_supply2                 > 0 AND p_x_rsv_tbl(I).derived_reserved_qty2 > l_total_conv_supply2 THEN
        p_x_rsv_tbl(I).derived_reserved_qty2 := l_total_conv_supply2; -- INVCONV
      ELSIF l_total_conv_supply2             <=0 THEN                ---6814153
        p_x_rsv_tbl(I).derived_reserved_qty2 := 0;
      END IF;
      --4695715 : Start
      l_temp :=0;
      --l_total_supply := l_total_supply - p_x_rsv_tbl(I).derived_reserved_qty;
      IF OE_GLOBALS.Equal(l_primary_uom ,p_x_rsv_tbl(I).ordered_qty_uom) THEN
        g_consumed_for_lot := g_consumed_for_lot + p_x_rsv_tbl(I).derived_reserved_qty;
        l_total_supply     := l_total_supply     - p_x_rsv_tbl(I).derived_reserved_qty;
      ELSE
        l_temp             := INV_CONVERT.INV_UM_CONVERT( item_id => p_x_rsv_tbl(I).inventory_item_id, PRECISION => 5, from_quantity => p_x_rsv_tbl(I).derived_reserved_qty, from_unit => p_x_rsv_tbl(I).ordered_qty_uom, to_unit => l_primary_uom, from_name => NULL, to_name => NULL );
        g_consumed_for_lot := g_consumed_for_lot + l_temp;
        l_total_supply     := l_total_supply     - l_temp;
      END IF;
      -- 4695715 : End
      p_x_rsv_tbl(I).reserved_qty_UOM := p_x_rsv_tbl(I).ordered_qty_UOM;
      -- 4695715 : Start
      l_temp :=0;
      --l_total_supply2 := l_total_supply2 - nvl(p_x_rsv_tbl(I).derived_reserved_qty2,0);  -- INVCONV
      --9135803
      IF NVL(p_x_rsv_tbl(I).derived_reserved_qty2,0) <= 0 THEN
        p_x_rsv_tbl(I).derived_reserved_qty2         := 0;
      END IF;
      g_consumed_for_lot2 := g_consumed_for_lot2 + NVL(p_x_rsv_tbl(I).derived_reserved_qty2,0); -- INVCONV
      l_total_supply2     := l_total_supply2     - NVL(p_x_rsv_tbl(I).derived_reserved_qty2,0); -- INVCONV
      --4695715 : End
    END IF;
    Validate_Derived_Quantities(p_x_rsv_tbl(I)); -- Bug 13657322
    -- Keeping derived quantity
    p_x_rsv_tbl(I).derived_reserved_qty_mir  := p_x_rsv_tbl(I).derived_reserved_qty;
    p_x_rsv_tbl(I).derived_reserved_qty2_mir := p_x_rsv_tbl(I).derived_reserved_qty2; -- INVCONV
    --5041136
    p_x_rsv_tbl(I).corrected_reserved_qty  := p_x_rsv_tbl(I).derived_reserved_qty;
    p_x_rsv_tbl(I).corrected_reserved_qty2 := p_x_rsv_tbl(I).derived_reserved_qty2;
  END LOOP;
  IF l_debug_level > 0 THEN
    oe_debug_pub.add( 'EXITING CALCULATE_PARTIAL_QUANTITY ' , 1 ) ;
  END IF;
EXCEPTION
WHEN FND_API.G_EXC_UNEXPECTED_ERROR THEN
  IF l_debug_level > 0 THEN
    OE_DEBUG_PUB.Add('In Unexpected Error...in Proc Calculate_Partial_Quantity ',1 );
  END IF;
  --x_return_status := FND_API.G_RET_STS_UNEXP_ERROR;
  RAISE FND_API.G_EXC_UNEXPECTED_ERROR;
WHEN OTHERS THEN
  IF l_debug_level > 0 THEN
    OE_DEBUG_PUB.Add('In others error...in Proc Calculate_Partial_Quantity ',1);
  END IF;
  --x_return_status := FND_API.G_RET_STS_UNEXP_ERROR;
  RAISE FND_API.G_EXC_UNEXPECTED_ERROR;
END Calculate_Partial_Quantity;
/*-------------------------------------------------------------------
Procedure Name : Query_Qty_Tree
Description    : Queries the On-Hand and Available to Reserve
quantites by calling INV's
inv_quantity_tree_pub.query_quantities.
The quantities are given at the highest level
(Item, Org, Subinventory combination).
--------------------------------------------------------------------- */
PROCEDURE Query_Qty_Tree
  (
    p_ship_from_org_id  IN NUMBER,
    p_subinventory_code IN VARCHAR2,
    p_inventory_item_id IN NUMBER,
    x_on_hand_qty OUT NOCOPY       NUMBER,
    x_avail_to_reserve OUT NOCOPY  NUMBER,
    x_on_hand_qty2 OUT NOCOPY      NUMBER, -- INVCONV
    x_avail_to_reserve2 OUT NOCOPY NUMBER  -- INVCONV
  )
IS
  --
  l_debug_level CONSTANT NUMBER := oe_debug_pub.g_debug_level;
  --
  l_return_status    VARCHAR2(1);
  l_msg_count        NUMBER;
  l_msg_data         VARCHAR2(2000);
  l_qoh              NUMBER;
  l_rqoh             NUMBER;
  l_msg_index        NUMBER;
  l_lot_control_flag BOOLEAN;
  l_lot_control_code NUMBER;
  l_qr               NUMBER;
  l_qs               NUMBER;
  l_att              NUMBER;
  l_atr              NUMBER;
  l_sqoh             NUMBER; -- INVCONV
  l_srqoh            NUMBER; -- INVCONV
  l_sqr              NUMBER; -- INVCONV
  l_sqs              NUMBER; -- INVCONV
  l_satt             NUMBER; -- INVCONV
  L_SATR             NUMBER; -- INVCONV
  L_EXPIRATION_DATE  DATE;
  L_SUBINVENTORY     VARCHAR2(20);
  L_LOCATOR_ID       NUMBER;
  L_revision         VARCHAR2(20);
  l_lot_number       VARCHAR2(200);
BEGIN
  fnd_file.put_line(fnd_file.log,'Query_Qty_Tree');
  IF l_debug_level > 0 THEN
    oe_debug_pub.add( 'ENTERING QUERY_QTY_TREE ' , 1 ) ;
  END IF;
  BEGIN
    SELECT msi.lot_control_code
    INTO l_lot_control_code
    FROM mtl_system_items msi
    WHERE msi.inventory_item_id = p_inventory_item_id
    AND msi.organization_id     = p_ship_from_org_id;
    IF l_lot_control_code       = 2 THEN
      l_lot_control_flag       := TRUE;
    ELSE
      l_lot_control_flag := FALSE;
    END IF;
  EXCEPTION
  WHEN OTHERS THEN
    l_lot_control_flag := FALSE;
  END;
  BEGIN
    SELECT UNIQUE MIN(EXPIRATION_DATE)
    INTO l_EXPIRATION_DATE
    FROM
      (SELECT V.LOT_NUMBER LOT,
        V.EXPIRATION_DATE EXPIRATION_DATE,
        T.SUBINVENTORY_CODE SUBINVENTORY,
        RTRIM(INV_PROJECT.GET_LOCATOR(T.LOCATOR_ID,T.ORGANIZATION_ID)) LOCATOR,
        SUM(T.TRANSACTION_QUANTITY) QUANTITY_On_Hand,
        V.C_ATTRIBUTE4 COUNTRY_OF_ORIGIN,
        T.ORGANIZATION_ID,
        t.inventory_item_id
      FROM MTL_ONHAND_QUANTITIES t,
        MTL_LOT_NUMBERS V,
        XXHA_COM_PICK_EXCEP A,
        MTL_SECONDARY_INVENTORIES SI
      WHERE 1                         =1
      AND T.INVENTORY_ITEM_ID         = V.INVENTORY_ITEM_ID(+)
      AND T.ORGANIZATION_ID           = V.ORGANIZATION_ID(+)
      AND T.LOT_NUMBER                = V.LOT_NUMBER(+)
      AND A.ITEM_ID                   = V.INVENTORY_ITEM_ID
      AND SI.ORGANIZATION_ID          = T.ORGANIZATION_ID
      AND si.secondary_inventory_name = T.SUBINVENTORY_CODE
      AND SI.Attribute1               ='Yes'
      AND UPPER(V.C_ATTRIBUTE4)       = UPPER(A.COUNTRY_OF_ORIGIN)
      --AND TRUNC(SYSDATE) BETWEEN TRUNC(A.DATE_FROM) AND NVL(TRUNC(A.DATE_TO),TRUNC(SYSDATE+1))
      AND SYSDATE BETWEEN A.DATE_FROM AND NVL(A.DATE_TO,SYSDATE+1)
      AND T.ORGANIZATION_ID   = p_ship_from_org_id
      AND T.INVENTORY_ITEM_ID = p_inventory_item_id
      GROUP BY V.LOT_NUMBER,
        V.EXPIRATION_DATE,
        T.SUBINVENTORY_CODE,
        RTRIM(INV_PROJECT.GET_LOCATOR(T.LOCATOR_ID,T.ORGANIZATION_ID)),
        V.C_ATTRIBUTE4,
        T.ORGANIZATION_ID,
        T.INVENTORY_ITEM_ID
      )
    WHERE QUANTITY_ON_HAND >= G_ORDERED_QUANTITY
    AND subinventory        =NVL(g_subinventory,subinventory);
    fnd_file.put_line(fnd_file.log,'l_EXPIRATION_DATE :'||l_EXPIRATION_DATE);
  EXCEPTION
  WHEN OTHERS THEN
    l_EXPIRATION_DATE := NULL;
  END;
  BEGIN
    SELECT revision
    INTO L_revision
    FROM Mtl_Item_Revisions
    WHERE 1               =1
    AND INVENTORY_ITEM_ID = p_inventory_item_id --:RESERV_LINES_BLK.INVENTORY_ITEM_ID
    AND ORGANIZATION_ID   = P_SHIP_FROM_ORG_ID  --:reserv_lines_blk.organization_id
    AND ROWNUM            =1
    ORDER BY effectivity_date DESC;
    fnd_file.put_line(fnd_file.log,'L_revision :'||L_revision);
  EXCEPTION
  WHEN OTHERS THEN
    L_REVISION := 'FG';
  END;
  BEGIN
    SELECT LOT,
      SUBINVENTORY,
      LOCATOR_ID
    INTO L_LOT_NUMBER,
      L_SUBINVENTORY,
      L_LOCATOR_ID
    FROM
      (SELECT LOT,
        EXPIRATION_DATE,
        SUBINVENTORY,
        LOCATOR,
        LOCATOR_ID,
        QUANTITY_ON_HAND,
        NVL(QUANTITY_ON_HAND,0) -(
        (SELECT NVL(SUM(RESERVATION_QUANTITY),0)
        FROM MTL_RESERVATIONS
        WHERE INVENTORY_ITEM_ID = T.INVENTORY_ITEM_ID
        AND ORGANIZATION_ID     = T.ORGANIZATION_ID
        AND LOT_NUMBER          = lot
        )+
        (SELECT NVL(SUM(transaction_quantity),0)
        FROM MTL_ONHAND_QUANTITIES_DETAIL
        WHERE INVENTORY_ITEM_ID = T.INVENTORY_ITEM_ID --643898 --:reserv_lines_blk.inventory_item_id
        AND ORGANIZATION_ID     = T.ORGANIZATION_ID   --2557   --:reserv_lines_blk.organization_id
        AND lot_number          = lot
        AND subinventory_code  IN
          (SELECT SECONDARY_INVENTORY_NAME
          FROM MTL_SECONDARY_INVENTORIES
          WHERE ORGANIZATION_ID = T.ORGANIZATION_ID --2557 --:reserv_lines_blk.organization_id
          AND RESERVABLE_TYPE   = '2'
          )
        )) avc ,
        COUNTRY_OF_ORIGIN
      FROM
        (SELECT V.LOT_NUMBER LOT,
          V.EXPIRATION_DATE EXPIRATION_DATE,
          T.SUBINVENTORY_CODE SUBINVENTORY,
          RTRIM(INV_PROJECT.GET_LOCATOR(T.LOCATOR_ID,T.ORGANIZATION_ID)) LOCATOR,
          T.LOCATOR_ID,
          SUM(T.TRANSACTION_QUANTITY) QUANTITY_On_Hand,
          V.C_ATTRIBUTE4 COUNTRY_OF_ORIGIN,
          T.ORGANIZATION_ID,
          t.inventory_item_id
        FROM MTL_ONHAND_QUANTITIES t,
          MTL_LOT_NUMBERS V,
          XXHA_COM_PICK_EXCEP A,
          MTL_SECONDARY_INVENTORIES SI
        WHERE 1                         =1
        AND t.inventory_item_id         = v.inventory_item_id(+)
        AND T.ORGANIZATION_ID           = V.ORGANIZATION_ID(+)
        AND T.LOT_NUMBER                = V.LOT_NUMBER(+)
        AND A.ITEM_ID                   = V.INVENTORY_ITEM_ID
        AND SI.ORGANIZATION_ID          = T.ORGANIZATION_ID
        AND si.secondary_inventory_name = T.SUBINVENTORY_CODE
        AND SI.Attribute1               ='Yes'
        AND UPPER(V.C_ATTRIBUTE4)       = UPPER(A.COUNTRY_OF_ORIGIN)
        --AND TRUNC(SYSDATE) BETWEEN TRUNC(A.DATE_FROM) AND NVL(TRUNC(A.DATE_TO),TRUNC(SYSDATE+1))
        AND SYSDATE BETWEEN A.DATE_FROM AND NVL(A.DATE_TO,SYSDATE+1)
        AND T.ORGANIZATION_ID   = P_SHIP_FROM_ORG_ID  --2557
        AND T.INVENTORY_ITEM_ID = p_inventory_item_id --643898
        GROUP BY V.LOT_NUMBER,
          V.EXPIRATION_DATE,
          T.SUBINVENTORY_CODE,
          RTRIM(INV_PROJECT.GET_LOCATOR(T.LOCATOR_ID,T.ORGANIZATION_ID)),
          T.LOCATOR_ID,
          V.C_ATTRIBUTE4,
          T.ORGANIZATION_ID,
          T.INVENTORY_ITEM_ID
        )T
      WHERE t.EXPIRATION_DATE = l_EXPIRATION_DATE              --'30-JUN-16'
      AND subinventory        =NVL(g_subinventory,subinventory)--QUANTITY_ON_HAND   >= G_ordered_quantity
      )
    WHERE avc >= G_ordered_quantity
    AND ROWNUM =1;
    fnd_file.put_line(fnd_file.log,'l_lot_number :'||l_lot_number);
  EXCEPTION
  WHEN OTHERS THEN
    l_lot_number := NULL;
  END;
  --inv_quantity_tree_pvt.clear_quantity_cache;
  inv_quantity_tree_pvt.mark_all_for_refresh ( p_api_version_number => 1.0 , p_init_msg_lst => FND_API.G_TRUE , x_return_status => l_return_status , x_msg_count => l_msg_count , x_msg_data => l_msg_data );
  IF l_return_status = FND_API.G_RET_STS_UNEXP_ERROR THEN
    oe_msg_pub.transfer_msg_stack;
    l_msg_count:=OE_MSG_PUB.COUNT_MSG;
    FOR I IN 1..l_msg_count
    LOOP
      l_msg_data      := OE_MSG_PUB.Get(I,'F');
      IF l_debug_level > 0 THEN
        oe_debug_pub.add( L_MSG_DATA , 1 ) ;
      END IF;
    END LOOP;
    RAISE FND_API.G_EXC_UNEXPECTED_ERROR;
  ELSIF l_return_status = FND_API.G_RET_STS_ERROR THEN
    oe_msg_pub.transfer_msg_stack;
    l_msg_count:=OE_MSG_PUB.COUNT_MSG;
    FOR I IN 1..l_msg_count
    LOOP
      l_msg_data      := OE_MSG_PUB.Get(I,'F');
      IF l_debug_level > 0 THEN
        oe_debug_pub.add( L_MSG_DATA , 1 ) ;
      END IF;
    END LOOP;
    RAISE FND_API.G_EXC_ERROR;
  END IF;
  FND_FILE.PUT_LINE(FND_FILE.LOG, 'P_ORGANIZATION_ID => '|| P_SHIP_FROM_ORG_ID);
  FND_FILE.PUT_LINE(FND_FILE.LOG, 'P_INVENTORY_ITEM_ID => '|| P_INVENTORY_ITEM_ID);
  FND_FILE.PUT_LINE(FND_FILE.LOG, 'P_IS_LOT_CONTROL => '|| l_lot_control_code);
  FND_FILE.PUT_LINE(FND_FILE.LOG, 'P_LOT_EXPIRATION_DATE => '|| L_EXPIRATION_DATE);
  FND_FILE.PUT_LINE(FND_FILE.LOG, 'P_REVISION => '|| L_REVISION);
  FND_FILE.PUT_LINE(FND_FILE.LOG, 'P_SUBINVENTORY_CODE => '|| L_SUBINVENTORY);
  FND_FILE.PUT_LINE(FND_FILE.LOG, 'P LOT_NUMBER => '|| L_LOT_NUMBER);
  FND_FILE.PUT_LINE(FND_FILE.LOG, 'L LOCATOR ID => '|| L_LOCATOR_ID );
  IF L_LOT_NUMBER IS NOT NULL THEN
    INV_QUANTITY_TREE_PUB.QUERY_QUANTITIES ( P_API_VERSION_NUMBER => 1.0 , X_RETURN_STATUS => L_RETURN_STATUS , X_MSG_COUNT => L_MSG_COUNT , X_MSG_DATA => L_MSG_DATA , P_ORGANIZATION_ID => P_SHIP_FROM_ORG_ID , P_INVENTORY_ITEM_ID => P_INVENTORY_ITEM_ID , P_TREE_MODE => 2 , P_IS_REVISION_CONTROL => TRUE , P_IS_LOT_CONTROL => L_LOT_CONTROL_FLAG , P_LOT_EXPIRATION_DATE => SYSDATE , P_IS_SERIAL_CONTROL => FALSE , P_GRADE_CODE => NULL -- INVCONV      NOT NEEDED NOW
    , P_REVISION => L_REVISION , P_LOT_NUMBER => L_LOT_NUMBER , P_SUBINVENTORY_CODE => L_SUBINVENTORY , P_LOCATOR_ID => L_LOCATOR_ID , x_qoh => l_qoh , x_rqoh => l_rqoh , x_qr => l_qr , x_qs => l_qs , x_att => l_att , x_atr => l_atr , x_sqoh => l_sqoh                                                                                                                                                                                       -- INVCONV
    , x_srqoh => l_srqoh                                                                                                                                                                                                                                                                                                                                                                                                                          -- INVCONV
    , x_sqr => l_sqr                                                                                                                                                                                                                                                                                                                                                                                                                              -- INVCONV
    , x_sqs => l_sqs                                                                                                                                                                                                                                                                                                                                                                                                                              -- INVCONV
    , x_satt => l_satt                                                                                                                                                                                                                                                                                                                                                                                                                            -- INVCONV
    , X_SATR => L_SATR                                                                                                                                                                                                                                                                                                                                                                                                                            -- INVCONV
    );
  END IF;
  IF l_debug_level > 0 THEN
    oe_debug_pub.add( 'AFTER CALLING QUERY_QUANTITIES' , 1 ) ;
    oe_debug_pub.add( 'RR: L_QOH ' || L_QOH , 1 ) ;
    oe_debug_pub.add( 'RR: L_QOH ' || L_ATR , 1 ) ;
  END IF;
  x_on_hand_qty       := l_qoh;
  x_avail_to_reserve  := l_atr;
  x_on_hand_qty2      := l_sqoh; -- INVCONV
  x_avail_to_reserve2 := l_satr; -- INVCONV
  FND_FILE.Put_Line(FND_FILE.LOG, 'Quantity on Hand =  '||x_on_hand_qty||' Qty2 ='||x_on_hand_qty2);
  FND_FILE.Put_Line(FND_FILE.LOG, 'Quantity available to reserve =  '||x_avail_to_reserve||' Qty2 ='||x_avail_to_reserve2);
  IF l_debug_level > 0 THEN
    OE_DEBUG_PUB.ADD( 'EXITING QUERY_QTY_TREE ' , 1 ) ;
    FND_FILE.Put_Line(FND_FILE.LOG, 'EXITING QUERY_QTY_TREE ');
  END IF;
EXCEPTION
WHEN OTHERS THEN
  IF OE_MSG_PUB.Check_Msg_Level(OE_MSG_PUB.G_MSG_LVL_UNEXP_ERROR) THEN
    OE_MSG_PUB.ADD_EXC_MSG ( G_PKG_NAME, 'Query_Qty_Tree');
    FND_FILE.Put_Line(FND_FILE.LOG, 'Query_Qty_Tree');
  END IF;
  RAISE FND_API.G_EXC_UNEXPECTED_ERROR;
END Query_Qty_Tree;
/*----------------------------------------------------------------
PROCEDURE  : Calculate_Percentage
DESCRIPTION: This Procedure is to determine the percengae when program
is running in "Fair Share" mode.
----------------------------------------------------------------*/
PROCEDURE Calculate_Percentage(
    p_inventory_item_id IN NUMBER,
    p_ship_from_org_id  IN NUMBER,
    p_subinventory      IN VARCHAR2,
    p_rsv_tbl           IN XXHEMO_RESERVE_CONC.rsv_tbl_type,
    x_percentage OUT NOCOPY
    /* file.sql.39 change */
                             NUMBER,
    x_primary_uom OUT NOCOPY VARCHAR2 )
IS
  l_total_demand      NUMBER :=0;
  l_total_supply      NUMBER :=0;
  l_primary_uom       VARCHAR2(3);
  l_converted_qty     NUMBER :=0;
  l_on_hand_qty       NUMBER;
  l_on_hand_qty2      NUMBER; -- INVCONV
  l_avail_to_reserve2 NUMBER; -- INVCONV
  --
  l_debug_level CONSTANT NUMBER := oe_debug_pub.g_debug_level;
  --
BEGIN
  IF l_debug_level > 0 THEN
    OE_DEBUG_PUB.Add('Inside Calculate Percentage Procedure',1);
  END IF;
  -- Getting the Primary UOM of the item
  BEGIN
    SELECT primary_uom_code
    INTO l_primary_uom
    FROM mtl_system_items_b
    WHERE inventory_item_id = p_inventory_item_id
    AND organization_id     = NVL(p_ship_from_org_id, OE_Sys_Parameters.VALUE_WNPS('MASTER_ORGANIZATION_ID',p_rsv_tbl(1).org_id)); --4759251
  EXCEPTION
  WHEN OTHERS THEN
    IF l_debug_level > 0 THEN
      OE_DEBUG_PUB.Add('Error in selecting Primary UOM code',1);
    END IF;
    IF OE_MSG_PUB.Check_Msg_Level(OE_MSG_PUB.G_MSG_LVL_UNEXP_ERROR) THEN
      OE_MSG_PUB.Add_Exc_Msg ( G_PKG_NAME, 'Calculate_Percentage');
    END IF;
    RAISE FND_API.G_EXC_UNEXPECTED_ERROR;
  END;
  -- Getting the ordered quantity
  IF l_debug_level > 0 THEN
    OE_DEBUG_PUB.Add('Calculate Percentage Table Count '||p_rsv_tbl.COUNT,1);
  END IF;
  FOR I IN 1..p_rsv_tbl.COUNT
  LOOP
    IF OE_GLOBALS.Equal(p_rsv_tbl(I).ordered_qty_uom, l_primary_uom) THEN
      l_total_demand := l_total_demand + p_rsv_tbl(I).ordered_qty;
    ELSE
      l_converted_qty := INV_CONVERT.INV_UM_CONVERT( item_id => p_inventory_item_id, PRECISION => 5, from_quantity => p_rsv_tbl(I).ordered_qty, from_unit => p_rsv_tbl(I).ordered_qty_uom, to_unit => l_primary_uom, from_name => NULL, to_name => NULL );
      l_total_demand  := l_total_demand + l_converted_qty;
    END IF;
  END LOOP;
  IF l_debug_level > 0 THEN
    OE_DEBUG_PUB.Add('Calculate Percentage Total demand '||l_total_demand,1);
  END IF;
  -- Getting reservable quantity
  IF l_total_demand > 0 THEN
    Query_Qty_Tree(p_ship_from_org_id => p_ship_from_org_id, p_subinventory_code => p_subinventory, p_inventory_item_id => p_inventory_item_id, x_on_hand_qty => l_on_hand_qty, x_avail_to_reserve => l_total_supply, x_on_hand_qty2 => l_on_hand_qty2, -- INVCONV
    x_avail_to_reserve2 => l_avail_to_reserve2                                                                                                                                                                                                          -- INVCONV
    );
  END IF;
  l_total_supply  := l_total_supply - g_total_consumed;
  IF l_debug_level > 0 THEN
    OE_DEBUG_PUB.Add('Calculate Percentage Total Supply '||l_total_Supply,1);
  END IF;
  -- Percent calculation
  IF (l_total_demand    = 0 OR l_total_supply = 0) THEN
    x_percentage       := 0;
  ELSIF l_total_demand <= l_total_supply THEN
    x_percentage       := 100;
  ELSE
    x_percentage := TRUNC((l_total_supply / l_total_demand) * 100, 5);
  END IF;
  -- 4695715
  x_primary_uom   := l_primary_uom;
  IF l_debug_level > 0 THEN
    OE_DEBUG_PUB.Add('Exiting Calculate Percentage '||x_percentage,1);
  END IF;
EXCEPTION
WHEN OTHERS THEN
  IF OE_MSG_PUB.Check_Msg_Level(OE_MSG_PUB.G_MSG_LVL_UNEXP_ERROR) THEN
    OE_MSG_PUB.Add_Exc_Msg ( G_PKG_NAME, 'Calculate_Percentage');
  END IF;
  RAISE FND_API.G_EXC_UNEXPECTED_ERROR;
END calculate_Percentage;
/*----------------------------------------------------------------
PROCEDURE  : Derive_Reservation_qty
DESCRIPTION: This Procedure is to derive reservation qty for each line
based on the percentage passed or derived.
----------------------------------------------------------------*/
PROCEDURE Derive_Reservation_qty(
    p_x_rsv_tbl        IN OUT NOCOPY rsv_tbl_type,
    p_percentage       IN NUMBER,
    p_reservation_mode IN VARCHAR2 DEFAULT NULL,
    p_primary_uom      IN VARCHAR2 DEFAULT NULL )
IS
  l_primary_uom        VARCHAR2(3);
  l_total_supply       NUMBER :=0;
  l_total_supply2      NUMBER :=0; -- INVCONV
  l_validated_quantity NUMBER;
  l_primary_quantity   NUMBER;
  l_qty_return_status  VARCHAR2(1);
  -- 4695715
  l_total_conv_supply  NUMBER :=0;
  l_total_conv_supply2 NUMBER :=0; -- INVCONV
  l_temp               NUMBER :=0;
  --
  l_debug_level CONSTANT NUMBER := oe_debug_pub.g_debug_level;
  --
BEGIN
  --4695715
  IF p_primary_uom IS NOT NULL THEN
    l_primary_uom  := p_primary_uom;
  END IF;
  IF NVL(p_reservation_mode,'*') ='PERCENT' THEN
    Reservable_Quantity(p_inventory_item_id => p_x_rsv_tbl(1).inventory_item_id, p_ship_from_org_id => p_x_rsv_tbl(1).ship_from_org_id, p_subinventory => p_x_rsv_tbl(1).subinventory, p_org_id => p_x_rsv_tbl(1).org_id, --4759251
    x_primary_uom => l_primary_uom, x_available_qty => l_total_supply, x_available_qty2 => l_total_supply2                                                                                                                -- INVCONV
    );
    l_total_conv_supply  := l_total_supply;
    l_total_conv_supply2 := l_total_supply2;
  END IF;
  FOR I IN 1..p_x_rsv_tbl.COUNT
  LOOP
    -- 4695715 :Start
    IF NOT OE_GLOBALS.Equal(p_x_rsv_tbl(I).ordered_qty_UOM, l_primary_uom) AND NVL(p_reservation_mode,'*') ='PERCENT' THEN
      IF l_debug_level                                                                                     > 0 THEN
        oe_debug_pub.add( 'Before UOM convertion :' || l_total_supply || '/' || l_primary_uom, 1 ) ;
      END IF;
      l_total_conv_supply := INV_CONVERT.INV_UM_CONVERT( item_id => p_x_rsv_tbl(I).inventory_item_id, PRECISION => 5, from_quantity => l_total_supply, from_unit => l_primary_uom, to_unit => p_x_rsv_tbl(I).ordered_qty_uom, from_name => NULL, to_name => NULL );
      IF l_debug_level     > 0 THEN
        oe_debug_pub.add( 'After UOM convertion :' || l_total_conv_supply || '/' || p_x_rsv_tbl(I).ordered_qty_uom, 1 );
        oe_debug_pub.add( 'Total Supply2 :' || l_total_conv_supply2 || '/' || p_x_rsv_tbl(I).ordered_qty_uom, 1 );
      END IF;
    ELSIF NVL(p_reservation_mode,'*') ='PERCENT' THEN
      l_total_conv_supply            := l_total_supply;
    END IF;
    --9135803
    l_total_conv_supply2 := l_total_supply2;
    IF l_debug_level      > 0 THEN
      oe_debug_pub.add( 'Total Supply2 :' || l_total_conv_supply2 || '/' || p_x_rsv_tbl(I).ordered_qty_uom2, 1 );
    END IF;
    -- 4695715 :End
    p_x_rsv_tbl(I).derived_reserved_qty  := TRUNC((p_x_rsv_tbl(I).ordered_qty * p_percentage) / 100, 5);
    p_x_rsv_tbl(I).derived_reserved_qty2 :=                       -- INVCONV
    TRUNC((p_x_rsv_tbl(I).ordered_qty2 * p_percentage) / 100, 5); -- INVCONV
    -- Commenting code for 13657322
    /*
    IF l_debug_level  > 0 THEN
    OE_DEBUG_PUB.Add('Before Calling  validate_quantity ' ,1);
    END IF;
    inv_decimals_pub.validate_quantity(
    p_item_id          => p_x_rsv_tbl(I).inventory_item_id,
    p_organization_id  =>
    OE_Sys_Parameters.VALUE('MASTER_ORGANIZATION_ID',p_x_rsv_tbl(I).org_id), -- 4759251
    p_input_quantity   => p_x_rsv_tbl(I).derived_reserved_qty,
    p_uom_code         => p_x_rsv_tbl(I).ordered_qty_uom,
    x_output_quantity  => l_validated_quantity,
    x_primary_quantity => l_primary_quantity,
    x_return_status    => l_qty_return_status);
    IF l_debug_level  > 0 THEN
    OE_DEBUG_PUB.Add('After Calling  validate_quantity: '||l_qty_return_status ,1);
    END IF;
    IF l_qty_return_status = 'W' OR l_qty_return_status = 'E' THEN
    IF l_debug_level  > 0 THEN
    OE_DEBUG_PUB.Add('Validate_quantity returns Error/Warning: truncating the quantity');
    END IF;
    p_x_rsv_tbl(I).derived_reserved_qty := TRUNC(l_validated_quantity);
    END IF;
    IF l_debug_level  > 0 THEN
    OE_DEBUG_PUB.Add('Validate_quantity: '||p_x_rsv_tbl(I).derived_reserved_qty ,1);
    OE_DEBUG_PUB.Add('Available quantity: '||l_total_conv_supply ,1);
    END IF;
    */
    IF NVL(p_reservation_mode,'*')           ='PERCENT' THEN
      IF l_total_conv_supply                 > 0 AND p_x_rsv_tbl(I).derived_reserved_qty > l_total_conv_supply THEN
        p_x_rsv_tbl(I).derived_reserved_qty := l_total_conv_supply;
      ELSIF l_total_conv_supply              = 0 THEN
        p_x_rsv_tbl(I).derived_reserved_qty := 0;
      END IF;
      --l_total_supply := l_total_supply - p_x_rsv_tbl(I).derived_reserved_qty;
      IF l_total_conv_supply2                 > 0 AND p_x_rsv_tbl(I).derived_reserved_qty2 > l_total_conv_supply2 THEN -- INVCONV from code review comments from AK
        p_x_rsv_tbl(I).derived_reserved_qty2 := l_total_conv_supply2;
      ELSIF l_total_conv_supply2              = 0 THEN
        p_x_rsv_tbl(I).derived_reserved_qty2 := 0;
      END IF;
      --l_total_supply2 := l_total_supply2 - p_x_rsv_tbl(I).derived_reserved_qty2;  -- INVCONV from code review comments from AK
    END IF;
    -- Bug 13657322
    Validate_Derived_Quantities(p_x_rsv_tbl(I));
    IF l_debug_level > 0 THEN
      OE_DEBUG_PUB.Add('Validate_quantity: '||p_x_rsv_tbl(I).derived_reserved_qty ,1);
      OE_DEBUG_PUB.Add('Validate_quantity2: '||p_x_rsv_tbl(I).derived_reserved_qty2 ,1);
      OE_DEBUG_PUB.Add('Available quantity: '||l_total_conv_supply ,1);
    END IF;
    -- Keeping copy of derived quantity
    p_x_rsv_tbl(I).derived_reserved_qty_mir := p_x_rsv_tbl(I).derived_reserved_qty;
    p_x_rsv_tbl(I).reserved_qty_UOM         := p_x_rsv_tbl(I).ordered_qty_UOM;
    -- 4695715 :Start
    IF OE_GLOBALS.Equal(l_primary_uom, p_x_rsv_tbl(I).ordered_qty_uom) THEN
      g_consumed_for_lot            := g_consumed_for_lot + p_x_rsv_tbl(I).derived_reserved_qty;
      IF NVL(p_reservation_mode,'*') ='PERCENT' THEN
        l_total_supply              := l_total_supply - p_x_rsv_tbl(I).derived_reserved_qty;
      END IF;
    ELSE
      l_temp                        := INV_CONVERT.INV_UM_CONVERT( item_id => p_x_rsv_tbl(I).inventory_item_id, PRECISION => 5, from_quantity => p_x_rsv_tbl(I).derived_reserved_qty, from_unit => p_x_rsv_tbl(I).ordered_qty_uom, to_unit => l_primary_uom, from_name => NULL, to_name => NULL );
      g_consumed_for_lot            := g_consumed_for_lot + l_temp;
      IF NVL(p_reservation_mode,'*') ='PERCENT' THEN
        l_total_supply              := l_total_supply - l_temp;
      END IF;
    END IF;
    -- 4695715 : End
    -- INVCONV from code review comments from AK
    p_x_rsv_tbl(I).derived_reserved_qty2_mir := p_x_rsv_tbl(I).derived_reserved_qty2;
    --p_x_rsv_tbl(I).reserved_qty_UOM := p_x_rsv_tbl(I).ordered_qty_UOM;
    -- 4695715 : Start
    l_temp :=0;
    --9135803
    g_consumed_for_lot2           := g_consumed_for_lot2 + p_x_rsv_tbl(I).derived_reserved_qty2;
    IF NVL(p_reservation_mode,'*') ='PERCENT' THEN
      l_total_supply2             := l_total_supply2 - p_x_rsv_tbl(I).derived_reserved_qty2; -- INVCONV from code review comments from AK
    END IF;
    IF l_debug_level > 0 THEN
      OE_Debug_pub.Add('Total Supply2 '||l_total_supply2,1);
    END IF;
    -- 4695715 : End
    --5041136
    p_x_rsv_tbl(I).corrected_reserved_qty  := p_x_rsv_tbl(I).derived_reserved_qty;
    p_x_rsv_tbl(I).corrected_reserved_qty2 := p_x_rsv_tbl(I).derived_reserved_qty2;
    IF l_debug_level                        > 0 THEN
      OE_Debug_pub.Add('Derived reserved Qty '||p_x_rsv_tbl(I).derived_reserved_qty,1);
      OE_Debug_pub.Add('Consumed reserved Qty '||g_consumed_for_lot,1);
      OE_Debug_pub.Add('Derived reserved Qty2 '||p_x_rsv_tbl(I).derived_reserved_qty2,1);
      OE_Debug_pub.Add('Consumed reserved Qty2 '||g_consumed_for_lot2,1);
    END IF;
  END LOOP;
END DERIVE_RESERVATION_QTY;
/*----------------------------------------------------------------
PROCEDURE  : send mail
DESCRIPTION: send mail
-----------------------------------------------------------------*/
PROCEDURE SEND_MAIL(
    V_FROM      IN VARCHAR2,
    V_RECIPIENT IN VARCHAR2,
    V_SUBJECT   IN VARCHAR2,
    V_BODY      IN VARCHAR2,
    V_ORG_ID    IN NUMBER)
AS
  --V_RECIPIENT1 VARCHAR2(80) ;--:= 'vijay.medikonda@haemonetics.com'
  v_Mail_Host  VARCHAR2(100); -- := 'smtp-bo.haemo.net'; --Modified by Sethu
  v_Mail_Conn utl_smtp.Connection;
  crlf VARCHAR2(2) := chr(13)||chr(10);
  L_RECIPIENT varchar2(100);
  l_prod_flag varchar2(10);
  l_test_email varchar2(2000);

  --L_RECIPIENT1 varchar2(100);
BEGIN
        --Added by Sethu
       v_Mail_Host := XXHA_FND_UTIL_PKG.get_ip_address;
       
       IF v_Mail_Host IS NULL THEN
        fnd_file.put_line (fnd_file.LOG, 'SMTP host does not exist');
       END IF;      
       --Change ends

  v_Mail_Conn := utl_smtp.Open_Connection(v_Mail_Host, 25);
  utl_smtp.Helo(v_Mail_Conn, v_Mail_Host);
  utl_smtp.Mail(v_Mail_Conn, v_From);  
  
  begin
      select FLV.description
        into L_RECIPIENT
      FROM FND_LOOKUP_VALUES FLV, HR_OPERATING_UNITS OU 
      where 1=1
            AND ou.organization_id = V_ORG_ID
            and FLV.LOOKUP_CODE like OU.ORGANIZATION_ID
              AND FLV.LOOKUP_TYPE='XXHA_RES_ORDER_EMAIL'  
          and FLV.LANGUAGE = USERENV('LANG')
        and flv.enabled_flag='Y'
        and trunc(sysdate) between trunc(start_date_active) and trunc(nvl(end_date_active,sysdate));
  exception when others then 
  fnd_file.put_line(fnd_file.log, 'Error Occured in getting email details from lookup XXHA_RES_ORDER_EMAIL');
  end;

   IF L_RECIPIENT IS NULL    THEN
    select FLV.description 
      INTO L_RECIPIENT
    FROM FND_LOOKUP_VALUES FLV, HR_OPERATING_UNITS OU 
    WHERE 1=1
      AND ou.NAME = 'Haemonetics Corp US OU'
      AND FLV.LOOKUP_CODE=OU.ORGANIZATION_ID
      AND FLV.LOOKUP_TYPE='XXHA_RES_ORDER_EMAIL' 
      and FLV.LANGUAGE = USERENV('LANG')
      and flv.enabled_flag='Y'
        and trunc(sysdate) between trunc(start_date_active) and trunc(nvl(end_date_active,sysdate));
  fnd_file.put_line(fnd_file.log, 'Email defaulted to US from lookup XXHA_RES_ORDER_EMAIL');
   END IF; 

   --Start AA Added to send email to test email address in non-prod instance
    BEGIN 
      SELECT xxha_prod_db INTO l_prod_flag FROM dual;
--      SELECT XXHA_GET_TEST_EMAIL_ADDRESS INTO l_test_email FROM dual; --Commented by Sethu
      SELECT XXHA_FND_UTIL_PKG.get_recipients INTO l_test_email FROM dual; --Added by Sethu
    EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log, 'Exception at Prod flag capture.'||SQLERRM);
    END;
      IF ( l_prod_flag = 'N') THEN
        L_RECIPIENT := l_test_email;
        fnd_file.put_line(fnd_file.log, 'L_RECIPIENT is defaulted to XXHA_GET_TEST_EMAIL_ADDRESS: '||l_test_email);
        END IF;
   --End AA Added to send email to test email address in non-prod instance        
   
  UTL_SMTP.RCPT(V_MAIL_CONN, L_RECIPIENT);  
  --UTL_SMTP.RCPT(V_MAIL_CONN, L_RECIPIENT1);
  --utl_smtp.Data(v_Mail_Conn, 'Date: ' || TO_CHAR(sysdate, 'Dy, DD Mon YYYY hh24:mi:ss') || crlf || 'From: ' || v_From || crlf || 'Subject: '|| v_Subject || crlf || 'To: ' || L_RECIPIENT || CRLF || 'Cc: ' || L_RECIPIENT1 || CRLF || CRLF || V_BODY );
  utl_smtp.Data(v_Mail_Conn, 'Date: ' || TO_CHAR(sysdate, 'Dy, DD Mon YYYY hh24:mi:ss') || crlf || 'From: ' || v_From || crlf || 'Subject: '|| v_Subject || crlf || 'To: ' || L_RECIPIENT || CRLF  || CRLF || V_BODY );
  utl_smtp.Quit(v_mail_conn);
EXCEPTION
WHEN utl_smtp.Transient_Error OR utl_smtp.Permanent_Error THEN
  RAISE_APPLICATION_ERROR(-20000, 'Unable to send mail: '||SQLERRM);
END;
/*----------------------------------------------------------------
PROCEDURE  : Create_Reservation
DESCRIPTION: This Procedure send each line in rsv_tbl to the Inventory for
Reservation
-----------------------------------------------------------------*/
PROCEDURE Create_Reservation(
    p_x_rsv_tbl           IN OUT NOCOPY XXHEMO_RESERVE_CONC.rsv_tbl_type,
    p_partial_reservation IN VARCHAR2 DEFAULT FND_API.G_TRUE,
    x_return_status OUT NOCOPY
    /* file.sql.39 change */
    VARCHAR2)
IS
  l_return_status VARCHAR2(1) := FND_API.G_RET_STS_SUCCESS;
  l_reservation_rec Inv_Reservation_Global.Mtl_Reservation_Rec_Type;
  l_msg_count NUMBER;
  l_dummy_sn Inv_Reservation_Global.Serial_Number_Tbl_Type;
  l_msg_data           VARCHAR2(1000);
  l_buffer             VARCHAR2(1000);
  l_quantity_reserved  NUMBER;
  l_quantity2_reserved NUMBER; -- INVCONV
  l_rsv_id             NUMBER;
  --Pack J
  l_count_header             NUMBER:=0;
  l_request_id               NUMBER;
  l_commit_count             NUMBER :=0;
  l_partial_reservation_flag VARCHAR2(1);
  l_validated_quantity       NUMBER;
  l_primary_quantity         NUMBER;
  l_qty_return_status        VARCHAR2(1);
  l_rsv_exists               BOOLEAN;
  --
  l_debug_level CONSTANT NUMBER := oe_debug_pub.g_debug_level;
  --
  L_EXPIRATION_DATE DATE;
  g_ordered_quantity number;
  g_subinventory VARCHAR2(20);
  L_SUBINVENTORY    VARCHAR2(20);
  L_LOCATOR_ID      NUMBER;
  L_REVISION        VARCHAR2(20);
  L_revision_COUNT  NUMBER;
  L_LOT_NUMBER      VARCHAR2(200);
  L_ORDER_NUMBER    VARCHAR2(30);
  l_org_name        VARCHAR2(100);
  l_org_id1            NUMBER;
  l_req_id          NUMBER;
  L_FROM            VARCHAR2(80);
  l_RECIPIENT       VARCHAR2(80);
  L_SUBJECT         VARCHAR2(80);
  L_BODY            VARCHAR2(300);
  L_LINE_NUMBER     VARCHAR2(30);
  L_ORDERED_ITEM    VARCHAR2(30);
  out_message       VARCHAR2(1000);
  l_msg_index_OUT   VARCHAR2(1000);
BEGIN
  OE_DEBUG_PUB.ADD ('inside Create reservation',1);
  FND_FILE.Put_Line(FND_FILE.LOG, 'inside Create reservation');
  FND_PROFILE.Get('CONC_REQUEST_ID', l_request_id);
  l_partial_reservation_flag := p_partial_reservation; -- Pack J
  FOR I IN 1..p_x_rsv_tbl.COUNT
  LOOP
    --5041136
    --IF p_x_rsv_tbl(I).derived_reserved_qty > 0 THEN
    IF p_x_rsv_tbl(I).corrected_reserved_qty > 0 THEN
      IF l_debug_level                       > 0 THEN
        OE_Debug_pub.Add('Creating reservation record',1);
      END IF;
      --Pack J
      l_count_header   := l_count_header + 1;
      IF l_count_header = 1 THEN
        -- Set Message Context
        OE_MSG_PUB.set_msg_context( p_entity_code => 'LINE' ,p_entity_id => p_x_rsv_tbl(I).line_id ,p_header_id => p_x_rsv_tbl(I).header_id ,p_line_id => p_x_rsv_tbl(I).line_id ,p_order_source_id => p_x_rsv_tbl(I).order_source_id ,p_orig_sys_document_ref => p_x_rsv_tbl(I).orig_sys_document_ref ,p_orig_sys_document_line_ref => p_x_rsv_tbl(I).orig_sys_line_ref ,p_orig_sys_shipment_ref => p_x_rsv_tbl(I).orig_sys_shipment_ref ,p_change_sequence => p_x_rsv_tbl(I).change_sequence ,p_source_document_type_id => p_x_rsv_tbl(I).source_document_type_id ,p_source_document_id => p_x_rsv_tbl(I).source_document_id ,p_source_document_line_id => p_x_rsv_tbl(I).source_document_line_id );
      ELSIF l_count_header > 1 THEN
        -- Update Message Context
        OE_MSG_PUB.update_msg_context( p_entity_code => 'LINE' ,p_entity_id => p_x_rsv_tbl(I).line_id ,p_header_id => p_x_rsv_tbl(I).header_id ,p_line_id => p_x_rsv_tbl(I).line_id ,p_orig_sys_document_ref => p_x_rsv_tbl(I).orig_sys_document_ref ,p_orig_sys_document_line_ref => p_x_rsv_tbl(I).orig_sys_line_ref ,p_change_sequence => p_x_rsv_tbl(I).change_sequence ,p_source_document_id => p_x_rsv_tbl(I).source_document_id ,p_source_document_line_id => p_x_rsv_tbl(I).source_document_line_id ,p_order_source_id => p_x_rsv_tbl(I).order_source_id ,p_source_document_type_id => p_x_rsv_tbl(I).source_document_type_id );
      END IF;
      FND_FILE.PUT_LINE(FND_FILE.LOG, 'l_reservation_rec NULL');
      BEGIN
      SELECT ordered_quantity,
        subinventory
      INTO G_ORDERED_QUANTITY,
        g_subinventory
      FROM OE_ORDER_LINES_ALL
      WHERE LINE_ID =  p_x_rsv_tbl(I).LINE_ID;
      fnd_file.put_line(fnd_file.log,'G_ordered_quantity :'||G_ordered_quantity); -----AppsAssociates
      fnd_file.put_line(fnd_file.log,'g_subinventory :'||g_subinventory);         -----AppsAssociates
    EXCEPTION
    WHEN OTHERS THEN
      G_ORDERED_QUANTITY := NULL;
    END;
    
      
      BEGIN
        SELECT UNIQUE MIN(EXPIRATION_DATE)
        INTO l_EXPIRATION_DATE
        FROM
          (SELECT V.LOT_NUMBER LOT,
            V.EXPIRATION_DATE EXPIRATION_DATE,
            T.SUBINVENTORY_CODE SUBINVENTORY,
            RTRIM(INV_PROJECT.GET_LOCATOR(T.LOCATOR_ID,T.ORGANIZATION_ID)) LOCATOR,
            SUM(T.TRANSACTION_QUANTITY) QUANTITY_On_Hand,
            V.C_ATTRIBUTE4 COUNTRY_OF_ORIGIN,
            T.ORGANIZATION_ID,
            t.inventory_item_id
          FROM MTL_ONHAND_QUANTITIES t,
            MTL_LOT_NUMBERS V,
            XXHA_COM_PICK_EXCEP A,
            MTL_SECONDARY_INVENTORIES SI
          WHERE 1                         =1
          AND T.INVENTORY_ITEM_ID         = V.INVENTORY_ITEM_ID(+)
          AND T.ORGANIZATION_ID           = V.ORGANIZATION_ID(+)
          AND T.LOT_NUMBER                = V.LOT_NUMBER(+)
          AND A.ITEM_ID                   = V.INVENTORY_ITEM_ID
          AND SI.ORGANIZATION_ID          = T.ORGANIZATION_ID
          AND si.secondary_inventory_name = T.SUBINVENTORY_CODE
          AND SI.Attribute1               ='Yes'
          AND UPPER(V.C_ATTRIBUTE4)       = UPPER(A.COUNTRY_OF_ORIGIN)
          --AND TRUNC(SYSDATE) BETWEEN TRUNC(A.DATE_FROM) AND NVL(TRUNC(A.DATE_TO),TRUNC(SYSDATE+1))
          AND SYSDATE BETWEEN A.DATE_FROM AND NVL(A.DATE_TO,SYSDATE+1)
          AND T.ORGANIZATION_ID   = p_x_rsv_tbl(I).SHIP_FROM_ORG_ID  -- P_SHIP_FROM_ORG_ID
          AND T.INVENTORY_ITEM_ID = p_x_rsv_tbl(I).inventory_item_id --p_inventory_item_id
          GROUP BY V.LOT_NUMBER,
            V.EXPIRATION_DATE,
            T.SUBINVENTORY_CODE,
            RTRIM(INV_PROJECT.GET_LOCATOR(T.LOCATOR_ID,T.ORGANIZATION_ID)),
            V.C_ATTRIBUTE4,
            T.ORGANIZATION_ID,
            T.INVENTORY_ITEM_ID
          )
        WHERE QUANTITY_ON_HAND >= G_ORDERED_QUANTITY
        AND subinventory        =NVL(g_subinventory,subinventory);
        fnd_file.put_line(fnd_file.log,'l_EXPIRATION_DATE :'||l_EXPIRATION_DATE);
                fnd_file.put_line(fnd_file.log,'Error_Vijay1 :'||G_ORDERED_QUANTITY);
 
      EXCEPTION
      WHEN OTHERS THEN
        l_EXPIRATION_DATE := NULL;
         fnd_file.put_line(fnd_file.log,'Error_Vijay :'||G_ORDERED_QUANTITY);
     
      END;
      BEGIN
        SELECT revision
        INTO L_revision
        FROM MTL_item_revisions
        WHERE 1               =1                                 -- NODE_LEVEL      = 2
        AND INVENTORY_ITEM_ID = p_x_rsv_tbl(I).inventory_item_id --:RESERV_LINES_BLK.INVENTORY_ITEM_ID
        AND ORGANIZATION_ID   = P_X_RSV_TBL(I).SHIP_FROM_ORG_ID  --:reserv_lines_blk.organization_id
          --AND DEMAND_SOURCE_HEADER_ID = P_X_RSV_TBL(I).DEMAND_SOURCE_HEADER_ID
          --AND DEMAND_SOURCE_LINE_ID = P_X_RSV_TBL(I).LINE_ID
        AND ROWNUM =1
        ORDER BY effectivity_date DESC;
        fnd_file.put_line(fnd_file.log,'L_revision :'||L_revision);
        IF l_debug_level > 0 THEN
          OE_DEBUG_PUB.Add('AA Testing Revision '||L_revision,1);
        END IF;
      EXCEPTION
      WHEN OTHERS THEN
        L_REVISION := 'FG';
      END;
      BEGIN
        SELECT LOT,
          SUBINVENTORY,
          LOCATOR_ID
        INTO L_LOT_NUMBER,
          L_SUBINVENTORY,
          L_LOCATOR_ID
        FROM
          (SELECT LOT,
            EXPIRATION_DATE,
            SUBINVENTORY,
            LOCATOR,
            LOCATOR_ID,
            QUANTITY_ON_HAND,
            NVL(QUANTITY_ON_HAND,0) -(
            (SELECT NVL(SUM(RESERVATION_QUANTITY),0)
            FROM MTL_RESERVATIONS
            WHERE INVENTORY_ITEM_ID = T.INVENTORY_ITEM_ID
            AND ORGANIZATION_ID     = T.ORGANIZATION_ID
            AND LOT_NUMBER          = lot
            )+
            (SELECT NVL(SUM(transaction_quantity),0)
            FROM MTL_ONHAND_QUANTITIES_DETAIL
            WHERE INVENTORY_ITEM_ID = T.INVENTORY_ITEM_ID --643898 --:reserv_lines_blk.inventory_item_id
            AND ORGANIZATION_ID     = T.ORGANIZATION_ID   --2557   --:reserv_lines_blk.organization_id
            AND lot_number          = lot
            AND subinventory_code  IN
              (SELECT SECONDARY_INVENTORY_NAME
              FROM MTL_SECONDARY_INVENTORIES
              WHERE ORGANIZATION_ID = T.ORGANIZATION_ID --2557 --:reserv_lines_blk.organization_id
              AND RESERVABLE_TYPE   = '2'
              )
            )) avc ,
            COUNTRY_OF_ORIGIN
          FROM
            (SELECT V.LOT_NUMBER LOT,
              V.EXPIRATION_DATE EXPIRATION_DATE,
              T.SUBINVENTORY_CODE SUBINVENTORY,
              RTRIM(INV_PROJECT.GET_LOCATOR(T.LOCATOR_ID,T.ORGANIZATION_ID)) LOCATOR,
              T.LOCATOR_ID,
              SUM(T.TRANSACTION_QUANTITY) QUANTITY_On_Hand,
              V.C_ATTRIBUTE4 COUNTRY_OF_ORIGIN,
              T.ORGANIZATION_ID,
              t.inventory_item_id
            FROM MTL_ONHAND_QUANTITIES t,
              MTL_LOT_NUMBERS V,
              XXHA_COM_PICK_EXCEP A,
              MTL_SECONDARY_INVENTORIES SI
            WHERE 1                         =1
            AND t.inventory_item_id         = v.inventory_item_id(+)
            AND T.ORGANIZATION_ID           = V.ORGANIZATION_ID(+)
            AND T.LOT_NUMBER                = V.LOT_NUMBER(+)
            AND A.ITEM_ID                   = V.INVENTORY_ITEM_ID
            AND SI.ORGANIZATION_ID          = T.ORGANIZATION_ID
            AND si.secondary_inventory_name = T.SUBINVENTORY_CODE
            AND SI.Attribute1               ='Yes'
            AND UPPER(V.C_ATTRIBUTE4)       = UPPER(A.COUNTRY_OF_ORIGIN)
            --AND TRUNC(SYSDATE) BETWEEN TRUNC(A.DATE_FROM) AND NVL(TRUNC(A.DATE_TO),TRUNC(SYSDATE+1))
            AND SYSDATE BETWEEN A.DATE_FROM AND NVL(A.DATE_TO,SYSDATE+1)
            AND T.ORGANIZATION_ID   = p_x_rsv_tbl(I).ship_from_org_id  --2557
            AND T.INVENTORY_ITEM_ID = p_x_rsv_tbl(I).inventory_item_id --643898
            GROUP BY V.LOT_NUMBER,
              V.EXPIRATION_DATE,
              T.SUBINVENTORY_CODE,
              RTRIM(INV_PROJECT.GET_LOCATOR(T.LOCATOR_ID,T.ORGANIZATION_ID)),
              T.LOCATOR_ID,
              V.C_ATTRIBUTE4,
              T.ORGANIZATION_ID,
              T.INVENTORY_ITEM_ID
            )T
          WHERE t.EXPIRATION_DATE = l_EXPIRATION_DATE              --'30-JUN-1
          AND subinventory        =NVL(g_subinventory,subinventory)--QUANTITY_ON_HAND   >= G_ordered_quantity
          )
        WHERE avc >= G_ordered_quantity
        AND ROWNUM =1;
        fnd_file.put_line(fnd_file.log,'l_lot_number :'||l_lot_number);
      EXCEPTION
      WHEN OTHERS THEN
        l_lot_number := NULL;
      END;
      l_reservation_rec                   := NULL;
      l_reservation_rec.reservation_id    := fnd_api.g_miss_num; -- cannot know
      l_reservation_rec.requirement_date  := p_x_rsv_tbl(I).schedule_ship_date;
      l_reservation_rec.organization_id   := p_x_rsv_tbl(I).ship_from_org_id;
      l_reservation_rec.inventory_item_id := p_x_rsv_tbl(I).inventory_item_id;
      ----
      l_reservation_rec.lot_number        := l_lot_number;
      l_reservation_rec.subinventory_code := L_SUBINVENTORY;
      l_reservation_rec.revision          := L_REVISION;
      ----
      IF p_x_rsv_tbl(I).source_document_type_id = 10 THEN
        -- This is an internal order line. We need to give
        -- a different demand source type for these lines.
        l_reservation_rec.demand_source_type_id := INV_RESERVATION_GLOBAL.G_SOURCE_TYPE_INTERNAL_ORD; -- intenal order
      ELSE
        l_reservation_rec.demand_source_type_id := INV_RESERVATION_GLOBAL.G_SOURCE_TYPE_OE; -- order entry
      END IF;
      l_reservation_rec.demand_source_header_id := OE_SCHEDULE_UTIL.Get_mtl_sales_order_id(p_x_rsv_tbl(I).header_id);
      l_reservation_rec.demand_source_line_id   := p_x_rsv_tbl(I).line_id;
      l_reservation_rec.reservation_uom_code    := p_x_rsv_tbl(I).ordered_qty_uom;
      --5041136
      --IF p_x_rsv_tbl(I).derived_reserved_qty IS NOT NULL THEN
      IF p_x_rsv_tbl(I).corrected_reserved_qty IS NOT NULL THEN
        --l_reservation_rec.reservation_quantity  := p_x_rsv_tbl(I).derived_reserved_qty;
        l_reservation_rec.reservation_quantity := p_x_rsv_tbl(I).corrected_reserved_qty;
      ELSE
        l_reservation_rec.reservation_quantity := p_x_rsv_tbl(I).ordered_qty;
      END IF;
      --IF p_x_rsv_tbl(I).derived_reserved_qty2 IS NOT NULL THEN -- INVCONV
      IF p_x_rsv_tbl(I).corrected_reserved_qty2 IS NOT NULL THEN -- INVCONV
        --l_reservation_rec.secondary_reservation_quantity  := p_x_rsv_tbl(I).derived_reserved_qty2;
        l_reservation_rec.secondary_reservation_quantity := p_x_rsv_tbl(I).corrected_reserved_qty2;
      ELSE
        l_reservation_rec.secondary_reservation_quantity := p_x_rsv_tbl(I).ordered_qty2;
      END IF;
      IF l_reservation_rec.secondary_reservation_quantity = 0 -- INVCONV
        THEN
        l_reservation_rec.secondary_reservation_quantity := NULL;
      END IF;
      --13397472
      IF p_x_rsv_tbl(I).project_id   IS NOT NULL THEN
        l_reservation_rec.project_id := p_x_rsv_tbl(I).project_id;
      END IF;
      IF p_x_rsv_tbl(I).task_id   IS NOT NULL THEN
        l_reservation_rec.task_id := p_x_rsv_tbl(I).task_id;
      END IF;
      IF l_debug_level > 0 THEN
        OE_DEBUG_PUB.Add('Project id '||l_reservation_rec.project_id||' Task Id '||l_reservation_rec.task_id,1);
      END IF;
      IF l_debug_level > 0 THEN
        OE_DEBUG_PUB.Add('Vijay Testing Revision '||l_reservation_rec.revision,1);
      END IF;
      l_reservation_rec.supply_source_type_id := INV_RESERVATION_GLOBAL.G_SOURCE_TYPE_INV;
      --   l_reservation_rec.subinventory_code     := p_x_rsv_tbl(I).subinventory;
      IF l_debug_level > 0 THEN
        OE_DEBUG_PUB.Add('Vijay Testing 2 '||l_reservation_rec.subinventory_code,1);
      END IF;
      -- check if derived qty has changed then validate the quantity
      IF NVL(l_reservation_rec.reservation_quantity,0) <> NVL(p_x_rsv_tbl(I).derived_reserved_qty_mir,0) THEN
        IF l_debug_level                                > 0 THEN
          OE_DEBUG_PUB.ADD('Before Calling  inv_reservation_pub.validate_quantity ' ,1);
          FND_FILE.PUT_LINE(FND_FILE.LOG, 'Before Calling  inv_reservation_pub.validate_quantity ' );
        END IF;
        inv_decimals_pub.validate_quantity( p_item_id => p_x_rsv_tbl(I).inventory_item_id, p_organization_id => OE_Sys_Parameters.VALUE('MASTER_ORGANIZATION_ID',p_x_rsv_tbl(I).org_id), --4759251
        p_input_quantity => l_reservation_rec.reservation_quantity, p_uom_code => l_reservation_rec.reservation_uom_code, x_output_quantity => l_validated_quantity, x_primary_quantity => l_primary_quantity, x_return_status => l_qty_return_status);
        IF l_debug_level > 0 THEN
          OE_DEBUG_PUB.ADD('After Calling  inv_reservation_pub.validate_quantity: '||L_QTY_RETURN_STATUS ,1);
          FND_FILE.PUT_LINE(FND_FILE.LOG,'After Calling  inv_reservation_pub.validate_quantity: ' );
        END IF;
        IF l_qty_return_status = 'W' OR l_qty_return_status = 'E' THEN
          IF l_debug_level     > 0 THEN
            OE_DEBUG_PUB.ADD('Validate_quantity returns Error/Warning: truncating the quantity');
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Validate_quantity returns Error/Warning: truncating the quantity' );
          END IF;
          l_validated_quantity := TRUNC(l_validated_quantity);
        END IF;
        IF L_DEBUG_LEVEL > 0 THEN
          OE_DEBUG_PUB.Add('Parimary_quantity: '||l_primary_quantity ,1);
          OE_DEBUG_PUB.Add('Validate_quantity: '||l_validated_quantity ,1);
          FND_FILE.PUT_LINE(FND_FILE.LOG,'Validate_quantity: '||l_validated_quantity );
        END IF;
      ELSE
        l_validated_quantity := l_reservation_rec.reservation_quantity;
      END IF;
      --IF l_qty_return_status = FND_API.G_RET_STS_SUCCESS
      IF l_validated_quantity                   > 0 THEN
        l_reservation_rec.reservation_quantity := l_validated_quantity;
        -- Partial reservation check
        IF NVL(p_x_rsv_tbl(I).reservation_exists,'N') = 'Y' THEN
          l_rsv_exists                               := TRUE;
        ELSE
          l_rsv_exists := FALSE;
        END IF;
        -- Call INV with action = RESERVE
        IF L_DEBUG_LEVEL > 0 THEN
          OE_DEBUG_PUB.ADD('Calling  inv_reservation_pub.create_reservation ' ||L_RESERVATION_REC.RESERVATION_QUANTITY,1);
          FND_FILE.PUT_LINE(FND_FILE.LOG,'Calling  inv_reservation_pub.create_reservation ' ||L_RESERVATION_REC.RESERVATION_QUANTITY);
        END IF;
        IF L_LOT_NUMBER IS NOT NULL THEN
          INV_RESERVATION_PUB.CREATE_RESERVATION ( P_API_VERSION_NUMBER => 1.0 , P_INIT_MSG_LST => FND_API.G_TRUE , X_RETURN_STATUS => L_RETURN_STATUS , X_MSG_COUNT => L_MSG_COUNT , X_MSG_DATA => L_MSG_DATA , P_RSV_REC => L_RESERVATION_REC , P_SERIAL_NUMBER => L_DUMMY_SN , X_SERIAL_NUMBER => L_DUMMY_SN , P_PARTIAL_RESERVATION_FLAG => L_PARTIAL_RESERVATION_FLAG --FND_API.G_TRUE
          , p_force_reservation_flag => FND_API.G_FALSE , p_validation_flag => FND_API.G_TRUE , x_quantity_reserved => l_quantity_reserved , x_secondary_quantity_reserved => l_quantity2_reserved                                                                                                                                                                         -- INVCONV
          , X_RESERVATION_ID => L_RSV_ID , P_PARTIAL_RSV_EXISTS => L_RSV_EXISTS );
        END IF;
        IF l_debug_level > 0 THEN
          OE_DEBUG_PUB.ADD('1. After Calling Create Reservation' || L_RETURN_STATUS ||' '||L_QUANTITY_RESERVED,1);
          FND_FILE.PUT_LINE(FND_FILE.LOG,'1. After Calling Create Reservation' || L_RETURN_STATUS ||' '||L_QUANTITY_RESERVED);
          IF ( FND_MSG_PUB.Count_Msg > 0) THEN
            FOR i IN 1..FND_MSG_PUB.Count_Msg
            LOOP
              FND_MSG_PUB.Get(p_msg_index => i, p_encoded => 'F', p_data => out_message, p_msg_index_OUT => l_msg_index_OUT );
              FND_FILE.PUT_LINE(FND_FILE.LOG,'l_msg_data :' ||out_message);
            END LOOP;
          END IF;
        END IF;
        -- Pack J
        IF l_return_status    = FND_API.G_RET_STS_SUCCESS THEN
          l_commit_count     := l_commit_count + 1;
        ELSIF l_return_status = FND_API.G_RET_STS_UNEXP_ERROR THEN
          IF l_debug_level    > 0 THEN
            OE_DEBUG_PUB.ADD('Raising Unexpected error',1);
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Raising Unexpected error');
          END IF;
          RAISE FND_API.G_EXC_UNEXPECTED_ERROR;
        ELSIF l_return_status = FND_API.G_RET_STS_ERROR THEN
          IF l_debug_level    > 0 THEN
            OE_DEBUG_PUB.Add('Raising Expected error',1);
          END IF;
          IF l_msg_data IS NOT NULL THEN
            fnd_message.set_encoded(l_msg_data);
            l_buffer := fnd_message.get;
            OE_MSG_PUB.Add_text(p_message_text => l_buffer);
            IF l_debug_level > 0 THEN
              OE_DEBUG_PUB.Add(l_msg_data,1);
            END IF;
          END IF;
          --RAISE FND_API.G_EXC_ERROR;  -- Commented as we don't need to fail the program for excepted error.
        END IF;
      END IF;
      -- Pack J
      IF l_commit_count  = 500 THEN
        IF l_debug_level > 0 THEN
          OE_DEBUG_PUB.ADD( ' INSIDE LOOP BEFORE CALLING THE COMMIT_RESERVATION' , 1 ) ;
          FND_FILE.PUT_LINE(FND_FILE.LOG,' INSIDE LOOP BEFORE CALLING THE COMMIT_RESERVATION');
        END IF;
        Commit_Reservation(p_request_id => l_request_id ,x_return_status => l_return_status);
        IF l_debug_level > 0 THEN
          OE_DEBUG_PUB.ADD( 'INSIDE LOOP AFTER CALLING THE COMMIT_RESERVATION : ' , 1 ) ;
          FND_FILE.PUT_LINE(FND_FILE.LOG,'INSIDE LOOP AFTER CALLING THE COMMIT_RESERVATION : ');
        END IF;
        --Pack J
        OE_MSG_PUB.Save_Messages(p_request_id => l_request_id);
        COMMIT;
        l_commit_count := 0;
      END IF;
    END IF;
    BEGIN
      SELECT ORDER_NUMBER,
        b.line_number ,
        B.ORDERED_ITEM,
        c.NAME,
        a.org_id
      INTO L_ORDER_NUMBER ,
        l_line_number,
        L_ORDERED_ITEM ,
        l_org_name,
        l_org_id1
      FROM OE_ORDER_HEADERS_ALL A ,
        OE_ORDER_LINES_ALL B ,
        HR_ALL_ORGANIZATION_UNITS c
      WHERE A.HEADER_ID = B.HEADER_ID
      AND a.org_id      = c.ORGANIZATION_ID
      AND B.LINE_ID     = P_X_RSV_TBL(I).LINE_ID;
      
      SELECT COUNT(*)
      INTO L_revision_COUNT
      FROM MTL_RESERVATIONS
      WHERE 1               =1                                 -- NODE_LEVEL      = 2
      AND INVENTORY_ITEM_ID = p_x_rsv_tbl(I).inventory_item_id --:RESERV_LINES_BLK.INVENTORY_ITEM_ID
      AND ORGANIZATION_ID   = P_X_RSV_TBL(I).SHIP_FROM_ORG_ID  --:reserv_lines_blk.organization_id
        --AND DEMAND_SOURCE_HEADER_ID = P_X_RSV_TBL(I).DEMAND_SOURCE_HEADER_ID
      AND DEMAND_SOURCE_LINE_ID = P_X_RSV_TBL(I).LINE_ID
      AND ROWNUM                =1;
      FND_FILE.PUT_LINE(FND_FILE.LOG,'L_revision_COUNT :'||L_REVISION_COUNT);
      -- 'Order Number XX123 is not reserved automatically'
      FND_PROFILE.Get('CONC_REQUEST_ID', l_req_id);
      IF L_REVISION_COUNT = 0 THEN
        L_FROM           := 'Workflow_Mailer@haemonetics.com';
        L_RECIPIENT      := NULL; --'MBerrada@haemonetics.com';--MBerrada@haemonetics.com
        L_SUBJECT        := l_org_name||': Order Number '||L_ORDER_NUMBER ||' is not reserved automatically';
        L_BODY           := ' The full Order is not reserved for Line No :'||l_line_number || ', For item :' ||l_ordered_item ||' automatically , Please place booking hold on order manually.';
        L_BODY           :=l_body||' Please check Request id : '|| l_req_id||' for exceptions.';
        SEND_MAIL(L_FROM,L_RECIPIENT,L_SUBJECT,L_BODY, l_org_id1);
      END IF;
    END;
  END LOOP;
  IF L_DEBUG_LEVEL > 0 THEN
    OE_DEBUG_PUB.ADD( ' BEFORE CALLING THE COMMIT_RESERVATION' , 1 ) ;
    FND_FILE.PUT_LINE(FND_FILE.LOG,' BEFORE CALLING THE COMMIT_RESERVATION');
  END IF;
  Commit_Reservation(p_request_id => l_request_id ,x_return_status => l_return_status);
  IF L_DEBUG_LEVEL > 0 THEN
    oe_debug_pub.add( ' AFTER CALLING THE COMMIT_RESERVATION  ', 1 ) ;
    FND_FILE.PUT_LINE(FND_FILE.LOG,' AFTER CALLING THE COMMIT_RESERVATION  ');
  END IF;
  --Pack J
  OE_MSG_PUB.Save_Messages(p_request_id => l_request_id);
  COMMIT;
  -- For Expected errors we will consider status as success.
  IF l_return_status = FND_API.G_RET_STS_ERROR THEN
    l_return_status := FND_API.G_RET_STS_SUCCESS;
  END IF;
  x_return_status := l_return_status;
  IF l_debug_level > 0 THEN
    OE_DEBUG_PUB.ADD('Exiting XXHEMO_RESERVE_CONC.Create_reservation for rsv_tbl',1);
    FND_FILE.PUT_LINE(FND_FILE.LOG,'Exiting XXHEMO_RESERVE_CONC.Create_reservation for rsv_tbl');
  END IF;
  -- SELECT COUNT(*) FROM MTL_RESERVATIONS WHERE ORIG_DEMAND_SOURCE_LINE_ID = 5559552;
EXCEPTION
WHEN FND_API.G_EXC_ERROR THEN
  IF L_DEBUG_LEVEL > 0 THEN
    FND_FILE.PUT_LINE(FND_FILE.LOG,'In Expected Error...in Proc Create_Reservation for rsv_tbl');
    OE_DEBUG_PUB.Add('In Expected Error...in Proc Create_Reservation for rsv_tbl',1);
  END IF;
  x_return_status := FND_API.G_RET_STS_ERROR;
WHEN FND_API.G_EXC_UNEXPECTED_ERROR THEN
  IF L_DEBUG_LEVEL > 0 THEN
    FND_FILE.PUT_LINE(FND_FILE.LOG,'In Unexpected Error...in Proc Create_Reservation for rsv tbl');
    OE_DEBUG_PUB.Add('In Unexpected Error...in Proc Create_Reservation for rsv tbl',1 );
  END IF;
  x_return_status := FND_API.G_RET_STS_UNEXP_ERROR;
WHEN OTHERS THEN
  IF L_DEBUG_LEVEL > 0 THEN
    FND_FILE.PUT_LINE(FND_FILE.LOG,'In others error...in Proc Create_Reservation for rsv tbl');
    OE_DEBUG_PUB.Add('In others error...in Proc Create_Reservation for rsv tbl',1);
  END IF;
  X_RETURN_STATUS := FND_API.G_RET_STS_UNEXP_ERROR;
  FND_FILE.PUT_LINE(FND_FILE.LOG,'<<<< END CREATE RESERVATIONS >>>>');
END create_reservation;
/*----------------------------------------------------------------
PROCEDURE  : Prepare_And_Reserve
DESCRIPTION: This Procedure will call procedures calculate_percentage,
Derive_reservation_qty and create_reservation based on
reservation mode and reservation run type.
-----------------------------------------------------------------*/
PROCEDURE Prepare_And_Reserve(
    p_rsv_tbl IN OUT NOCOPY
    /* file.sql.39 change */
    XXHEMO_RESERVE_CONC.Rsv_Tbl_Type,
    p_percent          IN NUMBER DEFAULT NULL,
    p_reservation_mode IN VARCHAR2,
    p_reserve_run_type IN VARCHAR2,
    p_reserve_set_name IN VARCHAR2 DEFAULT NULL)
IS
  l_percent       NUMBER;
  l_return_status VARCHAR2(1);
  l_request_id    NUMBER;
  l_primary_uom   VARCHAR2(3) := NULL; -- 4695715
  --
  l_debug_level CONSTANT NUMBER := oe_debug_pub.g_debug_level;
  --
BEGIN
  L_PERCENT := P_PERCENT;
  -- G_ORDERED_QUANTITY   := p_rsv_tbl(1).ORDERED_QUANTITY; ---AppsAssociates
  --fnd_file.putline(fnd_file.log,'G_ordered_quantity :'||G_ordered_quantity); -----AppsAssociates
  IF p_reservation_mode = 'FAIR' THEN
    calculate_percentage( p_inventory_item_id => p_rsv_tbl(1).inventory_item_id, p_ship_from_org_id => p_rsv_tbl(1).ship_from_org_id, p_subinventory => p_rsv_tbl(1).subinventory , p_rsv_tbl => p_rsv_tbl , x_percentage => l_percent , x_primary_uom => l_primary_uom --4695715
    );
  END IF; -- 'FAIR'
  IF p_reservation_mode = 'FAIR' OR p_reservation_mode = 'PERCENT' THEN
    Derive_reservation_qty( p_x_rsv_tbl => p_rsv_tbl, p_percentage => l_percent, p_reservation_mode => p_reservation_mode, p_primary_uom => l_primary_uom --4695715
    );
    --END IF;
  ELSIF P_RESERVATION_MODE = 'PARTIAL_ONLY_UNRESERVED' OR P_RESERVATION_MODE = 'PARTIAL' THEN -- Pack J
    FND_FILE.PUT_LINE(FND_FILE.LOG,'P_RESERVATION_MODE = PARTIAL_ONLY_UNRESERVED OR PARTIAL');
    CALCULATE_PARTIAL_QUANTITY(P_X_RSV_TBL => P_RSV_TBL, P_RESERVATION_MODE => P_RESERVATION_MODE, X_RETURN_STATUS => L_RETURN_STATUS);
    FND_FILE.PUT_LINE(FND_FILE.LOG,'After calling CALCULATE_PARTIAL_QUANTITY');
    --5034236
  ELSE -- Mode is not supplied
    FND_FILE.PUT_LINE(FND_FILE.LOG,'before4 Derive_reservation_qty');
    Derive_reservation_qty( p_x_rsv_tbl => p_rsv_tbl, p_percentage => 100, p_reservation_mode => 'PERCENT', p_primary_uom => l_primary_uom );
  END IF;
  IF l_debug_level > 0 THEN
    OE_DEBUG_PUB.Add('Going to call XXHEMO_RESERVE_CONC_HOOK.Qty_Per_Business_Rule ',1);
  END IF;
  XXHEMO_RESERVE_CONC_HOOK.Qty_Per_Business_Rule(p_x_rsv_tbl => p_rsv_tbl);
  IF l_debug_level > 0 THEN
    OE_DEBUG_PUB.Add('After calling XXHEMO_RESERVE_CONC_HOOK.Qty_Per_Business_Rule ',1);
  END IF;
  IF p_reserve_run_type = 'RESERVE' OR p_reserve_run_type IS NULL THEN
    --XXHEMO_RESERVE_CONC_HOOK.Qty_Per_Business_Rule(p_x_rsv_tbl => p_rsv_tbl);
    create_reservation(p_x_rsv_tbl => p_rsv_tbl ,x_return_status => l_return_status);
    IF l_return_status = FND_API.G_RET_STS_SUCCESS AND p_reserve_set_name IS NOT NULL THEN -- Pack J
      FND_PROFILE.Get('CONC_REQUEST_ID', l_request_id);
      Create_Reservation_Set(p_rsv_tbl => p_rsv_tbl, p_reserve_set_name => p_reserve_set_name, p_rsv_request_id => l_request_id, x_return_status => l_return_status);
    END IF;
    IF l_return_status = FND_API.G_RET_STS_ERROR THEN
      IF l_debug_level > 0 THEN
        OE_DEBUG_PUB.Add('Create Reservation returned with Expected error for rsv tbl ',1);
      END IF;
    ELSIF l_return_status = FND_API.G_RET_STS_UNEXP_ERROR THEN
      IF l_debug_level    > 0 THEN
        OE_DEBUG_PUB.Add('Create Reservation returned with Unexpected error for rsv tbl',1);
      END IF;
    END IF;
  ELSIF p_reserve_run_type = 'SIMULATE TO EXTERNAL TABLE' THEN
    IF l_debug_level       > 0 THEN
      OE_DEBUG_PUB.Add('Going to call XXHEMO_RESERVE_CONC_HOOK.Simulated_Results ',1);
    END IF;
    XXHEMO_RESERVE_CONC_HOOK.Simulated_Results(p_x_rsv_tbl => p_rsv_tbl);
    IF l_debug_level > 0 THEN
      OE_DEBUG_PUB.Add('After calling XXHEMO_RESERVE_CONC_HOOK.Simulated_Results ',1);
    END IF;
  ELSIF p_reserve_run_type = 'SIMULATE' THEN -- Pack J
    FND_PROFILE.Get('CONC_REQUEST_ID', l_request_id);
    Create_Reservation_set(p_rsv_tbl => p_rsv_tbl, p_reserve_set_name=> p_reserve_set_name, p_simulation_request_id => l_request_id, x_return_status => l_return_status);
  END IF;
END Prepare_And_Reserve;
/*----------------------------------------------------------------
PROCEDURE  : Reserve_Eligible
DESCRIPTION: This Procedure is to check if the Line that is being
considered needs Reservation
----------------------------------------------------------------*/
PROCEDURE Reserve_Eligible(
    p_line_rec                   IN OE_ORDER_PUB.line_rec_type,
    p_use_reservation_time_fence IN VARCHAR2,
    x_return_status OUT NOCOPY
    /* file.sql.39 change */
    VARCHAR2 )
IS
  l_return_status         VARCHAR2(1) := FND_API.G_RET_STS_SUCCESS;
  l_result                VARCHAR2(30);
  l_scheduling_level_code VARCHAR2(30) := NULL;
  l_out_return_status     VARCHAR2(1)  := FND_API.G_RET_STS_SUCCESS;
  l_type_code             VARCHAR2(30);
  l_org_id                NUMBER;
  l_time_fence            BOOLEAN;
  l_msg_count             NUMBER;
  l_msg_data              VARCHAR2(1000);
  l_dummy                 VARCHAR2(100);
  --
  l_debug_level CONSTANT NUMBER := 1;--oe_debug_pub.g_debug_level;
  --
BEGIN
  FND_FILE.PUT_LINE(FND_FILE.LOG, 'Inside Reserve Eligible Procedure start');
  FND_FILE.Put_Line(FND_FILE.LOG, 'debug level :'||l_debug_level);
  IF l_debug_level > 0 THEN
    OE_DEBUG_PUB.ADD('Inside Reserve Eligible Procedure',1);
    FND_FILE.Put_Line(FND_FILE.LOG,'Inside Reserve Eligible Procedure');
  END IF;
  /* Check if line is open, if not open ignore the line */
  IF ( p_line_rec.open_flag = 'N' ) THEN
    IF l_debug_level        > 0 THEN
      OE_DEBUG_PUB.ADD('Line is closed, not eligible for reservation', 1);
      FND_FILE.Put_Line(FND_FILE.LOG, 'Line is closed, not eligible for reservation');
    END IF;
    l_return_status := FND_API.G_RET_STS_ERROR;
    /* Check if line is shipped, if shipped then ignore the line */
  ELSIF ( NVL(p_line_rec.shipped_quantity, -99) > 0 ) THEN
    IF L_DEBUG_LEVEL                            > 0 THEN
      OE_DEBUG_PUB.Add('Line is shipped, not eligible for reservation', 1);
      FND_FILE.Put_Line(FND_FILE.LOG,'Line is shipped, not eligible for reservation');
    END IF;
    L_RETURN_STATUS := FND_API.G_RET_STS_ERROR;
    --Added for bug a6873122
  ELSIF ( NVL(p_line_rec.fulfilled_quantity, -99) > 0 ) THEN
    IF l_debug_level                              > 0 THEN
      OE_DEBUG_PUB.ADD('Line is Fulfilled, not eligible for reservation', 1);
      FND_FILE.Put_Line(FND_FILE.LOG,'Line is Fulfilled, not eligible for reservation');
    END IF;
    l_return_status := FND_API.G_RET_STS_ERROR;
    --Added for bug 6873122
  END IF;
  IF l_return_status = FND_API.G_RET_STS_SUCCESS AND NVL(g_reservation_mode,'*') <> 'PARTIAL' THEN -- Pack J
    /* We need to check for Existing Reservations on the Line */
    BEGIN
      IF l_debug_level > 0 THEN
        OE_DEBUG_PUB.ADD('Before checking Existing Reservations',1);
        FND_FILE.Put_Line(FND_FILE.LOG,'Before checking Existing Reservations');
      END IF;
      SELECT 'Reservation Exists'
      INTO l_dummy
      FROM MTL_RESERVATIONS
      WHERE DEMAND_SOURCE_LINE_ID = p_line_rec.line_id;
      IF l_debug_level            > 0 THEN
        OE_DEBUG_PUB.ADD('Reservations exists on the line',3);
        FND_FILE.Put_Line(FND_FILE.LOG,'Reservations exists on the line');
      END IF;
      RAISE FND_API.G_EXC_ERROR;
    EXCEPTION
    WHEN FND_API.G_EXC_ERROR THEN
      IF l_debug_level > 0 THEN
        OE_DEBUG_PUB.ADD('In Expected Error for Check Reservation',3);
        FND_FILE.Put_Line(FND_FILE.LOG,'In Expected Error for Check Reservation');
      END IF;
      l_return_status := FND_API.G_RET_STS_ERROR;
    WHEN NO_DATA_FOUND THEN
      NULL;
    WHEN TOO_MANY_ROWS THEN
      -- NULL;
      l_return_status := FND_API.G_RET_STS_ERROR; --2929716
    END;
  END IF;
  -- 3250889 Starts
  IF l_return_status = FND_API.G_RET_STS_SUCCESS THEN
    BEGIN
      IF l_debug_level > 0 THEN
        OE_DEBUG_PUB.ADD('Before checking for Staged/Closed deliveries', 1);
        FND_FILE.Put_Line(FND_FILE.LOG,'Before checking for Staged/Closed deliveries');
      END IF;
      SELECT 'Staging Exists'
      INTO l_dummy
      FROM WSH_DELIVERY_DETAILS
      WHERE SOURCE_LINE_ID = p_line_rec.line_id
      AND SOURCE_CODE      = 'OE' -- Added for bug 3286756
      AND RELEASED_STATUS IN ('Y', 'C');
      IF l_debug_level     > 0 THEN
        OE_DEBUG_PUB.ADD('Staged/Closed deliveries exist for the line', 3);
        FND_FILE.Put_Line(FND_FILE.LOG,'Staged/Closed deliveries exist for the line');
      END IF;
      RAISE FND_API.G_EXC_ERROR;
    EXCEPTION
    WHEN FND_API.G_EXC_ERROR THEN
      IF l_debug_level > 0 THEN
        OE_DEBUG_PUB.ADD('In Expected Error for Checking Staged/Closed deliveries', 3);
        FND_FILE.Put_Line(FND_FILE.LOG,'In Expected Error for Checking Staged/Closed deliveries');
      END IF;
      l_return_status := FND_API.G_RET_STS_ERROR;
    WHEN NO_DATA_FOUND THEN
      NULL;
    WHEN TOO_MANY_ROWS THEN
      l_return_status := FND_API.G_RET_STS_ERROR;
    END;
  END IF;
  -- 3250889 Ends
  IF l_return_status = FND_API.G_RET_STS_SUCCESS THEN
    -- WE NEED TO CHECK FOR THE reservation_time_fence Value.
    -- If the Value of the parameter passed to the concurrent
    -- program is "NO' then we reserve the lines irrespective
    -- of the profile option: OM : Reservation_Time_fence.
    -- By default this parameter will have a value of YES.
    IF (NVL(p_use_reservation_time_fence,'Y') = 'Y' OR NVL(p_use_reservation_time_fence,'Yes') = 'Yes') THEN
      IF l_debug_level                        > 0 THEN
        OE_DEBUG_PUB.Add('Schedule Ship Date:'|| p_line_rec.schedule_ship_date,3);
      END IF;
      -- Scheduling restructure
      /*    IF NVL(FND_PROFILE.VALUE('ONT_BRANCH_SCHEDULING'),'N') = 'N' THEN
      -- 4689197
      IF NOT OE_ORDER_SCH_UTIL.Within_Rsv_Time_Fence
      (p_line_rec.schedule_ship_date, p_line_rec.org_id) THEN
      IF l_debug_level  > 0 THEN
      OE_DEBUG_PUB.Add('The Schedule Date for Line falls
      beyond reservation Time Fence',3);
      END IF;
      RAISE FND_API.G_EXC_ERROR ;
      END IF;
      ELSE */
      -- 4689197
      IF NOT OE_SCHEDULE_UTIL.Within_Rsv_Time_Fence (p_line_rec.schedule_ship_date, p_line_rec.org_id) THEN
        IF l_debug_level > 0 THEN
          OE_DEBUG_PUB.Add('The Schedule Date for Line falls                          
beyond reservation Time Fence',3);
          FND_FILE.Put_Line(FND_FILE.LOG,'The Schedule Date for Line falls beyond reservation Time Fence');
        END IF;
        RAISE FND_API.G_EXC_ERROR ;
      END IF;
    END IF;
    --    END IF;
    -- We need to check if the Line Type for the Line allows
    -- us to reserve the Line or not.
    IF l_debug_level > 0 THEN
      OE_DEBUG_PUB.ADD('Checking Scheduling Level...',3);
      FND_FILE.Put_Line(FND_FILE.LOG,'Checking Scheduling Level...');
    END IF;
    -- Scheduling restructure
    /* Bug: 4504362
    IF NVL(FND_PROFILE.VALUE('ONT_BRANCH_SCHEDULING'),'N') = 'N' THEN
    l_scheduling_level_code := OE_ORDER_SCH_UTIL.Get_Scheduling_Level
    (p_line_rec.header_id
    ,p_line_rec.line_type_id);
    ELSE
    */
    l_scheduling_level_code := OE_SCHEDULE_UTIL.Get_Scheduling_Level (p_line_rec.header_id ,p_line_rec.line_type_id);
    --END IF;
    IF l_debug_level > 0 THEN
      OE_DEBUG_PUB.ADD('l_scheduling_level_code:'||L_SCHEDULING_LEVEL_CODE,1);
      FND_FILE.Put_Line(FND_FILE.LOG,'l_scheduling_level_code:'||L_SCHEDULING_LEVEL_CODE);
    END IF;
    IF l_scheduling_level_code          IS NOT NULL AND (l_scheduling_level_code = SCH_LEVEL_ONE OR l_scheduling_level_code = SCH_LEVEL_TWO OR l_scheduling_level_code = SCH_LEVEL_FIVE) THEN
      IF p_line_rec.schedule_action_code = OESCH_ACT_RESERVE OR (p_line_rec.schedule_status_code IS NULL AND (p_line_rec.schedule_ship_date IS NOT NULL OR p_line_rec.schedule_arrival_date IS NOT NULL)) THEN
        IF l_debug_level                 > 0 THEN
          OE_DEBUG_PUB.ADD('Order Type Does not Allow Scheduling',3);
          FND_FILE.Put_Line(FND_FILE.LOG,'Order Type Does not Allow Scheduling');
        END IF;
        RAISE FND_API.G_EXC_ERROR;
      END IF;
    END IF;
  END IF; -- Check for Reservation Exists Clause
  x_return_status := l_return_status;
  IF l_debug_level > 0 THEN
    OE_DEBUG_PUB.ADD('..Exiting XXHEMO_RESERVE_CONC.Need_Reservation' || L_RETURN_STATUS ,1);
    FND_FILE.Put_Line(FND_FILE.LOG,'..Exiting XXHEMO_RESERVE_CONC.Need_Reservation');
  END IF;
EXCEPTION
WHEN FND_API.G_EXC_ERROR THEN
  IF l_debug_level > 0 THEN
    OE_DEBUG_PUB.ADD('In Expected Error...in Proc Reserve_Eligible',3);
    FND_FILE.Put_Line(FND_FILE.LOG,'In Expected Error...in Proc Reserve_Eligible');
  END IF;
  x_return_status := FND_API.G_RET_STS_ERROR;
WHEN FND_API.G_EXC_UNEXPECTED_ERROR THEN
  IF l_debug_level > 0 THEN
    OE_DEBUG_PUB.ADD('In UnExpected Error...in Proc Reserve_Eligible',3);
    FND_FILE.Put_Line(FND_FILE.LOG,'In UnExpected Error...in Proc Reserve_Eligible');
  END IF;
  x_return_status := FND_API.G_RET_STS_UNEXP_ERROR;
WHEN OTHERS THEN
  x_return_status := FND_API.G_RET_STS_UNEXP_ERROR;
  IF OE_MSG_PUB.Check_Msg_Level(OE_MSG_PUB.G_MSG_LVL_UNEXP_ERROR) THEN
    OE_MSG_PUB.ADD_EXC_MSG ( G_PKG_NAME , 'Action_Reserve' );
    FND_FILE.Put_Line(FND_FILE.LOG,'Action_Reserve');
  END IF;
  FND_FILE.Put_Line(FND_FILE.LOG,'Reserve_Eligible End');
END Reserve_Eligible;
/*----------------------------------------------------------------
PROCEDURE  : Create_Reservation
DESCRIPTION: This Procedure send the line to the Inventory for
Reservation
-----------------------------------------------------------------*/
PROCEDURE Create_Reservation(
    p_line_rec IN OE_ORDER_PUB.line_rec_type,
    x_return_status OUT NOCOPY
    /* file.sql.39 change */
    VARCHAR2)
IS
  l_return_status VARCHAR2(1) := FND_API.G_RET_STS_SUCCESS;
  l_reservation_rec Inv_Reservation_Global.Mtl_Reservation_Rec_Type;
  l_msg_count NUMBER;
  l_dummy_sn Inv_Reservation_Global.Serial_Number_Tbl_Type;
  l_msg_data             VARCHAR2(1000);
  l_buffer               VARCHAR2(1000);
  l_quantity_reserved    NUMBER;
  l_quantity_to_reserve  NUMBER;
  l_rsv_id               NUMBER;
  l_quantity2_reserved   NUMBER; -- INVCONV
  l_quantity2_to_reserve NUMBER; -- INVCONV
  --
  l_debug_level CONSTANT NUMBER := oe_debug_pub.g_debug_level;
  --
BEGIN
  IF l_debug_level > 0 THEN
    OE_Debug_pub.Add('In the Procedure Create Reservation',1);
    OE_Debug_pub.Add('Before call of Load_INV_Request',1);
  END IF;
  IF p_line_rec.ordered_quantity2 = 0 -- INVCONV
    THEN
    l_quantity2_to_reserve := NULL;
  END IF;
  -- Added for Scheduling Restructring
  /* Bug: 4504362
  IF NVL(FND_PROFILE.VALUE('ONT_BRANCH_SCHEDULING'),'N') = 'N' THEN
  OE_ORDER_SCH_UTIL.Load_Inv_Request
  ( p_line_rec              => p_line_rec
  , p_quantity_to_reserve   => p_line_rec.ordered_quantity
  , p_quantity2_to_reserve   => l_quantity2_to_reserve -- INVCONV
  , x_reservation_rec       => l_reservation_rec);
  ELSE
  */
  OE_SCHEDULE_UTIL.Load_Inv_Request ( p_line_rec => p_line_rec , p_quantity_to_reserve => p_line_rec.ordered_quantity , p_quantity2_to_reserve => l_quantity2_to_reserve -- INVCONV
  , x_reservation_rec => l_reservation_rec);
  --END IF;
  -- Call INV with action = RESERVE
  IF l_debug_level > 0 THEN
    OE_DEBUG_PUB.Add('Before call of inv_reservation_pub.create_reservation',1);
  END IF;
  INV_RESERVATION_PUB.Create_Reservation ( p_api_version_number => 1.0 , p_init_msg_lst => FND_API.G_TRUE , x_return_status => l_return_status , x_msg_count => l_msg_count , x_msg_data => l_msg_data , p_rsv_rec => l_reservation_rec , p_serial_number => l_dummy_sn , x_serial_number => l_dummy_sn , p_partial_reservation_flag => FND_API.G_FALSE , p_force_reservation_flag => FND_API.G_FALSE , p_validation_flag => FND_API.G_TRUE , x_quantity_reserved => l_quantity_reserved , x_secondary_quantity_reserved => l_quantity2_reserved -- INVCONV
  , x_reservation_id => l_rsv_id );
  IF l_debug_level > 0 THEN
    OE_DEBUG_PUB.Add('1. After Calling Create Reservation' || l_return_status,1);
    OE_DEBUG_PUB.Add(l_msg_data,1);
  END IF;
  IF l_return_status = FND_API.G_RET_STS_UNEXP_ERROR THEN
    IF l_debug_level > 0 THEN
      OE_DEBUG_PUB.Add('Raising Unexpected error',1);
    END IF;
    RAISE FND_API.G_EXC_UNEXPECTED_ERROR;
  ELSIF l_return_status = FND_API.G_RET_STS_ERROR THEN
    IF l_debug_level    > 0 THEN
      OE_DEBUG_PUB.Add('Raising Expected error',1);
    END IF;
    IF l_msg_data IS NOT NULL THEN
      fnd_message.set_encoded(l_msg_data);
      l_buffer := fnd_message.get;
      OE_MSG_PUB.Add_text(p_message_text => l_buffer);
      IF l_debug_level > 0 THEN
        OE_DEBUG_PUB.Add(l_msg_data,1);
      END IF;
    END IF;
    RAISE FND_API.G_EXC_ERROR;
  END IF;
  IF l_debug_level > 0 THEN
    OE_DEBUG_PUB.Add('..Exiting XXHEMO_RESERVE_CONC.Create_reservation' || l_return_status ,1);
  END IF;
  x_return_status := FND_API.G_RET_STS_SUCCESS;
EXCEPTION
WHEN FND_API.G_EXC_ERROR THEN
  IF l_debug_level > 0 THEN
    OE_DEBUG_PUB.Add('In Expected Error...in Proc Create_Reservation',1);
  END IF;
  x_return_status := FND_API.G_RET_STS_ERROR;
WHEN FND_API.G_EXC_UNEXPECTED_ERROR THEN
  IF l_debug_level > 0 THEN
    OE_DEBUG_PUB.Add('In Unexpected Error...in Proc Create_Reservation');
  END IF;
  x_return_status := FND_API.G_RET_STS_UNEXP_ERROR;
WHEN OTHERS THEN
  IF l_debug_level > 0 THEN
    OE_DEBUG_PUB.Add('In others error...in Proc Create_Reservation');
  END IF;
  x_return_status := FND_API.G_RET_STS_UNEXP_ERROR;
END;
/*----------------------------------------------------------------
PROCEDURE  : Reserve
DESCRIPTION: Reserve Scheduled Orders Concurrent Request
-----------------------------------------------------------------*/
PROCEDURE Reserve(
    ERRBUF OUT NOCOPY
    /* file.sql.39 change */
    VARCHAR2,
    RETCODE OUT NOCOPY
    /* file.sql.39 change */
    VARCHAR2,
    /* Moac */
    p_org_id                     IN NUMBER,
    p_use_reservation_time_fence IN CHAR,
    p_order_number_low           IN NUMBER,
    p_order_number_high          IN NUMBER,
    p_customer_id                IN VARCHAR2,
    p_order_type                 IN VARCHAR2,
    p_line_type_id               IN VARCHAR2,
    p_warehouse                  IN VARCHAR2,
    p_inventory_item_id          IN VARCHAR2,
    p_request_date_low           IN VARCHAR2,
    p_request_date_high          IN VARCHAR2,
    p_schedule_ship_date_low     IN VARCHAR2,
    p_schedule_ship_date_high    IN VARCHAR2,
    p_schedule_arrival_date_low  IN VARCHAR2,
    p_schedule_arrival_date_high IN VARCHAR2,
    p_ordered_date_low           IN VARCHAR2,
    p_ordered_date_high          IN VARCHAR2,
    p_demand_class_code          IN VARCHAR2,
    p_planning_priority          IN NUMBER,
    p_booked                     IN VARCHAR2 DEFAULT NULL,
    p_reservation_mode           IN VARCHAR2 DEFAULT NULL,
    p_dummy1                     IN VARCHAR2 DEFAULT NULL,
    p_dummy2                     IN VARCHAR2 DEFAULT NULL,
    p_percent                    IN NUMBER DEFAULT NULL,
    p_shipment_priority          IN VARCHAR2 DEFAULT NULL,
    p_reserve_run_type           IN VARCHAR2 DEFAULT NULL,
    p_reserve_set_name           IN VARCHAR2 DEFAULT NULL,
    p_override_set               IN VARCHAR2 DEFAULT NULL,
    p_order_by                   IN VARCHAR2,
    p_selected_ids               IN VARCHAR2 DEFAULT NULL,
    p_dummy3                     IN VARCHAR2 DEFAULT NULL,
    p_partial_preference         IN VARCHAR2 DEFAULT 'N' )
IS
  l_stmt VARCHAR2(4000) :=NULL;
  l_line_rec OE_ORDER_PUB.line_rec_type;
  l_return_status              VARCHAR2(1) := FND_API.G_RET_STS_SUCCESS;
  l_request_date_low           DATE;
  l_request_date_high          DATE;
  l_schedule_ship_date_low     DATE;
  l_schedule_ship_date_high    DATE;
  l_schedule_arrival_date_low  DATE;
  l_schedule_arrival_date_high DATE;
  l_ordered_date_low           DATE;
  l_ordered_date_high          DATE;
  l_line_id                    NUMBER;
  l_rsv_tbl Rsv_Tbl_Type;
  l_temp_rsv_tbl Rsv_Tbl_Type;
  l_temp_par_rsv_tbl Rsv_Tbl_Type;
  l_percent          NUMBER;
  l_old_warehouse    NUMBER;
  l_old_subinventory VARCHAR2(10);
  l_old_item_id      NUMBER;
  l_index            NUMBER :=0;
  l_cursor_id        INTEGER;
  l_retval           INTEGER;
  l_set_id           NUMBER :=0;
  l_process_flag     VARCHAR2(1);
  --3710133
  l_request_id         NUMBER;
  l_msg_data           VARCHAR2(2000);
  l_sales_order_id     NUMBER;
  l_reserved_quantity  NUMBER;
  l_reserved_quantity2 NUMBER;
  CURSOR get_reservation_set
  IS
    SELECT reservation_set_id
    FROM oe_reservation_sets
    WHERE reservation_set_name = p_reserve_set_name;
  CURSOR rsv_process_flag
  IS
    SELECT process_flag
    FROM oe_reservation_sets
    WHERE reservation_set_name = p_reserve_set_name;
  --
  l_debug_level CONSTANT NUMBER := oe_debug_pub.g_debug_level;
  --
  -- Moac
  l_single_org    BOOLEAN := FALSE;
  l_old_org_id    NUMBER  := -99;
  l_org_id        NUMBER;
  l_user_set_id   NUMBER :=0;
  l_created_by    NUMBER;
  l_order_number1 VARCHAR2(40);
  l_line_number   NUMBER;
  l_ordered_item  VARCHAR2(100);
  l_org_name1 varchar2(100);
  l_ord_by        VARCHAR2(50) :=' '; --10241113
  l_org_id1 number;
BEGIN
  --Bug #4220950
  ERRBUF  := 'Reserve Schedule Orders Request completed successfully';
  RETCODE := 0;
  --3710133
  FND_PROFILE.Get('CONC_REQUEST_ID', l_request_id);
  -- MOAC Start
  BEGIN
    IF p_reserve_set_name IS NOT NULL THEN
      SELECT created_by
      INTO l_created_by
      FROM OE_RESERVATION_SETS
      WHERE reservation_set_name = p_reserve_set_name;
      --AND CREATED_BY = FND_GLOBAL.USER_ID ;
      IF l_created_by <> FND_GLOBAL.USER_ID THEN
        Fnd_Message.set_name('ONT', 'ONT_RSV_SET_NOT_CREATED_BY_USR');
        Fnd_Message.Set_Token('SET_NAME', p_reserve_set_name );
        Oe_Msg_Pub.Add;
        OE_MSG_PUB.Save_Messages(p_request_id => l_request_id);
        l_msg_data := Fnd_Message.get_string('ONT', 'ONT_RSV_SET_NOT_CREATED_BY_USR');
        FND_FILE.Put_Line(FND_FILE.LOG, l_msg_data);
        ERRBUF          := l_msg_data;
        RETCODE         := 2;
        IF l_debug_level > 0 THEN
          OE_DEBUG_PUB.Add('Error : Reservation set is not created by the current user',1);
        END IF;
        GOTO END_OF_PROCESS;
      END IF;
      /*
      IF l_user_set_id IS NULL THEN
      OE_DEBUG_PUB.Add('Error: user_set_id is null',1);
      END IF;
      */
    END IF;
  EXCEPTION
  WHEN NO_DATA_FOUND THEN
    NULL;
    /*
    Fnd_Message.set_name('ONT', 'ONT_RSV_SET_NOT_CREATED_BY_USR');
    Oe_Msg_Pub.Add;
    OE_MSG_PUB.Save_Messages(p_request_id => l_request_id);
    l_msg_data := Fnd_Message.get_string('ONT', 'ONT_RSV_SET_NOT_CREATED_BY_USR');
    FND_FILE.Put_Line(FND_FILE.LOG, l_msg_data);
    ERRBUF := l_msg_data;
    RETCODE := 2;
    IF l_debug_level  > 0 THEN
    OE_DEBUG_PUB.Add('Error : Reservation set is not created by the current user',1);
    END IF;
    GOTO END_OF_PROCESS;
    */
  WHEN OTHERS THEN
    NULL;
  END ;
  -- MOAC End
  -- validating reservation mode
  /* Commented to allow 'FAIR' mode for multiple items
  IF p_reservation_mode = 'FAIR'
  AND p_inventory_item_id IS NULL
  THEN
  IF l_debug_level  > 0 THEN
  OE_DEBUG_PUB.Add('Error : Item not supplied ',1);
  END IF;
  FND_FILE.Put_Line(FND_FILE.LOG, ' Concurrent request failed - item not supplied');
  ERRBUF := ' Concurrent request failed - item not supplied';
  RETCODE := 2;
  goto END_OF_PROCESS;
  */
  -- Pack J
  IF p_reservation_mode = 'PERCENT' THEN
    --code change for bug 3738107
    IF p_percent IS NULL THEN
      Fnd_Message.set_name('ONT', 'ONT_RSV_PCT_NULL');
      Oe_Msg_Pub.Add;
      OE_MSG_PUB.Save_Messages(p_request_id => l_request_id);
      l_msg_data := Fnd_Message.get_string('ONT', 'ONT_RSV_PCT_NULL');
      FND_FILE.Put_Line(FND_FILE.LOG, l_msg_data);
      ERRBUF          := 'ONT_RSV_PCT_NULL';
      RETCODE         := 2;
      IF l_debug_level > 0 THEN
        OE_DEBUG_PUB.Add('Error : Percentage is null ',1);
      END IF;
      GOTO END_OF_PROCESS;
    ELSIF p_percent > 100 OR p_percent < 1 THEN
      Fnd_Message.set_name('ONT', 'ONT_RSV_PCT_INVALID');
      Oe_Msg_Pub.Add;
      OE_MSG_PUB.Save_Messages(p_request_id => l_request_id);
      l_msg_data := Fnd_Message.get_string('ONT', 'ONT_RSV_PCT_INVALID');
      FND_FILE.Put_Line(FND_FILE.LOG, l_msg_data);
      ERRBUF          := 'ONT_RSV_PCT_INVALID';
      RETCODE         := 2;
      IF l_debug_level > 0 THEN
        OE_DEBUG_PUB.Add('Error : Percentage is lesser than 1 or greater than 100 ',1);
      END IF;
      GOTO END_OF_PROCESS;
    END IF;
  ELSIF (p_reserve_run_type = 'SIMULATE' OR p_reserve_run_type = 'CREATE_RESERVATION') AND p_reserve_set_name IS NULL THEN -- Pack J
    -- code change for bug 3738107
    Fnd_Message.set_name('ONT', 'ONT_RSV_SET_NOT_PROVIDED');
    Oe_Msg_Pub.Add;
    OE_MSG_PUB.Save_Messages(p_request_id => l_request_id);
    l_msg_data := Fnd_Message.get_string('ONT', 'ONT_RSV_SET_NOT_PROVIDED');
    FND_FILE.Put_Line(FND_FILE.LOG, l_msg_data);
    ERRBUF          := 'ONT_RSV_SET_NOT_PROVIDED';
    RETCODE         := 2;
    IF l_debug_level > 0 THEN
      OE_DEBUG_PUB.Add('Error : Reservation Set Name is not provided ',1);
    END IF;
    GOTO END_OF_PROCESS;
  ELSIF p_reserve_set_name IS NOT NULL AND NVL(p_override_set,'N') = 'N' AND p_reserve_run_type <> 'CREATE_RESERVATION' THEN -- Pack J
    OPEN get_reservation_set;
    FETCH get_reservation_set INTO l_set_id;
    CLOSE get_reservation_set;
    IF l_set_id > 0 THEN
      -- code change for 3738107
      Fnd_Message.set_name('ONT', 'ONT_RSV_SET_EXISTS');
      Oe_Msg_Pub.Add;
      OE_MSG_PUB.Save_Messages(p_request_id => l_request_id);
      l_msg_data := Fnd_Message.get_string('ONT', 'ONT_RSV_SET_EXISTS');
      FND_FILE.Put_Line(FND_FILE.LOG, l_msg_data);
      ERRBUF          := 'ONT_RSV_SET_EXISTS';
      RETCODE         := 2;
      IF l_debug_level > 0 THEN
        OE_DEBUG_PUB.Add('Error : Reservation Set Name exists ',1);
      END IF;
      GOTO END_OF_PROCESS;
    END IF;
  ELSIF p_reserve_set_name IS NOT NULL THEN -- Pack J  --- p_reserve_run_type = 'CREATE_RESERVATION'
    OPEN rsv_process_flag;
    FETCH rsv_process_flag INTO l_process_flag;
    CLOSE rsv_process_flag;
    IF l_process_flag  = 'Y' THEN
      IF l_debug_level > 0 THEN
        OE_DEBUG_PUB.Add('Error : Reservation Set already processed ',1);
      END IF;
      FND_FILE.Put_Line(FND_FILE.LOG, ' Concurrent request failed - Reserevation Set already processed');
      ERRBUF  := ' Concurrent request failed -  Reserevation Set already processed';
      RETCODE := 2;
      GOTO END_OF_PROCESS;
    END IF;
  END IF;
  IF p_reservation_mode = 'FAIR' AND p_percent IS NOT NULL THEN
    IF l_debug_level    > 0 THEN
      OE_DEBUG_PUB.Add('Warning : Percent is not valid for this reservation mode ',1);
    END IF;
    FND_FILE.Put_Line(FND_FILE.LOG, ' Percent is not valid for this reservation mode');
    ERRBUF  := ' Percent is not valid for this reservation mode - hence not considered';
    RETCODE := 2;
    GOTO END_OF_PROCESS;
  END IF;
  G_RESERVATION_MODE := p_reservation_mode; -- Pack J
  FND_FILE.Put_Line(FND_FILE.LOG, 'Parameters:');
  FND_FILE.Put_Line(FND_FILE.LOG, '    Use_reservation_time_fence =  '|| p_use_reservation_time_fence);
  FND_FILE.Put_Line(FND_FILE.LOG, '    order_number_low =  '|| p_order_number_low);
  FND_FILE.Put_Line(FND_FILE.LOG, '    order_number_high = '|| p_order_number_high);
  FND_FILE.Put_Line(FND_FILE.LOG, '    Customer = '|| p_customer_id);
  FND_FILE.Put_Line(FND_FILE.LOG, '    order_type = '|| p_order_type);
  FND_FILE.Put_Line(FND_FILE.LOG, '    Warehouse = '|| p_Warehouse);
  FND_FILE.Put_Line(FND_FILE.LOG, '    request_date_low = '|| p_request_date_low);
  FND_FILE.Put_Line(FND_FILE.LOG, '    request_date_high = '|| p_request_date_high);
  FND_FILE.Put_Line(FND_FILE.LOG, '    schedule_date_low = '|| p_schedule_ship_date_low);
  FND_FILE.Put_Line(FND_FILE.LOG, '    schedule_date_high = '|| p_schedule_ship_date_high);
  FND_FILE.Put_Line(FND_FILE.LOG, '    ordered_date_low = '|| p_ordered_date_low);
  FND_FILE.Put_Line(FND_FILE.LOG, '    ordered_date_high = '|| p_ordered_date_high);
  FND_FILE.Put_Line(FND_FILE.LOG, '    Demand Class = '|| p_demand_class_code);
  FND_FILE.Put_Line(FND_FILE.LOG, '    item = '|| p_inventory_item_id);
  FND_FILE.Put_Line(FND_FILE.LOG, '    Planning Priority = '|| p_Planning_priority);
  FND_FILE.Put_Line(FND_FILE.LOG, '    Booked Flag  = '|| p_booked);
  FND_FILE.Put_Line(FND_FILE.LOG, '    Order By = '|| p_order_by);
  FND_FILE.Put_Line(FND_FILE.LOG, '    Reservation Mode = '|| p_reservation_mode);
  FND_FILE.Put_Line(FND_FILE.LOG, '    Percent = '|| p_percent);
  FND_FILE.Put_Line(FND_FILE.LOG, '    Shipment Priority = '|| p_shipment_priority);
  FND_FILE.Put_Line(FND_FILE.LOG, '    Reserve Run Type = '|| p_reserve_run_type);
  FND_FILE.Put_Line(FND_FILE.LOG, '    Reserve Set Name  = '|| p_reserve_set_name);
  IF l_debug_level > 0 THEN
    OE_DEBUG_PUB.Add('Inside the Reserve Order Concurrent Program',1);
  END IF;
  SELECT FND_DATE.Canonical_To_Date(p_request_date_low),
    FND_DATE.Canonical_To_Date(p_request_date_high),
    FND_DATE.Canonical_To_Date(p_schedule_ship_date_low),
    FND_DATE.Canonical_To_Date(p_schedule_ship_date_high),
    FND_DATE.Canonical_To_Date(p_schedule_arrival_date_low),
    FND_DATE.Canonical_To_Date(p_schedule_arrival_date_high),
    FND_DATE.Canonical_To_Date(p_ordered_date_low),
    FND_DATE.Canonical_To_Date(p_ordered_date_high)
  INTO l_request_date_low,
    l_request_date_high,
    l_schedule_ship_date_low,
    l_schedule_ship_date_high,
    l_schedule_arrival_date_low,
    l_schedule_arrival_date_high,
    l_ordered_date_low,
    l_ordered_date_high
  FROM DUAL;
  -- Moac Start
  IF MO_GLOBAL.get_access_mode = 'S' THEN
    l_single_org              := TRUE;
  ELSIF p_org_id              IS NOT NULL THEN
    l_single_org              := TRUE;
    MO_GLOBAL.set_policy_context(p_access_mode => 'S', p_org_id => p_org_id);
  END IF;
  -- Moac End
  FND_FILE.Put_Line(FND_FILE.LOG,'OPEN CURSOR');
  l_cursor_id          := DBMS_SQL.OPEN_CURSOR;
  IF p_reserve_run_type ='CREATE_RESERVATION' THEN --Pack J
    l_stmt             := 'SELECT Line_id FROM  OE_Reservation_Sets_V rset WHERE '|| 'rset.reservation_set_name=:reservation_set_name';
  ELSE
    --Moac
    FND_FILE.PUT_LINE(FND_FILE.LOG,'CREATE_RESERVATION Dynamic sql start');
    l_stmt := 'SELECT Line_id, l.org_id ,h.order_number FROM  OE_ORDER_LINES l, OE_ORDER_HEADERS_ALL h ,MTL_SYSTEM_ITEMS msi ';
    --10241113
    IF P_SELECTED_IDS IS NOT NULL THEN
      l_stmt          := 'SELECT l.Line_id, l.org_id ,h.order_number FROM  OE_ORDER_LINES l, OE_ORDER_HEADERS_ALL h ,MTL_SYSTEM_ITEMS msi,oe_rsv_set_details rs ';
    END IF;
    l_stmt                 := l_stmt|| ' WHERE NVL(h.cancelled_flag,'||'''N'''||') <> ' ||'''Y'''|| ' AND  h.header_id  = l.header_id'|| ' AND  h.open_flag  = '||'''Y'''|| ' AND  NVL(l.cancelled_flag,'||'''N'''||') <> '||'''Y'''|| ' AND  NVL(l.line_category_code,'||'''ORDER'''||') <> '||'''RETURN''';
    IF NVL(p_booked,'*')    = 'Y' THEN
      l_stmt               := l_stmt||' AND  h.booked_flag  = '||'''Y''';
    ELSIF NVL(p_booked,'*') = 'N' THEN
      l_stmt               := l_stmt||' AND  h.booked_flag  = '||'''N''';
    END IF;
    -- Moac Start
    IF p_org_id IS NOT NULL THEN
      l_stmt    := l_stmt ||' AND  l.org_id = :org_id'; -- p_org_id
    END IF;
    -- Moac End
    IF p_order_number_low IS NOT NULL THEN
      l_stmt              := l_stmt ||' AND  h.order_number >=:order_number_low'; -- p_order_number_low
    END IF;
    IF p_order_number_high IS NOT NULL THEN
      l_stmt               := l_stmt ||' AND  h.order_number <=:order_number_high'; -- p_order_number_high
    END IF;
    IF p_customer_id IS NOT NULL THEN
      l_stmt         := l_stmt ||' AND  h.sold_to_org_id =:customer_id'; --p_customer_id
    END IF;
    IF p_order_type IS NOT NULL THEN
      l_stmt        := l_stmt ||' AND  h.order_type_id =:order_type'; --p_order_type
    END IF;
    IF l_ordered_date_low IS NOT NULL THEN
      l_stmt              := l_stmt ||' AND  h.ordered_date >=:ordered_date_low'; --l_ordered_date_low
    END IF;
    IF l_ordered_date_high IS NOT NULL THEN
      l_stmt               := l_stmt ||' AND  h.ordered_date <=:ordered_date_high'; --l_ordered_date_high;
    END IF;
    IF p_line_type_id IS NOT NULL THEN
      l_stmt          := l_stmt ||' AND l.line_type_id =:line_type_id'; --p_line_type_id
    END IF;
    l_stmt         := l_stmt ||' AND l.open_flag  = '||'''Y''';
    IF p_warehouse IS NOT NULL THEN
      l_stmt       := l_stmt ||' AND l.ship_from_org_id =:warehouse'; --p_warehouse
    END IF;
    IF l_request_date_low IS NOT NULL THEN
      l_stmt              := l_stmt ||' AND l.request_date >=:request_date_low'; --l_request_date_low;
    END IF;
    IF l_request_date_high IS NOT NULL THEN
      l_stmt               := l_stmt ||' AND l.request_date <=:request_date_high'; --l_request_date_high
    END IF;
    IF l_schedule_ship_date_low IS NOT NULL THEN
      l_stmt                    := l_stmt ||' AND l.schedule_ship_date >=:schedule_ship_date_low'; --l_schedule_ship_date_low
    END IF;
    IF l_schedule_ship_date_high IS NOT NULL THEN
      l_stmt                     := l_stmt ||' AND l.schedule_ship_date <=:schedule_ship_date_high'; --l_schedule_ship_date_high
    END IF;
    IF l_schedule_arrival_date_low IS NOT NULL THEN
      l_stmt                       := l_stmt ||' AND l.Schedule_Arrival_Date >=:schedule_arrival_date_low'; --l_schedule_arrival_date_low
    END IF;
    IF l_schedule_arrival_date_high IS NOT NULL THEN
      l_stmt                        := l_stmt ||' AND l.Schedule_Arrival_Date <=:schedule_arrival_date_high'; --l_schedule_arrival_date_high
    END IF;
    IF p_inventory_item_id IS NOT NULL THEN
      l_stmt               := l_stmt ||' AND l.inventory_item_id =:inventory_item_id'; -- p_inventory_item_id
    END IF;
    IF p_demand_class_code IS NOT NULL THEN
      l_stmt               := l_stmt ||' AND NVL(l.demand_class_code,'||'''-99'''||') =:demand_class_code'; --p_demand_class_code
    END IF;
    IF p_planning_priority IS NOT NULL THEN
      l_stmt               := l_stmt ||' AND NVL(l.planning_priority,-99)=:planning_priority'; --p_planning_priority
    END IF;
    IF p_shipment_priority IS NOT NULL THEN
      l_stmt               := l_stmt ||' AND NVL(l.shipment_priority_code, '||'''XX'''||')=:shipment_priority'; --p_shipment_priority
    END IF;
    IF p_selected_ids IS NOT NULL THEN --Pack J
      --l_stmt := l_stmt ||' AND l.line_id IN(:selected_ids)';  --p_selected_ids
      --R12.MOAC
      --10241113
      /*
      l_stmt := l_stmt ||' AND l.line_id IN(SELECT line_id FROM
      oe_rsv_set_details WHERE reservation_set_id=:set_id)';
      */
      l_stmt   := l_stmt ||' AND l.line_id = rs.line_id AND reservation_set_id=:set_id ';
      l_ord_by :=' rs.line_sequence,';
    END IF;
    IF p_reservation_mode    = 'PARTIAL_ONLY_UNRESERVED' THEN -- Pack J
      l_stmt                := l_stmt ||' AND NOT Exists (SELECT 1 FROM mtl_reservations mrs ' ||' WHERE l.line_id = mrs.demand_source_line_id)';
    ELSIF p_reservation_mode ='PARTIAL' THEN
      l_stmt                := l_stmt ||' AND (NOT Exists (SELECT 1 FROM mtl_reservations mrs ' ||' WHERE l.line_id = mrs.demand_source_line_id)' ||' OR l. ordered_quantity > (select sum(INV_CONVERT.INV_UM_CONVERT( ' ||' l.inventory_item_id, 5, reservation_quantity, reservation_uom_code,' ||' l.order_quantity_uom,  NULL, NULL)) from mtl_reservations ' ||' where demand_source_line_id = l.line_id))';
    END IF;
    L_STMT := L_STMT|| ' AND  l.shipped_quantity  IS NULL'|| ' AND l.source_type_code  = '||'''INTERNAL'''|| ' AND l.schedule_ship_date IS NOT NULL'|| ' AND NVL(l.shippable_flag,'||'''N'''||')  = '||'''Y'''|| ' AND l.ship_from_org_id   = msi.organization_id'|| ' AND l.inventory_item_id  = msi.inventory_item_id'|| ' AND msi.service_item_flag <> '||'''Y'''|| ' AND msi.reservable_type   <> 2';
    --9063115 : Added Line_id to the order By clause
    L_STMT := L_STMT|| ' and l.flow_status_code = '||'''AWAITING_SHIPPING''';
    L_STMT := L_STMT|| ' and trunc(l.schedule_ship_date) <= trunc(sysdate+1)';
    -- L_STMT := L_STMT|| ' AND h.order_type_id  in (select unique tl.transaction_type_id  from oe_transaction_types_tl tl '||' WHERE tl.NAME in ('||'''US Standard'''||','||'''XX Standard'''||','||'''XX Equipment'''||','||'''XX Distributor'''||'))';
    L_STMT        := L_STMT|| ' AND h.order_type_id  in ( SELECT unique oet.transaction_type_id FROM FND_FLEX_VALUE_SETS FFVS , FND_FLEX_VALUES FFV , FND_FLEX_VALUES_TL FFVT , OE_TRANSACTION_TYPES_TL OET '||' WHERE oet.NAME = FFVT.FLEX_VALUE_MEANING ' || ' and ffvs.flex_value_set_id = ffv.flex_value_set_id ' ||' AND FFV.FLEX_VALUE_ID = FFVT.FLEX_VALUE_ID ' ||' AND FFVT.LANGUAGE = USERENV('||'''LANG'''||')' ||' and flex_value_set_name = '||'''XXHA_RESERVE_ORDER_TYPES'''||')';
--    L_STMT        := L_STMT|| ' and  Exists (SELECT 1 FROM xxha_com_pick_excep xx  ' ||'  where XX.item_id = L.INVENTORY_ITEM_ID'||' AND (SYSDATE BETWEEN XX.DATE_FROM AND NVL(XX.DATE_TO,SYSDATE)))'; --AA
--    L_STMT        := L_STMT|| ' and  Exists (select 1 from hz_cust_site_uses_all cs, HZ_CUST_ACCT_SITES_ALL CAS, hz_party_sites ps, hz_locations hl, xxha_com_pick_excep XX ' ||' where hl.location_id = ps.location_id '|| ' and ps.party_site_id = cas.party_site_id '|| ' and CAS.CUST_ACCT_SITE_ID = CS.CUST_ACCT_SITE_ID'|| ' AND CS.SITE_USE_CODE = '||'''SHIP_TO'''||' AND XX.SHIP_TO_COUNTRY_CODE = hl.country '|| 'AND SYSDATE BETWEEN XX.DATE_FROM AND NVL(XX.DATE_TO,SYSDATE) '|| ' AND cs.site_use_id = L.SHIP_TO_ORG_ID)'; --AA
    --L_STMT        := L_STMT|| ' and  Exists (select 1 from hz_cust_site_uses_all cs, HZ_CUST_ACCT_SITES_ALL CAS, hz_party_sites ps, hz_locations hl, xxha_com_pick_excep XX '||'  where XX.item_id = L.INVENTORY_ITEM_ID'||' AND (SYSDATE BETWEEN XX.DATE_FROM AND NVL(XX.DATE_TO,SYSDATE))' ||' and hl.location_id = ps.location_id '|| ' and ps.party_site_id = cas.party_site_id '|| ' and CAS.CUST_ACCT_SITE_ID = CS.CUST_ACCT_SITE_ID'|| ' AND CS.SITE_USE_CODE = '||'''SHIP_TO'''||' AND XX.SHIP_TO_COUNTRY_CODE = hl.country '|| 'AND SYSDATE BETWEEN XX.DATE_FROM AND NVL(XX.DATE_TO,SYSDATE) '|| ' AND cs.site_use_id = L.SHIP_TO_ORG_ID)'; --AA Combined item/ ship to country validation in single condition
    L_STMT        := L_STMT|| ' and Exists ((select 1 from hz_cust_site_uses_all cs, HZ_CUST_ACCT_SITES_ALL CAS, hz_party_sites ps, hz_locations hl, xxha_com_pick_excep XX '||'  where XX.item_id = L.INVENTORY_ITEM_ID'||' AND (SYSDATE BETWEEN XX.DATE_FROM AND NVL(XX.DATE_TO,SYSDATE))' ||' and hl.location_id = ps.location_id '|| ' and ps.party_site_id = cas.party_site_id '|| ' and CAS.CUST_ACCT_SITE_ID = CS.CUST_ACCT_SITE_ID'|| ' AND CS.SITE_USE_CODE = '||'''SHIP_TO'''||' AND XX.SHIP_TO_COUNTRY_CODE = hl.country '|| 'AND SYSDATE BETWEEN XX.DATE_FROM AND NVL(XX.DATE_TO,SYSDATE) '|| ' AND cs.site_use_id = L.SHIP_TO_ORG_ID) '||' union (select 1 from xxha_com_pick_excep XX1 '||'  where XX1.item_id = L.INVENTORY_ITEM_ID'||' AND (SYSDATE BETWEEN XX1.DATE_FROM AND NVL(XX1.DATE_TO,SYSDATE)) '||' and XX1.ship_to_customer_site_id = L.SHIP_TO_ORG_ID)   ) '; --AA Combined item, ship to country validation  or item, ship to org in single condition    
    IF p_order_by IS NOT NULL THEN
      --      start for bug 3476226
      --      the following IF was added as ORDERED_DATE is not present im OE_ORDER_LINES l but in OE_ORDER_HEADERS h
      IF UPPER(p_order_by) = 'ORDERED_DATE' THEN
        --l_stmt := l_stmt || ' ORDER BY  l.inventory_item_id,l.ship_from_org_id,l.subinventory,h.ORDERED_DATE,l.line_id';
        l_stmt := l_stmt || ' ORDER BY '||l_ord_by||' l.inventory_item_id,l.ship_from_org_id,l.subinventory,h.ORDERED_DATE,l.line_id';
      ELSE
        l_stmt := l_stmt || ' ORDER BY '||l_ord_by||' l.inventory_item_id,l.ship_from_org_id,l.subinventory,l.'|| p_order_by||',l.line_id';
      END IF;
      --      end for bug 3476226
    ELSE
      L_ORD_BY := ' h.order_number';
      L_STMT   := L_STMT || ' ORDER BY '||L_ORD_BY;
      --l_stmt := l_stmt || ' ORDER BY '||l_ord_by||' l.inventory_item_id,l.ship_from_org_id,l.subinventory,l.line_id';
    END IF;
  END IF;
  FND_FILE.Put_Line(FND_FILE.LOG,'CREATE_RESERVATION Dynamic sql END');
  --  OE_DEBUG_PUB.Add(substr(l_stmt,1,length(l_stmt)),1);
  DBMS_SQL.PARSE(l_cursor_id,l_stmt,DBMS_SQL.NATIVE);
  -- Bind variables
  -- 4287740
  IF p_reserve_run_type <> 'CREATE_RESERVATION' OR p_reserve_run_type IS NULL THEN
    -- Moac start
    IF p_org_id IS NOT NULL THEN
      DBMS_SQL.BIND_VARIABLE(l_cursor_id,':org_id',p_org_id);
    END IF;
    -- Moac end
    IF p_order_number_low IS NOT NULL THEN
      DBMS_SQL.BIND_VARIABLE(l_cursor_id,':order_number_low',p_order_number_low);
    END IF;
    IF p_order_number_high IS NOT NULL THEN
      DBMS_SQL.BIND_VARIABLE(l_cursor_id,':order_number_high',p_order_number_high);
    END IF;
    IF p_customer_id IS NOT NULL THEN
      DBMS_SQL.BIND_VARIABLE(l_cursor_id,':customer_id',p_customer_id);
    END IF;
    IF p_order_type IS NOT NULL THEN
      DBMS_SQL.BIND_VARIABLE(l_cursor_id,':order_type',p_order_type);
    END IF;
    IF l_ordered_date_low IS NOT NULL THEN
      DBMS_SQL.BIND_VARIABLE(l_cursor_id,':ordered_date_low',l_ordered_date_low);
    END IF;
    IF l_ordered_date_high IS NOT NULL THEN
      DBMS_SQL.BIND_VARIABLE(l_cursor_id,':ordered_date_high',l_ordered_date_high);
    END IF;
    IF p_line_type_id IS NOT NULL THEN
      DBMS_SQL.BIND_VARIABLE(l_cursor_id,':line_type_id',p_line_type_id);
    END IF;
    IF p_warehouse IS NOT NULL THEN
      DBMS_SQL.BIND_VARIABLE(l_cursor_id,':warehouse',p_warehouse);
    END IF;
    IF l_request_date_low IS NOT NULL THEN
      DBMS_SQL.BIND_VARIABLE(l_cursor_id,':request_date_low',l_request_date_low);
    END IF;
    IF l_request_date_high IS NOT NULL THEN
      DBMS_SQL.BIND_VARIABLE(l_cursor_id,':request_date_high',l_request_date_high);
    END IF;
    IF l_schedule_ship_date_low IS NOT NULL THEN
      DBMS_SQL.BIND_VARIABLE(l_cursor_id,':schedule_ship_date_low',l_schedule_ship_date_low);
    END IF;
    IF l_schedule_ship_date_high IS NOT NULL THEN
      DBMS_SQL.BIND_VARIABLE(l_cursor_id,':schedule_ship_date_high',l_schedule_ship_date_high);
    END IF;
    IF l_schedule_arrival_date_low IS NOT NULL THEN
      DBMS_SQL.BIND_VARIABLE(l_cursor_id,':schedule_arrival_date_low',l_schedule_arrival_date_low);
    END IF;
    IF l_schedule_arrival_date_high IS NOT NULL THEN
      DBMS_SQL.BIND_VARIABLE(l_cursor_id,':schedule_arrival_date_high',l_schedule_arrival_date_high);
    END IF;
    IF p_inventory_item_id IS NOT NULL THEN
      DBMS_SQL.BIND_VARIABLE(l_cursor_id,':inventory_item_id',p_inventory_item_id);
    END IF;
    IF p_demand_class_code IS NOT NULL THEN
      DBMS_SQL.BIND_VARIABLE(l_cursor_id,':demand_class_code',p_demand_class_code);
    END IF;
    IF p_planning_priority IS NOT NULL THEN
      DBMS_SQL.BIND_VARIABLE(l_cursor_id,':planning_priority',p_planning_priority);
    END IF;
    IF p_shipment_priority IS NOT NULL THEN
      DBMS_SQL.BIND_VARIABLE(l_cursor_id,':shipment_priority',p_shipment_priority);
    END IF;
    --R12.MOAC
    IF p_selected_ids IS NOT NULL THEN
      DBMS_SQL.BIND_VARIABLE(l_cursor_id,':set_id',p_selected_ids);
    END IF;
  ELSIF p_reserve_run_type ='CREATE_RESERVATION' AND p_reserve_set_name IS NOT NULL THEN --Pack J
    DBMS_SQL.BIND_VARIABLE(l_cursor_id,':reservation_set_name',p_reserve_set_name);
  END IF;
  -- Define the output variables
  DBMS_SQL.DEFINE_COLUMN(l_cursor_id,1,l_line_id);
  --  DBMS_SQL.DEFINE_COLUMN(l_cursor_id,3,l_order_number1);
  -- OE_DEBUG_PUB.Add(length(l_stmt));
  IF l_debug_level > 0 THEN
    OE_DEBUG_PUB.Add(SUBSTR(l_stmt,1,LENGTH(l_stmt)),1);
  END IF;
  l_retval := DBMS_SQL.EXECUTE(l_cursor_id);
  -- OPEN l_ref_cur_lines FOR l_stmt;
  FND_FILE.Put_Line(FND_FILE.output, '***** XXHA Reserve Order Program Processed Orders *****');
  FND_FILE.Put_Line(FND_FILE.output, ' ');
  FND_FILE.Put_Line(FND_FILE.output, 'OU_Name                    Order_Number  Line_Number Ordered_Item');
  FND_FILE.Put_Line(FND_FILE.output, ' ');
  LOOP
    IF DBMS_SQL.FETCH_ROWS(l_cursor_id) = 0 THEN
      EXIT;
    END IF;
    DBMS_SQL.COLUMN_VALUE(l_cursor_id, 1, l_line_id);
    --  DBMS_SQL.COLUMN_VALUE(l_cursor_id, 3, l_order_number1);
    FND_FILE.Put_Line(FND_FILE.LOG, ' ');
    FND_FILE.Put_Line(FND_FILE.LOG, '***** Processing Line id '|| l_Line_id||' *****');
    --Added by Vijay on 19-Mar-2015
    BEGIN
      SELECT order_number,
        line_number,
        ordered_item,
        hou.name
      INTO l_order_number1,
        l_line_number,
        l_ordered_item,
        l_org_name1
      FROM oe_order_headers_all ooh,
        oe_order_lines_all ool,
        hr_operating_units hou
      WHERE line_id    =l_line_id
      AND ool.header_id=ooh.header_id
      and ooh.org_id=hou.organization_id;
    EXCEPTION
    WHEN OTHERS THEN
      NULL;
    END;
    FND_FILE.Put_Line(FND_FILE.output, l_org_name1||'      '||l_order_number1||'      '||l_line_number||'         '||l_ordered_item);
    l_return_status := FND_API.G_RET_STS_SUCCESS;
    BEGIN
      SELECT ordered_quantity,
        subinventory
      INTO G_ORDERED_QUANTITY,
        g_subinventory
      FROM OE_ORDER_LINES_ALL
      WHERE LINE_ID = L_LINE_ID;
      fnd_file.put_line(fnd_file.log,'G_ordered_quantity :'||G_ordered_quantity); -----AppsAssociates
      fnd_file.put_line(fnd_file.log,'g_subinventory :'||g_subinventory);         -----AppsAssociates
    EXCEPTION
    WHEN OTHERS THEN
      G_ORDERED_QUANTITY := NULL;
    END;
    OE_LINE_UTIL.LOCK_ROW (P_LINE_ID => L_LINE_ID, P_X_LINE_REC => L_LINE_REC, X_RETURN_STATUS => L_RETURN_STATUS);
    fnd_file.put_line(fnd_file.log,'After OE_LINE_UTIL.LOCK_ROW');
    IF l_return_status = FND_API.G_RET_STS_ERROR THEN
      IF l_debug_level > 0 THEN
        OE_DEBUG_PUB.ADD('Lock row returned with error',1);
        fnd_file.put_line(fnd_file.log,'Lock row returned with error');
      END IF;
    END IF;
    --      Updating the value of the Schedule Action Code
    IF l_return_status                 = FND_API.G_RET_STS_SUCCESS THEN
      l_line_rec.schedule_action_code := OESCH_ACT_RESERVE;
      IF l_debug_level                 > 0 THEN
        OE_DEBUG_PUB.Add('set mesg context line_id:'||l_line_rec.line_id);
        OE_DEBUG_PUB.ADD('set mesg context header_id:'||L_LINE_REC.HEADER_ID);
        FND_FILE.PUT_LINE(FND_FILE.LOG,'set mesg context line_id:'||L_LINE_REC.LINE_ID);
        fnd_file.put_line(fnd_file.log,'set mesg context header_id:'||L_LINE_REC.HEADER_ID);
      END IF;
      FND_FILE.PUT_LINE(FND_FILE.LOG,'before E_MSG_PUB.Set_Msg_Context');
      OE_MSG_PUB.SET_MSG_CONTEXT( P_ENTITY_CODE => 'LINE' ,P_ENTITY_ID => L_LINE_REC.LINE_ID ,P_HEADER_ID => L_LINE_REC.HEADER_ID ,P_LINE_ID => L_LINE_REC.LINE_ID ,P_ORDER_SOURCE_ID => L_LINE_REC.ORDER_SOURCE_ID ,P_ORIG_SYS_DOCUMENT_REF => L_LINE_REC.ORIG_SYS_DOCUMENT_REF ,P_ORIG_SYS_DOCUMENT_LINE_REF => L_LINE_REC.ORIG_SYS_LINE_REF ,P_ORIG_SYS_SHIPMENT_REF => L_LINE_REC.ORIG_SYS_SHIPMENT_REF ,P_CHANGE_SEQUENCE => L_LINE_REC.CHANGE_SEQUENCE ,P_SOURCE_DOCUMENT_TYPE_ID => L_LINE_REC.SOURCE_DOCUMENT_TYPE_ID ,P_SOURCE_DOCUMENT_ID => L_LINE_REC.SOURCE_DOCUMENT_ID ,P_SOURCE_DOCUMENT_LINE_ID => L_LINE_REC.SOURCE_DOCUMENT_LINE_ID );
      FND_FILE.PUT_LINE(FND_FILE.LOG,'After E_MSG_PUB.Set_Msg_Context');
      FND_FILE.PUT_LINE(FND_FILE.LOG,'p_reserve_run_type ::'||p_reserve_run_type);
      IF NVL(P_RESERVE_RUN_TYPE,'RESERVE') <> 'CREATE_RESERVATION' THEN -- Pack J
        FND_FILE.PUT_LINE(FND_FILE.LOG,' inside IF RESERVE <> CREATE_RESERVATION before Reserve_Eligible');
        RESERVE_ELIGIBLE( P_LINE_REC => L_LINE_REC ,P_USE_RESERVATION_TIME_FENCE => P_USE_RESERVATION_TIME_FENCE ,X_RETURN_STATUS => L_RETURN_STATUS );
        L_RETURN_STATUS := 'S';
        FND_FILE.PUT_LINE(FND_FILE.LOG,' inside IF RESERVE <> CREATE_RESERVATION After Reserve_Eligible');
        FND_FILE.PUT_LINE(FND_FILE.LOG,'L_RETURN_STATUS :'||L_RETURN_STATUS);
        FND_FILE.PUT_LINE(FND_FILE.LOG,'FND_API.G_RET_STS_SUCCESS :'||FND_API.G_RET_STS_SUCCESS);
        FND_FILE.PUT_LINE(FND_FILE.LOG,'FND_API.G_RET_STS_ERROR :'|| FND_API.G_RET_STS_ERROR);
        FND_FILE.PUT_LINE(FND_FILE.LOG,'FND_API.G_RET_STS_UNEXP_ERROR :'|| FND_API.G_RET_STS_UNEXP_ERROR);
        IF l_return_status = FND_API.G_RET_STS_ERROR THEN
          IF l_debug_level > 0 THEN
            OE_DEBUG_PUB.Add('Require Reservation returned with error for                                
Line id:'||l_line_rec.line_id,1);
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Require Reservation returned with error for Line id:'||l_line_rec.line_id);
          END IF;
        ELSIF l_return_status = FND_API.G_RET_STS_UNEXP_ERROR THEN
          IF l_debug_level    > 0 THEN
            OE_DEBUG_PUB.Add('Require Reservation returned with error for                                
Line id:'||l_line_rec.line_id,1);
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Require Reservation returned with error for Line id:'||l_line_rec.line_id);
            OE_DEBUG_PUB.Add(SUBSTR(sqlerrm, 1, 2000));
          END IF;
        END IF;
      ELSE
        L_RETURN_STATUS := FND_API.G_RET_STS_SUCCESS;
        FND_FILE.PUT_LINE(FND_FILE.LOG,'L_RETURN_STATUS :'||L_RETURN_STATUS);
        FND_FILE.PUT_LINE(FND_FILE.LOG,'FND_API.G_RET_STS_SUCCESS :'||FND_API.G_RET_STS_SUCCESS);
      END IF;
      IF l_return_status = FND_API.G_RET_STS_SUCCESS THEN
        /* Here we will call the Procedure for Reservation */
        FND_FILE.PUT_LINE(FND_FILE.LOG,'G_RET_STS_SUCCESS');
        IF P_RESERVATION_MODE IS NULL AND (P_RESERVE_RUN_TYPE ='RESERVE' OR P_RESERVE_RUN_TYPE IS NULL) THEN
          FND_FILE.PUT_LINE(FND_FILE.LOG,'before calling Create_Reservation');
          Create_Reservation( p_line_rec => l_line_rec ,x_return_status => l_return_status );
          -- 4287740 Start
          FND_FILE.PUT_LINE(FND_FILE.LOG,'After calling Create_Reservation');
          IF l_return_status = FND_API.G_RET_STS_ERROR THEN
            IF l_debug_level > 0 THEN
              OE_DEBUG_PUB.Add('Create Reservation returned with                         
Expected error for Line id:' ||l_line_rec.line_id,1);
              FND_FILE.PUT_LINE(FND_FILE.LOG,'Create Reservation returned with Expected error for Line id:' ||l_line_rec.line_id);
            END IF;
          ELSIF l_return_status = FND_API.G_RET_STS_UNEXP_ERROR THEN
            IF l_debug_level    > 0 THEN
              OE_DEBUG_PUB.Add('Create Reservation returned with                          
Unexpected error for Line id:'||l_line_rec.line_id,1);
              FND_FILE.PUT_LINE(FND_FILE.LOG,'Create Reservation returned with Unexpected error for Line id:' ||l_line_rec.line_id);
              OE_DEBUG_PUB.Add(SUBSTR(sqlerrm, 1, 2000));
            END IF;
          ELSE
            COMMIT;
          END IF;
          -- 4287740 End
        ELSE
          l_index                                    := l_rsv_tbl.COUNT +1;
          l_rsv_tbl(l_index).line_id                 := l_line_rec.line_id;
          l_rsv_tbl(l_index).header_id               := l_line_rec.header_id;
          l_rsv_tbl(l_index).inventory_item_id       := l_line_rec.inventory_item_id;
          l_rsv_tbl(l_index).ordered_qty             := l_line_rec.ordered_quantity;
          l_rsv_tbl(l_index).ordered_qty_UOM         := l_line_rec.order_quantity_uom;
          l_rsv_tbl(l_index).ordered_qty_UOM2        := l_line_rec.ordered_quantity_uom2; -- 13657322
          l_rsv_tbl(l_index).ship_from_org_id        := l_line_rec.ship_from_org_id;
          l_rsv_tbl(l_index).subinventory            := l_line_rec.subinventory;
          l_rsv_tbl(l_index).schedule_ship_date      := l_line_rec.schedule_ship_date;
          l_rsv_tbl(l_index).source_document_type_id := l_line_rec.source_document_type_id;
          -- Pack J
          l_rsv_tbl(l_index).order_source_id         := l_line_rec.order_source_id;
          l_rsv_tbl(l_index).orig_sys_document_ref   := l_line_rec.orig_sys_document_ref;
          l_rsv_tbl(l_index).orig_sys_line_ref       := l_line_rec.orig_sys_line_ref;
          l_rsv_tbl(l_index).orig_sys_shipment_ref   := l_line_rec.orig_sys_shipment_ref;
          l_rsv_tbl(l_index).change_sequence         := l_line_rec.change_sequence;
          l_rsv_tbl(l_index).source_document_id      := l_line_rec.source_document_id;
          l_rsv_tbl(l_index).source_document_line_id := l_line_rec.source_document_line_id;
          l_rsv_tbl(l_index).shipped_quantity        := l_line_rec.shipped_quantity;
          l_rsv_tbl(l_index).shipped_quantity2       := l_line_rec.shipped_quantity2; -- INVCONV
          l_rsv_tbl(l_index).ordered_qty2            := l_line_rec.ordered_quantity2; -- INVCONV
          --4759251
          L_RSV_TBL(L_INDEX).ORG_ID := L_LINE_REC.ORG_ID;
          FND_FILE.PUT_LINE(FND_FILE.LOG,'in Else block');
          --13397472
          IF l_line_rec.project_id        IS NOT NULL THEN
            l_rsv_tbl(l_index).project_id :=l_line_rec.project_id;
          END IF;
          IF l_line_rec.task_id        IS NOT NULL THEN
            l_rsv_tbl(l_index).task_id := l_line_rec.task_id;
          END IF;
        END IF;
        --4287740 Commented the below code as it has been moved up
        /*
        IF l_return_status = FND_API.G_RET_STS_ERROR THEN
        IF l_debug_level  > 0 THEN
        OE_DEBUG_PUB.Add('Create Reservation returned with
        Expected error for Line id:' ||l_line_rec.line_id,1);
        END IF;
        ELSIF l_return_status = FND_API.G_RET_STS_UNEXP_ERROR THEN
        IF l_debug_level  > 0 THEN
        OE_DEBUG_PUB.Add('Create Reservation returned with
        Unexpected error for Line id:'||l_line_rec.line_id,1);
        OE_DEBUG_PUB.Add(substr(sqlerrm, 1, 2000));
        END IF;
        ELSE
        COMMIT;
        END IF;
        */
      END IF; -- End of Create_Reservation
    END IF;   -- End of Lock Row
  END LOOP;   -- End of lines_cur
  DBMS_SQL.CLOSE_CURSOR(l_cursor_id);
  --3710133
  --4287740 Added Not null check for reservation mode
  IF p_reservation_mode IS NOT NULL AND l_rsv_tbl.count = 0 THEN
    FND_MESSAGE.SET_NAME('ONT', 'ONT_NO_LINES_RSV_ELIGIBLE');
    FND_FILE.PUT_LINE(FND_FILE.LOG,'ONT ONT_NO_LINES_RSV_ELIGIBLE');
    Oe_Msg_Pub.Add;
    OE_MSG_PUB.Save_Messages(p_request_id => l_request_id);
    l_msg_data := Fnd_Message.get_string('ONT', 'ONT_NO_LINES_RSV_ELIGIBLE');
    FND_FILE.Put_Line(FND_FILE.LOG, l_msg_data);
    RETCODE         := 1;
    IF l_debug_level > 0 THEN
      OE_DEBUG_PUB.ADD('Warning : No lines were eligible for reservation.',1);
      FND_FILE.PUT_LINE(FND_FILE.LOG,'Warning : No lines were eligible for reservation.');
    END IF;
    IF p_reserve_set_name IS NOT NULL THEN
      Fnd_Message.set_name('ONT', 'ONT_RSV_SET_NOT_CREATED');
      Oe_Msg_Pub.Add;
      OE_MSG_PUB.Save_Messages(p_request_id => l_request_id);
      l_msg_data := Fnd_Message.get_string('ONT', 'ONT_RSV_SET_NOT_CREATED');
      FND_FILE.Put_Line(FND_FILE.LOG, l_msg_data);
      RETCODE         := 1;
      IF l_debug_level > 0 THEN
        OE_DEBUG_PUB.ADD('Warning : The set is not created as no eligible  lines were selected',1);
        FND_FILE.PUT_LINE(FND_FILE.LOG,'Warning : The set is not created as no eligible  lines were selected');
      END IF;
    END IF;
    GOTO END_OF_PROCESS;
  END IF;
  IF p_reserve_run_type = 'CREATE_RESERVATION' THEN -- Pack J
    -- Get the set id
    OPEN get_reservation_set;
    FETCH get_reservation_set INTO l_set_id;
    CLOSE GET_RESERVATION_SET;
    FND_FILE.PUT_LINE(FND_FILE.LOG,'Before : Validate_and_Reserve_for_Set');
    Validate_and_Reserve_for_Set (p_x_rsv_tbl => l_rsv_tbl ,p_reservation_set_id => l_set_id ,x_return_status => l_return_status);
    IF L_RETURN_STATUS = FND_API.G_RET_STS_SUCCESS THEN
      FND_FILE.PUT_LINE(FND_FILE.LOG,'Before : Update_Reservation_Set');
      Update_Reservation_Set (p_reservation_set_id => l_set_id ,x_return_status => l_return_status);
    END IF;
  ELSE
    l_percent := p_percent;
    FOR I IN 1..l_rsv_tbl.COUNT
    LOOP
      IF l_old_item_id IS NULL THEN -- Pack J
        --IF l_old_warehouse IS NULL THEN
        l_old_item_id      := l_rsv_tbl(I).inventory_item_id;
        l_old_warehouse    := l_rsv_tbl(I).ship_from_org_id;
        l_old_subinventory := l_rsv_tbl(I).subinventory;
        l_old_org_id       := l_rsv_tbl(I).org_id; -- 4759251
      END IF;
      IF OE_GLOBALS.Equal(l_old_item_id, l_rsv_tbl(I).inventory_item_id) AND OE_GLOBALS.Equal(l_old_warehouse, l_rsv_tbl(I).ship_from_org_id) AND OE_GLOBALS.Equal(l_old_subinventory, l_rsv_tbl(I).subinventory) AND OE_GLOBALS.Equal(l_old_org_id,l_rsv_tbl(I).org_id) THEN --4759251
        -- 6814153
        IF p_reservation_mode ='PARTIAL' THEN
          L_SALES_ORDER_ID   := OE_SCHEDULE_UTIL.GET_MTL_SALES_ORDER_ID(L_RSV_TBL(I).HEADER_ID);
          FND_FILE.PUT_LINE(FND_FILE.LOG,'Before: Get_Reserved_Quantities');
          OE_LINE_UTIL.Get_Reserved_Quantities(p_header_id => l_sales_order_id ,p_line_id => l_rsv_tbl(I).line_id ,p_org_id => l_rsv_tbl(I).ship_from_org_id ,x_reserved_quantity => l_reserved_quantity ,x_reserved_quantity2 => l_reserved_quantity2);
          -- Derive the quantity to be reserved
          l_rsv_tbl(I).derived_reserved_qty := l_rsv_tbl(I).ordered_qty - NVL(l_reserved_quantity,0);
          l_rsv_tbl(I).derived_reserved_qty2 -- INVCONV
          := l_rsv_tbl(I).ordered_qty2 - NVL(l_reserved_quantity2,0);
          -- Partial Reservation
          -- Reservation exists for the line. Set the flag
          IF l_reserved_quantity             > 0 THEN
            l_rsv_tbl(I).reservation_exists := 'Y';
          END IF;
        END IF;
        IF NVL(l_rsv_tbl(I).reservation_exists,'N')         = 'Y' AND p_partial_preference = 'Y' THEN
          l_temp_par_rsv_tbl(l_temp_par_rsv_tbl.COUNT + 1) := l_rsv_tbl(I);
        ELSE
          l_temp_rsv_tbl(l_temp_rsv_tbl.COUNT + 1) := l_rsv_tbl(I);
        END IF;
      ELSE
        IF l_temp_rsv_tbl.COUNT       > 0 OR l_temp_par_rsv_tbl.COUNT > 0 THEN -- 6814153
          IF L_TEMP_PAR_RSV_TBL.COUNT > 0 THEN                                 --10241113
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Before1: Prepare_And_Reserve');
            Prepare_And_Reserve(p_rsv_tbl => l_temp_par_rsv_tbl, p_percent => l_percent, p_reservation_mode => p_reservation_mode, p_reserve_run_type => p_reserve_run_type, p_reserve_set_name => p_reserve_set_name);
            IF p_reserve_run_type ='SIMULATE' AND OE_GLOBALS.Equal(l_old_item_id, l_rsv_tbl(I).inventory_item_id) AND OE_GLOBALS.Equal(l_old_warehouse, l_rsv_tbl(I).ship_from_org_id) AND OE_GLOBALS.Equal(l_old_org_id,l_rsv_tbl(I).org_id) -- 4759251
              AND NOT OE_GLOBALS.Equal(l_old_subinventory, l_rsv_tbl(I).subinventory) THEN
              G_Total_Consumed    := G_Total_Consumed + G_Consumed_for_Lot;
              G_Consumed_for_Lot  := 0;
              G_Total_Consumed2   := G_Total_Consumed2 + G_Consumed_for_Lot2; -- INVCONV  from code review by AK
              G_Consumed_for_Lot2 := 0;
            ELSE
              G_Total_Consumed    :=0;
              G_Consumed_for_Lot  := 0;
              G_Total_Consumed2   :=0; -- INVCONV  from code review by AK
              G_Consumed_for_Lot2 := 0;
            END IF;
          END IF;
          IF L_TEMP_RSV_TBL.COUNT > 0 THEN --10241113
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Before2: Prepare_And_Reserve');
            Prepare_And_Reserve(p_rsv_tbl => l_temp_rsv_tbl, p_percent => l_percent, p_reservation_mode => p_reservation_mode, p_reserve_run_type => p_reserve_run_type, p_reserve_set_name => p_reserve_set_name);
            IF p_reserve_run_type ='SIMULATE' AND OE_GLOBALS.Equal(l_old_item_id, l_rsv_tbl(I).inventory_item_id) AND OE_GLOBALS.Equal(l_old_warehouse, l_rsv_tbl(I).ship_from_org_id) AND OE_GLOBALS.Equal(l_old_org_id,l_rsv_tbl(I).org_id) -- 4759251
              AND NOT OE_GLOBALS.Equal(l_old_subinventory, l_rsv_tbl(I).subinventory) THEN
              G_Total_Consumed    := G_Total_Consumed + G_Consumed_for_Lot;
              G_Consumed_for_Lot  := 0;
              G_Total_Consumed2   := G_Total_Consumed2 + G_Consumed_for_Lot2; -- INVCONV  from code review by AK
              G_Consumed_for_Lot2 := 0;
            ELSE
              G_Total_Consumed    :=0;
              G_Consumed_for_Lot  := 0;
              G_Total_Consumed2   :=0; -- INVCONV  from code review by AK
              G_Consumed_for_Lot2 := 0;
            END IF;
          END IF; --10241113
        END IF;
        COMMIT;
        l_temp_rsv_tbl.DELETE;
        l_temp_par_rsv_tbl.DELETE;                       --10241113
        l_old_item_id      := l_rsv_tbl(I).inventory_item_id; --Pack J
        l_old_warehouse    := l_rsv_tbl(I).ship_from_org_id;
        l_old_subinventory := l_rsv_tbl(I).subinventory;
        l_old_org_id       := l_rsv_tbl(I).org_id;
        -- l_temp_rsv_tbl(1) := l_rsv_tbl(I);
        IF p_reservation_mode ='PARTIAL' THEN
          L_SALES_ORDER_ID   := OE_SCHEDULE_UTIL.GET_MTL_SALES_ORDER_ID(L_RSV_TBL(I).HEADER_ID);
          FND_FILE.PUT_LINE(FND_FILE.LOG,'Before2: Get_Reserved_Quantities');
          OE_LINE_UTIL.Get_Reserved_Quantities(p_header_id => l_sales_order_id ,p_line_id => l_rsv_tbl(I).line_id ,p_org_id => l_rsv_tbl(I).ship_from_org_id ,x_reserved_quantity => l_reserved_quantity ,x_reserved_quantity2 => l_reserved_quantity2);
          -- Derive the quantity to be reserved
          l_rsv_tbl(I).derived_reserved_qty := l_rsv_tbl(I).ordered_qty - NVL(l_reserved_quantity,0);
          l_rsv_tbl(I).derived_reserved_qty2 -- INVCONV
          := l_rsv_tbl(I).ordered_qty2 - NVL(l_reserved_quantity2,0);
          -- Partial Reservation
          -- Reservation exists for the line. Set the flag
          IF l_reserved_quantity             > 0 THEN
            l_rsv_tbl(I).reservation_exists := 'Y';
          END IF;
        END IF;
        IF NVL(l_rsv_tbl(I).reservation_exists,'N') = 'Y' AND p_partial_preference = 'Y' THEN
          l_temp_par_rsv_tbl(1)                    := l_rsv_tbl(I);
        ELSE
          l_temp_rsv_tbl(1) := l_rsv_tbl(I);
        END IF;
      END IF;
    END LOOP;
    IF l_temp_rsv_tbl.COUNT       > 0 OR l_temp_par_rsv_tbl.COUNT > 0 THEN --- 6814153
      IF L_TEMP_PAR_RSV_TBL.COUNT > 0 THEN
        FND_FILE.PUT_LINE(FND_FILE.LOG,'Before3: Prepare_And_Reserve');
        Prepare_And_Reserve(p_rsv_tbl => l_temp_par_rsv_tbl, p_percent => l_percent, p_reservation_mode => p_reservation_mode, p_reserve_run_type => p_reserve_run_type, p_reserve_set_name => p_reserve_set_name);
        IF p_reserve_run_type  ='SIMULATE' THEN
          G_Total_Consumed    := G_Total_Consumed + G_Consumed_for_Lot;
          G_Consumed_for_Lot  := 0;
          G_Total_Consumed2   := G_Total_Consumed2 + G_Consumed_for_Lot2; -- INVCONV  from code review by AK
          G_Consumed_for_Lot2 := 0;
        ELSE
          G_Total_Consumed    :=0;
          G_Consumed_for_Lot  := 0;
          G_Total_Consumed2   :=0;
          G_Consumed_for_Lot2 := 0;
        END IF;
      END IF;
      FND_FILE.PUT_LINE(FND_FILE.LOG,'Before4: Prepare_And_Reserve');
      Prepare_And_Reserve(p_rsv_tbl => l_temp_rsv_tbl, p_percent => l_percent, p_reservation_mode => p_reservation_mode, p_reserve_run_type => p_reserve_run_type, p_reserve_set_name => p_reserve_set_name);
    END IF;
  END IF; -- Pack J
  --R12.MOAC
  IF p_selected_ids IS NOT NULL THEN
    DELETE FROM oe_rsv_set_details WHERE reservation_set_id = p_selected_ids;
  END IF;
  COMMIT;
  <<END_OF_PROCESS>>
  IF l_debug_level > 0 THEN
    OE_DEBUG_PUB.ADD('Exiting Reserve procedure ',1);
    FND_FILE.PUT_LINE(FND_FILE.LOG,'Exiting Reserve procedure');
  END IF;
EXCEPTION
WHEN OTHERS THEN
  IF l_debug_level > 0 THEN
    OE_DEBUG_PUB.ADD('Inside the When Others Execption',1);
    FND_FILE.PUT_LINE(FND_FILE.LOG,'Inside the When Others Execption');
    OE_DEBUG_PUB.Add(SUBSTR(sqlerrm, 1, 2000));
  END IF;
END RESERVE;
END XXHEMO_RESERVE_CONC;
/

