function methods = seven_arm_047_methods()
%SEVEN_ARM_047_METHODS Frozen reporting order and display-name boundary.

display_name = ["SVPRP+";"SVHS+";"SVLS+";"VPRP+"; ...
    "VHS+";"VLS+";"VSD"];
code_id = ["TTCGP";"TTCGH";"TTCGL";"PRP+";"HS+";"LS+";"MOSD"];
store = [repmat("base",4,1);repmat("extension",2,1);"base"];
order = (1:numel(display_name))';
methods = table(order,display_name,code_id,store);
end
