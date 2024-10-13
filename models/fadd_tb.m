N = 10000;
rng(0)
a = uint32(randi([0 2^31-1], N, 1));
b = uint32(randi([0 2^31-1], N, 1));
a = typecast(a,'single');
b = typecast(b,'single');
y = a + b;
z = floating_point_add(a,b);
c = cellfun(@(a,b)isEqual(a,b),num2cell(y),num2cell(z));
all(c)

function y = isEqual(a,b)
    if isnan(a)
        y = isnan(b);
    elseif isinf(a) 
        y = isinf(b) && (sign(a) == sign(b));
    else
        y = (a == b);
    end
end
