Dimrod
======

Dimrod is a library adding static dimensional checking to Nimrod programs.

The goal is to ensure at compile time that the measurement units are coherent in the program.

A statement such as

```nimrod
var
  distance: float = 2.0   # [m]
  delta_time: float = 3.2 # [s]
  acceleration: float     # [m/s/s]
acceleration = distance / delta_time
```
will compile but give an erronous result since [m]/[s] can't give [m/s/s].

```nimrod
import dimrod
var
  distance: Tm = 2.0
  delta_time: Ts = 3.2
  acceleration: Tm_sv2
acceleration = distance / delta_time
```
won't compile.

IMPORTANT: This is my fist project with Nimrod, my approach might be completly wrong.

Principle
---------
dimrod.nim contains procedures to create a librairy taylored to the needs of
the application (lib_example.nim in the example).
The created librairy contains the configuration and is called by the applicative code.

All possible combinations of types are created. The four basic operations are also defined.

Since underscore is not a significant character in identifiant, it can't be used to indicate negative. The letter 'v' is used by default Tmv2 correspond to the invert of square meters. 'v' has been chosen as it points to the bottom. 

Configuration
-------------
config_units defines the basics units that are supposed to be orthogonal.
"config_unit : TBasicUnitsConf = (@["m", "kg"],@[(-1,2), (-1,1)])" would define units 1/m, m, m², 1/kg, kg, kg.m, kg.m², m/kg, kg/m, m²/kg, kg/m² plus a "no unit" unit.  

uname_config defines miscellaneous parameters about unit names.
with "uname_config = ("T", "v", "nodim")" 
- Prefix "T" is placed before units names,
- "v" is placed before negative exponents (as a arrow pointing to bottom)
- "nodim" is the name of the scalar unit.

alias_config defines alias for derived units
"alias_config : TAliasConf= (@["N"], @[@[1,1,-2]])" would define unit N as the same that kg.m/s². 

Problems
--------
* Compiling is slow. Not that much of a problem when library is not modified (due to cache)
* Only handle floats. Not a big problem since use case for physical unit is mostly with continuous values

TODO
----
* Improve variable names
* Use "borrow" pragma (does not seem to work with last versions of Nimrod).
* Add some checks on uname_config.
* Change configuration to seq of tuples
* Cut code into smaller chunks (+ factoring for + - and * /)
* Use arrays instead of sequences ?

