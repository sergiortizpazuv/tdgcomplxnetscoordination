# tdgcomplxnetscoordination

Modelo basado en agentes para el estudio de la emergencia de la coordinación en redes complejas a través de un enfoque de integración de redes.

![Imagen de repositorio](https://github.com/sergiortizpazuv/tdgcomplxnetscoordination/blob/master/CIMMnetlogo.PNG?raw=true)

## ¿QUÉ ES ESTO?

Es un modelo para observar la emergencia de la coordinación a traves de la integración de los participantes de la red. El programa crea una red a través de las interacciones aleatorias de parejas de personas (agentes) donde un vinculo se concreta entre dos individuos solo si ambos tienen en común almenos un conocido o si se aventuran a juntarse aun con la desconfianza de no tener referencias de cercanos. (algo así como un esfuerzo de integración o un voto de confianza)

## ¿CÓMO FUNCIONA?

La integración de los agentes para la emergencia de la coordinación se plantea mediante la confianza mutua que debe existir para crear un vinculo entre agentes. Confianza que se genera si existe almenos un amigo en común para los dos, de lo contrario se busca un candidato que sea conveniente para ampliar el circulo de conocidos. Los candidatos se eligen del conjunto de agentes con mejores capacidades de traducción.

## ¿CÓMO UTILIZARLO?

Inicialmente seleccione la cantidad de personas con las que piensa simular la red ajustando la barra <b>num-people</b>.

Ajuste la cantidad máxima de intentos de integración que un agente puede hacer para encontrar un compañero confiable en la entrada con el nombre <b>limit-capacity</b>.

Ingrese el tiempo en ticks que la simulación debe durar en la entrada <b>stopTime</b>. O si lo desea también puede especificar el número aproximado de enlaces que desea tenga la red resultante al final de la simulción.

Luego de configurar y ajustar los pasos anteriores, puedes presionar el botón <b>setup</b> para inicializar la configuración y seguido oprimir el botón <b>go</b> para correr la simulación por tiempo o <b>generate</b> por número de enlaces.

Con el botón <b>go-once</b> puedes observar por cada tick como se integra el agente demarcado de rojo. Si los agentes con los que se relaciona son de color amarillo, significa que es su primer enlace <b>(pioneer-link)</b>, si son verdes es porque se permitió el enlace dado el consentimiento de sus vecinos <b>(deliberation-link)</b>. Y si son de color anaranjado es porque fueron enlazados dada la confianza establecida por algun vecino en común <b>(trust-link)</b>.

Si desea descargar la red generada por el modelo luego de la simulación, puede hacerlo presionando el botón <b>save-network-graphml</b> o <b>save-network-graph6</b> para el formato que guste. Todo lo anterior, no sin antes haber seleccionado un directorio o locación donde será guardado el archivo dando click en <b>select file location</b>.

## COSAS POR INTENTAR

Se puede variar los valores de limit-capacity para ver como se comportan las cantidades de enlaces establecidos por confianza y deliberación.

## NETLOGO FEATURES

El modelo está desarrollado en Netlogo version 5.0.5.
El modelo requiere de las extensiones NW y GRAPH6 para la exportación de las redes generadas para posteriormente analizarlas con otras herramientas como Wolfram Mathematica, R, etc.

## RELATED MODELS

Modelo de inteligencia colectiva. https://github.com/Evalab-Univalle/Collective-intelligence--Analysis-and-modeling

### UBICACIÓN DEL MODELO

El modelo se encuentra en la ruta (path):
/Trabajo de Grado II/Modelo Netlogo/modif/modelo-0-0-4-1.nlogo
