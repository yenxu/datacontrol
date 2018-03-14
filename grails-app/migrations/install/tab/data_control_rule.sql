--liquibase formatted sql
--changeset yen:data_control_rule
CREATE TABLE data_control_rule (
    sid                 NUMBER(19)                   NOT NULL
  , rule_id             VARCHAR2(100) NOT NULL
  , module              VARCHAR2(100)                NOT NULL
  , tag1                VARCHAR2(200)                NOT NULL
  , tag2                VARCHAR2(200)
  , comparison_operator VARCHAR2(20)                 NOT NULL
  , creation_date       DATE DEFAULT sysdate         NOT NULL
  , modified_date       DATE DEFAULT sysdate         NOT NULL
  , description         VARCHAR2(1000)               NOT NULL
  , result_text         VARCHAR2(1000)               NOT NULL
  , status_level        VARCHAR2(20) DEFAULT 'ERROR' NOT NULL
  , has_error_page      NUMBER(1) DEFAULT 0
  , error_page_view     CLOB
);

CREATE UNIQUE INDEX data_control_rule_pi on data_control_rule(sid) COMPUTE STATISTICS;
ALTER TABLE data_control_rule ADD CONSTRAINT data_control_rule_pk PRIMARY KEY (sid) USING INDEX data_control_rule_pi;
CREATE UNIQUE INDEX data_control_rule_ui on data_control_rule(module, tag1, tag2, comparison_operator)   COMPUTE STATISTICS;
ALTER TABLE data_control_rule ADD CONSTRAINT data_control_rule_uk UNIQUE (module, tag1, tag2, comparison_operator) USING INDEX data_control_rule_ui;

--changeset yen:comment_data_control_rule runOnChange:true
COMMENT ON TABLE data_control_rule is 'Tabellen inneholder valideringsregler.
Inneholdet i tabellen opprettes dynamisk via SQL-skript createDataControlRules.sql.
Reglene validerer dataen som samles sammen av forskjellige tellingsskript og vises i Trafikk.nsb.no
under Grunndata/Datakvalitet.';
COMMENT ON COLUMN data_control_rule.module is 'Vi har forskjellige predefinerte domener.
 Eksempel på domener er: TRAIN, TRAIN_COMPOSITION, TRAIN_STATION.
 Dette feltet inneholder domener som vi bruker til å gruppere de forskjellige valideringsreglene.';
COMMENT ON COLUMN data_control_rule.tag1 is 'Tag-er er valgt ved tellinger.';
COMMENT ON COLUMN data_control_rule.comparison_operator is
'Logisk sammenlignes operator som <, >, <=, >=, =, etc';
COMMENT ON COLUMN data_control_rule.description is 'Beskrivelse av regelen';
COMMENT ON COLUMN data_control_rule.result_text is 'Vises i skjermbildet Datakvalitet';
COMMENT ON COLUMN data_control_rule.status_level is 'Status har 3 nivåer: ERROR/WARNING/INFO';
COMMENT ON COLUMN data_control_rule.has_error_page is '1/0 Har en feilside eller ei';
COMMENT ON COLUMN data_control_rule.rule_id is 'En vilkårlig kode, f.eks tall for å lettere finne igjen reglene';
COMMENT ON COLUMN data_control_rule.error_page_view is 'SQL-setning som brukes til å danne data i error_page';