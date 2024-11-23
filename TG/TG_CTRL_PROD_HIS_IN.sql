CREATE TRIGGER "EXT"."TG_CTRL_PROD_HIS_IN" AFTER INSERT ON "EXT"."TB_CONTROLPRODUCCION_WKF" REFERENCING NEW ROW NEW_R FOR EACH ROW 
BEGIN

    -- Inserción en la tabla histórica para el caso de un nuevo registro (INSERT)
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
        'CREACIÓN'          -- TIPO_MOVIMIENTO
    );
END