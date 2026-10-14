function order = seededPermutation(n, seed)
%SEEDEDPERMUTATION Reproducible random permutation of 1:n.
%   order = seededPermutation(n, seed) always returns the same order for the
%   same (n, seed). The global random-number state is restored afterwards,
%   so calling this function has no side effects on other random draws.

previous = rng();
restore = onCleanup(@() rng(previous));
rng(seed, 'twister');
order = randperm(n);
order = order(:);
end
