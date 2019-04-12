extensions [nw]

; we have two different kind of link breeds, one directed and one undirected, just
; to show what the different networks look like with directed vs. unidirected links

directed-link-breed [ dirlinks dirlink ]
undirected-link-breed [ unlinks unlink ]


; below two link breeds are created for importing real networks from Twitter.

undirected-link-breed [ SocialLinks SocialLink ]
undirected-link-breed [ DiffusionLinks DiffusionLink ]

globals [
  opinion-leaders                      ; AGENTSETS to store nodes who are opinion leaders
  seed-nodes                           ; AGENTSETS to store seed nodes that adopt information at first
  adopter-size-list                    ; For calcuate the mean adoption size
  file                                 ; FILE to store the output experiment
  
  avg-adoption-list                    ; Each position in list is the average adoption size in a sample of 1000
  initial-nb-nodes
]

turtles-own [
  ; attributes of node in real networks (tweets)
  ID
  Name
  Identity
  Tweet_Time
  X_COR
  Y_COR
  
  influence                            ; numeric value to determine how influential the turtle is
  adopt?
  has-spread?                          ; boolean for independent cascade mode
  opinion-leader?
  dis-degree                           ; discount degree
  ks-degree                            ; k-shell degree
  nb-seed-neighbors                    ; number of neighbors of the turtle that are already selected as seeds
]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Clear functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to clear
  clear-all
  set-current-plot "Degree distribution"
  set-default-shape turtles "circle"
  reset-ticks
end

to clear-graph
  ; clear earlly adoters and opinion leaders but keep the underlying graph.
  set seed-nodes nobody
  
  ask turtles [
    set shape "circle"
    set size 1
    set influence 0
    set color grey
    set adopt? false
    set has-spread? false
  ]
end

to reset-graph
  ; used for switching the method in set seed nodes function.
  
  ask turtles [
    set shape "circle"
    set size 1
    set influence 0
    set color grey
    set adopt? false
    set has-spread? false
  ]
  
  if seed-nodes != nobody and seed-nodes != 0 [ask seed-nodes [set adopt? true]]
end

;; Reports the link set corresponding to the value of the links-to-use compbox

to-report get-links-to-use
  report ifelse-value (links-to-use = "directed")
  [ dirlinks ]
  [ unlinks ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Layouts
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to redo-layout [forever?]
  if layout = "radial" and count turtles > 1 [
    layout-radial turtles links (max-one-of turtles [ count my-links + count my-out-links + count my-in-links ])
  ]
  if layout = "spring" [
    let factor sqrt count turtles
    if factor = 0 [ set factor 1 ]
    repeat ifelse-value forever? [1] [50] [
      layout-spring turtles links (1 / factor) (14 / factor) (1.5 / factor)
      display
      if not forever? [wait 0.005]
    ]
  ]
  if layout = "circle" [
    layout-circle sort turtles max-pycor * 0.9
  ]
  if layout = "tutte" [
    layout-circle sort turtles max-pycor * 0.9
    repeat 10 [
      layout-tutte max-n-of (count turtles * 0.5) turtles [ count my-links ] links 12
    ]
  ]
end

to layout-once
  redo-layout false
end

to spring-forever
  set layout "spring"
  redo-layout true
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Network Generators
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to generate [ generator-task ]
  ; we have a general "generate" procedure that basically just takes a task
  ; parameter an run it, but takes care of calling layout and update stuff
  
  set-default-shape turtles "circle"
  run generator-task
  ask turtles [
    set color grey
    set adopt? false
    set has-spread? false
  ]
  layout-once
  update-plots
end

to preferential-attachment
  generate task [ nw:generate-preferential-attachment turtles get-links-to-use nb-nodes ]
end

to ring
  generate task [ nw:generate-ring turtles get-links-to-use nb-nodes ]
end

to star
  generate task [ nw:generate-star turtles get-links-to-use nb-nodes ]
end

to wheel
  ifelse (links-to-use = "directed") [
    ifelse spokes-direction = "inward" [
      generate task [ nw:generate-wheel-inward turtles get-links-to-use nb-nodes ]
    ]
    [; if it's no t inwark, it's outward
      generate task [ nw:generate-wheel-outward turtles get-links-to-use nb-nodes ]
    ]
  ]
  [ ; for an undirected network, we don't care about spokes
    generate task [ nw:generate-wheel turtles get-links-to-use nb-nodes ]
  ]
end

to lattice-2d
  generate task [ nw:generate-lattice-2d turtles get-links-to-use nb-rows nb-cols wrap ]
end

to small-world
  generate task [ nw:generate-small-world turtles get-links-to-use nb-rows nb-cols clustering-exponent wrap ]
end

to generate-random
  generate task [ nw:generate-random turtles get-links-to-use nb-nodes connexion-prob ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Saving and loading of network files
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; save and load GraphML, user could change the name of the to-save graphML
;; and open a GraphML from Windows Explore

to save-graphml
  nw:set-context turtles get-links-to-use
  nw:save-graphml "demo.graphml"
end

to load-graphml
  set-default-shape turtles "circle"
  nw:set-context turtles get-links-to-use
  let graphmlfile user-file
  if is-string? graphmlfile
  [ nw:load-graphml graphmlfile ]
  ask turtles [ set label ""]
  layout-once
  update-plots
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Opinion leaders
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to set-opinion-leaders
  ;;; first clear existing opinion leaders
  ask turtles [ set opinion-leader? false ]
  set opinion-leaders nobody
  ;; sort turtles in order of degree by descending
  foreach sort-by [[count link-neighbors] of ?1 > [count link-neighbors] of ?2] turtles
  [
    ;; if leaders in opinion-leader less than the desired number
    ;; the number of opinion-leaders here are 10% of total population
    ifelse (opinion-leaders = nobody) or (count opinion-leaders < precision (count turtles / 10) 0)
    [
      ask ?
      [
        if [shape] of ? != "target"; if it has not been selected as seed nodes
        [
          set shape "square"
          set opinion-leader? true; square is reserved for opinion leaders in this model
        ]
        set color yellow ;; yellow is also for opinion leaders; red target means it is
        set size 2 ;; both opinion leader and seed nodes
        set opinion-leader? true
      ]
      ;;add current turtle into opinion-eader agentset
      set opinion-leaders (turtle-set ? opinion-leaders)
    ]
    [stop]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Seed nodes / Early adopters
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to set-seed-nodes
  ;; set the seed nodes in the network using the methods chosen from seed-nodes-preference
  ;; draw the seed nodes as red target after the calculation
  reset-graph
  if seed-nodes-preference = "Betweenness" [
    draw-seed-nodes task nw:betweenness-centrality
  ]
  if seed-nodes-preference = "Eigenvector" [
    draw-seed-nodes task nw:eigenvector-centrality
  ]
  if seed-nodes-preference = "Closeness" [
    draw-seed-nodes task nw:closeness-centrality
  ]
  if seed-nodes-preference = "Diffusion simulation" [ ;Greedy algorithm
    ; Start simulation to find seed-nodes
    simulate-seed-nodes
    draw-seed-nodes-simple
  ]
  if seed-nodes-preference = "K-Shell" [
    k-shell
    draw-seed-nodes-simple
  ]
  if seed-nodes-preference = "Degree Discount" [
    degree-discount
    draw-seed-nodes-simple
  ]
  
  ;; Clear "Adoption Experiment" plot and adoption size/influence
  set-current-plot "Adoption Experiment"
  clear-plot
  set adopter-size-list []
end

to draw-seed-nodes [ measure ]
  set seed-nodes nobody
  foreach sort-by [[runresult measure] of ?1 > [runresult measure] of ?2] turtles
  [
    ifelse (seed-nodes = nobody) or (count seed-nodes < nb-seed-nodes)
    [
      ask ? [
        set shape "target"
        set color red
        set size 2
      ]
      set seed-nodes (turtle-set ? seed-nodes)
    ]
    [stop]
  ]
end

to draw-seed-nodes-simple
  ask seed-nodes [
    set shape "target"
    set color red
    set size 2
    set adopt? true
  ]
end

to simulate-seed-nodes
  ;;simulate the diffusion process to find early adopter using greedy algorithm
  let node-counter 0
  ifelse seed-nodes = nobody or seed-nodes = 0
  [print "there is no seed-nodes" set seed-nodes nobody]
  [set node-counter count seed-nodes]
  
  while [ node-counter < nb-seed-nodes ] ; node-counter means number of seed nodes
  [
    ask turtles with [adopt? = false]
    [
      let spread-influence 0
      repeat 300  ; the number of simulations on each seed node
      [
        adopt-cascade  ; run diffusion on current turtle with  seed-nodes
        set spread-influence count turtles with [adopt? = true] + spread-influence
        ask turtles with [adopt? = true][set adopt? false set has-spread? false] ; reset the status of all turtles
        
        if seed-nodes != nobody [ask seed-nodes [set adopt? true]]
      ]
      ; recorded the influence with current turtle
      set influence spread-influence / 200
    ]
    ; find the turtle with max influence and add it in seed-nodes turtle-set
    let seed-node one-of turtles with [influence = max [influence] of turtles]
    set seed-nodes (turtle-set seed-node seed-nodes)
    ask seed-nodes [set adopt? true]
    print seed-nodes
    set node-counter node-counter + 1
  ]
end

to degree-discount ; degree discount heuristics developed by Wei Chen et al.
  ;; (http://dl.acm.org/citation.cfm?id=1557047)
  set seed-nodes no-turtles
  ask turtles [
    set dis-degree count link-neighbors ;initiate the discount degree for all the nodes
    set nb-seed-neighbors count link-neighbors with [member? self seed-nodes]
  ]
  
  let node-counter 0
  while [node-counter < nb-seed-nodes] ; node-counter means number of seed nodes
  [
    ; finding the nodes that has the highest discount degree as the seed  nodes/early adopters
    let u max-one-of turtles with [not member? self seed-nodes][dis-degree]
    set seed-nodes (turtle-set u seed-nodes)
    
    ask u [
      ask link-neighbors with [not member? self seed-nodes]
      [
        set nb-seed-neighbors nb-seed-neighbors + 1
        set dis-degree count link-neighbors - 2 * nb-seed-neighbors - (count link-neighbors - nb-seed-neighbors) * p-adoption * nb-seed-neighbors
      ]
    ]
    set node-counter node-counter + 1
  ]
  print seed-nodes
end

;pagina 134 se comienza con k-shell

to k-shell
  ; k-shell heuristics
  ; because we cannot remove nodes in the network as the original methods suggested, this methods
  ; turned to rank each node using k-shell by multiplying a large number.
  let my-count 1   ; my-count for the rank node using k-shell
  set seed-nodes nobody
  
  ask turtles [
    ; initializing variable
    set ks-degree 0
    set influence 0
  ]
  
  ; calculating the influence of all the nodes in the network using k-shell methods.
  while [any? turtles with [ks-degree = 0]]
  [
    ; if there are any turtles that have ks-degree 0 and the number of their neighbors that have
    ; 0 ks-degree is less than my-count
    
    ; rank them as the #my-count shell of the network
    while [any? turtles with [ks-degree = 0 and (count link-neighbors with [ks-degree = 0]) <= my-count]]
    [
      ask turtles with [ks-degree = 0 and (count link-neighbors with [ks-degree = 0]) <= my-count]
      [
        set ks-degree my-count * 5000 ; 5000 as the multiplier for calculating k-shell influence
        set influence ks-degree + count link-neighbors ; differenciate the nodes that has the same
        ; ks-degree by counting link-neighbors
      ]
    ]
    set my-count my-count + 1
  ]
  set seed-nodes max-n-of nb-seed-nodes turtles [influence]
  print seed-nodes
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Information Diffusion Process
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to adopt-cascade    ; information diffusion. running until no one can be influenced
  
  ;set color red
  
  set adopt? true ;; set current node as innitial  adopters
  
  while [true] ;; it's an infinite loop
  [
    let initial-adopters turtles with [adopt? = true and has-spread? = false]
    
    ifelse any? initial-adopters  ; check if there is any new adopters
    [
      ask initial-adopters  ; ask all new adopters to spread the information
      [
        let potential-adopters link-neighbors with [adopt? = false]
        ;; those who have not adopted the information but are neighbors of adopters
        
        if any? potential-adopters
        [
          ask potential-adopters
          [
            let adopted-fraction 0
            let adopted-neighbors link-neighbors with [adopt? = true]
            let nb-neighbors count link-neighbors
            let nb-adopted-leaders count adopted-neighbors with [opinion-leader? = true]
            set adopted-fraction (count adopted-neighbors) / nb-neighbors
            
            let random-thresh random-float 1.0  ;; use random values as the threshold of adoption
            if random-thresh < (nb-adopted-leaders * p-op-leader + (count adopted-neighbors - nb-adopted-leaders) * p-adoption) / count adopted-neighbors
            ;; p-adoption is the parameter controlled by slider in the interface
            [
              set adopt? true
            ]
          ]
        ]
        
        set has-spread? true
        
      ]
    ]
    [stop] ;; else (not more new adopters) stop!!
  ]
end

to spread-information ; only diffuse information once
  ask seed-nodes [
    adopt-cascade
    let adopters turtles with [adopt? = true]
    ask adopters
    [
      set color red
    ]
  ]
end

to reset-diffuse  ; reset the diffusion to the starting status.
  ask turtles with [color = red]
  [
    set color grey
    set adopt? false
    set has-spread? false
  ]
  draw-seed-nodes-simple
end

to experiment
  ;; an experiment for testing the performance of the methods of choosing early adopters.
  ;; it runs 1000 times simulation on each node until the number of seed nodes reaches 20.
  
  set-opinion-leaders
  
  while [nb-seed-nodes <= 20] [
    set-seed-nodes
    let exp-count 0
    
    while [exp-count < 1000] [
      spread-information
      update-plots
      set adopter-size-list lput count turtles with [adopt? = true] adopter-size-list
      print count turtles with [adopt? = true]
      if file != 0 [write-to-file file] ;; write the results into a csv file
      
      reset-diffuse
      set exp-count exp-count + 1
    ]
    set nb-seed-nodes nb-seed-nodes + 1
  ]
end

to find-parameters
  ;; THIS FUNCTION IS TO FIND OPTIMAL PARAMETERS BY GRID SEARCHING.
  ;;;;;;;;;;;;;;;;;;EXPLANATION OF VARIABLES;;;;;;;;;;;;;;;;;;;;;;;
  ;; probability of adopting from opinion leaders p-op
  ;; probability of adopting from normal people   p-nm
  ;; first run: p-op & p-nm range from 0.1 - 0.4 where p-op > p-nm, increasement 0.1
  ;; p-op p-nm avg.adoption
  set seed-nodes nobody
  set adopter-size-list []
  let seed-list ["A" "B" "C"] ; set the early adopters mannually based on the real network data.
  
  ;; set up the result of experiment file
  let p-file "parameter_experiment.csv"
  
  if (file-exists? (p-file)) [carefully [file-delete (p-file)] [print error-message]]
  file-open(p-file)
  file-type "p-op,"
  file-type "p-nm,"
  file-type "avg_adoption"
  file-close
  
  ; set opinion leaders and set-seed-nodes
  
  set p-op-leader 0.01
  set-opinion-leaders
  
  ask turtles with [member? name seed-list][set seed-nodes (turtle-set self seed-nodes)]
  
  if seed-nodes = nobody [
    user-message ("Please import real network and set seed-list before running this function!")
    stop
  ]
  draw-seed-nodes-simple
  
  ;; grid search to ranverse all the possible parameters
  
  while [p-op-leader <= 0.03] [
    while [p-adoption < p-op-leader] [
      let exp-count 0
      while [exp-count < 10] [
        spread-information
        update-plots
        set adopter-size-list lput count turtles with [adopt? = true] adopter-size-list
        reset-diffuse
        set exp-count exp-count + 1
      ]
      ;; write result to the file
      file-open (p-file)
      file-print " "
      file-type p-op-leader
      file-type ","
      file-type p-adoption
      file-type ","
      file-type mean adopter-size-list
      file-type ","
      file-close
      
      print mean adopter-size-list
      set adopter-size-list []
      set p-adoption p-adoption + increment
    ]
    set p-adoption 0.0  ;; another round of search
    set p-op-leader p-op-leader + increment
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Dealing with files
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to set-up-file  ;; run it before hitting experiment button
  ; it initialize the output file for results of experiment.
  
  set file user-new-file
  
  if (file-exists? (word file ".csv")) [carefully [file-delete (word file ".csv")] [print error-message]]
  
  file-open (word file ".csv")
  
  file-type "seed-nodes-preference,"
  file-type "population,"
  file-type "seed nodes size,"
  file-type "number of opinion leaders,"
  file-type "adoption probability,"
  file-type "adoption probability from opinion leaders"
  file-type "adoption size"
  
  file-close
  
end

to write-to-file [my-file]
  file-open (word my-file ".csv")
  file-print " "
  file-type seed-nodes-preference
  file-type ","
  file-type count turtles
  file-type ","
  file-type count seed-nodes
  file-type ","
  file-type count turtles with [opinion-leader? = true]
  file-type ","
  file-type p-adoption
  file-type ","
  file-type p-op-leader
  file-type ","
  file-type count turtles with [adopt? = true]
  file-type ","
  file-close
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Reporters for monitors
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to-report mean-path-length
  report nw:mean-path-length
end


;;;;;;;;;;;;;;;;;;my-experiment;;;;;;;;;;;;;;;;;;;;;;;;;;;;,,,,

to my-experiment
  ;; an experiment for testing the performance of the methods of choosing early adopters.
  ;; it runs 1000 times simulation on each node until the number of seed nodes reaches 20.
  
  set avg-adoption-list (list)
  set initial-nb-nodes nb-seed-nodes
  
  set-opinion-leaders
  
  while [nb-seed-nodes <= 20] [
    set-seed-nodes
    let exp-count 0
    
    set adopter-size-list (list)
    ;; running num-samples times the diffusion for each seed-nodes config
    while [exp-count < num-samples] [ ;; num-samples 25
      spread-information
      ;update-plots
      set adopter-size-list lput count turtles with [adopt? = true] adopter-size-list
      ;print count turtles with [adopt? = true]
      ;if file != 0 [write-to-file file] ;; write the results into a csv file
      print (word "nb-seed-nodes: [" nb-seed-nodes "] - exp-count: [" exp-count "]")
      reset-diffuse
      set exp-count exp-count + 1
    ]
    
    set avg-adoption-list lput (mean adopter-size-list) avg-adoption-list
    update-plots
    set nb-seed-nodes nb-seed-nodes + 1
  ]
end


  
@#$#@#$#@
GRAPHICS-WINDOW
210
10
857
470
24
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
-24
24
-16
16
0
0
1
ticks
30.0

CHOOSER
9
4
147
49
links-to-use
links-to-use
"undirected" "directed"
0

CHOOSER
9
135
147
180
layout
layout
"radial" "spring" "circle" "tutte"
1

TEXTBOX
879
17
1029
35
Generators
11
0.0
1

BUTTON
865
37
928
70
ring
ring
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
865
73
927
106
star
star
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
865
113
928
161
wheel
wheel
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
865
167
928
204
random
generate-random
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
930
37
1071
70
nb-nodes
nb-nodes
0
500
100
1
1
NIL
HORIZONTAL

SLIDER
1075
36
1181
69
nb-cols
nb-cols
0
100
5
1
1
NIL
HORIZONTAL

SLIDER
1186
36
1295
69
nb-rows
nb-rows
0
100
5
1
1
NIL
HORIZONTAL

CHOOSER
932
115
1070
160
spokes-direction
spokes-direction
"inward"
0

BUTTON
930
76
1072
109
preferential attachment
preferential-attachment
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
1078
77
1294
110
wrap
wrap
0
1
-1000

SLIDER
1075
171
1291
204
clustering-exponent
clustering-exponent
0.0
1.0
0.06
0.01
1
NIL
HORIZONTAL

SLIDER
933
171
1072
204
connexion-prob
connexion-prob
0.01
1.0
0.13
0.01
1
NIL
HORIZONTAL

BUTTON
1074
116
1179
160
small world
small-world
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
1183
117
1293
159
lattice 2D
lattice-2d
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
868
208
1018
226
Diffusion
11
0.0
1

CHOOSER
866
224
1110
269
seed-nodes-preference
seed-nodes-preference
"Betweenness" "Eigenvector" "Closeness" "Diffusion simulation" "K-Shell" "Degree Discount"
5

SLIDER
1116
223
1288
256
nb-seed-nodes
nb-seed-nodes
0
30
21
1
1
NIL
HORIZONTAL

SLIDER
1115
293
1287
326
p-adoption
p-adoption
0.0
1.0
0.1
0.1
1
NIL
HORIZONTAL

SLIDER
1116
259
1288
292
p-op-leader
p-op-leader
0.0
1.0
0.2
0.1
1
NIL
HORIZONTAL

BUTTON
867
277
983
310
set seed nodes
set-seed-nodes
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
987
277
1111
310
set opinion leaders
set-opinion-leaders
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
867
314
983
347
spread information
spread-information
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
988
314
1111
347
reset diffuse
reset-diffuse
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
868
353
1018
371
Early Adopters Experiment
11
0.0
1

BUTTON
870
372
956
405
set up file
set-up-file
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
965
374
1059
407
experiment
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

TEXTBOX
867
411
1017
429
Real Network Function
11
0.0
1

CHOOSER
868
429
1006
474
increment
increment
0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1
0

BUTTON
1008
429
1111
462
NIL
find-parameters
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
80
59
174
92
clear graph
clear-graph
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
12
59
75
92
clear
clear
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
11
98
77
131
layout
redo-layout true
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
81
99
146
132
spring
spring-forever
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
10
188
160
206
Files
11
0.0
1

BUTTON
9
206
115
239
load GraphML
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

BUTTON
11
247
121
280
save GraphML
save-graphml
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
6
382
206
532
Degree distribution
Degrees
No nodes
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" "let max-degree max [count link-neighbors] of turtles\nplot-pen-reset ;; erase what we plotted before \nset-plot-x-range 1 (max-degree + 1)\nhistogram [count link-neighbors] of turtles"

PLOT
1114
330
1314
480
Adoption Experiment
Round
Adoption Size
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" ";foreach adopter-size-list plot\n;let max-x length avg-adoption-list\n;plot-pen-reset ;; erase what we plotted before \n;set-plot-x-range initial-nb-nodes (initial-nb-nodes + max-x)\n;foreach avg-adoption-list plot\nset-plot-x-range 13 20\nplot 32\nplot 15\nplot 45\nplot 9\nplot 58\nplot 23"

MONITOR
12
285
83
330
NIL
count links
17
1
11

MONITOR
87
285
170
330
NIL
count turtles
17
1
11

MONITOR
12
332
167
377
NIL
mean-path-length
17
1
11

BUTTON
323
490
437
523
NIL
my-experiment
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

INPUTBOX
225
471
300
531
num-samples
5
1
0
Number

MONITOR
455
482
1314
527
NIL
avg-adoption-list
17
1
11

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

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
