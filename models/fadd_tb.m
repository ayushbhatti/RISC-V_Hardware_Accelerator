% Number of random samples to generate
N = 10000;

% Random number generator seed
rng(0)

% Create random values. Use uniform distribution and uint32's to evenly
% distributes samples accross different exponents.
a = uint32(randi([0 2^32-1], N, 1));
b = uint32(randi([0 2^32-1], N, 1));
a = typecast(a,'single');
b = typecast(b,'single');

% Reference addition
y = a + b;

% Proposed implementation (calls C mex function)
z = floating_point_add(a,b);

% Compare reference model and proposed implementation
c = cellfun(@(a,b)isEqual(a,b),num2cell(y),num2cell(z));

% Determine if both are equal for all random samples
all(c)

% Compare two floating point values
function y = isEqual(a,b)

    % NaN. Match if both are NaN.
    if isnan(a)
        y = isnan(b);

    % Infinity. Match if both are Infinity and share the same sign
    elseif isinf(a) 
        y = isinf(b) && (sign(a) == sign(b));

    % Standard case
    else
        y = (a == b);
    end
end
