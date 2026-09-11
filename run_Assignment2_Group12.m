% Assignment 2
%
% Group 12, AY2025-2026
% 
% Cerrone Simone [303432]
% Tacconi Filippo [314998]
% Tomasini Vittoria [304183]
% 

clear all;
close all;
clc;

%% Settings

formatData  = 'dd/mm/yyyy';

%% Read market data
% Read deposit, futures and swap quotes from the Excel file

[datesSet, ratesSet] = readExcelData('MktData_CurveBootstrap.xls', formatData);

%% 1. Bootstrap
% Build the EUR discount curve from deposits, STIR futures and swaps
% Output: dates (datenum), discounts B(t0,T), zero rates z(T)

[dates, discounts, zeroRates] = bootstrap(datesSet, ratesSet);

%% 3. Asset swap
% Compute the Asset Swap Spread over Euribor 3M for issuer YY's bond

% Bond parameters
Cp0        = 101.5;          % clean price (% of face value)
c          = 0.046;          % annual coupon rate (4.6%)
face_value = 100;

% Key dates
iss_date = datenum('31/03/2007', formatData);   % issue date
t0       = datesSet.settlement;                 % settlement = 15 Feb 2008
mat_date = datenum('31/03/2012', formatData);   % maturity date

[A, Dp0, PV_bond,ASW_spread, yf_all, zr_all] = ASW_spread_funct(iss_date, t0, mat_date, Cp0, c, face_value, datesSet, dates, discounts);

fprintf('Accrued interest:  %.6f\n', A);
fprintf('Dirty price:       %.6f\n', Dp0);
fprintf('PV bond (risk-free): %.6f\n', PV_bond);
fprintf('\nASW spread = %.4f bps\n', ASW_spread *  1e4);


%% 4. CDS bootstrap
% Bootstrap survival probabilities and piecewise constant intensities
% for obligor ISP from CDS spreads

recovery=0.4;
spreadCDS=[29; 34; 37; 39; 40; 40];   % CDS spreads in bps
years = [1:5,7]';                       % available maturities (missing 6y)

% Compute CDS maturity dates from settlement
settlement_dt = datetime(datesSet.settlement, 'ConvertFrom', 'datenum');
datesCDS_dt = settlement_dt + calyears(years);

% Interpolate the missing 6y spread via cubic spline
interp_dt = settlement_dt + calyears(6);
datesCDS = datenum(datesCDS_dt);
interp_date = datenum(interp_dt);
interp_spread = interp1(datesCDS, spreadCDS, interp_date, 'spline');

% Build the complete set of CDS dates and spreads (1y to 7y)
datesCDS=[datesCDS;interp_date];
spreadsCDS=[spreadCDS;interp_spread]./10000;   % convert bps to decimal

% Sort by date to ensure correct ordering (6y inserted between 5y and 7y)
[datesCDS_new, sort_idx] = sort(datesCDS);
spreadCDS_new = spreadsCDS(sort_idx);

% Prepare the discount factor curve for CDS bootstrap:
% bootstrapCDS2 expects settlement as the first date with B(t0,t0)=1
datesDF_full = [datesSet.settlement; dates];
discounts_full = [1; discounts];

% Approximated method (neglects accrual term in the protection leg)
[datesCDS_approx, survProbs_approx, intensities_approx] = bootstrapCDS(datesDF_full, discounts_full, datesCDS_new, spreadCDS_new, 1, recovery)

% Exact method (accounts for accrual assuming default at midpoint of interval)
[datesCDS_exact, survProbs_exact, intensities_exact] = bootstrapCDS(datesDF_full, discounts_full, datesCDS_new, spreadCDS_new, 2, recovery)

% Jarrow-Turnbull approximation (constant intensity = spread / (1 - recovery))
[datesCDS_JT, survProbs_JT, intensities_JT] = bootstrapCDS(datesDF_full, discounts_full, datesCDS_new, spreadCDS_new, 3, recovery)

% Verify that the accrual term is negligible
max_diff = max(abs(intensities_exact-intensities_approx))

%% 5. Credit simulation
% Simulate default times from a piecewise constant hazard rate model

M = 1e5;                    % number of Monte Carlo simulations
lambda1 = 4 / 10000;        % hazard rate for t <= theta (4 bps)
lambda2 = 10 / 10000;       % hazard rate for t > theta  (10 bps)
theta = 5;                  % threshold year
T = 30;                     % time horizon

[tau] = default_times(M, lambda1, lambda2, theta, T);

%% Fitting lambdas
% Estimate lambda1 and lambda2 via MLE and compute 95% confidence intervals

alpha = 0.05;                              % significance level

[lambda1_estimator, lambda2_estimator, CI1, CI2] = lambda_estimation(alpha, tau, theta, T);

fprintf('Lambda 1 exact: 4 bps | Estimated: %.2f bps | CI 95%%: [%.2f, %.2f]\n', lambda1_estimator*10000, CI1(1)*10000, CI1(2)*10000);
fprintf('Lambda 2 exact: 10 bps | Estimated: %.2f bps | CI 95%%: [%.2f, %.2f]\n', lambda2_estimator*10000, CI2(1)*10000, CI2(2)*10000);



%% Plotting experimental survival probability vs fitted one
% Log-linear plot comparing empirical, MLE-fitted, and exact survival curves

plot_surv_prob(tau, theta, lambda1_estimator, lambda2_estimator, lambda1, lambda2, M);

%% 6. NPV of Monthly Cash Flows with AAGR
% Compute NPV of monthly payments on the 19th of each month for 20 years,
% with 5% AAGR applied every year in March

AAGR = 0.05;           % Average Annual Growth Rate
CF_a = 1500;            % initial monthly cash flow, case a)
CF_b = 6000;            % initial monthly cash flow, case b)

% Extract settlement date components for date arithmetic
dv = datevec(datesSet.settlement);

[NPV_a, NPV_b] = NPV(dv, AAGR, CF_a, CF_b, yf_all, zr_all, datesSet);

fprintf('NPV (Case A - 1.5K initial): %.2f EUR\n', NPV_a);
fprintf('NPV (Case B - 6.0K initial): %.2f EUR\n', NPV_b);