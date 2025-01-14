DO BEGIN
	DECLARE array_suc INTEGER ARRAY = ARRAY(16, 19, 28, 29, 32, 35, 38, 39, 40, 41, 43, 46, 55, 57, 68, 73, 77, 82, 84, 86, 87, 91, 96, 97, 99, 103, 105, 107, 112, 115, 118, 135, 137, 140, 143, 144, 150, 156, 168, 169, 179, 184, 187, 190, 193, 206, 209, 214, 215, 218, 222, 225, 227, 232, 242, 253, 257, 258, 262, 269, 277, 279, 283, 285, 289, 292, 296, 297, 299, 312, 313, 316, 317, 318, 321, 329, 330, 338, 351, 364, 373, 380, 392, 394, 395, 400, 401, 404, 408, 415, 423, 424, 428, 429, 432, 438, 444, 475, 478, 502, 538, 561, 577, 588, 599, 620, 625, 627, 632, 663, 665, 672, 678, 683, 697, 709, 853);
	DECLARE array_mesa INTEGER ARRAY = ARRAY(2, 4, 5);
	DECLARE array_date DATE ARRAY = ARRAY('2025-01-04', '2025-01-05', '2025-01-06', '2025-01-07', '2025-01-08', '2025-01-09', '2025-01-10');
	DECLARE i INT;
	DECLARE j INT;
	DECLARE k INT;
	FOR i IN 1 .. CARDINALITY(:array_suc) DO -- SUC
		FOR j IN 1 .. CARDINALITY(:array_mesa) DO
			FOR k IN 1 .. CARDINALITY(:array_date) DO
			-- CALL "EXT"."SP_RESET_PORC_SUC"( :array_suc[i] , '2024-11-30');
				CALL "EXT"."SP_RESET_PORC_EV"(:array_suc[i] ,:array_mesa[j], :array_date[k]);
				CALL "EXT"."SP_ACT_PORC_INDV_EV_OR"(:array_suc[i] ,:array_mesa[j], :array_date[k]);
				CALL "EXT"."SP_ACT_VACANTES_INDV_EV_OR"(:array_suc[i] ,:array_mesa[j], :array_date[k]);
				CALL "EXT"."SP_ACT_APOYO_ADIC_INDV_TST_EV_OR"(:array_suc[i] ,:array_mesa[j], :array_date[k]);
				CALL "EXT"."SP_ACT_COMPLEMENTO_INDV_EV_OR"(:array_suc[i] ,:array_mesa[j], :array_date[k]);
			END FOR;
		END FOR;
	END FOR;
END;

DO BEGIN
	DECLARE array_suc INTEGER ARRAY = ARRAY(16, 19, 28, 29, 32, 35, 38, 39, 40, 41, 43, 46, 55, 57, 68, 73, 77, 82, 84, 86, 87, 91, 96, 97, 99, 103, 105, 107, 112, 115, 118, 135, 137, 140, 143, 144, 150, 156, 168, 169, 179, 184, 187, 190, 193, 206, 209, 214, 215, 218, 222, 225, 227, 232, 242, 253, 257, 258, 262, 269, 277, 279, 283, 285, 289, 292, 296, 297, 299, 312, 313, 316, 317, 318, 321, 329, 330, 338, 351, 364, 373, 380, 392, 394, 395, 400, 401, 404, 408, 415, 423, 424, 428, 429, 432, 438, 444, 475, 478, 502, 538, 561, 577, 588, 599, 620, 625, 627, 632, 663, 665, 672, 678, 683, 697, 709, 853);
	DECLARE array_mesa INTEGER ARRAY = ARRAY(1, 3);
	DECLARE array_date DATE ARRAY = ARRAY('2025-01-04', '2025-01-05', '2025-01-06', '2025-01-07', '2025-01-08', '2025-01-09', '2025-01-10');
	DECLARE i INT;
	DECLARE j INT;
	DECLARE k INT;
	FOR i IN 1 .. CARDINALITY(:array_suc) DO -- SUC
		FOR j IN 1 .. CARDINALITY(:array_mesa) DO
			FOR k IN 1 .. CARDINALITY(:array_date) DO
			-- CALL "EXT"."SP_RESET_PORC_SUC"( :array_suc[i] , '2024-11-30');
				CALL "EXT"."SP_RESET_PORC"(:array_suc[i] ,:array_mesa[j], :array_date[k]);
				CALL "EXT"."SP_ACT_PORC_INDV_EV"(:array_suc[i] ,:array_mesa[j], :array_date[k]);
				CALL "EXT"."SP_ACT_VACANTES_INDV_EV"(:array_suc[i] ,:array_mesa[j], :array_date[k]);
				CALL "EXT"."SP_ACT_APOYO_ADIC_INDV_TST_EV"(:array_suc[i] ,:array_mesa[j], :array_date[k]);
				CALL "EXT"."SP_ACT_COMPLEMENTO_INDV_EV"(:array_suc[i] ,:array_mesa[j], :array_date[k]);
			END FOR;
		END FOR;
	END FOR;
END;