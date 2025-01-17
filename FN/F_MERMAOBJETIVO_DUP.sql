CREATE FUNCTION EXT.F_MERMAOBJETIVO_DUP (ID_EMPLEADO VARCHAR(20), PERIOD_SEQ BIGINT, ID_SUCURSAL VARCHAR(127)) -- parameters
RETURNS CREDIT_VALUE DECIMAL(25,10)
LANGUAGE SQLSCRIPT
AS
BEGIN
    
    -- Variables
    DECLARE lv_fecha DATE;
	DECLARE lv_dtype_merma BIGINT;
    
    -- PERDIODSEQ
    SELECT PER.STARTDATE 
	INTO lv_fecha DEFAULT NULL
	FROM TCMP.CS_PERIOD PER
	LEFT JOIN TCMP.CS_PERIODTYPE PT
	ON PER.PERIODTYPESEQ = PT.PERIODTYPESEQ
	WHERE PER.PERIODSEQ = :PERIOD_SEQ
	AND PER.REMOVEDATE = '2200-01-01 00:00:00.000000000'
	AND PT.NAME = 'day' 
	AND PT.REMOVEDATE = '2200-01-01 00:00:00.000000000';
	
	-- MERMA
	SELECT DATATYPESEQ INTO lv_dtype_merma
	FROM TCMP.CS_EVENTTYPE
	WHERE EVENTTYPEID = 'MERMA'
	AND REMOVEDATE = '2200-01-01 00:00:00.000000000';

	-- SUBTABLE
	SELECT GENERICNUMBER3
	INTO CREDIT_VALUE DEFAULT NULL
	FROM (
			SELECT 
			LINENUMBER,
			SUBLINENUMBER,
			COMPENSATIONDATE FECHA_INICIO,
			IFNULL(LEAD(COMPENSATIONDATE) OVER (ORDER BY COMPENSATIONDATE), '2200-01-01') FECHA_FIN,
			VALUE,
			GENERICNUMBER3
		FROM TCMP.CS_SALESTRANSACTION
		WHERE EVENTTYPESEQ =  :lv_dtype_merma-- merma
		AND GENERICATTRIBUTE3 = :ID_SUCURSAL
		AND COMPENSATIONDATE BETWEEN ADD_MONTHS(:lv_fecha, -12) AND ADD_MONTHS(:lv_fecha, 1)
	) SUBST
	WHERE 1 = 1
		AND SUBST.FECHA_INICIO <= :lv_fecha
		AND :lv_fecha < SUBST.FECHA_FIN;

END