# 15 · Infección

Zombis contra sobrevivientes. El código está en `src/server/Services/InfectionService.luau`
(servidor) y `src/client/UI/InfectionView.luau` (lo que ve cada jugador).

## Las reglas

1. Al empezar la partida se eligen zombis al azar: 1 por cada 4 jugadores, mínimo 1 y
   máximo 3. Antes de empezar nadie sabe quién va a ser.
2. Los zombis no tienen armas de fuego, escudo ni granadas, pero tienen 150 de vida (un
   sobreviviente tiene 100). Llevan un **machete** y golpean con **F** o **clic**: un
   machetazo mata. Corren a 26
   (los sobrevivientes caminan a 16).
3. Un zombi ve a los sobrevivientes resaltados en azul, aunque haya paredes.
4. Si un sobreviviente muere, por la razón que sea, se vuelve zombi.
5. Ganan los zombis si ya no queda ningún sobreviviente. Si al acabarse el tiempo (5 min)
   queda al menos uno, ganan los sobrevivientes.

El marcador muestra cuántos quedan de cada lado: sobrevivientes a la izquierda y zombis a la
derecha. Todo esto se cambia en `Config/Modes.luau`, en `Infection`.

## Cómo sabe el juego quién es quién

Cada jugador tiene un **atributo** `Side` con el valor `"Zombie"` o `"Survivor"`. Los
atributos se ven también desde el cliente, así que:

- `CombatService` y `ExplosionService` comparan el `Side`: los del mismo lado no se hacen daño.
- `LoadoutService` no le da armas a un zombi.
- `InfectionView` (cliente) le pone un `Highlight` a cada sobreviviente, pero solo si tú eres
  zombi. Como lo crea tu cliente, solo tú lo ves.
- `MeleeController` también golpea con el clic si eres zombi.

## Cómo se ve un zombi

`applyZombie` le quita armas, granadas y escudo, le da el machete y sube su `WalkSpeed` y
su `MaxHealth`.

El machete es un `Tool` que se arma en código (`makeMachete`): una hoja de metal (el
`Handle`) y un mango de madera soldado. `tool.Grip` dice dónde lo agarra la mano: en un
extremo, para que la hoja salga hacia el frente. Para ponerlo en la mano basta con meter el
`Tool` dentro del personaje. No hace daño por sí solo: el golpe lo sigue haciendo
`CombatService` (el mismo de la tecla F), que con un zombi lo cuenta como "Machete" en el
registro de bajas. También le quita la
ropa (`Shirt`, `Pants`) y pinta su piel de verde con `BodyColors`, para que se reconozca
de lejos.

## Casos especiales

- Si alguien entra a mitad de partida, empieza como zombi.
- Si se salen todos los zombis, se elige otro al azar.

## Para probar

En `Modes.luau` pon `Modes.selected = "Infection"` y abre Servidor y clientes con 2
jugadores. Uno será zombi: revisa que vea al otro a través de las paredes y que lo mate de
un golpe. Para no esperar 5 minutos, baja `timeLimit`.
