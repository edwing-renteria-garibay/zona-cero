# 23. Tienda de armaduras y skins

Con la tecla **B** (o el botón "Tienda" a la izquierda) se abre la tienda:

- **Armadura por partes:** casco, torso, brazos y piernas, en 6 estilos (Militar, Urbano,
  Desierto, Ártico, Noche y Élite). Puedes combinarlas, por ejemplo casco Élite con torso
  Desierto.
- **Skins de armas:** pintan todas tus armas, también la que ves en primera persona.
- **Créditos:** paquetes que se compran con Robux.

Todo es solo visual: las balas atraviesan la armadura y pegan en el cuerpo, igual que sin ella.
Nadie gana ventaja por pagar.

## Uniforme base

Para que la armadura no choque con la ropa de cada avatar, todos aparecen con el mismo cuerpo
de bloques y un uniforme verde olivo, sin la ropa ni los accesorios de Roblox. Esto se logra
con dos cosas:

- En `default.project.json`, `StarterPlayer.LoadCharacterAppearance = false`. Así Roblox no
  carga el avatar de cada jugador. Si Rojo no lo aplica, búscalo en Studio: **StarterPlayer** >
  Propiedades > **LoadCharacterAppearance**, y desactívalo.
- `ArmorService.ApplyUniform` quita cualquier ropa o accesorio que quede y pinta el cuerpo con
  los colores de `Shop.uniform`.

Para que cada quien use su avatar otra vez, pon `Shop.uniform.enabled = false` y
`LoadCharacterAppearance` en `true`.

## Créditos (¢)

Se ganan jugando (valores en `Shop.rewards`):

| Qué | Créditos |
| --- | --- |
| Baja | 10 |
| Baja a la cabeza | 5 extra |
| Terminar una partida | 25 |
| Ganarla | 75 extra |

Un jugador nuevo empieza con 200 ¢.

## Dónde está cada cosa

| Archivo | Qué hace |
| --- | --- |
| `src/shared/Config/Shop.luau` | Precios, estilos, skins, premios y paquetes de Robux |
| `src/server/Services/ShopService.luau` | Créditos, compras, guardado y paquetes de Robux |
| `src/server/Services/ArmorService.luau` | Pone las placas de armadura en el personaje |
| `src/shared/WeaponSkins.luau` | Pinta las armas con una skin |
| `src/client/UI/Shop.luau` | El menú, con la vista previa de tu personaje |

## Agregar un estilo o una skin

En `Config/Shop.luau`, copia uno de los estilos de `Shop.armor` y cámbiale `id`, `name`,
`price` y los colores. El `id` no debe tener espacios ni acentos, porque se usa para guardar
lo que compró cada jugador. Si cambias el `id` de algo ya vendido, quien lo compró lo pierde.

Las skins de armas van en `Shop.weaponSkins`. Una skin no pinta todo del mismo color: cada
pieza toma el tono de la skin pero conserva qué tan clara u oscura era, para no perder los
detalles. Las piezas que brillan (Neon) no cambian.

## Cómo se guarda

`ShopService` usa un **DataStore**, el almacenamiento de Roblox que no se borra al salir del
juego. Por cada jugador guarda sus créditos, lo que compró y lo que lleva puesto. Se guarda:

- al comprar algo,
- cada 2 minutos si ganó créditos,
- al salir del juego,
- al cerrar el servidor.

**En Studio** el DataStore solo funciona si el juego está publicado y activaste
*Configuración del juego > Seguridad > Enable Studio Access to API Services*. Si no, la tienda
funciona igual, pero no guarda nada (verás un aviso en la Salida).

**En modo de prueba** (`Modes.Testing.enabled = true`) la tienda no guarda nada y todos
empiezan con 5000 ¢, para que puedas probarla sin jugar.

## Seguridad: el servidor decide

El menú no cambia tus créditos. Solo le pide al servidor "quiero comprar Helmet.Elite" con
el RemoteFunction `Shop`. El servidor revisa que el objeto exista, que no lo tengas ya y que te
alcance, y solo entonces cobra. Si un tramposo manda pedidos falsos, el servidor los ignora.

## Paquetes de créditos con Robux

Cada paquete es un **Developer Product** (algo que se puede comprar muchas veces). Para
activarlos:

1. Publica el juego.
2. En el [Creator Dashboard](https://create.roblox.com/dashboard/creations), abre la
   experiencia y ve a **Monetization > Developer Products**.
3. Crea uno por paquete, por ejemplo "500 créditos" a 49 Robux.
4. Copia el **ID** de cada uno y ponlo en `productId` dentro de `Shop.creditPacks`.
   El campo `robux` solo es el texto que se muestra: el precio real es el del Dashboard,
   así que pon el mismo número en los dos.

Mientras un paquete tenga `productId = 0`, sale como "Próximamente".

Cuando alguien compra, Roblox llama a `processReceipt` en `ShopService`. Ahí se suman los
créditos y se guarda en seguida. Si no se pudo guardar, se responde `NotProcessedYet` y Roblox
lo intenta otra vez más tarde. Así nadie paga Robux sin recibir sus créditos. Cada compra
tiene un número (`PurchaseId`) que se recuerda, para no darla dos veces.

## El mouse con el menú abierto

En primera persona Roblox fija el mouse en el centro. El fondo oscuro del menú es un
`TextButton` con `Modal = true`, y eso suelta el mouse mientras el menú está abierto. Como es un
botón, los clics se quedan en el menú y no disparan tu arma.
