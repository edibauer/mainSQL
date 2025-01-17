CREATE PROCEDURE EXT.SP_TRAS_SIN_PLAN (OUT FILENAME VARCHAR(255), IN pPlRunSeq BIGINT)
LANGUAGE SQLSCRIPT
SQL SECURITY INVOKER
DEFAULT SCHEMA EXT
AS

BEGIN
	
	DECLARE LV_PERIODSEQ BIGINT;
	DECLARE LV_USER VARCHAR(127);
	DECLARE LV_DATE_PERIODSEQ DATE;
	DECLARE LV_PER_STARTDATE DATE;
	DECLARE LV_PER_ENDDATE DATE;
	DECLARE LV_NOMBRE VARCHAR(255);
	DECLARE vFechaArchivo VARCHAR(50);
	DECLARE LV_FECHA_MOVIMIENTO TIMESTAMP;
	DECLARE LV_CORREO VARCHAR(127);
	DECLARE LV_IDTRANSACCION BIGINT;
	DECLARE LV_IDTRANS VARCHAR(127);
	DECLARE LV_PERIODO VARCHAR(4);
	DECLARE LV_MAIN_PERIOD VARCHAR(127);
	DECLARE LV_TOTAL_REGISTROS INTEGER;
	
	-- Search PERIODSEQ using PIPE
	SELECT PERIODSEQ, USERID
	INTO LV_PERIODSEQ, LV_USER
	FROM TCMP.CS_PIPELINERUN
	WHERE PIPELINERUNSEQ = :pPlRunSeq;
	
	-- Date to extract
	SELECT 
		TO_VARCHAR(CURRENT_TIMESTAMP, 'YYYYMMDD_HH24MISS'), 
		CURRENT_TIMESTAMP
	INTO vFechaArchivo, LV_FECHA_MOVIMIENTO
	FROM DUMMY;
	
	-- Email
	SELECT 
		EMAIL--|| ',gonzalocgr@soriana.com'|| ',sistemasdesarrollonominasyrh@soriana.com'|| ',dulcecgr@soriana.com'
	INTO LV_CORREO 
	FROM TCMP.CS_USER 
	WHERE ID = :LV_USER
	AND REMOVEDATE = '2200-01-01 00:00:00.000000000';
	
	-- Last transaction number
	SELECT MAX(ID_TRANSACCION)
	INTO LV_IDTRANSACCION
	FROM EXT.TB_IDTRANSACCION_ITX;
	
	-- ID_TRANSACTION to filename
	SELECT 
		TO_VARCHAR(MAX(ID_TRANSACCION) + 1)
	INTO LV_IDTRANS
	FROM EXT.TB_IDTRANSACCION_ITX;
	
	-- Period (30, 31, 32)
	SELECT 
		CASE WHEN LENGTH (TRIM (' ' FROM PERIODO)) = 1 THEN '000'||PERIODO
		WHEN LENGTH (TRIM (' ' FROM PERIODO)) = 2 THEN '00'||PERIODO
		ELSE periodo
		END
	INTO LV_PERIODO DEFAULT NULL
	FROM (
		SELECT 
			SUBSTRING(NAME, 16, 2) AS PERIODO
		FROM TCMP.CS_PERIOD 
		WHERE PERIODSEQ = :LV_PERIODSEQ
		AND REMOVEDATE = '2200-01-01 00:00:00.000000000'
	);
	
	-- PERIOD PIPELINE
	SELECT 
		TO_VARCHAR(TO_DATE(ADD_DAYS(STARTDATE, -6)), 'YYYYMMDD')||'_'||TO_VARCHAR(TO_DATE(STARTDATE), 'YYYYMMDD')
	INTO LV_MAIN_PERIOD
	FROM TCMP.CS_PERIOD
	WHERE PERIODSEQ = :LV_PERIODSEQ
	LIMIT 1;
	
	-- New transaction ID
	LV_IDTRANSACCION = :LV_IDTRANSACCION + 1;
	
	-- PLAN
	-- Transform PERIODSEQ to DATE
	SELECT STARTDATE
	INTO LV_DATE_PERIODSEQ DEFAULT NULL
	FROM TCMP.CS_PERIOD
	WHERE PERIODSEQ = :LV_PERIODSEQ
	AND REMOVEDATE = '2200-01-01';
	
	-- LOGIC
	
	-- Search of period by PERIODSEQ
	-- Transform periodseq to date and search STARTDATE and ENDATE
	-- ex '2024-07-13', '2024-07-20'
	SELECT STARTDATE, ENDDATE
	INTO LV_PER_STARTDATE, LV_PER_ENDDATE
	FROM TCMP.CS_PERIOD
	WHERE STARTDATE <= :LV_DATE_PERIODSEQ -- periodseq date
	AND :LV_DATE_PERIODSEQ < ENDDATE -- periodseq date
	AND REMOVEDATE = '2200-01-01'
	AND DESCRIPTION = 'SEM';
	
	-- Reset Values
	DELETE FROM EXT.TB_INCIDENCIA_AUX
	WHERE 1 = 1;
	
	DELETE FROM EXT.TB_INCIDENCIA_ITX
	WHERE 1 = 1;
	
	-- Search the last period where there is a deposit and insert into AUX table
	-- EARNINGCODE (P0139, P0162, P0316)
	INSERT INTO EXT.TB_INCIDENCIA_AUX
		SELECT DISTINCT
		LV_IDTRANSACCION ID_TRANSACCION,
		TO_CHAR( :LV_DATE_PERIODSEQ, 'YYYYMMDD') PERIODO, -- from PERIOD
		PO.NAME ID_EMPLEADO,
		PO.GENERICATTRIBUTE1 ID_SUCURSAL,
		1 ID_MESA, -- CHECK MESA
		FDEP.EARNINGCODEID ID_CONCEPTO,
		'0' FIJO,
		TO_DECIMAL(FDEP.VALUE) IMPORTE,
		'0' PARAMNUM2,
		'0' PARAMNUM3,
		TO_CHAR( :LV_DATE_PERIODSEQ, 'YYYY-MM-DD') FECHA_ENVIO,-- from PERIOD
		'' PARAMDATE2,
		EC.DESCRIPTION REFERENCIA,
		TO_CHAR('COM-' || CASE WHEN LENGTH (PO.GENERICATTRIBUTE1) = 1 THEN '000'|| PO.GENERICATTRIBUTE1
		WHEN LENGTH (PO.GENERICATTRIBUTE1) = 2 THEN '00'|| PO.GENERICATTRIBUTE1 
		WHEN LENGTH (PO.GENERICATTRIBUTE1) = 3 THEN '0'|| PO.GENERICATTRIBUTE1 
		ELSE PO.GENERICATTRIBUTE1 END || '-' ||LV_PERIODO|| '-' || 1 -- CHECK MESA
		|| '-' || TO_CHAR( :LV_DATE_PERIODSEQ, 'DD/MM/YYYY')) LOTE,
		'' PARAMSTR3,
		'' PARAMSTR4
		FROM (
			SELECT DEP.*
			FROM TCMP.CS_DEPOSIT DEP, (
				SELECT POSITIONSEQ POSITIONSEQ, MAX(PERIODSEQ) PERIODSEQ
				FROM TCMP.CS_DEPOSIT
				WHERE PERIODSEQ IN (
					-- Actual period
					SELECT PERIODSEQ
					FROM TCMP.CS_PERIOD
					WHERE REMOVEDATE = '2200-01-01'
					AND STARTDATE BETWEEN :LV_PER_STARTDATE AND :LV_PER_ENDDATE -- From START and ENDDATE
					AND DESCRIPTION IS NULL
					ORDER BY PERIODSEQ
				)
				AND POSITIONSEQ IN (
					-- Position without asignned plan
					SELECT 
					PLAN.POSITIONSEQ
					-- PLAN.ID_EMPLEADO, 
					-- PL.NAME
					FROM (
						SELECT DISTINCT PO.RULEELEMENTOWNERSEQ POSITIONSEQ, PO.NAME ID_EMPLEADO, PO.TITLESEQ TITLESEQ, PA.PLANSEQ PLANSEQ
						FROM TCMP.CS_POSITION PO
						INNER JOIN 
						TCMP.CS_PLANASSIGNABLE PA
						ON PO.TITLESEQ = PA.RULEELEMENTOWNERSEQ
						WHERE 1 = 1
							AND PO.REMOVEDATE = '2200-01-01'
							AND PO.ISLAST = 1
							AND PA.REMOVEDATE = '2200-01-01'
							AND PA.ISLAST = 1
							AND PA.PLANSEQ IS NULL
					) PLAN
					LEFT JOIN 
					TCMP.CS_PLAN PL
					ON PL.RULEELEMENTOWNERSEQ = PLAN.PLANSEQ
					AND PL.REMOVEDATE = '2200-01-01'
					AND PL.ISLAST = 1
				)
				GROUP BY POSITIONSEQ
			) REF
			WHERE DEP.POSITIONSEQ = REF.POSITIONSEQ
			AND DEP.PERIODSEQ = REF.PERIODSEQ
		) FDEP
		-- JOINS
		INNER JOIN 
		TCMP.CS_POSITION PO
		ON FDEP.POSITIONSEQ = PO.RULEELEMENTOWNERSEQ
		INNER JOIN 
		TCMP.CS_EARNINGCODE EC
		ON FDEP.EARNINGCODEID = EC.EARNINGCODEID
		-- WHERE
		WHERE 1 = 1
			AND FDEP.EARNINGCODEID IN ('P0139', 'P0162', 'P0316')
			AND PO.REMOVEDATE = '2200-01-01'
			AND PO.ISLAST = 1
			AND EC.REMOVEDATE = '2200-01-01';
			
	-- EARNINGCODE (P0161, P0163)
	INSERT INTO EXT.TB_INCIDENCIA_AUX
		SELECT DISTINCT
		LV_IDTRANSACCION ID_TRANSACCION,
		TO_CHAR( :LV_DATE_PERIODSEQ, 'YYYYMMDD') PERIODO, -- from PERIOD
		PO.NAME ID_EMPLEADO,
		PO.GENERICATTRIBUTE1 ID_SUCURSAL,
		1 ID_MESA, -- CHECK MESA
		FDEP.EARNINGCODEID ID_CONCEPTO,
		'0' FIJO,
		TO_DECIMAL(FDEP.VALUE) IMPORTE,
		TO_DECIMAL(FDEP.GENERICNUMBER1, 6, 2) PARAMNUM2,
		'0' PARAMNUM3,
		TO_CHAR( :LV_DATE_PERIODSEQ, 'YYYY-MM-DD') FECHA_ENVIO,-- from PERIOD
		'' PARAMDATE2,
		EC.DESCRIPTION REFERENCIA,
		TO_CHAR('COM-' || CASE WHEN LENGTH (PO.GENERICATTRIBUTE1) = 1 THEN '000'|| PO.GENERICATTRIBUTE1
		WHEN LENGTH (PO.GENERICATTRIBUTE1) = 2 THEN '00'|| PO.GENERICATTRIBUTE1 
		WHEN LENGTH (PO.GENERICATTRIBUTE1) = 3 THEN '0'|| PO.GENERICATTRIBUTE1 
		ELSE PO.GENERICATTRIBUTE1 END || '-' ||LV_PERIODO|| '-' || 1 -- CHECK MESA
		|| '-' || TO_CHAR( :LV_DATE_PERIODSEQ, 'DD/MM/YYYY')) LOTE,
		'' PARAMSTR3,
		'' PARAMSTR4
		FROM (
			SELECT DEP.*
			FROM TCMP.CS_DEPOSIT DEP, (
				SELECT POSITIONSEQ POSITIONSEQ, MAX(PERIODSEQ) PERIODSEQ
				FROM TCMP.CS_DEPOSIT
				WHERE PERIODSEQ IN (
					-- Actual period
					SELECT PERIODSEQ
					FROM TCMP.CS_PERIOD
					WHERE REMOVEDATE = '2200-01-01'
					AND STARTDATE BETWEEN :LV_PER_STARTDATE AND :LV_PER_ENDDATE -- From START and ENDDATE
					AND DESCRIPTION IS NULL
					ORDER BY PERIODSEQ
				)
				AND POSITIONSEQ IN (
					-- Position without asignned plan
					SELECT 
					PLAN.POSITIONSEQ
					-- PLAN.ID_EMPLEADO, 
					-- PL.NAME
					FROM (
						SELECT DISTINCT PO.RULEELEMENTOWNERSEQ POSITIONSEQ, PO.NAME ID_EMPLEADO, PO.TITLESEQ TITLESEQ, PA.PLANSEQ PLANSEQ
						FROM TCMP.CS_POSITION PO
						INNER JOIN 
						TCMP.CS_PLANASSIGNABLE PA
						ON PO.TITLESEQ = PA.RULEELEMENTOWNERSEQ
						WHERE 1 = 1
							AND PO.REMOVEDATE = '2200-01-01'
							AND PO.ISLAST = 1
							AND PA.REMOVEDATE = '2200-01-01'
							AND PA.ISLAST = 1
							AND PA.PLANSEQ IS NULL
					) PLAN
					LEFT JOIN 
					TCMP.CS_PLAN PL
					ON PL.RULEELEMENTOWNERSEQ = PLAN.PLANSEQ
					AND PL.REMOVEDATE = '2200-01-01'
					AND PL.ISLAST = 1
				)
				GROUP BY POSITIONSEQ
			) REF
			WHERE DEP.POSITIONSEQ = REF.POSITIONSEQ
			AND DEP.PERIODSEQ = REF.PERIODSEQ
		) FDEP
		-- JOINS
		INNER JOIN 
		TCMP.CS_POSITION PO
		ON FDEP.POSITIONSEQ = PO.RULEELEMENTOWNERSEQ
		INNER JOIN 
		TCMP.CS_EARNINGCODE EC
		ON FDEP.EARNINGCODEID = EC.EARNINGCODEID
		-- WHERE
		WHERE 1 = 1
			AND FDEP.EARNINGCODEID IN ('P0161', 'P0163')
			AND PO.REMOVEDATE = '2200-01-01'
			AND PO.ISLAST = 1
			AND EC.REMOVEDATE = '2200-01-01';
			
	-- EARNINGCODE (P0167, P0168, P0177)
	INSERT INTO EXT.TB_INCIDENCIA_AUX
		SELECT DISTINCT
		LV_IDTRANSACCION ID_TRANSACCION,
		TO_CHAR( :LV_DATE_PERIODSEQ, 'YYYYMMDD') PERIODO, -- from PERIOD
		PO.NAME ID_EMPLEADO,
		PO.GENERICATTRIBUTE1 ID_SUCURSAL,
		1 ID_MESA, -- CHECK MESA
		FDEP.EARNINGCODEID ID_CONCEPTO,
		'0' FIJO,
		TO_DECIMAL(FDEP.VALUE) IMPORTE,
		TO_DECIMAL(FDEP.GENERICNUMBER1, 6, 2) PARAMNUM2,
		'0' PARAMNUM3,
		TO_CHAR( :LV_DATE_PERIODSEQ, 'YYYY-MM-DD') FECHA_ENVIO,-- from PERIOD
		'' PARAMDATE2,
		EC.DESCRIPTION REFERENCIA,
		TO_CHAR('COM-' || CASE WHEN LENGTH (PO.GENERICATTRIBUTE1) = 1 THEN '000'|| PO.GENERICATTRIBUTE1
		WHEN LENGTH (PO.GENERICATTRIBUTE1) = 2 THEN '00'|| PO.GENERICATTRIBUTE1 
		WHEN LENGTH (PO.GENERICATTRIBUTE1) = 3 THEN '0'|| PO.GENERICATTRIBUTE1 
		ELSE PO.GENERICATTRIBUTE1 END || '-' ||LV_PERIODO|| '-' || 1 -- CHECK MESA
		|| '-' || TO_CHAR( :LV_DATE_PERIODSEQ, 'DD/MM/YYYY')) LOTE,
		'' PARAMSTR3,
		'' PARAMSTR4
		FROM (
			SELECT DEP.*
			FROM TCMP.CS_DEPOSIT DEP, (
				SELECT POSITIONSEQ POSITIONSEQ, MAX(PERIODSEQ) PERIODSEQ
				FROM TCMP.CS_DEPOSIT
				WHERE PERIODSEQ IN (
					-- Actual period
					SELECT PERIODSEQ
					FROM TCMP.CS_PERIOD
					WHERE REMOVEDATE = '2200-01-01'
					AND STARTDATE BETWEEN :LV_PER_STARTDATE AND :LV_PER_ENDDATE -- From START and ENDDATE
					AND DESCRIPTION IS NULL
					ORDER BY PERIODSEQ
				)
				AND POSITIONSEQ IN (
					-- Position without asignned plan
					SELECT 
					PLAN.POSITIONSEQ
					-- PLAN.ID_EMPLEADO, 
					-- PL.NAME
					FROM (
						SELECT DISTINCT PO.RULEELEMENTOWNERSEQ POSITIONSEQ, PO.NAME ID_EMPLEADO, PO.TITLESEQ TITLESEQ, PA.PLANSEQ PLANSEQ
						FROM TCMP.CS_POSITION PO
						INNER JOIN 
						TCMP.CS_PLANASSIGNABLE PA
						ON PO.TITLESEQ = PA.RULEELEMENTOWNERSEQ
						WHERE 1 = 1
							AND PO.REMOVEDATE = '2200-01-01'
							AND PO.ISLAST = 1
							AND PA.REMOVEDATE = '2200-01-01'
							AND PA.ISLAST = 1
							AND PA.PLANSEQ IS NULL
					) PLAN
					LEFT JOIN 
					TCMP.CS_PLAN PL
					ON PL.RULEELEMENTOWNERSEQ = PLAN.PLANSEQ
					AND PL.REMOVEDATE = '2200-01-01'
					AND PL.ISLAST = 1
				)
				GROUP BY POSITIONSEQ
			) REF
			WHERE DEP.POSITIONSEQ = REF.POSITIONSEQ
			AND DEP.PERIODSEQ = REF.PERIODSEQ
		) FDEP
		-- JOINS
		INNER JOIN 
		TCMP.CS_POSITION PO
		ON FDEP.POSITIONSEQ = PO.RULEELEMENTOWNERSEQ
		INNER JOIN 
		TCMP.CS_EARNINGCODE EC
		ON FDEP.EARNINGCODEID = EC.EARNINGCODEID
		-- WHERE
		WHERE 1 = 1
			AND FDEP.EARNINGCODEID IN ('P0167', 'P0168', 'P0177')
			AND PO.REMOVEDATE = '2200-01-01'
			AND PO.ISLAST = 1
			AND EC.REMOVEDATE = '2200-01-01';
			
	-- Counting reg
	SELECT 
		COUNT(*) 
	INTO LV_TOTAL_REGISTROS 
	FROM EXT.TB_INCIDENCIA_AUX
	WHERE 1=1;
	
	-- Filename	
	LV_NOMBRE := 'DATASPLAN_'||vFechaArchivo||'_'||LV_MAIN_PERIOD||'_'||LV_IDTRANS||'.txt';
			
	-- Insert to main table that contains data to extract
	INSERT INTO EXT.TB_INCIDENCIA_ITX
		SELECT ID_TRANSACCION, ID_EMPLEADO, ID_CONCEPTO, FIJO, CAST (TO_DECIMAL(IMPORTE,12,2) AS NVARCHAR), CAST (TO_DECIMAL(PARAMNUM2,12,2) AS NVARCHAR), PARAMNUM3, FECHA_ENVIO, PARAMDATE2, REFERENCIA,
		LOTE, PARAMSTR3, PARAMSTR4, LV_TOTAL_REGISTROS, LV_CORREO, LV_NOMBRE
		FROM EXT.TB_INCIDENCIA_AUX
		WHERE 1=1;	
	
	-- OUT
	FILENAME := :LV_NOMBRE;

END