# 21. Armas especiales

Seis armas nuevas que se recogen en plataformas naranjas de los mapas, como el lanzacohetes.
Todas tienen sus números en `src/shared/Config/Weapons.luau`, su forma en
`src/shared/WeaponModels.luau` y sus sonidos en `src/shared/Config/Sounds.luau`.

| Arma | Nombre en el código | Cómo funciona |
| --- | --- | --- |
| Escopeta | `Shotgun` | 8 perdigones a la vez. De cerca mata de un tiro, de lejos casi no hace daño. |
| Lanzallamas | `Flamethrower` | Daña a todos los enemigos en un cono corto y los deja quemándose 3 s. |
| Rayo de energía | `LaserRifle` | Rayo verde instantáneo y preciso. Mata en 2 tiros. |
| Francotirador | `Sniper` | Clic derecho (o L2 en el mando) para apuntar con zoom. A la cabeza mata de un tiro. |
| Arma de hielo | `IceGun` | Poco daño, pero el enemigo camina a menos de la mitad de velocidad un rato. |
| Cañón de iones | `IonCannon` | Un láser rojo marca el punto. Al disparar aparece un círculo rojo, y 1.5 s después cae un rayo que explota. |

## Dónde aparecen

En cada mapa:

- **Francotirador y escopeta:** hay dos de cada una, una del lado de cada equipo y a la misma
  distancia de su base.
- **Las otras cuatro:** hay una de cada una, a la misma distancia de las dos bases, para que
  nadie tenga ventaja.

Las posiciones están al final de `Build` en cada archivo de `src/server/Maps/`. Busca
`Builder.pickupPad(map, "SniperPad", ...)`. Para mover un arma, cambia su `Vector3.new(x, y, z)`.

## Cómo se programó cada una

El servidor (`CombatService.onFire`) revisa `kind` en Config/Weapons:

- **Sin `kind`:** una bala normal, con un solo raycast. Así funcionan el rifle, la pistola, el
  rayo, el francotirador y el arma de hielo.
- **`"pellets"`:** `firePellets` hace un raycast por perdigón. Cada perdigón se desvía un poco al
  azar, hasta `spread` grados (función `spreadDirection`).
- **`"flame"`:** `fireFlame` no usa balas. Revisa a cada enemigo:
  - si está a menos de `range`;
  - si está dentro del cono (compara direcciones con `Dot`, el producto punto);
  - si no hay una pared en medio.
  
  Al que pasa las tres pruebas lo daña y lo quema con `ignite`.
- **`"ion"`:** `fireIon` busca el punto al que apuntas y llama a `ProjectileService.IonStrike`.
  Esa función pone el círculo rojo y, con `task.delay`, hace caer el rayo y la explosión.

Con `slow`, un acierto llama a `slowDown`, que hace tres cosas:

- baja la `WalkSpeed` del enemigo;
- lo pinta de azul con un `Highlight`;
- le avisa con el RemoteEvent `Frozen`, para que solo él oiga el sonido y vea la pantalla azul.

Del lado del jugador:

- `WeaponController` dibuja cada disparo según `beam`: el rayo verde, el azul o el láser rojo. Las
  llamas son bolas naranjas que crecen.
- `SpecialWeapons` (nuevo) maneja la mira del francotirador, el láser del cañón de iones y la
  pantalla congelada.

### La mira del francotirador

Para ver más cerca, se baja el campo de visión de la cámara (`FieldOfView`) de 70 a 18. El círculo
negro es un `Frame` redondo (`UICorner`) con un borde (`UIStroke`) de 2000 píxeles que tapa todo
lo demás.

## Sonidos

En `Config/Sounds` hay tres listas nuevas:

- `reload`: el sonido de recarga de cada arma.
- `emptyBy`: el clic sin balas de cada arma.
- `frozen`: el sonido que oye quien recibe un disparo de hielo.

El lanzallamas está en `burst`: su sonido se repite mientras disparas, en lugar de sonar entero
con cada llama.

El cañón de iones no tenía sonido propio, así que su explosión usa la del cohete. Puedes cambiarla
en `explosion.ion`.
