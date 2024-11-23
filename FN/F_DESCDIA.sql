CREATE FUNCTION EXT.f_descdia (ID_EMPLEADO VARCHAR(10), FECHA_COMPENSACION DATE) -- parameters
RETURNS RES_STRING VARCHAR(30)
LANGUAGE SQLSCRIPT
AS
BEGIN
    -- data or functions
    DECLARE lv_diaFestivo INT;
    DECLARE lv_descanso BOOLEAN;
    DECLARE lv_vacacincap VARCHAR(1);
    DECLARE lv_asistencia BOOLEAN;
    
    -- FESTIVO
	SELECT FEST.ID_SUCURSAL
	INTO lv_diaFestivo DEFAULT NULL
    FROM EXT.TB_DIAFESTIVO_WKF FEST
    LEFT JOIN TCMP.CS_POSITION POS
    ON POS.GENERICATTRIBUTE1 = FEST.ID_SUCURSAL
    WHERE POS.NAME = :ID_EMPLEADO -- $positonSeq || $1
    AND FEST.ID_FEC_DIAFESTIVO = :FECHA_COMPENSACION
    AND POS.ISLAST = 1
    AND POS.REMOVEDATE = '2200-01-01 00:00:00.000000000';

    -- DESCANSO
    SELECT ASIS.DESCANSO
    INTO lv_descanso DEFAULT NULL
    FROM EXT.TB_ASISTENCIA_WKF ASIS
    LEFT JOIN TCMP.CS_POSITION POS
    ON POS.NAME = :ID_EMPLEADO
    WHERE ASIS.FECHA_ASISTENCIA = :FECHA_COMPENSACION -- $FECHA_COMPENSACION || $7
    AND ASIS.ESTATUS_TRANS IN ('0', '2', '4')
    AND POS.ISLAST = 1
    AND POS.REMOVEDATE = '2200-01-01 00:00:00.000000000'
    AND ASIS.ID_EMPLEADO = :ID_EMPLEADO;

    -- VACACIONES INCAPACIDADES
    SELECT VAC.TIPO
    INTO lv_vacacincap DEFAULT NULL
    FROM EXT.TB_VACACINCAP_ITX_HIS VAC
    LEFT JOIN TCMP.CS_POSITION POS
    ON POS.NAME = :ID_EMPLEADO
    WHERE VAC.FECHA_INICIO <= :FECHA_COMPENSACION AND VAC.FECHA_FIN >= :FECHA_COMPENSACION
    AND POS.ISLAST = 1
    AND POS.REMOVEDATE = '2200-01-01 00:00:00.000000000'
    AND VAC.ID_EMPLEADO = :ID_EMPLEADO;
	
	-- ASISTENCIA
	SELECT ASISTENCIA_ITX
	INTO lv_asistencia DEFAULT NULL
	FROM EXT.TB_ASISTENCIA_WKF
	WHERE ID_EMPLEADO = :ID_EMPLEADO
	AND FECHA_ASISTENCIA = :FECHA_COMPENSACION
	AND ESTATUS_TRANS IN ('0', '2', '4');
	
    -- Returns definiton
    -- IF
    IF (lv_diaFestivo IS NOT NULL AND lv_descanso IS NULL AND lv_vacacincap IS NULL) THEN RES_STRING = 'FESTIVO';
    	ELSEIF (lv_diaFestivo IS NOT NULL AND lv_descanso = FALSE AND lv_vacacincap IS NULL) THEN RES_STRING = 'FESTIVO';
    	ELSEIF (lv_descanso IS NOT NULL AND lv_descanso = TRUE AND lv_diaFestivo IS NULL) THEN RES_STRING = 'DESCANSO';
    	ELSEIF (lv_descanso IS NOT NULL AND lv_descanso = TRUE AND lv_diaFestivo IS NOT NULL) THEN RES_STRING = 'DESCANSO';
    	ELSEIF (lv_vacacincap = 1) THEN 
        	IF (lv_vacacincap = 1) THEN RES_STRING = 'VACACIONES';
        	ELSEIF (lv_descanso IS NOT NULL AND lv_descanso = TRUE AND lv_vacacincap IS NULL) THEN RES_STRING = 'DESCANSO';
    		ELSEIF (lv_descanso IS NOT NULL AND lv_descanso = TRUE AND lv_vacacincap IS NOT NULL) THEN RES_STRING = 'DESCANSO';
    		ELSEIF (lv_descanso IS NOT NULL AND lv_descanso = FALSE AND lv_diaFestivo IS NULL) THEN RES_STRING = 'FESTIVO';
    		ELSEIF (lv_descanso IS NOT NULL AND lv_descanso = FALSE AND lv_diaFestivo IS NOT NULL) THEN RES_STRING = 'FESTIVO';
        	END IF;
        ELSEIF (lv_vacacincap = 2) THEN
        	IF (lv_vacacincap = 2) THEN RES_STRING = 'INCAPACIDAD';
    		ELSEIF (lv_descanso IS NOT NULL AND lv_descanso = FALSE AND lv_diaFestivo IS NULL) THEN RES_STRING = 'INCAPACIDAD';
    		ELSEIF (lv_descanso IS NOT NULL AND lv_descanso = FALSE AND lv_diaFestivo IS NOT NULL) THEN RES_STRING = 'INCAPACIDAD';
        	END IF;
    	ELSEIF (lv_asistencia = FALSE) THEN RES_STRING = 'FALTA';
    	ELSEIF (lv_asistencia = FALSE AND lv_vacacincap IS NULL) THEN RES_STRING = 'FALTA';
    	ELSEIF (lv_asistencia IS NULL) THEN RES_STRING = 'NO APLICA';
    	ELSE RES_STRING = 'ASISTENCIA';
    END IF;
    
END