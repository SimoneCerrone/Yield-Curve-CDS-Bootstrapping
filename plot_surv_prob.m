function plot_surv_prob(tau, theta, lambda1_estimator, lambda2_estimator, lambda1, lambda2, M)
% Plot survival probability on a semi-logarithmic scale, comparing:
%   - Experimental (empirical from Monte Carlo simulation)
%   - Fitted (using MLE-estimated lambda1, lambda2)
%   - Exact (using true lambda1, lambda2)
%
% Inputs:
%   tau               - simulated default times (Mx1 vector)
%   theta             - threshold year separating the two intensity regimes
%   lambda1_estimator - MLE estimate of lambda1
%   lambda2_estimator - MLE estimate of lambda2
%   lambda1           - true value of lambda1
%   lambda2           - true value of lambda2
%   M                 - number of Monte Carlo simulations

t_grid = linspace(0, 30, 100);

% Experimental survival probability: fraction of paths surviving beyond each t
surv_exp = zeros(length(t_grid), 1);
for i = 1:length(t_grid)
    surv_exp(i) = sum(tau > t_grid(i)) / M;
end

% Fitted survival probability using MLE-estimated intensities
surv_fit = zeros(length(t_grid), 1);
for i = 1:length(t_grid)
    t = t_grid(i);
    if t <= theta
        % Before theta: constant intensity lambda1_hat
        surv_fit(i) = exp(-lambda1_estimator * t);
    else
        % After theta: intensity switches to lambda2_hat
        surv_fit(i) = exp(-lambda1_estimator * theta - lambda2_estimator * (t - theta));
    end
end

% Exact (theoretical) survival probability using true parameter values
surv_exact = zeros(length(t_grid), 1);
for i = 1:length(t_grid)
    t = t_grid(i);
    if t <= theta
        surv_exact(i) = exp(-lambda1 * t);
    else
        surv_exact(i) = exp(-lambda1 * theta - lambda2 * (t - theta));
    end
end

% Semi-logarithmic plot
figure;
semilogy(t_grid, surv_exp, 'o', 'MarkerSize', 3, 'DisplayName', 'Experimental (10^5 sim)');
hold on;
semilogy(t_grid, surv_fit, 'r-', 'LineWidth', 2, 'DisplayName', 'Fitted (MLE)');
hold on;
semilogy(t_grid, surv_exact, 'black-', 'LineWidth', 0.5, 'DisplayName', 'Exact');
grid on;
xlabel('Time (years)');
ylabel('Survival Probability (Log Scale)');
title('Survival Probability');
legend('Location', 'southwest');

end
