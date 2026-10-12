def events:
  (if type == "array" then .
   elif (.response | type) == "array" then .response
   else error("Expected MISP event array or response array") end)
  | .[] | (.Event // .);
def truth: . == true or . == 1 or . == "1";
def attrs: ((.Attribute // []) + [.Object[]?.Attribute[]?])
  | unique_by(.uuid // .id // ([.type, .value] | join("|"))) | .[];
[events | attrs | {label: (if (.to_ids | truth) then "to_ids true" else "Context only" end)}] | group_by(.label) | .[] | {label: .[0].label, count: length}
