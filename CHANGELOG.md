0.0.4
=====

* BUG: Methods defined using the 'operation' DSL could not access other methods in the class.

0.0.3
=====

* Added a DSL for declaring operations.

0.0.2
=====

* Added alias to #fold, named the same as the class in underscore form. ie. for CertStatus, value.fold <=> value.cert_status
* Added special methods for enumerations (defined as ADTs with only nullary constructors): #all_values, #to_i/::from_i
* Added caching of the values for nullary constructors, ie. Maybe.nothing.object_id == Maybe.nothing.object_id
* Added #to_a: simplifies #==
* Added #<=>
* Added case information methods: #case_name, #case_index (1-based), #case_arity
* BUG: Constructors were being defined on every class that extended ADT.

