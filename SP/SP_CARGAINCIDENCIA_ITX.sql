CREATE PROCEDURE EXT.SP_CARGAINCIDENCIA_ITX (OUT FILENAME VARCHAR(255), IN pPlRunSeq BIGINT)
LANGUAGE SQLSCRIPT
SQL SECURITY INVOKER
DEFAULT SCHEMA EXT
AS

BEGIN
	DECLARE vPeriodSeq BIGINT;
	DECLARE vFechaArchivo VARCHAR(50);
	DECLARE LV_IDTRANSACCION BIGINT;
	DECLARE LV_IDTRANS VARCHAR(127);
	DECLARE LV_NOMBRE VARCHAR(255);
	DECLARE LV_TOTAL_REGISTROS INTEGER;
	DECLARE LV_USER VARCHAR(127);
	DECLARE LV_CORREO VARCHAR(127);
	DECLARE LV_FECHA_MOVIMIENTO TIMESTAMP;
	DECLARE LV_MAIN_PERIOD VARCHAR(127);
	DECLARE LV_PERIODO VARCHAR(4);
	DECLARE LV_PIPELINE BIGINT;
	DECLARE LV_LASTPIPE BIGINT;
	-- Plan
	DECLARE LV_DATE_PERIODSEQ DATE;
	DECLARE LV_PER_STARTDATE DATE;
	DECLARE LV_PER_ENDDATE DATE;

	SELECT PERIODSEQ, USERID
	INTO vPeriodSeq, LV_USER
	FROM TCMP.CS_PIPELINERUN
	WHERE PIPELINERUNSEQ = :pPlRunSeq;
	
	-- LAST PERIOD
	SELECT MAX(PIPELINERUNSEQ)
	INTO LV_LASTPIPE DEFAULT NULL
	FROM TCMP.CS_DEPOSIT
	WHERE PERIODSEQ = vPeriodSeq;
	
	SELECT TO_VARCHAR(
				CURRENT_TIMESTAMP, 
				'YYYYMMDD_HH24MISS'
			), CURRENT_TIMESTAMP
		INTO vFechaArchivo, LV_FECHA_MOVIMIENTO
		FROM DUMMY;
		
	select email--|| ',gonzalocgr@soriana.com'|| ',sistemasdesarrollonominasyrh@soriana.com'|| ',dulcecgr@soriana.com'
	INTO LV_CORREO 
	from cs_user 
	where id = :lv_user 
	and removedate = '2200-01-01 00:00:00.000000000';
	
	DELETE FROM EXT.TB_INCIDENCIA_AUX
	WHERE 1 = 1;
	
	DELETE FROM EXT.TB_INCIDENCIA_ITX
	WHERE 1 = 1;
	
	SELECT MAX(ID_TRANSACCION)
	INTO LV_IDTRANSACCION
	FROM EXT.TB_IDTRANSACCION_ITX;
	
	-- PERIODO
	SELECT 
	CASE WHEN LENGTH (TRIM (' ' FROM PERIODO)) = 1 THEN '000'||PERIODO
	WHEN LENGTH (TRIM (' ' FROM PERIODO)) = 2 THEN '00'||PERIODO
	ELSE periodo end 
	INTO LV_PERIODO DEFAULT NULL
	from (
		SELECT SUBSTRING(NAME, 16, 2) as PERIODO
		FROM TCMP.CS_PERIOD 
		WHERE PERIODSEQ = :vPeriodSeq
		AND REMOVEDATE = '2200-01-01 00:00:00.000000000');
	
	-- TO FILENAME
	SELECT TO_VARCHAR(MAX(ID_TRANSACCION) + 1)
	INTO LV_IDTRANS
	FROM EXT.TB_IDTRANSACCION_ITX;
	
	-- PERIOD PIPELINE
	SELECT TO_VARCHAR(TO_DATE(ADD_DAYS(STARTDATE, -6)), 'YYYYMMDD')||'_'||TO_VARCHAR(TO_DATE(STARTDATE), 'YYYYMMDD')
	INTO LV_MAIN_PERIOD
	FROM TCMP.CS_PERIOD
	WHERE PERIODSEQ = :vPeriodSeq
	LIMIT 1;
	
	-- Plan
	-- Transform PERIODSEQ to DATE
	SELECT STARTDATE
	INTO LV_DATE_PERIODSEQ DEFAULT NULL
	FROM TCMP.CS_PERIOD
	WHERE PERIODSEQ = :vPeriodSeq
	AND REMOVEDATE = '2200-01-01';
		
	LV_IDTRANSACCION = :LV_IDTRANSACCION + 1;
	
	-- ('P0139', 'P0162', 'P0316')
	INSERT INTO EXT.TB_INCIDENCIA_AUX
		SELECT LV_IDTRANSACCION AS ID_TRANSACCION, PERIODO, ID_EMPLEADO, ID_SUCURSAL, ID_MESA, ID_CONCEPTO, FIJO, SUM(A.IMPORTE), PARAMNUM2, PARAMNUM3, FECHA_ENVIO, PARAMDATE2, REFERENCIA, LOTE, PARAMSTR3, PARAMSTR4
		FROM (
            SELECT DISTINCT LV_IDTRANSACCION AS ID_TRANSACCION, 
			TO_CHAR(
					PR.STARTDATE, 
					'YYYYMMDD'
				) AS PERIODO, 
			PS.NAME AS ID_EMPLEADO, 
			PS.GENERICATTRIBUTE1 AS ID_SUCURSAL, 
			CAR.ID_MESA AS ID_MESA, 
			DP.EARNINGCODEID AS ID_CONCEPTO, 
			'0' AS FIJO, 
			TO_DECIMAL(DP.VALUE,12,2) AS IMPORTE, 
			'0' AS PARAMNUM2, 
			'0' AS PARAMNUM3, 
			TO_CHAR(
				PR.STARTDATE, 
				'YYYY-MM-DD'
			) AS FECHA_ENVIO, 
			'' AS PARAMDATE2, 
			ER.DESCRIPTION AS REFERENCIA, 
			TO_CHAR('COM-' || CASE WHEN LENGTH (PS.GENERICATTRIBUTE1) = 1 THEN '000'|| PS.GENERICATTRIBUTE1
			WHEN LENGTH (PS.GENERICATTRIBUTE1) = 2 THEN '00'|| PS.GENERICATTRIBUTE1 
			WHEN LENGTH (PS.GENERICATTRIBUTE1) = 3 THEN '0'|| PS.GENERICATTRIBUTE1 
			ELSE PS.GENERICATTRIBUTE1 END || '-' ||LV_PERIODO|| '-' || CAR.ID_MESA
			|| '-' || TO_CHAR(
					PR.STARTDATE, 
					'DD/MM/YYYY'
				)) AS LOTE, 
			'' AS PARAMSTR3, 
			'' AS PARAMSTR4
		FROM TCMP.CS_DEPOSIT AS DP
			INNER JOIN TCMP.CS_POSITION AS PS
			ON DP.POSITIONSEQ = PS.RULEELEMENTOWNERSEQ
			INNER JOIN TCMP.CS_PERIOD AS PR
			ON DP.PERIODSEQ = PR.PERIODSEQ
			INNER JOIN TCMP.CS_EARNINGCODE AS ER
			ON DP.EARNINGCODEID = ER.EARNINGCODEID
			INNER JOIN EXT.TB_SUCACT_PRD SA
			ON TO_INT(PS.GENERICATTRIBUTE1) = SA.ID_SUCURSAL
			INNER JOIN EXT.TB_CARGOS_WKF CAR
			ON CAR.ID_CARGO = PS.GENERICATTRIBUTE3
			INNER JOIN EXT.TB_SUCURSAL_WKF SUC
			ON SUC.ID_TIPO_MESA = CAR.ID_TIPO_MESA
			AND SUC.ID_SUCURSAL = PS.GENERICATTRIBUTE1
		WHERE 1 = 1
			AND DP.PIPELINERUNSEQ = :LV_LASTPIPE
			AND DP.PERIODSEQ = :vPeriodSeq
			AND DP.EARNINGCODEID IN ('P0139', 'P0162', 'P0316')
			AND PS.REMOVEDATE = '2200-01-01 00:00:00.000000000'
			-- AND PS.ISLAST = 1 -- Quit to validate vers
			AND PS.EFFECTIVESTARTDATE <= :LV_DATE_PERIODSEQ -- Add to validate vers
			AND :LV_DATE_PERIODSEQ < PS.EFFECTIVEENDDATE -- Ad to validate vers
			AND PR.REMOVEDATE = '2200-01-01 00:00:00.000000000'
			AND ER.REMOVEDATE = '2200-01-01 00:00:00.000000000'
			AND DP.GENERICNUMBER6 >= 1 -- Add to validate rest
			AND EARNINGGROUPID IN ('COMISION_ROJA', 'COMISION_AZUL', 'COMISION_EXPRESS', 'COMISION_CITYCLUB')
			AND SA.ESTATUS = TRUE
            GROUP BY PR.STARTDATE, PS.NAME, PS.GENERICATTRIBUTE1, CAR.ID_MESA, DP.EARNINGCODEID, DP.VALUE, DP.GENERICNUMBER1, PR.STARTDATE, ER.DESCRIPTION
		) A
		GROUP BY PERIODO, ID_EMPLEADO, ID_SUCURSAL, ID_MESA, ID_CONCEPTO, FIJO, PARAMNUM2, PARAMNUM3, FECHA_ENVIO, PARAMDATE2, REFERENCIA, LOTE, PARAMSTR3, PARAMSTR4;

	-- ('P0161')
	INSERT INTO EXT.TB_INCIDENCIA_AUX
		SELECT LV_IDTRANSACCION AS ID_TRANSACCION, PERIODO, ID_EMPLEADO, ID_SUCURSAL, ID_MESA, ID_CONCEPTO, FIJO, SUM(A.IMPORTE), SUM(PARAMNUM2), PARAMNUM3, FECHA_ENVIO, PARAMDATE2, REFERENCIA, LOTE, PARAMSTR3, PARAMSTR4
		FROM (
			SELECT DISTINCT LV_IDTRANSACCION AS ID_TRANSACCION, 
				TO_CHAR(
					PR.STARTDATE, 
					'YYYYMMDD'
				) AS PERIODO, 
			PS.NAME AS ID_EMPLEADO, 
			PS.GENERICATTRIBUTE1 AS ID_SUCURSAL, 
			CAR.ID_MESA AS ID_MESA, 
			DP.EARNINGCODEID AS ID_CONCEPTO, 
			'0' AS FIJO, 
			TO_DECIMAL(DP.VALUE,12,2) AS IMPORTE, 
			TO_DECIMAL(DP.GENERICNUMBER1,5,2) AS PARAMNUM2, 
			'0' AS PARAMNUM3, 
			TO_CHAR(
				PR.STARTDATE, 
				'YYYY-MM-DD'
			) AS FECHA_ENVIO, 
			'' AS PARAMDATE2, 
			ER.DESCRIPTION AS REFERENCIA, 
			TO_CHAR('COM-' || CASE WHEN LENGTH (PS.GENERICATTRIBUTE1) = 1 THEN '000'|| PS.GENERICATTRIBUTE1
			WHEN LENGTH (PS.GENERICATTRIBUTE1) = 2 THEN '00'|| PS.GENERICATTRIBUTE1 
			WHEN LENGTH (PS.GENERICATTRIBUTE1) = 3 THEN '0'|| PS.GENERICATTRIBUTE1 
			ELSE PS.GENERICATTRIBUTE1 END || '-' ||LV_PERIODO|| '-' || CAR.ID_MESA
			|| '-' || TO_CHAR(
					PR.STARTDATE, 
					'DD/MM/YYYY'
				)) AS LOTE, 
			'' AS PARAMSTR3, 
			'' AS PARAMSTR4
		FROM TCMP.CS_DEPOSIT AS DP
			INNER JOIN TCMP.CS_POSITION AS PS
			ON DP.POSITIONSEQ = PS.RULEELEMENTOWNERSEQ
			INNER JOIN TCMP.CS_PERIOD AS PR
			ON DP.PERIODSEQ = PR.PERIODSEQ
			INNER JOIN TCMP.CS_EARNINGCODE AS ER
			ON DP.EARNINGCODEID = ER.EARNINGCODEID
			INNER JOIN EXT.TB_SUCACT_PRD SA
			ON TO_INT(PS.GENERICATTRIBUTE1) = SA.ID_SUCURSAL
			INNER JOIN EXT.TB_CARGOS_WKF CAR
			ON CAR.ID_CARGO = PS.GENERICATTRIBUTE3
			INNER JOIN EXT.TB_SUCURSAL_WKF SUC
			ON SUC.ID_TIPO_MESA = CAR.ID_TIPO_MESA
			AND SUC.ID_SUCURSAL = PS.GENERICATTRIBUTE1
		WHERE 1 = 1
			AND DP.PIPELINERUNSEQ = :LV_LASTPIPE
			AND DP.PERIODSEQ = :vPeriodSeq
			AND DP.EARNINGCODEID IN ('P0161')
			AND PS.REMOVEDATE = '2200-01-01 00:00:00.000000000'
			-- AND PS.ISLAST = 1 -- quit
			AND PS.EFFECTIVESTARTDATE <= :LV_DATE_PERIODSEQ -- periodseq date
			AND :LV_DATE_PERIODSEQ < PS.EFFECTIVEENDDATE 
			AND PR.REMOVEDATE = '2200-01-01 00:00:00.000000000'
			AND ER.REMOVEDATE = '2200-01-01 00:00:00.000000000'
			AND DP.GENERICNUMBER6 >= 1
			AND EARNINGGROUPID IN ('COMISION_ROJA', 'COMISION_AZUL', 'COMISION_EXPRESS', 'COMISION_CITYCLUB')
			AND SA.ESTATUS = TRUE
			GROUP BY PR.STARTDATE, PS.NAME, PS.GENERICATTRIBUTE1, CAR.ID_MESA, DP.EARNINGCODEID, DP.VALUE, DP.GENERICNUMBER1, PR.STARTDATE, ER.DESCRIPTION
		) A
		GROUP BY PERIODO, ID_EMPLEADO, ID_SUCURSAL, ID_MESA, ID_CONCEPTO, FIJO, PARAMNUM3, FECHA_ENVIO, PARAMDATE2, REFERENCIA, LOTE, PARAMSTR3, PARAMSTR4;
	
	-- (P0163)
	INSERT INTO EXT.TB_INCIDENCIA_AUX
		SELECT LV_IDTRANSACCION AS ID_TRANSACCION, PERIODO, ID_EMPLEADO, ID_SUCURSAL, ID_MESA, ID_CONCEPTO, FIJO, SUM(A.IMPORTE), SUM(PARAMNUM2), PARAMNUM3, FECHA_ENVIO, PARAMDATE2, REFERENCIA, LOTE, PARAMSTR3, PARAMSTR4
		FROM (
			SELECT DISTINCT LV_IDTRANSACCION AS ID_TRANSACCION, 
				TO_CHAR(
					PR.STARTDATE, 
					'YYYYMMDD'
				) AS PERIODO, 
			PS.NAME AS ID_EMPLEADO, 
			PS.GENERICATTRIBUTE1 AS ID_SUCURSAL, 
			CAR.ID_MESA AS ID_MESA, 
			DP.EARNINGCODEID AS ID_CONCEPTO, 
			'0' AS FIJO, 
			TO_DECIMAL(DP.VALUE,12,2) AS IMPORTE, 
			TO_DECIMAL(DP.GENERICNUMBER1,5,2) AS PARAMNUM2, 
			'0' AS PARAMNUM3, 
			TO_CHAR(
				PR.STARTDATE, 
				'YYYY-MM-DD'
			) AS FECHA_ENVIO, 
			'' AS PARAMDATE2, 
			ER.DESCRIPTION AS REFERENCIA, 
			TO_CHAR('COM-' || CASE WHEN LENGTH (PS.GENERICATTRIBUTE1) = 1 THEN '000'|| PS.GENERICATTRIBUTE1
			WHEN LENGTH (PS.GENERICATTRIBUTE1) = 2 THEN '00'|| PS.GENERICATTRIBUTE1 
			WHEN LENGTH (PS.GENERICATTRIBUTE1) = 3 THEN '0'|| PS.GENERICATTRIBUTE1 
			ELSE PS.GENERICATTRIBUTE1 END || '-' ||LV_PERIODO|| '-' || CAR.ID_MESA
			|| '-' || TO_CHAR(
					PR.STARTDATE, 
					'DD/MM/YYYY'
				)) AS LOTE, 
			'' AS PARAMSTR3, 
			'' AS PARAMSTR4
		FROM TCMP.CS_DEPOSIT AS DP
			INNER JOIN TCMP.CS_POSITION AS PS
			ON DP.POSITIONSEQ = PS.RULEELEMENTOWNERSEQ
			INNER JOIN TCMP.CS_PERIOD AS PR
			ON DP.PERIODSEQ = PR.PERIODSEQ
			INNER JOIN TCMP.CS_EARNINGCODE AS ER
			ON DP.EARNINGCODEID = ER.EARNINGCODEID
			INNER JOIN EXT.TB_SUCACT_PRD SA
			ON TO_INT(PS.GENERICATTRIBUTE1) = SA.ID_SUCURSAL
			INNER JOIN EXT.TB_CARGOS_WKF CAR
			ON CAR.ID_CARGO = PS.GENERICATTRIBUTE3
			INNER JOIN EXT.TB_SUCURSAL_WKF SUC
			ON SUC.ID_TIPO_MESA = CAR.ID_TIPO_MESA
			AND SUC.ID_SUCURSAL = PS.GENERICATTRIBUTE1
		WHERE 1 = 1
			AND DP.PIPELINERUNSEQ = :LV_LASTPIPE
			AND DP.PERIODSEQ = :vPeriodSeq
			AND DP.EARNINGCODEID IN ('P0163')
			AND PS.REMOVEDATE = '2200-01-01 00:00:00.000000000'
			-- AND PS.ISLAST = 1 -- quit
			AND PS.EFFECTIVESTARTDATE <= :LV_DATE_PERIODSEQ -- periodseq date
			AND :LV_DATE_PERIODSEQ < PS.EFFECTIVEENDDATE 
			AND PR.REMOVEDATE = '2200-01-01 00:00:00.000000000'
			AND ER.REMOVEDATE = '2200-01-01 00:00:00.000000000'
			AND DP.GENERICNUMBER6 >= 1
			AND EARNINGGROUPID IN ('COMISION_ROJA', 'COMISION_AZUL', 'COMISION_EXPRESS', 'COMISION_CITYCLUB')
			AND SA.ESTATUS = TRUE
			GROUP BY PR.STARTDATE, PS.NAME, PS.GENERICATTRIBUTE1, CAR.ID_MESA, DP.EARNINGCODEID, DP.VALUE, DP.GENERICNUMBER1, PR.STARTDATE, ER.DESCRIPTION
		) A
		GROUP BY PERIODO, ID_EMPLEADO, ID_SUCURSAL, ID_MESA, ID_CONCEPTO, FIJO, PARAMNUM3, FECHA_ENVIO, PARAMDATE2, REFERENCIA, LOTE, PARAMSTR3, PARAMSTR4;
		
	-- 'P0167'
	INSERT INTO EXT.TB_INCIDENCIA_AUX
		SELECT LV_IDTRANSACCION AS ID_TRANSACCION, PERIODO, ID_EMPLEADO, ID_SUCURSAL, ID_MESA, ID_CONCEPTO, FIJO, SUM(A.IMPORTE), SUM(PARAMNUM2), PARAMNUM3, FECHA_ENVIO, PARAMDATE2, REFERENCIA, LOTE, PARAMSTR3, PARAMSTR4
		FROM (
			SELECT DISTINCT LV_IDTRANSACCION AS ID_TRANSACCION, 
			TO_CHAR(
					PR.STARTDATE, 
					'YYYYMMDD'
				) AS PERIODO, 
			PS.NAME AS ID_EMPLEADO, 
			PS.GENERICATTRIBUTE1 AS ID_SUCURSAL, 
			CAR.ID_MESA AS ID_MESA, 
			DP.EARNINGCODEID AS ID_CONCEPTO, 
			'0' AS FIJO, 
			TO_DECIMAL(DP.GENERICNUMBER1,5,2) AS IMPORTE, 
			TO_DECIMAL(DP.VALUE,12,2) AS PARAMNUM2, 
			'0' AS PARAMNUM3, 
			TO_CHAR(
				PR.STARTDATE, 
				'YYYY-MM-DD'
			) AS FECHA_ENVIO, 
			'' AS PARAMDATE2, 
			ER.DESCRIPTION AS REFERENCIA, 
			TO_CHAR('COM-' || CASE WHEN LENGTH (PS.GENERICATTRIBUTE1) = 1 THEN '000'|| PS.GENERICATTRIBUTE1
			WHEN LENGTH (PS.GENERICATTRIBUTE1) = 2 THEN '00'|| PS.GENERICATTRIBUTE1 
			WHEN LENGTH (PS.GENERICATTRIBUTE1) = 3 THEN '0'|| PS.GENERICATTRIBUTE1 
			ELSE PS.GENERICATTRIBUTE1 END || '-' ||LV_PERIODO|| '-' || CAR.ID_MESA
			|| '-' || TO_CHAR(
					PR.STARTDATE, 
					'DD/MM/YYYY'
				)) AS LOTE, 
			'' AS PARAMSTR3, 
			'' AS PARAMSTR4
		FROM TCMP.CS_DEPOSIT AS DP
			INNER JOIN TCMP.CS_POSITION AS PS
			ON DP.POSITIONSEQ = PS.RULEELEMENTOWNERSEQ
			INNER JOIN TCMP.CS_PERIOD AS PR
			ON DP.PERIODSEQ = PR.PERIODSEQ
			INNER JOIN TCMP.CS_EARNINGCODE AS ER
			ON DP.EARNINGCODEID = ER.EARNINGCODEID
			INNER JOIN EXT.TB_SUCACT_PRD SA
			ON TO_INT(PS.GENERICATTRIBUTE1) = SA.ID_SUCURSAL
			INNER JOIN EXT.TB_CARGOS_WKF CAR
			ON CAR.ID_CARGO = PS.GENERICATTRIBUTE3
			INNER JOIN EXT.TB_SUCURSAL_WKF SUC
			ON SUC.ID_TIPO_MESA = CAR.ID_TIPO_MESA
			AND SUC.ID_SUCURSAL = PS.GENERICATTRIBUTE1
		WHERE 1 = 1
			AND DP.PIPELINERUNSEQ = :LV_LASTPIPE
			AND DP.PERIODSEQ = :vPeriodSeq
			AND DP.EARNINGCODEID IN ('P0167')
			AND PS.REMOVEDATE = '2200-01-01 00:00:00.000000000'
			-- AND PS.ISLAST = 1 -- Quit
			AND PS.EFFECTIVESTARTDATE <= :LV_DATE_PERIODSEQ -- periodseq date
			AND :LV_DATE_PERIODSEQ < PS.EFFECTIVEENDDATE 
			AND PR.REMOVEDATE = '2200-01-01 00:00:00.000000000'
			AND ER.REMOVEDATE = '2200-01-01 00:00:00.000000000'
			AND DP.VALUE > 0
			AND EARNINGGROUPID IN ('COMISION_ROJA', 'COMISION_AZUL', 'COMISION_EXPRESS', 'COMISION_CITYCLUB')
			AND SA.ESTATUS = TRUE
			AND DP.GENERICNUMBER6 >= 1
			GROUP BY PR.STARTDATE, PS.NAME, PS.GENERICATTRIBUTE1, CAR.ID_MESA, DP.EARNINGCODEID, DP.GENERICNUMBER1, DP.VALUE, PR.STARTDATE, ER.DESCRIPTION
		) A
		GROUP BY PERIODO, ID_EMPLEADO, ID_SUCURSAL, ID_MESA, ID_CONCEPTO, FIJO, PARAMNUM3, FECHA_ENVIO, PARAMDATE2, REFERENCIA, LOTE, PARAMSTR3, PARAMSTR4;
		
	-- 'P0168'
	INSERT INTO EXT.TB_INCIDENCIA_AUX
		SELECT LV_IDTRANSACCION AS ID_TRANSACCION, PERIODO, ID_EMPLEADO, ID_SUCURSAL, ID_MESA, ID_CONCEPTO, FIJO, SUM(A.IMPORTE), SUM(PARAMNUM2), PARAMNUM3, FECHA_ENVIO, PARAMDATE2, REFERENCIA, LOTE, PARAMSTR3, PARAMSTR4
		FROM (
			SELECT DISTINCT LV_IDTRANSACCION AS ID_TRANSACCION, 
			TO_CHAR(
					PR.STARTDATE, 
					'YYYYMMDD'
				) AS PERIODO, 
			PS.NAME AS ID_EMPLEADO, 
			PS.GENERICATTRIBUTE1 AS ID_SUCURSAL, 
			CAR.ID_MESA AS ID_MESA, 
			DP.EARNINGCODEID AS ID_CONCEPTO, 
			'0' AS FIJO, 
			TO_DECIMAL(DP.GENERICNUMBER1,5,2) AS IMPORTE, 
			TO_DECIMAL(DP.VALUE,12,2) AS PARAMNUM2, 
			'0' AS PARAMNUM3, 
			TO_CHAR(
				PR.STARTDATE, 
				'YYYY-MM-DD'
			) AS FECHA_ENVIO, 
			'' AS PARAMDATE2, 
			ER.DESCRIPTION AS REFERENCIA, 
			TO_CHAR('COM-' || CASE WHEN LENGTH (PS.GENERICATTRIBUTE1) = 1 THEN '000'|| PS.GENERICATTRIBUTE1
			WHEN LENGTH (PS.GENERICATTRIBUTE1) = 2 THEN '00'|| PS.GENERICATTRIBUTE1 
			WHEN LENGTH (PS.GENERICATTRIBUTE1) = 3 THEN '0'|| PS.GENERICATTRIBUTE1 
			ELSE PS.GENERICATTRIBUTE1 END || '-' ||LV_PERIODO|| '-' || CAR.ID_MESA
			|| '-' || TO_CHAR(
					PR.STARTDATE, 
					'DD/MM/YYYY'
				)) AS LOTE, 
			'' AS PARAMSTR3, 
			'' AS PARAMSTR4
		FROM TCMP.CS_DEPOSIT AS DP
			INNER JOIN TCMP.CS_POSITION AS PS
			ON DP.POSITIONSEQ = PS.RULEELEMENTOWNERSEQ
			INNER JOIN TCMP.CS_PERIOD AS PR
			ON DP.PERIODSEQ = PR.PERIODSEQ
			INNER JOIN TCMP.CS_EARNINGCODE AS ER
			ON DP.EARNINGCODEID = ER.EARNINGCODEID
			INNER JOIN EXT.TB_SUCACT_PRD SA
			ON TO_INT(PS.GENERICATTRIBUTE1) = SA.ID_SUCURSAL
			INNER JOIN EXT.TB_CARGOS_WKF CAR
			ON CAR.ID_CARGO = PS.GENERICATTRIBUTE3
			INNER JOIN EXT.TB_SUCURSAL_WKF SUC
			ON SUC.ID_TIPO_MESA = CAR.ID_TIPO_MESA
			AND SUC.ID_SUCURSAL = PS.GENERICATTRIBUTE1
		WHERE 1 = 1
			AND DP.PIPELINERUNSEQ = :LV_LASTPIPE
			AND DP.PERIODSEQ = :vPeriodSeq
			AND DP.EARNINGCODEID IN ('P0168')
			AND PS.REMOVEDATE = '2200-01-01 00:00:00.000000000'
			-- AND PS.ISLAST = 1 -- Quit
			AND PS.EFFECTIVESTARTDATE <= :LV_DATE_PERIODSEQ -- periodseq date
			AND :LV_DATE_PERIODSEQ < PS.EFFECTIVEENDDATE 
			AND PR.REMOVEDATE = '2200-01-01 00:00:00.000000000'
			AND ER.REMOVEDATE = '2200-01-01 00:00:00.000000000'
			AND DP.VALUE > 0
			AND EARNINGGROUPID IN ('COMISION_ROJA', 'COMISION_AZUL', 'COMISION_EXPRESS', 'COMISION_CITYCLUB')
			AND SA.ESTATUS = TRUE
			AND DP.GENERICNUMBER6 >= 1
			GROUP BY PR.STARTDATE, PS.NAME, PS.GENERICATTRIBUTE1, CAR.ID_MESA, DP.EARNINGCODEID, DP.GENERICNUMBER1, DP.VALUE, PR.STARTDATE, ER.DESCRIPTION
		) A
		GROUP BY PERIODO, ID_EMPLEADO, ID_SUCURSAL, ID_MESA, ID_CONCEPTO, FIJO, PARAMNUM3, FECHA_ENVIO, PARAMDATE2, REFERENCIA, LOTE, PARAMSTR3, PARAMSTR4;
	
	-- 'P0177'
	INSERT INTO EXT.TB_INCIDENCIA_AUX
		SELECT LV_IDTRANSACCION AS ID_TRANSACCION, PERIODO, ID_EMPLEADO, ID_SUCURSAL, ID_MESA, ID_CONCEPTO, FIJO, SUM(A.IMPORTE), SUM(PARAMNUM2), PARAMNUM3, FECHA_ENVIO, PARAMDATE2, REFERENCIA, LOTE, PARAMSTR3, PARAMSTR4
		FROM (
			SELECT DISTINCT LV_IDTRANSACCION AS ID_TRANSACCION, 
			TO_CHAR(
					PR.STARTDATE, 
					'YYYYMMDD'
				) AS PERIODO, 
			PS.NAME AS ID_EMPLEADO, 
			PS.GENERICATTRIBUTE1 AS ID_SUCURSAL, 
			CAR.ID_MESA AS ID_MESA, 
			DP.EARNINGCODEID AS ID_CONCEPTO, 
			'0' AS FIJO, 
			TO_DECIMAL(DP.GENERICNUMBER1,5,2) AS IMPORTE, 
			TO_DECIMAL(DP.VALUE,12,2) AS PARAMNUM2, 
			'0' AS PARAMNUM3, 
			TO_CHAR(
				PR.STARTDATE, 
				'YYYY-MM-DD'
			) AS FECHA_ENVIO, 
			'' AS PARAMDATE2, 
			ER.DESCRIPTION AS REFERENCIA, 
			TO_CHAR('COM-' || CASE WHEN LENGTH (PS.GENERICATTRIBUTE1) = 1 THEN '000'|| PS.GENERICATTRIBUTE1
			WHEN LENGTH (PS.GENERICATTRIBUTE1) = 2 THEN '00'|| PS.GENERICATTRIBUTE1 
			WHEN LENGTH (PS.GENERICATTRIBUTE1) = 3 THEN '0'|| PS.GENERICATTRIBUTE1 
			ELSE PS.GENERICATTRIBUTE1 END || '-' ||LV_PERIODO|| '-' || CAR.ID_MESA
			|| '-' || TO_CHAR(
					PR.STARTDATE, 
					'DD/MM/YYYY'
				)) AS LOTE, 
			'' AS PARAMSTR3, 
			'' AS PARAMSTR4
		FROM TCMP.CS_DEPOSIT AS DP
			INNER JOIN TCMP.CS_POSITION AS PS
			ON DP.POSITIONSEQ = PS.RULEELEMENTOWNERSEQ
			INNER JOIN TCMP.CS_PERIOD AS PR
			ON DP.PERIODSEQ = PR.PERIODSEQ
			INNER JOIN TCMP.CS_EARNINGCODE AS ER
			ON DP.EARNINGCODEID = ER.EARNINGCODEID
			INNER JOIN EXT.TB_SUCACT_PRD SA
			ON TO_INT(PS.GENERICATTRIBUTE1) = SA.ID_SUCURSAL
			INNER JOIN EXT.TB_CARGOS_WKF CAR
			ON CAR.ID_CARGO = PS.GENERICATTRIBUTE3
			INNER JOIN EXT.TB_SUCURSAL_WKF SUC
			ON SUC.ID_TIPO_MESA = CAR.ID_TIPO_MESA
			AND SUC.ID_SUCURSAL = PS.GENERICATTRIBUTE1
		WHERE 1 = 1
			AND DP.PIPELINERUNSEQ = :LV_LASTPIPE
			AND DP.PERIODSEQ = :vPeriodSeq
			AND DP.EARNINGCODEID IN ('P0177')
			AND PS.REMOVEDATE = '2200-01-01 00:00:00.000000000'
			-- AND PS.ISLAST = 1 -- Quit
			AND PS.EFFECTIVESTARTDATE <= :LV_DATE_PERIODSEQ -- periodseq date
			AND :LV_DATE_PERIODSEQ < PS.EFFECTIVEENDDATE 
			AND PR.REMOVEDATE = '2200-01-01 00:00:00.000000000'
			AND ER.REMOVEDATE = '2200-01-01 00:00:00.000000000'
			AND DP.VALUE > 0
			AND EARNINGGROUPID IN ('COMISION_ROJA', 'COMISION_AZUL', 'COMISION_EXPRESS', 'COMISION_CITYCLUB')
			AND SA.ESTATUS = TRUE
			AND DP.GENERICNUMBER6 >= 1
			GROUP BY PR.STARTDATE, PS.NAME, PS.GENERICATTRIBUTE1, CAR.ID_MESA, DP.EARNINGCODEID, DP.GENERICNUMBER1, DP.VALUE, PR.STARTDATE, ER.DESCRIPTION
		) A
		GROUP BY PERIODO, ID_EMPLEADO, ID_SUCURSAL, ID_MESA, ID_CONCEPTO, FIJO, PARAMNUM3, FECHA_ENVIO, PARAMDATE2, REFERENCIA, LOTE, PARAMSTR3, PARAMSTR4;
	
	/*
	-- NUEVO INGRESO ('P0139', 'P0162', 'P0316')
	INSERT INTO EXT.TB_INCIDENCIA_AUX
		SELECT LV_IDTRANSACCION AS ID_TRANSACCION, PERIODO, ID_EMPLEADO, ID_SUCURSAL, ID_MESA, ID_CONCEPTO, FIJO, SUM(A.IMPORTE), PARAMNUM2, PARAMNUM3, FECHA_ENVIO, PARAMDATE2, REFERENCIA, LOTE, PARAMSTR3, PARAMSTR4
		FROM (
		    SELECT DISTINCT LV_IDTRANSACCION AS ID_TRANSACCION, 
			TO_CHAR(
					PR.STARTDATE, 
					'YYYYMMDD'
				) AS PERIODO, 
			PS.NAME AS ID_EMPLEADO, 
			PS.GENERICATTRIBUTE1 AS ID_SUCURSAL, 
			CAR.ID_MESA AS ID_MESA, 
			DP.EARNINGCODEID AS ID_CONCEPTO, 
			'0' AS FIJO, 
			TO_DECIMAL(DP.VALUE,12,2) AS IMPORTE, 
			'0' AS PARAMNUM2, 
			'0' AS PARAMNUM3, 
			TO_CHAR(
				PR.STARTDATE, 
				'YYYY-MM-DD'
			) AS FECHA_ENVIO, 
			'' AS PARAMDATE2, 
			ER.DESCRIPTION AS REFERENCIA, 
			TO_CHAR('COM-' || CASE WHEN LENGTH (PS.GENERICATTRIBUTE1) = 1 THEN '000'|| PS.GENERICATTRIBUTE1
			WHEN LENGTH (PS.GENERICATTRIBUTE1) = 2 THEN '00'|| PS.GENERICATTRIBUTE1 
			WHEN LENGTH (PS.GENERICATTRIBUTE1) = 3 THEN '0'|| PS.GENERICATTRIBUTE1 
			ELSE PS.GENERICATTRIBUTE1 END || '-' ||LV_PERIODO|| '-' || CAR.ID_MESA
			|| '-' || TO_CHAR(
					PR.STARTDATE, 
					'DD/MM/YYYY'
				)) AS LOTE, 
			'' AS PARAMSTR3, 
			'' AS PARAMSTR4
		FROM TCMP.CS_DEPOSIT AS DP
			INNER JOIN TCMP.CS_POSITION AS PS
			ON DP.POSITIONSEQ = PS.RULEELEMENTOWNERSEQ
			INNER JOIN TCMP.CS_PERIOD AS PR
			ON DP.PERIODSEQ = PR.PERIODSEQ
			INNER JOIN TCMP.CS_EARNINGCODE AS ER
			ON DP.EARNINGCODEID = ER.EARNINGCODEID
			INNER JOIN EXT.TB_SUCACT_PRD SA
			ON TO_INT(PS.GENERICATTRIBUTE1) = SA.ID_SUCURSAL
			INNER JOIN EXT.TB_CARGOS_WKF CAR
			ON CAR.ID_CARGO = PS.GENERICATTRIBUTE3
			INNER JOIN EXT.TB_SUCURSAL_WKF SUC
			ON SUC.ID_TIPO_MESA = CAR.ID_TIPO_MESA
			AND SUC.ID_SUCURSAL = PS.GENERICATTRIBUTE1
		WHERE 1 = 1
			AND DP.PIPELINERUNSEQ = :LV_LASTPIPE
			AND DP.PERIODSEQ = :vPeriodSeq
			AND DP.EARNINGCODEID IN ('P0139', 'P0162', 'P0316')
			AND PS.REMOVEDATE = '2200-01-01 00:00:00.000000000'
			-- AND PS.ISLAST = 1 -- quit
			AND PS.EFFECTIVESTARTDATE <= :LV_DATE_PERIODSEQ -- periodseq date
			AND :LV_DATE_PERIODSEQ < PS.EFFECTIVEENDDATE 
			AND PR.REMOVEDATE = '2200-01-01 00:00:00.000000000'
			AND ER.REMOVEDATE = '2200-01-01 00:00:00.000000000'
			AND SA.ESTATUS = TRUE
			AND EARNINGGROUPID IN ('COMISION_ROJA', 'COMISION_AZUL', 'COMISION_EXPRESS', 'COMISION_CITYCLUB')
			AND DP.POSITIONSEQ IN (
				SELECT DISTINCT POSITIONSEQ
				FROM TCMP.CS_DEPOSIT
				WHERE PIPELINERUNSEQ = :LV_LASTPIPE
				AND PERIODSEQ = :vPeriodSeq
				AND GENERICNUMBER6 = 0
				AND GENERICNUMBER5 = 1
			)
            GROUP BY PR.STARTDATE, PS.NAME, PS.GENERICATTRIBUTE1, CAR.ID_MESA, DP.EARNINGCODEID, DP.VALUE, DP.GENERICNUMBER1, PR.STARTDATE, ER.DESCRIPTION
		) A
		GROUP BY PERIODO, ID_EMPLEADO, ID_SUCURSAL, ID_MESA, ID_CONCEPTO, FIJO, PARAMNUM2, PARAMNUM3, FECHA_ENVIO, PARAMDATE2, REFERENCIA, LOTE, PARAMSTR3, PARAMSTR4;
	
	-- NUEVO INGRESO ('P0161')
	INSERT INTO EXT.TB_INCIDENCIA_AUX
		SELECT LV_IDTRANSACCION AS ID_TRANSACCION, PERIODO, ID_EMPLEADO, ID_SUCURSAL, ID_MESA, ID_CONCEPTO, FIJO, SUM(A.IMPORTE), SUM(PARAMNUM2), PARAMNUM3, FECHA_ENVIO, PARAMDATE2, REFERENCIA, LOTE, PARAMSTR3, PARAMSTR4
		FROM (
			SELECT DISTINCT LV_IDTRANSACCION AS ID_TRANSACCION, 
				TO_CHAR(
					PR.STARTDATE, 
					'YYYYMMDD'
				) AS PERIODO, 
			PS.NAME AS ID_EMPLEADO, 
			PS.GENERICATTRIBUTE1 AS ID_SUCURSAL, 
			CAR.ID_MESA AS ID_MESA, 
			DP.EARNINGCODEID AS ID_CONCEPTO, 
			'0' AS FIJO, 
			TO_DECIMAL(DP.VALUE,12,2) AS IMPORTE, 
			TO_DECIMAL(DP.GENERICNUMBER1,5,2) AS PARAMNUM2, 
			'0' AS PARAMNUM3, 
			TO_CHAR(
				PR.STARTDATE, 
				'YYYY-MM-DD'
			) AS FECHA_ENVIO, 
			'' AS PARAMDATE2, 
			ER.DESCRIPTION AS REFERENCIA, 
			TO_CHAR('COM-' || CASE WHEN LENGTH (PS.GENERICATTRIBUTE1) = 1 THEN '000'|| PS.GENERICATTRIBUTE1
			WHEN LENGTH (PS.GENERICATTRIBUTE1) = 2 THEN '00'|| PS.GENERICATTRIBUTE1 
			WHEN LENGTH (PS.GENERICATTRIBUTE1) = 3 THEN '0'|| PS.GENERICATTRIBUTE1 
			ELSE PS.GENERICATTRIBUTE1 END || '-' ||LV_PERIODO|| '-' || CAR.ID_MESA
			|| '-' || TO_CHAR(
					PR.STARTDATE, 
					'DD/MM/YYYY'
				)) AS LOTE, 
			'' AS PARAMSTR3, 
			'' AS PARAMSTR4
		FROM TCMP.CS_DEPOSIT AS DP
			INNER JOIN TCMP.CS_POSITION AS PS
			ON DP.POSITIONSEQ = PS.RULEELEMENTOWNERSEQ
			INNER JOIN TCMP.CS_PERIOD AS PR
			ON DP.PERIODSEQ = PR.PERIODSEQ
			INNER JOIN TCMP.CS_EARNINGCODE AS ER
			ON DP.EARNINGCODEID = ER.EARNINGCODEID
			INNER JOIN EXT.TB_SUCACT_PRD SA
			ON TO_INT(PS.GENERICATTRIBUTE1) = SA.ID_SUCURSAL
			INNER JOIN EXT.TB_CARGOS_WKF CAR
			ON CAR.ID_CARGO = PS.GENERICATTRIBUTE3
			INNER JOIN EXT.TB_SUCURSAL_WKF SUC
			ON SUC.ID_TIPO_MESA = CAR.ID_TIPO_MESA
			AND SUC.ID_SUCURSAL = PS.GENERICATTRIBUTE1
		WHERE 1 = 1
			AND DP.PIPELINERUNSEQ = :LV_LASTPIPE
			AND DP.PERIODSEQ = :vPeriodSeq
			AND DP.EARNINGCODEID IN ('P0161')
			AND PS.REMOVEDATE = '2200-01-01 00:00:00.000000000'
			-- AND PS.ISLAST = 1 -- quit
			AND PS.EFFECTIVESTARTDATE <= :LV_DATE_PERIODSEQ -- periodseq date
			AND :LV_DATE_PERIODSEQ < PS.EFFECTIVEENDDATE 
			AND PR.REMOVEDATE = '2200-01-01 00:00:00.000000000'
			AND ER.REMOVEDATE = '2200-01-01 00:00:00.000000000'
			AND SA.ESTATUS = TRUE
			AND EARNINGGROUPID IN ('COMISION_ROJA', 'COMISION_AZUL', 'COMISION_EXPRESS', 'COMISION_CITYCLUB')
			AND DP.POSITIONSEQ IN (
				SELECT DISTINCT POSITIONSEQ
				FROM TCMP.CS_DEPOSIT
				WHERE PIPELINERUNSEQ = :LV_LASTPIPE
				AND PERIODSEQ = :vPeriodSeq
				AND GENERICNUMBER6 = 0
				AND GENERICNUMBER5 = 1
			)
			GROUP BY PR.STARTDATE, PS.NAME, PS.GENERICATTRIBUTE1, CAR.ID_MESA, DP.EARNINGCODEID, DP.VALUE, DP.GENERICNUMBER1, PR.STARTDATE, ER.DESCRIPTION
		) A
		GROUP BY PERIODO, ID_EMPLEADO, ID_SUCURSAL, ID_MESA, ID_CONCEPTO, FIJO, PARAMNUM3, FECHA_ENVIO, PARAMDATE2, REFERENCIA, LOTE, PARAMSTR3, PARAMSTR4;
		
	-- NUEVO INGRESO ('P0163')
	INSERT INTO EXT.TB_INCIDENCIA_AUX
		SELECT LV_IDTRANSACCION AS ID_TRANSACCION, PERIODO, ID_EMPLEADO, ID_SUCURSAL, ID_MESA, ID_CONCEPTO, FIJO, SUM(A.IMPORTE), SUM(PARAMNUM2), PARAMNUM3, FECHA_ENVIO, PARAMDATE2, REFERENCIA, LOTE, PARAMSTR3, PARAMSTR4
		FROM (
			SELECT DISTINCT LV_IDTRANSACCION AS ID_TRANSACCION, 
				TO_CHAR(
					PR.STARTDATE, 
					'YYYYMMDD'
				) AS PERIODO, 
			PS.NAME AS ID_EMPLEADO, 
			PS.GENERICATTRIBUTE1 AS ID_SUCURSAL, 
			CAR.ID_MESA AS ID_MESA, 
			DP.EARNINGCODEID AS ID_CONCEPTO, 
			'0' AS FIJO, 
			TO_DECIMAL(DP.VALUE,12,2) AS IMPORTE, 
			TO_DECIMAL(DP.GENERICNUMBER1,5,2) AS PARAMNUM2, 
			'0' AS PARAMNUM3, 
			TO_CHAR(
				PR.STARTDATE, 
				'YYYY-MM-DD'
			) AS FECHA_ENVIO, 
			'' AS PARAMDATE2, 
			ER.DESCRIPTION AS REFERENCIA, 
			TO_CHAR('COM-' || CASE WHEN LENGTH (PS.GENERICATTRIBUTE1) = 1 THEN '000'|| PS.GENERICATTRIBUTE1
			WHEN LENGTH (PS.GENERICATTRIBUTE1) = 2 THEN '00'|| PS.GENERICATTRIBUTE1 
			WHEN LENGTH (PS.GENERICATTRIBUTE1) = 3 THEN '0'|| PS.GENERICATTRIBUTE1 
			ELSE PS.GENERICATTRIBUTE1 END || '-' ||LV_PERIODO|| '-' || CAR.ID_MESA
			|| '-' || TO_CHAR(
					PR.STARTDATE, 
					'DD/MM/YYYY'
				)) AS LOTE, 
			'' AS PARAMSTR3, 
			'' AS PARAMSTR4
		FROM TCMP.CS_DEPOSIT AS DP
			INNER JOIN TCMP.CS_POSITION AS PS
			ON DP.POSITIONSEQ = PS.RULEELEMENTOWNERSEQ
			INNER JOIN TCMP.CS_PERIOD AS PR
			ON DP.PERIODSEQ = PR.PERIODSEQ
			INNER JOIN TCMP.CS_EARNINGCODE AS ER
			ON DP.EARNINGCODEID = ER.EARNINGCODEID
			INNER JOIN EXT.TB_SUCACT_PRD SA
			ON TO_INT(PS.GENERICATTRIBUTE1) = SA.ID_SUCURSAL
			INNER JOIN EXT.TB_CARGOS_WKF CAR
			ON CAR.ID_CARGO = PS.GENERICATTRIBUTE3
			INNER JOIN EXT.TB_SUCURSAL_WKF SUC
			ON SUC.ID_TIPO_MESA = CAR.ID_TIPO_MESA
			AND SUC.ID_SUCURSAL = PS.GENERICATTRIBUTE1
		WHERE 1 = 1
			AND DP.PIPELINERUNSEQ = :LV_LASTPIPE
			AND DP.PERIODSEQ = :vPeriodSeq
			AND DP.EARNINGCODEID IN ('P0163')
			AND PS.REMOVEDATE = '2200-01-01 00:00:00.000000000'
			-- AND PS.ISLAST = 1 -- quit
			AND PS.EFFECTIVESTARTDATE <= :LV_DATE_PERIODSEQ -- periodseq date
			AND :LV_DATE_PERIODSEQ < PS.EFFECTIVEENDDATE 
			AND PR.REMOVEDATE = '2200-01-01 00:00:00.000000000'
			AND ER.REMOVEDATE = '2200-01-01 00:00:00.000000000'
			AND SA.ESTATUS = TRUE
			AND EARNINGGROUPID IN ('COMISION_ROJA', 'COMISION_AZUL', 'COMISION_EXPRESS', 'COMISION_CITYCLUB')
			AND DP.POSITIONSEQ IN (
				SELECT DISTINCT POSITIONSEQ
				FROM TCMP.CS_DEPOSIT
				WHERE PIPELINERUNSEQ = :LV_LASTPIPE
				AND PERIODSEQ = :vPeriodSeq
				AND GENERICNUMBER6 = 0
				AND GENERICNUMBER5 = 1
			)
			GROUP BY PR.STARTDATE, PS.NAME, PS.GENERICATTRIBUTE1, CAR.ID_MESA, DP.EARNINGCODEID, DP.VALUE, DP.GENERICNUMBER1, PR.STARTDATE, ER.DESCRIPTION
		) A
		GROUP BY PERIODO, ID_EMPLEADO, ID_SUCURSAL, ID_MESA, ID_CONCEPTO, FIJO, PARAMNUM3, FECHA_ENVIO, PARAMDATE2, REFERENCIA, LOTE, PARAMSTR3, PARAMSTR4;
		
	-- NUEVO INGRESO 'P0167'
	INSERT INTO EXT.TB_INCIDENCIA_AUX
		SELECT LV_IDTRANSACCION AS ID_TRANSACCION, PERIODO, ID_EMPLEADO, ID_SUCURSAL, ID_MESA, ID_CONCEPTO, FIJO, SUM(A.IMPORTE), SUM(PARAMNUM2), PARAMNUM3, FECHA_ENVIO, PARAMDATE2, REFERENCIA, LOTE, PARAMSTR3, PARAMSTR4
		FROM (
			SELECT DISTINCT LV_IDTRANSACCION AS ID_TRANSACCION, 
			TO_CHAR(
					PR.STARTDATE, 
					'YYYYMMDD'
				) AS PERIODO, 
			PS.NAME AS ID_EMPLEADO, 
			PS.GENERICATTRIBUTE1 AS ID_SUCURSAL, 
			CAR.ID_MESA AS ID_MESA, 
			DP.EARNINGCODEID AS ID_CONCEPTO, 
			'0' AS FIJO, 
			TO_DECIMAL(DP.GENERICNUMBER1,5,2) AS IMPORTE, 
			TO_DECIMAL(DP.VALUE,12,2) AS PARAMNUM2, 
			'0' AS PARAMNUM3, 
			TO_CHAR(
				PR.STARTDATE, 
				'YYYY-MM-DD'
			) AS FECHA_ENVIO, 
			'' AS PARAMDATE2, 
			ER.DESCRIPTION AS REFERENCIA, 
			TO_CHAR('COM-' || CASE WHEN LENGTH (PS.GENERICATTRIBUTE1) = 1 THEN '000'|| PS.GENERICATTRIBUTE1
			WHEN LENGTH (PS.GENERICATTRIBUTE1) = 2 THEN '00'|| PS.GENERICATTRIBUTE1 
			WHEN LENGTH (PS.GENERICATTRIBUTE1) = 3 THEN '0'|| PS.GENERICATTRIBUTE1 
			ELSE PS.GENERICATTRIBUTE1 END || '-' ||LV_PERIODO|| '-' || CAR.ID_MESA
			|| '-' || TO_CHAR(
					PR.STARTDATE, 
					'DD/MM/YYYY'
				)) AS LOTE, 
			'' AS PARAMSTR3, 
			'' AS PARAMSTR4
		FROM TCMP.CS_DEPOSIT AS DP
			INNER JOIN TCMP.CS_POSITION AS PS
			ON DP.POSITIONSEQ = PS.RULEELEMENTOWNERSEQ
			INNER JOIN TCMP.CS_PERIOD AS PR
			ON DP.PERIODSEQ = PR.PERIODSEQ
			INNER JOIN TCMP.CS_EARNINGCODE AS ER
			ON DP.EARNINGCODEID = ER.EARNINGCODEID
			INNER JOIN EXT.TB_SUCACT_PRD SA
			ON TO_INT(PS.GENERICATTRIBUTE1) = SA.ID_SUCURSAL
			INNER JOIN EXT.TB_CARGOS_WKF CAR
			ON CAR.ID_CARGO = PS.GENERICATTRIBUTE3
			INNER JOIN EXT.TB_SUCURSAL_WKF SUC
			ON SUC.ID_TIPO_MESA = CAR.ID_TIPO_MESA
			AND SUC.ID_SUCURSAL = PS.GENERICATTRIBUTE1
		WHERE 1 = 1
			AND DP.PIPELINERUNSEQ = :LV_LASTPIPE
			AND DP.PERIODSEQ = :vPeriodSeq
			AND DP.EARNINGCODEID IN ('P0167')
			AND PS.REMOVEDATE = '2200-01-01 00:00:00.000000000'
			-- AND PS.ISLAST = 1 -- Quit
			AND PS.EFFECTIVESTARTDATE <= :LV_DATE_PERIODSEQ -- periodseq date
			AND :LV_DATE_PERIODSEQ < PS.EFFECTIVEENDDATE 
			AND PR.REMOVEDATE = '2200-01-01 00:00:00.000000000'
			AND ER.REMOVEDATE = '2200-01-01 00:00:00.000000000'
			AND DP.VALUE > 0
			AND EARNINGGROUPID IN ('COMISION_ROJA', 'COMISION_AZUL', 'COMISION_EXPRESS', 'COMISION_CITYCLUB')
			AND SA.ESTATUS = TRUE
			AND DP.POSITIONSEQ IN (
				SELECT DISTINCT POSITIONSEQ
				FROM TCMP.CS_DEPOSIT
				WHERE PIPELINERUNSEQ = :LV_LASTPIPE
				AND PERIODSEQ = :vPeriodSeq
				AND GENERICNUMBER6 = 0
				AND GENERICNUMBER5 = 1
			)
			GROUP BY PR.STARTDATE, PS.NAME, PS.GENERICATTRIBUTE1, CAR.ID_MESA, DP.EARNINGCODEID, DP.GENERICNUMBER1, DP.VALUE, PR.STARTDATE, ER.DESCRIPTION
		) A
		GROUP BY PERIODO, ID_EMPLEADO, ID_SUCURSAL, ID_MESA, ID_CONCEPTO, FIJO, PARAMNUM3, FECHA_ENVIO, PARAMDATE2, REFERENCIA, LOTE, PARAMSTR3, PARAMSTR4;
		
	-- NUEVO INGRESO 'P0168'
	INSERT INTO EXT.TB_INCIDENCIA_AUX
		SELECT LV_IDTRANSACCION AS ID_TRANSACCION, PERIODO, ID_EMPLEADO, ID_SUCURSAL, ID_MESA, ID_CONCEPTO, FIJO, SUM(A.IMPORTE), SUM(PARAMNUM2), PARAMNUM3, FECHA_ENVIO, PARAMDATE2, REFERENCIA, LOTE, PARAMSTR3, PARAMSTR4
		FROM (
			SELECT DISTINCT LV_IDTRANSACCION AS ID_TRANSACCION, 
			TO_CHAR(
					PR.STARTDATE, 
					'YYYYMMDD'
				) AS PERIODO, 
			PS.NAME AS ID_EMPLEADO, 
			PS.GENERICATTRIBUTE1 AS ID_SUCURSAL, 
			CAR.ID_MESA AS ID_MESA, 
			DP.EARNINGCODEID AS ID_CONCEPTO, 
			'0' AS FIJO, 
			TO_DECIMAL(DP.GENERICNUMBER1,5,2) AS IMPORTE, 
			TO_DECIMAL(DP.VALUE,12,2) AS PARAMNUM2, 
			'0' AS PARAMNUM3, 
			TO_CHAR(
				PR.STARTDATE, 
				'YYYY-MM-DD'
			) AS FECHA_ENVIO, 
			'' AS PARAMDATE2, 
			ER.DESCRIPTION AS REFERENCIA, 
			TO_CHAR('COM-' || CASE WHEN LENGTH (PS.GENERICATTRIBUTE1) = 1 THEN '000'|| PS.GENERICATTRIBUTE1
			WHEN LENGTH (PS.GENERICATTRIBUTE1) = 2 THEN '00'|| PS.GENERICATTRIBUTE1 
			WHEN LENGTH (PS.GENERICATTRIBUTE1) = 3 THEN '0'|| PS.GENERICATTRIBUTE1 
			ELSE PS.GENERICATTRIBUTE1 END || '-' ||LV_PERIODO|| '-' || CAR.ID_MESA
			|| '-' || TO_CHAR(
					PR.STARTDATE, 
					'DD/MM/YYYY'
				)) AS LOTE, 
			'' AS PARAMSTR3, 
			'' AS PARAMSTR4
		FROM TCMP.CS_DEPOSIT AS DP
			INNER JOIN TCMP.CS_POSITION AS PS
			ON DP.POSITIONSEQ = PS.RULEELEMENTOWNERSEQ
			INNER JOIN TCMP.CS_PERIOD AS PR
			ON DP.PERIODSEQ = PR.PERIODSEQ
			INNER JOIN TCMP.CS_EARNINGCODE AS ER
			ON DP.EARNINGCODEID = ER.EARNINGCODEID
			INNER JOIN EXT.TB_SUCACT_PRD SA
			ON TO_INT(PS.GENERICATTRIBUTE1) = SA.ID_SUCURSAL
			INNER JOIN EXT.TB_CARGOS_WKF CAR
			ON CAR.ID_CARGO = PS.GENERICATTRIBUTE3
			INNER JOIN EXT.TB_SUCURSAL_WKF SUC
			ON SUC.ID_TIPO_MESA = CAR.ID_TIPO_MESA
			AND SUC.ID_SUCURSAL = PS.GENERICATTRIBUTE1
		WHERE 1 = 1
			AND DP.PIPELINERUNSEQ = :LV_LASTPIPE
			AND DP.PERIODSEQ = :vPeriodSeq
			AND DP.EARNINGCODEID IN ('P0168')
			AND PS.REMOVEDATE = '2200-01-01 00:00:00.000000000'
			-- AND PS.ISLAST = 1 -- Quit
			AND PS.EFFECTIVESTARTDATE <= :LV_DATE_PERIODSEQ -- periodseq date
			AND :LV_DATE_PERIODSEQ < PS.EFFECTIVEENDDATE 
			AND PR.REMOVEDATE = '2200-01-01 00:00:00.000000000'
			AND ER.REMOVEDATE = '2200-01-01 00:00:00.000000000'
			AND DP.VALUE > 0
			AND EARNINGGROUPID IN ('COMISION_ROJA', 'COMISION_AZUL', 'COMISION_EXPRESS', 'COMISION_CITYCLUB')
			AND SA.ESTATUS = TRUE
			AND DP.POSITIONSEQ IN (
				SELECT DISTINCT POSITIONSEQ
				FROM TCMP.CS_DEPOSIT
				WHERE PIPELINERUNSEQ = :LV_LASTPIPE
				AND PERIODSEQ = :vPeriodSeq
				AND GENERICNUMBER6 = 0
				AND GENERICNUMBER5 = 1
			)
			GROUP BY PR.STARTDATE, PS.NAME, PS.GENERICATTRIBUTE1, CAR.ID_MESA, DP.EARNINGCODEID, DP.GENERICNUMBER1, DP.VALUE, PR.STARTDATE, ER.DESCRIPTION
		) A
		GROUP BY PERIODO, ID_EMPLEADO, ID_SUCURSAL, ID_MESA, ID_CONCEPTO, FIJO, PARAMNUM3, FECHA_ENVIO, PARAMDATE2, REFERENCIA, LOTE, PARAMSTR3, PARAMSTR4;
	
	-- NUEVO INGRESO 'P0177'
	INSERT INTO EXT.TB_INCIDENCIA_AUX
		SELECT LV_IDTRANSACCION AS ID_TRANSACCION, PERIODO, ID_EMPLEADO, ID_SUCURSAL, ID_MESA, ID_CONCEPTO, FIJO, SUM(A.IMPORTE), SUM(PARAMNUM2), PARAMNUM3, FECHA_ENVIO, PARAMDATE2, REFERENCIA, LOTE, PARAMSTR3, PARAMSTR4
		FROM (
			SELECT DISTINCT LV_IDTRANSACCION AS ID_TRANSACCION, 
			TO_CHAR(
					PR.STARTDATE, 
					'YYYYMMDD'
				) AS PERIODO, 
			PS.NAME AS ID_EMPLEADO, 
			PS.GENERICATTRIBUTE1 AS ID_SUCURSAL, 
			CAR.ID_MESA AS ID_MESA, 
			DP.EARNINGCODEID AS ID_CONCEPTO, 
			'0' AS FIJO, 
			TO_DECIMAL(DP.GENERICNUMBER1,5,2) AS IMPORTE, 
			TO_DECIMAL(DP.VALUE,12,2) AS PARAMNUM2, 
			'0' AS PARAMNUM3, 
			TO_CHAR(
				PR.STARTDATE, 
				'YYYY-MM-DD'
			) AS FECHA_ENVIO, 
			'' AS PARAMDATE2, 
			ER.DESCRIPTION AS REFERENCIA, 
			TO_CHAR('COM-' || CASE WHEN LENGTH (PS.GENERICATTRIBUTE1) = 1 THEN '000'|| PS.GENERICATTRIBUTE1
			WHEN LENGTH (PS.GENERICATTRIBUTE1) = 2 THEN '00'|| PS.GENERICATTRIBUTE1 
			WHEN LENGTH (PS.GENERICATTRIBUTE1) = 3 THEN '0'|| PS.GENERICATTRIBUTE1 
			ELSE PS.GENERICATTRIBUTE1 END || '-' ||LV_PERIODO|| '-' || CAR.ID_MESA
			|| '-' || TO_CHAR(
					PR.STARTDATE, 
					'DD/MM/YYYY'
				)) AS LOTE, 
			'' AS PARAMSTR3, 
			'' AS PARAMSTR4
		FROM TCMP.CS_DEPOSIT AS DP
			INNER JOIN TCMP.CS_POSITION AS PS
			ON DP.POSITIONSEQ = PS.RULEELEMENTOWNERSEQ
			INNER JOIN TCMP.CS_PERIOD AS PR
			ON DP.PERIODSEQ = PR.PERIODSEQ
			INNER JOIN TCMP.CS_EARNINGCODE AS ER
			ON DP.EARNINGCODEID = ER.EARNINGCODEID
			INNER JOIN EXT.TB_SUCACT_PRD SA
			ON TO_INT(PS.GENERICATTRIBUTE1) = SA.ID_SUCURSAL
			INNER JOIN EXT.TB_CARGOS_WKF CAR
			ON CAR.ID_CARGO = PS.GENERICATTRIBUTE3
			INNER JOIN EXT.TB_SUCURSAL_WKF SUC
			ON SUC.ID_TIPO_MESA = CAR.ID_TIPO_MESA
			AND SUC.ID_SUCURSAL = PS.GENERICATTRIBUTE1
		WHERE 1 = 1
			AND DP.PIPELINERUNSEQ = :LV_LASTPIPE
			AND DP.PERIODSEQ = :vPeriodSeq
			AND DP.EARNINGCODEID IN ('P0177')
			AND PS.REMOVEDATE = '2200-01-01 00:00:00.000000000'
			-- AND PS.ISLAST = 1 -- Quit
			AND PS.EFFECTIVESTARTDATE <= :LV_DATE_PERIODSEQ -- periodseq date
			AND :LV_DATE_PERIODSEQ < PS.EFFECTIVEENDDATE 
			AND PR.REMOVEDATE = '2200-01-01 00:00:00.000000000'
			AND ER.REMOVEDATE = '2200-01-01 00:00:00.000000000'
			AND DP.VALUE > 0
			AND EARNINGGROUPID IN ('COMISION_ROJA', 'COMISION_AZUL', 'COMISION_EXPRESS', 'COMISION_CITYCLUB')
			AND SA.ESTATUS = TRUE
			AND DP.POSITIONSEQ IN (
				SELECT DISTINCT POSITIONSEQ
				FROM TCMP.CS_DEPOSIT
				WHERE PIPELINERUNSEQ = :LV_LASTPIPE
				AND PERIODSEQ = :vPeriodSeq
				AND GENERICNUMBER6 = 0
				AND GENERICNUMBER5 = 1
			)
			GROUP BY PR.STARTDATE, PS.NAME, PS.GENERICATTRIBUTE1, CAR.ID_MESA, DP.EARNINGCODEID, DP.GENERICNUMBER1, DP.VALUE, PR.STARTDATE, ER.DESCRIPTION
		) A
		GROUP BY PERIODO, ID_EMPLEADO, ID_SUCURSAL, ID_MESA, ID_CONCEPTO, FIJO, PARAMNUM3, FECHA_ENVIO, PARAMDATE2, REFERENCIA, LOTE, PARAMSTR3, PARAMSTR4;
	*/
	
	/*
	-- VENTA NO REPARTIDA
	-- ('P0166')
	INSERT INTO EXT.TB_INCIDENCIA_AUX
		SELECT DISTINCT LV_IDTRANSACCION AS ID_TRANSACCION, 
			TO_CHAR(
					PR.STARTDATE, 
					'YYYYMMDD'
				) AS PERIODO, 
			PS.NAME AS ID_EMPLEADO, 
			PS.GENERICATTRIBUTE1 AS ID_SUCURSAL, 
			CAR.ID_MESA AS ID_MESA, 
			DP.EARNINGCODEID AS ID_CONCEPTO, 
			'0' AS FIJO, 
			TO_DECIMAL(DP.GENERICNUMBER1,5,2) AS IMPORTE, 
			TO_DECIMAL(DP.VALUE,12,2) AS PARAMNUM2, 
			'0' AS PARAMNUM3, 
			TO_CHAR(
				PR.STARTDATE, 
				'YYYY-MM-DD'
			) AS FECHA_ENVIO, 
			'' AS PARAMDATE2, 
			ER.DESCRIPTION AS REFERENCIA, 
			TO_CHAR('COM-' || CASE WHEN LENGTH (PS.GENERICATTRIBUTE1) = 1 THEN '000'|| PS.GENERICATTRIBUTE1
			WHEN LENGTH (PS.GENERICATTRIBUTE1) = 2 THEN '00'|| PS.GENERICATTRIBUTE1 
			WHEN LENGTH (PS.GENERICATTRIBUTE1) = 3 THEN '0'|| PS.GENERICATTRIBUTE1 
			ELSE PS.GENERICATTRIBUTE1 END || '-' ||LV_PERIODO|| '-' || CAR.ID_MESA
			|| '-' || TO_CHAR(
					PR.STARTDATE, 
					'DD/MM/YYYY'
				)) AS LOTE, 
			'' AS PARAMSTR3, 
			'' AS PARAMSTR4
		FROM TCMP.CS_DEPOSIT AS DP
			INNER JOIN TCMP.CS_POSITION AS PS
			ON DP.POSITIONSEQ = PS.RULEELEMENTOWNERSEQ
			INNER JOIN TCMP.CS_PERIOD AS PR
			ON DP.PERIODSEQ = PR.PERIODSEQ
			INNER JOIN TCMP.CS_EARNINGCODE AS ER
			ON DP.EARNINGCODEID = ER.EARNINGCODEID
			INNER JOIN EXT.TB_SUCACT_PRD SA
			ON TO_INT(PS.GENERICATTRIBUTE1) = SA.ID_SUCURSAL
			INNER JOIN EXT.TB_CARGOS_WKF CAR
			ON CAR.ID_CARGO = PS.GENERICATTRIBUTE3
			INNER JOIN EXT.TB_SUCURSAL_WKF SUC
			ON SUC.ID_TIPO_MESA = CAR.ID_TIPO_MESA
			AND SUC.ID_SUCURSAL = PS.GENERICATTRIBUTE1
		WHERE 1 = 1
			AND DP.PIPELINERUNSEQ = :LV_LASTPIPE
			AND DP.PERIODSEQ = :vPeriodSeq
			AND DP.EARNINGCODEID IN ('P0166')
			AND PS.REMOVEDATE = '2200-01-01 00:00:00.000000000'
			-- AND PS.ISLAST = 1 -- Quit
			AND PS.EFFECTIVESTARTDATE <= :LV_DATE_PERIODSEQ -- periodseq date
			AND :LV_DATE_PERIODSEQ < PS.EFFECTIVEENDDATE 
			AND PR.REMOVEDATE = '2200-01-01 00:00:00.000000000'
			AND ER.REMOVEDATE = '2200-01-01 00:00:00.000000000'
			AND DP.VALUE > 1
			AND EARNINGGROUPID IN ('COMISION_ROJA', 'COMISION_AZUL', 'COMISION_EXPRESS', 'COMISION_CITYCLUB')
			AND SA.ESTATUS = TRUE;
			-- AND DP.GENERICNUMBER6 >= 1;
	*/
			
	SELECT COUNT(*) INTO LV_TOTAL_REGISTROS FROM EXT.TB_INCIDENCIA_AUX WHERE 1=1;
	
	LV_NOMBRE := 'CARGAINC_'||vFechaArchivo||'_'||LV_MAIN_PERIOD||'_'||LV_IDTRANS||'.txt';
	
	INSERT INTO EXT.TB_INCIDENCIA_ITX
	SELECT ID_TRANSACCION, ID_EMPLEADO, ID_CONCEPTO, FIJO, CAST (TO_DECIMAL(IMPORTE,12,2) AS NVARCHAR), CAST (TO_DECIMAL(PARAMNUM2,12,2) AS NVARCHAR), PARAMNUM3, FECHA_ENVIO, PARAMDATE2, REFERENCIA,
	LOTE, PARAMSTR3, PARAMSTR4, LV_TOTAL_REGISTROS, LV_CORREO, LV_NOMBRE
	FROM EXT.TB_INCIDENCIA_AUX
	WHERE 1=1;
	
	INSERT INTO EXT.TB_INCIDENCIA_HIS(ID_TRANSACCION, PERIODO, ID_EMPLEADO, ID_SUCURSAL, ID_MESA, ID_CONCEPTO, FIJO, IMPORTE, PARAMNUM2, PARAMNUM3,
		FECHA_ENVIO, PARAMDATE2, REFERENCIA, LOTE, PARAMSTR3, PARAMSTR4, ESTADO, FECHA_MOVIMIENTO
	)
	SELECT ID_TRANSACCION, PERIODO, ID_EMPLEADO, ID_SUCURSAL, ID_MESA, ID_CONCEPTO, FIJO, CAST (TO_DECIMAL(IMPORTE,12,2) AS NVARCHAR), CAST (TO_DECIMAL(PARAMNUM2,12,2) AS NVARCHAR), PARAMNUM3,
		FECHA_ENVIO, PARAMDATE2, REFERENCIA, LOTE, PARAMSTR3, PARAMSTR4, '1', LV_FECHA_MOVIMIENTO
		FROM EXT.TB_INCIDENCIA_AUX
	WHERE 1=1;
	
	INSERT INTO EXT.TB_IDTRANSACCION_ITX VALUES(LV_IDTRANSACCION, LV_NOMBRE);
	
	FILENAME := :LV_NOMBRE;
END