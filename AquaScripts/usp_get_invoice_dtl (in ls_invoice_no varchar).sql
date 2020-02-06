CREATE OR REPLACE FUNCTION public.usp_get_invoice_dtl (in ls_invoice_no varchar) RETURNS SETOF usp_get_invoice_dtl_ctype AS
$BODY$ DECLARE res 
	usp_get_invoice_dtl_ctype ; 

declare bkg_valid char(1);


BEGIN
select into bkg_valid case when (SELECT count(total_tax_supp_curr) FROM t_booking_air_fare 
where trans_xid=(SELECT trans_xid FROM t_booking_document WHERE document_no=ls_invoice_no) and total_tax_supp_curr is not null)=((SELECT count(*) FROM t_booking_air_fare where trans_xid=(SELECT trans_xid FROM t_booking_document WHERE document_no=ls_invoice_no))) then 'Y' else 'N' end;

update t_booking_document
set protas_hit_count = protas_hit_count + 1
where document_no = ls_invoice_no and is_invoice_blocked= 'N';


	FOR res IN 
SELECT
	trans_doc_pid                                                                                                
	AS doc_id,
	'A'                                                                                                          
	AS product,
	trans_air_pid                                                                                                
	AS product_id,
	t_booking_air_sector_pax_dtl.leg_pax_pid                                                                     
	AS leg_pax_pid,
	TRIM(m_client.account_code)                                                                                  
	AS AccNo,
	coalesce((SELECT
			TRIM(branch_code) 
		FROM
			m_branch 
		WHERE
			branch_pid=(SELECT branch_xid FROM m_regional_pcc_branch_mapping WHERE supplier_xid=(SELECT supplier_xid FROM m_hap_master WHERE hap_pid=t_booking_air.ticket_hapid) and (SELECT is_regional_pcc_ticketing FROM m_supplier WHERE supplier_pid=(SELECT supplier_xid FROM m_hap_master WHERE hap_pid=t_booking_air.ticket_hapid))='Y' and client_xid=t_booking.client_xid)),(	SELECT
			TRIM(branch_code) 
		FROM
			m_branch 
		WHERE
			branch_pid=(SELECT
							branch_xid 
						FROM
							m_client_branch_mapping 
						WHERE
							client_xid=t_booking.client_xid AND
							is_default='Y' 
			)
	))
	AS OffNo,
	(	SELECT
			employee_no 
		FROM
			m_login_user 
		WHERE
			login_user_pid=t_booking_air.salesman_xid 
	)
	AS SalNo,
	(	SELECT
			TRIM(branch_code) 
		FROM
			m_branch 
		WHERE
			branch_pid=(SELECT
							branch_xid 
						FROM
							m_client_branch_mapping 
						WHERE
							client_xid=t_booking.client_xid AND
							is_default='Y' 
			)
	)
	AS OwnOffNo,
	t_booking_air.travel_type                                                                                    
	AS CustType,
	(	SELECT
			COALESCE(TRIM(reference_number),'') 
		FROM
			m_traveller 
		WHERE
			traveller_pid =t_booking_air_pax.traveller_xid 
	)
	AS OrdEmpNo,
	CASE 
		WHEN (LENGTH(t_booking_air_pax.first_name)+LENGTH(t_booking_air_pax. 
		last_name)+LENGTH(t_booking_air_pax.title)) >38 
		THEN COALESCE(SUBSTRING (TRIM(t_booking_air_pax.last_name),1,17) ,'')|| 
		' ' ||COALESCE(SUBSTRING (TRIM(t_booking_air_pax.first_name),1,16) ,'') 
		||' ' ||COALESCE(SUBSTRING (TRIM(t_booking_air_pax.title),1,7) ,'') 
		ELSE COALESCE(TRIM(t_booking_air_pax.last_name),'') ||' ' || COALESCE ( 
		TRIM(t_booking_air_pax.first_name),'') || ' ' ||COALESCE(TRIM( 
		t_booking_air_pax.title),'') 
	END                                                                                                              
	AS TrvName,
    case when t_booking_document_dtl.fop_name = 'CC-CPG'
    THEN t_booking_document_dtl.ordercode
    else
	TRIM(t_booking_air.lpo_number) end                                                                               
    AS ReqNo,
	'0'                                                                                                          
	AS IT,
	(	SELECT
			TRIM(branch_code) 
		FROM
			m_branch 
		WHERE
			branch_pid=t_booking_air.booking_branch_xid 
	)
	AS BookingOffNo,
	(	SELECT
			TRIM(cost_center_code) 
		FROM
			m_cost_center 
		WHERE
			cost_center_pid=t_booking_air_pax.cost_center_xid 
	)
	AS CostCenter,
	''                                                                                                           
	AS ApprCd,
	(	SELECT
			TRIM(project_code) 
		FROM
			m_project 
		WHERE
			project_pid =t_booking_air_pax.project_xid 
	)
	AS project_no,
	t_booking_air.travel_dt                                                                                      
	AS TravelDate,
	'N'                                                                                                          
	AS Exchangetrans,
	(SELECT


					fop_no 
				FROM
					m_fop_meta 
				WHERE
					m_fop_meta.fop=
(CASE
WHEN t_booking_air.mode_of_booking in  ('CS','PG','CC') 
THEN
COALESCE(t_booking_document_dtl.fop_name,t_booking_air.mode_of_booking) 
ELSE
t_booking_air.mode_of_booking
END) )
AS FOPNo,
case
when t_booking_document_dtl.fop_name in ('CC-UCCCF') and  t_booking_air_fare.trans_fee_cons_curr <> 0 
then 4
else null end  AS FOPNo2,
	CASE 
		WHEN t_booking.fop_type='PT' 
		THEN TRIM(t_booking_air.mode_of_booking) 
		ELSE (	SELECT
					TRIM(mop) 
				FROM
					(	SELECT
							mop,
							trans_pax_mop_pid 
						FROM
							t_booking_pax_mop 
						WHERE
							t_booking_pax_mop.trans_prod_xid=t_booking_air. 
							trans_air_pid AND
							trans_doc_xid=t_booking_document.trans_doc_pid 
						ORDER BY
							trans_pax_mop_pid ASC LIMIT 1 
					)
					t 
		)
	END                                                                                                              
	AS mop,
	(	SELECT
			TRIM(mop) 
		FROM
			(	SELECT
					mop,
					trans_pax_mop_pid 
				FROM
					t_booking_pax_mop 
				WHERE
					t_booking_pax_mop.trans_prod_xid=t_booking_air.trans_air_pid 
					AND
					trans_doc_xid=t_booking_document.trans_doc_pid 
				ORDER BY
					trans_pax_mop_pid ASC LIMIT 2 
			)
			t 
		ORDER BY
			trans_pax_mop_pid DESC LIMIT 1 
	)
	AS mop1,
	(	SELECT
			type_no 
		FROM
			m_document_master 
		WHERE
			doc_code=t_booking_air.doc_code 
	)
	AS TypeNo,
	CASE 
		WHEN t_booking_air.is_lcc='N' then
case when (
select enable_regional_pcc from m_supplier 
where supplier_pid=t_booking_air.supplier_xid
)='Y' then (
select regional_pcc_doc_no from m_supplier 
where supplier_pid=t_booking_air.supplier_xid
) else

		TRIM(SUBSTRING(t_booking_air_sector_pax_dtl.tkt_no,1,5)) end
		ELSE 
            
(	SELECT
					TRIM(CAST(doc_no AS VARCHAR)) 
				FROM
					m_document_master 
				WHERE
					doc_code=t_booking_air.doc_code
		)

	END                                                                                                              
	AS DocNo,
	CASE 
		WHEN t_booking_air.is_lcc='N' 
		THEN TRIM(t_booking_air_sector_pax_dtl.tkt_no) 
		ELSE '' 
	END                                                                                                              
	AS SerNo,
	TRIM(t_booking_air.tocity_xid)                                                                               
	AS DestCd,
	CASE 
		WHEN t_booking_air_fare.base_fare=0 
		THEN 0 
		ELSE round(((((COALESCE(t_booking_air_fare.iata_comm_amt_retain,0))/ ( 
		t_booking_air_fare.base_fare-t_booking_air_fare. 
		overriding_comm_amt_retain)))*100)::NUMERIC, 0) 
	END                                                                                                              
	AS CommPct,
	CASE 
		WHEN t_booking_air_pax.pax_type='ADT' 
		THEN COALESCE(t_booking_air.no_adults,0) 
		WHEN t_booking_air_pax.pax_type='INF' 
		THEN COALESCE(t_booking_air.no_infant ,0) 
		WHEN t_booking_air_pax.pax_type='CHD' 
		THEN COALESCE(t_booking_air.no_childrens,0) 
		ELSE NULL 
	END                                                                                                              
	AS Grp,
	NULL                                                                                                         
	AS conjNo,
	round((((COALESCE(t_booking_air_fare.base_fare_supp_curr,0))* COALESCE(
	t_booking_air_fare. suppliertoadminexcgrate,0)) +COALESCE(t_booking_air_fare
	.adhoc_markup_cons_curr, 0) +COALESCE(t_booking_air_fare.markup_cons_curr,0) + case when COALESCE(t_booking_air_fare.regional_pcc_markup,0)>=0 then COALESCE(t_booking_air_fare.regional_pcc_markup,0) else 0 end
	)::NUMERIC, 2)                                                                                        
	AS SalAmountLocal,
	round((COALESCE (t_booking_air_fare.iata_comm_amt_retain,0) * COALESCE(
	t_booking_air. selling_cons_exc_rt,0)) ::NUMERIC, 0)                                                                                       
	AS CommAmt,
    round((t_booking_air_fare.total_tax):: NUMERIC,2)                                                                                       
                                                                                       
	AS TaxAmount,
	round(((((COALESCE(t_booking_air_fare.iata_comm_amt,0)) +(COALESCE( 
	t_booking_air_fare.plb_amount,0)) +(COALESCE(t_booking_air_fare.
	overriding_comm_amt,0)) ) * COALESCE(t_booking_air.selling_cons_exc_rt,0)) + 
	(COALESCE(t_booking_air_fare.adhoc_rebate_cons_curr,0) + case when COALESCE(t_booking_air_fare.regional_pcc_markup,0)<=0 then COALESCE(t_booking_air_fare.regional_pcc_markup *-1,0) else 0 end
+ COALESCE(t_booking_air_fare.pure_discount_cons_curr,0))) ::NUMERIC,2)                                                                                        
	AS Rbamount,
	NULL                                                                                                         
	AS Rbamount2,
	round((( (COALESCE(t_booking_air_fare.base_fare_supp_curr,0))* COALESCE(
	t_booking_air_fare. suppliertoadminexcgrate,0)) -(((COALESCE(t_booking_air_fare.
	overriding_comm_amt_retain_supp_currr,0) * COALESCE(t_booking_air_fare.
	suppliertoadminexcgrate)))))::NUMERIC,2)                                                                                         
	AS EqAmount,
	CASE 
		WHEN (value_code IS NULL) 
		THEN 
		CASE 
			WHEN (t_booking_air_fare.iata_comm_amt_retain IS NOT NULL AND
			t_booking_air_fare.iata_comm_amt_retain <> 0) 
			THEN 
			CASE 
				WHEN LENGTH(CAST( trunc (round((((COALESCE(t_booking_air_fare. 
				base_fare,0))-((COALESCE(t_booking_air_fare.overriding_comm_amt_retain,0))))* 
				COALESCE(t_booking_air.selling_cons_exc_rt,0))::NUMERIC,0))AS 
				VARCHAR))=1 
				THEN 'M'||'0000'||CAST(round(((((COALESCE(t_booking_air_fare. 
				base_fare_supp_curr,0)*COALESCE(t_booking_air_fare. 
				suppliertoadminexcgrate )) -((COALESCE(t_booking_air_fare. 
				overriding_comm_amt_retain_supp_currr,0) * COALESCE( 
				t_booking_air_fare.suppliertoadminexcgrate )) ) )))::NUMERIC,0) 
				AS VARCHAR) 
				WHEN LENGTH(CAST( trunc (round((((COALESCE(t_booking_air_fare. 
				base_fare,0))-((COALESCE(t_booking_air_fare.overriding_comm_amt_retain,0))))* 
				COALESCE(t_booking_air.selling_cons_exc_rt,0))::NUMERIC,0))AS 
				VARCHAR))=2 
				THEN 'M'||'000'||CAST(round(((((COALESCE(t_booking_air_fare. 
				base_fare_supp_curr,0)*COALESCE(t_booking_air_fare. 
				suppliertoadminexcgrate )) -( (COALESCE(t_booking_air_fare. 
				overriding_comm_amt_retain_supp_currr,0) * COALESCE( 
				t_booking_air_fare.suppliertoadminexcgrate )) ) )))::NUMERIC,0) 
				AS VARCHAR) 
				WHEN LENGTH(CAST( trunc (round((((COALESCE(t_booking_air_fare. 
				base_fare,0))-((COALESCE(t_booking_air_fare.overriding_comm_amt_retain,0))))* 
				COALESCE(t_booking_air.selling_cons_exc_rt,0))::NUMERIC,0))AS 
				VARCHAR))=3 
				THEN 'M'||'00'||CAST(round(((((COALESCE(t_booking_air_fare. 
				base_fare_supp_curr,0)*COALESCE(t_booking_air_fare. 
				suppliertoadminexcgrate )) -( (COALESCE(t_booking_air_fare. 
				overriding_comm_amt_retain_supp_currr,0) * COALESCE( 
				t_booking_air_fare.suppliertoadminexcgrate )) ) )))::NUMERIC,0) 
				AS VARCHAR) 
				WHEN LENGTH(CAST( trunc (round((((COALESCE(t_booking_air_fare. 
				base_fare,0))-((COALESCE(t_booking_air_fare.overriding_comm_amt_retain,0))))* 
				COALESCE(t_booking_air.selling_cons_exc_rt,0))::NUMERIC,0))AS 
				VARCHAR))=4 
				THEN 'M'||'0'||CAST(round(((((COALESCE(t_booking_air_fare. 
				base_fare_supp_curr,0)*COALESCE(t_booking_air_fare. 
				suppliertoadminexcgrate )) -( (COALESCE(t_booking_air_fare. 
				overriding_comm_amt_retain_supp_currr,0) * COALESCE( 
				t_booking_air_fare.suppliertoadminexcgrate )) ) )))::NUMERIC,0) 
				AS VARCHAR) 
				ELSE 'M'||CAST(round(((((COALESCE(t_booking_air_fare. 
				base_fare_supp_curr,0)*COALESCE(t_booking_air_fare. 
				suppliertoadminexcgrate )) -( (COALESCE(t_booking_air_fare. 
				overriding_comm_amt_retain_supp_currr,0) * COALESCE( 
				t_booking_air_fare.suppliertoadminexcgrate )) ) )))::NUMERIC,0) 
				AS VARCHAR) 
			END 
			ELSE 
			CASE 
				WHEN LENGTH(CAST( trunc (round((((COALESCE(t_booking_air_fare. 
				base_fare,0))-((COALESCE(t_booking_air_fare.overriding_comm_amt_retain,0))))* 
				COALESCE(t_booking_air.selling_cons_exc_rt,0))::NUMERIC,0))AS 
				VARCHAR))=1 
				THEN 'D'||'0000'||CAST(round(((((COALESCE(t_booking_air_fare. 
				base_fare_supp_curr,0)*COALESCE(t_booking_air_fare. 
				suppliertoadminexcgrate )) -( (COALESCE(t_booking_air_fare. 
				overriding_comm_amt_retain_supp_currr,0) * COALESCE( 
				t_booking_air_fare.suppliertoadminexcgrate )) ) )))::NUMERIC,0) 
				AS VARCHAR) 
				WHEN LENGTH(CAST( trunc (round((((COALESCE(t_booking_air_fare. 
				base_fare,0))-((COALESCE(t_booking_air_fare.overriding_comm_amt_retain,0))))* 
				COALESCE(t_booking_air.selling_cons_exc_rt,0))::NUMERIC,0))AS 
				VARCHAR))=2 
				THEN 'D'||'000'||CAST(round(((((COALESCE(t_booking_air_fare. 
				base_fare_supp_curr,0)*COALESCE(t_booking_air_fare. 
				suppliertoadminexcgrate )) -( (COALESCE(t_booking_air_fare. 
				overriding_comm_amt_retain_supp_currr,0) * COALESCE( 
				t_booking_air_fare.suppliertoadminexcgrate )) ) )))::NUMERIC,0) 
				AS VARCHAR) 
				WHEN LENGTH(CAST( trunc (round((((COALESCE(t_booking_air_fare. 
				base_fare,0))-((COALESCE(t_booking_air_fare.overriding_comm_amt_retain,0))))* 
				COALESCE(t_booking_air.selling_cons_exc_rt,0))::NUMERIC,0))AS 
				VARCHAR))=3 
				THEN 'D'||'00'||CAST(round(((((COALESCE(t_booking_air_fare. 
				base_fare_supp_curr,0)*COALESCE(t_booking_air_fare. 
				suppliertoadminexcgrate )) -( (COALESCE(t_booking_air_fare. 
				overriding_comm_amt_retain_supp_currr,0) * COALESCE( 
				t_booking_air_fare.suppliertoadminexcgrate )) ) )))::NUMERIC,0) 
				AS VARCHAR) 
				WHEN LENGTH(CAST( trunc (round((((COALESCE(t_booking_air_fare. 
				base_fare,0))-((COALESCE(t_booking_air_fare.overriding_comm_amt_retain,0))))* 
				COALESCE(t_booking_air.selling_cons_exc_rt,0))::NUMERIC,0))AS 
				VARCHAR))=4 
				THEN 'D'||'0'||CAST(round(((((COALESCE(t_booking_air_fare. 
				base_fare_supp_curr,0)*COALESCE(t_booking_air_fare. 
				suppliertoadminexcgrate )) -( (COALESCE(t_booking_air_fare. 
				overriding_comm_amt_retain_supp_currr,0) * COALESCE( 
				t_booking_air_fare.suppliertoadminexcgrate )) ) )))::NUMERIC,0) 
				AS VARCHAR) 
				ELSE 'D'||CAST(round(((((COALESCE(t_booking_air_fare. 
				base_fare_supp_curr,0)*COALESCE(t_booking_air_fare. 
				suppliertoadminexcgrate )) -( (COALESCE(t_booking_air_fare. 
				overriding_comm_amt_retain_supp_currr,0) * COALESCE( 
				t_booking_air_fare.suppliertoadminexcgrate )) ) )))::NUMERIC,0) 
				AS VARCHAR) 
			END 
		END 
		ELSE 
		CASE 
			WHEN SUBSTRING(t_booking_air_fare.value_code,1,1)='Q' 
			THEN 'M'||SUBSTRING(t_booking_air_fare.value_code,2,LENGTH( 
			t_booking_air_fare.value_code)-1) 
			ELSE TRIM(t_booking_air_fare.value_code) 
		END 
	END                                                                                                              
	AS ValueCd,
	'AED'                                                                                                        
	AS PurrCurrCd,
	100                                                                                                          
	AS PurRate,
	0                                                                                                            
	AS PurAmount,
	CASE 
		WHEN t_booking_air.is_lcc='Y' 
		THEN TRIM(m_supplier.account_code) 
		ELSE '' 
	END                                                                                                              
	AS AccNo,
	TRIM(t_booking.booking_no)                                                                                   
	AS VendInvoNo,
	case when t_booking_document_dtl.fop_name='CC-UCCCF' 
    then 
    CASE 
    WHEN approved_key ILIKE '%/%'
    THEN (COALESCE(t_booking_air_fare.trans_fee_cons_curr,2)) + substring(approved_key, '[^/]*$') :: float8
    ELSE
    (COALESCE(t_booking_air_fare.trans_fee_cons_curr,2))
    END
    else
    NULL end                                                                                                         
	AS FopAmt2,
	TRIM(t_booking_air_pnr.gds_pnr)                                                                              
	AS PNRno,
	case when TRIM(t_booking_air_fare.tour_code) ilike '%*%' then 
case when TRIM(t_booking_air_fare.tour_code) like '%\/%' then 
substring (TRIM(t_booking_air_fare.tour_code), 
length(TRIM(t_booking_air_fare.tour_code)) - position('*' in reverse_string(TRIM(t_booking_air_fare.tour_code))) + 2,
position('/' in (TRIM(t_booking_air_fare.tour_code))) - (length(TRIM(t_booking_air_fare.tour_code)) - position('*' in reverse_string(TRIM(t_booking_air_fare.tour_code))) + 2))
else substring (TRIM(t_booking_air_fare.tour_code),
length(TRIM(t_booking_air_fare.tour_code)) - position('*' in reverse_string(TRIM(t_booking_air_fare.tour_code))) + 2,length(TRIM(t_booking_air_fare.tour_code)))
end
else TRIM(t_booking_air_fare.tour_code) end                                                                           
	AS tourcd,
	t_booking_document.document_dt                                                                               
	AS VendorInvoiceDate,
	(	SELECT
			crs_id 
		FROM
			m_supplier 
		WHERE
			m_supplier.supplier_pid=t_booking_air.supplier_xid 
	)
	AS crs_pnr_no,
	0                                                                                                            
	AS savamount,
	CASE 
		WHEN t_booking_air.is_lcc='Y' 
		THEN TRIM(t_booking_air_pnr.airline_pnr) 
		ELSE case when (
SELECT enable_regional_pcc FROM m_supplier 
where supplier_pid=t_booking_air.supplier_xid
)='Y' then tkt_no else
t_booking_air_sector_pax_dtl.old_tkt_no end
			END                                                                                                              
	AS dsr_remarks,
	''                                                                                                           
	AS servicename,
	''                                                                                                           
	AS servicecategory,
	NULL                                                                                                         
	AS checkindate,
	NULL                                                                                                         
	AS checkoutdate,
	''                                                                                                           
	AS servicecity,
	''                                                                                                           
	AS remarks,
	(	SELECT
			TRIM(cost_center_code) 
		FROM
			m_cost_center 
		WHERE
			cost_center_pid=t_booking_air_pax.cost_center_xid 
	)
	AS costcenterno,
	TRIM(t_booking_air_pax.country)                                                                              
	AS visacountry,
	NULL                                                                                                         
	AS rbdeposit,
	NULL                                                                                                         
	AS rbdeposit2,
	COALESCE(t_booking_air_fare.trans_fee_cons_curr,2)                                                           
	AS Transfee,
	0                                                                                                            
	AS transfeed,
	NULL                                                                                                         
	AS transfee2,
	NULL                                                                                                         
	AS transfeed2,
	''                                                                                                           
	AS ca,
	TRIM(t_booking_air.primary_carrier)                                                                          
	AS airlcd,
	TRIM(fmcity_xid)                                                                                             
	AS frmdestcd,
	TRIM(tocity_xid)                                                                                             
	AS todestcd,
	CASE 
		WHEN (LENGTH(t_booking_air_pax.first_name)+LENGTH(t_booking_air_pax. 
		last_name)+LENGTH(t_booking_air_pax.title)) >38 
		THEN COALESCE(SUBSTRING (TRIM(t_booking_air_pax.last_name),1,17) ,'')|| 
		' ' ||COALESCE(SUBSTRING (TRIM(t_booking_air_pax.first_name),1,16) ,'') 
		||' ' ||COALESCE(SUBSTRING (TRIM(t_booking_air_pax.title),1,7) ,'') 
		ELSE COALESCE(TRIM(t_booking_air_pax.last_name),'') ||' ' || COALESCE ( 
		TRIM(t_booking_air_pax.first_name),'') || ' ' ||COALESCE(TRIM( 
		t_booking_air_pax.title),'') 
	END                                                                                                              
	AS TrvName,
	''                                                                                                           
	AS isi,
case when (m_supplier.enable_regional_pcc ='Y') then 	
	'AED'||'' ||round(CAST ( (	SELECT
									SUM (tax)
								FROM
									t_booking_air_fare_tax 
								WHERE
									(t_booking_air_pnr.trans_pnr_pid= 
									t_booking_air_fare_tax.trans_pnr_xid) AND
									(t_booking_air_fare.pax_fare_pid= 
									t_booking_air_fare_tax.pax_fare_xid) ) AS VARCHAR)::NUMERIC,2)||'' || 
	'XT'
else 
array_to_string(ARRAY(	SELECT
								'AED'||'' ||round((tax)::
								NUMERIC,2) ||'' ||TRIM( tax_info) 
							FROM
								t_booking_air_fare_tax 
							WHERE
								(t_booking_air_pnr.trans_pnr_pid= 
								t_booking_air_fare_tax.trans_pnr_xid) AND
								(t_booking_air_fare.pax_fare_pid= 
								t_booking_air_fare_tax.pax_fare_xid) 
							ORDER BY
								trans_air_fare_tax_pid ASC LIMIT 1) ,',') end                                                                               
	AS taxprint1,

case when m_supplier.enable_regional_pcc = 'Y' then '' else
	array_to_string(ARRAY(	SELECT
								tax2 
							FROM
								(	SELECT
										'AED'||'' ||round((tax)::NUMERIC,2) || 
										'' || TRIM(tax_info) AS tax2 ,
										trans_air_fare_tax_pid 
									FROM
										t_booking_air_fare_tax 
									WHERE
										(t_booking_air_pnr.trans_pnr_pid= 
										t_booking_air_fare_tax.trans_pnr_xid) 
										AND
										(t_booking_air_fare.pax_fare_pid= 
										t_booking_air_fare_tax.pax_fare_xid) AND
										pax_fare_xid IN (	SELECT
																pax_fare_xid 
															FROM
																t_booking_air_fare_tax 
															WHERE
																trans_air_xid= 
																t_booking_air. 
																trans_air_pid 
															GROUP BY
																pax_fare_xid 
															HAVING
																COUNT( 
																pax_fare_xid)>1 
										)
									ORDER BY
										trans_air_fare_tax_pid ASC LIMIT 2 
								)
								t 
							ORDER BY
								trans_air_fare_tax_pid DESC LIMIT 1 ) ,',') end                                                                               
	AS taxprint2,

case when m_supplier.enable_regional_pcc = 'Y' then '' else	

	'AED'||'' ||round(CAST ( (	SELECT
									SUM (tax)- (	SELECT
																SUM (
																tax) 
															FROM
																(	SELECT
																		tax 
																	FROM
																		t_booking_air_fare_tax 
																	WHERE
																		( 
																		t_booking_air_pnr 
																		. 
																		trans_pnr_pid 
																		= 
																		t_booking_air_fare_tax 
																		. 
																		trans_pnr_xid 
																		) AND
																		( 
																		t_booking_air_fare 
																		. 
																		pax_fare_pid 
																		= 
																		t_booking_air_fare_tax 
																		. 
																		pax_fare_xid 
																		) 
																	ORDER BY
																		trans_air_fare_tax_pid 
																		ASC 
																		LIMIT 2 
																)
																t 
									)
								FROM
									t_booking_air_fare_tax 
								WHERE
									(t_booking_air_pnr.trans_pnr_pid= 
									t_booking_air_fare_tax.trans_pnr_xid) AND
									(t_booking_air_fare.pax_fare_pid= 
									t_booking_air_fare_tax.pax_fare_xid) )  AS VARCHAR)::NUMERIC,2)||'' || 
	'XT' end AS taxprint3,
	''                                                                                                           
	AS excarrcd,
	''                                                                                                           
	AS exdocno,
	''                                                                                                           
	AS exserno,
	''                                                                                                           
	AS exconj,
	CASE 
		WHEN t_booking_air.is_lcc='N' AND
		(	SELECT
				DISTINCT '1S' 
			FROM
				m_login 
			WHERE
				m_login.comp_name= m_supplier.comp_name AND
				impl_name='Sabre' 
		)
		IS NOT NULL 
		THEN TRIM(t_booking_air_pnr.gds_pnr)||'/' ||(	SELECT
															DISTINCT '1S' 
														FROM
															m_login 
														WHERE
															m_login.comp_name= 
															m_supplier.comp_name 
															AND
															impl_name='Sabre' 
		)
		WHEN t_booking_air.is_lcc='N' AND
		(	SELECT
				DISTINCT '1G' 
			FROM
				m_login 
			WHERE
				m_login.comp_name= m_supplier.comp_name AND
				impl_name='Galilieo' 
		)
		IS NOT NULL 
		THEN TRIM(t_booking_air_pnr.gds_pnr)||'/' ||(	SELECT
															DISTINCT '1G' 
														FROM
															m_login 
														WHERE
															m_login.comp_name= 
															m_supplier.comp_name 
															AND
															impl_name='Galilieo' 
		)
		WHEN t_booking_air.is_lcc='N' AND
		(	SELECT
				DISTINCT '1A' 
			FROM
				m_login 
			WHERE
				m_login.comp_name= m_supplier.comp_name AND
				impl_name='Amadeuswspremium' 
		)
		IS NOT NULL 
		THEN TRIM(t_booking_air_pnr.gds_pnr)||'/' ||(	SELECT
															DISTINCT '1A' 
														FROM
															m_login 
														WHERE
															m_login.comp_name= 
															m_supplier.comp_name 
															AND
															impl_name=
															'Amadeuswspremium' 
		)
		ELSE '' 
	END                                                                                                              
	AS bookingno,
	TRIM(CAST (t_booking_air_fare.fare_calculation AS VARCHAR))                                                  
	AS fc ,

case when (m_supplier.enable_regional_pcc  ='Y') then 	
'XT'||'('||(round(CAST ( (	SELECT
									SUM (tax)
								FROM
									t_booking_air_fare_tax 
								WHERE
									(t_booking_air_pnr.trans_pnr_pid= 
									t_booking_air_fare_tax.trans_pnr_xid) AND
									(t_booking_air_fare.pax_fare_pid= 
									t_booking_air_fare_tax.pax_fare_xid) ) AS VARCHAR)::NUMERIC,2))||')' else
	array_to_string(ARRAY(	SELECT
								TRIM(tax_info) ||'(' ||round((tax):: 
								NUMERIC,2) ||')' 
							FROM
								t_booking_air_fare_tax 
							WHERE
								(t_booking_air_pnr.trans_pnr_pid= 
								t_booking_air_fare_tax.trans_pnr_xid) AND
								(t_booking_air_fare.pax_fare_pid= 
								t_booking_air_fare_tax.pax_fare_xid) 
							ORDER BY
								trans_air_fare_tax_pid ASC ) ,',') end                                                                                
	AS tax ,
	TRIM(fm_iata_xid)||'-'|| TRIM(to_iata_xid)                                                                   
	AS sector,
	CASE WHEN TRIM(t_booking_air_sector.status_code) = 'AA'
    THEN 'HK'
	ELSE TRIM(t_booking_air_sector.status_code) END                                                                       
	AS stcd,
	TRIM(t_booking_air_sector.fare_basis)                                                                        
	AS fbno,
	TRIM(t_booking_air.primary_carrier)                                                                          
	AS carrcd,
	TRIM(flight_no)                                                                                              
	AS flightno,
	substring(TRIM(booking_class),1,1)                                                                                          
	AS classcd,
	dep_date                                                                                                     
	AS depdate,
	dep_time                                                                                                     
	AS deptime,
	arr_date                                                                                                     
	AS arrdate,
	arr_time                                                                                                     
	AS arrtime,
    CASE 
	WHEN TRIM(t_booking_air_sector_pax_dtl.baggage_allowance) IN ('NIN','-NA-')
    THEN 'NIL'
    ELSE LEFT(TRIM(t_booking_air_sector_pax_dtl.baggage_allowance),3) END
	AS allow,
	t_booking_air_sector_pax_dtl.not_valid_before                                                                
	AS nvb,
	t_booking_air_sector_pax_dtl.not_valid_after                                                                 
	AS nva,
	TRIM(t_booking_air_sector.airline_xid)                                                                       
	AS operbycarrcode,
	TRIM(t_booking_air_sector.code_share_flight)                                                                 
	AS opercarrcd,
	TRIM(flight_no)                                                                                              
	AS operflight,
	TRIM(t_booking_air_pax.mealpref)                                                                             
	AS meal,
	'0'                                                                                                          
	AS nostop,
	TRIM(t_booking_air_sector.duration)                                                                          
	AS journeytime,
	TRIM(t_booking_air_sector.equipment_type)                                                                    
	AS equipmenttype,
	CASE 
		WHEN t_booking_air.is_lcc='N' 
		THEN TRIM(t_booking_air_sector_pax_dtl.tkt_no) 
		ELSE '' 
	END                                                                                                              
	AS serno,
	CASE 
		WHEN (LENGTH(t_booking_air_pax.first_name)+LENGTH(t_booking_air_pax. 
		last_name)+LENGTH(t_booking_air_pax.title)) >38 
		THEN COALESCE(SUBSTRING (TRIM(t_booking_air_pax.last_name),1,17) ,'')|| 
		' ' ||COALESCE(SUBSTRING (TRIM(t_booking_air_pax.first_name),1,16) ,'') 
		||' ' ||COALESCE(SUBSTRING (TRIM(t_booking_air_pax.title),1,7) ,'') 
		ELSE COALESCE(TRIM(t_booking_air_pax.last_name),'') ||' ' || COALESCE ( 
		TRIM(t_booking_air_pax.first_name),'') || ' ' ||COALESCE(TRIM( 
		t_booking_air_pax.title),'') 
	END                                                                                                              
	AS TrvName,
	''                                                                                                           
	AS admcd,
	(	SELECT
			COALESCE(TRIM(reference_number),'') 
		FROM
			m_traveller 
		WHERE
			traveller_pid =t_booking_air_pax.traveller_xid 
	)
	AS empno,
	(	SELECT
			TRIM(project_code) 
		FROM
			m_project 
		WHERE
			project_pid=t_booking_air_pax.project_xid 
	)
	AS projno,
	case when t_booking_document_dtl.fop_name = 'CC-CPG'
    THEN t_booking_document_dtl.ordercode
    else
	TRIM(CAST(COALESCE (t_booking_air_pax.traveller_xid,dependent_xid)
     AS 
	VARCHAR))         end                      AS reqno,
	NULL                                                                                                         
	AS costcenter,
	NULL                                                                                                         
	AS fareid,
	NULL                                                                                                         
	AS farequoteid,
	NULL                                                                                                         
	AS dbinfo,
	NULL                                                                                                         
	AS dbinfocardtype ,
	TRIM(is_miscellaneous)                                                                                       
	AS is_miscellaneous,
	NULL,
	NULL,
	NULL,
	NULL,
	NULL,
	NULL,
	is_lcc_ancillary                                                                                             
	AS is_lcc_ancillary ,
	t_booking_air.is_lcc                                                                                         
	AS is_lcc ,protas_order_no,
    t_booking_document_dtl.fop_type,
    credit_card_no,
    CASE 
    WHEN approved_key ILIKE '%/%'
    THEN left(approved_key, strpos(approved_key, '/') - 1)
    ELSE
    approved_key
    END,
case when TRIM(t_booking_air.tour_code) ilike '%*%' then 
case when TRIM(t_booking_air.tour_code) like '%\/%' then 
substring (TRIM(t_booking_air.tour_code), 
length(TRIM(t_booking_air.tour_code)) - position('*' in reverse_string(TRIM(t_booking_air.tour_code))) + 2,
position('/' in (TRIM(t_booking_air.tour_code))) - (length(TRIM(t_booking_air.tour_code)) - position('*' in reverse_string(TRIM(t_booking_air.tour_code))) + 2))
else substring (TRIM(t_booking_air_fare.tour_code),
length(TRIM(t_booking_air.tour_code)) - position('*' in reverse_string(TRIM(t_booking_air.tour_code))) + 2,length(TRIM(t_booking_air.tour_code)))
end
else TRIM(t_booking_air.tour_code) end  

,
	'eTravel',
	round((t_booking_air_fare.markup+t_booking_air_fare.adhoc_markup_sell_curr + case when COALESCE(t_booking_air_fare.regional_pcc_markup,0)>=0 then COALESCE(t_booking_air_fare.regional_pcc_markup,0) else 0 end )::NUMERIC,2),
CASE WHEN (select upper(country) from m_iata where iata_pid=tocity_xid)<>upper('BAHRAIN')then	'VX' 
else
		case	WHEN (	SELECT
						country_code 
					FROM
						m_country 
					WHERE
						UPPER(country_name) =(	SELECT
													UPPER(country) 
												FROM
													m_supplier 
												WHERE
													supplier_pid=t_booking_air.supplier_xid
						)
			)
			='BH' 
			THEN 'V5' else 'V0' end 
		END  ,
			round((((COALESCE(t_booking_air_fare.base_fare_supp_curr,0))* COALESCE(
	t_booking_air_fare. suppliertoadminexcgrate,0)) +COALESCE(t_booking_air_fare
	.adhoc_markup_cons_curr, 0) +COALESCE(t_booking_air_fare.markup_cons_curr,0) + case when COALESCE(t_booking_air_fare.regional_pcc_markup,0)>=0 then COALESCE(t_booking_air_fare.regional_pcc_markup,0) else 0 end
	)::NUMERIC, 2),
	round((((COALESCE(t_booking_air_fare.base_fare_supp_curr,0))* COALESCE(
	t_booking_air_fare. suppliertoadminexcgrate,0)) +COALESCE(t_booking_air_fare
	.adhoc_markup_cons_curr, 0) +COALESCE(t_booking_air_fare.markup_cons_curr,0) + case when COALESCE(t_booking_air_fare.regional_pcc_markup,0)>=0 then COALESCE(t_booking_air_fare.regional_pcc_markup,0) else 0 end
	)::NUMERIC, 2),
	0,
	case when (select upper(country) from m_iata where iata_pid=tocity_xid)=upper('BAHRAIN')then	'V5' else 'VX' end,
	0,
	0,
CASE WHEN (select upper(country) from m_iata where iata_pid=tocity_xid)<>upper('BAHRAIN')then	'VX' 
else
		case	WHEN (	SELECT
						country_code 
					FROM
						m_country 
					WHERE
						UPPER(country_name) =(	SELECT
													UPPER(country) 
												FROM
													m_supplier 
												WHERE
													supplier_pid=t_booking_air.supplier_xid
						)
			)
			='BH' 
			THEN 'V5' else 'V0' end 
		END  ,
	0,
	'',
	0,
	'',
	0,
	'Service',
	to_char(t_booking_air.travel_dt::DATE,'dd-Mon-yyyy'),
	'',
	(	SELECT
			TRIM(country_code) 
		FROM
			m_country 
		WHERE
			UPPER(country_name) =(	SELECT
										UPPER(country) 
									FROM
										m_supplier 
									WHERE
										supplier_pid=t_booking_air.supplier_xid
			)
	)
	,
	(	SELECT
			TRIM(country_code) 
		FROM
			m_country 
		WHERE
			UPPER(country_name) =(	SELECT
										UPPER(country) 
									FROM
										m_client 
									WHERE
										client_pid=t_booking.client_xid
			)
	)
	,
	(	SELECT
			vat_registration_no 
		FROM
			m_client 
		WHERE
			client_pid=t_booking.client_xid
	)
	,
	'',
	'',is_pnr_sync_only ,supplier_pid,protas_hit_count
FROM
	t_booking 
		JOIN t_booking_air 
		ON (trans_pid=t_booking_air.trans_xid) 
			JOIN t_booking_air_pax 
			ON (trans_air_pid=t_booking_air_pax.trans_air_xid) 
				JOIN t_booking_document 
				ON(t_booking_document.trans_xid = t_booking.trans_pid AND
				(string_to_array(selected_travelers_ids,',')@>string_to_array( 
				'T-'||traveller_xid,',')) OR
				(string_to_array(selected_travelers_ids,',')@>string_to_array( 
				'D-'||dependent_xid,','))) 
					JOIN t_booking_document_dtl 
					ON (t_booking_document_dtl.trans_doc_xid = 
					t_booking_document.trans_doc_pid AND
					trans_prod_xid = trans_air_pid AND
					(t_booking_document_dtl.air_pax_xid = air_pax_pid OR
					t_booking_document_dtl.air_pax_xid IS NULL)) 
						JOIN m_client 
						ON (client_pid=t_booking.client_xid) 
							JOIN t_booking_air_sector 
							ON (t_booking.trans_pid=t_booking_air_sector. 
							trans_xid AND
							t_booking_air.trans_air_pid=t_booking_air_sector. 
							trans_air_xid) 
								JOIN t_booking_air_sector_pax_dtl 
								ON (t_booking_air.trans_air_pid= 
								t_booking_air_sector_pax_dtl.trans_air_xid AND
								t_booking_air_pax.air_pax_pid= 
								t_booking_air_sector_pax_dtl.air_pax_xid AND
								t_booking_air_sector.air_leg_pid= 
								t_booking_air_sector_pax_dtl.air_leg_xid AND
								t_booking.trans_pid=t_booking_air_sector_pax_dtl 
								.trans_xid ) 
									JOIN t_booking_air_fare 
									ON (t_booking.trans_pid=t_booking_air_fare. 
									trans_xid AND
									t_booking_air.trans_air_pid= 
									t_booking_air_fare.trans_air_xid AND
									t_booking_air_pax.air_pax_pid= 
									t_booking_air_fare.air_pax_xid) 
										JOIN m_supplier 
										ON (t_booking_air.supplier_xid = 
										m_supplier.supplier_pid) 
											JOIN m_login_user 
											ON (login_user_pid=t_booking. 
											employee_xid) 
												JOIN t_booking_air_pnr 
												ON (trans_pid=t_booking_air_pnr. 
												trans_xid AND
												trans_air_pid=t_booking_air_pnr. 
												trans_air_xid) 
													LEFT JOIN 
													t_booking_air_reissue_ticket 
													ON (trans_pid= 
													t_booking_air_reissue_ticket 
													.trans_xid AND
													trans_air_pid= 
													t_booking_air_reissue_ticket 
													.trans_air_xid) 
WHERE
	document_no = ls_invoice_no AND
            (SELECT count(total_tax_supp_curr) FROM t_booking_air_fare 
where trans_xid=(SELECT trans_xid FROM t_booking_document WHERE document_no=ls_invoice_no) and total_tax_supp_curr is not null)=((SELECT count(*) FROM t_booking_air_fare where trans_xid=(SELECT trans_xid FROM t_booking_document WHERE document_no=ls_invoice_no))) AND
	doc_type='I' AND
	t_booking_air.is_lcc='N'  and is_invoice_blocked= 'N'
UNION
	ALL 
SELECT
	trans_doc_pid                                                                   
	AS doc_id,
	'H'                                                                             
	AS product,
	trans_hotel_pid                                                                 
	AS product_id,
	NULL                                                                            
	AS leg_pax_pid,
	TRIM(m_client.account_code)                                                     
	AS AccNo,
	(	SELECT
			TRIM(branch_code) 
		FROM
			m_branch 
		WHERE
			branch_pid=t_booking_hotel.branch_xid 
	)
	AS OffNo,
	(	SELECT
			employee_no 
		FROM
			m_login_user 
		WHERE
			login_user_pid=t_booking_hotel.salesman_xid 
	)
	AS SalNo,
	(	SELECT
			TRIM(branch_code) 
		FROM
			m_branch 
		WHERE
			branch_pid=(SELECT
							branch_xid 
						FROM
							m_client_branch_mapping 
						WHERE
							client_xid=t_booking.client_xid AND
							is_default='Y' 
			)
	)
	AS OwnOffNo,
	t_booking_hotel.travel_type                                                     
	AS CustType,
	NULL                                                                            
	AS OrdEmpNo,
	CASE 
		WHEN (LENGTH(t_booking_hotel.lead_firstname)+LENGTH(t_booking_hotel. 
		lead_lastname)+LENGTH(t_booking_hotel.lead_title)) >38 
		THEN COALESCE(SUBSTRING (TRIM(t_booking_hotel.lead_lastname),1,17) ,'') 
		||' ' ||COALESCE(SUBSTRING (TRIM(t_booking_hotel.lead_firstname),1,16) , 
		'') ||' ' ||COALESCE(SUBSTRING (TRIM(t_booking_hotel.lead_title),1,7) , 
		'') 
		ELSE COALESCE(TRIM(t_booking_hotel.lead_lastname),'') ||' ' || COALESCE 
		(TRIM(t_booking_hotel.lead_firstname),'') || ' ' ||COALESCE(TRIM( 
		t_booking_hotel.lead_title),'') 
	END                                                                                 
	AS TrvName,
	case when t_booking_document_dtl.fop_name = 'CC-CPG'
    THEN t_booking_document_dtl.ordercode
    else
	TRIM(t_booking_hotel.lpo_number)  end                                              
	AS ReqNo,
	'0'                                                                             
	AS IT,
	(	SELECT
			TRIM(branch_code) 
		FROM
			m_branch 
		WHERE
			branch_pid=t_booking_hotel.booking_branch_xid 
	)
	AS BookingOffNo,
	(	SELECT
			TRIM(cost_center_code) 
		FROM
			m_cost_center 
		WHERE
			cost_center_pid=(	SELECT
									DISTINCT cost_center_xid 
								FROM
									t_booking_hotel_pass_dtl 
								WHERE
									trans_hotel_xid=t_booking_hotel. 
									trans_hotel_pid AND
									cost_center_xid IS NOT NULL 
			)
	)
	AS CostCenter,
	''                                                                              
	AS ApprCd,
	(	SELECT
			TRIM(project_code) 
		FROM
			m_project 
		WHERE
			project_pid =(	SELECT
								DISTINCT project_xid 
							FROM
								t_booking_hotel_pass_dtl 
							WHERE
								trans_hotel_xid=t_booking_hotel.trans_hotel_pid 
								AND
								project_xid IS NOT NULL 
			)
	)
	AS project_no,
	t_booking_hotel.fm_dt                                                           
	AS TravelDate,
	'N'                                                                             
	AS Exchangetrans,
		(SELECT


					fop_no 
				FROM
					m_fop_meta 
				WHERE
					m_fop_meta.fop=
(CASE
WHEN t_booking_hotel.mode_of_booking in  ('CS','PG','CC') 
THEN
COALESCE(t_booking_document_dtl.fop_name,t_booking_hotel.mode_of_booking) 
ELSE
t_booking_hotel.mode_of_booking
END) )
AS FOPNo,
case
when t_booking_document_dtl.fop_name in ('CC-UCCCF') then 4
else null end  AS FOPNo2,
	CASE 
		WHEN t_booking.fop_type='PT' 
		THEN TRIM(t_booking_hotel.mode_of_booking) 
		ELSE (	SELECT
					TRIM(mop) 
				FROM
					(	SELECT
							mop,
							trans_pax_mop_pid 
						FROM
							t_booking_pax_mop 
						WHERE
							t_booking_pax_mop.trans_prod_xid=t_booking_hotel. 
							trans_hotel_pid AND
							trans_doc_xid=t_booking_document.trans_doc_pid 
						ORDER BY
							trans_pax_mop_pid ASC LIMIT 1 
					)
					t 
		)
	END                                                                                 
	AS mop,
	(	SELECT
			TRIM(mop) 
		FROM
			(	SELECT
					mop,
					trans_pax_mop_pid 
				FROM
					t_booking_pax_mop 
				WHERE
					t_booking_pax_mop.trans_prod_xid=t_booking_hotel. 
					trans_hotel_pid AND
					trans_doc_xid=t_booking_document.trans_doc_pid 
				ORDER BY
					trans_pax_mop_pid ASC LIMIT 2 
			)
			t 
		ORDER BY
			trans_pax_mop_pid DESC LIMIT 1 
	)
	AS mop1,
	(	SELECT
			type_no 
		FROM
			m_document_master 
		WHERE
			doc_code=t_booking_hotel.doc_code 
	)
	AS TypeNo,
	(	SELECT
			TRIM(CAST (doc_no AS VARCHAR)) 
		FROM
			m_document_master 
		WHERE
			doc_code=t_booking_hotel.doc_code 
	)
	AS DocNo,
	NULL                                                                            
	AS SerNo,
	CASE 
		WHEN t_booking_hotel.is_miscellaneous='Y' 
		THEN (	SELECT
					DISTINCT TRIM(city_code) 
				FROM
					m_city 
				WHERE
					LOWER(city_name) = LOWER(m_hotel.city) AND
					city_code IS NOT NULL LIMIT 1 
		)
		ELSE (	SELECT
					TRIM(city_code) 
				FROM
					m_city 
				WHERE
					LOWER(city_name) = LOWER(m_hotel.city) AND
					country_xid=(	SELECT
										country_pid 
									FROM
										m_country 
									WHERE
										LOWER(country_name)=LOWER(m_hotel. 
										country) 
					)
		)
	END                                                                                 
	AS DestCd,
	CASE 
		WHEN t_booking_hotel.is_miscellaneous='Y' 
		THEN (	SELECT
					round(COALESCE (commission_perc,0) ::NUMERIC,2) 
				FROM
					t_booking_hotel_price_dtl 
				WHERE
					trans_prod_xid=t_booking_hotel.trans_hotel_pid 
		)
		ELSE NULL 
	END                                                                                 
	AS CommPct,
	COALESCE(t_booking_hotel.no_adults,0)+COALESCE(t_booking_hotel.no_childrens, 
	0) AS Grp,
	NULL                                                                            
	AS conjNo,
round((((t_booking_hotel.buying_amt*sup_client_exc_rate)-input_tax+(
	total_markup_amt_sell_curr+adhoc_markup_sell_curr))/ 
	adm_to_client_exchange_rate)::NUMERIC,2) 
	AS SalAmountLocal,
	CASE 
		WHEN t_booking_hotel.is_miscellaneous='Y' 
		THEN (	SELECT
					round((COALESCE(((buying_cons_curr_amt* 
					t_booking_hotel_price_dtl.commission_perc) / 100) ,0) + 
					COALESCE(t_booking_hotel.adhoc_markup_cons_curr,0) + 
					COALESCE(t_booking_hotel.total_markup_amt_cons_curr,0)):: 
					NUMERIC,2) 
				FROM
					t_booking_hotel_price_dtl 
				WHERE
					trans_prod_xid=t_booking_hotel.trans_hotel_pid 
		)
		ELSE round( (COALESCE(t_booking_hotel.total_markup_amt_cons_curr,0) + 
		COALESCE(t_booking_hotel.adhoc_markup_cons_curr,0)) ::NUMERIC, 2) 
	END                                                                                 
	AS CommAmt,
	round(( 
	COALESCE(t_booking_hotel.total_gen_tax_amt_cons_curr,0))::NUMERIC,2)                                                            
	AS TaxAmount,
	round((t_booking_hotel.total_discount_amt_cons_curr + COALESCE(
	t_booking_hotel.adhoc_rebate_cons_curr,0) ) ::NUMERIC,2)AS Rbamount,
	NULL                                                                            
	AS Rbamount2,
	round((COALESCE(t_booking_hotel.buying_cons_curr_amt,0)+COALESCE( 
	t_booking_hotel.total_markup_amt_cons_curr,0) +COALESCE(t_booking_hotel. 
	adhoc_markup_cons_curr,0) )::NUMERIC, 2)                                                           
	AS EqAmount,
	''                                                                              
	AS ValueCd,
	TRIM(t_booking_hotel.buying_currency)                                           
	AS PurrCurrCd,
	round(100/ COALESCE(t_booking_hotel.buying_cons_exc_rt,1)::NUMERIC,5)           
	AS PurRate,
	round((t_booking_hotel.buying_amt -( 
	CASE 
		WHEN t_booking_hotel.is_miscellaneous='Y' 
		THEN (	SELECT
					COALESCE(((t_booking_hotel.buying_amt* 
					t_booking_hotel_price_dtl.commission_perc) / 100) ,0) 
				FROM
					t_booking_hotel_price_dtl 
				WHERE
					trans_prod_xid=t_booking_hotel.trans_hotel_pid 
		)
		ELSE 0 
	END ))::NUMERIC,2)                                                            
	AS PurAmount,
    CASE WHEN UPPER(impl_name) = 'YALAGO'
    THEN (SELECT accno FROM m_yalaogo_vendor_currency_meta WHERE currency_code = t_booking_hotel.buying_currency)
    ELSE   
	TRIM(m_supplier.account_code)                                                   
    END	AS AccNo,
	TRIM(t_booking.booking_no)                                                      
	AS VendInvoNo,
	NULL                                                                            
	AS FopAmt2,
	''                                                                              
	AS PNRno,
	''                                                                              
	AS tourcd,
	t_booking_hotel.fm_dt                                                           
	AS VendorInvoiceDate,
	(	SELECT
			crs_id 
		FROM
			m_supplier 
		WHERE
			m_supplier.supplier_pid=t_booking_hotel.supplier_xid 
	)
	AS crs_pnr_no,
	0                                                                               
	AS savamount,
	TRIM(t_booking_hotel.sup_ref_no)                                                
	AS dsr_remarks,
	TRIM(t_booking_hotel.hotel_name)                                                
	AS servicename,
	LEFT(TRIM(t_booking_hotel.room_type),100)                                                 
	AS servicecategory,
	t_booking_hotel.fm_dt                                                           
	AS checkindate,
	t_booking_hotel.to_dt                                                           
	AS checkoutdate,
	TRIM(m_hotel.city)                                                              
	AS servicecity,
	COALESCE(TRIM(t_booking.checkout_remarks),'')                                   
	AS remarks,
	(	SELECT
			TRIM(cost_center_code) 
		FROM
			m_cost_center 
		WHERE
			cost_center_pid=(	SELECT
									DISTINCT cost_center_xid 
								FROM
									t_booking_hotel_pass_dtl 
								WHERE
									trans_hotel_xid=t_booking_hotel. 
									trans_hotel_pid AND
									cost_center_xid IS NOT NULL 
			)
	)
	AS costcenterno,
	TRIM(m_hotel.country)                                                           
	AS visacountry,
	NULL                                                                            
	AS rbdeposit,
	NULL                                                                            
	AS rbdeposit2,
	COALESCE(t_booking_hotel.total_transfee_amt_cons_curr,0)                        
	AS Transfee,
	NULL                                                                            
	AS transfeed,
	NULL                                                                            
	AS transfee2,
	NULL                                                                            
	AS transfeed2,
	''                                                                              
	AS ca,
	''                                                                              
	AS airlcd,
	''                                                                              
	AS frmdestcd,
	''                                                                              
	AS todestcd,
	CASE 
		WHEN (LENGTH(t_booking_hotel.lead_firstname)+LENGTH(t_booking_hotel. 
		lead_lastname)+LENGTH(t_booking_hotel.lead_title)) >38 
		THEN COALESCE(SUBSTRING (TRIM(t_booking_hotel.lead_lastname),1,17) ,'') 
		||' ' ||COALESCE(SUBSTRING (TRIM(t_booking_hotel.lead_firstname),1,16) , 
		'') ||' ' ||COALESCE(SUBSTRING (TRIM(t_booking_hotel.lead_title),1,7) , 
		'') 
		ELSE COALESCE(TRIM(t_booking_hotel.lead_lastname),'') ||' ' || COALESCE 
		(TRIM(t_booking_hotel.lead_firstname),'') || ' ' ||COALESCE(TRIM( 
		t_booking_hotel.lead_title),'') 
	END                                                                                 
	AS TrvName,
	''                                                                              
	AS isi,
	''                                                                              
	AS taxprint1,
	''                                                                              
	AS taxprint2,
	''                                                                              
	AS taxprint3,
	''                                                                              
	AS excarrcd,
	''                                                                              
	AS exdocno,
	''                                                                              
	AS exserno,
	''                                                                              
	AS exconj,
	TRIM(t_booking_hotel.sup_ref_no)                                                
	AS bookingno,
	''                                                                              
	AS fc ,
	''                                                                              
	AS tax ,
	''                                                                              
	AS sector,
	''                                                                              
	AS stcd,
	''                                                                              
	AS fbno,
	''                                                                              
	AS carrcd,
	''                                                                              
	AS flightno,
	''                                                                              
	AS classcd,
	NULL                                                                            
	AS depdate,
	''                                                                              
	AS deptime,
	NULL                                                                            
	AS arrdate,
	''                                                                              
	AS arrtime,
	''                                                                              
	AS allow,
	''                                                                              
	AS nvb,
	''                                                                              
	AS nva,
	''                                                                              
	AS operbycarrcode,
	''                                                                              
	AS opercarrcd,
	''                                                                              
	AS operflight,
	''                                                                              
	AS meal,
	''                                                                              
	AS nostop,
	''                                                                              
	AS journeytime,
	''                                                                              
	AS equipmenttype,
	''                                                                              
	AS serno,
	''                                                                              
	AS TrvName,
	''                                                                              
	AS admcd,
	''                                                                              
	AS empno,
	''                                                                              
	AS projno,
	case when t_booking_document_dtl.fop_name = 'CC-CPG'
    THEN t_booking_document_dtl.ordercode
    else
    ''  end                                                                            
	AS reqno,
	''                                                                              
	AS costcenter,
	''                                                                              
	AS fareid,
	''                                                                              
	AS farequoteid,
	''                                                                              
	AS dbinfo,
	''                                                                              
	AS dbinfocardtype ,
	TRIM(is_miscellaneous)                                                          
	AS is_miscellaneous,
	'',
	'',
	'',
	NULL,
	'' ,
	'',
	'N'                                                                             
	AS is_lcc_ancillary ,
	'N'                                                                             
	AS is_lcc ,protas_order_no,
    t_booking_document_dtl.fop_type,
    credit_card_no,
    CASE 
    WHEN approved_key ILIKE '%/%'
    THEN left(approved_key, strpos(approved_key, '/') - 1)
    ELSE
    approved_key
    END,'',
	'eTravel',
	round(((total_markup_amt_sell_curr / adm_to_client_exchange_rate )+
	adhoc_markup_cons_curr)::NUMERIC,2),
	  CASE 
			WHEN (select upper(country) from t_booking_hotel_param where trans_hotel_xid=t_booking_hotel.trans_hotel_pid) not IN ('BAHRAIN','BH') then 'VX'
		else
		case	WHEN (	SELECT
						country_code 
					FROM
						m_country 
					WHERE
						UPPER(country_name) =(	SELECT
													UPPER(country) 
												FROM
													m_supplier 
												WHERE
													supplier_pid=t_booking_hotel.supplier_xid
						)
			)='BH' 
			THEN 'V5' else 'V0' end 
		END  ,
	round((((t_booking_hotel.buying_amt*sup_client_exc_rate)-input_tax+(
	total_markup_amt_sell_curr+adhoc_markup_sell_curr))/ 
	adm_to_client_exchange_rate)::NUMERIC,2),
	round((((t_booking_hotel.buying_amt*sup_client_exc_rate)-input_tax+t_booking_hotel.total_service_tax_amt_sell_curr+(
	total_markup_amt_sell_curr+adhoc_markup_sell_curr))/ 
	adm_to_client_exchange_rate)::NUMERIC,2),
	round((t_booking_hotel.total_service_tax_amt_sell_curr / adm_to_client_exchange_rate)::NUMERIC,2),
	case when (select upper(country) from t_booking_hotel_param where trans_hotel_xid=t_booking_hotel.trans_hotel_pid) IN ('BAHRAIN','BH') then 'V5' else 'VX' end,

	0,
	0                                                                               
	AS comm_amt,
	CASE 
			WHEN (select upper(country) from t_booking_hotel_param where trans_hotel_xid=t_booking_hotel.trans_hotel_pid) not IN ('BAHRAIN','BH') then 'VX'
		else
		case	WHEN (	SELECT
						country_code 
					FROM
						m_country 
					WHERE
						UPPER(country_name) =(	SELECT
													UPPER(country) 
												FROM
													m_supplier 
												WHERE
													supplier_pid=t_booking_hotel.supplier_xid
						)
			)='BH' 
			THEN 'V5' else 'V0' end 
		END                                                                          
	AS purchase_vatcode ,
	input_tax,
	'',
	0,
	'',
	0,
	'Service',
	to_char(t_booking_hotel.fm_dt::DATE,'dd-Mon-yyyy'),
	CASE 
		WHEN t_booking_hotel.is_miscellaneous='N' 
		THEN (	SELECT
					TRIM(country_code) 
				FROM
					m_country 
				WHERE
					UPPER(country_name) =(	SELECT
												UPPER(country) 
											FROM
												m_hotel 
											WHERE
												hotel_pid=t_booking_hotel.
												hotel_xid
					)
		)
		ELSE (	SELECT
					TRIM(country_code) 
				FROM
					m_country 
				WHERE
					(	SELECT
							UPPER(city) 
						FROM
							m_hotel 
						WHERE
							hotel_pid=t_booking_hotel.hotel_xid
					)
					LIKE '%'||UPPER(country_name)||'%'
		)
	END ,
	(	SELECT
			TRIM(country_code) 
		FROM
			m_country 
		WHERE
			UPPER(country_name) =(	SELECT
										UPPER(country) 
									FROM
										m_supplier 
									WHERE
										supplier_pid=t_booking_hotel.
										supplier_xid
			)
	)
	,
	(	SELECT
			TRIM(country_code) 
		FROM
			m_country 
		WHERE
			UPPER(country_name) =(	SELECT
										UPPER(country) 
									FROM
										m_client 
									WHERE
										client_pid=t_booking.client_xid
			)
	)
	,
	(	SELECT
			vat_registration_no 
		FROM
			m_client 
		WHERE
			client_pid=t_booking.client_xid
	)
	,
	'',
	vat_comment,'N',0,protas_hit_count
FROM
	t_booking 
		JOIN t_booking_hotel 
		ON (trans_pid=trans_xid) 
			JOIN m_client 
			ON (client_pid=client_xid) 
				JOIN m_hotel 
				ON (t_booking_hotel.hotel_xid = m_hotel.hotel_pid) 
					JOIN m_login_user 
					ON (login_user_pid=t_booking.employee_xid) 
						JOIN m_supplier 
						ON (t_booking_hotel.supplier_xid = m_supplier.supplier_pid) 
                            JOIN m_login
                                ON (login_pid = supplier_pid)
							JOIN t_booking_document 
							ON (t_booking.trans_pid=t_booking_document.trans_xid 
							) 	
								JOIN t_booking_document_dtl 
								ON (t_booking_document_dtl.trans_doc_xid = 
								t_booking_document. trans_doc_pid AND
								trans_prod_xid = trans_hotel_pid) 
WHERE
	document_no = ls_invoice_no 
and bkg_valid='Y' and is_invoice_blocked= 'N'
UNION
	ALL 
SELECT
	trans_doc_pid                                                                                                                                      
	AS doc_id,
	'X'                                                                                                                                                
	AS product,
	trans_sgt_pid                                                                                                                                      
	AS product_id,
	NULL                                                                                                                                               
	AS leg_pax_pid,
	TRIM(m_client.account_code)                                                                                                                        
	AS AccNo,
	(	SELECT
			TRIM(branch_code) 
		FROM
			m_branch 
		WHERE
			branch_pid=t_booking_sightseeing_dtl.branch_xid 
	)
	AS OffNo,
	(	SELECT
			employee_no 
		FROM
			m_login_user 
		WHERE
			login_user_pid=t_booking_sightseeing_dtl.salesman_xid 
	)
	AS SalNo,
	(	SELECT
			TRIM(branch_code) 
		FROM
			m_branch 
		WHERE
			branch_pid=(SELECT
							branch_xid 
						FROM
							m_client_branch_mapping 
						WHERE
							client_xid=t_booking.client_xid AND
							is_default='Y' 
			)
	)
	AS OwnOffNo,
	t_booking_sightseeing_dtl.travel_type                                                                                                              
	AS CustType,
	NULL                                                                                                                                               
	AS OrdEmpNo,
	TRIM(t_booking_sightseeing_dtl.lead_name)                                                                                                          
	AS TrvName,
	case when t_booking_document_dtl.fop_name = 'CC-CPG'
    THEN t_booking_document_dtl.ordercode
    else
	TRIM(t_booking_sightseeing_dtl.lpo_number)     end                                                                                                    
	AS ReqNo,
	'0'                                                                                                                                                
	AS IT,
	(	SELECT
			TRIM(branch_code) 
		FROM
			m_branch 
		WHERE
			branch_pid=t_booking_sightseeing_dtl.booking_branch_xid 
	)
	AS BookingOffNo,
	(	SELECT
			TRIM(cost_center_code) 
		FROM
			m_cost_center 
		WHERE
			cost_center_pid=(	SELECT
									DISTINCT cost_center_xid 
								FROM
									t_booking_sightseeing_pass_dtl 
								WHERE
									trans_sgt_xid=t_booking_sightseeing_dtl. 
									trans_sgt_pid AND
									cost_center_xid IS NOT NULL 
			)
	)
	AS CostCenter,
	''                                                                                                                                                 
	AS ApprCd,
	(	SELECT
			TRIM(project_code) 
		FROM
			m_project 
		WHERE
			project_pid =(	SELECT
								DISTINCT project_xid 
							FROM
								t_booking_sightseeing_pass_dtl 
							WHERE
								trans_sgt_xid=t_booking_sightseeing_dtl. 
								trans_sgt_pid AND
								project_xid IS NOT NULL 
			)
	)
	AS project_no,
	t_booking_sightseeing_dtl.fm_dt                                                                                                                    
	AS TravelDate,
	'N'                                                                                                                                                
	AS Exchangetrans,
		(SELECT


					fop_no 
				FROM
					m_fop_meta 
				WHERE
					m_fop_meta.fop=
(CASE
WHEN t_booking_sightseeing_dtl.mode_of_booking in ('CS','PG','CC') 
THEN
COALESCE(t_booking_document_dtl.fop_name,t_booking_sightseeing_dtl.mode_of_booking) 
ELSE
t_booking_sightseeing_dtl.mode_of_booking
END) )
AS FOPNo,

	null
	AS FOPNo2,
	CASE 
		WHEN t_booking.fop_type='PT' 
		THEN TRIM(t_booking_sightseeing_dtl.mode_of_booking) 
		ELSE (	SELECT
					TRIM(mop) 
				FROM
					(	SELECT
							mop,
							trans_pax_mop_pid 
						FROM
							t_booking_pax_mop 
						WHERE
							t_booking_pax_mop.trans_prod_xid= 
							t_booking_sightseeing_dtl.trans_sgt_pid AND
							trans_doc_xid=t_booking_document.trans_doc_pid 
						ORDER BY
							trans_pax_mop_pid ASC LIMIT 1 
					)
					t 
		)
	END                                                                                                                                                    
	AS mop,
	(	SELECT
			TRIM(mop) 
		FROM
			(	SELECT
					mop,
					trans_pax_mop_pid 
				FROM
					t_booking_pax_mop 
				WHERE
					t_booking_pax_mop.trans_prod_xid=t_booking_sightseeing_dtl. 
					trans_sgt_pid AND
					trans_doc_xid=t_booking_document.trans_doc_pid 
				ORDER BY
					trans_pax_mop_pid ASC LIMIT 2 
			)
			t 
		ORDER BY
			trans_pax_mop_pid DESC LIMIT 1 
	)
	AS mop1,
	(	SELECT
			type_no 
		FROM
			m_document_master 
		WHERE
			doc_code=t_booking_sightseeing_dtl.doc_code 
	)
	AS TypeNo,
	(	SELECT
			TRIM(CAST(doc_no AS VARCHAR)) 
		FROM
			m_document_master 
		WHERE
			doc_code=t_booking_sightseeing_dtl.doc_code 
	)
	AS DocNo,
	NULL                                                                                                                                               
	AS SerNo,
	(	SELECT
			TRIM(city_code) 
		FROM
			m_city 
		WHERE
			LOWER(city_name) = LOWER(t_booking_sightseeing_dtl.city) AND
			country_xid=(	SELECT
								country_pid 
							FROM
								m_country 
							WHERE
								LOWER(country_name)=LOWER( 
								t_booking_sightseeing_dtl.country) 
			)
	)
	AS DestCd,
	round(((t_booking_sightseeing_dtl.comm_received_cons_curr/ 
	buying_cons_curr_amt)*100)::NUMERIC, 2)                                                                                                                              
	AS CommPct,
	COALESCE(t_booking_sightseeing_dtl.adult_qty,0)+COALESCE( 
	t_booking_sightseeing_dtl.child_qty,0)+COALESCE(t_booking_sightseeing_dtl. 
	infant_qty,0) AS Grp,
	NULL                                                                                                                                               
	AS conjNo,
	round((COALESCE(buying_cons_curr_amt,0)+COALESCE(markup_cons_curr,0) + 
	COALESCE(total_adhoc_markup_cons_curr,0))::NUMERIC, 2)                                                                                                                              
	AS SalAmountLocal,
	round(COALESCE (t_booking_sightseeing_dtl.comm_received_cons_curr,0):: 
	NUMERIC, 2)                                                                 
	AS CommAmt,
	NULL                                                                                                                                               
	AS TaxAmount,
	round( ( ( ( (COALESCE(t_booking_sightseeing_dtl.
	total_discount_amt_client_curr,0 )) +(COALESCE(t_booking_sightseeing_dtl.
	comm_received_client_curr,0)) ) * (COALESCE(t_booking_sightseeing_dtl.
	selling_cons_exc_rt,0)) ) +(COALESCE(t_booking_sightseeing_dtl.
	total_adhoc_discount_cons_curr,0)) ) ::NUMERIC,2)AS Rbamount,
	NULL                                                                                                                                               
	AS Rbamount2,
	round((COALESCE(buying_cons_curr_amt,0)+COALESCE(markup_cons_curr,0) + 
	COALESCE(total_adhoc_markup_cons_curr,0) )::NUMERIC, 2)                                                                                                                              
	AS EqAmount,
	''                                                                                                                                                 
	AS ValueCd,
	TRIM(t_booking_sightseeing_dtl.buying_currency)                                                                                                    
	AS PurrCurrCd,
	round(100/ COALESCE(t_booking_sightseeing_dtl.buying_cons_exc_rt,1)::NUMERIC 
	,5)                                                                   AS 
	PurRate,
	round((t_booking_sightseeing_dtl.buying_amt-(t_booking_sightseeing_dtl. 
	comm_received_client_curr/sup_client_exg_rate))::NUMERIC,2)                                                                                                                               
	AS PurAmount,
	TRIM(m_supplier.account_code)                                                                                                                      
	AS AccNo,
	TRIM(t_booking.booking_no)                                                                                                                         
	AS VendInvoNo,
	NULL                                                                                                                                               
	AS FopAmt2,
	''                                                                                                                                                 
	AS PNRno,
	''                                                                                                                                                 
	AS tourcd,
	t_booking_sightseeing_dtl.fm_dt                                                                                                                    
	AS VendorInvoiceDate,
	(	SELECT
			crs_id 
		FROM
			m_supplier 
		WHERE
			m_supplier.supplier_pid=t_booking_sightseeing_dtl.supplier_xid 
	)
	AS crs_pnr_no,
	0                                                                                                                                                  
	AS savamount,
	TRIM(t_booking_sightseeing_dtl.sup_ref_no)                                                                                                         
	AS dsr_remarks,
	TRIM(t_booking_sightseeing_dtl.sightseeing_name)                                                                                                   
	AS servicename,
	NULL                                                                                                                                               
	AS servicecategory,
	t_booking_sightseeing_dtl.fm_dt                                                                                                                    
	AS checkindate,
	t_booking_sightseeing_dtl.to_dt                                                                                                                    
	AS checkoutdate,
	TRIM(t_booking_sightseeing_dtl.city)                                                                                                               
	AS servicecity,
	COALESCE(TRIM(t_booking.checkout_remarks),'')                                                                                                      
	AS remarks,
	(	SELECT
			TRIM(cost_center_code) 
		FROM
			m_cost_center 
		WHERE
			cost_center_pid=(	SELECT
									DISTINCT cost_center_xid 
								FROM
									t_booking_sightseeing_pass_dtl 
								WHERE
									trans_sgt_xid=t_booking_sightseeing_dtl. 
									trans_sgt_pid AND
									cost_center_xid IS NOT NULL 
			)
	)
	AS costcenterno,
	TRIM(t_booking_sightseeing_dtl.country)                                                                                                            
	AS visacountry,
	NULL                                                                                                                                               
	AS rbdeposit,
	NULL                                                                                                                                               
	AS rbdeposit2,
	COALESCE(trans_fee_cons_curr,0)                                                                                                                    
	AS Transfee,
	NULL                                                                                                                                               
	AS transfeed,
	NULL                                                                                                                                               
	AS transfee2,
	NULL                                                                                                                                               
	AS transfeed2,
	''                                                                                                                                                 
	AS ca,
	''                                                                                                                                                 
	AS airlcd,
	''                                                                                                                                                 
	AS frmdestcd,
	''                                                                                                                                                 
	AS todestcd,
	TRIM(t_booking_sightseeing_dtl.lead_name)                                                                                                          
	AS TrvName,
	''                                                                                                                                                 
	AS isi,
	''                                                                                                                                                 
	AS taxprint1,
	''                                                                                                                                                 
	AS taxprint2,
	''                                                                                                                                                 
	AS taxprint3,
	''                                                                                                                                                 
	AS excarrcd,
	''                                                                                                                                                 
	AS exdocno,
	''                                                                                                                                                 
	AS exserno,
	''                                                                                                                                                 
	AS exconj,
	TRIM(t_booking_sightseeing_dtl.sup_ref_no)                                                                                                         
	AS bookingno,
	''                                                                                                                                                 
	AS fc ,
	''                                                                                                                                                 
	AS tax ,
	''                                                                                                                                                 
	AS sector,
	''                                                                                                                                                 
	AS stcd,
	''                                                                                                                                                 
	AS fbno,
	''                                                                                                                                                 
	AS carrcd,
	''                                                                                                                                                 
	AS flightno,
	''                                                                                                                                                 
	AS classcd,
	NULL                                                                                                                                               
	AS depdate,
	''                                                                                                                                                 
	AS deptime,
	NULL                                                                                                                                               
	AS arrdate,
	''                                                                                                                                                 
	AS arrtime,
	''                                                                                                                                                 
	AS allow,
	''                                                                                                                                                 
	AS nvb,
	''                                                                                                                                                 
	AS nva,
	''                                                                                                                                                 
	AS operbycarrcode,
	''                                                                                                                                                 
	AS opercarrcd,
	''                                                                                                                                                 
	AS operflight,
	''                                                                                                                                                 
	AS meal,
	''                                                                                                                                                 
	AS nostop,
	''                                                                                                                                                 
	AS journeytime,
	''                                                                                                                                                 
	AS equipmenttype,
	''                                                                                                                                                 
	AS serno,
	''                                                                                                                                                 
	AS TrvName,
	''                                                                                                                                                 
	AS admcd,
	''                                                                                                                                                 
	AS empno,
	''                                                                                                                                                 
	AS projno,
	case when t_booking_document_dtl.fop_name = 'CC-CPG'
    THEN t_booking_document_dtl.ordercode
    else
	''       end                                                                                                                                          
	AS reqno,
	''                                                                                                                                                 
	AS costcenter,
	''                                                                                                                                                 
	AS fareid,
	''                                                                                                                                                 
	AS farequoteid,
	''                                                                                                                                                 
	AS dbinfo,
	''                                                                                                                                                 
	AS dbinfocardtype ,
	TRIM(is_miscellaneous)                                                                                                                             
	AS is_miscellaneous,
	'',
	'',
	'',
	NULL,
	'' ,
	'',
	'N'                                                                                                                                                
	AS is_lcc_ancillary ,
	'N'                                                                                                                                                
	AS is_lcc ,protas_order_no,
        t_booking_document_dtl.fop_type,
        credit_card_no,
        CASE 
    WHEN approved_key ILIKE '%/%'
    THEN left(approved_key, strpos(approved_key, '/') - 1)
    ELSE
    approved_key
    END,'',
	'eTravel',
	0,
	'',
	(t_booking_sightseeing_dtl.selling_amt-input_vat),
	t_booking_sightseeing_dtl.selling_amt,
	vat_tax_amt,
	'',
	0,
	0,
	'',
	input_vat,
	'',
	0,
	'',
	0,
	'Service',
	to_char(t_booking_sightseeing_dtl.fm_dt::DATE,'dd-Mon-yyyy'),
	(	SELECT
			TRIM(country_code) 
		FROM
			m_country 
		WHERE
			UPPER(country_name) =(	SELECT
										UPPER(country_name) 
									FROM
										m_sightseeing_contract 
									WHERE
										contract_pid=(	SELECT
															contract_xid 
														FROM
															m_sightseeing_tour 
														WHERE
															sightseeing_pid=
															t_booking_sightseeing_dtl
															.sightseeing_xid
										)
			)
	)
	,
	(	SELECT
			TRIM(country_code) 
		FROM
			m_country 
		WHERE
			UPPER(country_name) =(	SELECT
										UPPER(country) 
									FROM
										m_supplier 
									WHERE
										supplier_pid=t_booking_sightseeing_dtl.
										supplier_xid
			)
	)
	,
	(	SELECT
			TRIM(country_code) 
		FROM
			m_country 
		WHERE
			UPPER(country_name) =(	SELECT
										UPPER(country) 
									FROM
										m_client 
									WHERE
										client_pid=t_booking.client_xid
			)
	)
	,
	(	SELECT
			vat_registration_no 
		FROM
			m_client 
		WHERE
			client_pid=t_booking.client_xid
	)
	,
	'',
	vat_comment,'N' ,0,protas_hit_count
FROM
	t_booking 
		JOIN t_booking_sightseeing_dtl 
		ON (trans_pid=t_booking_sightseeing_dtl.trans_xid) 
			JOIN m_sightseeing_tour 
			ON (m_sightseeing_tour.sightseeing_pid=t_booking_sightseeing_dtl. 
			sightseeing_xid) 
				JOIN m_sightseeing_contract 
				ON (m_sightseeing_contract.contract_pid=contract_xid) 
					JOIN m_client 
					ON (client_pid=t_booking.client_xid) 
						JOIN m_login_user 
						ON (login_user_pid=t_booking.employee_xid) 
							JOIN m_supplier 
							ON (t_booking_sightseeing_dtl.supplier_xid = 
							m_supplier.supplier_pid) 
								JOIN t_booking_document 
								ON (t_booking.trans_pid=t_booking_document. 
								trans_xid) 
									JOIN t_booking_document_dtl 
									ON (t_booking_document_dtl.trans_doc_xid = 
									t_booking_document. trans_doc_pid AND
									trans_prod_xid = trans_sgt_pid) 
WHERE
	document_no = ls_invoice_no 
and bkg_valid='Y' and is_invoice_blocked= 'N'
UNION
	ALL 
SELECT
	trans_doc_pid                                                                    
	AS doc_id,
	'T'                                                                              
	AS product,
	trans_tra_pid                                                                    
	AS product_id,
	NULL                                                                             
	AS leg_pax_pid,
	TRIM(m_client.account_code)                                                      
	AS AccNo,
	(	SELECT
			TRIM(branch_code) 
		FROM
			m_branch 
		WHERE
			branch_pid=t_booking_transfer.branch_xid 
	)
	AS OffNo,
	(	SELECT
			employee_no 
		FROM
			m_login_user 
		WHERE
			login_user_pid=t_booking_transfer.salesman_xid 
	)
	AS SalNo,
	((	SELECT
			TRIM(branch_code) 
		FROM
			m_branch 
		WHERE
			branch_pid=(SELECT
							branch_xid 
						FROM
							m_client_branch_mapping 
						WHERE
							client_xid=t_booking.client_xid AND
							is_default='Y' 
			)
	)
	)                                                                            
	AS OwnOffNo,
	t_booking_transfer.travel_type                                                   
	AS CustType,
	NULL                                                                             
	AS OrdEmpNo,
	CASE 
		WHEN (LENGTH(t_booking_transfer.lead_firstname)+LENGTH( 
		t_booking_transfer.lead_lastname)+LENGTH(t_booking_transfer.lead_title)) 
		>38 
		THEN COALESCE(SUBSTRING (TRIM(t_booking_transfer.lead_lastname),1,17) , 
		'')||' ' ||COALESCE(SUBSTRING (TRIM(t_booking_transfer.lead_firstname),1 
		,16) ,'') ||' ' ||COALESCE(SUBSTRING (TRIM(t_booking_transfer.lead_title 
		),1,7) ,'') 
		ELSE COALESCE(TRIM(t_booking_transfer.lead_lastname),'') ||' ' || 
		COALESCE (TRIM(t_booking_transfer.lead_firstname),'') || ' ' ||COALESCE( 
		TRIM(t_booking_transfer.lead_title),'') 
	END                                                                                  
	AS TrvName,
	case when t_booking_document_dtl.fop_name = 'CC-CPG'
    THEN t_booking_document_dtl.ordercode
    else
	TRIM(t_booking_transfer.lpo_number)  end                                            
	AS ReqNo,
	'0'                                                                              
	AS IT,
	(	SELECT
			TRIM(branch_code) 
		FROM
			m_branch 
		WHERE
			branch_pid=t_booking_transfer.booking_branch_xid 
	)
	AS BookingOffNo,
	(	SELECT
			TRIM(cost_center_code) 
		FROM
			m_cost_center 
		WHERE
			cost_center_pid=(	SELECT
									DISTINCT cost_center_xid 
								FROM
									t_booking_transfer_pax 
								WHERE
									trans_tra_xid=t_booking_transfer. 
									trans_tra_pid AND
									cost_center_xid IS NOT NULL 
			)
	)
	AS CostCenter,
	''                                                                               
	AS ApprCd,
	(	SELECT
			TRIM(project_code) 
		FROM
			m_project 
		WHERE
			project_pid =(	SELECT
								DISTINCT project_xid 
							FROM
								t_booking_transfer_pax 
							WHERE
								trans_tra_xid=t_booking_transfer.trans_tra_pid 
								AND
								project_xid IS NOT NULL 
			)
	)
	AS project_no,
	t_booking_transfer.fm_dt                                                         
	AS TravelDate,
	'N'                                                                              
	AS Exchangetrans,
	(SELECT


					fop_no 
				FROM
					m_fop_meta 
				WHERE
					m_fop_meta.fop=
(CASE
WHEN t_booking_transfer.mode_of_booking in  ('CS','PG','CC') 
THEN
COALESCE(t_booking_document_dtl.fop_name,t_booking_transfer.mode_of_booking) 
ELSE
t_booking_transfer.mode_of_booking
END) )
AS FOPNo,
null AS FOPNo2,
	CASE 
		WHEN t_booking.fop_type='PT' 
		THEN TRIM(t_booking_transfer.mode_of_booking) 
		ELSE (	SELECT
					TRIM(mop) 
				FROM
					(	SELECT
							mop,
							trans_pax_mop_pid 
						FROM
							t_booking_pax_mop 
						WHERE
							t_booking_pax_mop.trans_prod_xid=t_booking_transfer. 
							trans_tra_pid AND
							trans_doc_xid=t_booking_document.trans_doc_pid 
						ORDER BY
							trans_pax_mop_pid ASC LIMIT 1 
					)
					t 
		)
	END                                                                                  
	AS mop,
	(	SELECT
			TRIM(mop) 
		FROM
			(	SELECT
					mop,
					trans_pax_mop_pid 
				FROM
					t_booking_pax_mop 
				WHERE
					t_booking_pax_mop.trans_prod_xid=t_booking_transfer. 
					trans_tra_pid AND
					trans_doc_xid=t_booking_document.trans_doc_pid 
				ORDER BY
					trans_pax_mop_pid ASC LIMIT 2 
			)
			t 
		ORDER BY
			trans_pax_mop_pid DESC LIMIT 1 
	)
	AS mop1,
	(	SELECT
			type_no 
		FROM
			m_document_master 
		WHERE
			doc_code=t_booking_transfer.doc_code 
	)
	AS TypeNo,
	(	SELECT
			TRIM(CAST(doc_no AS VARCHAR)) 
		FROM
			m_document_master 
		WHERE
			doc_code=t_booking_transfer.doc_code 
	)
	AS DocNo,
	NULL                                                                             
	AS SerNo,
	CASE 
		WHEN t_booking_transfer.is_miscellaneous='Y' 
		THEN (	SELECT
					DISTINCT TRIM(city_code) 
				FROM
					m_city 
				WHERE
					LOWER(m_city.city_name) = ( 
					CASE 
						WHEN m_transfer_contract.city_name ilike '%,%' 
						THEN ltrim(LOWER(reverse(SUBSTRING(reverse( 
						m_transfer_contract.city_name),1,POSITION (',' IN 
						reverse(m_transfer_contract.city_name))-1)))) 
						ELSE LOWER(m_transfer_contract.city_name) 
					END) AND
					m_city.city_code IS NOT NULL LIMIT 1 
		)
		ELSE (	SELECT
					city_code 
				FROM
					m_city 
				WHERE
					LOWER(m_city.city_name) = ( 
					CASE 
						WHEN m_transfer_contract.city_name ilike '%,%' 
						THEN ltrim(LOWER(reverse(SUBSTRING(reverse( 
						m_transfer_contract.city_name),1,POSITION (',' IN 
						reverse(m_transfer_contract.city_name))-1)))) 
						ELSE LOWER(m_transfer_contract.city_name) 
					END) AND
					country_xid=(	SELECT
										country_pid 
									FROM
										m_country 
									WHERE
										LOWER(country_name)=LOWER( 
										m_transfer_contract.country_name) 
					)
		)
	END                                                                                  
	AS DestCd,
	round(((t_booking_transfer.comm_received_sell_curr/(t_booking_transfer. 
	client_curr_buying_amt + t_booking_transfer.other_charges))*100)::NUMERIC, 2 
	)                                                           AS CommPct,
	COALESCE(t_booking_transfer.no_adult,0)+COALESCE(t_booking_transfer.no_child 
	,0) AS Grp,
	NULL                                                                             
	AS conjNo,
round((((client_curr_buying_amt-comm_received_sell_curr-input_tax) +(
	markup_sell_curr+adhoc_markup_sell_curr+other_charges)) / cons_sell_exc_rt)::NUMERIC,2) 	                                                             
	AS SalAmountLocal,
	round((COALESCE (t_booking_transfer.comm_received_cons_curr,0) +COALESCE( 
	adhoc_markup_cons_curr,0) + COALESCE(markup_cons_curr,0))::NUMERIC,2)                                                             
	AS CommAmt,
	round(t_booking_transfer.sup_tax_cons_curr::NUMERIC, 2)                          
	AS TaxAmount,
	round((COALESCE(t_booking_transfer.total_rebate_amt,0) + COALESCE( 
	t_booking_transfer.adhoc_rebate_cons_curr,0) + COALESCE(t_booking_transfer. 
	comm_passon_cons_curr,0))::NUMERIC,2)AS Rbamount,
	NULL                                                                             
	AS Rbamount2,
	round((COALESCE(buying_cons_curr_amt,0) +COALESCE(adhoc_markup_cons_curr,0) 
	+COALESCE(markup_cons_curr,0) +(COALESCE(other_charges,0)*(COALESCE ( 
	t_booking_transfer.selling_cons_exc_rt,1))) )::NUMERIC, 2)                                                            
	AS EqAmount,
	''                                                                               
	AS ValueCd,
	TRIM(t_booking_transfer.buying_currency)                                         
	AS PurrCurrCd,
	round(100/ COALESCE(t_booking_transfer.buying_cons_exc_rt,1)::NUMERIC,5)         
	AS PurRate,
	round((t_booking_transfer.client_curr_buying_amt *(COALESCE ( 
	t_booking_transfer.client_buy_exc_rt,1)) +(COALESCE(other_charges,0)*(
	COALESCE ( t_booking_transfer.client_buy_exc_rt,1))) +(t_booking_transfer. 
	supp_tax_supp_curr ))::NUMERIC,2)                                                             
	AS PurAmount,
	TRIM(m_supplier.account_code)                                                    
	AS AccNo,
	TRIM(t_booking.booking_no)                                                       
	AS VendInvoNo,
	NULL                                                                             
	AS FopAmt2,
	''                                                                               
	AS PNRno,
	''                                                                               
	AS tourcd,
	t_booking_transfer.fm_dt                                                         
	AS VendorInvoiceDate,
	(	SELECT
			crs_id 
		FROM
			m_supplier 
		WHERE
			m_supplier.supplier_pid=t_booking_transfer.supplier_xid 
	)
	AS crs_pnr_no,
	0                                                                                
	AS savamount,
	TRIM(t_booking_transfer.sup_ref_no)                                              
	AS dsr_remarks,
	TRIM(t_booking_transfer.vehicle_name)                                            
	AS servicename,
	NULL                                                                             
	AS servicecategory,
	t_booking_transfer.fm_dt                                                         
	AS checkindate,
	t_booking_transfer.to_dt                                                         
	AS checkoutdate,
	TRIM(m_transfer_contract.city_name)                                              
	AS servicecity,
	COALESCE(TRIM(t_booking.checkout_remarks),'')                                    
	AS remarks,
	(	SELECT
			TRIM(cost_center_code) 
		FROM
			m_cost_center 
		WHERE
			cost_center_pid=(	SELECT
									DISTINCT cost_center_xid 
								FROM
									t_booking_transfer_pax 
								WHERE
									trans_tra_xid=t_booking_transfer. 
									trans_tra_pid AND
									cost_center_xid IS NOT NULL 
			)
	)
	AS costcenterno,
	TRIM(m_transfer_contract.country_name)                                           
	AS visacountry,
	NULL                                                                             
	AS rbdeposit,
	NULL                                                                             
	AS rbdeposit2,
	COALESCE(trans_fee_cons_curr,0)                                                  
	AS Transfee,
	NULL                                                                             
	AS transfeed,
	NULL                                                                             
	AS transfee2,
	NULL                                                                             
	AS transfeed2,
	''                                                                               
	AS ca,
	''                                                                               
	AS airlcd,
	''                                                                               
	AS frmdestcd,
	''                                                                               
	AS todestcd,
	CASE 
		WHEN (LENGTH(t_booking_transfer.lead_firstname)+LENGTH( 
		t_booking_transfer.lead_lastname)+LENGTH(t_booking_transfer.lead_title)) 
		>38 
		THEN COALESCE(SUBSTRING (TRIM(t_booking_transfer.lead_lastname),1,17) , 
		'')||' ' ||COALESCE(SUBSTRING (TRIM(t_booking_transfer.lead_firstname),1 
		,16) ,'') ||' ' ||COALESCE(SUBSTRING (TRIM(t_booking_transfer.lead_title 
		),1,7) ,'') 
		ELSE COALESCE(TRIM(t_booking_transfer.lead_lastname),'') ||' ' || 
		COALESCE (TRIM(t_booking_transfer.lead_firstname),'') || ' ' ||COALESCE( 
		TRIM(t_booking_transfer.lead_title),'') 
	END                                                                                  
	AS TrvName,
	''                                                                               
	AS isi,
	''                                                                               
	AS taxprint1,
	''                                                                               
	AS taxprint2,
	''                                                                               
	AS taxprint3,
	''                                                                               
	AS excarrcd,
	''                                                                               
	AS exdocno,
	''                                                                               
	AS exserno,
	''                                                                               
	AS exconj,
	TRIM(t_booking_transfer.sup_ref_no)                                              
	AS bookingno,
	''                                                                               
	AS fc ,
	''                                                                               
	AS tax ,
	''                                                                               
	AS sector,
	''                                                                               
	AS stcd,
	''                                                                               
	AS fbno,
	''                                                                               
	AS carrcd,
	''                                                                               
	AS flightno,
	''                                                                               
	AS classcd,
	NULL                                                                             
	AS depdate,
	''                                                                               
	AS deptime,
	NULL                                                                             
	AS arrdate,
	''                                                                               
	AS arrtime,
	''                                                                               
	AS allow,
	''                                                                               
	AS nvb,
	''                                                                               
	AS nva,
	''                                                                               
	AS operbycarrcode,
	''                                                                               
	AS opercarrcd,
	''                                                                               
	AS operflight,
	''                                                                               
	AS meal,
	''                                                                               
	AS nostop,
	''                                                                               
	AS journeytime,
	''                                                                               
	AS equipmenttype,
	''                                                                               
	AS serno,
	''                                                                               
	AS TrvName,
	''                                                                               
	AS admcd,
	''                                                                               
	AS empno,
	''                                                                               
	AS projno,
	 case when t_booking_document_dtl.fop_name = 'CC-CPG'
    THEN t_booking_document_dtl.ordercode
    else
	''   end                                                                            
	AS reqno,
	''                                                                               
	AS costcenter,
	''                                                                               
	AS fareid,
	''                                                                               
	AS farequoteid,
	''                                                                               
	AS dbinfo,
	''                                                                               
	AS dbinfocardtype ,
	TRIM(is_miscellaneous)                                                           
	AS is_miscellaneous,
	'',
	'',
	'',
	NULL,
	'' ,
	'',
	'N'                                                                              
	AS is_lcc_ancillary ,
	'N'                                                                              
	AS is_lcc ,protas_order_no,
    t_booking_document_dtl.fop_type,
    credit_card_no,
    CASE 
    WHEN approved_key ILIKE '%/%'
    THEN left(approved_key, strpos(approved_key, '/') - 1)
    ELSE
    approved_key
    END,'',
	'eTravel',
	round((markup_cons_curr+adhoc_markup_cons_curr)::NUMERIC,2),
	CASE 
		WHEN t_booking_transfer.is_miscellaneous='N'
		THEN case when dropoff_place not ilike '%BAHRAIN%' then 'VX' else
		case	WHEN (	SELECT	country_code FROM m_country WHERE UPPER(country_name) =(	SELECT
													UPPER(country) 
												FROM
													m_supplier 
												WHERE
													supplier_pid=t_booking_transfer.supplier_xid
						)
			)
			='BH' 
			THEN 'V5' else 'V0' end 
		END  
		ELSE 
		CASE 
			WHEN dropoff_place not ilike '%BAHRAIN%'
			THEN 'VX' else
case	WHEN (	SELECT	country_code FROM m_country WHERE UPPER(country_name) =(	SELECT
													UPPER(country) 
												FROM
													m_supplier 
												WHERE
													supplier_pid=t_booking_transfer.supplier_xid
						)
			)
			='BH' 
			THEN 'V5' else 'V0' end 
		END  
	END,
round((((client_curr_buying_amt-comm_received_sell_curr-input_tax) +(
	markup_sell_curr+adhoc_markup_sell_curr+other_charges)) / cons_sell_exc_rt)::NUMERIC,2) 	                                                             
,
round((((client_curr_buying_amt-comm_received_sell_curr-input_tax+service_tax_sell_curr) +(
	markup_sell_curr+adhoc_markup_sell_curr+other_charges)) / cons_sell_exc_rt)::NUMERIC,2) 	                                                             
,
	round((service_tax_sell_curr / cons_sell_exc_rt)::NUMERIC,2),
	CASE 
		WHEN t_booking_transfer.is_miscellaneous='N'
		THEN case when pickup_place ilike '%BAHRAIN%' then 'V5' else 'VX' end
		ELSE 
		CASE 
			WHEN  pickup_place  ilike '%BAHRAIN%'
			THEN 'V5' 
			ELSE 'VX' 
		END 
	END,
	0,
	round((comm_received_sell_curr / cons_sell_exc_rt)::NUMERIC,2)                                                             
	AS comm_amt,
CASE 
		WHEN t_booking_transfer.is_miscellaneous='N'
		THEN case when dropoff_place not ilike '%BAHRAIN%' then 'VX' else
		case	WHEN (	SELECT	country_code FROM m_country WHERE UPPER(country_name) =(	SELECT
													UPPER(country) 
												FROM
													m_supplier 
												WHERE
													supplier_pid=t_booking_transfer.supplier_xid
						)
			)
			='BH' 
			THEN 'V5' else 'V0' end 
		END  
		ELSE 
		CASE 
			WHEN dropoff_place not ilike '%BAHRAIN%'
			THEN 'VX' else
case	WHEN (	SELECT	country_code FROM m_country WHERE UPPER(country_name) =(	SELECT
													UPPER(country) 
												FROM
													m_supplier 
												WHERE
													supplier_pid=t_booking_transfer.supplier_xid
						)
			)
			='BH' 
			THEN 'V5' else 'V0' end 
		END  
	END                                                                          
	AS purchase_vatcode ,
	round(input_tax::NUMERIC,2),
	'',
	0,
	'',
	0,
	'Service',
	to_char(t_booking_transfer.fm_dt::DATE,'dd-Mon-yyyy'),
	(	SELECT
			TRIM(country_code) 
		FROM
			m_country 
		WHERE
			UPPER(country_name)= (	SELECT
										UPPER(country_name) 
									FROM
										m_transfer_contract 
									WHERE
										contract_pid =(	SELECT
															contract_xid 
														FROM
															m_transfer 
														WHERE
															transfer_pid=
															t_booking_transfer.
															tranfer_xid
										)
			)
	)
	,
	(	SELECT
			TRIM(country_code) 
		FROM
			m_country 
		WHERE
			UPPER(country_name) =(	SELECT
										UPPER(country) 
									FROM
										m_supplier 
									WHERE
										supplier_pid=t_booking_transfer.
										supplier_xid
			)
	)
	,
	(	SELECT
			TRIM(country_code) 
		FROM
			m_country 
		WHERE
			UPPER(country_name) =(	SELECT
										UPPER(country) 
									FROM
										m_client 
									WHERE
										client_pid=t_booking.client_xid
			)
	)
	,
	(	SELECT
			vat_registration_no 
		FROM
			m_client 
		WHERE
			client_pid=t_booking.client_xid
	)
	,
	'',
	vat_comment,'N',0,protas_hit_count

FROM
	t_booking 
		JOIN t_booking_transfer 
		ON (trans_pid=t_booking_transfer.trans_xid) 
			JOIN m_transfer 
			ON (t_booking_transfer.tranfer_xid = m_transfer.transfer_pid) 
				JOIN m_transfer_contract 
				ON (m_transfer.contract_xid = m_transfer_contract.contract_pid) 
					JOIN m_client 
					ON (client_pid=t_booking.client_xid) 
						JOIN m_login_user 
						ON (login_user_pid=t_booking.employee_xid) 
							JOIN m_supplier 
							ON (t_booking_transfer.supplier_xid = m_supplier. 
							supplier_pid) 
								JOIN t_booking_document 
								ON (t_booking.trans_pid=t_booking_document. 
								trans_xid) 
									JOIN t_booking_document_dtl 
									ON (t_booking_document_dtl.trans_doc_xid = 
									t_booking_document. trans_doc_pid AND
									trans_prod_xid = trans_tra_pid) 
WHERE
	document_no = ls_invoice_no 
and bkg_valid='Y' and is_invoice_blocked= 'N'
UNION
	ALL 
SELECT
	trans_doc_pid                                                                        
	AS doc_id,
	'I'                                                                                  
	AS product,
	trans_insurance_pid                                                                  
	AS product_id,
	NULL                                                                                 
	AS leg_pax_pid,
	TRIM(m_client.account_code)                                                          
	AS AccNo,
	(	SELECT
			TRIM(branch_code) 
		FROM
			m_branch 
		WHERE
			branch_pid=t_booking_insurance.branch_xid 
	)
	AS OffNo,
	(	SELECT
			employee_no 
		FROM
			m_login_user 
		WHERE
			login_user_pid=t_booking_insurance.salesman_xid 
	)
	AS SalNo,
	(	SELECT
			TRIM(branch_code) 
		FROM
			m_branch 
		WHERE
			branch_pid=(SELECT
							branch_xid 
						FROM
							m_client_branch_mapping 
						WHERE
							client_xid=t_booking.client_xid AND
							is_default='Y' 
			)
	)
	AS OwnOffNo,
	t_booking_insurance.travel_type                                                      
	AS CustType,
	NULL                                                                                 
	AS OrdEmpNo,
	CASE 
		WHEN (LENGTH(t_booking_insurance.lead_first)+LENGTH(t_booking_insurance. 
		lead_last)+LENGTH(t_booking_insurance.lead_title)) >38 
		THEN COALESCE(SUBSTRING (TRIM(t_booking_insurance.lead_last),1,17) ,'') 
		||' ' ||COALESCE(SUBSTRING (TRIM(t_booking_insurance.lead_first),1,16) , 
		'') ||' ' ||COALESCE(SUBSTRING (TRIM(t_booking_insurance.lead_title),1,7 
		) ,'') 
		ELSE COALESCE(TRIM(t_booking_insurance.lead_last),'') ||' ' || COALESCE 
		(TRIM(t_booking_insurance.lead_first),'') || ' ' ||COALESCE(TRIM( 
		t_booking_insurance.lead_title),'') 
	END                                                                                      
	AS TrvName,
	case when t_booking_document_dtl.fop_name = 'CC-CPG'
    THEN t_booking_document_dtl.ordercode
    else
	TRIM(t_booking_insurance.lpo_number)     end                                             
	AS ReqNo,
	'0'                                                                                  
	AS IT,
	(	SELECT
			TRIM(branch_code) 
		FROM
			m_branch 
		WHERE
			branch_pid=t_booking_insurance.booking_branch_xid 
	)
	AS BookingOffNo,
	(	SELECT
			TRIM(cost_center_code) 
		FROM
			m_cost_center 
		WHERE
			cost_center_pid=(	SELECT
									DISTINCT cost_center_xid 
								FROM
									t_booking_insurance_pax_details 
								WHERE
									trans_insurance_xid=t_booking_insurance. 
									trans_insurance_pid AND
									cost_center_xid IS NOT NULL 
			)
	)
	AS CostCenter,
	''                                                                                   
	AS ApprCd,
	(	SELECT
			TRIM(project_code) 
		FROM
			m_project 
		WHERE
			project_pid =(	SELECT
								DISTINCT project_xid 
							FROM
								t_booking_insurance_pax_details 
							WHERE
								trans_insurance_xid=t_booking_insurance. 
								trans_insurance_pid AND
								project_xid IS NOT NULL 
			)
	)
	AS project_no,
	t_booking_insurance.fm_dt                                                            
	AS TravelDate,
	'N'                                                                                  
	AS Exchangetrans,
	(SELECT


					fop_no 
				FROM
					m_fop_meta 
				WHERE
					m_fop_meta.fop=
(CASE
WHEN t_booking_insurance.mode_of_booking in ('CS','PG','CC') 
THEN
COALESCE(t_booking_document_dtl.fop_name,t_booking_insurance.mode_of_booking) 
ELSE
t_booking_insurance.mode_of_booking
END) )
AS FOPNo,
null AS FOPNo2,
	CASE 
		WHEN t_booking.fop_type='PT' 
		THEN TRIM(t_booking_insurance.mode_of_booking) 
		ELSE (	SELECT
					TRIM(mop) 
				FROM
					(	SELECT
							mop,
							trans_pax_mop_pid 
						FROM
							t_booking_pax_mop 
						WHERE
							t_booking_pax_mop.trans_prod_xid=t_booking_insurance 
							.trans_insurance_pid AND
							trans_doc_xid=t_booking_document.trans_doc_pid 
						ORDER BY
							trans_pax_mop_pid ASC LIMIT 1 
					)
					t 
		)
	END                                                                                      
	AS mop,
	(	SELECT
			TRIM(mop) 
		FROM
			(	SELECT
					mop,
					trans_pax_mop_pid 
				FROM
					t_booking_pax_mop 
				WHERE
					t_booking_pax_mop.trans_prod_xid=t_booking_insurance. 
					trans_insurance_pid AND
					trans_doc_xid=t_booking_document.trans_doc_pid 
				ORDER BY
					trans_pax_mop_pid ASC LIMIT 2 
			)
			t 
		ORDER BY
			trans_pax_mop_pid DESC LIMIT 1 
	)
	AS mop1,
	(	SELECT
			type_no 
		FROM
			m_document_master 
		WHERE
			doc_code=t_booking_insurance.doc_code 
	)
	AS TypeNo,
	(	SELECT
			TRIM(CAST(doc_no AS VARCHAR)) 
		FROM
			m_document_master 
		WHERE
			doc_code=t_booking_insurance.doc_code 
	)
	AS DocNo,
	NULL                                                                                 
	AS SerNo,
	''                                                                                   
	AS DestCd,
	round(((t_booking_insurance.comm_received_cons_curr/t_booking_insurance. 
	buying_amt_cons_curr)*100)::NUMERIC, 2)                                                                
	AS CommPct,
	COALESCE(t_booking_insurance.adult_qty,0)+COALESCE(t_booking_insurance. 
	child_qty,0) AS Grp,
	NULL                                                                                 
	AS conjNo,
	round((COALESCE(buying_amt_cons_curr,0)+COALESCE(markup_cons_curr,0) + 
	COALESCE(total_adhoc_markup_cons_curr,0) )::NUMERIC, 2)                                                                
	AS SalAmountLocal,
	round(COALESCE (t_booking_insurance.comm_received_cons_curr,0)::NUMERIC, 2)          
	AS CommAmt,
	round(supp_tax_cons_curr::NUMERIC, 2)AS TaxAmount,
	round((COALESCE(t_booking_insurance.discount_applied_cons_curr,0) + COALESCE
	(t_booking_insurance.total_adhoc_discount_cons_curr,0) + COALESCE(
	t_booking_insurance.comm_passon_cons_curr,0))::NUMERIC,2)AS Rbamount,
	NULL                                                                                 
	AS Rbamount2,
	round((COALESCE(buying_amt_cons_curr,0)+COALESCE(markup_cons_curr,0) + 
	COALESCE(total_adhoc_markup_cons_curr,0) ):: NUMERIC, 2)                                                               
	AS EqAmount,
	''                                                                                   
	AS ValueCd,
	TRIM(t_booking_insurance.buying_currency)                                            
	AS PurrCurrCd,
	round(100/ COALESCE(t_booking_insurance.sup_adm_exchange_rate,1)::NUMERIC,5)         
	AS PurRate,
	round((t_booking_insurance.buying_amt-t_booking_insurance. 
	comm_received_buy_curr)::NUMERIC,2)AS PurAmount,
	TRIM(m_supplier.account_code)                                                        
	AS AccNo,
	TRIM(t_booking.booking_no)                                                           
	AS VendInvoNo,
	NULL                                                                                 
	AS FopAmt2,
	''                                                                                   
	AS PNRno,
	''                                                                                   
	AS tourcd,
	t_booking_insurance.fm_dt                                                            
	AS VendorInvoiceDate,
	(	SELECT
			crs_id 
		FROM
			m_supplier 
		WHERE
			m_supplier.supplier_pid=t_booking_insurance.supplier_xid 
	)
	AS crs_pnr_no,
	0                                                                                    
	AS savamount,
	TRIM(t_booking_insurance.supplier_ref_no)                                            
	AS dsr_remarks,
	TRIM(t_booking_insurance.type_of_insurance)                                          
	AS servicename,
	NULL                                                                                 
	AS servicecategory,
	t_booking_insurance.fm_dt                                                            
	AS checkindate,
	t_booking_insurance.to_dt                                                            
	AS checkoutdate,
	''                                                                                   
	AS servicecity,
	COALESCE(TRIM(t_booking.checkout_remarks),'')                                        
	AS remarks,
	(	SELECT
			TRIM(cost_center_code) 
		FROM
			m_cost_center 
		WHERE
			cost_center_pid=(	SELECT
									DISTINCT cost_center_xid 
								FROM
									t_booking_insurance_pax_details 
								WHERE
									trans_insurance_xid=t_booking_insurance. 
									trans_insurance_pid AND
									cost_center_xid IS NOT NULL 
			)
	)
	AS costcenterno,
	''                                                                                   
	AS visacountry,
	NULL                                                                                 
	AS rbdeposit,
	NULL                                                                                 
	AS rbdeposit2,
	COALESCE(trans_fee_cons_curr,0)                                                      
	AS Transfee,
	NULL                                                                                 
	AS transfeed,
	NULL                                                                                 
	AS transfee2,
	NULL                                                                                 
	AS transfeed2,
	''                                                                                   
	AS ca,
	''                                                                                   
	AS airlcd,
	''                                                                                   
	AS frmdestcd,
	''                                                                                   
	AS todestcd,
	CASE 
		WHEN (LENGTH(t_booking_insurance.lead_first)+LENGTH(t_booking_insurance. 
		lead_last)+LENGTH(t_booking_insurance.lead_title)) >38 
		THEN COALESCE(SUBSTRING (TRIM(t_booking_insurance.lead_last),1,17) ,'') 
		||' ' ||COALESCE(SUBSTRING (TRIM(t_booking_insurance.lead_first),1,16) , 
		'') ||' ' ||COALESCE(SUBSTRING (TRIM(t_booking_insurance.lead_title),1,7 
		) ,'') 
		ELSE COALESCE(TRIM(t_booking_insurance.lead_last),'') ||' ' || COALESCE 
		(TRIM(t_booking_insurance.lead_first),'') || ' ' ||COALESCE(TRIM( 
		t_booking_insurance.lead_title),'') 
	END                                                                                      
	AS TrvName,
	''                                                                                   
	AS isi,
	''                                                                                   
	AS taxprint1,
	''                                                                                   
	AS taxprint2,
	''                                                                                   
	AS taxprint3,
	''                                                                                   
	AS excarrcd,
	''                                                                                   
	AS exdocno,
	''                                                                                   
	AS exserno,
	''                                                                                   
	AS exconj,
	TRIM(t_booking_insurance.supplier_ref_no)                                            
	AS bookingno,
	''                                                                                   
	AS fc ,
	''                                                                                   
	AS tax ,
	''                                                                                   
	AS sector,
	''                                                                                   
	AS stcd,
	''                                                                                   
	AS fbno,
	''                                                                                   
	AS carrcd,
	''                                                                                   
	AS flightno,
	''                                                                                   
	AS classcd,
	NULL                                                                                 
	AS depdate,
	''                                                                                   
	AS deptime,
	NULL                                                                                 
	AS arrdate,
	''                                                                                   
	AS arrtime,
	''                                                                                   
	AS allow,
	''                                                                                   
	AS nvb,
	''                                                                                   
	AS nva,
	''                                                                                   
	AS operbycarrcode,
	''                                                                                   
	AS opercarrcd,
	''                                                                                   
	AS operflight,
	''                                                                                   
	AS meal,
	''                                                                                   
	AS nostop,
	''                                                                                   
	AS journeytime,
	''                                                                                   
	AS equipmenttype,
	''                                                                                   
	AS serno,
	''                                                                                   
	AS TrvName,
	''                                                                                   
	AS admcd,
	''                                                                                   
	AS empno,
	''                                                                                   
	AS projno,
	 case when t_booking_document_dtl.fop_name = 'CC-CPG'
    THEN t_booking_document_dtl.ordercode
    else
	''     end                                                                              
	AS reqno,
	''                                                                                   
	AS costcenter,
	''                                                                                   
	AS fareid,
	''                                                                                   
	AS farequoteid,
	''                                                                                   
	AS dbinfo,
	''                                                                                   
	AS dbinfocardtype ,
	TRIM(is_miscellaneous)                                                               
	AS is_miscellaneous,
	'',
	'',
	'',
	NULL,
	'' ,
	'',
	'N'                                                                                  
	AS is_lcc_ancillary ,
	'N'                                                                                  
	AS is_lcc ,protas_order_no,
        t_booking_document_dtl.fop_type,
        credit_card_no,
    CASE 
    WHEN approved_key ILIKE '%/%'
    THEN left(approved_key, strpos(approved_key, '/') - 1)
    ELSE
    approved_key
    END,'',
	'eTravel',
	0,
	'',
	0,
	0,
	0,
	'',
	0,
	0,
	'' ,
	0,
	'',
	0,
	'',
	0,
	'Service',
	to_char(t_booking_insurance.fm_dt::DATE,'dd-Mon-yyyy'),
	'',
	(	SELECT
			TRIM(country_code) 
		FROM
			m_country 
		WHERE
			UPPER(country_name) =(	SELECT
										UPPER(country) 
									FROM
										m_supplier 
									WHERE
										supplier_pid=t_booking_insurance.
										supplier_xid
			)
	)
	,
	(	SELECT
			TRIM(country_code) 
		FROM
			m_country 
		WHERE
			UPPER(country_name) =(	SELECT
										UPPER(country) 
									FROM
										m_client 
									WHERE
										client_pid=t_booking.client_xid
			)
	)
	,
	(	SELECT
			vat_registration_no 
		FROM
			m_client 
		WHERE
			client_pid=t_booking.client_xid
	)
	,
	'',
	vat_comment ,'N',0,protas_hit_count
FROM
	t_booking 
		JOIN t_booking_insurance 
		ON (trans_pid=t_booking_insurance.trans_xid) 
			JOIN m_client 
			ON (client_pid=t_booking.client_xid) 
				JOIN m_login_user 
				ON (login_user_pid=t_booking.employee_xid) 
					JOIN m_supplier 
					ON (t_booking_insurance.supplier_xid = m_supplier. 
					supplier_pid) 
						JOIN t_booking_document 
						ON (t_booking.trans_pid=t_booking_document.trans_xid) 
							JOIN t_booking_document_dtl 
							ON (t_booking_document_dtl.trans_doc_xid = 
							t_booking_document. trans_doc_pid AND
							trans_prod_xid = trans_insurance_pid) 
WHERE
	document_no = ls_invoice_no 
and bkg_valid='Y' and is_invoice_blocked= 'N'
UNION
	ALL 
SELECT
	trans_doc_pid                                                                                                 
	AS doc_id,
	'M'                                                                                                           
	AS product,
	trans_misc_pid                                                                                                
	AS product_id,
	NULL                                                                                                          
	AS leg_pax_pid,
	TRIM(m_client.account_code)                                                                                   
	AS AccNo,
	(	SELECT
			TRIM(branch_code) 
		FROM
			m_branch 
		WHERE
			branch_pid=t_booking_misc.branch_xid 
	)
	AS OffNo,
	(	SELECT
			employee_no 
		FROM
			m_login_user 
		WHERE
			login_user_pid=t_booking_misc.salesman_xid 
	)
	AS SalNo,
	(	SELECT
			TRIM(branch_code) 
		FROM
			m_branch 
		WHERE
			branch_pid=(SELECT
							branch_xid 
						FROM
							m_client_branch_mapping 
						WHERE
							client_xid=t_booking.client_xid AND
							is_default='Y' 
			)
	)
	AS OwnOffNo,
	t_booking_misc.travel_type                                                                                    
	AS CustType,
	NULL                                                                                                          
	AS OrdEmpNo,
	CASE 
		WHEN (LENGTH(t_booking_misc.lead_fname)+LENGTH(t_booking_misc.lead_lname 
		)) >38 
		THEN COALESCE(SUBSTRING (TRIM(t_booking_misc.lead_lname),1,17) ,'')||' ' 
		||COALESCE(SUBSTRING (TRIM(t_booking_misc.lead_fname),1,16) ,'') 
		ELSE COALESCE(TRIM(t_booking_misc.lead_lname),'') ||' ' || COALESCE ( 
		TRIM(t_booking_misc.lead_fname),'') 
	END                                                                                                               
	AS TrvName,
	case when t_booking_document_dtl.fop_name = 'CC-CPG'
    THEN t_booking_document_dtl.ordercode
    else
	TRIM(t_booking_misc.lpo_number)    end                                                                           
	AS ReqNo,
	'0'                                                                                                           
	AS IT,
	(	SELECT
			TRIM(branch_code) 
		FROM
			m_branch 
		WHERE
			branch_pid=t_booking_misc.booking_branch_xid 
	)
	AS BookingOffNo,
	''                                                                                                            
	AS CostCenter,
	''                                                                                                            
	AS ApprCd,
	''AS project_no,

case when (service_param_values::json->0)->>'labelName'='Insurance' then
	replace (
((((((service_param_values::json->0)->'groupFields')->5)->'dateConfigs')->0)->>'selectedDateInNetworkDateFormat'),',','')::timestamp
when (service_param_values::json->0)->>'labelName'='Other Misc' then
replace (
((((((service_param_values::json->0)->'groupFields')->1)->'dateConfigs')->0)->>'selectedDateInNetworkDateFormat'),',','')::timestamp
when (service_param_values::json->0)->>'labelName'='Transfer Service' then
replace (
((((((service_param_values::json->0)->'groupFields')->3)->'dateConfigs')->0)->>'selectedDateInNetworkDateFormat'),',','')::timestamp
when (service_param_values::json->0)->>'labelName'='Re-issue / Refund charges' 
then replace (((((service_param_values::json->0)->'groupFields'->2)->'dateConfigs'->0)->>'selectedDateInNetworkDateFormat'),',','')::timestamp 
when (service_param_values::json->0)->>'labelName'='Visa' then
document_dt
end
	AS TravelDate,
	'N'                                                                                                           
	AS Exchangetrans,
(SELECT


					fop_no 
				FROM
					m_fop_meta 
				WHERE
					m_fop_meta.fop=
(CASE
WHEN t_booking.mode_of_booking in  ('CS','PG','CC')  
THEN
COALESCE(t_booking_document_dtl.fop_name,t_booking.mode_of_booking) 
ELSE
t_booking.mode_of_booking
END) )
AS FOPNo,
null AS FOPNo2,
	CASE 
		WHEN t_booking.fop_type='PT' 
		THEN TRIM(t_booking.mode_of_booking) 
		ELSE (	SELECT
					TRIM(mop) 
				FROM
					(	SELECT
							mop,
							trans_pax_mop_pid 
						FROM
							t_booking_pax_mop 
						WHERE
							t_booking_pax_mop.trans_prod_xid=t_booking_misc. 
							trans_misc_pid AND
							trans_doc_xid=t_booking_document.trans_doc_pid 
						ORDER BY
							trans_pax_mop_pid ASC LIMIT 1 
					)
					t 
		)
	END                                                                                                               
	AS mop,
	(	SELECT
			TRIM(mop) 
		FROM
			(	SELECT
					mop,
					trans_pax_mop_pid 
				FROM
					t_booking_pax_mop 
				WHERE
					t_booking_pax_mop.trans_prod_xid=t_booking_misc. 
					trans_misc_pid AND
					trans_doc_xid=t_booking_document.trans_doc_pid 
				ORDER BY
					trans_pax_mop_pid ASC LIMIT 2 
			)
			t 
		ORDER BY
			trans_pax_mop_pid DESC LIMIT 1 
	)
	AS mop1,
	(	SELECT
			type_no 
		FROM
			m_miscellaneous_services 
		WHERE
			m_miscellaneous_services.service_pid=t_booking_misc.service_xid 
	)
	AS TypeNo,
	(	SELECT
			TRIM(CAST(doc_no AS VARCHAR)) 
		FROM
			m_miscellaneous_services 
		WHERE
			m_miscellaneous_services.service_pid=t_booking_misc.service_xid 
	)
	AS DocNo,
	NULL                                                                                                          
	AS SerNo,
	NULL                                                                                                          
	AS DestCd,
	round((((COALESCE(t_booking_misc.comm_amt,0)/buying_amt_in_sell_curr))*100) 
	::NUMERIC, 2)                                                                                        
	AS CommPct,
	COALESCE(t_booking_misc.no_adult,0)+COALESCE(t_booking_misc.no_child,0)+ 
	COALESCE(t_booking_misc.no_infant,0) AS Grp,
	NULL                                                                                                          
	AS conjNo,
	round(((COALESCE(buying_amt_in_sell_curr,0)+COALESCE(markup,0))*(COALESCE( 
	t_booking_misc.selling_cons_exc_rt,1)))::NUMERIC, 2)                                                                                         
	AS SalAmountLocal,
	round(COALESCE (t_booking_misc.comm_amt,0)::NUMERIC, 2)                                                       
	AS CommAmt,
	NULL                                                                                                          
	AS TaxAmount,
	round(((COALESCE(t_booking_misc.passon_amt_sell_curr,0))*(COALESCE( 
	t_booking_misc.selling_cons_exc_rt,1)))::NUMERIC,2)AS Rbamount,
	NULL                                                                                                          
	AS Rbamount2,
	round(((COALESCE(buying_amt_in_sell_curr,0)+COALESCE(markup,0))*(COALESCE( 
	t_booking_misc.selling_cons_exc_rt,1)))::NUMERIC, 2)                                                                                         
	AS EqAmount,
	''                                                                                                            
	AS ValueCd,
	TRIM(t_booking_misc_dtl.buying_currency)                                                                      
	AS PurrCurrCd,
	round(100/ COALESCE(t_booking_misc.buying_cons_exc_rt,1)::NUMERIC,5)                                          
	AS PurRate,
	round((t_booking_misc_dtl.buying_amt-t_booking_misc.comm_amt)::NUMERIC,2)                                                                                          
	AS PurAmount,
	TRIM(m_supplier.account_code)                                                                                 
	AS AccNo,
	TRIM(t_booking.booking_no)                                                                                    
	AS VendInvoNo,
	NULL                                                                                                          
	AS FopAmt2,
	''                                                                                                            
	AS PNRno,
	''                                                                                                            
	AS tourcd,
	t_booking_misc.invoice_date                                                                                          
	AS VendorInvoiceDate,
	(	SELECT
			crs_id 
		FROM
			m_supplier 
		WHERE
			m_supplier.supplier_pid=t_booking_misc_dtl.supplier_xid 
	)
	AS crs_pnr_no,
	0                                                                                                             
	AS savamount,
	TRIM(t_booking_misc.sup_ref_no)||'' ||TRIM(t_booking_misc.sp_remarks)                                         
	AS dsr_remarks,
	TRIM(t_booking_misc.misc_name)                                                                                
	AS servicename,
	NULL                                                                                                          
	AS servicecategory,
	t_booking_misc.fm_dt                                                                                          
	AS checkindate,
	t_booking_misc.to_dt                                                                                          
	AS checkoutdate,
	TRIM(t_booking_misc.service_city)                                                                             
	AS servicecity,
	COALESCE(TRIM(t_booking_misc.sp_remarks),'')                                                                  
	AS remarks,
	''                                                                                                            
	AS costcenterno,
	''                                                                                                            
	AS visacountry,
	NULL                                                                                                          
	AS rbdeposit,
	NULL                                                                                                          
	AS rbdeposit2,
	(COALESCE(trans_fee_sell_curr,0)*COALESCE(t_booking_misc.selling_cons_exc_rt 
	,1))                             AS Transfee,
	NULL                                                                                                          
	AS transfeed,
	NULL                                                                                                          
	AS transfee2,
	NULL                                                                                                          
	AS transfeed2,
	''                                                                                                            
	AS ca,
	''                                                                                                            
	AS airlcd,
	''                                                                                                            
	AS frmdestcd,
	''                                                                                                            
	AS todestcd,
	CASE 
		WHEN (LENGTH(t_booking_misc.lead_fname)+LENGTH(t_booking_misc.lead_lname 
		)) >38 
		THEN COALESCE(SUBSTRING (TRIM(t_booking_misc.lead_lname),1,17) ,'')||' ' 
		||COALESCE(SUBSTRING (TRIM(t_booking_misc.lead_fname),1,16) ,'') 
		ELSE COALESCE(TRIM(t_booking_misc.lead_lname),'') ||' ' || COALESCE ( 
		TRIM(t_booking_misc.lead_fname),'') 
	END                                                                                                               
	AS TrvName,
	''                                                                                                            
	AS isi,
	''                                                                                                            
	AS taxprint1,
	''                                                                                                            
	AS taxprint2,
	''                                                                                                            
	AS taxprint3,
	''                                                                                                            
	AS excarrcd,
	''                                                                                                            
	AS exdocno,
	''                                                                                                            
	AS exserno,
	''                                                                                                            
	AS exconj,
	TRIM(t_booking_misc.sup_ref_no)                                                                               
	AS bookingno,
	''                                                                                                            
	AS fc ,
	''                                                                                                            
	AS tax ,
	''                                                                                                            
	AS sector,
	''                                                                                                            
	AS stcd,
	''                                                                                                            
	AS fbno,
	''                                                                                                            
	AS carrcd,
	''                                                                                                            
	AS flightno,
	''                                                                                                            
	AS classcd,
	NULL                                                                                                          
	AS depdate,
	''                                                                                                            
	AS deptime,
	NULL                                                                                                          
	AS arrdate,
	''                                                                                                            
	AS arrtime,
	''                                                                                                            
	AS allow,
	''                                                                                                            
	AS nvb,
	''                                                                                                            
	AS nva,
	''                                                                                                            
	AS operbycarrcode,
	''                                                                                                            
	AS opercarrcd,
	''                                                                                                            
	AS operflight,
	''                                                                                                            
	AS meal,
	''                                                                                                            
	AS nostop,
	''                                                                                                            
	AS journeytime,
	''                                                                                                            
	AS equipmenttype,
	''                                                                                                            
	AS serno,
	''                                                                                                            
	AS TrvName,
	''                                                                                                            
	AS admcd,
	''                                                                                                            
	AS empno,
	''                                                                                                            
	AS projno,
    case when t_booking_document_dtl.fop_name = 'CC-CPG'
    THEN t_booking_document_dtl.ordercode
    else
	''     end                                                                                                       
	AS reqno,
	''                                                                                                            
	AS costcenter,
	''                                                                                                            
	AS fareid,
	''                                                                                                            
	AS farequoteid,
	''                                                                                                            
	AS dbinfo,
	''                                                                                                            
	AS dbinfocardtype ,
	'Y'                                                                                                           
	AS is_miscellaneous,
	'',
	'',
	'',
	NULL,
	'' ,
	'',
	'N'                                                                                                           
	AS is_lcc_ancillary ,
	'N'                                                                                                           
	AS is_lcc ,protas_order_no,
    t_booking_document_dtl.fop_type,
    credit_card_no,
    CASE 
    WHEN approved_key ILIKE '%/%'
    THEN left(approved_key, strpos(approved_key, '/') - 1)
    ELSE
    approved_key
    END,'',
	'eTravel',
	0,
	'',
	0,
	0,
	0,
	'',
	0,
	0,
	'' ,
	0,
	'',
	0,
	'',
	0,
	'Service',
	to_char(case when (service_param_values::json->0)->>'labelName'='Insurance' then
	replace (
((((((service_param_values::json->0)->'groupFields')->5)->'dateConfigs')->0)->>'selectedDateInNetworkDateFormat'),',','')::timestamp
when (service_param_values::json->0)->>'labelName'='Other Misc' then
replace (
((((((service_param_values::json->0)->'groupFields')->1)->'dateConfigs')->0)->>'selectedDateInNetworkDateFormat'),',','')::timestamp
when (service_param_values::json->0)->>'labelName'='Re-issue / Refund charges' 
then replace (((((service_param_values::json->0)->'groupFields'->2)->'dateConfigs'->0)->>'selectedDateInNetworkDateFormat'),',','')::timestamp
when (service_param_values::json->0)->>'labelName'='Transfer Service' then
replace (
((((((service_param_values::json->0)->'groupFields')->3)->'dateConfigs')->0)->>'selectedDateInNetworkDateFormat'),',','')::timestamp
when (service_param_values::json->0)->>'labelName'='Visa' then
'01/01/1900'
end::DATE,'dd-Mon-yyyy'),
	'',
	(	SELECT
			TRIM(country_code) 
		FROM
			m_country 
		WHERE
			UPPER(country_name) =(	SELECT
										UPPER(country) 
									FROM
										m_supplier 
									WHERE
										supplier_pid=t_booking_misc.supplier_xid
			)
	)
	,
	(	SELECT
			TRIM(country_code) 
		FROM
			m_country 
		WHERE
			UPPER(country_name) =(	SELECT
										UPPER(country) 
									FROM
										m_client 
									WHERE
										client_pid=t_booking.client_xid
			)
	)
	,
	(	SELECT
			vat_registration_no 
		FROM
			m_client 
		WHERE
			client_pid=t_booking.client_xid
	)
	,
	'',
	vat_comment ,'N',0,protas_hit_count
FROM
	t_booking 
		JOIN t_booking_misc 
		ON (trans_pid=t_booking_misc.trans_xid) 
			JOIN t_booking_misc_dtl 
			ON (t_booking_misc_dtl.trans_misc_xid=trans_misc_pid) 
				JOIN m_client 
				ON (client_pid=t_booking.client_xid) 
					JOIN m_login_user 
					ON (login_user_pid=t_booking.employee_xid) 
						JOIN m_supplier 
						ON (t_booking_misc.supplier_xid = m_supplier. 
						supplier_pid) 
							JOIN t_booking_document 
							ON (t_booking.trans_pid=t_booking_document.trans_xid 
							) 	
								JOIN t_booking_document_dtl 
								ON (t_booking_document_dtl.trans_doc_xid = 
								t_booking_document. trans_doc_pid AND
								trans_prod_xid = trans_misc_pid) 
WHERE
	document_no = ls_invoice_no 
and bkg_valid='Y' and is_invoice_blocked= 'N'
UNION
	ALL 
SELECT
	trans_doc_pid                                                                   
	AS doc_id,
	'A'                                                                             
	AS product,
	trans_air_pid                                                                   
	AS product_id,
	t_booking_air_sector_pax_dtl.leg_pax_pid                                        
	AS leg_pax_pid,
	TRIM(m_client.account_code)                                                     
	AS AccNo,
	coalesce((SELECT
			TRIM(branch_code) 
		FROM
			m_branch 
		WHERE
			branch_pid=(SELECT branch_xid FROM m_regional_pcc_branch_mapping WHERE supplier_xid=(SELECT supplier_xid FROM m_hap_master WHERE hap_pid=t_booking_air.ticket_hapid) and (SELECT is_regional_pcc_ticketing FROM m_supplier WHERE supplier_pid=(SELECT supplier_xid FROM m_hap_master WHERE hap_pid=t_booking_air.ticket_hapid))='Y' and client_xid=t_booking.client_xid)),(	SELECT
			TRIM(branch_code) 
		FROM
			m_branch 
		WHERE
			branch_pid=(SELECT
							branch_xid 
						FROM
							m_client_branch_mapping 
						WHERE
							client_xid=t_booking.client_xid AND
							is_default='Y' 
			)
	))

	AS OffNo,
	(	SELECT
			employee_no 
		FROM
			m_login_user 
		WHERE
			login_user_pid=t_booking_air.salesman_xid 
	)
	AS SalNo,
	(	SELECT
			TRIM(branch_code) 
		FROM
			m_branch 
		WHERE
			branch_pid=(SELECT
							branch_xid 
						FROM
							m_client_branch_mapping 
						WHERE
							client_xid=t_booking.client_xid AND
							is_default='Y' 
			)
	)
	AS OwnOffNo,
	t_booking_air.travel_type                                                       
	AS CustType,
	(	SELECT
			COALESCE(TRIM(reference_number),'') 
		FROM
			m_traveller 
		WHERE
			traveller_pid =t_booking_air_pax.traveller_xid 
	)
	AS OrdEmpNo,
	CASE 
		WHEN (LENGTH(t_booking_air_pax.first_name)+LENGTH(t_booking_air_pax. 
		last_name)+LENGTH(t_booking_air_pax.title)) >38 
		THEN COALESCE(SUBSTRING (TRIM(t_booking_air_pax.last_name),1,17) ,'')|| 
		' ' ||COALESCE(SUBSTRING (TRIM(t_booking_air_pax.first_name),1,16) ,'') 
		||' ' ||COALESCE(SUBSTRING (TRIM(t_booking_air_pax.title),1,7) ,'') 
		ELSE COALESCE(TRIM(t_booking_air_pax.last_name),'') ||' ' || COALESCE ( 
		TRIM(t_booking_air_pax.first_name),'') || ' ' ||COALESCE(TRIM( 
		t_booking_air_pax.title),'') 
	END                                                                                 
	AS TrvName,
	case when t_booking_document_dtl.fop_name = 'CC-CPG'
    THEN t_booking_document_dtl.ordercode
    else
	TRIM(t_booking_air.lpo_number)  end                                                
	AS ReqNo,
	'0'                                                                             
	AS IT,
	(	SELECT
			TRIM(branch_code) 
		FROM
			m_branch 
		WHERE
			branch_pid=t_booking_air.booking_branch_xid 
	)
	AS BookingOffNo,
	(	SELECT
			TRIM(cost_center_code) 
		FROM
			m_cost_center 
		WHERE
			cost_center_pid=t_booking_air_pax.cost_center_xid 
	)
	AS CostCenter,
	''                                                                              
	AS ApprCd,
	(	SELECT
			TRIM(project_code) 
		FROM
			m_project 
		WHERE
			project_pid =t_booking_air_pax.project_xid 
	)
	AS project_no,
	t_booking_air.travel_dt                                                         
	AS TravelDate,
	'N'                                                                             
	AS Exchangetrans,
	(SELECT


					fop_no 
				FROM
					m_fop_meta 
				WHERE
					m_fop_meta.fop=
(CASE
WHEN t_booking_air.mode_of_booking in  ('CS','PG','CC') 
THEN
COALESCE(t_booking_document_dtl.fop_name,t_booking_air.mode_of_booking) 
ELSE
t_booking_air.mode_of_booking
END) )
AS FOPNo,
null AS FOPNo2,
	CASE 
		WHEN t_booking.fop_type='PT' 
		THEN TRIM(t_booking_air.mode_of_booking) 
		ELSE (	SELECT
					TRIM(mop) 
				FROM
					(	SELECT
							mop,
							trans_pax_mop_pid 
						FROM
							t_booking_pax_mop 
						WHERE
							t_booking_pax_mop.trans_prod_xid=t_booking_air. 
							trans_air_pid AND
							trans_doc_xid=t_booking_document.trans_doc_pid 
						ORDER BY
							trans_pax_mop_pid ASC LIMIT 1 
					)
					t 
		)
	END                                                                                 
	AS mop,
	(	SELECT
			TRIM(mop) 
		FROM
			(	SELECT
					mop,
					trans_pax_mop_pid 
				FROM
					t_booking_pax_mop 
				WHERE
					t_booking_pax_mop.trans_prod_xid=t_booking_air.trans_air_pid 
					AND
					trans_doc_xid=t_booking_document.trans_doc_pid 
				ORDER BY
					trans_pax_mop_pid ASC LIMIT 2 
			)
			t 
		ORDER BY
			trans_pax_mop_pid DESC LIMIT 1 
	)
	AS mop1,
	(	SELECT
			type_no 
		FROM
			m_document_master 
		WHERE
			doc_code=t_booking_air.doc_code 
	)
	AS TypeNo,
	(	SELECT
			TRIM(CAST(doc_no AS VARCHAR)) 
		FROM
			m_document_master 
		WHERE
			doc_code=t_booking_air.doc_code 
	)
	AS DocNo,
	''                                                                              
	AS SerNo,
	TRIM(t_booking_air.tocity_xid)                                                  
	AS DestCd,
	CASE 
		WHEN t_booking_air_fare.base_fare=0 
		THEN 0 
		ELSE (	SELECT
					round(((SUM(COALESCE(t_booking_air_fare.iata_comm_amt_retain 
					,0)) / SUM(t_booking_air_fare.base_fare-t_booking_air_fare. 
					overriding_comm_amt_retain)) * 100)::NUMERIC, 0) 
				FROM
					t_booking_air_fare 
				WHERE
					trans_xid =t_booking.trans_pid AND
					trans_air_xid =t_booking_air.trans_air_pid 
		)
	END                                                                                 
	AS CommPct,
	1 Grp,
	NULL                                                                            
	AS conjNo,
	(	SELECT
			round(SUM( ((COALESCE(t_booking_air_fare.base_fare_supp_curr,0))* 
			COALESCE(t_booking_air_fare. suppliertoadminexcgrate,0)) +COALESCE(
			t_booking_air_fare.markup_cons_curr,0) + (t_booking_air_fare.
			adhoc_markup_cons_curr))::NUMERIC, 2) 
		FROM
			t_booking_air_fare 
		WHERE
			trans_xid =t_booking.trans_pid AND
			trans_air_xid =t_booking_air.trans_air_pid 
	)
	AS SalAmountLocal,
	(	SELECT
			round(SUM(( (t_booking_air_fare.iata_comm_amt_retain * COALESCE(
			t_booking_air.selling_cons_exc_rt,0)) +COALESCE(t_booking_air_fare.
			markup_cons_curr,0) + (t_booking_air_fare.adhoc_markup_cons_curr) ))
			:: NUMERIC, 0) 
		FROM
			t_booking_air_fare 
		WHERE
			trans_xid =t_booking.trans_pid AND
			trans_air_xid =t_booking_air.trans_air_pid 
	)
	AS CommAmt,
	(	SELECT
			round(SUM(t_booking_air_fare.total_tax)::NUMERIC, 2) 
		FROM
			t_booking_air_fare 
		WHERE
			trans_xid =t_booking.trans_pid AND
			trans_air_xid =t_booking_air.trans_air_pid 
	)
	AS TaxAmount,
	(	SELECT
			round(SUM (((((COALESCE(t_booking_air_fare.iata_comm_amt,0)) +( 
			COALESCE(t_booking_air_fare.plb_amount,0)) +(COALESCE( 
			t_booking_air_fare.overriding_comm_amt,0)) ) * COALESCE( 
			t_booking_air.selling_cons_exc_rt,0)) + ( COALESCE( 
			t_booking_air_fare.adhoc_rebate_cons_curr,0) + COALESCE( 
			t_booking_air_fare.pure_discount_cons_curr,0)))) ::NUMERIC,2) 
		FROM
			t_booking_air_fare 
		WHERE
			trans_xid =t_booking.trans_pid AND
			trans_air_xid =t_booking_air.trans_air_pid 
	)
	AS Rbamount,
	NULL                                                                            
	AS Rbamount2,
	(	SELECT
			round(SUM ((COALESCE(t_booking_air_fare.base_fare_supp_curr,0)* 
			COALESCE(t_booking_air_fare. suppliertoadminexcgrate,0)) -((COALESCE
			(t_booking_air_fare.plb_amount_retain,0) * COALESCE(t_booking_air.
			selling_cons_exc_rt,0)) +(COALESCE(t_booking_air_fare.
			overriding_comm_amt_retain_supp_currr,0) * COALESCE(
			t_booking_air_fare.suppliertoadminexcgrate))))::NUMERIC,2) 
		FROM
			t_booking_air_fare 
		WHERE
			trans_xid =t_booking.trans_pid AND
			trans_air_xid =t_booking_air.trans_air_pid 
	)
	AS EqAmount,
	CASE 
		WHEN (value_code IS NULL) 
		THEN 
		CASE 
			WHEN (t_booking_air_fare.iata_comm_amt_retain IS NOT NULL AND
			t_booking_air_fare.iata_comm_amt_retain <> 0) 
			THEN 
			CASE 
				WHEN (	SELECT
							LENGTH(CAST(trunc(round(SUM ((((COALESCE( 
							t_booking_air_fare.base_fare,0)) -((COALESCE( 
							t_booking_air_fare.plb_amount_retain,0)) +(COALESCE( 
							t_booking_air_fare.overriding_comm_amt_retain,0)))) 
							* COALESCE(t_booking_air.selling_cons_exc_rt,0))):: 
							NUMERIC,0))AS VARCHAR)) 
						FROM
							t_booking_air_fare 
						WHERE
							trans_xid =t_booking.trans_pid AND
							trans_air_xid =t_booking_air.trans_air_pid 
				)
				=1 
				THEN 'M'||'0000'|| (SELECT
										CAST(round(SUM((COALESCE(
										t_booking_air_fare.base_fare_supp_curr,0
										) * COALESCE(t_booking_air_fare.
										suppliertoadminexcgrate) ) - ((COALESCE(
										t_booking_air_fare.plb_amount_retain,0) 
										* COALESCE(t_booking_air.
										selling_cons_exc_rt,0)) + (COALESCE(
										t_booking_air_fare.
										overriding_comm_amt_retain_supp_currr,0) 
										* COALESCE(t_booking_air_fare.
										suppliertoadminexcgrate)) ) )::NUMERIC,0
										)AS VARCHAR) 
									FROM
										t_booking_air_fare 
									WHERE
										trans_xid =t_booking.trans_pid AND
										trans_air_xid =t_booking_air. 
										trans_air_pid 
				)
				WHEN (	SELECT
							LENGTH(CAST(trunc(round(SUM ((((COALESCE( 
							t_booking_air_fare.base_fare,0)) -((COALESCE( 
							t_booking_air_fare.plb_amount_retain,0)) +(COALESCE( 
							t_booking_air_fare.overriding_comm_amt_retain,0)))) 
							* COALESCE(t_booking_air.selling_cons_exc_rt,0))):: 
							NUMERIC,0))AS VARCHAR)) 
						FROM
							t_booking_air_fare 
						WHERE
							trans_xid =t_booking.trans_pid AND
							trans_air_xid =t_booking_air.trans_air_pid 
				)
				=2 
				THEN 'M'||'000'|| (	SELECT
										CAST(round(SUM((COALESCE(
										t_booking_air_fare.base_fare_supp_curr,0
										) * COALESCE(t_booking_air_fare.
										suppliertoadminexcgrate) ) - ((COALESCE(
										t_booking_air_fare.plb_amount_retain,0) 
										* COALESCE(t_booking_air.
										selling_cons_exc_rt,0)) + (COALESCE(
										t_booking_air_fare.
										overriding_comm_amt_retain_supp_currr,0) 
										* COALESCE(t_booking_air_fare.
										suppliertoadminexcgrate)) ) )::NUMERIC,0
										)AS VARCHAR) 
									FROM
										t_booking_air_fare 
									WHERE
										trans_xid =t_booking.trans_pid AND
										trans_air_xid =t_booking_air. 
										trans_air_pid 
				)
				WHEN (	SELECT
							LENGTH(CAST(trunc(round(SUM ((((COALESCE( 
							t_booking_air_fare.base_fare,0)) -((COALESCE( 
							t_booking_air_fare.plb_amount_retain,0)) +(COALESCE( 
							t_booking_air_fare.overriding_comm_amt_retain,0)))) 
							* COALESCE(t_booking_air.selling_cons_exc_rt,0))):: 
							NUMERIC,0))AS VARCHAR)) 
						FROM
							t_booking_air_fare 
						WHERE
							trans_xid =t_booking.trans_pid AND
							trans_air_xid =t_booking_air.trans_air_pid 
				)
				=3 
				THEN 'M'||'00'|| (	SELECT
										CAST(round(SUM((COALESCE(
										t_booking_air_fare.base_fare_supp_curr,0
										) * COALESCE(t_booking_air_fare.
										suppliertoadminexcgrate) ) - ((COALESCE(
										t_booking_air_fare.plb_amount_retain,0) 
										* COALESCE(t_booking_air.
										selling_cons_exc_rt,0)) + (COALESCE(
										t_booking_air_fare.
										overriding_comm_amt_retain_supp_currr,0) 
										* COALESCE(t_booking_air_fare.
										suppliertoadminexcgrate)) ) )::NUMERIC,0
										)AS VARCHAR) 
									FROM
										t_booking_air_fare 
									WHERE
										trans_xid =t_booking.trans_pid AND
										trans_air_xid =t_booking_air. 
										trans_air_pid 
				)
				WHEN (	SELECT
							LENGTH(CAST(trunc(round(SUM ((((COALESCE( 
							t_booking_air_fare.base_fare,0)) -((COALESCE( 
							t_booking_air_fare.plb_amount_retain,0)) +(COALESCE( 
							t_booking_air_fare.overriding_comm_amt_retain,0)))) 
							* COALESCE(t_booking_air.selling_cons_exc_rt,0))):: 
							NUMERIC,0))AS VARCHAR)) 
						FROM
							t_booking_air_fare 
						WHERE
							trans_xid =t_booking.trans_pid AND
							trans_air_xid =t_booking_air.trans_air_pid 
				)
				=4 
				THEN 'M'||'0'|| (	SELECT
										CAST(round(SUM((COALESCE(
										t_booking_air_fare.base_fare_supp_curr,0
										) * COALESCE(t_booking_air_fare.
										suppliertoadminexcgrate) ) - ((COALESCE(
										t_booking_air_fare.plb_amount_retain,0) 
										* COALESCE(t_booking_air.
										selling_cons_exc_rt,0)) + (COALESCE(
										t_booking_air_fare.
										overriding_comm_amt_retain_supp_currr,0) 
										* COALESCE(t_booking_air_fare.
										suppliertoadminexcgrate)) ) )::NUMERIC,0
										)AS VARCHAR) 
									FROM
										t_booking_air_fare 
									WHERE
										trans_xid =t_booking.trans_pid AND
										trans_air_xid =t_booking_air. 
										trans_air_pid 
				)
				ELSE 'M'|| (SELECT
								CAST(round(SUM((COALESCE(t_booking_air_fare.
								base_fare_supp_curr,0) * COALESCE(
								t_booking_air_fare.suppliertoadminexcgrate) ) - 
								((COALESCE(t_booking_air_fare.plb_amount_retain,
								0) * COALESCE(t_booking_air.selling_cons_exc_rt,
								0)) + (COALESCE(t_booking_air_fare.
								overriding_comm_amt_retain_supp_currr,0) * 
								COALESCE(t_booking_air_fare.
								suppliertoadminexcgrate)) ) )::NUMERIC,0)AS 
								VARCHAR) 
							FROM
								t_booking_air_fare 
							WHERE
								trans_xid =t_booking.trans_pid AND
								trans_air_xid =t_booking_air.trans_air_pid 
				)
			END 
			ELSE 
			CASE 
				WHEN (	SELECT
							LENGTH(CAST(trunc(round(SUM ((((COALESCE( 
							t_booking_air_fare.base_fare,0)) -((COALESCE( 
							t_booking_air_fare.plb_amount_retain,0)) +(COALESCE( 
							t_booking_air_fare.overriding_comm_amt_retain,0)))) 
							* COALESCE(t_booking_air.selling_cons_exc_rt,0))):: 
							NUMERIC,0))AS VARCHAR)) 
						FROM
							t_booking_air_fare 
						WHERE
							trans_xid =t_booking.trans_pid AND
							trans_air_xid =t_booking_air.trans_air_pid 
				)
				=1 
				THEN 'D'||'0000'|| (SELECT
										CAST(round(SUM((COALESCE(
										t_booking_air_fare.base_fare_supp_curr,0
										) * COALESCE(t_booking_air_fare.
										suppliertoadminexcgrate) ) - ((COALESCE(
										t_booking_air_fare.plb_amount_retain,0) 
										* COALESCE(t_booking_air.
										selling_cons_exc_rt,0)) + (COALESCE(
										t_booking_air_fare.
										overriding_comm_amt_retain_supp_currr,0) 
										* COALESCE(t_booking_air_fare.
										suppliertoadminexcgrate)) ) )::NUMERIC,0
										)AS VARCHAR) 
									FROM
										t_booking_air_fare 
									WHERE
										trans_xid =t_booking.trans_pid AND
										trans_air_xid =t_booking_air. 
										trans_air_pid 
				)
				WHEN (	SELECT
							LENGTH(CAST(trunc(round(SUM ((((COALESCE( 
							t_booking_air_fare.base_fare,0)) -((COALESCE( 
							t_booking_air_fare.plb_amount_retain,0)) +(COALESCE( 
							t_booking_air_fare.overriding_comm_amt_retain,0)))) 
							* COALESCE(t_booking_air.selling_cons_exc_rt,0))):: 
							NUMERIC,0))AS VARCHAR)) 
						FROM
							t_booking_air_fare 
						WHERE
							trans_xid =t_booking.trans_pid AND
							trans_air_xid =t_booking_air.trans_air_pid 
				)
				=2 
				THEN 'D'||'000'|| (	SELECT
										CAST(round(SUM((COALESCE(
										t_booking_air_fare.base_fare_supp_curr,0
										) * COALESCE(t_booking_air_fare.
										suppliertoadminexcgrate) ) - ((COALESCE(
										t_booking_air_fare.plb_amount_retain,0) 
										* COALESCE(t_booking_air.
										selling_cons_exc_rt,0)) + (COALESCE(
										t_booking_air_fare.
										overriding_comm_amt_retain_supp_currr,0) 
										* COALESCE(t_booking_air_fare.
										suppliertoadminexcgrate)) ) )::NUMERIC,0
										)AS VARCHAR) 
									FROM
										t_booking_air_fare 
									WHERE
										trans_xid =t_booking.trans_pid AND
										trans_air_xid =t_booking_air. 
										trans_air_pid 
				)
				WHEN (	SELECT
							LENGTH(CAST(trunc(round(SUM ((((COALESCE( 
							t_booking_air_fare.base_fare,0)) -((COALESCE( 
							t_booking_air_fare.plb_amount_retain,0)) +(COALESCE( 
							t_booking_air_fare.overriding_comm_amt_retain,0)))) 
							* COALESCE(t_booking_air.selling_cons_exc_rt,0))):: 
							NUMERIC,0))AS VARCHAR)) 
						FROM
							t_booking_air_fare 
						WHERE
							trans_xid =t_booking.trans_pid AND
							trans_air_xid =t_booking_air.trans_air_pid 
				)
				=3 
				THEN 'D'||'00'|| (	SELECT
										CAST(round(SUM((COALESCE(
										t_booking_air_fare.base_fare_supp_curr,0
										) * COALESCE(t_booking_air_fare.
										suppliertoadminexcgrate) ) - ((COALESCE(
										t_booking_air_fare.plb_amount_retain,0) 
										* COALESCE(t_booking_air.
										selling_cons_exc_rt,0)) + (COALESCE(
										t_booking_air_fare.
										overriding_comm_amt_retain_supp_currr,0) 
										* COALESCE(t_booking_air_fare.
										suppliertoadminexcgrate)) ) )::NUMERIC,0
										)AS VARCHAR) 
									FROM
										t_booking_air_fare 
									WHERE
										trans_xid =t_booking.trans_pid AND
										trans_air_xid =t_booking_air. 
										trans_air_pid 
				)
				WHEN (	SELECT
							LENGTH(CAST(trunc(round(SUM ((((COALESCE( 
							t_booking_air_fare.base_fare,0)) -((COALESCE( 
							t_booking_air_fare.plb_amount_retain,0)) +(COALESCE( 
							t_booking_air_fare.overriding_comm_amt_retain,0)))) 
							* COALESCE(t_booking_air.selling_cons_exc_rt,0))):: 
							NUMERIC,0))AS VARCHAR)) 
						FROM
							t_booking_air_fare 
						WHERE
							trans_xid =t_booking.trans_pid AND
							trans_air_xid =t_booking_air.trans_air_pid 
				)
				=4 
				THEN 'D'||'0'|| (	SELECT
										CAST(round(SUM((COALESCE(
										t_booking_air_fare.base_fare_supp_curr,0
										) * COALESCE(t_booking_air_fare.
										suppliertoadminexcgrate) ) - ((COALESCE(
										t_booking_air_fare.plb_amount_retain,0) 
										* COALESCE(t_booking_air.
										selling_cons_exc_rt,0)) + (COALESCE(
										t_booking_air_fare.
										overriding_comm_amt_retain_supp_currr,0) 
										* COALESCE(t_booking_air_fare.
										suppliertoadminexcgrate)) ) )::NUMERIC,0
										)AS VARCHAR) 
									FROM
										t_booking_air_fare 
									WHERE
										trans_xid =t_booking.trans_pid AND
										trans_air_xid =t_booking_air. 
										trans_air_pid 
				)
				ELSE 'D'|| (SELECT
								CAST(round(SUM((COALESCE(t_booking_air_fare.
								base_fare_supp_curr,0) * COALESCE(
								t_booking_air_fare.suppliertoadminexcgrate) ) - 
								((COALESCE(t_booking_air_fare.plb_amount_retain,
								0) * COALESCE(t_booking_air.selling_cons_exc_rt,
								0)) + (COALESCE(t_booking_air_fare.
								overriding_comm_amt_retain_supp_currr,0) * 
								COALESCE(t_booking_air_fare.
								suppliertoadminexcgrate)) ) )::NUMERIC,0)AS 
								VARCHAR) 
							FROM
								t_booking_air_fare 
							WHERE
								trans_xid =t_booking.trans_pid AND
								trans_air_xid =t_booking_air.trans_air_pid 
				)
			END 
		END 
		ELSE 
		CASE 
			WHEN SUBSTRING(t_booking_air_fare.value_code,1,1)='Q' 
			THEN 'M'||SUBSTRING(t_booking_air_fare.value_code,2,LENGTH( 
			t_booking_air_fare.value_code)-1) 
			ELSE TRIM(t_booking_air_fare.value_code) 
		END 
	END                                                                                 
	AS ValueCd,
	'AED'                                                                           
	AS PurrCurrCd,
	100                                                                             
	AS PurRate,
	0                                                                               
	AS PurAmount,
	CASE 
		WHEN t_booking_air.is_lcc='Y' 
		THEN (	SELECT
					vendor_number 
				FROM
					m_document_master 
				WHERE
					t_booking_air.doc_code=m_document_master.doc_code 
		)
		ELSE '' 
	END                                                                                 
	AS AccNo,
	TRIM(t_booking.booking_no)                                                      
	AS VendInvoNo,
	NULL                                                                            
	AS FopAmt2,
	TRIM(t_booking_air_pnr.gds_pnr)                                                 
	AS PNRno,
	case when TRIM(t_booking_air_fare.tour_code) ilike '%*%' then 
case when TRIM(t_booking_air_fare.tour_code) like '%\/%' then 
substring (TRIM(t_booking_air_fare.tour_code), 
length(TRIM(t_booking_air_fare.tour_code)) - position('*' in reverse_string(TRIM(t_booking_air_fare.tour_code))) + 2,
position('/' in (TRIM(t_booking_air_fare.tour_code))) - (length(TRIM(t_booking_air_fare.tour_code)) - position('*' in reverse_string(TRIM(t_booking_air_fare.tour_code))) + 2))
else substring (TRIM(t_booking_air_fare.tour_code),
length(TRIM(t_booking_air_fare.tour_code)) - position('*' in reverse_string(TRIM(t_booking_air_fare.tour_code))) + 2,length(TRIM(t_booking_air_fare.tour_code)))
end
else TRIM(t_booking_air_fare.tour_code) end                                               
	AS tourcd,
	t_booking_document.document_dt                                                  
	AS VendorInvoiceDate,
	(	SELECT
			crs_id 
		FROM
			m_supplier 
		WHERE
			m_supplier.supplier_pid=t_booking_air.supplier_xid 
	)
	AS crs_pnr_no,
	0                                                                               
	AS savamount,
	TRIM(t_booking_air_pnr.gds_pnr)                                                 
	AS dsr_remarks,
	''                                                                              
	AS servicename,
	''                                                                              
	AS servicecategory,
	NULL                                                                            
	AS checkindate,
	NULL                                                                            
	AS checkoutdate,
	''                                                                              
	AS servicecity,
	''                                                                              
	AS remarks,
	(	SELECT
			TRIM(cost_center_code) 
		FROM
			m_cost_center 
		WHERE
			cost_center_pid=t_booking_air_pax.cost_center_xid 
	)
	AS costcenterno,
	TRIM(t_booking_air_pax.country)                                                 
	AS visacountry,
	NULL                                                                            
	AS rbdeposit,
	NULL                                                                            
	AS rbdeposit2,
	(	SELECT
			SUM(COALESCE(t_booking_air_fare.trans_fee_cons_curr,2)) 
		FROM
			t_booking_air_fare 
		WHERE
			trans_xid =t_booking.trans_pid AND
			trans_air_xid =t_booking_air.trans_air_pid 
	)
	AS Transfee,
	0                                                                               
	AS transfeed,
	NULL                                                                            
	AS transfee2,
	NULL                                                                            
	AS transfeed2,
	''                                                                              
	AS ca,
	TRIM(t_booking_air.primary_carrier)                                             
	AS airlcd,
	TRIM(fmcity_xid)                                                                
	AS frmdestcd,
	TRIM(tocity_xid)                                                                
	AS todestcd,
	CASE 
		WHEN (LENGTH(t_booking_air_pax.first_name)+LENGTH(t_booking_air_pax. 
		last_name)+LENGTH(t_booking_air_pax.title)) >38 
		THEN COALESCE(SUBSTRING (TRIM(t_booking_air_pax.last_name),1,17) ,'')|| 
		' ' ||COALESCE(SUBSTRING (TRIM(t_booking_air_pax.first_name),1,16) ,'') 
		||' ' ||COALESCE(SUBSTRING (TRIM(t_booking_air_pax.title),1,7) ,'') 
		ELSE COALESCE(TRIM(t_booking_air_pax.last_name),'') ||' ' || COALESCE ( 
		TRIM(t_booking_air_pax.first_name),'') || ' ' ||COALESCE(TRIM( 
		t_booking_air_pax.title),'') 
	END                                                                                 
	AS TrvName,
	''                                                                              
	AS isi,
	(	SELECT
			'AED'||''||round(tax::NUMERIC,2)||''|| TRIM(tax_info) 
		FROM
			(	SELECT
					SUM ((tax))             AS tax ,
					tax_info,
					row_number() over () AS row_no 
				FROM
					t_booking_air_fare_tax 
				WHERE
					trans_air_xid=t_booking_air.trans_air_pid 
				GROUP BY
					tax_info 
			)
			t 
		WHERE
			row_no=1 
	)
	AS taxprint1,
	(	SELECT
			'AED'||''||round(tax::NUMERIC,2)||''|| TRIM(tax_info) 
		FROM
			(	SELECT
					SUM ((tax))             AS tax,
					tax_info,
					row_number() over () AS row_no 
				FROM
					t_booking_air_fare_tax 
				WHERE
					trans_air_xid=t_booking_air.trans_air_pid 
				GROUP BY
					tax_info 
			)
			t 
		WHERE
			row_no =2 
	)
	AS taxprint2,
	(	SELECT
			'AED'||''||round(SUM (tax)::NUMERIC,2)||'' ||'XT' 
		FROM
			(	SELECT
					SUM ((tax))             AS tax ,
					tax_info,
					row_number() over () AS row_no 
				FROM
					t_booking_air_fare_tax 
				WHERE
					trans_air_xid=t_booking_air.trans_air_pid 
				GROUP BY
					tax_info 
			)
			t 
		WHERE
			row_no >2 
	)
	AS taxprint3,
	''                                                                              
	AS excarrcd,
	''                                                                              
	AS exdocno,
	''                                                                              
	AS exserno,
	''                                                                              
	AS exconj,
	'DIRECT/1L'                                                                     
	AS bookingno,
	TRIM(CAST (t_booking_air_fare.fare_calculation AS VARCHAR))                     
	AS fc ,
	array_to_string(ARRAY(	SELECT
								TRIM(tax_info) ||'(' || round( SUM((
								tax))::NUMERIC,2)||')' 
							FROM
								t_booking_air_fare_tax 
							WHERE
								trans_air_xid =t_booking_air.trans_air_pid 
							GROUP BY
								tax_info ) ,',')                                                   
	AS tax ,
	TRIM(fm_iata_xid)||'-'|| TRIM(to_iata_xid)                                      
	AS sector,
	CASE WHEN TRIM(t_booking_air_sector.status_code) = 'AA'
    THEN 'HK'
	ELSE TRIM(t_booking_air_sector.status_code) END                                          
	AS stcd,
	TRIM(t_booking_air_sector.fare_basis)                                           
	AS fbno,
	TRIM(t_booking_air.primary_carrier)                                             
	AS carrcd,
	TRIM(flight_no)                                                                 
	AS flightno,
		substring(TRIM(booking_class),1,1)                                                                                          
	AS classcd,
	dep_date                                                                        
	AS depdate,
	dep_time                                                                        
	AS deptime,
	arr_date                                                                        
	AS arrdate,
	arr_time                                                                        
	AS arrtime,
	CASE 
	WHEN TRIM(t_booking_air_sector_pax_dtl.baggage_allowance) IN ('NIN','-NA-')
    THEN 'NIL'
    ELSE LEFT(TRIM(t_booking_air_sector_pax_dtl.baggage_allowance),3) END                            
	AS allow,
	t_booking_air_sector_pax_dtl.not_valid_before                                   
	AS nvb,
	t_booking_air_sector_pax_dtl.not_valid_after                                    
	AS nva,
	TRIM(t_booking_air_sector.airline_xid)                                          
	AS operbycarrcode,
	TRIM(t_booking_air_sector.code_share_flight)                                    
	AS opercarrcd,
	TRIM(flight_no)                                                                 
	AS operflight,
	TRIM(t_booking_air_pax.mealpref)                                                
	AS meal,
	'0'                                                                             
	AS nostop,
	TRIM(t_booking_air_sector.duration)                                             
	AS journeytime,
	TRIM(t_booking_air_sector.equipment_type)                                       
	AS equipmenttype,
	CASE 
		WHEN t_booking_air.is_lcc='N' 
		THEN TRIM(t_booking_air_sector_pax_dtl.tkt_no) 
		ELSE '' 
	END                                                                                 
	AS serno,
	CASE 
		WHEN (LENGTH(t_booking_air_pax.first_name)+LENGTH(t_booking_air_pax. 
		last_name)+LENGTH(t_booking_air_pax.title)) >38 
		THEN COALESCE(SUBSTRING (TRIM(t_booking_air_pax.last_name),1,17) ,'')|| 
		' ' ||COALESCE(SUBSTRING (TRIM(t_booking_air_pax.first_name),1,16) ,'') 
		||' ' ||COALESCE(SUBSTRING (TRIM(t_booking_air_pax.title),1,7) ,'') 
		ELSE COALESCE(TRIM(t_booking_air_pax.last_name),'') ||' ' || COALESCE ( 
		TRIM(t_booking_air_pax.first_name),'') || ' ' ||COALESCE(TRIM( 
		t_booking_air_pax.title),'') 
	END                                                                                 
	AS TrvName,
	''                                                                              
	AS admcd,
	(	SELECT
			COALESCE(TRIM(reference_number),'') 
		FROM
			m_traveller 
		WHERE
			traveller_pid =t_booking_air_pax.traveller_xid 
	)
	AS empno,
	(	SELECT
			TRIM(project_code) 
		FROM
			m_project 
		WHERE
			project_pid=t_booking_air_pax.project_xid 
	)
	AS projno,
	    case when t_booking_document_dtl.fop_name = 'CC-CPG'
    THEN t_booking_document_dtl.ordercode
    else
	TRIM(CAST(COALESCE (t_booking_air_pax.traveller_xid,dependent_xid)  AS 
	VARCHAR)) end AS reqno,
	NULL                                                                            
	AS costcenter,
	NULL                                                                            
	AS fareid,
	NULL                                                                            
	AS farequoteid,
	NULL                                                                            
	AS dbinfo,
	NULL                                                                            
	AS dbinfocardtype ,
	TRIM(is_miscellaneous)                                                          
	AS is_miscellaneous,
	NULL,
	NULL,
	NULL,
	NULL,
	NULL,
	NULL,
	is_lcc_ancillary                                                                
	AS is_lcc_ancillary ,
	t_booking_air.is_lcc                                                            
	AS is_lcc ,protas_order_no,
    t_booking_document_dtl.fop_type,
    credit_card_no,
    CASE 
    WHEN approved_key ILIKE '%/%'
    THEN left(approved_key, strpos(approved_key, '/') - 1)
    ELSE
    approved_key
    END,case when TRIM(t_booking_air.tour_code) ilike '%*%' then 
case when TRIM(t_booking_air.tour_code) like '%\/%' then 
substring (TRIM(t_booking_air.tour_code), 
length(TRIM(t_booking_air.tour_code)) - position('*' in reverse_string(TRIM(t_booking_air.tour_code))) + 2,
position('/' in (TRIM(t_booking_air.tour_code))) - (length(TRIM(t_booking_air.tour_code)) - position('*' in reverse_string(TRIM(t_booking_air.tour_code))) + 2))
else substring (TRIM(t_booking_air_fare.tour_code),
length(TRIM(t_booking_air.tour_code)) - position('*' in reverse_string(TRIM(t_booking_air.tour_code))) + 2,length(TRIM(t_booking_air.tour_code)))
end
else TRIM(t_booking_air.tour_code) end  ,
	'eTravel',
	(total_markup+t_booking_air.adhoc_markup_sell_curr),
CASE WHEN (select upper(country) from m_iata where iata_pid=tocity_xid)<>upper('BAHRAIN')then	'VX' 
else
		case	WHEN (	SELECT
						country_code 
					FROM
						m_country 
					WHERE
						UPPER(country_name) =(	SELECT
													UPPER(country) 
												FROM
													m_supplier 
												WHERE
													supplier_pid=t_booking_air.supplier_xid
						)
			)
			='BH' 
			THEN 'V5' else 'V0' end 
		END  ,	(	SELECT
			round(SUM( ((COALESCE(t_booking_air_fare.base_fare_supp_curr,0))* 
			COALESCE(t_booking_air_fare. suppliertoadminexcgrate,0)) +COALESCE(
			t_booking_air_fare.markup_cons_curr,0) + (t_booking_air_fare.
			adhoc_markup_cons_curr))::NUMERIC, 2) 
		FROM
			t_booking_air_fare 
		WHERE
			trans_xid =t_booking.trans_pid AND
			trans_air_xid =t_booking_air.trans_air_pid 
	),
	(	SELECT
			round(SUM( ((COALESCE(t_booking_air_fare.base_fare_supp_curr,0))* 
			COALESCE(t_booking_air_fare. suppliertoadminexcgrate,0)) +COALESCE(
			t_booking_air_fare.markup_cons_curr,0) + (t_booking_air_fare.
			adhoc_markup_cons_curr))::NUMERIC, 2) 
		FROM
			t_booking_air_fare 
		WHERE
			trans_xid =t_booking.trans_pid AND
			trans_air_xid =t_booking_air.trans_air_pid 
	),
	0,
	case when (select upper(country) from m_iata where iata_pid=tocity_xid)=upper('BAHRAIN')then	'V5' else 'VX' end,
	0,
	0,
CASE WHEN (select upper(country) from m_iata where iata_pid=tocity_xid)<>upper('BAHRAIN')then	'VX' 
else
		case	WHEN (	SELECT
						country_code 
					FROM
						m_country 
					WHERE
						UPPER(country_name) =(	SELECT
													UPPER(country) 
												FROM
													m_supplier 
												WHERE
													supplier_pid=t_booking_air.supplier_xid
						)
			)
			='BH' 
			THEN 'V5' else 'V0' end 
		END  ,	0,
	'',
	0,
	'',
	0,
	'Service',
	to_char(t_booking_air.travel_dt::DATE,'dd-Mon-yyyy'),
	'',
	(	SELECT
			TRIM(country_code) 
		FROM
			m_country 
		WHERE
			UPPER(country_name) =(	SELECT
										UPPER(country) 
									FROM
										m_supplier 
									WHERE
										supplier_pid=t_booking_air.supplier_xid
			)
	)
	,
	(	SELECT
			TRIM(country_code) 
		FROM
			m_country 
		WHERE
			UPPER(country_name) =(	SELECT
										UPPER(country) 
									FROM
										m_client 
									WHERE
										client_pid=t_booking.client_xid
			)
	)
	,
	(	SELECT
			vat_registration_no 
		FROM
			m_client 
		WHERE
			client_pid=t_booking.client_xid
	)
	,
	'',
	'',is_pnr_sync_only,supplier_pid,protas_hit_count
FROM
	t_booking 
		JOIN t_booking_air 
		ON (trans_pid=t_booking_air.trans_xid) 
			JOIN t_booking_air_pax 
			ON (trans_air_pid=t_booking_air_pax.trans_air_xid AND
			t_booking_air_pax.air_pax_pid IN (	SELECT
													MIN(COALESCE(air_pax_pid)) 
												FROM
													t_booking_air_pax 
												WHERE
													trans_xid=t_booking.
													trans_pid 
												GROUP BY
													trans_air_xid 
			)
			) 	
				JOIN t_booking_document 
				ON(t_booking_document.trans_xid = t_booking.trans_pid AND
				(string_to_array(selected_travelers_ids,',')@>string_to_array( 
				'T-'||traveller_xid,',')) OR
				(string_to_array(selected_travelers_ids,',')@>string_to_array( 
				'D-'||dependent_xid,','))) 
					JOIN t_booking_document_dtl 
					ON (t_booking_document_dtl.trans_doc_xid = 
					t_booking_document.trans_doc_pid AND
					trans_prod_xid = trans_air_pid AND
					(t_booking_document_dtl.air_pax_xid = air_pax_pid OR
					t_booking_document_dtl.air_pax_xid IS NULL)) 
						JOIN m_client 
						ON (client_pid=t_booking.client_xid) 
							JOIN t_booking_air_sector 
							ON (t_booking.trans_pid=t_booking_air_sector. 
							trans_xid AND
							t_booking_air.trans_air_pid=t_booking_air_sector. 
							trans_air_xid) 
								JOIN t_booking_air_sector_pax_dtl 
								ON (t_booking_air.trans_air_pid= 
								t_booking_air_sector_pax_dtl.trans_air_xid AND
								t_booking_air_pax.air_pax_pid= 
								t_booking_air_sector_pax_dtl.air_pax_xid AND
								t_booking_air_sector.air_leg_pid= 
								t_booking_air_sector_pax_dtl.air_leg_xid AND
								t_booking.trans_pid=t_booking_air_sector_pax_dtl 
								.trans_xid ) 
									JOIN t_booking_air_fare 
									ON (t_booking.trans_pid=t_booking_air_fare. 
									trans_xid AND
									t_booking_air.trans_air_pid= 
									t_booking_air_fare.trans_air_xid AND
									t_booking_air_pax.air_pax_pid= 
									t_booking_air_fare.air_pax_xid) 
										JOIN m_supplier 
										ON (t_booking_air.supplier_xid = 
										m_supplier.supplier_pid) 
											JOIN m_login_user 
											ON (login_user_pid=t_booking. 
											employee_xid) 
												JOIN t_booking_air_pnr 
												ON (trans_pid=t_booking_air_pnr. 
												trans_xid AND
												trans_air_pid=t_booking_air_pnr. 
												trans_air_xid) 
													LEFT JOIN 
													t_booking_air_reissue_ticket 
													ON (trans_pid= 
													t_booking_air_reissue_ticket 
													.trans_xid AND
													trans_air_pid= 
													t_booking_air_reissue_ticket 
													.trans_air_xid) 
WHERE
	document_no = ls_invoice_no AND
            (SELECT count(total_tax_supp_curr) FROM t_booking_air_fare 
where trans_xid=(SELECT trans_xid FROM t_booking_document WHERE document_no=ls_invoice_no) and total_tax_supp_curr is not null)=((SELECT count(*) FROM t_booking_air_fare where trans_xid=(SELECT trans_xid FROM t_booking_document WHERE document_no=ls_invoice_no))) AND
	doc_type='I' AND
	t_booking_air.is_lcc='Y' AND
	t_booking_air.is_miscellaneous='N'  and is_invoice_blocked= 'N'
UNION
	ALL 
SELECT
	trans_doc_pid                                                                   
	AS doc_id,
	'ANC'                                                                           
	AS product,
	trans_air_pid                                                                   
	AS product_id,
	NULL                                                                            
	AS leg_pax_pid,
	TRIM(m_client.account_code)                                                     
	AS AccNo,

	coalesce((SELECT
			TRIM(branch_code) 
		FROM
			m_branch 
		WHERE
			branch_pid=(SELECT branch_xid FROM m_regional_pcc_branch_mapping WHERE supplier_xid=(SELECT supplier_xid FROM m_hap_master WHERE hap_pid=t_booking_air.ticket_hapid) and (SELECT is_regional_pcc_ticketing FROM m_supplier WHERE supplier_pid=(SELECT supplier_xid FROM m_hap_master WHERE hap_pid=t_booking_air.ticket_hapid))='Y' and client_xid=t_booking.client_xid)),(	SELECT
			TRIM(branch_code) 
		FROM
			m_branch 
		WHERE
			branch_pid=(SELECT
							branch_xid 
						FROM
							m_client_branch_mapping 
						WHERE
							client_xid=t_booking.client_xid AND
							is_default='Y' 
			)
	))
	AS OffNo,
	(	SELECT
			employee_no 
		FROM
			m_login_user 
		WHERE
			login_user_pid=t_booking_air.salesman_xid 
	)
	AS SalNo,
	(	SELECT
			TRIM(branch_code) 
		FROM
			m_branch 
		WHERE
			branch_pid=(SELECT
							branch_xid 
						FROM
							m_client_branch_mapping 
						WHERE
							client_xid=t_booking.client_xid AND
							is_default='Y' 
			)
	)
	AS OwnOffNo,
	t_booking_air.travel_type                                                       
	AS CustType,
	(	SELECT
			COALESCE(TRIM(reference_number),'') 
		FROM
			m_traveller 
		WHERE
			traveller_pid =t_booking_air_pax.traveller_xid 
	)
	AS OrdEmpNo,
	CASE 
		WHEN (LENGTH(t_booking_air_pax.first_name)+LENGTH(t_booking_air_pax. 
		last_name)+LENGTH(t_booking_air_pax.title)) >38 
		THEN COALESCE(SUBSTRING (TRIM(t_booking_air_pax.last_name),1,17) ,'')|| 
		' ' ||COALESCE(SUBSTRING (TRIM(t_booking_air_pax.first_name),1,16) ,'') 
		||' ' ||COALESCE(SUBSTRING (TRIM(t_booking_air_pax.title),1,7) ,'') 
		ELSE COALESCE(TRIM(t_booking_air_pax.last_name),'') ||' ' || COALESCE ( 
		TRIM(t_booking_air_pax.first_name),'') || ' ' ||COALESCE(TRIM( 
		t_booking_air_pax.title),'') 
	END                                                                                 
	AS TrvName,
    case when t_booking_document_dtl.fop_name = 'CC-CPG'
    THEN t_booking_document_dtl.ordercode
    else
	TRIM(t_booking_air.lpo_number)     end                                             
	AS ReqNo,
	'0'                                                                             
	AS IT,
	(	SELECT
			TRIM(branch_code) 
		FROM
			m_branch 
		WHERE
			branch_pid=t_booking_air.booking_branch_xid 
	)
	AS BookingOffNo,
	(	SELECT
			TRIM(cost_center_code) 
		FROM
			m_cost_center 
		WHERE
			cost_center_pid=t_booking_air_pax.cost_center_xid 
	)
	AS CostCenter,
	''                                                                              
	AS ApprCd,
	(	SELECT
			TRIM(project_code) 
		FROM
			m_project 
		WHERE
			project_pid =t_booking_air_pax.project_xid 
	)
	AS project_no,
	t_booking_air.travel_dt                                                         
	AS TravelDate,
	'N'                                                                             
	AS Exchangetrans,
	(SELECT


					fop_no 
				FROM
					m_fop_meta 
				WHERE
					m_fop_meta.fop=
(CASE
WHEN t_booking_air.mode_of_booking in  ('CS','PG','CC') 
THEN
COALESCE(t_booking_document_dtl.fop_name,t_booking_air.mode_of_booking) 
ELSE
t_booking_air.mode_of_booking
END) )
AS FOPNo,
null AS FOPNo2,
	CASE 
		WHEN t_booking.fop_type='PT' 
		THEN TRIM(t_booking_air.mode_of_booking) 
		ELSE (	SELECT
					TRIM(mop) 
				FROM
					(	SELECT
							mop,
							trans_pax_mop_pid 
						FROM
							t_booking_pax_mop 
						WHERE
							t_booking_pax_mop.trans_prod_xid=t_booking_air. 
							trans_air_pid AND
							trans_doc_xid=t_booking_document.trans_doc_pid 
						ORDER BY
							trans_pax_mop_pid ASC LIMIT 1 
					)
					t 
		)
	END                                                                                 
	AS mop,
	(	SELECT
			TRIM(mop) 
		FROM
			(	SELECT
					mop,
					trans_pax_mop_pid 
				FROM
					t_booking_pax_mop 
				WHERE
					t_booking_pax_mop.trans_prod_xid=t_booking_air.trans_air_pid 
					AND
					trans_doc_xid=t_booking_document.trans_doc_pid 
				ORDER BY
					trans_pax_mop_pid ASC LIMIT 2 
			)
			t 
		ORDER BY
			trans_pax_mop_pid DESC LIMIT 1 
	)
	AS mop1,
	(	SELECT
			type_no 
		FROM
			m_document_master 
		WHERE
			doc_code=t_booking_air.anc_doc_code 
	)
	AS TypeNo,
	(	SELECT
			TRIM(CAST(doc_no AS VARCHAR)) 
		FROM
			m_document_master 
		WHERE
			doc_code=t_booking_air.anc_doc_code 
	)
	AS DocNo,
	''                                                                              
	AS SerNo,
	TRIM(t_booking_air.tocity_xid)                                                  
	AS DestCd,
	0                                                                               
	AS CommPct,
	1 Grp,
	NULL                                                                            
	AS conjNo,
	round(( (COALESCE(t_booking_air.total_ancillary_amt_client_curr,0) * 
	COALESCE(t_booking_air.selling_cons_exc_rt,0) + COALESCE(t_booking_air.
	total_markup_amt_admin_curr,0) + COALESCE(t_booking_air.seat_markup_amt_client_curr,0)*COALESCE(t_booking_air.selling_cons_exc_rt,0) ))::NUMERIC,2)                                                            
	AS SalAmountLocal,
	round((COALESCE(t_booking_air.total_markup_amt_admin_curr,0) + COALESCE(t_booking_air.seat_markup_amt_client_curr,0)*COALESCE(t_booking_air.selling_cons_exc_rt,0) ) ::NUMERIC,2)        
	AS CommAmt,
	0                                                                               
	AS TaxAmount ,
	round((COALESCE(t_booking_air.total_discount_amt_admin_curr,0) + (COALESCE(t_booking_air.seat_discount_amt_client_curr,0)*COALESCE(t_booking_air.selling_cons_exc_rt,0)) ) ::NUMERIC,2)       
	AS Rbamount,
	NULL                                                                            
	AS Rbamount2,
	round((COALESCE(t_booking_air.total_ancillary_amt_client_curr,0) * COALESCE(
	t_booking_air.selling_cons_exc_rt,0) + COALESCE(t_booking_air.
	total_markup_amt_admin_curr,0) + COALESCE(t_booking_air.seat_markup_amt_client_curr,0)*COALESCE(t_booking_air.selling_cons_exc_rt,0)  )::NUMERIC,2)                                                            
	AS EqAmount,
	''                                                                              
	AS ValueCd,
	'AED'                                                                           
	AS PurrCurrCd,
	100                                                                             
	AS PurRate,
	0                                                                               
	AS PurAmount,
	CASE 
		WHEN t_booking_air.is_lcc='Y' 
		THEN (	SELECT
					vendor_number 
				FROM
					m_document_master 
				WHERE
					t_booking_air.anc_doc_code=m_document_master.doc_code 
		)
		ELSE '' 
	END                                                                                 
	AS AccNo,
	TRIM(t_booking.booking_no)                                                      
	AS VendInvoNo,
	NULL                                                                            
	AS FopAmt2,
	TRIM(t_booking_air_pnr.gds_pnr)                                                 
	AS PNRno,
case when TRIM(t_booking_air_fare.tour_code) ilike '%*%' then 
case when TRIM(t_booking_air_fare.tour_code) like '%\/%' then 
substring (TRIM(t_booking_air_fare.tour_code), 
length(TRIM(t_booking_air_fare.tour_code)) - position('*' in reverse_string(TRIM(t_booking_air_fare.tour_code))) + 2,
position('/' in (TRIM(t_booking_air_fare.tour_code))) - (length(TRIM(t_booking_air_fare.tour_code)) - position('*' in reverse_string(TRIM(t_booking_air_fare.tour_code))) + 2))
else substring (TRIM(t_booking_air_fare.tour_code),
length(TRIM(t_booking_air_fare.tour_code)) - position('*' in reverse_string(TRIM(t_booking_air_fare.tour_code))) + 2,length(TRIM(t_booking_air_fare.tour_code)))
end
else TRIM(t_booking_air_fare.tour_code) end   
	AS tourcd,
	t_booking_document.document_dt                                                  
	AS VendorInvoiceDate,
	0                                                                               
	AS crs_pnr_no,
	0                                                                               
	AS savamount,
	TRIM(t_booking_air_pnr.gds_pnr)                                                 
	AS dsr_remarks,
	'Ancillary'                                                                     
	AS servicename,
	array_to_string(ARRAY(	SELECT
								CASE 
									WHEN t_booking_air.seat_fare_client_curr >0 
									THEN 'Seat' 
									ELSE NULL 
								END 
							UNION
SELECT
	CASE 
		WHEN t_booking_air.baggage_fare_client_curr >0 
		THEN 'Baggage' 
		ELSE NULL 
	END 
UNION
SELECT
	CASE 
		WHEN t_booking_air.meal_fare_client_curr >0 
		THEN 'Meal' 
		ELSE NULL 
	END ) ,'/')                                                   AS 
	servicecategory,
	NULL                                                                            
	AS checkindate,
	NULL                                                                            
	AS checkoutdate,
	TRIM(tocity_xid)                                                                
	AS servicecity,
	''                                                                              
	AS remarks,
	(	SELECT
			TRIM(cost_center_code) 
		FROM
			m_cost_center 
		WHERE
			cost_center_pid=t_booking_air_pax.cost_center_xid 
	)
	AS costcenterno,
	TRIM(t_booking_air_pax.country)                                                 
	AS visacountry,
	NULL                                                                            
	AS rbdeposit,
	NULL                                                                            
	AS rbdeposit2,
	0                                                                               
	AS Transfee,
	0                                                                               
	AS transfeed,
	NULL                                                                            
	AS transfee2,
	NULL                                                                            
	AS transfeed2,
	''                                                                              
	AS ca,
	''                                                                              
	AS airlcd,
	''                                                                              
	AS frmdestcd,
	''                                                                              
	AS todestcd,
	CASE 
		WHEN (LENGTH(t_booking_air_pax.first_name)+LENGTH(t_booking_air_pax. 
		last_name)+LENGTH(t_booking_air_pax.title)) >38 
		THEN COALESCE(SUBSTRING (TRIM(t_booking_air_pax.last_name),1,17) ,'')|| 
		' ' ||COALESCE(SUBSTRING (TRIM(t_booking_air_pax.first_name),1,16) ,'') 
		||' ' ||COALESCE(SUBSTRING (TRIM(t_booking_air_pax.title),1,7) ,'') 
		ELSE COALESCE(TRIM(t_booking_air_pax.last_name),'') ||' ' || COALESCE ( 
		TRIM(t_booking_air_pax.first_name),'') || ' ' ||COALESCE(TRIM( 
		t_booking_air_pax.title),'') 
	END                                                                                 
	AS TrvName,
	''                                                                              
	AS isi,
	''                                                                              
	AS taxprint1,
	''                                                                              
	AS taxprint2,
	''                                                                              
	AS taxprint3,
	''                                                                              
	AS excarrcd,
	''                                                                              
	AS exdocno,
	''                                                                              
	AS exserno,
	''                                                                              
	AS exconj,
	'DIRECT/1L'                                                                     
	AS bookingno,
	TRIM(CAST (t_booking_air_fare.fare_calculation AS VARCHAR))                     
	AS fc ,
	''                                                                              
	AS tax ,
	TRIM(fmcity_xid)||'-'|| TRIM(tocity_xid)                                        
	AS sector,
	''                                                                              
	AS stcd,
	''                                                                              
	AS fbno,
	''                                                                              
	AS carrcd,
	''                                                                              
	AS flightno,
	''                                                                              
	AS classcd,
	NULL                                                                            
	AS depdate,
	''                                                                              
	AS deptime,
	NULL                                                                            
	AS arrdate,
	''                                                                              
	AS arrtime,
	''                                                                              
	AS allow,
	''                                                                              
	AS nvb,
	''                                                                              
	AS nva,
	''                                                                              
	AS operbycarrcode,
	''                                                                              
	AS opercarrcd,
	''                                                                              
	AS operflight,
	TRIM(t_booking_air_pax.mealpref)                                                
	AS meal,
	'0'                                                                             
	AS nostop,
	''                                                                              
	AS journeytime,
	''                                                                              
	AS equipmenttype,
	''                                                                              
	AS serno,
	CASE 
		WHEN (LENGTH(t_booking_air_pax.first_name)+LENGTH(t_booking_air_pax. 
		last_name)+LENGTH(t_booking_air_pax.title)) >38 
		THEN COALESCE(SUBSTRING (TRIM(t_booking_air_pax.last_name),1,17) ,'')|| 
		' ' ||COALESCE(SUBSTRING (TRIM(t_booking_air_pax.first_name),1,16) ,'') 
		||' ' ||COALESCE(SUBSTRING (TRIM(t_booking_air_pax.title),1,7) ,'') 
		ELSE COALESCE(TRIM(t_booking_air_pax.last_name),'') ||' ' || COALESCE ( 
		TRIM(t_booking_air_pax.first_name),'') || ' ' ||COALESCE(TRIM( 
		t_booking_air_pax.title),'') 
	END                                                                                 
	AS TrvName,
	''                                                                              
	AS admcd,
	(	SELECT
			COALESCE(TRIM(reference_number),'') 
		FROM
			m_traveller 
		WHERE
			traveller_pid =t_booking_air_pax.traveller_xid 
	)
	AS empno,
	(	SELECT
			TRIM(project_code) 
		FROM
			m_project 
		WHERE
			project_pid=t_booking_air_pax.project_xid 
	)
	AS projno,
	case when t_booking_document_dtl.fop_name = 'CC-CPG'
    THEN t_booking_document_dtl.ordercode
    else
	TRIM(CAST(COALESCE (t_booking_air_pax.traveller_xid,dependent_xid) AS 
	VARCHAR)) end AS reqno,
	NULL                                                                            
	AS costcenter,
	NULL                                                                            
	AS fareid,
	NULL                                                                            
	AS farequoteid,
	NULL                                                                            
	AS dbinfo,
	NULL                                                                            
	AS dbinfocardtype ,
	TRIM(is_miscellaneous)                                                          
	AS is_miscellaneous,
	NULL,
	NULL,
	NULL,
	NULL,
	NULL,
	NULL,
	is_lcc_ancillary                                                                
	AS is_lcc_ancillary ,
	t_booking_air.is_lcc                                                            
	AS is_lcc ,protas_order_no,
    t_booking_document_dtl.fop_type,
    credit_card_no,
    CASE 
    WHEN approved_key ILIKE '%/%'
    THEN left(approved_key, strpos(approved_key, '/') - 1)
    ELSE
    approved_key
    END,case when TRIM(t_booking_air.tour_code) ilike '%*%' then 
case when TRIM(t_booking_air.tour_code) like '%\/%' then 
substring (TRIM(t_booking_air.tour_code), 
length(TRIM(t_booking_air.tour_code)) - position('*' in reverse_string(TRIM(t_booking_air.tour_code))) + 2,
position('/' in (TRIM(t_booking_air.tour_code))) - (length(TRIM(t_booking_air.tour_code)) - position('*' in reverse_string(TRIM(t_booking_air.tour_code))) + 2))
else substring (TRIM(t_booking_air_fare.tour_code),
length(TRIM(t_booking_air.tour_code)) - position('*' in reverse_string(TRIM(t_booking_air.tour_code))) + 2,length(TRIM(t_booking_air.tour_code)))
end
else TRIM(t_booking_air.tour_code) end  ,
	'eTravel',
	(total_markup+t_booking_air.adhoc_markup_sell_curr),
CASE WHEN (select upper(country) from m_iata where iata_pid=tocity_xid)<>upper('BAHRAIN')then	'VX' 
else
		case	WHEN (	SELECT
						country_code 
					FROM
						m_country 
					WHERE
						UPPER(country_name) =(	SELECT
													UPPER(country) 
												FROM
													m_supplier 
												WHERE
													supplier_pid=t_booking_air.supplier_xid
						)
			)
			='BH' 
			THEN 'V5' else 'V0' end 
		END  ,	round(( (COALESCE(t_booking_air.total_ancillary_amt_client_curr,0) * 
	COALESCE(t_booking_air.selling_cons_exc_rt,0) + COALESCE(t_booking_air.
	total_markup_amt_admin_curr,0) + COALESCE(t_booking_air.seat_markup_amt_client_curr,0)*COALESCE(t_booking_air.selling_cons_exc_rt,0)  ))::NUMERIC,2),
	round(( (COALESCE(t_booking_air.total_ancillary_amt_client_curr,0) * 
	COALESCE(t_booking_air.selling_cons_exc_rt,0) + COALESCE(t_booking_air.
	total_markup_amt_admin_curr,0)  + COALESCE(t_booking_air.seat_markup_amt_client_curr,0)*COALESCE(t_booking_air.selling_cons_exc_rt,0) ))::NUMERIC,2),
	0,
	case when (select upper(country) from m_iata where iata_pid=tocity_xid)=upper('BAHRAIN')then	'V5' else 'VX' end,
	0,
	0,
CASE WHEN (select upper(country) from m_iata where iata_pid=tocity_xid)<>upper('BAHRAIN')then	'VX' 
else
		case	WHEN (	SELECT
						country_code 
					FROM
						m_country 
					WHERE
						UPPER(country_name) =(	SELECT
													UPPER(country) 
												FROM
													m_supplier 
												WHERE
													supplier_pid=t_booking_air.supplier_xid
						)
			)
			='BH' 
			THEN 'V5' else 'V0' end 
		END  ,	0,
	'',
	0,
	'',
	0,
	'Service',
	to_char(t_booking_air.travel_dt::DATE,'dd-Mon-yyyy'),
	'',
	(	SELECT
			TRIM(country_code) 
		FROM
			m_country 
		WHERE
			UPPER(country_name) =(	SELECT
										UPPER(country) 
									FROM
										m_supplier 
									WHERE
										supplier_pid=t_booking_air.supplier_xid
			)
	)
	,
	(	SELECT
			TRIM(country_code) 
		FROM
			m_country 
		WHERE
			UPPER(country_name) =(	SELECT
										UPPER(country) 
									FROM
										m_client 
									WHERE
										client_pid=t_booking.client_xid
			)
	)
	,
	(	SELECT
			vat_registration_no 
		FROM
			m_client 
		WHERE
			client_pid=t_booking.client_xid
	)
	,
	'',
	'',is_pnr_sync_only,supplier_pid,protas_hit_count
FROM
	t_booking 
		JOIN t_booking_air 
		ON (trans_pid=t_booking_air.trans_xid) 
			JOIN t_booking_air_pax 
			ON (trans_air_pid=t_booking_air_pax.trans_air_xid AND
			t_booking_air_pax.air_pax_pid IN (	SELECT
													MIN(COALESCE(air_pax_pid)) 
												FROM
													t_booking_air_pax 
												WHERE
													trans_xid=t_booking.
													trans_pid 
												GROUP BY
													trans_air_xid 
			)
			) 	
				JOIN t_booking_document 
				ON(t_booking_document.trans_xid = t_booking.trans_pid AND
				(string_to_array(selected_travelers_ids,',')@>string_to_array( 
				'T-'||traveller_xid,',')) OR
				(string_to_array(selected_travelers_ids,',')@>string_to_array( 
				'D-'||dependent_xid,','))) 
					JOIN t_booking_document_dtl 
					ON (t_booking_document_dtl.trans_doc_xid = 
					t_booking_document.trans_doc_pid AND
					trans_prod_xid = trans_air_pid AND
					(t_booking_document_dtl.air_pax_xid = air_pax_pid OR
					t_booking_document_dtl.air_pax_xid IS NULL)) 
						JOIN m_client 
						ON (client_pid=t_booking.client_xid) 
							JOIN t_booking_air_fare 
							ON (t_booking.trans_pid=t_booking_air_fare.trans_xid 
							AND
							t_booking_air.trans_air_pid=t_booking_air_fare. 
							trans_air_xid AND
							t_booking_air_pax.air_pax_pid=t_booking_air_fare. 
							air_pax_xid) 
								JOIN m_supplier 
								ON (t_booking_air.supplier_xid = m_supplier. 
								supplier_pid) 
									JOIN m_login_user 
									ON (login_user_pid=t_booking.employee_xid) 
										JOIN t_booking_air_pnr 
										ON (trans_pid=t_booking_air_pnr. 
										trans_xid AND
										trans_air_pid=t_booking_air_pnr. 
										trans_air_xid) 
											LEFT JOIN 
											t_booking_air_reissue_ticket 
											ON (trans_pid= 
											t_booking_air_reissue_ticket. 
											trans_xid AND
											trans_air_pid= 
											t_booking_air_reissue_ticket. 
											trans_air_xid) 
WHERE
	document_no = ls_invoice_no AND
        (SELECT count(total_tax_supp_curr) FROM t_booking_air_fare 
where trans_xid=(SELECT trans_xid FROM t_booking_document WHERE document_no=ls_invoice_no) and total_tax_supp_curr is not null)=((SELECT count(*) FROM t_booking_air_fare where trans_xid=(SELECT trans_xid FROM t_booking_document WHERE document_no=ls_invoice_no))) AND
	doc_type='I' AND
	t_booking_air.is_lcc_ancillary='Y' AND
	t_booking_air.is_miscellaneous='N'  and is_invoice_blocked= 'N'
UNION
	ALL 
SELECT
	trans_doc_pid                                                                   
	AS doc_id,
	'A'                                                                             
	AS product,
	trans_air_pid                                                                   
	AS product_id,
	t_booking_air_sector_pax_dtl.leg_pax_pid                                        
	AS leg_pax_pid,
	TRIM(m_client.account_code)                                                     
	AS AccNo,

	coalesce((SELECT
			TRIM(branch_code) 
		FROM
			m_branch 
		WHERE
			branch_pid=(SELECT branch_xid FROM m_regional_pcc_branch_mapping WHERE supplier_xid=(SELECT supplier_xid FROM m_hap_master WHERE hap_pid=t_booking_air.ticket_hapid) and (SELECT is_regional_pcc_ticketing FROM m_supplier WHERE supplier_pid=(SELECT supplier_xid FROM m_hap_master WHERE hap_pid=t_booking_air.ticket_hapid))='Y' and client_xid=t_booking.client_xid)),(	SELECT
			TRIM(branch_code) 
		FROM
			m_branch 
		WHERE
			branch_pid=(SELECT
							branch_xid 
						FROM
							m_client_branch_mapping 
						WHERE
							client_xid=t_booking.client_xid AND
							is_default='Y' 
			)
	))
	AS OffNo,
	(	SELECT
			employee_no 
		FROM
			m_login_user 
		WHERE
			login_user_pid=t_booking_air.salesman_xid 
	)
	AS SalNo,
	(	SELECT
			TRIM(branch_code) 
		FROM
			m_branch 
		WHERE
			branch_pid=(SELECT
							branch_xid 
						FROM
							m_client_branch_mapping 
						WHERE
							client_xid=t_booking.client_xid AND
							is_default='Y' 
			)
	)
	AS OwnOffNo,
	t_booking_air.travel_type                                                       
	AS CustType,
	(	SELECT
			COALESCE(TRIM(reference_number),'') 
		FROM
			m_traveller 
		WHERE
			traveller_pid =t_booking_air_pax.traveller_xid 
	)
	AS OrdEmpNo,
	CASE 
		WHEN (LENGTH(t_booking_air_pax.first_name)+LENGTH(t_booking_air_pax. 
		last_name)+LENGTH(t_booking_air_pax.title)) >38 
		THEN COALESCE(SUBSTRING (TRIM(t_booking_air_pax.last_name),1,17) ,'')|| 
		' ' ||COALESCE(SUBSTRING (TRIM(t_booking_air_pax.first_name),1,16) ,'') 
		||' ' ||COALESCE(SUBSTRING (TRIM(t_booking_air_pax.title),1,7) ,'') 
		ELSE COALESCE(TRIM(t_booking_air_pax.last_name),'') ||' ' || COALESCE ( 
		TRIM(t_booking_air_pax.first_name),'') || ' ' ||COALESCE(TRIM( 
		t_booking_air_pax.title),'') 
	END                                                                                 
	AS TrvName,
    case when t_booking_document_dtl.fop_name = 'CC-CPG'
    THEN t_booking_document_dtl.ordercode
    else
	TRIM(t_booking_air.lpo_number) end                                                 
	AS ReqNo,
	'0'                                                                             
	AS IT,
	(	SELECT
			TRIM(branch_code) 
		FROM
			m_branch 
		WHERE
			branch_pid=t_booking_air.booking_branch_xid 
	)
	AS BookingOffNo,
	(	SELECT
			TRIM(cost_center_code) 
		FROM
			m_cost_center 
		WHERE
			cost_center_pid=t_booking_air_pax.cost_center_xid 
	)
	AS CostCenter,
	''                                                                              
	AS ApprCd,
	(	SELECT
			TRIM(project_code) 
		FROM
			m_project 
		WHERE
			project_pid =t_booking_air_pax.project_xid 
	)
	AS project_no,
	t_booking_air.travel_dt                                                         
	AS TravelDate,
	'N'                                                                             
	AS Exchangetrans,
	(SELECT


					fop_no 
				FROM
					m_fop_meta 
				WHERE
					m_fop_meta.fop=
(CASE
WHEN t_booking_air.mode_of_booking in  ('CS','PG','CC')   
THEN
COALESCE(t_booking_document_dtl.fop_name,t_booking_air.mode_of_booking) 
ELSE
t_booking_air.mode_of_booking
END) )
AS FOPNo,
null AS FOPNo2,
	CASE 
		WHEN t_booking.fop_type='PT' 
		THEN TRIM(t_booking_air.mode_of_booking) 
		ELSE (	SELECT
					TRIM(mop) 
				FROM
					(	SELECT
							mop,
							trans_pax_mop_pid 
						FROM
							t_booking_pax_mop 
						WHERE
							t_booking_pax_mop.trans_prod_xid=t_booking_air. 
							trans_air_pid AND
							trans_doc_xid=t_booking_document.trans_doc_pid 
						ORDER BY
							trans_pax_mop_pid ASC LIMIT 1 
					)
					t 
		)
	END                                                                                 
	AS mop,
	(	SELECT
			TRIM(mop) 
		FROM
			(	SELECT
					mop,
					trans_pax_mop_pid 
				FROM
					t_booking_pax_mop 
				WHERE
					t_booking_pax_mop.trans_prod_xid=t_booking_air.trans_air_pid 
					AND
					trans_doc_xid=t_booking_document.trans_doc_pid 
				ORDER BY
					trans_pax_mop_pid ASC LIMIT 2 
			)
			t 
		ORDER BY
			trans_pax_mop_pid DESC LIMIT 1 
	)
	AS mop1,
	(	SELECT
			type_no 
		FROM
			m_document_master 
		WHERE
			doc_code=t_booking_air.doc_code 
	)
	AS TypeNo,
	(	SELECT
			TRIM(CAST(doc_no AS VARCHAR)) 
		FROM
			m_document_master 
		WHERE
			doc_code=t_booking_air.doc_code 
	)
	AS DocNo,
	''                                                                              
	AS SerNo,
	TRIM(t_booking_air.tocity_xid)                                                  
	AS DestCd,
	CASE 
		WHEN t_booking_air_fare.base_fare=0 
		THEN 0 
		ELSE (	SELECT
					round(((SUM(COALESCE(t_booking_air_fare.iata_comm_amt_retain 
					,0)) / SUM(t_booking_air_fare.base_fare-t_booking_air_fare. 
					overriding_comm_amt_retain)) * 100)::NUMERIC, 0) 
				FROM
					t_booking_air_fare 
				WHERE
					t_booking_air_fare.trans_air_xid=t_booking_air.trans_air_pid 
					AND
					t_booking_air_fare .trans_xid =t_booking.trans_pid AND
					t_booking_air_fare.trans_pnr_xid=t_booking_air_pnr.
					trans_pnr_pid AND
					t_booking_air_fare.air_pax_xid=t_booking_air_pax.air_pax_pid 
		)
	END                                                                                 
	AS CommPct,
	1 Grp,
	NULL                                                                            
	AS conjNo,
	(	SELECT
			round(SUM( ((COALESCE(t_booking_air_fare.base_fare_supp_curr,0)) * 
			COALESCE(t_booking_air_fare. suppliertoadminexcgrate,0)) +COALESCE(
			t_booking_air_fare.markup_cons_curr,0) + (t_booking_air_fare.
			adhoc_markup_cons_curr))::NUMERIC, 2) 
		FROM
			t_booking_air_fare 
		WHERE
			t_booking_air_fare.trans_air_xid=t_booking_air.trans_air_pid AND
			t_booking_air_fare .trans_xid =t_booking.trans_pid AND
			t_booking_air_fare.trans_pnr_xid=t_booking_air_pnr.trans_pnr_pid AND
			t_booking_air_fare.air_pax_xid=t_booking_air_pax.air_pax_pid 
	)
	AS SalAmountLocal,
	(	SELECT
			round(SUM(( (t_booking_air_fare.iata_comm_amt_retain * COALESCE(
			t_booking_air.selling_cons_exc_rt,0)) +COALESCE(t_booking_air_fare.
			markup_cons_curr,0) + (t_booking_air_fare.adhoc_markup_cons_curr) ))
			:: NUMERIC, 0) 
		FROM
			t_booking_air_fare 
		WHERE
			t_booking_air_fare.trans_air_xid=t_booking_air.trans_air_pid AND
			t_booking_air_fare .trans_xid =t_booking.trans_pid AND
			t_booking_air_fare.trans_pnr_xid=t_booking_air_pnr.trans_pnr_pid AND
			t_booking_air_fare.air_pax_xid=t_booking_air_pax.air_pax_pid 
	)
	AS CommAmt,
	(	SELECT
			round(SUM(t_booking_air_fare.total_tax)::NUMERIC, 2) 
		FROM
			t_booking_air_fare 
		WHERE
			t_booking_air_fare.trans_air_xid=t_booking_air.trans_air_pid AND
			t_booking_air_fare .trans_xid =t_booking.trans_pid AND
			t_booking_air_fare.trans_pnr_xid=t_booking_air_pnr.trans_pnr_pid AND
			t_booking_air_fare.air_pax_xid=t_booking_air_pax.air_pax_pid 
	)
	AS TaxAmount ,
	(	SELECT
			round(SUM (((((COALESCE(t_booking_air_fare.iata_comm_amt,0)) +( 
			COALESCE(t_booking_air_fare.plb_amount,0)) +(COALESCE( 
			t_booking_air_fare.overriding_comm_amt,0)) ) * COALESCE( 
			t_booking_air.selling_cons_exc_rt,0)) + ( COALESCE( 
			t_booking_air_fare.adhoc_rebate_cons_curr,0) + COALESCE( 
			t_booking_air_fare.pure_discount_cons_curr,0)))) ::NUMERIC,2) 
		FROM
			t_booking_air_fare 
		WHERE
			t_booking_air_fare.trans_air_xid=t_booking_air.trans_air_pid AND
			t_booking_air_fare .trans_xid =t_booking.trans_pid AND
			t_booking_air_fare.trans_pnr_xid=t_booking_air_pnr.trans_pnr_pid AND
			t_booking_air_fare.air_pax_xid=t_booking_air_pax.air_pax_pid 
	)
	AS Rbamount,
	NULL                                                                            
	AS Rbamount2,
	(	SELECT
			round(SUM ((COALESCE(t_booking_air_fare.base_fare_supp_curr,0)* 
			COALESCE(t_booking_air_fare. suppliertoadminexcgrate,0)) -((COALESCE
			(t_booking_air_fare.plb_amount_retain,0) * COALESCE(t_booking_air.
			selling_cons_exc_rt,0)) +(COALESCE(t_booking_air_fare.
			overriding_comm_amt_retain_supp_currr,0) * COALESCE(
			t_booking_air_fare.suppliertoadminexcgrate))))::NUMERIC,2) 
		FROM
			t_booking_air_fare 
		WHERE
			t_booking_air_fare.trans_air_xid=t_booking_air.trans_air_pid AND
			t_booking_air_fare .trans_xid =t_booking.trans_pid AND
			t_booking_air_fare.trans_pnr_xid=t_booking_air_pnr.trans_pnr_pid AND
			t_booking_air_fare.air_pax_xid=t_booking_air_pax.air_pax_pid 
	)
	AS EqAmount,
	CASE 
		WHEN (value_code IS NULL) 
		THEN 
		CASE 
			WHEN (t_booking_air_fare.iata_comm_amt_retain IS NOT NULL AND
			t_booking_air_fare.iata_comm_amt_retain <> 0) 
			THEN 
			CASE 
				WHEN (	SELECT
							LENGTH(CAST(trunc(round(SUM ((((COALESCE( 
							t_booking_air_fare.base_fare,0)) -((COALESCE( 
							t_booking_air_fare.plb_amount_retain,0)) +(COALESCE( 
							t_booking_air_fare.overriding_comm_amt_retain,0)))) 
							* COALESCE(t_booking_air.selling_cons_exc_rt,0))):: 
							NUMERIC,0))AS VARCHAR)) 
						FROM
							t_booking_air_fare 
						WHERE
							t_booking_air_fare.trans_air_xid=t_booking_air.
							trans_air_pid AND
							t_booking_air_fare .trans_xid =t_booking.trans_pid 
							AND
							t_booking_air_fare.trans_pnr_xid=t_booking_air_pnr.
							trans_pnr_pid AND
							t_booking_air_fare.air_pax_xid=t_booking_air_pax.
							air_pax_pid 
				)
				=1 
				THEN 'M'||'0000'|| (SELECT
										CAST(round(SUM((COALESCE(
										t_booking_air_fare.base_fare_supp_curr,0
										) * COALESCE(t_booking_air_fare.
										suppliertoadminexcgrate) ) - ((COALESCE(
										t_booking_air_fare.plb_amount_retain,0) 
										* COALESCE(t_booking_air.
										selling_cons_exc_rt,0)) + (COALESCE(
										t_booking_air_fare.
										overriding_comm_amt_retain_supp_currr,0) 
										* COALESCE(t_booking_air_fare.
										suppliertoadminexcgrate)) ) )::NUMERIC,0
										)AS VARCHAR) 
									FROM
										t_booking_air_fare 
									WHERE
										t_booking_air_fare.trans_air_xid=
										t_booking_air.trans_air_pid AND
										t_booking_air_fare .trans_xid =t_booking
										.trans_pid AND
										t_booking_air_fare.trans_pnr_xid=
										t_booking_air_pnr.trans_pnr_pid AND
										t_booking_air_fare.air_pax_xid=
										t_booking_air_pax.air_pax_pid 
				)
				WHEN (	SELECT
							LENGTH(CAST(trunc(round(SUM ((((COALESCE( 
							t_booking_air_fare.base_fare,0)) -((COALESCE( 
							t_booking_air_fare.plb_amount_retain,0)) +(COALESCE( 
							t_booking_air_fare.overriding_comm_amt_retain,0)))) 
							* COALESCE(t_booking_air.selling_cons_exc_rt,0))):: 
							NUMERIC,0))AS VARCHAR)) 
						FROM
							t_booking_air_fare 
						WHERE
							t_booking_air_fare.trans_air_xid=t_booking_air.
							trans_air_pid AND
							t_booking_air_fare .trans_xid =t_booking.trans_pid 
							AND
							t_booking_air_fare.trans_pnr_xid=t_booking_air_pnr.
							trans_pnr_pid AND
							t_booking_air_fare.air_pax_xid=t_booking_air_pax.
							air_pax_pid 
				)
				=2 
				THEN 'M'||'000'|| (	SELECT
										CAST(round(SUM((COALESCE(
										t_booking_air_fare.base_fare_supp_curr,0
										) * COALESCE(t_booking_air_fare.
										suppliertoadminexcgrate) ) - ((COALESCE(
										t_booking_air_fare.plb_amount_retain,0) 
										* COALESCE(t_booking_air.
										selling_cons_exc_rt,0)) + (COALESCE(
										t_booking_air_fare.
										overriding_comm_amt_retain_supp_currr,0) 
										* COALESCE(t_booking_air_fare.
										suppliertoadminexcgrate)) ) )::NUMERIC,0
										)AS VARCHAR) 
									FROM
										t_booking_air_fare 
									WHERE
										t_booking_air_fare.trans_air_xid=
										t_booking_air.trans_air_pid AND
										t_booking_air_fare .trans_xid =t_booking
										.trans_pid AND
										t_booking_air_fare.trans_pnr_xid=
										t_booking_air_pnr.trans_pnr_pid AND
										t_booking_air_fare.air_pax_xid=
										t_booking_air_pax.air_pax_pid 
				)
				WHEN (	SELECT
							LENGTH(CAST(trunc(round(SUM ((((COALESCE( 
							t_booking_air_fare.base_fare,0)) -((COALESCE( 
							t_booking_air_fare.plb_amount_retain,0)) +(COALESCE( 
							t_booking_air_fare.overriding_comm_amt_retain,0)))) 
							* COALESCE(t_booking_air.selling_cons_exc_rt,0))):: 
							NUMERIC,0))AS VARCHAR)) 
						FROM
							t_booking_air_fare 
						WHERE
							t_booking_air_fare.trans_air_xid=t_booking_air.
							trans_air_pid AND
							t_booking_air_fare .trans_xid =t_booking.trans_pid 
							AND
							t_booking_air_fare.trans_pnr_xid=t_booking_air_pnr.
							trans_pnr_pid AND
							t_booking_air_fare.air_pax_xid=t_booking_air_pax.
							air_pax_pid 
				)
				=3 
				THEN 'M'||'00'|| (	SELECT
										CAST(round(SUM((COALESCE(
										t_booking_air_fare.base_fare_supp_curr,0
										) * COALESCE(t_booking_air_fare.
										suppliertoadminexcgrate) ) - ((COALESCE(
										t_booking_air_fare.plb_amount_retain,0) 
										* COALESCE(t_booking_air.
										selling_cons_exc_rt,0)) + (COALESCE(
										t_booking_air_fare.
										overriding_comm_amt_retain_supp_currr,0) 
										* COALESCE(t_booking_air_fare.
										suppliertoadminexcgrate)) ) )::NUMERIC,0
										)AS VARCHAR) 
									FROM
										t_booking_air_fare 
									WHERE
										t_booking_air_fare.trans_air_xid=
										t_booking_air.trans_air_pid AND
										t_booking_air_fare .trans_xid =t_booking
										.trans_pid AND
										t_booking_air_fare.trans_pnr_xid=
										t_booking_air_pnr.trans_pnr_pid AND
										t_booking_air_fare.air_pax_xid=
										t_booking_air_pax.air_pax_pid 
				)
				WHEN (	SELECT
							LENGTH(CAST(trunc(round(SUM ((((COALESCE( 
							t_booking_air_fare.base_fare,0)) -((COALESCE( 
							t_booking_air_fare.plb_amount_retain,0)) +(COALESCE( 
							t_booking_air_fare.overriding_comm_amt_retain,0)))) 
							* COALESCE(t_booking_air.selling_cons_exc_rt,0))):: 
							NUMERIC,0))AS VARCHAR)) 
						FROM
							t_booking_air_fare 
						WHERE
							t_booking_air_fare.trans_air_xid=t_booking_air.
							trans_air_pid AND
							t_booking_air_fare .trans_xid =t_booking.trans_pid 
							AND
							t_booking_air_fare.trans_pnr_xid=t_booking_air_pnr.
							trans_pnr_pid AND
							t_booking_air_fare.air_pax_xid=t_booking_air_pax.
							air_pax_pid 
				)
				=4 
				THEN 'M'||'0'|| (	SELECT
										CAST(round(SUM((COALESCE(
										t_booking_air_fare.base_fare_supp_curr,0
										) * COALESCE(t_booking_air_fare.
										suppliertoadminexcgrate) ) - ((COALESCE(
										t_booking_air_fare.plb_amount_retain,0) 
										* COALESCE(t_booking_air.
										selling_cons_exc_rt,0)) + (COALESCE(
										t_booking_air_fare.
										overriding_comm_amt_retain_supp_currr,0) 
										* COALESCE(t_booking_air_fare.
										suppliertoadminexcgrate)) ) )::NUMERIC,0
										)AS VARCHAR) 
									FROM
										t_booking_air_fare 
									WHERE
										t_booking_air_fare.trans_air_xid=
										t_booking_air.trans_air_pid AND
										t_booking_air_fare .trans_xid =t_booking
										.trans_pid AND
										t_booking_air_fare.trans_pnr_xid=
										t_booking_air_pnr.trans_pnr_pid AND
										t_booking_air_fare.air_pax_xid=
										t_booking_air_pax.air_pax_pid 
				)
				ELSE 'M'|| (SELECT
								CAST(round(SUM((COALESCE(t_booking_air_fare.
								base_fare_supp_curr,0) * COALESCE(
								t_booking_air_fare.suppliertoadminexcgrate) ) - 
								((COALESCE(t_booking_air_fare.plb_amount_retain,
								0) * COALESCE(t_booking_air.selling_cons_exc_rt,
								0)) + (COALESCE(t_booking_air_fare.
								overriding_comm_amt_retain_supp_currr,0) * 
								COALESCE(t_booking_air_fare.
								suppliertoadminexcgrate)) ) )::NUMERIC,0)AS 
								VARCHAR) 
							FROM
								t_booking_air_fare 
							WHERE
								t_booking_air_fare.trans_air_xid=t_booking_air.
								trans_air_pid AND
								t_booking_air_fare .trans_xid =t_booking.
								trans_pid AND
								t_booking_air_fare.trans_pnr_xid=
								t_booking_air_pnr.trans_pnr_pid AND
								t_booking_air_fare.air_pax_xid=t_booking_air_pax
								.air_pax_pid 
				)
			END 
			ELSE 
			CASE 
				WHEN (	SELECT
							LENGTH(CAST(trunc(round(SUM ((((COALESCE( 
							t_booking_air_fare.base_fare,0)) -((COALESCE( 
							t_booking_air_fare.plb_amount_retain,0)) +(COALESCE( 
							t_booking_air_fare.overriding_comm_amt_retain,0)))) 
							* COALESCE(t_booking_air.selling_cons_exc_rt,0))):: 
							NUMERIC,0))AS VARCHAR)) 
						FROM
							t_booking_air_fare 
						WHERE
							t_booking_air_fare.trans_air_xid=t_booking_air.
							trans_air_pid AND
							t_booking_air_fare .trans_xid =t_booking.trans_pid 
							AND
							t_booking_air_fare.trans_pnr_xid=t_booking_air_pnr.
							trans_pnr_pid AND
							t_booking_air_fare.air_pax_xid=t_booking_air_pax.
							air_pax_pid 
				)
				=1 
				THEN 'D'||'0000'|| (SELECT
										CAST(round(SUM((COALESCE(
										t_booking_air_fare.base_fare_supp_curr,0
										) * COALESCE(t_booking_air_fare.
										suppliertoadminexcgrate) ) - ((COALESCE(
										t_booking_air_fare.plb_amount_retain,0) 
										* COALESCE(t_booking_air.
										selling_cons_exc_rt,0)) + (COALESCE(
										t_booking_air_fare.
										overriding_comm_amt_retain_supp_currr,0) 
										* COALESCE(t_booking_air_fare.
										suppliertoadminexcgrate)) ) )::NUMERIC,0
										)AS VARCHAR) 
									FROM
										t_booking_air_fare 
									WHERE
										t_booking_air_fare.trans_air_xid=
										t_booking_air.trans_air_pid AND
										t_booking_air_fare .trans_xid =t_booking
										.trans_pid AND
										t_booking_air_fare.trans_pnr_xid=
										t_booking_air_pnr.trans_pnr_pid AND
										t_booking_air_fare.air_pax_xid=
										t_booking_air_pax.air_pax_pid 
				)
				WHEN (	SELECT
							LENGTH(CAST(trunc(round(SUM ((((COALESCE( 
							t_booking_air_fare.base_fare,0)) -((COALESCE( 
							t_booking_air_fare.plb_amount_retain,0)) +(COALESCE( 
							t_booking_air_fare.overriding_comm_amt_retain,0)))) 
							* COALESCE(t_booking_air.selling_cons_exc_rt,0))):: 
							NUMERIC,0))AS VARCHAR)) 
						FROM
							t_booking_air_fare 
						WHERE
							t_booking_air_fare.trans_air_xid=t_booking_air.
							trans_air_pid AND
							t_booking_air_fare .trans_xid =t_booking.trans_pid 
							AND
							t_booking_air_fare.trans_pnr_xid=t_booking_air_pnr.
							trans_pnr_pid AND
							t_booking_air_fare.air_pax_xid=t_booking_air_pax.
							air_pax_pid 
				)
				=2 
				THEN 'D'||'000'|| (	SELECT
										CAST(round(SUM((COALESCE(
										t_booking_air_fare.base_fare_supp_curr,0
										) * COALESCE(t_booking_air_fare.
										suppliertoadminexcgrate) ) - ((COALESCE(
										t_booking_air_fare.plb_amount_retain,0) 
										* COALESCE(t_booking_air.
										selling_cons_exc_rt,0)) + (COALESCE(
										t_booking_air_fare.
										overriding_comm_amt_retain_supp_currr,0) 
										* COALESCE(t_booking_air_fare.
										suppliertoadminexcgrate)) ) )::NUMERIC,0
										)AS VARCHAR) 
									FROM
										t_booking_air_fare 
									WHERE
										t_booking_air_fare.trans_air_xid=
										t_booking_air.trans_air_pid AND
										t_booking_air_fare .trans_xid =t_booking
										.trans_pid AND
										t_booking_air_fare.trans_pnr_xid=
										t_booking_air_pnr.trans_pnr_pid AND
										t_booking_air_fare.air_pax_xid=
										t_booking_air_pax.air_pax_pid 
				)
				WHEN (	SELECT
							LENGTH(CAST(trunc(round(SUM ((((COALESCE( 
							t_booking_air_fare.base_fare,0)) -((COALESCE( 
							t_booking_air_fare.plb_amount_retain,0)) +(COALESCE( 
							t_booking_air_fare.overriding_comm_amt_retain,0)))) 
							* COALESCE(t_booking_air.selling_cons_exc_rt,0))):: 
							NUMERIC,0))AS VARCHAR)) 
						FROM
							t_booking_air_fare 
						WHERE
							t_booking_air_fare.trans_air_xid=t_booking_air.
							trans_air_pid AND
							t_booking_air_fare .trans_xid =t_booking.trans_pid 
							AND
							t_booking_air_fare.trans_pnr_xid=t_booking_air_pnr.
							trans_pnr_pid AND
							t_booking_air_fare.air_pax_xid=t_booking_air_pax.
							air_pax_pid 
				)
				=3 
				THEN 'D'||'00'|| (	SELECT
										CAST(round(SUM((COALESCE(
										t_booking_air_fare.base_fare_supp_curr,0
										) * COALESCE(t_booking_air_fare.
										suppliertoadminexcgrate) ) - ((COALESCE(
										t_booking_air_fare.plb_amount_retain,0) 
										* COALESCE(t_booking_air.
										selling_cons_exc_rt,0)) + (COALESCE(
										t_booking_air_fare.
										overriding_comm_amt_retain_supp_currr,0) 
										* COALESCE(t_booking_air_fare.
										suppliertoadminexcgrate)) ) )::NUMERIC,0
										)AS VARCHAR) 
									FROM
										t_booking_air_fare 
									WHERE
										t_booking_air_fare.trans_air_xid=
										t_booking_air.trans_air_pid AND
										t_booking_air_fare .trans_xid =t_booking
										.trans_pid AND
										t_booking_air_fare.trans_pnr_xid=
										t_booking_air_pnr.trans_pnr_pid AND
										t_booking_air_fare.air_pax_xid=
										t_booking_air_pax.air_pax_pid 
				)
				WHEN (	SELECT
							LENGTH(CAST(trunc(round(SUM ((((COALESCE( 
							t_booking_air_fare.base_fare,0)) -((COALESCE( 
							t_booking_air_fare.plb_amount_retain,0)) +(COALESCE( 
							t_booking_air_fare.overriding_comm_amt_retain,0)))) 
							* COALESCE(t_booking_air.selling_cons_exc_rt,0))):: 
							NUMERIC,0))AS VARCHAR)) 
						FROM
							t_booking_air_fare 
						WHERE
							t_booking_air_fare.trans_air_xid=t_booking_air.
							trans_air_pid AND
							t_booking_air_fare .trans_xid =t_booking.trans_pid 
							AND
							t_booking_air_fare.trans_pnr_xid=t_booking_air_pnr.
							trans_pnr_pid AND
							t_booking_air_fare.air_pax_xid=t_booking_air_pax.
							air_pax_pid 
				)
				=4 
				THEN 'D'||'0'|| (	SELECT
										CAST(round(SUM((COALESCE(
										t_booking_air_fare.base_fare_supp_curr,0
										) * COALESCE(t_booking_air_fare.
										suppliertoadminexcgrate) ) - ((COALESCE(
										t_booking_air_fare.plb_amount_retain,0) 
										* COALESCE(t_booking_air.
										selling_cons_exc_rt,0)) + (COALESCE(
										t_booking_air_fare.
										overriding_comm_amt_retain_supp_currr,0) 
										* COALESCE(t_booking_air_fare.
										suppliertoadminexcgrate)) ) )::NUMERIC,0
										)AS VARCHAR) 
									FROM
										t_booking_air_fare 
									WHERE
										t_booking_air_fare.trans_air_xid=
										t_booking_air.trans_air_pid AND
										t_booking_air_fare .trans_xid =t_booking
										.trans_pid AND
										t_booking_air_fare.trans_pnr_xid=
										t_booking_air_pnr.trans_pnr_pid AND
										t_booking_air_fare.air_pax_xid=
										t_booking_air_pax.air_pax_pid 
				)
				ELSE 'D'|| (SELECT
								CAST(round(SUM((COALESCE(t_booking_air_fare.
								base_fare_supp_curr,0) * COALESCE(
								t_booking_air_fare.suppliertoadminexcgrate) ) - 
								((COALESCE(t_booking_air_fare.plb_amount_retain,
								0) * COALESCE(t_booking_air.selling_cons_exc_rt,
								0)) + (COALESCE(t_booking_air_fare.
								overriding_comm_amt_retain_supp_currr,0) * 
								COALESCE(t_booking_air_fare.
								suppliertoadminexcgrate)) ) )::NUMERIC,0)AS 
								VARCHAR) 
							FROM
								t_booking_air_fare 
							WHERE
								t_booking_air_fare.trans_air_xid=t_booking_air.
								trans_air_pid AND
								t_booking_air_fare .trans_xid =t_booking.
								trans_pid AND
								t_booking_air_fare.trans_pnr_xid=
								t_booking_air_pnr.trans_pnr_pid AND
								t_booking_air_fare.air_pax_xid=t_booking_air_pax
								.air_pax_pid 
				)
			END 
		END 
		ELSE 
		CASE 
			WHEN SUBSTRING(t_booking_air_fare.value_code,1,1)='Q' 
			THEN 'M'||SUBSTRING(t_booking_air_fare.value_code,2,LENGTH( 
			t_booking_air_fare.value_code)-1) 
			ELSE TRIM(t_booking_air_fare.value_code) 
		END 
	END                                                                                 
	AS ValueCd,
	'AED'                                                                           
	AS PurrCurrCd,
	100                                                                             
	AS PurRate,
	0                                                                               
	AS PurAmount,
	CASE 
		WHEN t_booking_air.is_lcc='Y' 
		THEN (	SELECT
					vendor_number 
				FROM
					m_document_master 
				WHERE
					t_booking_air.doc_code=m_document_master.doc_code 
		)
		ELSE '' 
	END                                                                                 
	AS AccNo,
	TRIM(t_booking.booking_no)                                                      
	AS VendInvoNo,
	NULL                                                                            
	AS FopAmt2,
	TRIM(t_booking_air_pnr.gds_pnr)                                                 
	AS PNRno,
case when TRIM(t_booking_air_fare.tour_code) ilike '%*%' then 
case when TRIM(t_booking_air_fare.tour_code) like '%\/%' then 
substring (TRIM(t_booking_air_fare.tour_code), 
length(TRIM(t_booking_air_fare.tour_code)) - position('*' in reverse_string(TRIM(t_booking_air_fare.tour_code))) + 2,
position('/' in (TRIM(t_booking_air_fare.tour_code))) - (length(TRIM(t_booking_air_fare.tour_code)) - position('*' in reverse_string(TRIM(t_booking_air_fare.tour_code))) + 2))
else substring (TRIM(t_booking_air_fare.tour_code),
length(TRIM(t_booking_air_fare.tour_code)) - position('*' in reverse_string(TRIM(t_booking_air_fare.tour_code))) + 2,length(TRIM(t_booking_air_fare.tour_code)))
end
else TRIM(t_booking_air_fare.tour_code) end                                              
	AS tourcd,
	t_booking_document.document_dt                                                  
	AS VendorInvoiceDate,
	(	SELECT
			crs_id 
		FROM
			m_supplier 
		WHERE
			m_supplier.supplier_pid=t_booking_air.supplier_xid 
	)
	AS crs_pnr_no,
	0                                                                               
	AS savamount,
	TRIM(t_booking_air_pnr.gds_pnr)                                                 
	AS dsr_remarks,
	''                                                                              
	AS servicename,
	''                                                                              
	AS servicecategory,
	NULL                                                                            
	AS checkindate,
	NULL                                                                            
	AS checkoutdate,
	''                                                                              
	AS servicecity,
	''                                                                              
	AS remarks,
	(	SELECT
			TRIM(cost_center_code) 
		FROM
			m_cost_center 
		WHERE
			cost_center_pid=t_booking_air_pax.cost_center_xid 
	)
	AS costcenterno,
	TRIM(t_booking_air_pax.country)                                                 
	AS visacountry,
	NULL                                                                            
	AS rbdeposit,
	NULL                                                                            
	AS rbdeposit2,
	(	SELECT
			SUM(COALESCE(t_booking_air_fare.trans_fee_cons_curr,2)) 
		FROM
			t_booking_air_fare 
		WHERE
			t_booking_air_fare.trans_air_xid=t_booking_air.trans_air_pid AND
			t_booking_air_fare .trans_xid =t_booking.trans_pid AND
			t_booking_air_fare.trans_pnr_xid=t_booking_air_pnr.trans_pnr_pid AND
			t_booking_air_fare.air_pax_xid=t_booking_air_pax.air_pax_pid 
	)
	AS Transfee,
	0                                                                               
	AS transfeed,
	NULL                                                                            
	AS transfee2,
	NULL                                                                            
	AS transfeed2,
	''                                                                              
	AS ca,
	TRIM(t_booking_air.primary_carrier)                                             
	AS airlcd,
	TRIM(fmcity_xid)                                                                
	AS frmdestcd,
	TRIM(tocity_xid)                                                                
	AS todestcd,
	CASE 
		WHEN (LENGTH(t_booking_air_pax.first_name)+LENGTH(t_booking_air_pax. 
		last_name)+LENGTH(t_booking_air_pax.title)) >38 
		THEN COALESCE(SUBSTRING (TRIM(t_booking_air_pax.last_name),1,17) ,'')|| 
		' ' ||COALESCE(SUBSTRING (TRIM(t_booking_air_pax.first_name),1,16) ,'') 
		||' ' ||COALESCE(SUBSTRING (TRIM(t_booking_air_pax.title),1,7) ,'') 
		ELSE COALESCE(TRIM(t_booking_air_pax.last_name),'') ||' ' || COALESCE ( 
		TRIM(t_booking_air_pax.first_name),'') || ' ' ||COALESCE(TRIM( 
		t_booking_air_pax.title),'') 
	END                                                                                 
	AS TrvName,
	''                                                                              
	AS isi,
	(	SELECT
			'AED'||''||round(tax::NUMERIC,2)||''|| TRIM(tax_info) 
		FROM
			(	SELECT
					SUM ((tax))             AS tax ,
					tax_info,
					row_number() over () AS row_no 
				FROM
					t_booking_air_fare_tax 
				WHERE
					t_booking_air_fare_tax.pax_fare_xid=t_booking_air_fare.
					pax_fare_pid AND
					t_booking_air_fare_tax .trans_pnr_xid =t_booking.trans_pid 
				GROUP BY
					tax_info 
			)
			t 
		WHERE
			row_no=1 
	)
	AS taxprint1,
	(	SELECT
			'AED'||''||round(tax::NUMERIC,2)||''|| TRIM(tax_info) 
		FROM
			(	SELECT
					SUM ((tax))             AS tax,
					tax_info,
					row_number() over () AS row_no 
				FROM
					t_booking_air_fare_tax 
				WHERE
					t_booking_air_fare_tax.pax_fare_xid=t_booking_air_fare.
					pax_fare_pid AND
					t_booking_air_fare_tax .trans_pnr_xid =t_booking.trans_pid 
				GROUP BY
					tax_info 
			)
			t 
		WHERE
			row_no =2 
	)
	AS taxprint2,
	(	SELECT
			'AED'||''||round(SUM (tax)::NUMERIC,0)||'' ||'XT' 
		FROM
			(	SELECT
					SUM ((tax))             AS tax ,
					tax_info,
					row_number() over () AS row_no 
				FROM
					t_booking_air_fare_tax 
				WHERE
					t_booking_air_fare_tax.pax_fare_xid=t_booking_air_fare.
					pax_fare_pid AND
					t_booking_air_fare_tax .trans_pnr_xid =t_booking.trans_pid 
				GROUP BY
					tax_info 
			)
			t 
		WHERE
			row_no >2 
	)
	AS taxprint3,
	''                                                                              
	AS excarrcd,
	''                                                                              
	AS exdocno,
	''                                                                              
	AS exserno,
	''                                                                              
	AS exconj,
	'DIRECT/1L'                                                                     
	AS bookingno,
	TRIM(CAST (t_booking_air_fare.fare_calculation AS VARCHAR))                     
	AS fc ,
	array_to_string(ARRAY(	SELECT
								TRIM(tax_info) ||'(' || round( SUM((
								tax))::NUMERIC,2)||')' 
							FROM
								t_booking_air_fare_tax 
							WHERE
								t_booking_air_fare_tax.pax_fare_xid=
								t_booking_air_fare.pax_fare_pid AND
								t_booking_air_fare_tax .trans_pnr_xid =t_booking
								.trans_pid 
							GROUP BY
								tax_info ) ,',')                                                   
	AS tax ,
	TRIM(fm_iata_xid)||'-'|| TRIM(to_iata_xid)                                      
	AS sector,
    CASE WHEN TRIM(t_booking_air_sector.status_code) = 'AA'
    THEN 'HK'
	ELSE TRIM(t_booking_air_sector.status_code) END                                          
	AS stcd,
	TRIM(t_booking_air_sector.fare_basis)                                           
	AS fbno,
	TRIM(t_booking_air.primary_carrier)                                             
	AS carrcd,
	TRIM(flight_no)                                                                 
	AS flightno,
		substring(TRIM(booking_class),1,1)                                                                                          
	AS classcd,
	dep_date                                                                        
	AS depdate,
	dep_time                                                                        
	AS deptime,
	arr_date                                                                        
	AS arrdate,
	arr_time                                                                        
	AS arrtime,
	CASE 
	WHEN TRIM(t_booking_air_sector_pax_dtl.baggage_allowance) IN ('NIN','-NA-')
    THEN 'NIL'
    ELSE LEFT(TRIM(t_booking_air_sector_pax_dtl.baggage_allowance),3) END                          
	AS allow,
	t_booking_air_sector_pax_dtl.not_valid_before                                   
	AS nvb,
	t_booking_air_sector_pax_dtl.not_valid_after                                    
	AS nva,
	TRIM(t_booking_air_sector.airline_xid)                                          
	AS operbycarrcode,
	TRIM(t_booking_air_sector.code_share_flight)                                    
	AS opercarrcd,
	TRIM(flight_no)                                                                 
	AS operflight,
	TRIM(t_booking_air_pax.mealpref)                                                
	AS meal,
	'0'                                                                             
	AS nostop,
	TRIM(t_booking_air_sector.duration)                                             
	AS journeytime,
	TRIM(t_booking_air_sector.equipment_type)                                       
	AS equipmenttype,
	CASE 
		WHEN t_booking_air.is_lcc='N' 
		THEN TRIM(t_booking_air_sector_pax_dtl.tkt_no) 
		ELSE '' 
	END                                                                                 
	AS serno,
	CASE 
		WHEN (LENGTH(t_booking_air_pax.first_name)+LENGTH(t_booking_air_pax. 
		last_name)+LENGTH(t_booking_air_pax.title)) >38 
		THEN COALESCE(SUBSTRING (TRIM(t_booking_air_pax.last_name),1,17) ,'')|| 
		' ' ||COALESCE(SUBSTRING (TRIM(t_booking_air_pax.first_name),1,16) ,'') 
		||' ' ||COALESCE(SUBSTRING (TRIM(t_booking_air_pax.title),1,7) ,'') 
		ELSE COALESCE(TRIM(t_booking_air_pax.last_name),'') ||' ' || COALESCE ( 
		TRIM(t_booking_air_pax.first_name),'') || ' ' ||COALESCE(TRIM( 
		t_booking_air_pax.title),'') 
	END                                                                                 
	AS TrvName,
	''                                                                              
	AS admcd,
	(	SELECT
			COALESCE(TRIM(reference_number),'') 
		FROM
			m_traveller 
		WHERE
			traveller_pid =t_booking_air_pax.traveller_xid 
	)
	AS empno,
	(	SELECT
			TRIM(project_code) 
		FROM
			m_project 
		WHERE
			project_pid=t_booking_air_pax.project_xid 
	)
	AS projno,
	    case when t_booking_document_dtl.fop_name = 'CC-CPG'
    THEN t_booking_document_dtl.ordercode
    else
	TRIM(CAST(COALESCE (t_booking_air_pax.traveller_xid,dependent_xid)  AS 
	VARCHAR)) end AS reqno,
	NULL                                                                            
	AS costcenter,
	NULL                                                                            
	AS fareid,
	NULL                                                                            
	AS farequoteid,
	NULL                                                                            
	AS dbinfo,
	NULL                                                                            
	AS dbinfocardtype ,
	TRIM(is_miscellaneous)                                                          
	AS is_miscellaneous,
	NULL,
	NULL,
	NULL,
	NULL,
	NULL,
	NULL,
	is_lcc_ancillary                                                                
	AS is_lcc_ancillary ,
	t_booking_air.is_lcc                                                            
	AS is_lcc ,protas_order_no,
    t_booking_document_dtl.fop_type,
    credit_card_no,
    CASE 
    WHEN approved_key ILIKE '%/%'
    THEN left(approved_key, strpos(approved_key, '/') - 1)
    ELSE
    approved_key
    END,case when TRIM(t_booking_air.tour_code) ilike '%*%' then 
case when TRIM(t_booking_air.tour_code) like '%\/%' then 
substring (TRIM(t_booking_air.tour_code), 
length(TRIM(t_booking_air.tour_code)) - position('*' in reverse_string(TRIM(t_booking_air.tour_code))) + 2,
position('/' in (TRIM(t_booking_air.tour_code))) - (length(TRIM(t_booking_air.tour_code)) - position('*' in reverse_string(TRIM(t_booking_air.tour_code))) + 2))
else substring (TRIM(t_booking_air_fare.tour_code),
length(TRIM(t_booking_air.tour_code)) - position('*' in reverse_string(TRIM(t_booking_air.tour_code))) + 2,length(TRIM(t_booking_air.tour_code)))
end
else TRIM(t_booking_air.tour_code) end  ,
	'eTravel',
	(total_markup+t_booking_air.adhoc_markup_sell_curr),
CASE WHEN (select upper(country) from m_iata where iata_pid=tocity_xid)<>upper('BAHRAIN')then	'VX' 
else
		case	WHEN (	SELECT
						country_code 
					FROM
						m_country 
					WHERE
						UPPER(country_name) =(	SELECT
													UPPER(country) 
												FROM
													m_supplier 
												WHERE
													supplier_pid=t_booking_air.supplier_xid
						)
			)
			='BH' 
			THEN 'V5' else 'V0' end 
		END  ,	(	SELECT
			round(SUM( ((COALESCE(t_booking_air_fare.base_fare_supp_curr,0)) * 
			COALESCE(t_booking_air_fare. suppliertoadminexcgrate,0)) +COALESCE(
			t_booking_air_fare.markup_cons_curr,0) + (t_booking_air_fare.
			adhoc_markup_cons_curr))::NUMERIC, 2) 
		FROM
			t_booking_air_fare 
		WHERE
			t_booking_air_fare.trans_air_xid=t_booking_air.trans_air_pid AND
			t_booking_air_fare .trans_xid =t_booking.trans_pid AND
			t_booking_air_fare.trans_pnr_xid=t_booking_air_pnr.trans_pnr_pid AND
			t_booking_air_fare.air_pax_xid=t_booking_air_pax.air_pax_pid 
	),
	(	SELECT
			round(SUM( ((COALESCE(t_booking_air_fare.base_fare_supp_curr,0)) * 
			COALESCE(t_booking_air_fare. suppliertoadminexcgrate,0)) +COALESCE(
			t_booking_air_fare.markup_cons_curr,0) + (t_booking_air_fare.
			adhoc_markup_cons_curr))::NUMERIC, 2) 
		FROM
			t_booking_air_fare 
		WHERE
			t_booking_air_fare.trans_air_xid=t_booking_air.trans_air_pid AND
			t_booking_air_fare .trans_xid =t_booking.trans_pid AND
			t_booking_air_fare.trans_pnr_xid=t_booking_air_pnr.trans_pnr_pid AND
			t_booking_air_fare.air_pax_xid=t_booking_air_pax.air_pax_pid 
	),
	0,
	case when (select upper(country) from m_iata where iata_pid=tocity_xid)=upper('BAHRAIN')then	'V0' else 'VX' end,
	0,
	0,
CASE WHEN (select upper(country) from m_iata where iata_pid=tocity_xid)<>upper('BAHRAIN')then	'VX' 
else
		case	WHEN (	SELECT
						country_code 
					FROM
						m_country 
					WHERE
						UPPER(country_name) =(	SELECT
													UPPER(country) 
												FROM
													m_supplier 
												WHERE
													supplier_pid=t_booking_air.supplier_xid
						)
			)
			='BH' 
			THEN 'V5' else 'V0' end 
		END  ,	0,
	'',
	0,
	'',
	0,
	'Service',
	to_char(t_booking_air.travel_dt::DATE,'dd-Mon-yyyy'),
	'',
	(	SELECT
			TRIM(country_code) 
		FROM
			m_country 
		WHERE
			UPPER(country_name) =(	SELECT
										UPPER(country) 
									FROM
										m_supplier 
									WHERE
										supplier_pid=t_booking_air.supplier_xid
			)
	)
	,
	(	SELECT
			TRIM(country_code) 
		FROM
			m_country 
		WHERE
			UPPER(country_name) =(	SELECT
										UPPER(country) 
									FROM
										m_client 
									WHERE
										client_pid=t_booking.client_xid
			)
	)
	,
	(	SELECT
			vat_registration_no 
		FROM
			m_client 
		WHERE
			client_pid=t_booking.client_xid
	)
	,
	'',
	'',is_pnr_sync_only,supplier_pid,protas_hit_count
FROM
	t_booking 
		JOIN t_booking_air 
		ON (trans_pid=t_booking_air.trans_xid AND
		trans_air_pid IN (	SELECT
								MIN(trans_air_xid) 
							FROM
								t_booking_air_pnr 
							WHERE
								trans_xid=t_booking.trans_pid 
							GROUP BY
								gds_pnr,
								trans_xid
		)
		) 	
			JOIN t_booking_air_pax 
			ON (trans_air_pid=t_booking_air_pax.trans_air_xid AND
			t_booking_air_pax.air_pax_pid IN (	SELECT
													MIN(COALESCE(air_pax_pid)) 
												FROM
													t_booking_air_pax 
												WHERE
													trans_xid=t_booking.
													trans_pid 
												GROUP BY
													trans_air_xid 
			)
			) 	
				JOIN t_booking_document 
				ON(t_booking_document.trans_xid = t_booking.trans_pid AND
				(string_to_array(selected_travelers_ids,',')@>string_to_array( 
				'T-'||traveller_xid,',')) OR
				(string_to_array(selected_travelers_ids,',')@>string_to_array( 
				'D-'||dependent_xid,','))) 
					JOIN t_booking_document_dtl 
					ON (t_booking_document_dtl.trans_doc_xid = 
					t_booking_document.trans_doc_pid AND
					trans_prod_xid = trans_air_pid AND
					(t_booking_document_dtl.air_pax_xid = air_pax_pid OR
					t_booking_document_dtl.air_pax_xid IS NULL)) 
						JOIN m_client 
						ON (client_pid=t_booking.client_xid) 
							JOIN t_booking_air_sector 
							ON (t_booking.trans_pid=t_booking_air_sector. 
							trans_xid AND
							t_booking_air.trans_air_pid=t_booking_air_sector. 
							trans_air_xid) 
								JOIN t_booking_air_sector_pax_dtl 
								ON (t_booking_air.trans_air_pid= 
								t_booking_air_sector_pax_dtl.trans_air_xid AND
								t_booking_air_pax.air_pax_pid= 
								t_booking_air_sector_pax_dtl.air_pax_xid AND
								t_booking_air_sector.air_leg_pid= 
								t_booking_air_sector_pax_dtl.air_leg_xid AND
								t_booking.trans_pid=t_booking_air_sector_pax_dtl 
								.trans_xid ) 
									JOIN t_booking_air_fare 
									ON (t_booking.trans_pid=t_booking_air_fare. 
									trans_xid AND
									t_booking_air.trans_air_pid= 
									t_booking_air_fare.trans_air_xid AND
									t_booking_air_pax.air_pax_pid= 
									t_booking_air_fare.air_pax_xid) 
										JOIN m_supplier 
										ON (t_booking_air.supplier_xid = 
										m_supplier.supplier_pid) 
											JOIN m_login_user 
											ON (login_user_pid=t_booking. 
											employee_xid) 
												JOIN t_booking_air_pnr 
												ON (trans_pid=t_booking_air_pnr. 
												trans_xid AND
												trans_air_pid=t_booking_air_pnr. 
												trans_air_xid) 
													LEFT JOIN 
													t_booking_air_reissue_ticket 
													ON (trans_pid= 
													t_booking_air_reissue_ticket 
													.trans_xid AND
													trans_air_pid= 
													t_booking_air_reissue_ticket 
													.trans_air_xid) 
WHERE
	document_no = ls_invoice_no AND
            (SELECT count(total_tax_supp_curr) FROM t_booking_air_fare 
where trans_xid=(SELECT trans_xid FROM t_booking_document WHERE document_no=ls_invoice_no) and total_tax_supp_curr is not null)=((SELECT count(*) FROM t_booking_air_fare where trans_xid=(SELECT trans_xid FROM t_booking_document WHERE document_no=ls_invoice_no))) AND
	doc_type='I' AND
	t_booking_air.is_lcc='Y' AND
	t_booking_air.is_miscellaneous='Y' and is_invoice_blocked= 'N'
ORDER BY
	leg_pax_pid LOOP RETURN NEXT res; 
END
	LOOP; 

 EXCEPTION
     WHEN OTHERS THEN 
      RAISE WARNING '[usp_get_invoice_dtl] - UDF ERROR [OTHER] - SQLSTATE: %, SQLERRM: %',SQLSTATE,SQLERRM;
      Insert into exception_details values(current_query(),'usp_get_invoice_dtl(ls_invoice_no)'||' '||sqlerrm,now());


RETURN; 
END
	; $BODY$
LANGUAGE 'plpgsql'
GO
