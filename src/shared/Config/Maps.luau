-- Qué mapa se juega. Cada mapa está en src/server/Maps/ (un archivo por mapa).
--
-- selected: el nombre de un mapa de la lista, o "Aleatorio" para que el servidor elija uno.
-- Con "Aleatorio", cada partida nueva se juega en un mapa distinto al anterior.

return {
	selected = "Aleatorio",

	-- Nombre del archivo en src/server/Maps/ = nombre que se muestra
	list = {
		CanonRojo = "Cañón Rojo", -- el mapa estándar
		Fortines = "Fortines",
		Cruce = "El Cruce",
		Estacion = "La Estación",
		CamaraFria = "Cámara Fría",
		Barranca = "La Barranca",
	},

	-- Mapas con jeeps en todos los modos (aunque el modo diga vehicles = false)
	alwaysVehicles = {
		Barranca = true,
	},

	-- La luz de cada mapa (la aplica MapService al construirlo). Los colores son RGB de 0 a 255.
	--   clockTime: hora del día (14 = 2 de la tarde, 17.5 = atardecer)
	--   brightness: qué tan fuerte es el sol
	--   haze: color de la niebla de cerca · decay: color de la niebla a lo lejos
	--   density: qué tanta niebla (0 = nada, 0.5 = mucha) · tint: tono de toda la pantalla
	--   ambient (opcional): luz que llega a donde no da el sol, como bajo techo (RGB)
	--   exposure (opcional): sube (+) o baja (-) la luz de toda la pantalla; 0 = normal
	lighting = {
		-- Cañón desértico: sol de la tarde, polvo cálido
		CanonRojo = {
			clockTime = 15.5,
			brightness = 2.8,
			haze = { 214, 178, 140 },
			decay = { 120, 84, 60 },
			density = 0.33,
			tint = { 255, 244, 228 },
		},
		-- Fuertes de concreto: día nublado, gris azulado
		Fortines = {
			clockTime = 12,
			brightness = 3,
			haze = { 200, 208, 216 },
			decay = { 130, 140, 152 },
			density = 0.25,
			tint = { 246, 248, 255 },
			ambient = { 120, 120, 128 },
			exposure = 0.3,
		},
		-- Zona industrial: atardecer dorado, sombras largas
		Cruce = {
			clockTime = 17.4,
			brightness = 2.4,
			haze = { 222, 186, 150 },
			decay = { 128, 88, 76 },
			density = 0.3,
			tint = { 255, 236, 214 },
		},
		-- Estación cerrada con techo: noche afuera, luces frías por dentro
		Estacion = {
			clockTime = 20,
			brightness = 1,
			haze = { 96, 118, 140 },
			decay = { 40, 52, 70 },
			density = 0.12,
			tint = { 236, 244, 255 },
			ambient = { 140, 145, 160 },
			exposure = 0.5,
		},
		-- Cuarto cerrado de concreto: luz fría y pareja, un poco de bruma
		CamaraFria = {
			clockTime = 12,
			brightness = 2.5,
			haze = { 170, 192, 204 },
			decay = { 100, 120, 134 },
			density = 0.1,
			tint = { 240, 248, 255 },
			ambient = { 140, 148, 158 },
			exposure = 0.4,
		},
		-- Cañón de pasto al aire libre: día claro, un poco de bruma a lo lejos
		Barranca = {
			clockTime = 13.5,
			brightness = 2.6,
			haze = { 196, 212, 226 },
			decay = { 110, 130, 150 },
			density = 0.28,
			tint = { 250, 250, 244 },
		},
	},
}
