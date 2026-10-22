-- Qué mapa se juega. Cada mapa está en src/server/Maps/ (un archivo por mapa).
--
-- selected: el nombre de un mapa de la lista, o "Aleatorio" para que el servidor elija uno.

return {
	selected = "Fortines",

	-- Nombre del archivo en src/server/Maps/ = nombre que se muestra
	list = {
		CanonRojo = "Cañón Rojo", -- el mapa estándar
		Fortines = "Fortines",
	},
}
