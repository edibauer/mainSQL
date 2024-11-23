CREATE PROCEDURE EXT.SP_ACT_APOYO_ADIC_FECHA (FECHA DATE)
LANGUAGE SQLSCRIPT
SQL SECURITY INVOKER
DEFAULT SCHEMA EXT
AS
BEGIN

	DECLARE lv_PUESTOS_DUP INT;
	DECLARE lv_NUM_EMPL_TRUE INT;
	DECLARE lv_PORC_PUESTO_DUP DECIMAL(12,6);
	DECLARE lv_FECHA DATE = :FECHA;
	DECLARE lv_APORTE DECIMAL(12,6);
	DECLARE lv_PUESTO VARCHAR(6);
	DECLARE lv_MAX_SUCURSAL INT;
	DECLARE lv_MIN_SUCURSAL INT;
	DECLARE i INT;
	DECLARE j INT;
	
	
	-- DECLARE i INT = 675;
	-- DECLARE j INT = 1;
	
	--RANGO DE SUCURSALES PARA CICLO
	SELECT MAX(ID_SUCURSAL)
	INTO lv_MAX_SUCURSAL DEFAULT NULL
	FROM EXT.TB_SUCURSAL_WKF;
	
	SELECT MIN(ID_SUCURSAL)
	INTO lv_MIN_SUCURSAL DEFAULT NULL
	FROM EXT.TB_SUCURSAL_WKF;
	
	FOR i IN lv_MIN_SUCURSAL .. lv_MAX_SUCURSAL DO
		FOR j IN 1 .. 6 DO
			
			-- CONTADOR DE PUESTOS DUPLICADO POR MESA
			SELECT COUNT(*)
			INTO lv_PUESTOS_DUP DEFAULT NULL
			FROM (
				SELECT ID_CVE_CARGO_REAL
				FROM EXT.TB_ASISTENCIA_WKF
				WHERE ID_SUCURSAL = :i
				AND ID_MESA_REAL = :j
				AND FECHA_ASISTENCIA = :lv_FECHA
				AND ASISTENCIA_ITX = TRUE
				GROUP BY ID_CVE_CARGO_REAL
				HAVING COUNT(*) > 1 -- C336
			);
			
			-- VALIDACION DE PUESTOS ADICIONALES
			IF (lv_PUESTOS_DUP = 1) THEN
			
					-- PUESTO DUPLICADO
					SELECT ID_CVE_CARGO_REAL
					INTO lv_PUESTO DEFAULT NULL
					FROM EXT.TB_ASISTENCIA_WKF
					WHERE ID_SUCURSAL = :i
					AND ID_MESA_REAL = :j
					AND FECHA_ASISTENCIA = :lv_FECHA
					AND ASISTENCIA_ITX = TRUE
					GROUP BY ID_CVE_CARGO_REAL
					HAVING COUNT(*) > 1; -- C336
					
					-- PORCENTAJE DE PUESTO DUPLICADO
					SELECT DISTINCT PORCENTAJE_PARTICIPACION_EMPLEADO
					INTO lv_PORC_PUESTO_DUP DEFAULT NULL
					FROM EXT.TB_ASISTENCIA_WKF
					WHERE ID_SUCURSAL = :i
					AND ID_MESA_REAL = :j
					AND ID_CVE_CARGO_REAL = :lv_PUESTO
					AND FECHA_ASISTENCIA = :lv_FECHA
					AND ESTATUS_TRANS IN ('0','2')
					AND ASISTENCIA_ITX = TRUE;
					
					-- EMPLEADO CON ASISETNCIA
					SELECT EXT.F_NUMERO_EMPLEADOS_TRUE_ADIC(i, j, lv_FECHA)
					INTO lv_NUM_EMPL_TRUE
					FROM DUMMY;
					
					-- PORC A REPARTIR PORC / NUM_EMPL_TRUE
					SELECT lv_PORC_PUESTO_DUP / lv_NUM_EMPL_TRUE
					INTO lv_APORTE DEFAULT NULL
					FROM DUMMY;
					
					-- RESTA DEL PORC DE APORTE
					UPDATE EXT.TB_ASISTENCIA_WKF
					SET PORCENTAJE_PARTICIPACION_EMPLEADO = TO_DECIMAL(PORCENTAJE_PARTICIPACION_EMPLEADO - lv_APORTE, 10, 5) -- (20 / 2)
					WHERE ID_SUCURSAL = :i
					AND ID_MESA_REAL = :j
					AND ASISTENCIA_ITX = TRUE
					AND FECHA_ASISTENCIA = :lv_FECHA;
					
			ELSEIF (lv_PUESTOS_DUP = 2) THEN
				UPDATE EXT.TB_ASISTENCIA_WKF
				SET PORCENTAJE_PARTICIPACION_EMPLEADO = EXT.TB_PORCPARTICIPACION_WKF.PORCENTAJE_PART_CARGO
				FROM EXT.TB_ASISTENCIA_WKF, EXT.TB_PORCPARTICIPACION_WKF
				WHERE EXT.TB_ASISTENCIA_WKF.ID_SUCURSAL = EXT.TB_PORCPARTICIPACION_WKF.ID_SUCURSAL
				AND EXT.TB_ASISTENCIA_WKF.ID_MESA_REAL = EXT.TB_PORCPARTICIPACION_WKF.ID_MESA
				AND EXT.TB_ASISTENCIA_WKF.ID_CVE_CARGO_REAL = EXT.TB_PORCPARTICIPACION_WKF.ID_CVE_CARGO
				AND EXT.TB_ASISTENCIA_WKF.FECHA_ASISTENCIA = :lv_FECHA
				AND EXT.TB_ASISTENCIA_WKF.ID_SUCURSAL = :i
				AND EXT.TB_ASISTENCIA_WKF.ID_MESA_REAL = :j;
				
			END IF;
		END FOR;
	END FOR;
END