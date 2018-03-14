--liquibase formatted sql
--changeset yen:data_statistic
CREATE TABLE data_statistic (
  sid           NUMBER(19)          NOT NULL,
  version       NUMBER(3) DEFAULT 0 NOT NULL,
  nominal_date  DATE,
  module        VARCHAR2(100),
  tag           VARCHAR2(100),
  row_count     number(38,15),
  description   VARCHAR2(400),    
  version number(10),
  creation_date DATE DEFAULT sysdate,
  modified_date DATE DEFAULT sysdate
)TABLESPACE rask_dc;
CREATE UNIQUE INDEX data_statistic_pi on data_statistic(nominal_date, module, tag) TABLESPACE rask_dc_index COMPUTE STATISTICS;
ALTER TABLE data_statistic ADD CONSTRAINT data_statistic_pk PRIMARY KEY (nominal_date, module, tag) USING INDEX data_statistic_pi;

--changeset yen:comments runOnChange:true
COMMENT ON TABLE data_statistic is 'Inneholder tellinger som brukes til datakvalitetsvalideringer.';

 
 