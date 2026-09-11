function [lambda1_estimator, lambda2_estimator, CI1, CI2] = lambda_estimation(alpha, tau, theta, T)

z = norminv(1 - alpha/2, 0, 1);           % z-quantile for bilateral CI

% Lambda1: defaults observed in [0, theta]
N1 = sum(tau <= theta);                    % number of defaults before theta
T1 = sum(min(tau, theta));                 % total exposure time in [0, theta]

% MLE: lambda_hat = N / T_risk
lambda1_estimator = N1 / T1;

% 95% CI using asymptotic normality of MLE
CI1_margin  = z * (lambda1_estimator / sqrt(N1));
CI1 = [lambda1_estimator - CI1_margin, lambda1_estimator + CI1_margin];

% Lambda2: defaults observed in (theta, T)
N2 = sum(tau > theta & tau < T);           % number of defaults after theta
tau_over_theta = tau(tau > theta);          % paths surviving past theta
T2 = sum(min(tau_over_theta - theta, T - theta));  % exposure time in (theta, T]

% MLE for lambda2
lambda2_estimator = N2 / T2;

% 95% CI for lambda2
CI2_margin  = z * (lambda2_estimator / sqrt(N2));
CI2 = [lambda2_estimator - CI2_margin, lambda2_estimator + CI2_margin];

end