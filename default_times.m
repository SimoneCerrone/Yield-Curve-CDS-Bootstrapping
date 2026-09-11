function [tau] = default_times(M, lambda1, lambda2, theta, T)

% Inverse transform sampling: U = P(0,tau) ~ Uniform(0,1)
rng(1);                      % fix seed for reproducibility
U = rand(M, 1);

% Initialize default times
tau = zeros(M, 1);

% Separate cases: default before theta vs after theta
idx_1 = (U >= exp(- lambda1 * theta));   % default in [0, theta]
idx_2 = (U < exp(- lambda1 * theta));    % default in (theta, +inf)

% Invert survival function analytically in each regime
tau(idx_1) = -log( U(idx_1) ) / lambda1;
tau(idx_2) = theta - (log( U(idx_2) ) + lambda1 * theta) / lambda2;

% Cap default time at T = 30 years (no default observed beyond horizon)
tau(tau > T) = T;

end