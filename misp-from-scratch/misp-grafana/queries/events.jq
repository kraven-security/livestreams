def events:
  (if type == "array" then .
   elif (.response | type) == "array" then .response
   else error("Expected MISP event array or response array") end)
  | .[] | (.Event // .);
def truth: . == true or . == 1 or . == "1";
def attrs: ((.Attribute // []) + [.Object[]?.Attribute[]?])
  | unique_by(.uuid // .id // ([.type, .value] | join("|"))) | .[];
[events] | {events: length}
