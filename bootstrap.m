function [dates, discounts, zeroRates] = bootstrap(datesSet, ratesSet)

% mid market rates
mid_dep   = mean(ratesSet.depos,   2);
mid_fut   = mean(ratesSet.futures, 2);
mid_swaps = mean(ratesSet.swaps,   2);

% yearfracs
yf_dep = yearfrac(datesSet.settlement,datesSet.depos,2);
yf_fut = yearfrac(datesSet.futures(:,1),datesSet.futures(:,2),2);
% dates and discounts
dates     = [];
discounts = [];
fut_mark  = datesSet.futures(1,2);   % expiry date of the first future

% dates and discounts of deposits
for i = 1:length(datesSet.depos)
    if datesSet.depos(i) < fut_mark
        dates     = [dates;     datesSet.depos(i)];
        depo_disc = 1 / (1 + yf_dep(i)*mid_dep(i));
        discounts = [discounts; depo_disc];
    end
end

% dates and discounts of deposits
yf_act365  = yearfrac(datesSet.settlement,dates,3);
zero_rates = -log(discounts) ./ yf_act365;

% dates and discounts futures
% B(t0, t_{i+1}) = B(t0, t_i) * 1/(1 + delta*L_i)
% B(t0, t_i) via interpolation on deposit zero rates

for i = 1 : (size(datesSet.futures,1) - 2)

    % t_i = settle (col 2), t_{i+1} = expiry (col 3)
    t_i  = yearfrac(datesSet.settlement,datesSet.futures(i,1),3);
    % B(t0, t_i) via zero rate interpolation
    zr_i  = interp1(yf_act365, zero_rates, t_i, 'linear', 'extrap');
    B_ti  = exp(-zr_i * t_i);

    % forward discount from futures rate
    B_fwd  = 1 / (1 + yf_fut(i) * mid_fut(i));

    % discount B(t0, t_{i+1})
    futs_disc = B_ti * B_fwd;

    dates     = [dates;     datesSet.futures(i,2)];
    discounts = [discounts; futs_disc];

    % update zero rates with new pillar
    yf_act365  = yearfrac(datesSet.settlement,dates,3);
    zero_rates = -log(discounts) ./ yf_act365;
end

% dates and discounts of swaps 
% B(t0,ti) = (1 - S*sum_{n=1}^{i-1} delta_n*B(0,tn)) / (1 + delta_last*S)
% delta: 30/360 European, B(0,t1) from interpolation

swaps_disc_vect = [];

for i = 2 :length(datesSet.swaps)

    % annual coupon dates
    nYears      = round((datesSet.swaps(i) - datesSet.settlement) / 365);
    couponDates = zeros(nYears, 1);
    for k = 1 : nYears

        dv    = datevec(datesSet.settlement);
        dv(1) = dv(1) + k;
        couponDates(k) = datenum(dv);

    end

    couponDates(end) = datesSet.swaps(i);

    % delta 30/360 for each coupon period
    prevDates = [datesSet.settlement; couponDates(1:end-1)];
    delta     = yearfrac(prevDates, couponDates,6);   % nYears x 1

        % intermediate coupon dates (all but last)
        t_coupon = yearfrac(datesSet.settlement,couponDates(1:end-1),3);

        % interpolate zero rates at intermediate dates
        zr_interp      = interp1(yf_act365, zero_rates, t_coupon, 'linear', 'extrap');

        % convert to discounts
        B_intermediate = exp(-zr_interp .* t_coupon);

        % BPV sum with explicit 30/360 deltas
        BPV = sum(delta(1:end-1) .* B_intermediate);


    % bootstrap: B(t0,ti) = (1 - S*BPV) / (1 + delta_last*S)
    S          = mid_swaps(i);
    swaps_disc = (1 - S * BPV) / (1 + delta(end) * S);

    swaps_disc_vect = [swaps_disc_vect; swaps_disc];
    dates           = [dates;           datesSet.swaps(i)];
    discounts       = [discounts;       swaps_disc];

    % update zero rates with new pillar
    yf_act365  = yearfrac(datesSet.settlement,dates,3);
    zero_rates = -log(discounts) ./ yf_act365;
end

zeroRates=zero_rates;

% plot of the two cruves 

% fine grid for smooth plot
t_fine    = unique(sort([linspace(yf_act365(1), yf_act365(end), 500)'; yf_act365]));
zr_fine   = interp1(yf_act365, zero_rates, t_fine, 'linear', 'extrap');
disc_fine = exp(-zr_fine .* t_fine);

disp(table(datetime(dates, 'ConvertFrom', 'datenum', 'Format', 'dd/MM/yyyy'),discounts, zero_rates, 'VariableNames', {'dates', 'discounts','zero rates'}))

% --- plot ---
c_dep  = [0.20 0.45 0.75];
c_swap = [0.85 0.33 0.10];
c_dots = [0.60 0.60 0.60];

figure('Color','white','Position',[120 80 920 680]);

subplot(2,1,1); hold on;
plot(t_fine,       disc_fine,      '-', 'Color', c_dep,  'LineWidth', 1.8);
scatter(yf_act365, discounts,       25,  c_dots, 'filled');
xlabel('Maturity (years)', 'FontSize', 11);
ylabel('Discount factor',  'FontSize', 11);
title('EUR Discount Curve  —  15 Feb 2008', 'FontSize', 12, 'FontWeight', 'bold');
xlim([0 yf_act365(end)*1.02]); grid on; box on;

subplot(2,1,2); hold on;
plot(t_fine,       zr_fine*100,    '-', 'Color', c_swap, 'LineWidth', 1.8);
scatter(yf_act365, zero_rates*100,  25,  c_dots, 'filled');
xlabel('Maturity (years)', 'FontSize', 11);
ylabel('Zero rate (%)',    'FontSize', 11);
title('EUR Zero Rate Curve  —  15 Feb 2008', 'FontSize', 12, 'FontWeight', 'bold');
xlim([0 yf_act365(end)*1.02]); grid on; box on;

end % bootstrap