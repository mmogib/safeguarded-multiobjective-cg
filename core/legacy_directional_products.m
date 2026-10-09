function products = legacy_directional_products(J, direction)
%LEGACY_DIRECTIONAL_PRODUCTS Reproduce objective-wise legacy dot products.

products = zeros(size(J,1), 1);
for objective = 1:size(J,1)
    products(objective) = J(objective,:)*direction;
end
end
