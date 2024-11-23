CREATE PROCEDURE EXT.SP_ASTNCITX ()
LANGUAGE SQLSCRIPT
SQL SECURITY INVOKER
DEFAULT SCHEMA EXT
AS
BEGIN

-- REMOVE C480
-- Plantilla base con cargos sin/con asignación de empleados
-- Cargo dependendiendo de la version de la posición y la fecha de ejecución de este SP
INSERT INTO EXT.TB_ASISTENCIA_WKF (ID_SUCURSAL, ID_EMPLEADO, FECHA_ASISTENCIA, ESTATUS_TRANS, ID_CVE_EMPRESA, ID_MESA_ORIGINAL, ID_MESA_REAL, ID_CVE_CARGO, ID_CVE_CARGO_REAL, PORCENTAJE_PARTICIPACION_EMPLEADO, ASISTENCIA_ITX, DESCANSO, FECHA_CREACION, FECHA_MODIFICACION, USUARIO_CREACION, USUARIO_MODIFICACION)
	SELECT DISTINCT PORC.ID_SUCURSAL, IFNULL(MP.ID_EMPLEADO, PORC.ID_SUCURSAL||PORC.ID_MESA||PORC.ID_CVE_CARGO||TO_INT(PORC.PORCENTAJE_PART_CARGO)), CURRENT_DATE, TO_VARCHAR(0), 'SO004', PORC.ID_MESA, PORC.ID_MESA, PORC.ID_CVE_CARGO, PORC.ID_CVE_CARGO, PORC.PORCENTAJE_PART_CARGO, TO_BOOLEAN('0'), TO_BOOLEAN('0'), CURRENT_DATE, CURRENT_DATE, 'SYSTEM', 'SYSTEM'
	FROM (
			SELECT REF.GENERICATTRIBUTE1 ID_SUCURSAL, REF.NAME ID_EMPLEADO, CURRENT_DATE FECHA_ASISTENCIA, TO_VARCHAR(0) ESTATUS_TRANS, 'SO004' CVE_EMPRESA, PP.ID_MESA ID_MESA_ORIGINAL, PP.ID_MESA ID_MESA_REAL, REF.GENERICATTRIBUTE3 ID_CVE_CARGO, REF.GENERICATTRIBUTE3 ID_CVE_CARGO_REAL, PP.PORCENTAJE_PART_CARGO PORC, TO_BOOLEAN('0') ASISTENCIA_ITX, TO_BOOLEAN('0') DECORADO, CURRENT_DATE FECHA_CREACION, CURRENT_DATE FECHA_MODIFICACION, 'SYSTEM' USUARIO_CREACION, 'SYSTEM' USUARIO_MODIFICACION
		FROM (
			SELECT *
			FROM TCMP.CS_POSITION
			WHERE 1 = 1 -- NAME = '561000209'
			AND EFFECTIVEENDDATE != '2200-01-01'
			UNION
			SELECT *
			FROM TCMP.CS_POSITION
			WHERE 1 = 1 -- NAME = '561000209'
			AND ISLAST = 1
			AND REMOVEDATE = '2200-01-01'
		) REF
		-- JOIN
		INNER JOIN EXT.TB_PORCPARTICIPACION_WKF PP
		ON REF.GENERICATTRIBUTE3 = PP.ID_CVE_CARGO
			AND REF.GENERICATTRIBUTE1 = PP.ID_SUCURSAL
			AND PP.ID_SUCURSAL = REF.GENERICATTRIBUTE1
		--WHERE
		WHERE REF.EFFECTIVESTARTDATE <= CURRENT_DATE
		AND CURRENT_DATE < REF.EFFECTIVEENDDATE
		AND REF.PAYEESEQ IS NOT NULL
		AND REF.GENERICATTRIBUTE1 NOT IN ('C480') -- REMOVE
	) MP
	RIGHT JOIN EXT.TB_PORCPARTICIPACION_WKF PORC
	ON MP.ID_SUCURSAL = PORC.ID_SUCURSAL
	AND MP.ID_MESA_ORIGINAL = PORC.ID_MESA
	AND MP.ID_CVE_CARGO = PORC.ID_CVE_CARGO;
    
-- ACTUALIZAR DESCANSOS
UPDATE EXT.TB_ASISTENCIA_WKF
SET DESCANSO = TRUE
FROM EXT.TB_ASISTENCIA_WKF, EXT.TB_DESCANSO_WKF
WHERE EXT.TB_ASISTENCIA_WKF.ID_SUCURSAL = EXT.TB_DESCANSO_WKF.ID_SUCURSAL
AND EXT.TB_ASISTENCIA_WKF.ID_EMPLEADO = TO_VARCHAR(EXT.TB_DESCANSO_WKF.ID_NUM_EMPL)
AND EXT.TB_ASISTENCIA_WKF.FECHA_ASISTENCIA = EXT.TB_DESCANSO_WKF.ID_FEC_DESCANSO
AND EXT.TB_ASISTENCIA_WKF.FECHA_ASISTENCIA = CURRENT_DATE
AND EXT.TB_DESCANSO_WKF.ID_FEC_DESCANSO = CURRENT_DATE;

END