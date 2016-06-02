name "barbican-server"
description "Barbican Role"
run_list(
  "recipe[barbican::api]",
  "recipe[barbican::common]",
  "recipe[barbican::keysotne-listener]"
  "recipe[barbican::worker]",
  "recipe[barbican::retry]",
)
default_attributes
override_attributes
