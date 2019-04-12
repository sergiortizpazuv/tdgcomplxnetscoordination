extensions [nw]

globals [ lista-ticks ]

turtles-own [
  adoptee-neighbors ;; count of number of red linked turtles
  random-thresh ;; instantaneous random threshold for adoption -- currently _i(t) uncorrelated w/ _i(t+1)
]

to setup
  ;; (for this model to work with NetLogo's new plotting features,
  ;; __clear-all-and-reset-ticks should be replaced with clear-all at
  ;; the beginning of your setup procedure and reset-ticks at the end
  ;; of the procedure.)
  __clear-all-and-reset-ticks
  set lista-ticks (list)
  setup-pa
  ask turtle random number-of-nodes [set color red]
end

to update-local-search
  ask turtles [ 
    set adoptee-neighbors count link-neighbors with [color = red]
    ;;set adoptee-neighbors 5
    set label adoptee-neighbors 
    set label-color green ]
end

to decide-adopt
  let nadopt count turtles with [color = red]
  ask turtles [
    set shape "circle"
    if color = white [
      set random-thresh random-normal 50 25
      if random-thresh < 1 [ set random-thresh 0] 
      ;;set random-thresh random-poisson 20 
      if random-thresh < constant-effect + ( endogenous-effect * (nadopt / number-of-nodes ) ) + ( adoptee-neighbors * cohesion-effect ) [
           set color red 
           set shape "circle 2"]
      ;; adopt if random number (0-100) is lower than
      ;; constant hazard + proportion adopted * endogenous hazard
      ;; note, cohesion-fx doesn't seem to work yet
    ]
  ]
end

to go
  ;if ticks >= 100 [stop]
  let adopters count turtles with [ color = red ]
  if adopters = number-of-nodes [ 
    ;set lista-ticks lput difussion-time lista-ticks
    stop
     ]
  update-local-search
  decide-adopt
  tick
  do-plots
end

to go-once
  go
end

to wipe
  reset-ticks
  clear-all-plots
  ask turtles [
    set color white
    set label ""
    set shape "circle"]
  ask turtle random number-of-nodes [set color red]
end

to do-plots
  set-current-plot "Totals"
  set-current-plot-pen "adoptions"
  plot count turtles with [color = red]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; all code below this line is borrowed (with minor changes) from model library "Preferential Attachment"
;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to setup-pa
  set-default-shape turtles "circle"
  ;; make the initial network of two turtles and an edge
  make-node nobody        ;; first node, unattached
  make-node turtle 0      ;; second node, attached to first node
  repeat (number-of-nodes - 2) [ go-pa ]
  ask turtles [set color white]
  ask links [set color grey]
  reset-ticks
end

to go-pa
  ask links [ set color gray ]
  make-node find-partner         ;; find partner & use it as attachment
                                 ;; point for new node
  tick
  if layout? [ layout ]
  ;;if plot? [ do-plotting ]
end

;; used for creating a new node
to make-node [old-node]
  crt 1
  [
    set color red
    if old-node != nobody
      [ create-link-with old-node [ set color green ]
        ;; position the new node near its partner
        move-to old-node
        fd 8
      ]
  ]
end

;; This code is borrowed from Lottery Example (in the Code Examples
;; section of the Models Library).
;;  ...
to-report find-partner
  let total random-float sum [count link-neighbors] of turtles
  let partner nobody
  ask turtles
  [
    let nc count link-neighbors
    ;; if there's no winner yet...
    if partner = nobody
    [
      ifelse nc > total
        [ set partner self ]
        [ set total total - nc ]
    ]
  ]
  report partner
end


;;;;;;;;;;;;;;
;;; Layout ;;;
;;;;;;;;;;;;;;

;; resize-nodes, change back and forth from size based on degree to a size of 1
to resize-nodes
  ifelse all? turtles [size <= 1]
  [
    ;; a node is a circle with diameter determined by
    ;; the SIZE variable; using SQRT makes the circle's
    ;; area proportional to its degree
    ask turtles [ set size sqrt count link-neighbors ]
  ]
  [
    ask turtles [ set size 1 ]
  ]
end

to layout
  ;; the number 3 here is arbitrary; more repetitions slows down the
  ;; model, but too few gives poor layouts
  repeat 3 [
    ;; the more turtles we have to fit into the same amount of space,
    ;; the smaller the inputs to layout-spring we'll need to use
    let factor sqrt count turtles
    ;; numbers here are arbitrarily chosen for pleasing appearance
    layout-spring turtles links (1 / factor) (7 / factor) (1 / factor)
    display  ;; for smooth animation
  ]
  ;; don't bump the edges of the world
  let x-offset max [xcor] of turtles + min [xcor] of turtles
  let y-offset max [ycor] of turtles + min [ycor] of turtles
  ;; big jumps look funny, so only adjust a little each time
  set x-offset limit-magnitude x-offset 0.1
  set y-offset limit-magnitude y-offset 0.1
  ask turtles [ setxy (xcor - x-offset / 2) (ycor - y-offset / 2) ]
end

to-report limit-magnitude [number limit]
  if number > limit [ report limit ]
  if number < (- limit) [ report (- limit) ]
  report number
end

;;;;;;;;;;;;;;;;;;;;;
;;TO DO NOTES
;;1. also allow "Small Worlds" or "Giant Component" network structures in initial setup phase that builds network
;;2. batching
;; a. create "auto-pilot" switch that overrides other GUI elements and goes to loops over hard-coded lists
;; b. use file i/o to record results so as to pipe to gnuplot and/or Stata
;;3. build in awareness/adoption distinction where awareness can be spread either exo or endo (from adopters) 
;; can use color [white=nothing, yellow=aware, red=adopt where yellow are more susceptible than white]

to load-graphml
  __clear-all-and-reset-ticks
  set lista-ticks (list)
  set-default-shape turtles "circle"
  nw:set-context turtles links
  let graphmlfile user-file
  if is-string? graphmlfile [ nw:load-graphml graphmlfile ]
  set number-of-nodes (count turtles)
  ask turtles [set color white]
  ask links [set color grey]
  ask turtle random number-of-nodes [set color red]
  repeat 3 [ layout ]
end


to experiment
  ; samples = 10
  set lista-ticks (list)
  let i 1
  repeat samples [
    dosample
    set i (i + 1)
    print (word "repeat number " i) 
  ]
  
  ;set lista-ticks lput difussion-time lista-ticks
end

to dosample
  let adoptions 0
  ifelse experiment-type = 1 [ wipe ]
  [
    wipe-dos nodo
    print (word "nodo elegido: " nodo)
  ]
  ;wipe
  while [ adoptions < number-of-nodes ]
  [
    go
    set adoptions count turtles with [ color = red ]
    ;print (word "adoptions: " adoptions)
    ]
  ;print "salio"
  set lista-ticks lput difussion-time lista-ticks
end

to-report difussion-time
  report ticks
end

to-report trululu
  ifelse empty? lista-ticks [ report 0 ]
  [ report mean lista-ticks ]
end


to wipe-dos [ tortuga ]
  reset-ticks
  clear-all-plots
  ask turtles [
    set color white
    set label ""
    set shape "circle"]
  ask turtle tortuga [set color red]
end

to experimento-dos
  
end















@#$#@#$#@
GRAPHICS-WINDOW
210
10
688
509
16
16
14.2
1
10
1
1
1
0
1
1
1
-16
16
-16
16
0
0
1
ticks
30.0

BUTTON
6
10
72
43
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

SLIDER
6
126
178
159
constant-effect
constant-effect
0
25
0
1
1
NIL
HORIZONTAL

BUTTON
137
10
200
43
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
4
229
204
379
Totals
time
adoptions
0.0
100.0
0.0
100.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" ""
"adoptions" 1.0 0 -2674135 true "" ""

SLIDER
6
158
180
191
endogenous-effect
endogenous-effect
0
25
0
1
1
NIL
HORIZONTAL

SWITCH
6
43
109
76
layout?
layout?
0
1
-1000

BUTTON
73
10
136
43
NIL
wipe
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
6
76
178
109
number-of-nodes
number-of-nodes
0
1000
100
1
1
NIL
HORIZONTAL

SLIDER
7
192
179
225
cohesion-effect
cohesion-effect
0
25
2
1
1
NIL
HORIZONTAL

BUTTON
116
44
201
77
NIL
go-once
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
10
393
73
426
clear
clear-all
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
92
394
195
427
NIL
load-graphml
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
10
429
67
474
NIL
ticks
0
1
11

MONITOR
90
431
177
476
average ticks
trululu
17
1
11

BUTTON
697
222
791
269
NIL
experiment
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

CHOOSER
799
222
891
267
samples
samples
100 200 300 400 500 600 700 800 900 1000
1

INPUTBOX
694
110
753
170
nodo
48
1
0
Number

CHOOSER
764
111
902
156
experiment-type
experiment-type
1 2
0

MONITOR
698
272
888
317
Average complete diffusion time
mean lista-ticks
17
1
11

MONITOR
700
329
818
374
Standard deviation
standard-deviation lista-ticks
17
1
11

@#$#@#$#@
## DIFFUSION SIMULATION

This program first creates a social network and then simulates the diffusion of an innovation through the network following a combination of the Bass model and a network contagion model. Agents turn red as they adopt the innovation. New adopters are shown as hollow red circles and incumbent adopters as solid red circles. In a Bass model (unlike an S-I-R model) adoption is permanent. Small green numbers show the number of neighbors having adopted.

## HOW TO USE IT

Press "setup" to create the social network following Barabasi's preferential attachment model. "Wipe" will reset the diffusion process but keep the social network. "Go" and "go-once" simulate the diffusion process.

Adjust the sliders to see how the diffusion reacts to different assumptions. 

The "constant effect" is an effect that applies to all agents and has the same effect at all time periods. Substantively it can be taken to reflect things like advertising or government mandates. It is sometimes referred to as a "mass media effect," "a," or "p." 

The "endogenous effect" is a non-spatial cumulative advantage effect that applies to all agents but is a function of popularity (including among "strangers"). Substantively it can be taken to reflect things like bestseller lists or search algorithms like PageRank. It is sometimes referred to as an "information cascade," "network externalities," "b," or "q." 

The "cohesion effect" is how sensitive an agent is to neighbors. (This is similar to the "endogenous" effect but applies only to neighbors rather than the whole population). It substantively reflects "word of mouth." This effect is sometimes referred to as "network diffusion," "contagion," or "local network externalities."

Note that under some circumstances the "endogenous" and "cohesion" effects behave similarly and both usually produce an "s-curve." In many works (e.g., Bass 1969, Rogers 2003) a model specification that lacks network structure (and thus is similar to the "endogenous effect") is given a substantive interpretation of a "cohesion effect."

## CREDITS AND REFERENCES

This model was written by Gabriel Rossman of the UCLA Depatment of Sociology. Substantial parts of the code are borrowed from Wilensky's "Preferential Attachment" model.

For additional information:

Abrahamson, Eric and Lori Rosenkopf. 1997. �Social Network Effects on the Extent of Innovation Diffusion: A Computer Simulation.� Organization Science 8:289�309.

Bass, Frank M. 1969. �A New Product Growth for Model Consumer Durables.� Management Science 50:1825�1832.

DiMaggio, Paul J. and Filiz Garip. 2010. �Intergroup Inequality as a Product of Diffusion of Practices with Network Externalities under Conditions of Homophily: Applications to the Digital Divide in the U.S. and Rural/Urban Migration in Thailand.� Princeton University Center for the Study of Social Organization Working Paper #2.

Rogers, Everett M. 2003. Diffusion of Innovations. New York: Free Press, 5th edition.
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
0
Rectangle -7500403 true true 151 225 180 285
Rectangle -7500403 true true 47 225 75 285
Rectangle -7500403 true true 15 75 210 225
Circle -7500403 true true 135 75 150
Circle -16777216 true false 165 76 116

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
