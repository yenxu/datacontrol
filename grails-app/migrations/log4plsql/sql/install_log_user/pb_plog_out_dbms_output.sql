create or replace
PACKAGE BODY PLOG_OUT_DBMS_OUTPUT AS

--*******************************************************************************
--   NAME:   PLOG_OUT_DBMS_OUTPUT
--
--   writes the log information in the standard output trough the DBMS_OUPUT package
--
--   Ver    Date        Autor             Comment
--   -----  ----------  ----------------  ---------------------------------------
--   1.0    14.04.2008  Bertrand Caradec  First version.
--*******************************************************************************

  PROCEDURE log
(
    pCTX        IN OUT NOCOPY PLOGPARAM.LOG_CTX                ,
    pID         IN       TLOG.id%TYPE                      ,
    pLDate      IN       TLOG.ldate%TYPE                   ,
    pLHSECS     IN       TLOG.lhsecs%TYPE                  ,
    pLLEVEL     IN       TLOG.llevel%TYPE                  ,
    pLSECTION   IN       TLOG.lsection%TYPE                ,
    pLUSER      IN       TLOG.luser%TYPE                   ,
    pLTEXT      IN       TLOG.LTEXT%TYPE                   ,
		pLTAG       IN       TLOG.LTAG%TYPE
)
--*******************************************************************************
--   NAME:   log
--
--   PARAMETERS:
--
--      pCTX               log context
--      pID                ID of the log message, generated by the sequence
--      pLDate             Date of the log message (SYSDATE)
--      pLHSECS            Number of seconds since the beginning of the epoch
--      pLSection          formated call stack
--      pLUSER             database user (SYSUSER)
--      pLTEXT             log text
--
--   Public. Add a log information to the standard output using the
--   DBMS_OUTPUT package.
--
--   Ver    Date        Autor             Comment
--   -----  ----------  ---------------   ----------------------------------------
--   1.0    04.14.2008  Bertrand Caradec  Initial version
--*******************************************************************************

AS
  pt          NUMBER;
  hdr         VARCHAR2(4000);
  hdr_len     pls_integer;
  line_len    pls_integer;
  wrap        NUMBER := pCTX.DBMS_OUTPUT_WRAP;   --length to wrap long text.

  BEGIN
    IF pCTX.USE_DBMS_OUTPUT = TRUE THEN
      hdr := TO_CHAR(pLDATE, 'HH24:MI:SS')||':'||
             LTRIM(TO_CHAR(MOD(pLHSECS,100),'09'))||'-' ||
             PLOGPARAM.getLevelInText(pLLEVEL)||'-'||pLSECTION||'  ';

      hdr_len := LENGTH(hdr);
      line_len := wrap - hdr_len;

      sys.DBMS_OUTPUT.PUT(hdr);
      pt := 1;

      WHILE pt <= LENGTH(pLTEXT) LOOP
        IF pt = 1 THEN
          sys.DBMS_OUTPUT.PUT_LINE(substr(pLTEXT,pt,line_len));
        ELSE
          sys.DBMS_OUTPUT.PUT_LINE(lpad(' ',hdr_len)||substr(pLTEXT,pt,line_len));
        END IF;
        pt := pt + line_len;
      END LOOP;
    END IF;
  END log;

-- end of the package
END;
/