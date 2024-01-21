#lang forge

option run_sterling off


option verbose 0
option problem_type temporal

abstract sig CitySize {}
sig Village, Town, Metropolis extends CitySize {}

sig City {
  -- Roads get built, fall into disrepair, etc.
  var roads: set City,
  -- Cities always remain within the same polity (in this model!)
  polity: set City,
  size: one CitySize
}

pred polityIsEquivRel {
  iden & (City->City) in polity
  polity = ~polity
  all c1, c2, c3 : City | c1->c2 in polity and c2->c3 in polity implies c1->c3 in polity
}

pred init { no roads }

pred doNothing[c: City] {
  c.roads' = c.roads 
}

pred buildARoad[c: City] {
  some c2 : City-(c.roads + c.polity) | 
    c.roads' = c.roads + c2
}

pred traces {
  init
  --always all c: City | doNothing[c] or buildARoad[c]
  always { all c: City | doNothing[c] or buildARoad[c] }
}

--run {polityIsEquivRel} for exactly 5 City

pred roadsOnlyCrossPolities {
  traces
  always {
      --no disj c1, c2: City | c1->c2 in roads and c1->c2 in polity
      no c1, c2: City | {
        c1 != c2
        c1->c2 in roads and c1->c2 in polity
      }
  }
}

/*
foo: run {
  not {
    roadsOnlyCrossPolities
  }
} for exactly 5 City
*/
