--liquibase formatted sql
--changeset yen:data_module
create table data_module(
  module varchar2(100) not null
  ,creation_date DATE DEFAULT sysdate
  ,modified_date DATE DEFAULT sysdate
  ,description varchar2(1000)
);

CREATE UNIQUE INDEX data_module_pi on data_module(module)  COMPUTE STATISTICS;
alter table  data_module add constraint data_module_pk primary key (module) USING INDEX data_module_pi;
