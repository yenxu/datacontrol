--liquibase formatted sql
--changeset Yen:createDataControlRules splitStatements:false runAlways:true
DECLARE
  PROCEDURE add_rule(
      i_domain          data_control_rule.domain%TYPE
    , i_tag1            data_control_rule.tag1%TYPE
    , i_tag2            data_control_rule.tag2%TYPE
    , i_op              data_control_rule.comparison_operator%TYPE
    , i_description     data_control_rule.description%TYPE
    , i_result_text     data_control_rule.RESULT_TEXT%TYPE
    , i_code            data_control_rule.code%TYPE
    , i_status_level    data_control_rule.status_level%TYPE DEFAULT 'ERROR'
    , i_has_error_page  data_control_rule.has_error_page%TYPE DEFAULT 0
    , i_error_page_view data_control_rule.error_page_view%TYPE DEFAULT NULL
  ) IS
    BEGIN
      MERGE INTO data_control_rule dcr
      USING (
              SELECT i_domain          AS domain
                ,    i_tag1            AS tag1
                ,    i_tag2            AS tag2
                ,    i_op              AS comparison_operator
                ,    i_description     AS description
                ,    i_result_text     AS result_text
                ,    i_status_level    AS status_level
                ,    i_has_error_page  AS has_error_page
                ,    i_error_page_view AS error_page_view
                ,    i_code            AS code

              FROM dual
            ) idc
      ON (idc.domain = dcr.domain AND idc.tag1 = dcr.tag1 AND (idc.tag2 is null and dcr.tag2 is null or idc.tag2 = dcr.tag2))
      WHEN MATCHED THEN UPDATE SET
        dcr.comparison_operator = idc.comparison_operator
        , dcr.description = idc.description
        , dcr.result_text = idc.result_text
        , dcr.status_level = idc.status_level
        , dcr.has_error_page = idc.has_error_page
        , dcr.code = idc.code
        , dcr.error_page_view = nvl(idc.error_page_view, dcr.error_page_view)
        , dcr.modified_date = sysdate
      WHEN NOT MATCHED THEN INSERT (
        dcr.sid
        , dcr.domain
        , dcr.tag1
        , dcr.tag2
        , dcr.comparison_operator
        , dcr.description
        , dcr.result_text
        , dcr.status_level
        , dcr.has_error_page
        , dcr.error_page_view
        , dcr.code
      ) VALUES (
        data_control_s.nextval
        , idc.domain
        , idc.tag1
        , idc.tag2
        , idc.comparison_operator
        , idc.description
        , idc.result_text
        , idc.status_level
        , idc.has_error_page
        , idc.error_page_view
        , idc.code
        );

      COMMIT;
      exception when others then
       raise_application_error(-20000,sqlerrm||'.Code = '||i_code||' Domain = '||i_domain||', tag1 = '||i_tag1||', tag2 = '||i_tag2);
    END;
  PROCEDURE train_rules IS
    train VARCHAR2(100) := 'TRAIN';

    BEGIN
      add_rule(i_code=>'1', i_domain=>TRAIN, i_tag1=>'RM_MINUS_RASK', i_tag2=>null, i_op=>'>0', i_description=>'Eksisterer det tog i RM som ikke fins i RASK?', i_result_text=>'Det er :1 tog i RM som ikke fins i RASK', i_status_level=>'ERROR', i_has_error_page=>0);
      add_rule(i_code=>'2', i_domain=>TRAIN, i_tag1=>'TIOS_MINUS_RASK', i_tag2=>null, i_op=>'>0', i_description=>'Eksisterer det tog i TIOS som ikke fins i RASK?', i_result_text=>'Det er :1 tog i TIOS (med både avgangs- og ankomststider) som ikke fins i RASK', i_status_level=>'ERROR', i_has_error_page=>0);
      add_rule(i_code=>'3', i_domain=>TRAIN, i_tag1=>'3NF', i_tag2=>'DIM', i_op=>'=', i_description=>'Antall tog i DIM == antall tog i 3NF', i_result_text=>'Det er :1 rader i 3NF og :2 rader i DIM', i_status_level=>'ERROR', i_has_error_page=>0);
      add_rule(i_code=>'4', i_domain=>TRAIN, i_tag1=>'RM', i_tag2=>'3NF_RM', i_op=>'=', i_description=>'Antall tog i 3NF importert fra TP == Antall tog i RM', i_result_text=>'Det er :1 rader i RM og :2 rader i 3NF fra RM', i_status_level=>'WARNING', i_has_error_page=>0);
      add_rule(i_code=>'5', i_domain=>TRAIN, i_tag1=>'TIOS', i_tag2=>'3NF_TIOS', i_op=>'=', i_description=>'Antall tog i 3NF importert fra TIOS == Antall tog i TIOS', i_result_text=>'Det er :1 rader i TIOS og :2 rader i 3NF fra TIOS', i_status_level=>'ERROR', i_has_error_page=>0);
      add_rule(i_code=>'6', i_domain=>TRAIN, i_tag1=>'3NF', i_tag2=>'FACT', i_op=>'=', i_description=>'Antall tog i FACT == antall tog i 3NF', i_result_text=>'Det er :1 rader i 3NF og :2 rader i FACT', i_status_level=>'ERROR', i_has_error_page=>0);
      add_rule(i_code=>'7', i_domain=>TRAIN, i_tag1=>'ACTUAL_KM_GREATER_THAN_PLANNED', i_tag2=>NULL, i_op=>'>0', i_description=>'Eksisterer det tog med faktisk km > planlagte', i_result_text=>'Det finnes :1 tog med faktisk km > planlagt', i_status_level=>'WARNING', i_has_error_page=>1
                            ,i_error_page_view=>'select t.train_id, t.nominal_date,  o.location_id ORIG_ID, d.location_id DEST_ID, tt.train_type_id, t.rm_planned_distance_km, t.planned_distance_km, t.actual_distance_km, t.modified_by
                from train t join location o ON o.sid = t.origin_sid JOIN location d ON d.sid = t.destination_sid
                  JOIN MASTER_TRAIN_NUMBER mtn on mtn.sid = t.sid
                  JOIN train_type tt ON tt.sid = mtn.train_type_sid
                where nvl(round(t.planned_distance_km),0) < nvl(round(t.actual_distance_km),0) and t.nominal_date=:nominalDate');
      add_rule(i_code=>'8', i_domain=>TRAIN, i_tag1=>'PT_WO_PRODUCT', i_tag2=>NULL, i_op=>'>0', i_description=>'Antall NSB/Gjøvik persontog i 3NF uten produktkode', i_result_text=>'Det finnes :1 tog i 3NF som mangler produktkode', i_status_level=>'ERROR', i_has_error_page=>1
             ,i_error_page_view=>'SELECT t.train_id, t.nominal_date, o.location_id ORIG_ID, o.name ORIG_NAME, d.location_id DEST_ID, d.name DEST_NAME,
                                   case when t.rm_external_id is not null then ''RM'' when t.tios_sid is not null then ''TIOS'' end source
                                  FROM train t JOIN master_train_number mtn on mtn.sid = t.sid AND mtn.product_sid = -1
                                    JOIN train_type tt ON tt.sid = mtn.train_type_sid AND tt.TRAIN_TYPE_ID IN (''Pt'', ''EPt'')
                                    JOIN train_number tn on tn.sid = t.sid
                                    JOIN train_category tc on tc.sid = tn.rm_train_category_sid and tc.train_category_id != ''Lx''
                                    JOIN owner ow ON mtn.owner_sid = ow.sid AND ow.owner_id IN (''NSB'', ''NG'')
                                    JOIN location o ON o.sid = t.origin_sid
                                    JOIN location d ON d.sid = t.destination_sid where t.nominal_date = :nominalDate and exists(select 1 from train_composition tc where tc.train_sid=t.sid)');
      add_rule(i_code=>'9', i_domain=>TRAIN, i_tag1=>'WO_DISTANCE', i_tag2=>NULL, i_op=>'>0', i_description=>'Eksisterer det tog (alle typer) med NULL/0 distanse km', i_result_text=>'Det finnes :1 tog som har distanse er 0 eller NULL', i_status_level=>'WARNING', i_has_error_page=>0);
      add_rule(i_code=>'10', i_domain=>TRAIN, i_tag1=>'SUM_ACTUAL_KM_3NF', i_tag2=>'SUM_ACTUAL_KM_DIM', i_op=>'=', i_description=>'Totalt antall faktiske km i DIM == totalt antall faktiske km i 3NF', i_result_text=>'Det er :1 faktiske km i 3NF og :2 faktiske km i DIM', i_status_level=>'ERROR', i_has_error_page=>0);
      add_rule(i_code=>'11', i_domain=>TRAIN, i_tag1=>'SUM_ACTUAL_KM_3NF_NSB_PT', i_tag2=>'SUM_ACTUAL_KM_DIM_NSB_PT', i_op=>'=', i_description=>'Totalt antall faktiske km i DIM == 3NF (NSB Pt)', i_result_text=>'Det er :1 faktiske km i 3NF og :2 faktiske km i DIM', i_status_level=>'ERROR', i_has_error_page=>0);
      add_rule(i_code=>'12', i_domain=>TRAIN, i_tag1=>'SUM_ACTUAL_KM_3NF_NSB_EPT', i_tag2=>'SUM_ACTUAL_KM_DIM_NSB_EPT', i_op=>'=', i_description=>'Totalt antall faktiske km i DIM == 3NF (NSB EPt)', i_result_text=>'Det er :1 faktiske km i 3NF og :2 faktiske km i DIM', i_status_level=>'ERROR', i_has_error_page=>0);
      add_rule(i_code=>'13', i_domain=>TRAIN, i_tag1=>'SUM_ACTUAL_KM_3NF_NSB_T', i_tag2=>'SUM_ACTUAL_KM_DIM_NSB_T', i_op=>'=', i_description=>'Totalt antall faktiske km i DIM == 3NF (NSB tomtog)', i_result_text=>'Det er :1 faktiske km i 3NF og :2 faktiske km i DIM', i_status_level=>'ERROR', i_has_error_page=>0);
      add_rule(i_code=>'14', i_domain=>TRAIN, i_tag1=>'SUM_ACTUAL_KM_3NF_NSB_ET', i_tag2=>'SUM_ACTUAL_KM_DIM_NSB_ET', i_op=>'=', i_description=>'Totalt antall faktiske km i DIM == 3NF (NSB ET)', i_result_text=>'Det er :1 faktiske km i 3NF og :2 faktiske km i DIM', i_status_level=>'ERROR', i_has_error_page=>0);
      add_rule(i_code=>'15', i_domain=>TRAIN, i_tag1=>'SUM_ACTUAL_KM_3NF_NG_PT', i_tag2=>'SUM_ACTUAL_KM_DIM_NG_PT', i_op=>'=', i_description=>'Totalt antall faktiske km i DIM == 3NF (Gjøvik Pt)', i_result_text=>'Det er :1 faktiske km i 3NF og :2 faktiske km i DIM', i_status_level=>'ERROR', i_has_error_page=>0);
      add_rule(i_code=>'16', i_domain=>TRAIN, i_tag1=>'SUM_ACTUAL_KM_3NF_NG_EPT', i_tag2=>'SUM_ACTUAL_KM_DIM_NG_EPT', i_op=>'=', i_description=>'Totalt antall faktiske km i DIM == 3NF (Gjøvik EPt)', i_result_text=>'Det er :1 faktiske km i 3NF og :2 faktiske km i DIM', i_status_level=>'ERROR', i_has_error_page=>0);
      add_rule(i_code=>'17', i_domain=>TRAIN, i_tag1=>'SUM_ACTUAL_KM_3NF_NG_T', i_tag2=>'SUM_ACTUAL_KM_DIM_NG_T', i_op=>'=', i_description=>'Totalt antall faktiske km i DIM == 3NF (Gjøvik tomtog)', i_result_text=>'Det er :1 faktiske km i 3NF og :2 faktiske km i DIM', i_status_level=>'ERROR', i_has_error_page=>0);
      add_rule(i_code=>'18', i_domain=>TRAIN, i_tag1=>'SUM_ACTUAL_KM_3NF_NG_ET', i_tag2=>'SUM_ACTUAL_KM_DIM_NG_ET', i_op=>'=', i_description=>'Totalt antall faktiske km i DIM == 3NF (Gjøvik ET)', i_result_text=>'Det er :1 faktiske km i 3NF og :2 faktiske km i DIM', i_status_level=>'ERROR', i_has_error_page=>0);
      add_rule(i_code=>'19', i_domain=>TRAIN, i_tag1=>'SUM_PLANNED_KM_3NF', i_tag2=>'SUM_PLANNED_KM_DIM', i_op=>'=', i_description=>'Totalt antall planlagte km i DIM = 3NF (totalt)', i_result_text=>'Det er :1 planlagte km i 3NF og :2 planlagte km i DIM', i_status_level=>'ERROR', i_has_error_page=>0);
      add_rule(i_code=>'20', i_domain=>TRAIN, i_tag1=>'SUM_PLANNED_KM_3NF_NSB_PT', i_tag2=>'SUM_PLANNED_KM_DIM_NSB_PT', i_op=>'=', i_description=>'Totalt antall planlagte km i DIM = 3NF (NSB Pt)', i_result_text=>'Det er :1 planlagte km i 3NF og :2 planlagte km i DIM', i_status_level=>'ERROR', i_has_error_page=>0);
      add_rule(i_code=>'21', i_domain=>TRAIN, i_tag1=>'SUM_PLANNED_KM_3NF_NSB_EPT', i_tag2=>'SUM_PLANNED_KM_DIM_NSB_EPT', i_op=>'=', i_description=>'Totalt antall planlagte km i DIM = 3NF (NSB EPt)', i_result_text=>'Det er :1 planlagte km i 3NF og :2 planlagte km i DIM', i_status_level=>'ERROR', i_has_error_page=>0);
      add_rule(i_code=>'22', i_domain=>TRAIN, i_tag1=>'SUM_PLANNED_KM_3NF_NSB_T', i_tag2=>'SUM_PLANNED_KM_DIM_NSB_T', i_op=>'=', i_description=>'Totalt antall planlagte km i DIM = 3NF (NSB tomtog)', i_result_text=>'Det er :1 planlagte km i 3NF og :2 planlagte km i DIM', i_status_level=>'ERROR', i_has_error_page=>0);
      add_rule(i_code=>'23', i_domain=>TRAIN, i_tag1=>'SUM_PLANNED_KM_3NF_NSB_ET', i_tag2=>'SUM_PLANNED_KM_DIM_NSB_ET', i_op=>'=', i_description=>'Totalt antall planlagte km i DIM = 3NF (NSB ET)', i_result_text=>'Det er :1 planlagte km i 3NF og :2 planlagte km i DIM', i_status_level=>'ERROR', i_has_error_page=>0);
      add_rule(i_code=>'24', i_domain=>TRAIN, i_tag1=>'SUM_PLANNED_KM_3NF_NG_PT', i_tag2=>'SUM_PLANNED_KM_DIM_NG_PT', i_op=>'=', i_description=>'Totalt antall planlagte km i DIM = 3NF (Gjøvik Pt)', i_result_text=>'Det er :1 planlagte km i 3NF og :2 planlagte km i DIM', i_status_level=>'ERROR', i_has_error_page=>0);
      add_rule(i_code=>'25', i_domain=>TRAIN, i_tag1=>'SUM_PLANNED_KM_3NF_NG_EPT', i_tag2=>'SUM_PLANNED_KM_DIM_NG_EPT', i_op=>'=', i_description=>'Totalt antall planlagte km i DIM = NF (Gjøvik EPt)', i_result_text=>'Det er :1 planlagte km i 3NF og :2 planlagte km i DIM', i_status_level=>'ERROR', i_has_error_page=>0);
      add_rule(i_code=>'26', i_domain=>TRAIN, i_tag1=>'SUM_PLANNED_KM_3NF_NG_T', i_tag2=>'SUM_PLANNED_KM_DIM_NG_T', i_op=>'=', i_description=>'Totalt antall planlagte km i DIM = 3NF (Gjøvik tomtog)', i_result_text=>'Det er :1 planlagte km i 3NF og :2 planlagte km i DIM', i_status_level=>'ERROR', i_has_error_page=>0);
      add_rule(i_code=>'27', i_domain=>TRAIN, i_tag1=>'SUM_PLANNED_KM_3NF_NG_ET', i_tag2=>'SUM_PLANNED_KM_DIM_NG_ET', i_op=>'=', i_description=>'Totalt antall planlagte km i DIM = 3NF (Gjøvik ET)', i_result_text=>'Det er :1 planlagte km i 3NF og :2 planlagte km i DIM', i_status_level=>'ERROR', i_has_error_page=>0);
      add_rule(i_code=>'28', i_domain=>TRAIN, i_tag1=>'SUM_ACTUAL_KM_3NF', i_tag2=>'SUM_ACTUAL_KM_FACT', i_op=>'=', i_description=>'Totalt antall faktiske km i FACT == totalt antall faktiske km i 3NF', i_result_text=>'Det er :1 faktiske km i 3NF og :2 faktiske km i FACT', i_status_level=>'ERROR', i_has_error_page=>1
          ,i_error_page_view=>'SELECT t.train_id, t.nominal_date, o.owner_id owner_id, tt.TRAIN_TYPE_ID TRAIN_TYPE_ID, ROUND(t.actual_distance_km,2) actual_km_3nf, ROUND(ft.ACTUAL_TOT_DISTANCE_KM,2) actual_km_fact
            FROM fact_train ft, TRAIN_NUMBER tn, train t, master_train_number mtn, owner o, train_type tt
            WHERE ft.TRAIN_NUMBER_DIM = tn.sid AND ft.TRAIN_DIM = t.sid AND mtn.sid = t.sid AND mtn.owner_sid = o.sid
            AND mtn.train_type_sid = tt.sid AND ROUND(NVL(t.actual_distance_km,0),2) != ROUND(NVL(ft.ACTUAL_TOT_DISTANCE_KM,0),2) AND t.nominal_date = :nominalDate');
      add_rule(i_code=>'29', i_domain=>TRAIN, i_tag1=>'SUM_PLANNED_KM_3NF', i_tag2=>'SUM_PLANNED_KM_FACT', i_op=>'=', i_description=>'Totalt antall planlagte km i FACT == totalt antall planlagte km i 3NF', i_result_text=>'Det er :1 planlagte km i 3NF og :2 planlagte km i FACT', i_status_level=>'ERROR', i_has_error_page=>0);
      add_rule(i_code=>'30', i_domain=>TRAIN, i_tag1=>'NUM_TRAINS_PLANNED_KM_GREATER_THAN_800', i_tag2=>NULL, i_op=>'>0', i_description=>'Eksisterer det tog (NSB,NG,Pt,EPt,T,ET) med planlagt distanse > 800 km', i_result_text=>'Det finnes :1 tog som har planlagt distanse større enn 800 km', i_status_level=>'WARNING', i_has_error_page=>0);
      add_rule(i_code=>'31', i_domain=>TRAIN, i_tag1=>'NUM_TRAINS_ACTUAL_KM_GREATER_THAN_800', i_tag2=>NULL, i_op=>'>0', i_description=>'Eksisterer det tog (NSB,NG,Pt,EPt,T,ET)  med faktisk distanse > 800 km', i_result_text=>'Det finnes :1 tog som har faktisk distanse større enn 800 km', i_status_level=>'WARNING', i_has_error_page=>0);
      add_rule(i_code=>'32', i_domain=>TRAIN, i_tag1=>'WO_DISTANCE_ACT_NSB_NG_PT', i_tag2=>NULL, i_op=>'>0', i_description=>'Antall persontog NSB eller Gjøvikbanen (Pt,EPt) med NULL/0 faktisk distanse km som skulle hatt km', i_result_text=>'Det finnes :1 persontog for NSB som har faktisk distanse lik 0 eller NULL', i_status_level=>'WARNING', i_has_error_page=>1
                    ,i_error_page_view=>'select train_id, nominal_date,orig_id, dest_id, train_type_id from train_distance_v t where  t.train_type_id in (''Pt'', ''EPt'') and t.owner_id in (''NSB'',''NG'') and has_not_act_km = 1 and shall_not_have_act_km = 0 AND t.train_category_id != ''Lx'' and t.nominal_date=:nominalDate');
      add_rule(i_code=>'33', i_domain=>TRAIN, i_tag1=>'WO_DISTANCE_PL_NSB_NG_PT', i_tag2=>NULL, i_op=>'>0', i_description=>'Antall persontog NSB eller Gjøvikbanen (Pt,EPt) med NULL/0 planlagt distanse km', i_result_text=>'Det finnes :1 persontog for NSB som har planlagt distanse lik 0 eller NULL', i_status_level=>'ERROR', i_has_error_page=>1
      ,i_error_page_view=>'select train_id, nominal_date,orig_id, dest_id, train_type_id  from train_distance_v t where  t.train_type_id in (''Pt'', ''EPt'') and t.owner_id in (''NSB'',''NG'') and has_not_pl_km = 1 AND t.train_category_id != ''Lx'' and t.nominal_date=:nominalDate' );
      add_rule(i_code=>'34', i_domain=>TRAIN, i_tag1=>'MISSING_ACTUAL_TIME', i_tag2=>null, i_op=>'>0', i_description=>'Eksisterer det fullførte (PT,EPt,T,ET) tog uten faktiske tider?', i_result_text=>'Det er :1 fullførte tog uten faktiske tider', i_status_level=>'WARNING', i_has_error_page=>1
      ,i_error_page_view=>'SELECT dtn.train_id, dt.nominal_date, dtn.ma_train_type_id train_type_id, dtn.ma_owner_id owner_id,
                          dt.origin_name origin,dt.destination_name destination, dt.actual_departure_time, dt.actual_arrival_time
                        FROM fact_train ft , DIM_TRAIN_NUMBER dtn, DIM_TRAIN dt, DIM_CALENDAR dc
                          where ft.TRAIN_NUMBER_DIM = dtn.DIM_SID
                          and ft.TRAIN_DIM = dt.DIM_SID
                            and ft.NOMINAL_DATE_DIM = dc.DIM_SID
                                AND ft.completed_rm = 1   and TOT_CANCELLED_TIOS_TRAIN = 0
                               and PART_CANCELLED_RM = 0  and TOT_CANCELLED_RM = 0
                               AND dtn.MA_TRAIN_TYPE_ID IN (''Pt'', ''EPt'', ''T'', ''ET'')
                               AND (ft.actual_departure_date_dim = -1 OR ft.actual_arrival_date_dim = -1)
                           and dc.day =:nominalDate');
      add_rule(i_code=>'35', i_domain=>TRAIN, i_tag1=>'FACT_MISSING', i_tag2=>null, i_op=>'>0', i_description=>'Eksisterer det tog Pt,EPt for NSB eller NG som har missing-eksekveringsflagget satt', i_result_text=>'Det er :1 tog med missing eksekveringsstatus', i_status_level=>'WARNING', i_has_error_page=>1
        ,i_error_page_view=>'SELECT t.train_id, dtn.ma_owner_id, dtn.ma_train_type_id, dtn.nominal_date, ft.COMPLETED_TIOS_REASON, ft.PART_CANCELLED_TIOS_REASON, ft.TOT_CANCELLED_TIOS_REASON, ft.COMPLETED_TIOS_TRAIN, ft.PART_CANCELLED_TIOS_TRAIN, ft.TOT_CANCELLED_TIOS_TRAIN,
                              ft.COMPLETED_TIOS_STATION, ft.PART_CANCELLED_TIOS_STATION, ft.TOT_CANCELLED_TIOS_STATION, ft.COMPLETED_RM, ft.PART_CANCELLED_RM, ft.TOT_CANCELLED_RM, ft.MISSING_EXECUTION_STATUS, ft.JBV_CANCELLATION_LOOKUP_DIM
                            from fact_train ft, dim_train_number dtn, dim_train t
                            WHERE dtn.dim_sid = ft.train_number_dim and ft.missing_execution_status = 1 and dtn.ma_train_type_id in (''Pt'',''EPt'') and dtn.ma_owner_id in (''NSB'', ''NG'') and t.dim_sid = ft.train_dim
                              and t.NOMINAL_DATE = :nominalDate');
      add_rule(i_code=>'36', i_domain=>TRAIN, i_tag1=>'MTN_PT_5_CHARS', i_tag2=>null, i_op=>'>0', i_description=>'Det skal ikke eksistere tog (Pt,EPt) for NSB som har 5 tegn i tognr', i_result_text=>'Det er :1 tog med 5 tegn i tognr', i_status_level=>'ERROR', i_has_error_page=>1
      ,i_error_page_view=>'select dtn.train_id, dtn.name,dtn.nominal_date, dtn.ma_train_Type_id train_type_id, dtn.ma_product_id product_id, dtn.ma_region_name region_name
                              from dim_train_Number dtn where
                              tREGEXP_LIKE (dtn.train_id, ''^([^98].{4})$'') and dtn.MA_TRAIN_TYPE_ID in (''Pt'',''EPt'') and dtn.MA_OWNER_ID = ''NSB'' and nominal_date = :nominalDate
                              order by train_id');
      add_rule(i_code=>'37', i_domain=>TRAIN, i_tag1=>'MTN_PT_LETTERS', i_tag2=>null, i_op=>'>0', i_description=>'Det skal ikke eksistere tog (Pt,EPt) for NSB som har bokstaver tognr', i_result_text=>'Det er :1 tog med bokstaver i tognr', i_status_level=>'ERROR', i_has_error_page=>1
      ,i_error_page_view=>'SELECT dtn.train_id,
                          dtn.nominal_date,
                          dtn.name,
                          dtn.ma_train_Type_id train_type_id,
                          dtn.ma_product_id product_id,
                          dtn.ma_region_name region_name
                        FROM dim_train_Number dtn
                        WHERE REGEXP_LIKE (dtn.train_id, ''[^0-9]'')
                        AND dtn.MA_TRAIN_TYPE_ID   IN (''Pt'',''EPt'')
                        AND dtn.MA_OWNER_ID       = ''NSB''
                        AND nominal_date = :nominalDate
                        ORDER BY train_id');
      add_rule(i_code=>'38', i_domain=>TRAIN, i_tag1=>'MTN_PT_NO_PRODUCT', i_tag2=>null, i_op=>'>0', i_description=>'Det skal ikke eksistere tog (Pt,EPt) for NSB som ikke er tilknyttet ett produkt', i_result_text=>'Det er :1 tog uten produkt', i_status_level=>'ERROR', i_has_error_page=>1
      ,i_error_page_view=>'SELECT dtn.train_id,
                              dtn.nominal_date,
                              dtn.ma_train_Type_id train_type_id,
                              dtn.ma_product_id product_id,
                              dtn.ma_region_name region_name
                            FROM dim_train_Number dtn
                            WHERE dtn.ma_product_sid  = -1
                            AND dtn.MA_TRAIN_TYPE_ID   IN (''Pt'',''EPt'')
                            AND dtn.MA_OWNER_ID       = ''NSB''
                            AND nominal_date          = :nominalDate
                            ORDER BY train_id');

    END;
  PROCEDURE train_composition_rules IS
    train_composition VARCHAR2(100) := 'TRAIN_COMPOSITION';
    BEGIN
      add_rule(i_code=>'1', i_domain=>TRAIN_COMPOSITION, i_tag1=>'3NF', i_tag2=>'RM', i_op=>'=', i_description=>'Antall togkomposisjoner i RM er lik antallet i 3NF', i_result_text=>'Det er :1 rader i 3NF og :2 rader i RM', i_status_level=>'ERROR', i_has_error_page=>1
      ,i_error_page_view=>'select '||''''||'RASK'||''''||' source,tc.* from rask_train_composition_diff_v tc where NOMINAL_DATE=:nominalDate union
                           select  '||''''||'RM'||''''||', tc.* from rm_train_composition_diff_v tc where NOMINAL_DATE=:nominalDate');
      add_rule(i_code=>'2', i_domain=>TRAIN_COMPOSITION, i_tag1=>'3NF', i_tag2=>'DIM', i_op=>'=', i_description=>'Antall togkomposisjoner i 3NF er lik antallet i DIM', i_result_text=>'Det er :1 rader i 3NF og :2 rader i DIM', i_status_level=>'ERROR', i_has_error_page=>0);
      add_rule(i_code=>'3', i_domain=>TRAIN_COMPOSITION, i_tag1=>'3NF', i_tag2=>'FACT', i_op=>'=', i_description=>'Antall togkomposisjoner i FACT er likt antall i 3NF', i_result_text=>'Det er :1 rader i 3NF og :2 rader i FACT', i_status_level=>'ERROR', i_has_error_page=>0);
      add_rule(i_code=>'4', i_domain=>TRAIN_COMPOSITION, i_tag1=>'3NF_WO_PLANNED_DISTANCE', i_tag2=>NULL, i_op=>'>0', i_description=>'Det eksisterer ikke komposisjoner uten planlagt kilometer', i_result_text=>'Det er :1 togkomposisjoner uten planlagt kilometer', i_status_level=>'ERROR', i_has_error_page=>0);
      add_rule(i_code=>'5', i_domain=>TRAIN_COMPOSITION, i_tag1=>'3NF_WO_ACTUAL_DISTANCE', i_tag2=>NULL, i_op=>'>0', i_description=>'Det eksisterer ikke kansellerte togkomposisjoner uten faktiske distanse', i_result_text=>'Det er :1 kansellerte togkomposisjoner uten faktisk kilometer', i_status_level=>'ERROR', i_has_error_page=>0);
      add_rule(i_code=>'6', i_domain=>TRAIN_COMPOSITION, i_tag1=>'MISSING_ACTUAL_TIME', i_tag2=>NULL, i_op=>'>0', i_description=>'Det eksisterer ikke togkomposisjoner (Pt, EPt, T, ET) uten faktiske tider', i_result_text=>'Det er :1 togkomposisjoner uten faktiske tider', i_status_level=>'WARNING', i_has_error_page=>1
      ,i_error_page_view=>'select tc.train_id, tc.nominal_date,dtn.ma_owner_id owner_id,dtn.ma_train_type_id train_Type_id, tc.ACTUAL_VEHICLE_SET_ID,tc.start_location_id, tc.end_location_id, tc.PLANNED_START_TIME, tc.PLANNED_END_TIME, tc.ACTUAL_START_TIME, tc.ACTUAL_END_TIME
              FROM dim_train_composition tc ,DIM_TRAIN_NUMBER dtn
              WHERE tc.ACTUAL_VEHICLE_SET_SID > -1 AND tc.is_cancelled = 0
                    AND (tc.ACTUAL_START_TIME IS NULL OR tc.actual_end_time IS NULL)
                    AND tc.train_number_sid = dtn.dim_sid
      AND dtn.ma_train_type_id IN (''Pt'', ''EPt'', ''T'', ''ET'') and tc.nominal_date=:nominalDate');
      -- her er regler for å validere om vi har nok data for å kunne vise det fram i trafikk.nsb.no, ikke endre nummeret på disse
      add_rule(i_code=>'7', i_domain=>TRAIN_COMPOSITION, i_tag1=>'FACT_W_ACTUAL_VEHICLE_SET', i_tag2=>null, i_op=>'=0', i_description=>'Har vi noen komposisjoner med faktisk materiell', i_result_text=>'Vi har :1 komposisjoner med faktisk materiell', i_status_level=>'ERROR', i_has_error_page=>0);
      add_rule(i_code=>'8', i_domain=>TRAIN_COMPOSITION, i_tag1=>'TRAIN_COMP_PT_WITHOUT_PLANNED_SET_TYPE_SID', i_tag2=>NULL, i_op=>'>0', i_description=>'Et skal ikke eksistere togkomposisjoner for persontog uten planlagt settype.', i_result_text=>'Det er :1 persontogkomposisjoner uten faktiske settype', i_status_level=>'ERROR', i_has_error_page=>0);
      add_rule(i_code=>'9', i_domain=>TRAIN_COMPOSITION, i_tag1=>'DIM_WAGON_WITH_WAGON_0', i_tag2=>NULL, i_op=>'>0', i_description=>'Det skal ikke være togsett med is_wagon=0 som er vogner', i_result_text=>'Det er :1 rader i dim_train_composition som burde vært merket med is_wagon=1', i_status_level=>'ERROR', i_has_error_page=>0);
      add_rule(i_code=>'10', i_domain=>TRAIN_COMPOSITION, i_tag1=>'FTC_DIFF', i_tag2=>NULL, i_op=>'>0', i_description=>'Alle utregnede verdier i FTC må værre korrekte', i_result_text=>'Det er :1 verdier i FACT_TRAIN_COMPOSITON sine utregnede verdier som er inkorrekt', i_status_level=>'ERROR', i_has_error_page=>1
      ,i_error_page_view=>'SELECT  * from tmp_diff_ftc');
      add_rule(i_code=>'11', i_domain=>TRAIN_COMPOSITION, i_tag1=>'MATERIAL_KM', i_tag2=>NULL, i_op=>'>0', i_description=>'Det skal ikke eksistere avvik av materiellkm per vehicleSet mellom RM og RASK', i_result_text=>'Det er :1 vehicleSett med feil materiellkm', i_status_level=>'ERROR', i_has_error_page=>1
      ,i_error_page_view=>'SELECT * FROM validate_material_km_v WHERE NOMINAL_DATE=:nominalDate  ORDER BY VEHICLE_SET_ID');
      add_rule(i_code=>'12', i_domain=>TRAIN_COMPOSITION, i_tag1=>'BUS_IN_DIM', i_tag2=>NULL, i_op=>'>0', i_description=>'Det skal ikke finnes togslag Bu (Buss) med materiell',i_result_text=>'Det er :1 busser med materiell', i_status_level=>'ERROR', i_has_error_page=>1
      ,i_error_page_view=>'select dtn.TRAIN_ID, dtn.NOMINAL_DATE,dtn.NAME, dtc.ACTUAL_VEHICLE_SET_ID, dtc.START_LOCATION, dtc.END_LOCATION, dtc.PLANNED_START_TIME
      from DIM_TRAIN_NUMBER dtn join DIM_TRAIN_COMPOSITION dtc
      on dtc.TRAIN_SID = dtn.DIM_SID where dtn.MA_TRAIN_TYPE_ID in (''B'', ''Bu'') and dtc.ACTUAL_VEHICLE_SET_ID is not null');
    END;
  PROCEDURE tpo_rules IS
    TPO VARCHAR2(100) := 'TPO';
    BEGIN
      add_rule(i_code=>'1', i_domain=>TPO, i_tag1=>'3NF_HAS_TRAIN', i_tag2=>'DIM', i_op=>'=', i_description=>'Antall rader i DIM == antall rader koblet til tog i 3NF', i_result_text=>'Det er :1 rader i 3NF og :2 rader i DIM', i_status_level=>'ERROR', i_has_error_page=>0);
      add_rule(i_code=>'2', i_domain=>TPO, i_tag1=>'PT_TRAINS_NO_TPO', i_tag2=>NULL, i_op=>'>0', i_description=>'Det eksisterer ikke fremførte persontog uten lokfører', i_result_text=>'Det finnes :1 persontog uten lokfører', i_status_level=>'ERROR', i_has_error_page=>1
          ,i_error_page_view=>'select * from pt_trains_no_tpo_v where nominal_date = :nominalDate');
      add_rule(i_code=>'3', i_domain=>TPO, i_tag1=>'SOURCE', i_tag2=>'3NF', i_op=>'=', i_description=>'Antall rader i 3NF == antall rader i TPO', i_result_text=>'Det er :1 i TPO/Kilden og :2 rader i 3NF', i_status_level=>'ERROR', i_has_error_page=>0);
      add_rule(i_code=>'4', i_domain=>TPO, i_tag1=>'TRAINS_NO_TPO', i_tag2=>NULL, i_op=>'>0', i_description=>'Det eksisterer ikke fremførte NSB-tog uten lokfører', i_result_text=>'Det finnes :1 tog uten lokfører', i_status_level=>'WARNING', i_has_error_page=>1,
               i_error_page_view=>'select t.nominal_date, t.train_id, t.jbv_cancellation_sid, l1.location_id orig_id,
                                   l1.name orig, l2.location_id dest_id, l2.name dest, tt.train_type_id
                                from train t join  MASTER_TRAIN_NUMBER mtn on mtn.sid = t.sid
                                  join train_type tt on tt.sid = mtn.train_type_sid
                                  join location l1 on t.origin_sid=l1.sid
                                  join location l2 on t.destination_sid = l2.sid
                                  join owner o on mtn.owner_sid = o.sid and o.owner_id = ''NSB''
                                where not exists(select 1 from tpo_train_driver tpo
                                where tpo.train_sid = t.sid) and t.nominal_date = :nominalDate and tt.train_type_id not in (''Bu'', ''TU'')');
      add_rule(i_code=>'5', i_domain=>TPO, i_tag1=>'TRIPS_WO_TRAIN', i_tag2=>NULL, i_op=>'>0', i_description=>'Det eksisterer ikke lokfører uten tog', i_result_text=>'Det finnes :1 lokførerturer uten tog', i_status_level=>'WARNING', i_has_error_page=>1,
            i_error_page_view=>'select task_code, employee_number, day_date, tpo_train_id from tpo_train_driver where day_date = :nominalDate and train_sid is null and tpo_train_id is not null');
    END;
  PROCEDURE deviation_reason_rules IS
    DEVIATION_REASON VARCHAR2(50) := 'DEVIATION_REASON';
    BEGIN
      add_rule(i_code=>'1', i_domain=>DEVIATION_REASON, i_tag1=>'TIOS', i_tag2=>'3NF', i_op=>'=', i_description=>'Antall rader i 3NF er det samme som antall rader i TIOS', i_result_text=>'Det er :1 rader i TIOS og :2 rader i 3NF', i_status_level=>'WARNING', i_has_error_page=>0);
      add_rule(i_code=>'2', i_domain=>DEVIATION_REASON, i_tag1=>'3NF', i_tag2=>'FACT', i_op=>'=', i_description=>'Antall rader i 3NF er det samme som antall rader i FACT', i_result_text=>'Det er :1 rader i 3NF og :2 rader i FACT', i_status_level=>'ERROR', i_has_error_page=>0);
      add_rule(i_code=>'3', i_domain=>DEVIATION_REASON, i_tag1=>'HAS_CANCEL_CODE_WHEN_DELAY', i_tag2=>null, i_op=>'>0', i_description=>'Det fins rader i (FACT_DEVIATION_REASON) med forsinkelses minutter og har årsakskode', i_result_text=>'Det er :1 rader i FDR', i_status_level=>'ERROR', i_has_error_page=>1
      ,i_error_page_view=>'select dc.day, fdr.train_dim from FACT_DEVIATION_REASON fdr, DIM_CALENDAR dc where IS_DELETED=0 and IS_CANCELLATION_REASON=1 and DELAYED_IN_RELATIVE_MIN > 0
                  and dc.DIM_SID=fdr.NOMINAL_DATE_DIM and dc.DAY=:nominalDate;');
      add_rule(i_code=>'4', i_domain=>DEVIATION_REASON, i_tag1=>'TIOS_MULTIPLE_CANCELLATIONS', i_tag2=>null, i_op=>'>0', i_description=>'Det fins tog i (FACT_DEVIATION_REASON) med flere helinnstillinger', i_result_text=>'Det er :1 tog med flere enn 1 helinnstilling', i_status_level=>'ERROR', i_has_error_page=>1
      ,i_error_page_view=>'SELECT * FROM
                  (SELECT drv.train_id, drv.train_type_id, drv.day nominal_date, drv.description name, drv.REASON_CANCELLATION, COUNT(*) reasons
                   FROM deviation_reason_v drv
                   WHERE owner_id       = ''NSB'' AND drv.is_planned   = 1 AND drv.is_deleted   = 0
                         AND drv.REASON_CANCELLATION IN (''Y'',''B'')  AND drv.day = to_date(''20160628'',''yyyymmdd'') AND train_type_id IN (''Pt'', ''EPt'')
                   GROUP BY train_id, train_type_id, description, REASON_CANCELLATION, DAY) r
                WHERE r.reasons > 1');
      add_rule(i_code=>'5', i_domain=>DEVIATION_REASON, i_tag1=>'3NF_DELETED', i_tag2=>'TIOS_DELETED', i_op=>'=', i_description=>'Antall rader merket som slettet i 3NF er det samme som i TIOS', i_result_text=>'Det er :1 rader i 3NF og :2 rader i TIOS', i_status_level=>'ERROR', i_has_error_page=>0);
    END;
  PROCEDURE vehicle_rules IS
    VEHICLE varchar2(50) := 'VEHICLE';
  BEGIN
    add_rule(i_code=>'1', i_domain=>VEHICLE, i_tag1=>'RM', i_tag2=>'3NF', i_op=>'=', i_description=>'Antall rader i 3NF er det samme som antall rader i RM', i_result_text=>'Det er :1 rader i RM og :2 rader i 3NF', i_status_level=>'ERROR', i_has_error_page=>0);
    END;
  PROCEDURE vehicle_set_rules IS
    VEHICLE_SET varchar2(50) := 'VEHICLE_SET';
  BEGIN
    add_rule(i_code=>'1', i_domain=>VEHICLE_SET, i_tag1=>'RM', i_tag2=>'3NF', i_op=>'=', i_description=>'Antall rader i 3NF er det samme som antall rader i RM', i_result_text=>'Det er :1 rader i RM og :2 rader i 3NF', i_status_level=>'ERROR', i_has_error_page=>0);
    add_rule(i_code=>'2', i_domain=>VEHICLE_SET, i_tag1=>'INVALID_VS_USED_IN_TC', i_tag2=>null, i_op=>'>0', i_description=>'Antall vognsettversjoner uten individ som brukes i togsammensettinger siste 2-3 måneder',i_result_text=>'Det er :1 togsammensettinger hvor vognsett uten individ er brukt', i_status_level=>'WARNING',i_has_error_page=>1
      ,i_error_page_view=>'SELECT vs.vehicle_set_id , vs.APPLICABLE_FROM , vs.APPLICABLE_UNTIL , t.TRAIN_ID , t.NOMINAL_DATE , tc.PLANNED_START_TIME
FROM vehicle_set vs JOIN TRAIN_COMPOSITION tc ON tc.VEHICLE_SET_SID = vs.sid AND tc.VEHICLE_SET_SID > -1
  JOIN train t ON t.sid = tc.TRAIN_SID
WHERE NOT exists(SELECT 1 FROM VEHICLE_SET_COMPOSITION vsc WHERE vsc.VEHICLE_SET_SID = vs.sid)
      AND tc.PLANNED_START_TIME > add_months(trunc(sysdate, ''MONTH''), -2) order by PLANNED_START_TIME');
    END;
  PROCEDURE vehicle_set_comp_rules IS
    VEHICLE_SET_COMPOSITION varchar2(50) := 'VEHICLE_SET_COMPOSITION';
  BEGIN
    add_rule(i_code=>'1', i_domain=>VEHICLE_SET_COMPOSITION, i_tag1=>'RM_3NF', i_tag2=>null, i_op=>'>0', i_description=>'Antall rader i 3NF er det samme som antall rader i RM', i_result_text=>'Det er :1 rader i forskjell mellom RM og 3NF', i_status_level=>'ERROR', i_has_error_page=>1,
    i_error_page_view=>'SELECT rmvsc.vehicle_set_id, rmvsc.rm_vehicle_set_ref, rmvsc.vehicle_id, rmvsc.position, rmvsc.orientation, rmvsc.applicable_from, rmvsc.applicable_until
                          FROM rm_vehicle_set_composition_v rmvsc where rmvsc.applicable_from <= sysdate -1 and rmvsc.applicable_until <= sysdate -1
                          MINUS
                        SELECT vs.VEHICLE_SET_ID, vs.rm_vehicle_set_ref, v.VEHICLE_ID, vsc.POSITION, vsc.ORIENTATION, vs.APPLICABLE_FROM, vs.APPLICABLE_UNTIL FROM VEHICLE_SET_COMPOSITION vsc
                          JOIN vehicle v ON vsc.VEHICLE_SID = v.sid JOIN vehicle_set vs ON vs.sid = vsc.VEHICLE_SET_SID');
    END;
  PROCEDURE vehicle_type_rules IS
    VEHICLE_TYPE varchar2(50) := 'VEHICLE_TYPE';
    BEGIN
      add_rule(i_code=>'1', i_domain=>VEHICLE_TYPE, i_tag1=>'RM', i_tag2=>'3NF', i_op=>'=', i_description=>'Antall rader i 3NF er det samme som antall rader i RM', i_result_text=>'Det er :1 rader i RM og :2 rader i 3NF', i_status_level=>'ERROR', i_has_error_page=>0);
    END;
  PROCEDURE set_type_rules IS
    SET_TYPE varchar2(50) := 'SET_TYPE';
    BEGIN
      add_rule(i_code=>'1', i_domain=>SET_TYPE, i_tag1=>'RM', i_tag2=>'3NF', i_op=>'=', i_description=>'Antall rader i 3NF er det samme som antall rader i RM', i_result_text=>'Det er :1 rader i RM og :2 rader i 3NF', i_status_level=>'ERROR', i_has_error_page=>1
      , i_error_page_view=>'select set_type_id,  APPLICABLE_FROM, APPLICABLE_UNTIL from RM_SET_TYPE_V where applicable_from < trunc(sysdate) MINUS
                  select set_type_id,  APPLICABLE_FROM, APPLICABLE_UNTIL from set_type where sid > -1');
    END;
  PROCEDURE set_type_comp_rules IS
    SET_TYPE_COMPOSITION varchar2(50) := 'SET_TYPE_COMPOSITION';
    BEGIN
      add_rule(i_code=>'1', i_domain=>SET_TYPE_COMPOSITION, i_tag1=>'RM_3NF', i_tag2=>null, i_op=>'>0', i_description=>'Antall rader i 3NF er det samme som antall rader i RM', i_result_text=>'Det er :1 rader i forskjell mellom RM og 3NF', i_status_level=>'ERROR', i_has_error_page=>1
      , i_error_page_view=>'SELECT set_type_id, rm_set_type_ref, vehicle_type_id, position, orientation, applicable_from, trunc(applicable_until) applicable_until FROM rm_set_type_composition_v WHERE APPLICABLE_FROM < trunc(sysdate)
                              minus
                            SELECT st.set_type_id, st.rm_set_type_ref, vt.vehicle_type_id, stc.position, stc.orientation, st.applicable_from, trunc(st.applicable_until) FROM SET_TYPE_COMPOSITION stc join SET_TYPE st on st.sid = stc.SET_TYPE_SID join VEHICLE_TYPE vt on vt.sid = stc.VEHICLE_TYPE_SID');
    END;
  PROCEDURE energy_rules IS
    ENERGY VARCHAR2(50) := 'ENERGY';
    BEGIN
      add_rule(i_code=>'1', i_domain=>ENERGY, i_tag1=>'ENERGY_QUALITY_3NF', i_tag2=>NULL, i_op=>'>0', i_description=>'Alle tog skal ha minst 95% energimålinger', i_result_text=>'Det er :1 tog som ikke har nok energimålinger', i_status_level=>'WARNING', i_has_error_page=>1,
               i_error_page_view=>'select nominal_date, train_id, energy_quality_pct from train t where (t.ENERGY_QUALITY_PCT < 95 or t.ENERGY_QUALITY_PCT is null) and t.nominal_date = :nominalDate');
      add_rule(i_code=>'2', i_domain=>ENERGY, i_tag1=>'ENERGY_GPS_QUALITY_3NF', i_tag2=>NULL, i_op=>'>0', i_description=>'Alle tog skal ha riktig possisjon på energimålingene', i_result_text=>'Det er :1 tog som ikke har bra nok possisjonskvalitet i energimålingene', i_status_level=>'WARNING', i_has_error_page=>1,
               i_error_page_view=>'select nominal_date, train_id, energy_gps_quality_pct from train t where (t.ENERGY_GPS_QUALITY_PCT < 95 ) and t.nominal_date = :nominalDate');
--       add_rule(i_code=>'ENERGY_NO_CONSUMED', i_domain=>ENERGY, i_tag1=>'ENERGY_NO_CONSUMED', i_tag2=>NULL, i_op=>'>0', i_description=>'Det skal være mindre enn 50 energimålere som ikke har meldt inn forbruk.', i_result_text=>'Det er :1 målere som ikke har rapportert energiforbruk', i_status_level=>'ERROR', i_has_error_page=>1,
--                i_error_page_view=>'select nominal_date, v.vehicle_id, sum_consumed_mwh, sum_generated_mwh from vehicle_energy_mapping
--                join vehicle v on v.sid = vehicle_energy_mapping.vehicle_sid where sum_consumed_mwh is null and nominal_date = :nominalDate');

    END;
  PROCEDURE train_station_rules IS
    train_station varchar2(50) := 'TRAIN_STATION';
  BEGIN
    add_rule(i_code=>'1', i_domain=>train_station, i_tag1=>'3NF_TIOS', i_tag2=>'TIOS', i_op=>'=', i_description=>'Antall rader i 3NF fra TIOS må være lik antall rader i TIOS', i_result_text=>'Det er :1 rader i 3NF fra TIOS og :2 rader i TIOS', i_status_level=>'WARNING', i_has_error_page=>1,
    i_error_page_view=>'select t.TIOS_SID, t.train_id, t.nominal_date, t.location_id, tv.last_modified_date from (SELECT TIOS_SID, TRAIN_ID,NOMINAL_DATE, LOCATION_ID FROM tios_train_station_v  MINUS SELECT ts.TIOS_SID, t.TRAIN_ID, NOMINAL_DATE,l.LOCATION_ID from TRAIN_STATION ts join train t on t.sid = ts.TRAIN_SID join LOCATION l on l.sid = ts.LOCATION_SID) t, tios_train_station_v tv where t.tios_sid = tv.tios_sid and t.nominal_date=:nominalDate');
    add_rule(i_code=>'2', i_domain=>train_station, i_tag1=>'HAS_ALL_RM_LOC', i_tag2=>null, i_op=>'>0', i_description=>'Har vi fått alle togstasjoner fra RM?', i_result_text=>'Det er :1 togstasjoner i RM som ikke fins i 3NF', i_status_level=>'ERROR', i_has_error_page=>0);
    add_rule(i_code=>'3', i_domain=>train_station, i_tag1=>'3NF', i_tag2=>'DIM', i_op=>'=', i_description=>'Antall rader i 3NF må være lik antall rader i DIM', i_result_text=>'Det er :1 rader i 3NF  og :2 rader i DIM', i_status_level=>'ERROR', i_has_error_page=>0);
--add_rule(i_code=>'3NF_EQ_RM', i_domain=>train_station, i_tag1=>'3NF_RM', i_tag2=>'RM', i_op=>'=', i_description=>'Antall rader i 3NF fra RM må være lik antall rader i RM', i_result_text=>'Det er :1 rader i 3NF fra RM og :2 rader i RM', i_status_level=>'ERROR', i_has_error_page=>0);
    add_rule(i_code=>'4', i_domain=>train_station, i_tag1=>'DIFF_PL_PASSENGER_STOPS', i_tag2=>null, i_op=>'>0', i_description=>'Antall tog med passasjerstopp som er forskjellige fra forrige uke med samme ukedag', i_result_text=>'Det er :1 rader tog som ikke stemmer med forventet passasjerstopp', i_status_level=>'WARNING', i_has_error_page=>1
    ,i_error_page_view=>'
    SELECT  nominal_date, train_id, prev_cnt, cnt
        FROM ( select    dts.train_id, dts.nominal_date
                 ,sum(dts.PLANNED_PASSENGER_STOP) cnt,
                  lag(sum(dts.PLANNED_PASSENGER_STOP),1,0) over (PARTITION BY dts.TRAIN_ID  ORDER by NOMINAL_DATE) as prev_cnt
               from DIM_TRAIN_STATION dts
               where dts.NOMINAL_DATE in (:nominalDate, :nominalDate-7) and dts.PLANNED_PASSENGER_STOP = 1
          GROUP BY  train_id, NOMINAL_DATE)
        WHERE prev_cnt > 0 and cnt != prev_cnt');
      -- her er regler for å validere om vi har nok data for å kunne vise det fram i trafikk.nsb.no, ikke endre nummeret på disse
      add_rule(i_code=>'5', i_domain=>train_station, i_tag1=>'ROWS_WITH_ACT_DEP_TIME_DIM', i_tag2=>null, i_op=>'=0', i_description=>'Har vi fått noen faktiske avgangstider', i_result_text=>'Vi har :1 faktiske avgangstider', i_status_level=>'ERROR', i_has_error_page=>0);
      add_rule(i_code=>'6', i_domain=>train_station, i_tag1=>'ROWS_WITH_ACT_ARR_TIME_DIM', i_tag2=>null, i_op=>'=0', i_description=>'Har vi fått noen faktiske ankomsttider', i_result_text=>'Vi har :1 faktiske ankomsttider', i_status_level=>'ERROR', i_has_error_page=>0);
      add_rule(i_code=>'7', i_domain=>train_station, i_tag1=>'PLANNED_PS_PT', i_tag2=>null, i_op=>'>0', i_description=>'Antall tog (Pt) for NSB og NG som har færre enn 2 planlagte passasjerstopp', i_result_text=>'Det er :1 tog som mangler planlagte passasjerstopp', i_status_level=>'ERROR', i_has_error_page=>1
      ,i_error_page_view=>'
      select * from (
        select dt.nominal_date nominal_date, dt.train_id train_id, dtn.ma_train_type_id train_type, dtn.ma_owner_id owner, sum(nvl(dts.planned_passenger_stop, 0)) ps
        from dim_train_station dts, dim_train dt , dim_train_number dtn, dim_train_composition dtc
        where
        dts.train_sid = dt.dim_sid
        and dtc.train_sid = dt.dim_sid
        and dt.train_number_SID = dtn.dim_sid
        and dtn.MA_OWNER_ID in  (''NSB'', ''NG'')
        and dtn.MA_TRAIN_TYPE_ID = ''Pt''
        and dt.nominal_date  = :nominalDate
        and dt.JBV_CANCELLATION_CODE not in (''Y'', ''B'')
        group by dt.train_id, dt.nominal_date, dtn.ma_train_type_id, dtn.ma_owner_id) where ps < 2');
      add_rule(i_code=>'8', i_domain=>train_station, i_tag1=>'PLANNED_PS_EPT', i_tag2=>null, i_op=>'>0', i_description=>'Antall tog (EPt) for NSB og NG som har færre enn 2 planlagte passasjerstopp', i_result_text=>'Det er :1 tog som mangler planlagte passasjerstopp', i_status_level=>'ERROR', i_has_error_page=>1
      ,i_error_page_view=>'
      select * from (
        select dt.nominal_date nominal_date, dt.train_id train_id, dtn.ma_train_type_id train_type, dtn.ma_owner_id owner, sum(nvl(dts.planned_passenger_stop, 0)) ps
        from dim_train_station dts, dim_train dt , dim_train_number dtn, dim_train_composition dtc
        where
        dts.train_sid = dt.dim_sid
        and dtc.train_sid = dt.dim_sid
        and dt.train_number_SID = dtn.dim_sid
        and dtn.MA_OWNER_ID in  (''NSB'', ''NG'')
        and dtn.MA_TRAIN_TYPE_ID = ''EPt''
        and dt.nominal_date  = :nominalDate
        and dt.JBV_CANCELLATION_CODE not in (''Y'', ''B'')
        group by dt.train_id, dt.nominal_date, dtn.ma_train_type_id, dtn.ma_owner_id) where ps < 2');
    add_rule(i_code=>'9', i_domain=>train_station, i_tag1=>'DIM', i_tag2=>'FACT', i_op=>'=', i_description=>'Antall rader i DIM må være lik antall rader i FACT', i_result_text=>'Det er :1 rader i DIM  og :2 rader i FACT', i_status_level=>'ERROR', i_has_error_page=>0);
  END;
  PROCEDURE apc_rules IS
    apc varchar2(50) := 'APC';
    BEGIN
      add_rule(i_code=>'1', i_domain=>apc, i_tag1=>'APC_CLOSED_W_APC', i_tag2=>null, i_op=>'>0', i_description=>'Antall rader med APC-data som er merket closed_vehicles = X', i_result_text=>'Det er :1 rader som er merket med closed_Vehicles=X som har APC-data', i_status_level=>'WARNING', i_has_error_page=>1
      ,i_error_page_view=>'SELECT nominal_date Nominaldag, train_id TogId, is_cancelled kansellert, location_id Lokasjon, vehicle_set_id Togsett, product_id Produkt, passenger_count_in_raw Ant_inn, passenger_count_out_raw Ant_ut, DILAX_QUALITY_LEVEL Dilaxkvalitet, locked_trip dilax_Lukket
                          FROM enka_apc_data
                          WHERE nominal_date       = :nominalDate
                          AND is_deleted           = 0
                          AND closed_vehicles      = ''X''
                          AND DILAX_QUALITY_LEVEL IS NOT NULL order by nominal_date,train_id, vehicle_Set_id, location_id');
      add_rule(i_code=>'2', i_domain=>apc, i_tag1=>'3NF_TC_APC', i_tag2=>'APC_WITH_APC_DATA', i_op=>'=', i_description=>'Antall rader med APC-data i 3NF skal være likt antall rader med APC-data i APC-tabellen', i_result_text=>'Det er :1 rader i 3NF og :2 rader i APC', i_status_level=>'ERROR', i_has_error_page=>0);
      add_rule(i_code=>'3', i_domain=>apc, i_tag1=>'3NF_TSC', i_tag2=>'FACT_TOTAL', i_op=>'=', i_description=>'Antall rader i 3NF skal være likt antall rader i FACT_TSC', i_result_text=>'Det er :1 rader i 3NF og :2 rader i FACT', i_status_level=>'ERROR', i_has_error_page=>0);
      add_rule(i_code=>'4', i_domain=>apc, i_tag1=>'FACT_TOTAL', i_tag2=>'APC_TOTAL', i_op=>'=', i_description=>'Antall rader i FACT skal være likt antall rader i APC-tabellen', i_result_text=>'Det er :1 rader i FACT og :2 rader i APC', i_status_level=>'ERROR', i_has_error_page=>0);
      add_rule(i_code=>'5', i_domain=>apc, i_tag1=>'APC_CANCELLED_W_APC', i_tag2=>null, i_op=>'>0', i_description=>'Antall rader med APC-data som er merket is_cancelled = 1', i_result_text=>'Det er :1 rader som er merket med is_cancelled=1 som har APC-data', i_status_level=>'WARNING', i_has_error_page=>1
      ,i_error_page_view=>'SELECT nominal_date Nominaldag, train_id TogId, is_cancelled Kansellert, location_id Lokasjon, vehicle_set_id Togsett, product_id Produkt, passenger_count_in_raw Ant_inn, passenger_count_out_raw Ant_ut, DILAX_QUALITY_LEVEL Dilaxkvalitet, locked_trip Dilax_Lukket
                          FROM enka_apc_data
                          WHERE nominal_date       = :nominalDate
                          AND is_deleted           = 0
                          AND is_cancelled = 1
                          AND DILAX_QUALITY_LEVEL IS NOT NULL order by nominal_date,train_id, vehicle_Set_id, location_id');
      add_rule(i_code=>'6', i_domain=>apc, i_tag1=>'FACT_TRAINS', i_tag2=>'APC_TRAINS', i_op=>'=', i_description=>'Antall tog i FTSC skal være likt antall tog i APC_DATA', i_result_text=>'Det er :1 rader i FACT og :2 rader i APC', i_status_level=>'ERROR');
      add_rule(i_code=>'7', i_domain=>apc, i_tag1=>'FACT_TRAIN_STATIONS', i_tag2=>'APC_PASSENGER_STOPS', i_op=>'=', i_description=>'Antall togstopp i FTSC skal være likt antall togstopp i APC_DATA', i_result_text=>'Det er :1 rader i FACT og :2 rader i APC', i_status_level=>'ERROR');
      add_rule(i_code=>'8', i_domain=>apc, i_tag1=>'PLANNED_TRAINS_W_COMPOSITION', i_tag2=>'APC_TRAINS', i_op=>'=', i_description=>'Antall planlagte tog med komposisjon og passasjerstopp i RASK (:1) skal være overført til APC_DATA (:2)', i_result_text=>'Det er :1 rader i RASK og :2 rader i APC', i_status_level=>'ERROR', i_has_error_page=>1
      ,i_error_page_view=>'select distinct dtc.nominal_date Nominaldag, tn.train_id TogId, tn.ma_owner_id Eier, tn.ma_train_type_id Togtype
      from fact_train ft, dim_train_number tn, dim_train_composition dtc, dim_train_station dts where
      dtc.train_sid = ft.train_dim and
      tn.dim_sid = ft.TRAIN_NUMBER_DIM and tn.ma_train_type_id in (''EPt'',''Pt'')
      and tn.MA_OWNER_ID = ''NSB'' and ft.is_planned = 1
      and dts.train_sid = ft.train_dim  and dts.PLANNED_PASSENGER_STOP = 1
      and dtc.nominal_date = :nominalDate and ft.train_dim not in
      (select train_sid from enka_apc_data where nominal_date = :nominalDate) order by tn.train_id');
      add_rule(i_code=>'9', i_domain=>apc, i_tag1=>'3NF_ERROR_TABLE', i_tag2=>null, i_op=>'>0', i_description=>'Antall rader fra Dilax som er forkastet av RASK', i_result_text=>'Det er :1 rader i errortabellen som er forkastet av RASK', i_status_level=>'WARNING', i_has_error_page=>1
      ,i_error_page_view=>'SELECT distinct nominal_date, train_id, short_name, vehicle_set_id, arrival_time, departure_time,
        gps_latitude, gps_longitude, quality_level, ordinal, apc_in_raw_total, apc_out_raw_total, err_mesg$ AS error_message
      FROM discarded_tsc_v WHERE nominal_date = :nominalDate
      ORDER BY nominal_date, train_id, ordinal');
    END;
BEGIN
  delete from data_control_rule;
  train_rules();
  train_composition_rules();
  tpo_rules();
  deviation_reason_rules;
  vehicle_rules;
  vehicle_set_rules;
  vehicle_set_comp_rules;
  vehicle_type_rules;
  set_type_rules;
  set_type_comp_rules;
  train_station_rules;
  energy_rules;
  apc_rules;
  COMMIT;
  /*
select distinct 'add_rule(i_code=>'''||code||''',i_domain=>'|| domain||', i_tag1=>''1'', i_tag2=>''2'', i_op=>''?'', i_description=>'''
||description ||''', i_result_text=>'''||regexp_replace(result_text,  '([[:digit:]+]|(null))','?')
|| ''',i_status_level=>'''|| status|| ''', i_has_error_page=>'|| has_error_page||');'
from VALIDATION_RESULT
where domain='TRAIN'
order by 1
;;
   */
END;
