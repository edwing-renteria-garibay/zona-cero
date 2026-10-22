# 16 · Asalto

Una sola bomba. En cada ronda un equipo **ataca** y el otro **defiende**; en la siguiente
ronda se cambian los papeles. El código está en `src/server/Services/AssaultService.luau`.

## Las reglas

1. La bomba aparece en la base de bandera de los atacantes (la misma pieza `FlagStand` de
   Captura la bandera). Cualquier atacante la toma al tocarla.
2. Hay que llevarla a la base de bandera enemiga y quedarse ahí **3 segundos**. El letrero
   de la bomba cuenta hacia atrás ("ARMANDO 2.0"). Si te alejas, se reinicia.
3. Si explota, los atacantes ganan 1 punto y la ronda termina.
4. Si matan al que la lleva, la bomba cae al piso y se queda ahí hasta que otro atacante
   la tome. Los defensores no la pueden mover: les toca cuidarla para que nadie la recoja.
5. Cada ronda dura 2 min 30 s. Si nadie la detona, los defensores aguantaron y se cambian los
   papeles. Entre rondas todos reaparecen en su base.
6. Gana el primer equipo en detonar **3 bombas** (o el límite de 15 minutos).

El letrero "BOMBA" se ve a través de las paredes: todos saben dónde está. Arriba, el
marcador dice la ronda, si atacas o defiendes, y cuánto le queda a la ronda.

Todo se cambia en `Config/Modes.luau`, en `Assault`.

## Cómo funcionan las rondas

`runRounds` es un ciclo que corre en su propio hilo (`task.spawn`):

1. Pone la bomba en casa y avisa "Ronda 2: ataca Rojo, defiende Azul".
2. Cada 0.1 s llama a `update`, que revisa quién la toca, quién la lleva y si se está armando.
3. Cuando explota o se acaba el tiempo, espera 4 s y cambia de equipo atacante.

Para poder detenerlo cuando termina la partida se usa un número, `generation`. Cada vez que
la partida empieza o termina, el número cambia, y el ciclo viejo ve que ya no es el suyo y
se detiene.

## Para probar

En `Modes.luau` pon `Modes.selected = "Assault"` y abre Servidor y clientes con 2
jugadores (uno en cada equipo). Para no esperar, baja `roundTime` a 30.
