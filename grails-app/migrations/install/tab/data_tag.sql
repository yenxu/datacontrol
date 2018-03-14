--liquibase formatted sql
--changeset yen:data_tag
create table data_tag(
  module varchar2(100) not null
  ,tag varchar2(200) not null
  ,creation_date DATE DEFAULT sysdate
  ,modified_date DATE DEFAULT sysdate
  ,description varchar2(1000)
);

CREATE UNIQUE INDEX data_tag_pi on data_tag(module, tag)  COMPUTE STATISTICS;
alter table  data_tag add constraint data_tag_pk primary key (module, tag) USING INDEX data_tag_pi;


