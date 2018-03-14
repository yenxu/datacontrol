
CREATE TABLESPACE "DQC_DATA"
LOGGING DATAFILE '/home/oracle/app/oracle/oradata/orcl/dqc_data_tb01.dbf'
size 400m autoextend on;

CREATE TABLESPACE "DQC_LOB"
LOGGING DATAFILE '/home/oracle/app/oracle/oradata/orcl/dqc_lob_tb01.dbf'
size 400m autoextend on;

CREATE USER dqc
IDENTIFIED BY dqc
DEFAULT TABLESPACE DQC_DATA
TEMPORARY TABLESPACE temp_smaller
QUOTA 0 ON SYSTEM
QUOTA 0 ON SYSAUX
QUOTA UNLIMITED ON dqc_data
;

grant create session to dqc;
grant create table to dqc;
grant create trigger to dqc;
grant create view to dqc;
grant create type to dqc;
grant create procedure to dqc;
grant create synonym to dqc;
grant create sequence to dqc;
grant create database link to dqc;
grant alter system to dqc ;
