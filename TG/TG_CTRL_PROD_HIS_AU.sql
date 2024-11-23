CREATE TRIGGER "EXT"."TG_CTRL_PROD_HIS_AU" AFTER UPDATE ON "EXT"."TB_CONTROLPRODUCCION_WKF" REFERENCING OLD ROW OLD_U, NEW ROW NEW_R FOR EACH ROW 
BEGIN

	-- Se actualizae el regsitro anterior para cerrar la validez
	UPDATE EXT.TB_CONTROLPRODUCCION_HIS
    SET "FECHA_FIN" = CURRENT_TIMESTAMP
    WHERE "ID_EMPRESA" = :OLD_U."ID_EMPRESA"
    	AND "ID_SUCURSAL" = :OLD_U."ID_SUCURSAL"
        AND "ID_MESA" = :OLD_U."ID_MESA"
        AND "FECHA_PRODUCCION" = :OLD_U."FECHA_PRODUCCION"
        AND "FECHA_FIN" IS NULL;
	
    -- Inserción en la tabla como nueva entrada en la histórica
    INSERT INTO EXT.TB_CONTROLPRODUCCION_HIS (
        "ID_EMPRESA",
        "ID_SUCURSAL",
        "ID_MESA",
        "FECHA_PRODUCCION",
        "ESTATUS",
        "USUARIO_CREACION",
        "USUARIO_MODIFICACION",
        "FECHA_CREACION",
        "FECHA_MODIFICACION",
        "FECHA_INICIO",
        "FECHA_FIN",
        ACCION
    ) VALUES (
        :NEW_R."ID_EMPRESA",
        :NEW_R."ID_SUCURSAL",
        :NEW_R."ID_MESA",
        :NEW_R."FECHA_PRODUCCION",
        :NEW_R."ESTATUS",
        :NEW_R."USUARIO_CREACION",
        :NEW_R."USUARIO_MODIFICACION",
        :NEW_R."FECHA_CREACION",
        :NEW_R."FECHA_MODIFICACION",
        CURRENT_TIMESTAMP,  -- FECHA_INICIO (actual)
        NULL,               -- FECHA_FIN (registro vigente)
        'ACTUALIZACIÓN'          -- TIPO_MOVIMIENTO
    );
END