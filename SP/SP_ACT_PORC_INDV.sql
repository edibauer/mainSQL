CREATE PROCEDURE EXT.SP_ACT_PORC_INDV (i INT, j INT, k DATE)
LANGUAGE SQLSCRIPT
SQL SECURITY INVOKER
DEFAULT SCHEMA EXT
AS
BEGIN
--i = SUCURSAL j = MESA
	DECLARE lv_NUM_EMPL_TRUE INT;
	DECLARE lv_PORC_PART_FALSE DECIMAL(10,5);
	DECLARE lv_PORC_PART_FALSE2 DECIMAL(10,5);
	DECLARE lv_FECHA DATE = :k;
	DECLARE lv_CONTADOR INT = 1;
	DECLARE lv_CONTADOR_FALSE INT = 1;
	DECLARE lv_CONT_MAX INT;
	DECLARE lv_NUM_EMPL_FALSE INT;
	DECLARE lv_PORC_PART_AUX INT;
	DECLARE lv_CONTADOR_SUCURSAL_INIT INT = 1;
	DECLARE lv_CONTADOR_MESA_INIT INT = 1;
	DECLARE lv_CONTADOR_SUCURSAL INT;
	DECLARE lv_CONTADOR_MESA INT;
	-- DECLARE i INT = 28;
	-- DECLARE j INT = 4;
	
			SELECT COUNT(*)
			INTO lv_CONT_MAX DEFAULT NULL
			FROM EXT.TB_ASISTENCIA_WKF
			WHERE ASISTENCIA_ITX = FALSE
			AND ID_SUCURSAL = i
			AND ID_MESA_REAL = j
			AND ESTATUS_TRANS IN ('0', '2', '4')
			AND PORCENTAJE_PARTICIPACION_EMPLEADO != 0
			AND ID_EMPLEADO NOT LIKE '%C%'
			AND FECHA_ASISTENCIA = lv_FECHA; -- CURRENT_DATE
	
			IF (lv_CONT_MAX != 0) 
			THEN
				SELECT F_NUMERO_EMPLEADOS_TRUE(i, j, lv_FECHA)
				INTO lv_NUM_EMPL_TRUE
				FROM DUMMY;
			
				SELECT SUM(PORCENTAJE_PARTICIPACION_EMPLEADO) / lv_NUM_EMPL_TRUE
				INTO lv_PORC_PART_FALSE DEFAULT NULL
				FROM EXT.TB_ASISTENCIA_WKF
				WHERE ID_SUCURSAL = i
				AND ID_MESA_REAL = j
				AND FECHA_ASISTENCIA = lv_FECHA
				AND ESTATUS_TRANS IN ('0', '2', '4')
				AND ASISTENCIA_ITX = FALSE
				AND ID_EMPLEADO NOT LIKE '%C%'
				AND PORCENTAJE_PARTICIPACION_EMPLEADO != 0;
				
				UPDATE EXT.TB_ASISTENCIA_WKF
				SET PORCENTAJE_PARTICIPACION_EMPLEADO = TO_DECIMAL(PORCENTAJE_PARTICIPACION_EMPLEADO + lv_PORC_PART_FALSE, 10, 5) -- (20 / 2)
				WHERE ID_SUCURSAL = i
				AND ID_MESA_REAL = j
				AND ASISTENCIA_ITX = TRUE
				AND ESTATUS_TRANS IN ('0', '2', '4')
				AND FECHA_ASISTENCIA = lv_FECHA;
			END IF;
	
END