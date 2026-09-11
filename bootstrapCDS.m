function [datesCDS, survProbs, intensities] = bootstrapCDS(datesDF, discounts, datesCDS, spreadsCDS, flag, recovery)
% Bootstrap survival probabilities and default intensities
% from CDS spreads using three different methods.
%
% Inputs:
%   datesDF    - vector of discount factor dates (first element = settlement)
%   discounts  - vector of discount factors (first element = 1)
%   datesCDS   - vector of CDS maturity dates
%   spreadsCDS - vector of CDS spreads (in decimal, not bps)
%   flag       - method: 1 = approximated, 2 = exact, 3 = Jarrow-Turnbull
%   recovery   - recovery rate (e.g. 0.4)
%
% Outputs:
%   datesCDS    - same as input (CDS maturity dates)
%   survProbs   - bootstrapped survival probabilities at each CDS date
%   intensities - piecewise constant default intensities

%% Initialization

N = length(spreadsCDS);
survProbs = zeros(N, 1);
intensities = zeros(N, 1);
settlement = datesDF(1);

% Year fractions from settlement (ACT/365)
t_DF  = yearfrac(settlement, datesDF, 3);
t_CDS = yearfrac(settlement, datesCDS, 3);

% Continuously compounded zero rates from discount factors
zero_rates = zeros(size(discounts));
zero_rates(2:end) = -log(discounts(2:end)) ./ t_DF(2:end);
zero_rates(1) = zero_rates(2); % flat extrapolation at t=0

% Interpolate zero rates at CDS dates and compute corresponding discount factors
zero_rates_CDS = interp1(t_DF, zero_rates, t_CDS, 'linear');
DF_CDS = exp(-zero_rates_CDS .* t_CDS);

% Year fractions between consecutive CDS payment dates (ACT/365)
date_all = [settlement; datesCDS]; 
delta_t = yearfrac(date_all(1:end-1), date_all(2:end), 3);

%% Recursive bootstrap algorithm

for i = 1:N
    % --- Jarrow-Turnbull: closed-form, non-recursive ---
    if flag == 3
        % Intensity = spread / (1 - recovery), constant for each maturity
        intensities(i) = spreadsCDS(i) / (1 - recovery);
        % Survival probability from constant intensity over the full period
        survProbs(i)   = exp(-intensities(i) * yearfrac(settlement, datesCDS(i), 3));
        continue;
    end
    
    % --- Approximated and Exact methods ---
    % First iteration (i=1): no previous pillars, direct formula
    if i == 1
        
        % Approximated: neglects accrual term in protection leg
        if flag == 1
            survProbs(i) = (1 - recovery) / (spreadsCDS(i) * delta_t(i) + 1 - recovery);
        % Exact: assumes default at midpoint of interval (accrual = spread * delta/2)
        elseif flag == 2
            survProbs(i) = (1 - recovery - spreadsCDS(i) * delta_t(i)/2) / (spreadsCDS(i) * delta_t(i)/2 + 1 - recovery);
        end
        % Extract piecewise constant intensity from survival probability
        intensities(i) = -log(survProbs(i)) / delta_t(i);
    
    % Recursive steps (i > 1): use previously bootstrapped survival probs
    else
        
        % Premium leg: sum of discounted survival-weighted year fractions
        sum_PL = sum( delta_t(1:i-1) .* DF_CDS(1:i-1) .* survProbs(1:i-1) );
        Q_prev = [1; survProbs(1:i-2)];  % survival probs at previous nodes
        
        % Loss given default terms depend on the method
        if flag == 1
            % Approximated: protection leg uses (1-R) only
            Loss_term = (1 - recovery) * ones(i-1, 1);
            Loss_n    = (1 - recovery);
        elseif flag == 2
            % Exact: protection leg subtracts accrual correction
            Loss_term = (1 - recovery) - spreadsCDS(i) * (delta_t(1:i-1) / 2);
            Loss_n    = (1 - recovery) - spreadsCDS(i) * (delta_t(i) / 2);
        end
        
        % Protection leg: sum over previous intervals
        sum_ProtL = sum( Loss_term .* DF_CDS(1:i-1) .* (Q_prev - survProbs(1:i-1)) );
        
        % Numerator: equate premium and protection legs, solve for Q(t_i)
        num = sum_ProtL + Loss_n * DF_CDS(i) * survProbs(i-1) - spreadsCDS(i) * sum_PL;
        
        % Denominator depends on the method
        if flag == 1
            den = DF_CDS(i) * (spreadsCDS(i) * delta_t(i) + 1 - recovery);
        elseif flag == 2
            den = DF_CDS(i) * (spreadsCDS(i) * delta_t(i)/2 + 1 - recovery);
        end
        
        % Survival probability at current CDS maturity
        survProbs(i) = num / den;
        % Piecewise constant intensity in [t_{i-1}, t_i]
        intensities(i) = -log(survProbs(i) / survProbs(i-1)) / delta_t(i);
    end
end
