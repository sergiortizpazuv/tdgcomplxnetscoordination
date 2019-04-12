;; version del modelo. version 0.0.4.01
;; Modelo basado en la confianza mutua como mecanismo de integración, la traducción, la deliberacion y negociación
;; Author: Sergio Ortiz P.

extensions [graph6 nw]

globals [
  num-trials               ;; numero máximo de intentos que un agente puede hacer para encontrar otro agente que ya esté relacionado con almenos uno de las amistades propias
  num-selection            ;; cantidad de agentas que actuaran en cada tick de la simulacion 
  location                 ;; cadena que almacena la ruta al directorio donde se almacenará la red resultante de la simulación
  
  num-pioneer-links
  num-trust-links
  num-deliberation-links
]

breed [people person]      ;; cada agente o nodo representa a una persona

people-own [
  trial-capacity           ;; número de veces que puede una persona buscar a una persona de mutua confiabilidad en un tick de la simulación
  traduction-capacity      ;; número que denota el estatus de una persona para servir de intermediario entre grupos distintos
]

to setup
  ;; se inicializa el modelo
  ca                        ;;se limpia la escena
  set-default-shape people "circle"

  set num-selection 1
  set num-trials limit-capacity
  set num-trust-links 0
  set num-deliberation-links 0
  set num-pioneer-links 0

  ;; inicializa las personas
  setup-people

  ;; se establece la ubicacion del directorio donde se guardaran las redes del modelo
  set location (word graph-file-location "integration-network-" num-people "-" num-trials)

  reset-ticks

end

to setup-people
  create-people num-people [
    setxy random-xcor random-ycor
    set color blue
    
    set trial-capacity ((random num-trials) + 1)
    set traduction-capacity 0
  ]
end

to go
  if ticks = stopTime [ stop ]
  ;; Seleccion de un grupo de personas o una sola aleatoriamente
  let selection n-of num-selection people
  ;; Se le pide a la selección que se relacione con personas de confianza
  ask selection [
    ;make-selection-choose self
    make-person-relate self
  ]
  tick
end


to make-person-relate [agent]
  ask people [ set color blue ]
  ask agent [ set color red ]
  repeat trial-capacity [
    make-integration agent
  ]
end

to make-integration [ agent ]
  
  let vecinos [link-neighbors] of agent
  let selected-one nobody
  let flag false
  if (count vecinos) > 0 [
    ;;seleccionamos un vecino al azar
    let vecino-seleccionado one-of vecinos
    ;;contactos del vecino, excepto el propio agente y contactos compartidos
    let conocidos-indirectos ([link-neighbors] of vecino-seleccionado) with [ not member? self (turtle-set vecinos agent)]
    
    ;;si el conj de conocidos-indirectos es vacio, quiere decir que el vecino seleccionado no tiene vecinos aun o todos sus contactos hacen parte de los del agente
    if (count conocidos-indirectos) > 0 [
      set flag true
      ;;una vez tenemos los conocidos indirectos no comunes podemos seleccionar uno para crear un enlace de confianza mutua
      set selected-one one-of conocidos-indirectos
    ]
  ]
  
  ;;de acuerdo al flag, si es verdadero se conecta con un agente referenciado por uno de los contactos del agente, de lo contrario se escoge cualquiera distinto de los ya relacionados
  ifelse flag [
    ;;crear el link
    ask agent [ create-link-with selected-one ]
    ask selected-one [ set color orange ]
    set num-trust-links (num-trust-links + 1)
  ]
  [
    ;;si no tiene vecinos, generar un link con cualquier nodo diferente de los propios
    let grupo-azar people with [ not member? self (turtle-set agent vecinos) ]
    
    ;;si el conjunto grupo-azar esta vacio quiere decir que para el agente ya no hay posibles nodos o agentes para relacionarse
    if (count grupo-azar) > 0 [
      let top-traductors sort-on [(- traduction-capacity)] grupo-azar
      ;;Seleccionar de la lista de top-traductors un agente al azar de los mejores calificados en traduction-capacity.
      set selected-one item (round ((count grupo-azar) * 0.05)) top-traductors
      ;;Si el agente no tiene vecinos, se hace un enlace pionero como forma inicial de integración con el agente selected-one (de buena capacidad de traducción)
      ifelse (count vecinos) = 0 [
        ask agent [ create-link-with selected-one ]
        ask selected-one [ 
          set color yellow
          set traduction-capacity (traduction-capacity + 1)
          set label traduction-capacity
          set num-pioneer-links (num-pioneer-links + 1)
        ]
      ]
      [
        ;;Dado que el agente si tiene vecinos se les convoca a votar para deliberar si es conveniente enlazarse con el agente selected-one
        if (deliberation vecinos selected-one) [
          ask agent [ create-link-with selected-one ]
          ask selected-one [ 
            set color green
            set traduction-capacity (traduction-capacity + 1)
            set label traduction-capacity
            set num-deliberation-links (num-deliberation-links + 1)
          ]
        ]
      ]
    ]
  ]
    
end

;;hacer votacion para deliberar si el agente que eligió un amigo es aceptable
to-report deliberation [ neighboors selected-agent ]
  let votes 0
  let num-neighbors (count neighboors)
  ask neighboors [
    if not member? selected-agent ([link-neighbors] of self) [
      set votes (votes + 1)
    ]
  ]
  ifelse (votes > (num-neighbors / 2)) [
    ;print (word "Votacion pasó con : " votes "/" num-neighbors " de los votos") 
    report true
  ]
  [
    ;print (word "Votacion no pasó con : " votes "/" num-neighbors " de los votos")
    report false
  ]
end


to save-network-graphml
  nw:set-context people links
  nw:save-graphml (word graph-file-location "integration-network-" num-people "-" stopTime ".graphml")
  user-message (word "Red guardada como integration-network-" num-people "-" stopTime ".graphml en: " graph-file-location)
end

to save-network-graph6
  graph6:save-graph6 people links (word graph-file-location "integration-network-" num-people "-" stopTime ".g6")
  print (word "Graph was successfully saved on directory: " location)
  ;print timer
end

to save
  nw:set-context people links
  nw:save-graphml (word graph-file-location "integration-network-" num-people "-" stopTime ".graphml")
  print (word "Red guardada como integration-network-" num-people "-" stopTime ".graphml en: " graph-file-location)
end

to select-directory
  set graph-file-location user-directory
end



;; Procedimiento para generar redes con un numero promedio de enlaces
to generate
  ;let mylinks (count links)
  ;if mylinks = nb-of-links [ stop ]
  if (num-pioneer-links + num-trust-links + num-deliberation-links) >= nb-of-links [ stop ]
  ;; Seleccion de un grupo de personas o una sola aleatoriamente
  let selection n-of num-selection people
  ;; Se le pide a la selección que se relacione con personas de confianza
  ask selection [
    ;make-selection-choose self
    make-person-relate self
  ]
  tick
end








@#$#@#$#@
GRAPHICS-WINDOW
457
13
1312
473
32
16
13.0
1
10
1
1
1
0
0
0
1
-32
32
-16
16
0
0
1
ticks
30.0

INPUTBOX
3
10
319
70
graph-file-location
C:\\Users\\usuario\\Documents\\Trabajo de Grado II\\RedesDeAnalisis\\Version4\\Muestras\\2analisisPorTicks\\5\\500\\50porcientocompletitud\\
1
0
String

SLIDER
4
77
319
110
num-people
num-people
2
1000
500
1
1
NIL
HORIZONTAL

INPUTBOX
6
122
92
182
limit-capacity
5
1
0
Number

BUTTON
322
49
385
82
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
387
49
450
82
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
237
123
437
273
degree distribution
degree
# of people
1.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" "let max-degree max [count link-neighbors] of people\nplot-pen-reset ;; erase what we plotted before\nif max-degree > 0 [\nset-plot-x-range 1 (max-degree + 1) ;; +1 to make room for the width of the last bar\n]\nhistogram [count link-neighbors] of people"

INPUTBOX
102
122
185
182
stopTime
500
1
0
Number

BUTTON
322
12
451
45
select file location
select-directory
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
7
223
185
256
NIL
save-network-graphml
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
9
277
297
305
Generar red con la cantidad de enlaces especificados por nb-of-links aproximadamente
11
0.0
1

INPUTBOX
11
303
166
363
nb-of-links
5000
1
0
Number

BUTTON
171
303
253
336
NIL
generate
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
345
85
422
118
go-once
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
321
290
438
335
NIL
num-deliberation-links
17
1
11

MONITOR
322
340
437
385
NIL
num-trust-links
17
1
11

BUTTON
7
186
185
219
NIL
save-network-graph6
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
323
388
436
433
NIL
num-pioneer-links
17
1
11

MONITOR
173
341
295
386
links-of-complete-graph
(num-people * (num-people - 1)) / 2
17
1
11

@#$#@#$#@
## ¿QUÉ ES ESTO?

Es un modelo para observar la emergencia de la coordinación a traves de la integración de los participantes de la red. El programa crea una red a través de las interacciones aleatorias de parejas de personas (agentes) donde un vinculo se concreta entre dos individuos solo si ambos tienen en común almenos un conocido o si se aventuran a juntarse aun con la desconfianza de no tener referencias de cercanos. (algo así como un esfuerzo de integración o un voto de confianza)

## ¿CÓMO FUNCIONA?

La integración de los agentes para la emergencia de la coordinación se plantea mediante la confianza mutua que debe existir para crear un vinculo entre agentes. Confianza que se genera si existe almenos un amigo en común para los dos, de lo contrario se busca un candidato que sea conveniente para ampliar el circulo de conocidos. Los candidatos se eligen del conjunto de agentes con mejores capacidades de traducción.

## ¿CÓMO UTILIZARLO?

Inicialmente seleccione la cantidad de personas con las que piensa simular la red ajustando la barra **num-people**.

Ajuste la cantidad máxima de intentos de integración que un agente puede hacer para encontrar un compañero confiable en la entrada con el nombre **limit-capacity**


Ingrese el tiempo en ticks que la simulación debe durar en la entrada **stopTime**. O si lo desea también puede especificar el número aproximado de enlaces que desea tenga la red resultante al final de la simulción.

Luego de configurar y ajustar los pasos anteriores, puedes presionar el botón **setup** para inicializar la configuración y seguido oprimir el botón **go** para correr la simulación por tiempo o **generate** por número de enlaces.

Con el botón **go-once** puedes observar por cada tick como se integra el agente demarcado de rojo. Si los agentes con los que se relaciona son de color amarillo, significa que es su primer enlace (pioneer-link), si son verdes es porque se permitió el enlace dado el consentimiento de sus vecinos (deliberation-link). Y si son de color anaranjado es porque fueron enlazados dada la confianza establecida por algun vecino en común (trust-link). 

Si desea descargar la red generada por el modelo luego de la simulación, puede hacerlo presionando el botón **save-network-graphml** o **save-network-graph6** para el formato que guste. Todo lo anterior, no sin antes haber seleccionado un directorio o locación donde será guardado el archivo dando click en **select file location**.


## COSAS POR INTENTAR

Se puede variar los valores de limit-capacity para ver como se comportan las cantidades de enlaces establecidos por confianza y deliberación.


## NETLOGO FEATURES

El modelo hace uso de las extensiones NW y GRAPH6 para la exportación de las redes generadas.

## RELATED MODELS

Modelo de inteligencia colectiva. https://github.com/Evalab-Univalle/Collective-intelligence--Analysis-and-modeling

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.0.5
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@
