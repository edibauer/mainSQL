CREATE PROCEDURE EXT.SP_BAL_VENTA_NO_REP (i INT, j INT, k DATE)
LANGUAGE SQLSCRIPT
SQL SECURITY INVOKER
DEFAULT SCHEMA EXT
AS

BEGIN

	-- VARIABLES
	-- i = SUCRUSAL
	-- j = MESA
	-- K = FECHA
	DECLARE lv_NUM_DESC_TRUE INT;
	DECLARE lv_SUMA_PORC DECIMAL(10,5);
	DECLARE lv_SUMA_ASTNC DECIMAL(10,5);
	
	-- PORC RESET
	UPDATE EXT.TB_ASISTENCIA_WKF
	SET PORCENTAJE_PARTICIPACION_EMPLEADO = EXT.TB_PORCPARTICIPACION_WKF.PORCENTAJE_PART_CARGO
	FROM EXT.TB_ASISTENCIA_WKF, EXT.TB_PORCPARTICIPACION_WKF
	WHERE EXT.TB_ASISTENCIA_WKF.ID_SUCURSAL = EXT.TB_PORCPARTICIPACION_WKF.ID_SUCURSAL
	AND EXT.TB_ASISTENCIA_WKF.ID_MESA_REAL = EXT.TB_PORCPARTICIPACION_WKF.ID_MESA
	AND EXT.TB_ASISTENCIA_WKF.ID_CVE_CARGO_REAL = EXT.TB_PORCPARTICIPACION_WKF.ID_CVE_CARGO
	AND EXT.TB_ASISTENCIA_WKF.FECHA_ASISTENCIA = :k
	AND EXT.TB_ASISTENCIA_WKF.ID_SUCURSAL = :i
	AND EXT.TB_ASISTENCIA_WKF.ID_MESA_REAL = :j
	AND EXT.TB_ASISTENCIA_WKF.ESTATUS_TRANS IN ('5', '7', '9');
	
	-- BAL COMPLEMENT
	SELECT SUM(PORCENTAJE_PARTICIPACION_EMPLEADO)
	INTO lv_SUMA_ASTNC DEFAULT NULL
	FROM EXT.TB_ASISTENCIA_WKF
	WHERE ID_SUCURSAL = :i
	AND ID_MESA_REAL = :j
	AND ESTATUS_TRANS IN ('5', '7', '9')
	AND FECHA_ASISTENCIA = :K;
	-- AND DESCANSO = TRUE;
			
	IF (lv_SUMA_ASTNC < 100) THEN
			
		SELECT 100 - SUM(PORCENTAJE_PARTICIPACION_EMPLEADO)
		INTO lv_SUMA_PORC DEFAULT NULL
		FROM EXT.TB_ASISTENCIA_WKF
		WHERE ID_SUCURSAL = :i
		AND ID_MESA_REAL = :j
		AND ESTATUS_TRANS IN ('5', '7', '9')
		AND FECHA_ASISTENCIA = :K;
		-- AND DESCANSO = TRUE;
			
		SELECT F_NUM_ESTATUS(i, j, K)
		INTO lv_NUM_DESC_TRUE
		FROM DUMMY;
				
		UPDATE EXT.TB_ASISTENCIA_WKF
		SET PORCENTAJE_PARTICIPACION_EMPLEADO = TO_DECIMAL(PORCENTAJE_PARTICIPACION_EMPLEADO + (lv_SUMA_PORC/lv_NUM_DESC_TRUE),10,5) -- (20 / 2)
		WHERE ID_SUCURSAL = :i
		AND ID_MESA_REAL = :j
		AND ESTATUS_TRANS IN ('5', '7', '9')
		-- AND DESCANSO = TRUE
		AND FECHA_ASISTENCIA = :K;
				
	ELSEIF (lv_SUMA_ASTNC > 100) THEN
			
		SELECT SUM(PORCENTAJE_PARTICIPACION_EMPLEADO) - 100
		INTO lv_SUMA_PORC DEFAULT NULL
		FROM EXT.TB_ASISTENCIA_WKF
		WHERE ID_SUCURSAL = :i
		AND ID_MESA_REAL = :j
		AND ESTATUS_TRANS IN ('5', '7', '9')
		AND FECHA_ASISTENCIA = :K;
		-- AND DESCANSO = TRUE;
			
		SELECT F_NUM_ESTATUS(i, j, k)
		INTO lv_NUM_DESC_TRUE
		FROM DUMMY;
				
		UPDATE EXT.TB_ASISTENCIA_WKF
		SET PORCENTAJE_PARTICIPACION_EMPLEADO = TO_DECIMAL(PORCENTAJE_PARTICIPACION_EMPLEADO - (lv_SUMA_PORC/lv_NUM_DESC_TRUE),10,5) -- (20 / 2)
		WHERE ID_SUCURSAL = :i
		AND ID_MESA_REAL = :j
		AND ESTATUS_TRANS IN ('5', '7', '9')
		-- AND DESCANSO = TRUE
		AND FECHA_ASISTENCIA = :k;
				
	END IF;
END