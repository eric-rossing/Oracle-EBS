create or replace PACKAGE body XXHA_User_Maintenance_pkg
AS
  --$Header$
  /*******************************************************************************************
  *Program Name: XXHA_User_Maintenance_pkg
  *
  *Description: This package automates manual steps done during the off-boarding (termination) process
  *       a) end date user's login account
  *
  *Created By: David Lund
  *Date:   JAN-24-2011
  *
  *Modification Log:
  *Developer            Date                 Description
  *-----------------    ------------------   ------------------------------------------------
  * David Lund          Jan-24-2011          Created this Package
  * David Lund          Oct-24-2011          Added auto_assign and assign_ess procedures
  * David Lund          Nov-21-2011          changed auto_assign to remove the europe restriction
  * David Lund          Feb-02-2012          Added procedure populate_def_po_acct
  * Manuel Fernandes    Jul-10-2012          changed auto_assign to remove end date if assignment exists
  * Venkatesh Sarangam  Apr-05-2013          Added procedure assign_mss
  * David Lund          May-01-2013          Changed auto_assign MSS to remove end date if assignment exists
  * Bruce Marcoux       Jun-28-2013          Added procedure revoke_ess
  * Manuel Fernandes    Dec-03-2013          Added "assign_responsibility('HAE_CWK_MAINTENANCE');" in auto_assign
  * Manuel Fernandes    May-14-2014          Added procedure end_responsibility_assignments
  *                                          End Date all responsibilty assignments for terminated
  *                                          Users terminated date is 14 days prior to to-date
  *                                          Added "assign_responsibility('HAE_CWK_MAINTENANCE');" in auto_assign
  * Divya Kantem        Jun-30-2015          Fixed the Start date in "assign_responsibility" (Incident #INC0055908)
  * Apps Associates     Apr-01-2015          Added Procedure 'XXHA_UNASSIGN_ROLE' for Removing roles associated with Oracle Installed Base responsibility
  * Preethi Revalli     Apr-23-2015          Added procedure xxha_endate_subinv for end dating the subinventories of terminated users
  * Preethi Revalli     Apr-30-2015          Added procedure xxha_endate_buyer for end dating the buyer setup for terminated users
  * Krishna Murthy      Aug-10-2015          Added procedure xxha_del_user_apprgroup for deleting terminated user from approver group
  * Divya Kantem        Aug-25-2015          Fixed the issue with end dating buyers for the persons which are not supposed to
  * Krishna Murthy      Aug-10-2015          Added procedure xxha_del_user_apprgroup for deleting terminated user from approver group
  * Krishna Murthy      Aug-21-2015          Added procedure xxha_Endate_SaleRep for End Dating Sales Representative
  * Divya Kantem        Aug-21-2015          Added procedure xxha_enduser_apsp to end date user in APSP instance
  * Bruce Marcoux       Apr-20-2018          Modified package for Workday Processing
  *                                          - Assign Manager Self Service Responsibility if not already assigned (PROCEDURE assign_mss) – Comment out code
  *                                          - Remove Employee Self Service Responsibility for non-employees (CWK) (PROCEDURE REVOKE_ESS) – Comment out code
  *Vijay Medikonda      21-Apr-2020          Modified end date responsibility cursor to include all scenarios who does not have employee
  *Sriram Ganesan       05-Jun-2020          Replaced sysdate by fnd user end date for responsibility end date
  *******************************************************************************************/
  --
PROCEDURE Main(
    errbuf OUT VARCHAR2 ,
    retcode OUT NUMBER ,
    p_person_id NUMBER ,
    p_user_name VARCHAR2)
IS
  --
BEGIN
  --initialize for last update data
  FND_GLOBAL.APPS_INITIALIZE(fnd_global.user_id, fnd_global.resp_id, fnd_global.resp_appl_id);
  FND_FILE.PUT_LINE(FND_FILE.LOG,TO_CHAR(fnd_global.user_id)||' '||TO_CHAR(fnd_global.resp_id)||' '||TO_CHAR(fnd_global.resp_appl_id));
  IF p_user_name IS NOT NULL THEN
    FND_FILE.PUT_LINE(FND_FILE.LOG,'End dating user account: '||p_user_name);
    end_date_user(p_user_name);
  END IF;
  --Cancel_termed_enrollees;
END Main;
--
--*******************************************************************
--
PROCEDURE end_date_user(
    p_username VARCHAR2)
IS
  v_last_day_worked DATE;
  v_end_date        DATE;
  CURSOR c_terms
  IS
    SELECT t.person_id,
      t.user_name,
      t.last_day_worked,
      t.period_of_service_id,
      t.date_sent ,
      ppos.leaving_reason
    FROM haemo.xxha_processed_terms t,
      per_periods_of_service ppos
    WHERE t.user_name          = p_username
    AND t.period_of_service_id = ppos.period_of_service_id
    ORDER BY date_sent ;
BEGIN
  v_last_day_worked := to_date(NULL);
  FOR terms IN c_terms
  LOOP
    IF terms.leaving_reason = 'TINV' THEN
      v_last_day_worked    := terms.last_day_worked;
    ELSE
      v_last_day_worked := terms.last_day_worked + 1;
    END IF;
  END LOOP;
  SELECT end_date INTO v_end_date FROM fnd_user WHERE user_name = p_username;
  IF v_end_date IS NULL OR v_end_date > v_last_day_worked THEN
    fnd_user_pkg.UpdateUser ( x_user_name => p_username, x_owner => 'SEED', x_end_date => v_last_day_worked);
  END IF;
END end_date_user;
--
--*******************************************************************
--
PROCEDURE Cancel_termed_enrollees
IS
  --
  v_object_version_number     NUMBER;
  v_finance_line_id           NUMBER;
  v_book_status_id            NUMBER;
  v_tlf_object_version_number NUMBER;
  --
  CURSOR c_enrollments
  IS
    SELECT pep.full_name ,
      pep.employee_number ,
      s.name enrol_status ,
      ppos.ACTUAL_TERMINATION_DATE ,
      E.COURSE_START_DATE ,
      b.BOOKING_ID ,
      b.BOOKING_STATUS_TYPE_ID ,
      b.DELEGATE_PERSON_ID ,
      b.CONTACT_ID ,
      b.BUSINESS_GROUP_ID ,
      b.EVENT_ID ,
      b.CUSTOMER_ID ,
      b.AUTHORIZER_PERSON_ID ,
      b.DATE_BOOKING_PLACED ,
      b.CORESPONDENT ,
      b.INTERNAL_BOOKING_FLAG ,
      b.NUMBER_OF_PLACES ,
      b.ADMINISTRATOR ,
      b.BOOKING_PRIORITY ,
      b.COMMENTS ,
      b.CONTACT_ADDRESS_ID ,
      b.DELEGATE_CONTACT_PHONE ,
      b.DELEGATE_CONTACT_FAX ,
      b.THIRD_PARTY_CONTACT_ID ,
      b.THIRD_PARTY_CUSTOMER_ID ,
      b.THIRD_PARTY_ADDRESS_ID ,
      b.THIRD_PARTY_CONTACT_FAX ,
      b.THIRD_PARTY_CONTACT_phone ,
      b.DATE_STATUS_CHANGED ,
      b.FAILURE_REASON ,
      b.ATTENDANCE_RESULT ,
      b.LANGUAGE_ID ,
      b.SOURCE_OF_BOOKING ,
      b.SPECIAL_BOOKING_INSTRUCTIONS ,
      b.SUCCESSFUL_ATTENDANCE_FLAG ,
      b.TDB_INFORMATION_CATEGORY ,
      b.TDB_INFORMATION1 ,
      b.TDB_INFORMATION2 ,
      b.TDB_INFORMATION3 ,
      b.TDB_INFORMATION4 ,
      b.TDB_INFORMATION5 ,
      b.TDB_INFORMATION6 ,
      b.TDB_INFORMATION7 ,
      b.TDB_INFORMATION8 ,
      b.TDB_INFORMATION9 ,
      b.TDB_INFORMATION10 ,
      b.TDB_INFORMATION11 ,
      b.TDB_INFORMATION12 ,
      b.TDB_INFORMATION13 ,
      b.TDB_INFORMATION14 ,
      b.TDB_INFORMATION15 ,
      b.TDB_INFORMATION16 ,
      b.TDB_INFORMATION17 ,
      b.TDB_INFORMATION18 ,
      b.TDB_INFORMATION19 ,
      b.TDB_INFORMATION20 ,
      b.SPONSOR_PERSON_ID ,
      b.SPONSOR_ASSIGNMENT_ID ,
      b.PERSON_ADDRESS_ID ,
      b.DELEGATE_ASSIGNMENT_ID ,
      b.DELEGATE_CONTACT_EMAIL ,
      b.DELEGATE_CONTACT_ID ,
      b.THIRD_PARTY_EMAIL ,
      b.PERSON_ADDRESS_type ,
      b.LINE_ID ,
      b.ORG_ID ,
      b.DAEMON_FLAG ,
      b.DAEMON_TYPE ,
      b.OLD_EVENT_ID ,
      b.QUOTE_LINE_ID ,
      b.INTERFACE_SOURCE ,
      b.TOTAL_TRAINING_TIME ,
      b.CONTENT_PLAYER_STATUS ,
      b.SCORE ,
      b.COMPLETED_CONTENT ,
      b.TOTAL_CONTENT ,
      b.BOOKING_JUSTIFICATION_ID ,
      b.IS_HISTORY_FLAG ,
      b.ORGANIZATION_ID ,
      b.OBJECT_VERSION_NUMBER ,
      l.FINANCE_HEADER_ID ,
      l.FINANCE_LINE_ID ,
      l.CURRENCY_CODE ,
      l.STANDARD_AMOUNT ,
      l.UNITARY_AMOUNT ,
      l.MONEY_AMOUNT ,
      l.BOOKING_DEAL_ID ,
      l.OBJECT_VERSION_NUMBER tlf_obj_version_num ,
      d.TYPE ,
      av.VERSION_NAME course
    FROM ota.OTA_DELEGATE_BOOKINGS b ,
      hr.per_all_people_f pep ,
      ota.ota_offerings o ,
      ota.ota_activity_versions_tl av ,
      ota.OTA_FINANCE_LINES l ,
      ota.OTA_BOOKING_DEALS d ,
      ota.ota_events e ,
      hr.per_periods_of_service ppos ,
      hr.per_all_assignments_f asg ,
      ota.OTA_BOOKING_STATUS_TYPES_TL s
    WHERE b.DELEGATE_PERSON_ID = pep.person_id
    AND TRUNC(SYSDATE) BETWEEN pep.effective_start_date AND pep.effective_end_date
    AND b.BOOKING_STATUS_TYPE_ID = s.BOOKING_STATUS_TYPE_ID
    AND b.BOOKING_ID             = l.BOOKING_ID(+)
    AND l.BOOKING_DEAL_ID        = d.BOOKING_DEAL_ID(+)
    AND pep.person_id            = asg.person_id
    AND asg.PRIMARY_FLAG         = 'Y'
    AND ppos.ACTUAL_TERMINATION_DATE BETWEEN asg.effective_start_date AND asg.effective_end_date
    AND b.EVENT_ID            = e.event_id
    AND o.ACTIVITY_VERSION_ID = av.ACTIVITY_VERSION_ID
    AND e.parent_OFFERING_ID  = o.offering_id
    AND s.name               IN ('Enrolled','Waitlisted','Employee Request','Manager Request','Requested','Placed','Incomplete')
    AND pep.person_id         = ppos.PERSON_ID
    AND av.language           = 'US'
    AND s.language            = 'US'
    AND NOT EXISTS
      (SELECT NULL
      FROM hr.per_periods_of_service ppos2
      WHERE pep.person_id           = ppos2.person_id
      AND ppos.PERIOD_OF_SERVICE_ID < ppos2.PERIOD_OF_SERVICE_ID
      )
  AND ppos.ACTUAL_TERMINATION_DATE < TRUNC(SYSDATE)
  ORDER BY 1 ;
  --
  CURSOR c_cert_enrollments
  IS
    SELECT pep.employee_number ,
      pep.person_id ,
      pep.full_name ,
      pep.business_group_id ,
      ppos.actual_termination_date ,
      ce.certification_status_code ,
      c.name certification ,
      ce.object_version_number ,
      ce.certification_id ,
      ce.cert_enrollment_id ,
      ce.enrollment_date
    FROM OTA_CERT_ENROLLMENTS ce ,
      OTA_CERTIFICATIONS_TL c ,
      per_all_people_f pep ,
      hr.per_periods_of_service ppos ,
      hr.per_all_assignments_f asg
    WHERE ce.person_id = pep.person_id
    AND TRUNC(SYSDATE) BETWEEN pep.effective_start_date AND pep.effective_end_date
    AND ce.certification_status_code IN ('ENROLLED','CERTIFIED')
    AND c.certification_id            = ce.certification_id
    AND c.language                    = 'US'
    AND pep.person_id                 = asg.person_id
    AND asg.PRIMARY_FLAG              = 'Y'
    AND ppos.ACTUAL_TERMINATION_DATE BETWEEN asg.effective_start_date AND asg.effective_end_date
    AND pep.person_id = ppos.PERSON_ID
    AND NOT EXISTS
      (SELECT NULL
      FROM hr.per_periods_of_service ppos2
      WHERE pep.person_id           = ppos2.person_id
      AND ppos.PERIOD_OF_SERVICE_ID < ppos2.PERIOD_OF_SERVICE_ID
      )
  AND ppos.ACTUAL_TERMINATION_DATE < TRUNC(SYSDATE) ;
  --
BEGIN
  BEGIN
    --
    fnd_file.put_line(FND_FILE.OUTPUT,'**********************************************************************');
    fnd_file.put_line(FND_FILE.OUTPUT,'The following employees have terminated but have active class enrollments');
    fnd_file.put_line(FND_FILE.OUTPUT,'Updating status to Cancelled.');
    fnd_file.put_line(FND_FILE.OUTPUT,'**********************************************************************');
    --
    FOR enrol IN c_enrollments
    LOOP
      --
      fnd_file.put_line(FND_FILE.OUTPUT,'Employee: '||enrol.employee_number||' '||enrol.full_name||' Course: '||enrol.course);
      --
      SELECT s.BOOKING_STATUS_TYPE_ID
      INTO v_book_status_id
      FROM ota.OTA_BOOKING_STATUS_TYPES s
      WHERE s.BUSINESS_GROUP_ID = enrol.business_group_id
      AND s.ACTIVE_FLAG         = 'Y'
      AND s.name                = 'Cancelled';
      --
      v_finance_line_id           := NULL;
      v_tlf_object_version_number := enrol.tlf_obj_version_num;
      v_object_version_number     := enrol.object_version_number;
      --
      apps.OTA_DELEGATE_BOOKING_API.update_delegate_booking (p_validate => false ,p_effective_date => enrol.date_booking_placed ,p_booking_id => enrol.booking_id ,p_booking_status_type_id => v_book_status_id ,p_delegate_person_id => enrol.delegate_person_id ,p_contact_id => enrol.contact_id ,p_business_group_id => enrol.business_group_id ,p_event_id => enrol.event_id ,p_customer_id => enrol.customer_id ,p_authorizer_person_id => enrol.authorizer_person_id ,p_date_booking_placed => enrol.date_booking_placed ,p_corespondent => enrol.corespondent ,p_internal_booking_flag => enrol.internal_booking_flag ,p_number_of_places => enrol.number_of_places ,p_object_version_number => v_object_version_number ,p_tfl_object_version_number => v_tlf_object_version_number ,p_administrator => enrol.administrator ,p_booking_priority => enrol.booking_priority ,p_comments => enrol.comments ,p_contact_address_id => enrol.contact_address_id ,p_delegate_contact_phone => enrol.delegate_contact_phone ,
      p_delegate_contact_fax => enrol.delegate_contact_fax ,p_third_party_customer_id => enrol.third_party_customer_id ,p_third_party_contact_id => enrol.third_party_contact_id ,p_third_party_address_id => enrol.third_party_address_id ,p_third_party_contact_phone => enrol.third_party_contact_phone ,p_third_party_contact_fax => enrol.third_party_contact_fax ,p_date_status_changed => NVL(enrol.date_status_changed,sysdate) ,p_failure_reason => enrol.failure_reason ,p_attendance_result => enrol.attendance_result ,p_language_id => enrol.language_id ,p_source_of_booking => enrol.source_of_booking ,p_special_booking_instructions => enrol.special_booking_instructions ,p_successful_attendance_flag => enrol.successful_attendance_flag ,p_tdb_information_category => enrol.tdb_information_category ,p_tdb_information1 => 'Updated to Cancelled on '||TO_CHAR(sysdate,'DD-MON-YYYY')||' due to termination' ,p_tdb_information2 => enrol.tdb_information2 ,p_tdb_information3 => enrol.tdb_information3 ,
      p_tdb_information4 => enrol.tdb_information4 ,p_tdb_information5 => enrol.tdb_information5 ,p_tdb_information6 => enrol.tdb_information6 ,p_tdb_information7 => enrol.tdb_information7 ,p_tdb_information8 => enrol.tdb_information8 ,p_tdb_information9 => enrol.tdb_information9 ,p_tdb_information10 => enrol.tdb_information10 ,p_tdb_information11 => enrol.tdb_information11 ,p_tdb_information12 => enrol.tdb_information12 ,p_tdb_information13 => enrol.tdb_information13 ,p_tdb_information14 => enrol.tdb_information14 ,p_tdb_information15 => enrol.tdb_information15 ,p_tdb_information16 => enrol.tdb_information16 ,p_tdb_information17 => enrol.tdb_information17 ,p_tdb_information18 => enrol.tdb_information18 ,p_tdb_information19 => enrol.tdb_information19 ,p_tdb_information20 => enrol.tdb_information20 ,p_update_finance_line => 'N' ,p_finance_header_id => enrol.finance_header_id ,p_currency_code => enrol.currency_code ,p_standard_amount => enrol.standard_amount ,p_unitary_amount =>
      enrol.unitary_amount ,p_money_amount => enrol.money_amount ,p_booking_deal_id => enrol.booking_deal_id ,p_booking_deal_type => enrol.type ,p_finance_line_id => v_finance_line_id ,p_enrollment_type => 'S' --student
      ,p_organization_id => enrol.organization_id ,p_sponsor_person_id => enrol.sponsor_person_id ,p_sponsor_assignment_id => enrol.sponsor_assignment_id ,p_person_address_id => enrol.person_address_id ,p_delegate_assignment_id => enrol.delegate_assignment_id ,p_delegate_contact_id => enrol.delegate_contact_id ,p_delegate_contact_email => enrol.delegate_contact_email ,p_third_party_email => enrol.third_party_email ,p_person_address_type => enrol.person_address_type ,p_line_id => enrol.line_id ,p_org_id => enrol.org_id ,p_daemon_flag => enrol.daemon_flag ,p_daemon_type => enrol.daemon_type ,p_old_event_id => enrol.old_event_id ,p_quote_line_id => enrol.quote_line_id ,p_interface_source => enrol.interface_source ,p_total_training_time => enrol.total_training_time ,p_content_player_status => enrol.content_player_status ,p_score => enrol.score ,p_completed_content => enrol.completed_content ,p_total_content => enrol.total_content ,p_booking_justification_id =>
      enrol.booking_justification_id ,p_is_history_flag => enrol.is_history_flag ,p_override_prerequisites => 'N' ,p_override_learner_access => 'N' ,p_source_cancel => NULL);
      --
    END LOOP;
    COMMIT;
  END;
  --
  BEGIN
    --
    fnd_file.put_line(FND_FILE.OUTPUT,'**********************************************************************');
    fnd_file.put_line(FND_FILE.OUTPUT,'The following employees have terminated but have active certification enrollments');
    fnd_file.put_line(FND_FILE.OUTPUT,'Updating status to Cancelled.');
    fnd_file.put_line(FND_FILE.OUTPUT,'**********************************************************************');
    --
    FOR cert_enrol IN c_cert_enrollments
    LOOP
      --
      fnd_file.put_line(FND_FILE.OUTPUT,'Employee: '||cert_enrol.employee_number||' '||cert_enrol.full_name||' Certificaton: '||cert_enrol.certification);
      --
      v_object_version_number := cert_enrol.object_version_number;
      --
      ota_cert_enrollment_api.update_cert_enrollment( p_effective_date => cert_enrol.actual_termination_date, p_cert_enrollment_id => cert_enrol.cert_enrollment_id, p_object_version_number => v_object_version_number, p_certification_id => cert_enrol.certification_id, p_person_id => cert_enrol.person_id,
      --  p_contact_id                   in number           default hr_api.g_number,
      p_certification_status_code => 'CANCELLED', p_completion_date => to_date(NULL), p_UNENROLLMENT_DATE => cert_enrol.actual_termination_date,
      --  p_EXPIRATION_DATE              in date             default hr_api.g_date,
      --  p_EARLIEST_ENROLL_DATE         in date             default hr_api.g_date,
      --  p_IS_HISTORY_FLAG              in varchar2         default hr_api.g_varchar2,
      p_business_group_id => cert_enrol.business_group_id,
      --  p_attribute_category           in varchar2         default hr_api.g_varchar2,
      --  p_attribute1                   in varchar2         default hr_api.g_varchar2,
      --  p_attribute2                   in varchar2         default hr_api.g_varchar2,
      --  p_attribute3                   in varchar2         default hr_api.g_varchar2,
      --  p_attribute4                   in varchar2         default hr_api.g_varchar2,
      --  p_attribute5                   in varchar2         default hr_api.g_varchar2,
      --  p_attribute6                   in varchar2         default hr_api.g_varchar2,
      --  p_attribute7                   in varchar2         default hr_api.g_varchar2,
      --  p_attribute8                   in varchar2         default hr_api.g_varchar2,
      --  p_attribute9                   in varchar2         default hr_api.g_varchar2,
      --  p_attribute10                  in varchar2         default hr_api.g_varchar2,
      --  p_attribute11                  in varchar2         default hr_api.g_varchar2,
      --  p_attribute12                  in varchar2         default hr_api.g_varchar2,
      --  p_attribute13                  in varchar2         default hr_api.g_varchar2,
      --  p_attribute14                  in varchar2         default hr_api.g_varchar2,
      --  p_attribute15                  in varchar2         default hr_api.g_varchar2,
      --  p_attribute16                  in varchar2         default hr_api.g_varchar2,
      --  p_attribute17                  in varchar2         default hr_api.g_varchar2,
      --  p_attribute18                  in varchar2         default hr_api.g_varchar2,
      --  p_attribute19                  in varchar2         default hr_api.g_varchar2,
      --  p_attribute20                  in varchar2         default hr_api.g_varchar2,
      p_enrollment_date => cert_enrol.enrollment_date, p_validate => false);
      --
    END LOOP;
    COMMIT;
  END;
  --
END Cancel_termed_enrollees;
--****************************************************************
--
PROCEDURE assign_responsibility(
    p_responsibility_key VARCHAR2)
IS
  CURSOR cu(x_responsibility_key VARCHAR2)
  IS
    SELECT --ppf.person_id, ppf.full_name,
      DISTINCT paf.supervisor_id,
      supervisor.full_name,
      u.user_name,
      u.user_id,
      upper(hr_person_type_usage_info.get_user_person_type(supervisor.effective_end_date, supervisor.person_id)) Supervisor_employee_type,
      greatest(supervisor.effective_start_date, TRUNC(sysdate)) start_date_for_access
    FROM per_all_people_f ppf,
      per_assignments_f2 paf,
      per_all_people_f supervisor,
      fnd_user u
    WHERE upper(hr_person_type_usage_info.get_user_person_type(ppf.effective_end_date, ppf.person_id)) LIKE '%HAE%CONTINGENT%WORKER%'
    AND ( (TRUNC(sysdate) BETWEEN ppf.effective_start_date AND ppf.effective_end_date)
    OR ( ppf.effective_start_date BETWEEN TRUNC(sysdate) AND ppf.effective_end_date) )
    AND paf.person_id = ppf.person_id
    AND ( ( TRUNC(sysdate) BETWEEN paf.effective_start_date AND paf.effective_end_date)
    OR ( ppf.effective_start_date BETWEEN TRUNC(sysdate) AND paf.effective_end_date) )
    AND paf.assignment_type IN ('E','C')
    AND supervisor.person_id = paf.supervisor_id
    AND ( (TRUNC(sysdate) BETWEEN supervisor.effective_start_date AND supervisor.effective_end_date)
    OR ( supervisor.effective_start_date BETWEEN TRUNC(sysdate) AND supervisor.effective_end_date) )
    AND SUPERVISOR.PERSON_ID = U.EMPLOYEE_ID
    AND upper(hr_person_type_usage_info.get_user_person_type(supervisor.effective_end_date, supervisor.person_id)) LIKE 'EMPLOYEE%'
      --and u.user_name = 'VSAMBA'
    AND NOT EXISTS
      (SELECT 1
      FROM fnd_responsibility_vl r,
        applsys.WF_USER_ROLE_ASSIGNMENTS ra
      WHERE u.user_name          = ra.user_name
      AND ra.role_orig_system    = 'FND_RESP'
      AND ra.role_orig_system_id = r.responsibility_id
        --and   (ra.end_date is null or ra.end_date > trunc(sysdate))
      AND ra.end_date         IS NULL
      AND r.responsibility_key = x_responsibility_key
      )
  --and paf.supervisor_id in (7841,2841)
  UNION
  SELECT DISTINCT supervisor.person_id supervisor_id,
    supervisor.full_name,
    u.user_name,
    u.user_id,
    upper(hr_person_type_usage_info.get_user_person_type(supervisor.effective_end_date, supervisor.person_id)) Supervisor_employee_type,
    greatest(supervisor.effective_start_date, TRUNC(sysdate)) start_date_for_access
  FROM per_all_people_f supervisor,
    fnd_user u
  WHERE ( (TRUNC(sysdate) BETWEEN supervisor.effective_start_date AND supervisor.effective_end_date)
  OR ( supervisor.effective_start_date BETWEEN TRUNC(sysdate) AND supervisor.effective_end_date) )
  AND SUPERVISOR.PERSON_ID = U.EMPLOYEE_ID
  AND upper(hr_person_type_usage_info.get_user_person_type(supervisor.effective_end_date, supervisor.person_id)) LIKE 'EMPLOYEE%'
  AND 1 = 2 -- ******DISABLE ALL EMPLOYEES FOR NOW
  AND NOT EXISTS
    (SELECT 1
    FROM fnd_responsibility_vl r,
      applsys.WF_USER_ROLE_ASSIGNMENTS ra
    WHERE u.user_name          = ra.user_name
    AND ra.role_orig_system    = 'FND_RESP'
    AND ra.role_orig_system_id = r.responsibility_id
      --and   (ra.end_date is null or ra.end_date > trunc(sysdate))
    AND ra.end_date         IS NULL
    AND r.responsibility_key = x_responsibility_key
    ) ;
  CURSOR cr(x_responsibility_key VARCHAR2, x_start_date DATE, x_user_name VARCHAR2)
  IS
    SELECT r.responsibility_id,
      r.application_id,
      r.start_date,
      ra.user_name, -- if null insert assignment
      ra.start_date exisiting_start_date
    FROM fnd_responsibility_vl r,
      applsys.WF_USER_ROLE_ASSIGNMENTS ra
    WHERE r.responsibility_key    = x_responsibility_key
    AND (r.end_date              IS NULL
    OR r.end_date                >= x_start_date)
    AND ra.role_orig_system(+)    = 'FND_RESP'
    AND ra.role_orig_system_id(+) = r.responsibility_id
    AND ra.user_name(+)           = x_user_name ;
BEGIN
  fnd_file.put_line(FND_FILE.OUTPUT,'**********************************************************************');
  fnd_file.put_line(FND_FILE.OUTPUT,'Assigning Responsibility :'||p_responsibility_key);
  fnd_file.put_line(FND_FILE.OUTPUT,'**********************************************************************');
  FOR u IN cu(p_responsibility_key)
  LOOP
    FOR r IN cr(p_responsibility_key, u.start_date_for_access, u.user_name)
    LOOP
      IF r.user_name IS NULL THEN
        fnd_user_resp_groups_api.insert_assignment( user_id => u.user_id, responsibility_id => r.responsibility_id, responsibility_application_id => r.application_id, security_group_id => 0, start_date => NVL(r.exisiting_start_date,u.start_date_for_access),--r.exisiting_start_date, --u.start_date_for_access,
        end_date => NULL, description => 'Auto-Activated Access');
        dbms_output.put_line('New Assignment - Supervisor: '||u.full_name ||' ('||u.user_name||')');
        fnd_file.put_line(FND_FILE.OUTPUT,'New Assignment - Supervisor: '||u.full_name ||' ('||u.user_name||')');
      ELSE
        fnd_user_resp_groups_api.update_assignment( user_id => u.user_id, responsibility_id => r.responsibility_id, responsibility_application_id => r.application_id, security_group_id => 0, start_date => u.start_date_for_access, end_date => NULL, description => 'Auto-Activated Access');
        dbms_output.put_line('Updated Assignment - Supervisor: '||u.full_name ||' ('||u.user_name||')');
        fnd_file.put_line(FND_FILE.OUTPUT,'Updated Assignment - Supervisor: '||u.full_name ||' ('||u.user_name||')');
      END IF;
    END LOOP;
  END LOOP;
END assign_responsibility;
--****************************************************************
--
PROCEDURE end_responsibility_assignments
IS
  CURSOR cu
  IS
  SELECT distinct 
      u.user_name ,
      u.user_id ,
      u.end_date -- Added By Sriram Ganesan to give user end date in responsibility instead of sysdate
    FROM 
      apps.fnd_user u
    WHERE 1=1
    and u.end_date is not null
    AND u.end_date <= TRUNC(SYSDATE)-14
--and u.user_name='OP_SYSADMIN'
    AND EXISTS
      (SELECT 1
      FROM 
        FND_RESPONSIBILITY_TL R,
        FND_USER_RESP_GROUPS_DIRECT RA
      WHERE 1=1
      AND RA.RESPONSIBILITY_ID             = R.RESPONSIBILITY_ID
      AND R.LANGUAGE                       = 'US'
      AND Ra.RESPONSIBILITY_APPLICATION_ID = r.application_id
      AND ra.user_id                        = u.user_id
      AND (RA.END_DATE      IS NULL
      OR RA.END_DATE         > TRUNC(SYSDATE)) );
      
    CURSOR CR(X_USER_ID NUMBER)
    IS
      /*     select ra.start_date, ra.end_date, r.responsibility_id, r.application_id, r.responsibility_name, ra
      from  fnd_user u, fnd_responsibility_tl r, applsys.WF_USER_ROLE_ASSIGNMENTS ra
      where u.user_name = ra.user_name
      and   ra.role_orig_system = 'FND_RESP'
      and   ra.role_orig_system_id = r.responsibility_id
      and   r.language = 'US'
      and   u.user_id = x_user_id
      --and   u.user_id = 19714
      and   (ra.end_date is null or ra.end_date > trunc(sysdate))
      */
      SELECT RA.START_DATE,
        RA.END_DATE,
        R.RESPONSIBILITY_ID,
        R.APPLICATION_ID,
        R.RESPONSIBILITY_NAME,
        RA.security_group_id
      FROM FND_USER U,
        FND_RESPONSIBILITY_TL R,
        FND_USER_RESP_GROUPS_DIRECT RA
      WHERE u.user_id                      = ra.user_id
      AND RA.RESPONSIBILITY_ID             = R.RESPONSIBILITY_ID
      AND R.LANGUAGE                       = 'US'
      AND Ra.RESPONSIBILITY_APPLICATION_ID = r.application_id
      AND u.user_id                        = x_user_id
        --and   u.user_id = 19714
      AND (RA.END_DATE      IS NULL
      OR RA.END_DATE         > TRUNC(SYSDATE)) ;
    v_process_counts NUMBER := 0;
  BEGIN
    FND_FILE.PUT_LINE(FND_FILE.LOG,'End Date User Responsibility Assignments');
    FOR u IN cu
    LOOP
      FND_FILE.PUT_LINE(FND_FILE.LOG,'Username: '||u.user_name);
      FOR r IN cr(u.user_id)
      LOOP
        FND_FILE.PUT_LINE(FND_FILE.LOG,'Responsibility to End date: '||r.responsibility_name);
--        fnd_user_resp_groups_api.update_assignment( user_id => u.user_id, responsibility_id => r.responsibility_id, RESPONSIBILITY_APPLICATION_ID => R.APPLICATION_ID, security_group_id => r.security_group_id, start_date => r.start_date, end_date => TRUNC(sysdate), description => 'Terminated user');
 -- Added By Sriram Ganesan to give user end date in responsibility instead of sysdate
        fnd_user_resp_groups_api.update_assignment( user_id => u.user_id, responsibility_id => r.responsibility_id, RESPONSIBILITY_APPLICATION_ID => R.APPLICATION_ID, security_group_id => r.security_group_id, start_date => r.start_date, end_date => u.end_date, description => 'Terminated user');        
        v_process_counts := v_process_counts +1;
      END LOOP;
    END LOOP;
    FND_FILE.PUT_LINE(FND_FILE.LOG,'Records End Dated: '||TO_CHAR(v_process_counts));
  END END_RESPONSIBILITY_ASSIGNMENTS;
  --****************************************************************
  --
PROCEDURE Auto_assign(
    errbuf OUT VARCHAR2 ,
    retcode OUT NUMBER)
IS
  --Cursor to pick persons who are terminated
  CURSOR C_edu
  IS
    SELECT DISTINCT u.user_name ,
      u.user_id,
      pep.full_name
    FROM hr.per_all_people_f pep ,
      per_business_groups bg ,
      hr.per_all_assignments_f asg ,
      hr.per_periods_of_service ppos ,
      apps.fnd_user u
    WHERE sysdate BETWEEN pep.effective_start_date AND pep.effective_end_date
    AND pep.person_id = asg.person_id
    AND pep.person_id = u.employee_id
      --AND sysdate                      >= asg.effective_end_date
      --AND sysdate BETWEEN asg.effective_start_date AND asg.effective_end_date
    AND ((sysdate     >= asg.effective_end_date
    AND TRUNC(sysdate) = TRUNC(asg.last_update_date))
    OR (sysdate BETWEEN asg.effective_start_date AND asg.effective_end_date))
    AND asg.PERIOD_OF_SERVICE_ID      = ppos.PERIOD_OF_SERVICE_ID
    AND PPOS.ACTUAL_TERMINATION_DATE IS NOT NULL
    AND PPOS.ACTUAL_TERMINATION_DATE <= sysdate
    AND pep.business_group_id         = bg.business_group_id
    AND (u.end_date                  IS NULL
    OR u.end_date                    >= sysdate);
BEGIN
  --initialize for last update data
  FND_GLOBAL.APPS_INITIALIZE(fnd_global.user_id, fnd_global.resp_id, fnd_global.resp_appl_id);
  FND_FILE.PUT_LINE(FND_FILE.LOG,TO_CHAR(fnd_global.user_id)||' '||TO_CHAR(fnd_global.resp_id)||' '||TO_CHAR(fnd_global.resp_appl_id));
  ASSIGN_ESS;
  POPULATE_DEF_PO_ACCT;
--ASSIGN_MSS; -- Bruce Marcoux - Apr-20-2018 - Modified package for Workday Processing
  -- Revoke "Employee Self Service" from CWK people
--REVOKE_ESS; -- Bruce Marcoux - Apr-20-2018 - Modified package for Workday Processing
  -- End Date all responsibilty Assignments for Terminated users
  END_RESPONSIBILITY_ASSIGNMENTS;
  assign_responsibility('HAE_CWK_MAINTENANCE');
  -- Offboarding
  FOR Rec_edu IN C_edu
  LOOP
    FND_FILE.PUT_LINE(FND_FILE.LOG,'********************************************' );
    FND_FILE.PUT_LINE(FND_FILE.LOG,'End Dating the Sales Representative: '||Rec_edu.full_name);
    xxha_Endate_SaleRep(Rec_edu.full_name);
    FND_FILE.PUT_LINE(FND_FILE.LOG,'Remove roles associated with Oracle Installed Base responsibility: '||Rec_edu.user_name);
    XXHA_UNASSIGN_ROLE(Rec_edu.user_name);
    FND_FILE.PUT_LINE(FND_FILE.LOG,'End dating all assigned subinventories: '||Rec_edu.user_name);
    xxha_endate_subinv(Rec_edu.user_name);
    FND_FILE.PUT_LINE(FND_FILE.LOG,'End dating the buyer account for terminated user: '||Rec_edu.user_name);
    xxha_endate_buyer(Rec_edu.user_name);
    FND_FILE.PUT_LINE(FND_FILE.LOG,'Deleting the terminated user from Approver Group: '||Rec_edu.user_name);
    xxha_del_user_apprgroup(Rec_edu.user_name);
    FND_FILE.PUT_LINE(FND_FILE.LOG,'End Date User in APSD: '||Rec_edu.user_name);
    xxha_enduser_apsp(Rec_edu.user_name);
  END LOOP;
END Auto_assign;
--****************************************************************
--
PROCEDURE assign_ess
IS
  /**********************************************************************
  This procedure checks for employees who do not currently have
  the Employee Self Service responsibility by location assigned.
  It will assign the role which contains the responsibility.
  **********************************************************************/
  --
  -- variables
  --
  --v_role varchar2(200) := 'UMX|HAE_ALL_EMPLOYEES';
  v_resp_id      NUMBER;
  v_app_id       NUMBER;
  v_BIZ_GROUP_ID NUMBER;
  v_start_date   DATE;
  v_end_date     DATE;
  --
  -- cursors
  --
  CURSOR c_emps
  IS
    SELECT pep.BUSINESS_GROUP_ID ,
      pep.employee_number ,
      pep.full_name ,
      u.user_name ,
      u.user_id
    FROM hr.per_all_people_f pep ,
      per_business_groups bg ,
      hr.per_all_assignments_f asg ,
      hr.per_periods_of_service ppos ,
      apps.fnd_user u
    WHERE sysdate BETWEEN pep.effective_start_date AND pep.effective_end_date
    AND pep.person_id = asg.person_id
    AND pep.person_id = u.employee_id
    AND sysdate BETWEEN asg.effective_start_date AND asg.effective_end_date
    AND asg.PERIOD_OF_SERVICE_ID                    = ppos.PERIOD_OF_SERVICE_ID
    AND NVL(ppos.ACTUAL_TERMINATION_DATE,sysdate+1) > TRUNC(sysdate)
    AND u.END_DATE                                 IS NULL
      ------- exclude users that are not actually employees
    AND hr_person_type_usage_info.get_user_person_type (SYSDATE,pep.person_id) LIKE 'Employee%'
      ------- check for existing role or responsibility by business group
    AND NOT EXISTS
      (SELECT NULL
      FROM applsys.WF_USER_ROLE_ASSIGNMENTS ra
      WHERE ra.role_orig_system  = 'FND_RESP'
      AND ra.role_orig_system_id =
        (SELECT responsibility_id
        FROM fnd_responsibility_tl
        WHERE responsibility_name = 'Haemonetics Employee Self Service'
        AND application_id        = 800
        AND language              = 'US'
        )
    AND NVL(ra.END_DATE,sysdate+1) > sysdate
    AND u.user_name                = ra.user_name
      )
    AND pep.business_group_id = bg.business_group_id
      --    and bg.name in ('BG_US','BG_CA','BG_KR','BG_CN','BG_JP','BG_TW','BG_GB','BG_HK')
      ;
    --
  BEGIN
    SELECT responsibility_id,
      application_id
    INTO v_resp_id,
      v_app_id
    FROM fnd_responsibility_tl
    WHERE responsibility_name = 'Haemonetics Employee Self Service'
    AND language              = 'US';
    FOR emps IN c_emps
    LOOP
      SELECT ur.start_date,
        ur.end_date
      INTO v_start_date,
        v_end_date
      FROM fnd_responsibility_tl r,
        FND_USER_RESP_GROUPS_DIRECT ur
      WHERE r.responsibility_id               = v_resp_id
      AND r.application_id                    = v_app_id
      AND r.language                          = 'US'
      AND ur.responsibility_id (+)            = r.responsibility_id
      AND ur.responsibility_application_id(+) = r.application_id
      AND ur.user_id(+)                       = emps.user_id ;
      IF v_start_date                        IS NULL THEN
        fnd_user_resp_groups_api.insert_assignment( user_id => emps.user_id, responsibility_id => v_resp_id, responsibility_application_id => v_app_id, security_group_id => 0, start_date => sysdate, end_date => NULL, description => NULL);
      elsif v_end_date IS NOT NULL THEN
        fnd_user_resp_groups_api.update_assignment( user_id => emps.user_id, responsibility_id => v_resp_id, responsibility_application_id => v_app_id, security_group_id => 0, start_date => v_start_date, end_date => NULL, description => NULL);
      END IF;
    END LOOP; --c_emps
    -----------------------------------------------------------------------
  END assign_ess;
  --****************************************************************
PROCEDURE assign_mss
IS
  /**********************************************************************
  This procedure checks for employees present as super visor or
  employees not present as super visor who do not currently have
  the Manager Self Service responsibility by location assigned.
  It will assign the role which contains the responsibility.
  **********************************************************************/
  --
  -- variables
  --
  --v_role varchar2(200) := 'UMX|HAE_ALL_EMPLOYEES';
  v_resp_id       NUMBER;
  v_app_id        NUMBER;
  v_BIZ_GROUP_ID  NUMBER;
  v_start_date    DATE;
  V_END_DATE      DATE;
  v_biz_group_id1 NUMBER;
  v_start_date1   DATE;
  v_end_date1     DATE;
  v_cnt           NUMBER;
  --
  -- cursors
  --
  CURSOR c_sup
  IS
    SELECT pep.BUSINESS_GROUP_ID ,
      pep.employee_number ,
      pep.full_name ,
      u.user_name ,
      u.user_id ,
      asg.PERSON_ID
    FROM hr.per_all_people_f pep ,
      per_business_groups bg ,
      hr.per_all_assignments_f asg ,
      hr.per_periods_of_service ppos ,
      apps.fnd_user u
    WHERE sysdate BETWEEN pep.effective_start_date AND pep.effective_end_date
    AND PEP.PERSON_ID = ASG.PERSON_ID
    AND PEP.PERSON_ID = U.EMPLOYEE_ID
      -- and ASG.SUPERVISOR_ID = U.EMPLOYEE_ID
      --and ASG.SUPERVISOR_ID is not null
    AND sysdate BETWEEN asg.effective_start_date AND asg.effective_end_date
    AND asg.PERIOD_OF_SERVICE_ID                    = ppos.PERIOD_OF_SERVICE_ID
    AND NVL(ppos.ACTUAL_TERMINATION_DATE,sysdate+1) > TRUNC(sysdate)
    AND u.END_DATE                                 IS NULL
      ------- exclude users that are not actually employees
    AND hr_person_type_usage_info.get_user_person_type (SYSDATE,pep.person_id) LIKE 'Employee%'
      ------- check for existing role or responsibility by business group
    AND NOT EXISTS
      (SELECT NULL
      FROM applsys.WF_USER_ROLE_ASSIGNMENTS ra
      WHERE ra.role_orig_system  = 'FND_RESP'
      AND ra.role_orig_system_id =
        (SELECT responsibility_id
        FROM fnd_responsibility_tl
        WHERE responsibility_name = 'Manager Self Service'
        AND application_id        = 800
        AND language              = 'US'
        )
    AND NVL(ra.END_DATE,sysdate+1) > sysdate
    AND u.user_name                = ra.user_name
      )
    AND pep.business_group_id = bg.business_group_id
      --    and bg.name in ('BG_US','BG_CA','BG_KR','BG_CN','BG_JP','BG_TW','BG_GB','BG_HK')
      ;
    --
    CURSOR c_sup1
    IS
      SELECT pep.BUSINESS_GROUP_ID ,
        pep.employee_number ,
        pep.full_name ,
        u.user_name ,
        u.user_id ,
        asg.PERSON_ID
      FROM hr.per_all_people_f pep ,
        per_business_groups bg ,
        hr.per_all_assignments_f asg ,
        hr.per_periods_of_service ppos ,
        apps.fnd_user u
      WHERE sysdate BETWEEN pep.effective_start_date AND pep.effective_end_date
      AND PEP.PERSON_ID = ASG.PERSON_ID
      AND PEP.PERSON_ID = U.EMPLOYEE_ID
        -- and ASG.SUPERVISOR_ID = U.EMPLOYEE_ID
        --and ASG.SUPERVISOR_ID is null
      AND sysdate BETWEEN asg.effective_start_date AND asg.effective_end_date
      AND asg.PERIOD_OF_SERVICE_ID                    = ppos.PERIOD_OF_SERVICE_ID
      AND NVL(ppos.ACTUAL_TERMINATION_DATE,sysdate+1) > TRUNC(sysdate)
      AND u.END_DATE                                 IS NULL
        ------- exclude users that are not actually employees
      AND hr_person_type_usage_info.get_user_person_type (SYSDATE,pep.person_id) LIKE 'Employee%'
        ------- check for existing role or responsibility by business group
      AND EXISTS
        (SELECT NULL
        FROM applsys.WF_USER_ROLE_ASSIGNMENTS ra
        WHERE ra.role_orig_system  = 'FND_RESP'
        AND ra.role_orig_system_id =
          (SELECT responsibility_id
          FROM fnd_responsibility_tl
          WHERE responsibility_name = 'Manager Self Service'
          AND application_id        = 800
          AND language              = 'US'
          )
      AND NVL(ra.END_DATE,sysdate+1) > sysdate
      AND u.user_name                = ra.user_name
        )
      AND pep.business_group_id = bg.business_group_id
        --    and bg.name in ('BG_US','BG_CA','BG_KR','BG_CN','BG_JP','BG_TW','BG_GB','BG_HK')
        ;
      --
    BEGIN
      SELECT responsibility_id,
        application_id
      INTO v_resp_id,
        v_app_id
      FROM fnd_responsibility_tl
      WHERE responsibility_name = 'Manager Self Service'
      AND language              = 'US'
      AND application_id        = 800;
      FOR sup IN c_sup
      LOOP
        BEGIN
          v_cnt := 0;
          SELECT COUNT(asg.person_id)
          INTO v_cnt
          FROM PER_ALL_ASSIGNMENTS_F asg,
            per_all_people_f pep
          WHERE asg.supervisor_id = sup.person_id
          AND asg.person_id       = pep.person_id
          AND hr_person_type_usage_info.get_user_person_type (SYSDATE,pep.person_id) LIKE 'Employee%'
          AND SYSDATE BETWEEN asg.EFFECTIVE_START_DATE AND asg.EFFECTIVE_END_DATE
          AND sysdate BETWEEN pep.effective_start_date AND pep.effective_end_date;
        END;
        IF v_cnt > 0 THEN
          SELECT ur.start_date,
            ur.end_date
          INTO v_start_date,
            v_end_date
          FROM fnd_responsibility_tl r,
            FND_USER_RESP_GROUPS_DIRECT ur
          WHERE r.responsibility_id               = v_resp_id
          AND r.application_id                    = v_app_id
          AND r.language                          = 'US'
          AND ur.responsibility_id (+)            = r.responsibility_id
          AND UR.RESPONSIBILITY_APPLICATION_ID(+) = R.APPLICATION_ID
          AND ur.user_id(+)                       = sup.user_id ;
          IF v_start_date                        IS NULL THEN
            FND_USER_RESP_GROUPS_API.INSERT_ASSIGNMENT( user_id => sup.user_id, responsibility_id => v_resp_id, responsibility_application_id => v_app_id, security_group_id => 0, start_date => sysdate, end_date => NULL, description => NULL);
            COMMIT;
            ---Dave Lund 5/1/2013 to remove end date from responsibility
          elsif v_end_date IS NOT NULL THEN
            fnd_user_resp_groups_api.update_assignment( user_id => sup.user_id, responsibility_id => v_resp_id, responsibility_application_id => v_app_id, security_group_id => 0, start_date => v_start_date, end_date => NULL, description => NULL);
          END IF;
        END IF;
      END LOOP; --c_sup
      FOR sup1 IN c_sup1
      LOOP
        BEGIN
          v_cnt := 0;
          SELECT COUNT(asg.person_id)
          INTO v_cnt
          FROM PER_ALL_ASSIGNMENTS_F asg
          WHERE asg.supervisor_id = sup1.person_id
          AND SYSDATE BETWEEN asg.EFFECTIVE_START_DATE AND asg.EFFECTIVE_END_DATE;
        END;
        IF v_cnt = 0 THEN
          SELECT UR.START_DATE,
            UR.END_DATE
          INTO v_start_date1,
            v_end_date1
          FROM FND_RESPONSIBILITY_TL R,
            FND_USER_RESP_GROUPS_DIRECT UR
          WHERE R.RESPONSIBILITY_ID               = V_RESP_ID
          AND r.application_id                    = v_app_id
          AND r.language                          = 'US'
          AND ur.responsibility_id (+)            = r.responsibility_id
          AND UR.RESPONSIBILITY_APPLICATION_ID(+) = R.APPLICATION_ID
          AND ur.user_id(+)                       = sup1.user_id ;
          IF v_start_date1                       IS NOT NULL THEN
            FND_USER_RESP_GROUPS_API.UPDATE_ASSIGNMENT( USER_ID => SUP1.USER_ID, RESPONSIBILITY_ID => V_RESP_ID, responsibility_application_id => v_app_id, SECURITY_GROUP_ID => 0, START_DATE => V_START_DATE1, end_date => sysdate, description => NULL);
            COMMIT;
          END IF;
        END IF;
      END LOOP; --c_sup1*/
      -----------------------------------------------------------------------
    END ASSIGN_MSS;
    --****************************************************************
    --
  PROCEDURE populate_def_po_acct
  IS
    /**********************************************************************
    This procedure will populate the DFF on the person record to show the
    default PO account in the Haemonetics Employee Self Service responsibility
    **********************************************************************/
    --
    -- variables
    --
    V_EFFECTIVE_START_DATE     DATE;
    V_EFFECTIVE_END_DATE       DATE;
    v_full_name                VARCHAR2(240);
    v_comment_id               NUMBER;
    v_name_combination_warning BOOLEAN;
    V_ASSIGN_PAYROLL_WARNING   BOOLEAN;
    V_ORIG_HIRE_WARNING        BOOLEAN;
    V_OBJECT_VERSION_NUMBER    NUMBER;
    v_employee_number          VARCHAR2(20);
    --
    CURSOR C_EMPS
    IS
      SELECT GCC.SEGMENT1
        ||'.'
        ||GCC.SEGMENT2
        ||'.'
        ||GCC.SEGMENT3
        ||'.'
        ||GCC.SEGMENT4
        ||'.'
        ||GCC.SEGMENT5
        ||'.'
        ||GCC.SEGMENT6 DEF_CODE ,
        ATTRIBUTE11 ,
        PEP.PERSON_ID ,
        PEP.EFFECTIVE_START_DATE ,
        PEP.OBJECT_VERSION_NUMBER ,
        pep.employee_number
      FROM PER_ALL_ASSIGNMENTS_F ASG ,
        PER_PEOPLE_X PEP ,
        gl_code_combinations gcc
      WHERE sysdate BETWEEN ASG.EFFECTIVE_START_DATE AND ASG.EFFECTIVE_END_DATE
      AND ASG.DEFAULT_CODE_COMB_ID = GCC.CODE_COMBINATION_ID
      AND ASG.PERSON_ID            = PEP.PERSON_ID
      AND GCC.SEGMENT1
        ||'.'
        ||GCC.SEGMENT2
        ||'.'
        ||GCC.SEGMENT3
        ||'.'
        ||GCC.SEGMENT4
        ||'.'
        ||GCC.SEGMENT5
        ||'.'
        ||GCC.SEGMENT6 != NVL(ATTRIBUTE11,'XXX')
        --  and ASG.PERSON_ID = 15091
        ;
  BEGIN
    FND_FILE.PUT_LINE(FND_FILE.log,'Starting Default PO assignment');
    FOR EMPS IN C_EMPS
    LOOP
      V_OBJECT_VERSION_NUMBER := EMPS.OBJECT_VERSION_NUMBER;
      v_employee_number       := emps.employee_number;
      BEGIN
        HR_PERSON_API.UPDATE_PERSON (P_VALIDATE => false ,P_EFFECTIVE_DATE => emps.EFFECTIVE_start_DATE ,P_DATETRACK_UPDATE_MODE => 'CORRECTION' ,P_PERSON_ID => EMPS.PERSON_ID ,P_OBJECT_VERSION_NUMBER => V_OBJECT_VERSION_NUMBER
        --  ,p_person_type_id               in      number   default hr_api.g_number
        --  ,p_last_name                    in      varchar2 default hr_api.g_varchar2
        --  ,p_applicant_number             in      varchar2 default hr_api.g_varchar2
        --  ,p_comments                     in      varchar2 default hr_api.g_varchar2
        --  ,p_date_employee_data_verified  in      date     default hr_api.g_date
        --  ,p_date_of_birth                in      date     default hr_api.g_date
        --  ,p_email_address                in      varchar2 default hr_api.g_varchar2
        ,p_employee_number => v_employee_number
        --  ,p_expense_check_send_to_addres in      varchar2 default hr_api.g_varchar2
        --  ,p_first_name                   in      varchar2 default hr_api.g_varchar2
        --  ,p_known_as                     in      varchar2 default hr_api.g_varchar2
        --  ,p_marital_status               in      varchar2 default hr_api.g_varchar2
        --  ,p_middle_names                 in      varchar2 default hr_api.g_varchar2
        --  ,p_nationality                  in      varchar2 default hr_api.g_varchar2
        --  ,p_national_identifier          in      varchar2 default hr_api.g_varchar2
        --  ,p_previous_last_name           in      varchar2 default hr_api.g_varchar2
        --  ,p_registered_disabled_flag     in      varchar2 default hr_api.g_varchar2
        --  ,p_sex                          in      varchar2 default hr_api.g_varchar2
        --  ,p_title                        in      varchar2 default hr_api.g_varchar2
        --  ,p_vendor_id                    in      number   default hr_api.g_number
        --  ,p_work_telephone               in      varchar2 default hr_api.g_varchar2
        --  ,p_attribute_category           in      varchar2 default hr_api.g_varchar2
        ,p_attribute11 => emps.def_code
        --  ,p_date_of_death                in      date     default hr_api.g_date
        --  ,p_background_check_status      in      varchar2 default hr_api.g_varchar2
        --  ,p_background_date_check        in      date     default hr_api.g_date
        --  ,p_blood_type                   in      varchar2 default hr_api.g_varchar2
        --  ,p_correspondence_language      in      varchar2 default hr_api.g_varchar2
        --  ,p_fast_path_employee           in      varchar2 default hr_api.g_varchar2
        --  ,p_fte_capacity                 in      number   default hr_api.g_number
        --  ,p_hold_applicant_date_until    in      date     default hr_api.g_date
        --  ,p_honors                       in      varchar2 default hr_api.g_varchar2
        --  ,p_internal_location            in      varchar2 default hr_api.g_varchar2
        --  ,p_last_medical_test_by         in      varchar2 default hr_api.g_varchar2
        --  ,p_last_medical_test_date       in      date     default hr_api.g_date
        --  ,p_mailstop                     in      varchar2 default hr_api.g_varchar2
        --  ,p_office_number                in      varchar2 default hr_api.g_varchar2
        --  ,p_on_military_service          in      varchar2 default hr_api.g_varchar2
        --  ,p_pre_name_adjunct             in      varchar2 default hr_api.g_varchar2
        --  ,p_projected_start_date         in      date     default hr_api.g_date
        --  ,p_rehire_authorizor            in      varchar2 default hr_api.g_varchar2
        --  ,p_rehire_recommendation        in      varchar2 default hr_api.g_varchar2
        --  ,p_resume_exists                in      varchar2 default hr_api.g_varchar2
        --  ,p_resume_last_updated          in      date     default hr_api.g_date
        --  ,p_second_passport_exists       in      varchar2 default hr_api.g_varchar2
        --  ,p_student_status               in      varchar2 default hr_api.g_varchar2
        --  ,p_work_schedule                in      varchar2 default hr_api.g_varchar2
        --  ,p_rehire_reason                in      varchar2 default hr_api.g_varchar2
        --  ,p_suffix                       in      varchar2 default hr_api.g_varchar2
        --  ,p_benefit_group_id             in      number   default hr_api.g_number
        --  ,p_receipt_of_death_cert_date   in      date     default hr_api.g_date
        --  ,p_coord_ben_med_pln_no         in      varchar2 default hr_api.g_varchar2
        --  ,p_coord_ben_no_cvg_flag        in      varchar2 default hr_api.g_varchar2
        --  ,p_coord_ben_med_ext_er         in      varchar2 default hr_api.g_varchar2
        --  ,p_coord_ben_med_pl_name        in      varchar2 default hr_api.g_varchar2
        --  ,p_coord_ben_med_insr_crr_name  in      varchar2 default hr_api.g_varchar2
        -- ,p_coord_ben_med_insr_crr_ident in      varchar2 default hr_api.g_varchar2
        -- ,p_coord_ben_med_cvg_strt_dt    in      date     default hr_api.g_date
        --  ,p_coord_ben_med_cvg_end_dt     in      date     default hr_api.g_date
        --  ,p_uses_tobacco_flag            in      varchar2 default hr_api.g_varchar2
        --  ,p_dpdnt_adoption_date          in      date     default hr_api.g_date
        --  ,p_dpdnt_vlntry_svce_flag       in      varchar2 default hr_api.g_varchar2
        --  ,p_original_date_of_hire        in      date     default hr_api.g_date
        --  ,p_adjusted_svc_date            in      date     default hr_api.g_date
        --  ,p_town_of_birth                in      varchar2 default hr_api.g_varchar2
        --  ,p_region_of_birth              in      varchar2 default hr_api.g_varchar2
        --  ,p_country_of_birth             in      varchar2 default hr_api.g_varchar2
        -- ,p_global_person_id             in      varchar2 default hr_api.g_varchar2
        --  ,p_party_id                     in      number   default hr_api.g_number
        --  ,p_npw_number                   in      varchar2 default hr_api.g_varchar2
        ,P_EFFECTIVE_START_DATE => V_EFFECTIVE_START_DATE ,P_EFFECTIVE_END_DATE => V_EFFECTIVE_END_DATE ,P_FULL_NAME => V_FULL_NAME ,P_COMMENT_ID => V_COMMENT_ID ,P_NAME_COMBINATION_WARNING => V_NAME_COMBINATION_WARNING ,P_ASSIGN_PAYROLL_WARNING => V_ASSIGN_PAYROLL_WARNING ,p_orig_hire_warning => v_orig_hire_warning );
        COMMIT;
      EXCEPTION
      WHEN OTHERS THEN
        NULL;
        FND_FILE.PUT_LINE(FND_FILE.log,'Error populating Default PO assignment for '||emps.employee_number);
      END;
    END LOOP;
    -----------------------------------------------------------------------
  EXCEPTION
  WHEN OTHERS THEN
    NULL;
  END populate_def_po_acct;
  --****************************************************************
  --
PROCEDURE revoke_ess
IS
  /**********************************************************************
  This procedure checks for non-employees (CWK) who have the Employee
  Self Service responsibility assigned.  It will end-date the
  role which contains the responsibility.
  **********************************************************************/
  --
  -- variables
  --
  v_resp_id    NUMBER;
  v_app_id     NUMBER;
  v_start_date DATE;
  v_end_date   DATE;
  --
  -- cursors
  --
  CURSOR c_emps
  IS
    SELECT pep.BUSINESS_GROUP_ID ,
      pep.employee_number ,
      pep.full_name ,
      u.user_name ,
      u.user_id
    FROM hr.per_all_people_f pep ,
      per_business_groups bg ,
      hr.per_all_assignments_f asg ,
      hr.per_periods_of_service ppos ,
      apps.fnd_user u
    WHERE sysdate BETWEEN pep.effective_start_date AND pep.effective_end_date
    AND sysdate BETWEEN asg.effective_start_date AND asg.effective_end_date
    AND pep.person_id                               = asg.person_id
    AND pep.person_id                               = u.employee_id
    AND asg.PERIOD_OF_SERVICE_ID                    = ppos.PERIOD_OF_SERVICE_ID
    AND NVL(PPOS.ACTUAL_TERMINATION_DATE,SYSDATE+1) > TRUNC(SYSDATE)
    AND (u.END_DATE                                IS NULL
    OR u.end_date                                   > TRUNC(sysdate))
    AND pep.business_group_id                       = bg.business_group_id
      ------- exclude users that are not actually employees
    AND hr_person_type_usage_info.get_user_person_type (SYSDATE,pep.person_id) LIKE 'HAE Cont%'
      ------- check for existing role or responsibility by business group
    AND EXISTS
      (SELECT NULL
      FROM applsys.WF_USER_ROLE_ASSIGNMENTS ra
      WHERE ra.role_orig_system  = 'FND_RESP'
      AND ra.role_orig_system_id =
        (SELECT responsibility_id
        FROM fnd_responsibility_tl
        WHERE responsibility_name = 'Haemonetics Employee Self Service'
        AND APPLICATION_ID        = 800
        AND LANGUAGE              = 'US'
        )
    AND TRUNC(sysdate) BETWEEN ra.start_date AND NVL(ra.END_DATE,sysdate+1)
    AND U.USER_NAME = RA.USER_NAME
      ) ;
    --
  BEGIN
    SELECT responsibility_id ,
      application_id
    INTO v_resp_id ,
      v_app_id
    FROM fnd_responsibility_tl
    WHERE responsibility_name = 'Haemonetics Employee Self Service'
    AND language              = 'US' ;
    FOR emps IN c_emps
    LOOP
      SELECT ur.start_date ,
        ur.end_date
      INTO v_start_date ,
        v_end_date
      FROM fnd_responsibility_tl r ,
        FND_USER_RESP_GROUPS_DIRECT ur
      WHERE r.responsibility_id               = v_resp_id
      AND r.application_id                    = v_app_id
      AND r.language                          = 'US'
      AND ur.responsibility_id (+)            = r.responsibility_id
      AND ur.responsibility_application_id(+) = r.application_id
      AND ur.user_id(+)                       = emps.user_id ;
      -- End Date the ESS Responsibility
      fnd_user_resp_groups_api.update_assignment ( user_id => emps.user_id , responsibility_id => v_resp_id , responsibility_application_id => v_app_id , security_group_id => 0 , START_DATE => V_START_DATE , end_date => greatest(v_start_date,TRUNC(SYSDATE) - 1) , description => NULL );
    END LOOP; --c_emps
    -----------------------------------------------------------------------
  END revoke_ess;
PROCEDURE XXHA_UNASSIGN_ROLE(
    P_USERNAME VARCHAR2)
AS
  /***************************************************************************************
  This procedure takes input of username and gets records who satisfy conditions below
  1. Responsibility check - Oracle Installed Base User.
  2. Roles assigned check - CSI_NORMAL_USER, CSI_READ_ONLY_USER, HAE_CSI_UPD_ADDATTR_NOTES
  Based on check results, performs unassing roles to user.
  ****************************************************************************************/
  CURSOR CUR_UR(L_USERNAME VARCHAR2)
  IS
    (SELECT A.principal_name username,
      u.user_id,
      b.principal_name rolename,
      b.creation_date rolecreation,
      d.domain_name
    FROM jtf_auth_principal_maps c,
      jtf_auth_principals_b A,
      jtf_auth_domains_b d,
      jtf_auth_principals_b b,
      fnd_user u,
      fnd_user_resp_groups_direct ur,
      fnd_responsibility_tl rn
    WHERE 1=1
      --AND A.principal_name='CBOGDANSKI'
    AND A.is_user_flag   =1
    AND A.principal_name = u.user_name
    AND u.user_name      = l_username
      --and u.end_Active <= sysdate
    AND u.user_id              = ur.user_id
    AND ur.responsibility_id   = rn.responsibility_id
    AND rn.responsibility_name = 'Oracle Installed Base User'
    AND rn.language            = 'US'
    AND A.jtf_auth_principal_id=c.jtf_auth_principal_id
    AND b.principal_name      IN ('CSI_NORMAL_USER', 'CSI_READ_ONLY_USER', 'HAE_CSI_UPD_ADDATTR_NOTES')
    AND b.is_user_flag         =0
    AND b.jtf_auth_principal_id=c.jtf_auth_parent_principal_id
    AND d.domain_name          ='CRM_DOMAIN'
    AND d.jtf_auth_domain_id   =c.jtf_auth_domain_id
    );
BEGIN
  DBMS_OUTPUT.PUT_LINE('START - Procedure XXHA_UNASSIGN_ROLE');
  FND_FILE.PUT_LINE(FND_FILE.LOG,'Entered procedure XXHA_UNASSIGN_ROLE');
  SAVEPOINT UNASSIGN_ROLE;
  FOR rec_ur IN cur_ur(P_USERNAME)
  LOOP
    BEGIN
      DBMS_OUTPUT.PUT_LINE('Started Unassign role for Username: '||rec_ur.username|| ' and Role: '||rec_ur.rolename);
      FND_FILE.PUT_LINE(FND_FILE.LOG,'Started Unassign role for Username: '||rec_ur.username|| ' and Role: '||rec_ur.rolename);
      DELETE
      FROM JTF_AUTH_PRINCIPAL_MAPS
      WHERE JTF_AUTH_PRINCIPAL_MAPPING_ID IN
        (SELECT A.JTF_AUTH_PRINCIPAL_MAPPING_ID
        FROM JTF_AUTH_PRINCIPAL_MAPS a,
          JTF_AUTH_PRINCIPALS_B b,
          JTF_AUTH_DOMAINS_B c,
          JTF_AUTH_PRINCIPALS_B d
        WHERE 1                            = 1
        AND a.JTF_AUTH_PRINCIPAL_ID        = B.JTF_AUTH_PRINCIPAL_ID
        AND B.IS_USER_FLAG                 = 1
        AND B.PRINCIPAL_NAME               = rec_ur.username
        AND a.JTF_AUTH_PARENT_PRINCIPAL_ID = D.JTF_AUTH_PRINCIPAL_ID
        AND D.IS_USER_FLAG                 = 0
        AND D.PRINCIPAL_NAME               = rec_ur.rolename
        AND a.JTF_AUTH_DOMAIN_ID           = C.JTF_AUTH_DOMAIN_ID
        AND c.domain_name                  = rec_ur.domain_name
        );
      DBMS_OUTPUT.PUT_LINE('Completed Unassign role for Username: '||rec_ur.username|| ' and Role: '||rec_ur.rolename|| chr(13));
      FND_FILE.PUT_LINE(FND_FILE.LOG,'Completed Unassign role for Username: '||rec_ur.username|| ' and Role: '||rec_ur.rolename|| chr(13));
    EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('Exception encountered in loop while performing unassing: '||SQLERRM);
      FND_FILE.PUT_LINE(FND_FILE.LOG,'Exception encountered in loop while performing unassing: '||SQLERRM);
      ROLLBACK TO UNASSIGN_ROLE;
    END;
  END LOOP;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('END - Procedure XXHA_UNASSIGN_ROLE');
  FND_FILE.PUT_LINE(FND_FILE.LOG,'END - Procedure XXHA_UNASSIGN_ROLE');
EXCEPTION
WHEN OTHERS THEN
  DBMS_OUTPUT.PUT_LINE('Exception encountered in procedure XXHA_UNASSIGN_ROLE: '||SQLERRM);
  FND_FILE.PUT_LINE(FND_FILE.LOG,'Exception encountered in procedure XXHA_UNASSIGN_ROLE: '||SQLERRM);
END XXHA_UNASSIGN_ROLE;
--------------------------------------------------------------------------------------------------------------
PROCEDURE XXHA_ENDATE_SUBINV(
    p_user_name VARCHAR2)
AS
  p_return_status              VARCHAR2(50);
  p_msg_count                  NUMBER;
  p_msg_data                   VARCHAR2(2000);
  px_CSP_INV_LOC_ASSIGNMENT_ID NUMBER;
  l_assignment_id              NUMBER := 0; -- := 15027;
  /***************************************************************************************
  This procedure takes input of username and gets the user's assigned subinventories records to be end dated.
  ****************************************************************************************/
  CURSOR cur_endate_subinv
  IS
    SELECT i.csp_inv_loc_assignment_id,
      i.created_by,
      i.creation_date,
      i.resource_id,
      i.organization_id,
      i.subinventory_code,
      i.locator_id,
      i.resource_type,
      i.effective_date_start,
      i.default_code
    FROM fnd_user u,
      csp_inv_loc_assignments i,
      per_all_people_f papf,
      csp_sec_inventories s
    WHERE i.organization_id                                           = s.organization_id (+)
    AND i.subinventory_code                                           = s.secondary_inventory_name (+)
    AND papf.person_id                                                = u.employee_id
    AND csp_pick_utils.get_object_name(i.resource_type,i.resource_id) = papf.full_name
    AND TRUNC(sysdate) BETWEEN TRUNC(papf.effective_start_date) AND TRUNC(papf.effective_end_date)
    AND u.user_name = p_user_name
      --AND u.end_date            <= SYSDATE
    AND (i.effective_date_end IS NULL
    OR i.effective_date_end   >= sysdate);
BEGIN
  DBMS_OUTPUT.PUT_LINE('In XXHA_ENDATE_SUBINV' );
  FND_FILE.PUT_LINE(FND_FILE.LOG,'In XXHA_ENDATE_SUBINV' );
  FOR rec_subinv IN cur_endate_subinv
  LOOP
    l_assignment_id := rec_subinv.csp_inv_loc_assignment_id;
    DBMS_OUTPUT.PUT_LINE('End date Sub inventory '||rec_subinv.subinventory_code );
    FND_FILE.PUT_LINE(FND_FILE.LOG,'End date Sub inventory '||rec_subinv.subinventory_code );
    BEGIN
      CSP_RESOURCE_PUB.ASSIGN_RESOURCE_INV_LOC ( P_Api_Version_Number => 1 ,P_Init_Msg_List => FND_API.G_FALSE ,P_Commit => FND_API.G_TRUE ,p_validation_level => FND_API.G_VALID_LEVEL_FULL ,p_action_code => 1 -- 0 = insert, 1 = update, 2 = delete
      ,px_CSP_INV_LOC_ASSIGNMENT_ID => l_assignment_id ,p_CREATED_BY => rec_subinv.created_by ,p_CREATION_DATE => rec_subinv.creation_date ,p_LAST_UPDATED_BY => fnd_global.user_id ,p_LAST_UPDATE_DATE => SYSDATE ,p_LAST_UPDATE_LOGIN => NULL ,p_RESOURCE_ID => rec_subinv.resource_id ,p_ORGANIZATION_ID => rec_subinv.organization_id ,p_SUBINVENTORY_CODE => rec_subinv.subinventory_code ,p_LOCATOR_ID => rec_subinv.locator_id ,p_RESOURCE_TYPE => rec_subinv.resource_type ,p_EFFECTIVE_DATE_START => rec_subinv.effective_date_start ,p_EFFECTIVE_DATE_END => SYSDATE ,p_DEFAULT_CODE => rec_subinv.default_code ,p_ATTRIBUTE_CATEGORY => NULL ,p_ATTRIBUTE1 => NULL ,p_ATTRIBUTE2 => NULL ,p_ATTRIBUTE3 => NULL ,p_ATTRIBUTE4 => NULL ,p_ATTRIBUTE5 => NULL ,p_ATTRIBUTE6 => NULL ,p_ATTRIBUTE7 => NULL ,p_ATTRIBUTE8 => NULL ,p_ATTRIBUTE9 => NULL ,p_ATTRIBUTE10 => NULL ,p_ATTRIBUTE11 => NULL ,p_ATTRIBUTE12 => NULL ,p_ATTRIBUTE13 => NULL ,p_ATTRIBUTE14 => NULL ,p_ATTRIBUTE15 => NULL ,x_return_status =>
      p_return_status ,x_msg_count => p_msg_count ,x_msg_data => p_msg_data );
      COMMIT;
      DBMS_OUTPUT.put_line(p_return_status);
      FND_FILE.PUT_LINE(FND_FILE.LOG,'Return status of the API for end dating the assigned subinventories for the terminated user : '||p_return_status);
      DBMS_OUTPUT.PUT_LINE('Completed end dating the assigned subinventory: '||rec_subinv.subinventory_code||' for Username: '||p_user_name);
      FND_FILE.PUT_LINE(FND_FILE.LOG,'Completed end dating the assigned subinventory: '||rec_subinv.subinventory_code||' for Username: '||p_user_name);
      IF p_return_status <> 'S' THEN
        DBMS_OUTPUT.PUT_LINE('Exception encountered in api: '||SQLERRM);
        FND_FILE.PUT_LINE(FND_FILE.LOG,'Exception encountered in api: '||SQLERRM);
      END IF;
    EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('Exception encountered in procedure XXHA_ENDATE_SUBINV: '||SQLERRM);
      FND_FILE.PUT_LINE(FND_FILE.LOG,'Exception encountered in procedure XXHA_ENDATE_SUBINV: '||SQLERRM);
    END;
  END LOOP;
  COMMIT;
END XXHA_ENDATE_SUBINV;
PROCEDURE XXHA_ENDATE_BUYER(
    p_user_name VARCHAR2)
AS
  /***************************************************************************************
  This procedure takes input of username and end dates the buyer account for a terminated user.
  ****************************************************************************************/
  CURSOR cur_endate_buyer
  IS
    SELECT u.employee_id
    FROM fnd_user u,
      po_agents p
    WHERE u.user_name = p_user_name
      --AND u.end_date         IS NOT NULL
      --AND u.end_date         <= SYSDATE
    AND p.agent_id          = u.employee_id
    AND (p.end_date_active IS NULL
    OR p.end_date_active   >= sysdate);
BEGIN
  DBMS_OUTPUT.PUT_LINE('In XXHA_ENDATE_BUYER' );
  FND_FILE.PUT_LINE(FND_FILE.LOG,'In XXHA_ENDATE_BUYER' );
  FOR rec_endate_buyer IN cur_endate_buyer
  LOOP
    DBMS_OUTPUT.PUT_LINE('End date Buyer ');
    FND_FILE.PUT_LINE(FND_FILE.LOG,'End date Buyer ');
    BEGIN
      UPDATE po_agents
      SET end_date_active   = sysdate
      WHERE agent_id        = rec_endate_buyer.employee_id
      AND (end_date_active IS NULL
      OR end_date_active   >= sysdate);
      COMMIT;
    EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('Exception encountered in procedure XXHA_ENDATE_BUYER: '||SQLERRM);
      FND_FILE.PUT_LINE(FND_FILE.LOG,'Exception encountered while updating PO_AGENTS table: '||SQLERRM);
    END;
  END LOOP;
END XXHA_ENDATE_BUYER;
--****************************************************************
PROCEDURE XXHA_DEL_USER_APPRGROUP(
    p_user_name VARCHAR2)
AS
  L_validate               BOOLEAN;
  L_approval_group_item_id NUMBER;
  --L_object_version_number number:=1;
  L_object_version_number NUMBER;
  L_start_date            DATE;
  L_end_date              DATE;
  /*********************************************************************************************************************************
  This procedure takes input of user name who is end dated/terminated from existing functionality and is deleted from approver group
  ***********************************************************************************************************************************/
  CURSOR cur_Delete_User_AppGrp
  IS
    SELECT aagi.approval_group_item_id,
      aagi.object_version_number
    FROM ame_approval_group_items aagi,
      ame_approval_groups aag
    WHERE aagi.parameter      = p_user_name
    AND aagi.approval_group_id=aag.approval_group_id
    AND (aagi.end_date        > sysdate
    OR aagi.end_date         IS NULL);
  /*Added to pick up the active record here, can be null or
  future date(for some users they have already given future date to make record inactive at that point of time
  but no we need to pic this record as well and need to delete them from approver group */
BEGIN
  DBMS_OUTPUT.PUT_LINE('In XXHA_DEL_USER_APPRGROUP' );
  FND_FILE.PUT_LINE(FND_FILE.LOG,'In XXHA_DEL_USER_APPRGROUP' );
  FOR Rec_Delete_User_AppGrp IN cur_Delete_User_AppGrp
  LOOP
    L_object_version_number := Rec_Delete_User_AppGrp.object_version_number;
    L_approval_group_item_id:=Rec_Delete_User_AppGrp.approval_group_item_id;
    FND_FILE.PUT_LINE(FND_FILE.LOG,'Approval Group Item Id of the end dated user: '||L_approval_group_item_id);
    DBms_output.put_line('Approval Group Item Id of the end dated user: '||L_approval_group_item_id);
    BEGIN
      AME_APPROVER_GROUP_API.delete_approver_group_item ( p_validate => FALSE ,p_approval_group_item_id =>L_approval_group_item_id ,p_object_version_number =>L_object_version_number ,p_start_date => L_start_date ,p_end_date => L_end_date );
      COMMIT;
      DBms_output.put_line('Object version number after deleting the terminated user : '||L_object_version_number);
      FND_FILE.PUT_LINE(FND_FILE.LOG,'Object version number after deleting the terminated user : '||L_object_version_number);
    EXCEPTION
    WHEN OTHERS THEN
      FND_FILE.PUT_LINE(FND_FILE.LOG,'Exception encountered in procedure XXHA_DEL_USER_APPRGROUP: '||SQLERRM);
    END;
  END LOOP;
END XXHA_DEL_USER_APPRGROUP;
-------------------------------------------------------------------------------------------------
--****************************************************************
PROCEDURE xxha_Endate_SaleRep(
    p_source_name VARCHAR2)
AS
  v_api_version VARCHAR2(100) := '1.0';
  --v_salesrep_id            JTF_RS_SALESREPS.SALESREP_ID%TYPE;
  --V_SALES_CREDIT_TYPE_ID  JTF_RS_SALESREPS.SALES_CREDIT_TYPE_ID%TYPE:=1001;
  --V_SALESREP_NUMBER  JTF_RS_SALESREPS.SALESREP_NUMBER%TYPE:='100';
  --V_ORG_ID  JTF_RS_SALESREPS.ORG_ID%TYPE;
  V_OBJECT_VERSION_NUMBER JTF_RS_SALESREPS.OBJECT_VERSION_NUMBER%TYPE:=1; --In out
  lc_return_status VARCHAR2(1);
  ln_msg_count     NUMBER;
  lc_msg_data      VARCHAR2(5000);
  lc_msg_dummy     VARCHAR2(5000);
  lc_output        VARCHAR2(5000);
  /**************************************************************************************************************************************
  This procedure takes input of user name who is end dated/terminated from existing functionality and End Dates the Sales representative
  **************************************************************************************************************************************/
  CURSOR cur_end_date_salesrep
  IS
    SELECT sr.SALESREP_ID,
      sr.SALES_CREDIT_TYPE_ID,
      sr.SALESREP_NUMBER,
      sr.ORG_ID,
      sr.OBJECT_VERSION_NUMBER,
      sr.start_date_active
    FROM jtf_rs_resource_extns b,
      JTF_RS_SALESREPS SR
    WHERE b.resource_id    =sr.resource_id
    AND b.source_name      =p_source_name 
    AND (sr.end_date_active > sysdate
    OR sr.end_date_active  IS NULL);
BEGIN
  --mo_global.set_policy_context('S',102);
  DBMS_OUTPUT.PUT_LINE('In xxha_Endate_SaleRep' );
  FND_FILE.PUT_LINE(FND_FILE.LOG,'In xxha_Endate_SaleRep' );
  FOR Rec_end_date_salesrep IN cur_end_date_salesrep
  LOOP
    mo_global.set_policy_context('S',Rec_end_date_salesrep.ORG_ID); --FND_PROFILE.VALUE('ORG_ID');
	V_OBJECT_VERSION_NUMBER:=Rec_end_date_salesrep.OBJECT_VERSION_NUMBER;
    FND_FILE.PUT_LINE(FND_FILE.LOG,'In ending Sales rep Loop :'||V_OBJECT_VERSION_NUMBER);
    FND_FILE.PUT_LINE(FND_FILE.LOG,'User Name while end dating Sales Representative :'||p_source_name);
    jtf_rs_salesreps_pub.update_salesrep (P_API_VERSION => v_api_version, P_INIT_MSG_LIST => 'T', P_COMMIT => 'T', P_SALESREP_ID => Rec_end_date_salesrep.SALESREP_ID,
    P_SALES_CREDIT_TYPE_ID => Rec_end_date_salesrep.SALES_CREDIT_TYPE_ID,                                                                                             
    P_START_DATE_ACTIVE => Rec_end_date_salesrep.start_date_active,                                                                                                   
    P_END_DATE_ACTIVE => TRUNC(sysdate)+180, P_SALESREP_NUMBER => Rec_end_date_salesrep.SALESREP_NUMBER,                                                              
    P_ORG_ID => Rec_end_date_salesrep.ORG_ID,                                                                                                                         
    P_OBJECT_VERSION_NUMBER =>V_OBJECT_VERSION_NUMBER, x_return_status => lc_return_status, x_msg_count => ln_msg_count, x_msg_data => lc_msg_data );
    COMMIT;
    IF (lc_return_status <> 'S') THEN
      BEGIN
        FOR i IN 1 .. ln_msg_count
        LOOP
          fnd_msg_pub.get (i, fnd_api.g_false, lc_msg_data, lc_msg_dummy);
          lc_output := (TO_CHAR (i) || ': ' || lc_msg_data);
        END LOOP;
        dbms_output.put_line('Error :'||lc_output);
        FND_FILE.PUT_LINE(FND_FILE.LOG,'Error :'||lc_output);
      END;
      ROLLBACK;
    ELSE
      dbms_output.put_line('Sales Representative end dated successfully');
      FND_FILE.PUT_LINE(FND_FILE.LOG,'Sales Representative end dated successfully');
      COMMIT;
    END IF;
  END LOOP;
EXCEPTION
WHEN OTHERS THEN
  DBMS_OUTPUT.PUT_LINE ('Error While End Dating the sale representative :'||SQLERRM);
  FND_FILE.PUT_LINE(FND_FILE.LOG,'Error While End Dating the sale representative :'||SQLERRM);
  ROLLBACK;
END xxha_Endate_SaleRep;
--****************************************************************
PROCEDURE xxha_enduser_apsp(
    p_user_name IN VARCHAR2)
AS
  l_instance VARCHAR2(10);
  v_end_date DATE;
BEGIN
  FND_FILE.PUT_LINE(FND_FILE.LOG,'In XXHA_ENDUSER_APSP');
  SELECT instance_name INTO l_instance FROM v$instance;
  /*IF l_instance = 'HAEWKLY' THEN
    FND_FILE.PUT_LINE(FND_FILE.LOG,'Instance '||l_instance);
    dbms_output.put_line('Instance '||l_instance);
    SELECT end_date
    INTO v_end_date
    FROM fnd_user@HAEWKLY_TO_HAEAPSD.DATAINTENSITY.COM
    WHERE user_name = p_user_name;
    IF v_end_date  IS NULL OR v_end_date > sysdate THEN
      fnd_user_pkg.UpdateUser@HAEWKLY_TO_HAEAPSD.DATAINTENSITY.COM ( x_user_name => p_user_name, x_owner => 'SEED', x_end_date => sysdate);
      FND_FILE.PUT_LINE(FND_FILE.LOG,'End dated User '||p_user_name);
      dbms_output.put_line('End dated User '||p_user_name);
    END IF;*/
    if l_instance = 'HAEPRD' THEN
    FND_FILE.PUT_LINE(FND_FILE.LOG,'Instance '||l_instance);
    dbms_output.put_line('Instance '||l_instance);
    SELECT end_date
    INTO v_end_date
    FROM fnd_user@PRD_TO_APSP.DATAINTENSITY.COM
    WHERE user_name = p_user_name;
    IF v_end_date  IS NULL OR v_end_date > sysdate THEN
    fnd_user_pkg.UpdateUser@PRD_TO_APSP.DATAINTENSITY.COM ( x_user_name => p_user_name, x_owner => 'SEED', x_end_date => sysdate);
    FND_FILE.PUT_LINE(FND_FILE.LOG,'End dated User '||p_user_name);
    dbms_output.put_line('End dated User '||p_user_name);
    END IF;
  END IF;
EXCEPTION
WHEN no_data_found THEN
  DBMS_OUTPUT.PUT_LINE ('Exception - No_data_found '||SQLERRM);
  FND_FILE.PUT_LINE(FND_FILE.LOG,'Exception - No_data_found '||SQLERRM);
WHEN OTHERS THEN
  DBMS_OUTPUT.PUT_LINE ('Exception - Others '||SQLERRM);
  FND_FILE.PUT_LINE(FND_FILE.LOG,'Exception - Others '||SQLERRM);
END xxha_enduser_apsp;
--****************************************************************
END XXHA_USER_MAINTENANCE_PKG ;
/